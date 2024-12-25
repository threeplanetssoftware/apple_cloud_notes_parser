# This line ensures that Ruby 2.3 loads the *right* openssl module
gem 'openssl'

require 'aes_key_wrap'
require 'logger'
require 'openssl'

##
#
# This class plays a supporting role in decrypting data Apple encrypts at rest.
class AppleDecrypter

  attr_accessor :passwords,
                :successful_passwords

  EMPTY_IV = Array.new(16, 0x00).pack("C*")

  ##
  # Creates a new AppleDecrypter.
  # Immediately initalizes +@passwords+ and +@successful_passwords+ as Arrays to keep track of loaded 
  # passwords and the ones that worked. Also sets +@warned_about_empty_password_list+ to false in order 
  # to nicely warn the user ones if they should be trying to decrypt. Make sure to call logger= at some 
  # point if you don't want to dump to STDOUT. 
  def initialize
    @logger = Logger.new(STDOUT)
    @passwords = Array.new
    @successful_passwords = Array.new
    @warned_about_empty_password_list = false
  end

  ##
  # Sets the logger for the AppleDecrypter
  def logger=(logger)
    @logger = logger
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
    return @passwords.length
  end

  ##
  # This function takes a String +password+ and appends it to the overall +@passwords+ Array. 
  # Make sure to chomp the password prior to calling this function. 
  def add_password(password)
    @passwords.push(password)
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
  # This function checks a suspected password, salt, iteration count, and wrapped key 
  # to determine if the settings are valid. It does this by checking that the unwrapped key 
  # has the correct iv. It returns true if the settings are valid, false otherwise. 
  # It expects the +password+ as a String, the +salt+ as a binary String, and the number of 
  # +iterations+ as an integer, and the +wrapped_key+ as a binary String.
  def check_cryptographic_settings(password, salt, iterations, wrapped_key)
    tmp_key_encrypting_key = generate_key_encrypting_key(password, salt, iterations)
    tmp_unwrapped_key = aes_key_unwrap(wrapped_key, tmp_key_encrypting_key) if tmp_key_encrypting_key

    @successful_passwords.push(password) if (tmp_unwrapped_key and !@successful_passwords.include?(password))

    return (tmp_unwrapped_key != nil)
  end 

  ## 
  # This function calls PBKDF2 with Apple's settings to generate a key encrypting key. 
  # It expects the +password+ as a String, the +salt+ as a binary String, and the number of 
  # +iterations+ as an integer. It returns either nil or the generated key as a binary String. 
  # It an error occurs, it will rescue a OpenSSL::Cipher::CipherError and log it.
  def generate_key_encrypting_key(password, salt, iterations, debug_text=nil, key_size=16, hash_function=OpenSSL::Digest::SHA256.new)
    # Key length in bytes, multiple by 8 for bits. Apple is using 16 (128-bit)
    # key_size = 16
    generated_key = nil

    begin
      generated_key = OpenSSL::PKCS5.pbkdf2_hmac(password, salt, iterations, key_size, hash_function)
    rescue OpenSSL::Cipher::CipherError
      puts "Caught CipherError trying to generate PBKDF2 key"
      @logger.error("Apple Decrypter: #{debug_text} caught a CipherError while trying to generate PBKDF2 key.")
    rescue OpenSSL::KDF::KDFError
      puts "Caught KDFError trying to generate PBKDF2 key"
      @logger.error("Apple Decrypter: #{debug_text} caught a KDFError while trying to generate PBKDF2 key. Length: #{key_size}, Iterations: #{iterations}")
    end

    return generated_key
  end

  ##
  # This function performs an AES key unwrap function. It expects the +wrapped_key+ as a binary String 
  # and the +key_encrypting_key+ as a binary String. It returns either nil or the unwrapped key as a binary 
  # String. 
  def aes_key_unwrap(wrapped_key, key_encrypting_key)
    unwrapped_key = nil

    begin
      unwrapped_key = AESKeyWrap.unwrap!(wrapped_key, key_encrypting_key)
    rescue AESKeyWrap::UnwrapFailedError => error
      puts error
      # Not logging this because it will get spammy if different accounts have different passwords
    end

    return unwrapped_key
  end

  ##
  # This function performs an AES-CBC decryption. It expects the +key+ as a binary String, an +iv+ as a binary String, which
  # should be 16 0x00 bytes if you don't have another, and the +encrypted_data+ as a binary String. 
  # It returns either nil or the decrypted data as a binary String.
  def aes_cbc_decrypt(key, encrypted_data, iv=EMPTY_IV, debug_text=nil)
    decrypted_data = nil

    if (!key or !iv or !encrypted_data)
      @logger.error("AES CBC Decrypt called without either key, iv, or encrypted data.")
    end

    begin
      decrypter = OpenSSL::Cipher.new('aes-256-cbc').decrypt
      decrypter.decrypt
      decrypter.padding = 0 # If this is not set to 0, openssl appears to generate an extra block
      decrypter.key = key
      decrypter.iv = iv
      decrypted_data = decrypter.update(encrypted_data) + decrypter.final
    rescue OpenSSL::Cipher::CipherError => error
      puts "Failed to decrypt #{debug_text}, unwrapped key likely isn't right."
      @logger.error("Apple Decrypter: #{debug_text} caught a CipherError while trying final decrypt, likely the unwrapped key is not correct.")
    end

    return decrypted_data
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
      @logger.debug("Apple Decrypter: #{debug_text} decrypted")
    end

    return decrypt_result
  end

end
