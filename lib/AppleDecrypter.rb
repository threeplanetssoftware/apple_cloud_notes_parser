# This line ensures that Ruby 2.3 loads the *right* openssl module
gem 'openssl'

require 'aes_key_wrap'
require 'openssl'

##
#
# This class plays a supporting role in decrypting data Apple encrypts at rest.
class AppleDecrypter

  attr_accessor :successful_passwords

  ##
  # Creates a new AppleDecrypter. Expects an AppleBackup +backup+ to make use of the logger.
  # Immediately initalizes +@passwords+ and +@successful_passwords+ as Arrays to keep track of loaded 
  # passwords and the ones that worked. Also sets +@warned_about_empty_password_list+ to false in order 
  # to nicely warn the user ones if they should be trying to decrypt. 
  def initialize(backup)
    @logger = backup.logger
    @passwords = Array.new
    @successful_passwords = Array.new
    @warned_about_empty_password_list = false
  end

  ##
  # This function takes a FilePath +file+ and reads passwords from it 
  # one per line to build the overall +@passwords+ Array.
  def add_passwords_from_file(password_file)
    if password_file
      @passwords = Array.new()

      # Read in each line and add them to our list
      File.readlines(password_file).each do |password|
        #@logger.debug("Apple Decrypter: Adding password number #{passwords.length} to our list")
        @passwords.push(password.chomp)
      end

      puts "Added #{@passwords.length} passwords to the AppleDecrypter from #{password_file}"
    end
  end

  ##
  # This function attempts to decrypt the specified data by looping over all the loaded passwords. 
  # It expects a +salt+ as a binary String, the number of +iterations+ as an Integer, 
  # a +key+ representing the wrapped key as a binary String, an +iv+ as a binary String, a +tag+ as a binary String, 
  # the +data+ to be decrypted as a binary String, and the +item+ being decrypted as an Object to help with debugging. 
  # Any successful decrypts will add the corresponding password to the +@successful_passwords+ to be tried 
  # first the next time. 
  def decrypt(salt, iterations, key, iv, tag, data, debug_text=nil)

    # Initialize plaintext variable to be false so we can check if we don't succeed
    decrypt_result = false

    # Warn the user if we come across something encrypted and they haven't provided a password list
    if @passwords.length == 0 and !@warned_about_empty_password_list
      puts "Apple Decrypter: Attempting to decrypt objects without a password list set, check the -w option for more success"
      @logger.error("Apple Decrypter: Attempting to decrypt objects without a password list set, check the -w option for more success")
      @warned_about_empty_password_list = true
    end

    # Start with the known good passwords
    @successful_passwords.each do |password|
      decrypt_result = decrypt_with_password(password, salt, iterations, key, iv, tag, data, debug_text)
      if decrypt_result
        break
      end
    end

    # Only try the full list if we haven't already found the password
    if !decrypt_result
      @passwords.each do |password|
        decrypt_result = decrypt_with_password(password, salt, iterations, key, iv, tag, data, debug_text)
        if decrypt_result
          @successful_passwords.push(password)
          break
        end
      end
    end

    return decrypt_result
  end

  ## 
  # This function calls PBKDF2 with Apple's settings to generate a key encrypting key. 
  # It expects the +password+ as a String, the +salt+ as a binary String, and the number of 
  # +iterations+ as an integer. It returns either nil or the generated key as a binary String. 
  # It an error occurs, it will rescue a OpenSSL::Cipher::CipherError and log it.
  def generate_key_encrypting_key(password, salt, iterations, debug_text=nil)
    # Key length in bytes, multiple by 8 for bits. Apple is using 16 (128-bit)
    key_size = 16
    generated_key = nil

    begin
      generated_key = OpenSSL::PKCS5.pbkdf2_hmac(password, salt, iterations, key_size, OpenSSL::Digest::SHA256.new)
    rescue OpenSSL::Cipher::CipherError
      puts "Caught CipherError trying to generate PBKDF2 key"
      @logger.error("Apple Decrypter: #{debug_text} caught a CipherError while trying to generate PBKDF2 key.")
    end

    return generated_key
  end

  ##
  # This function performs an AES key unwrap function. It expects the +wrapped_key+ as a binary String 
  # and the +key_encrypting_key+ as a binary String. It returns either nil of the unwrapped key as a binary 
  # String. 
  def aes_key_unwrap(wrapped_key, key_encrypting_key)
    unwrapped_key = nil

    begin
      unwrapped_key = AESKeyWrap.unwrap!(wrapped_key, key_encrypting_key)
    rescue AESKeyWrap::UnwrapFailedError
      # Not logging this because it will get spammy if different accounts have different passwords
    end

    return unwrapped_key
  end

  ## 
  # This function performs the AES-GCM decryption. It expects a +key+ as a binary String, an +iv+ as a binary
  # String, a +tag+ as a binary String, the +encrypted_data+ as a binary String, and optional +debug_text+ 
  # if you want something helpful to hunt in the debug logs. It sets the iv length explicitly to the length of 
  # the iv and returns either nil or the plaintext if there was a decrypt. It rescues an OpenSSL::Cipher::CipherError 
  # and logs the issue. 
  def aes_gcm_decrypt(key, iv, tag, encrypted_data, debug_text=nil)
    plaintext = nil

      begin
        decrypter = OpenSSL::Cipher.new('aes-128-gcm').decrypt
        decrypter.key = key
        decrypter.iv_len = iv.length # Just in case the IV isn't 16-bytes
        decrypter.iv = iv
        decrypter.auth_tag = tag
        plaintext = decrypter.update(encrypted_data) + decrypter.final
      rescue OpenSSL::Cipher::CipherError
        puts "Failed to decrypt #{debug_text}, unwrapped key likely isn't right."
        @logger.error("Apple Decrypter: #{debug_text} caught a CipherError while trying final decrypt, likely the unwrapped key is not correct.")
      end

    return plaintext
  end

  ##
  # This function attempts to decrypt the note with a specified password.
  # It expects a +password+ as a normal String, a +salt+ as a binary String, the number of +iterations+ as an Integer, 
  # a +key+ representing the wrapped key as a binary String, an +iv+ as a binary String, a +tag+ as a binary String, 
  # the +data+ to be decrypted as a binary String, and the +item+ being decrypted as an Object to help with debugging. 
  # This starts by unwrapping the +wrapped_key+ using the given +password+ by computing the PBDKF2 with the given +salt+ and +iterations+.
  # With the unwrapped key, we can then use the +iv+ to decrypt the +data+ and authenticate it with the +tag+.
  def decrypt_with_password(password, salt, iterations, key, iv, tag, data, debug_text=nil)


    # Create the key with our password
    @logger.debug("Apple Decrypter: #{debug_text} Attempting decryption.")

    # Create variables to track our generated and unwrapped keys between blocks
    decrypt_result = false
    plainext = false

    # Generate the key-encrypting key from the user's password
    generated_key = generate_key_encrypting_key(password, salt, iterations)

    # Unwrap the key
    unwrapped_key = aes_key_unwrap(key, generated_key) if generated_key

    # Decrypt the content only if we have a key
    plaintext = aes_gcm_decrypt(unwrapped_key, iv, tag, data, debug_text) if unwrapped_key

    if plaintext
      decrypt_result = { plaintext: plaintext, password: password }
      @logger.debug("Apple Decrypter: #{debug_text} generated a decrypt")
    end

    return decrypt_result
  end

end
