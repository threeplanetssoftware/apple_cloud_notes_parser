require 'fileutils'
require 'cfpropertylist'
require 'pathname'
require_relative 'AppleDecrypter.rb'

# Big thanks to https://stackoverflow.com/questions/1498342/how-to-decrypt-an-encrypted-apple-itunes-iphone-backup/13793043#13793043

class AppleProtectionClass

  attr_accessor :uuid,
                :clas,
                :wrap,
                :ktyp,
                :wrapped_key,
                :unwrapped_key

  def initialize(uuid)
    @uuid = uuid
    @clas = nil
    @wrap = nil
    @ktyp = nil
    @wrapped_key = nil
    @unwrapped_key = nil
  end

end

class AppleBackupHashedManifestPlist

  attr_accessor :encrypted,
                :manifest_key,
                :manifest_key_class,
                :protection_classes

  def initialize(manifest_path, decrypter, logger=nil)

    # Read in the Manifest Plist for later use
    @manifest_plist_data = nil
    tmp_plist = CFPropertyList::List.new(:file => manifest_path);
    @manifest_plist_data = CFPropertyList.native_types(tmp_plist.value);

    @logger = Logger.new(STDOUT)
    @logger = logger if logger

    # Set up the encryption variables
    @encrypted = @manifest_plist_data["IsEncrypted"]
    @pbkdf2_salt = nil
    @pbkdf2_iter = nil
    @pbkdf2_double_protection_salt = nil
    @pbkdf2_double_protection_iter = nil

    @decrypter = decrypter

    @protection_classes = Array.new

    if @encrypted
      tmp_manifest_string = @manifest_plist_data["ManifestKey"]
      @manifest_key_class = tmp_manifest_string[0,4].unpack("V")[0]
      @manifest_key = tmp_manifest_string[4,40]
      self.parse_keybag
    end

  end

  ##
  # This method parses the manifest's keybag into internal data structures. 
  def parse_keybag
    current_location = 0
    tmp_keybag = @manifest_plist_data["BackupKeyBag"]

    pbkdf2_salt = nil
    pbkdf2_iters = 0
    pbkdf2_double_protection_salt = nil
    pbkdf2_double_protection_iters = 0

    @keybag_uuid = nil
    @keybag_wrap = nil

    tmp_protection_class = nil

    while current_location < tmp_keybag.length
      # First four bytes are the string type
      tmp_string_type = tmp_keybag[current_location, 4]
      current_location += 4

      # Next four bytes are the length, in big-endian
      tmp_length = tmp_keybag[current_location, 4].unpack("N")[0]
      current_location += 4

      # next X bytes are the value itself
      tmp_value = tmp_keybag[current_location, tmp_length]
      current_location += tmp_length

      # Read in values
      case tmp_string_type
        when "VERS"
          @keybag_version = tmp_value.unpack("N")[0]
        when "HMCK"
          @keybag_hmac = tmp_value
        when "TYPE"
          @keybag_type = tmp_value.unpack("N")[0]
        when "SALT"
          @pbkdf2_salt = tmp_value
        when "ITER"
          @pbkdf2_iter = tmp_value.unpack("N")[0]
        when "DPSL"
          @pbkdf2_double_protection_salt = tmp_value
        when "DPIC"
          @pbkdf2_double_protection_iter = tmp_value.unpack("N")[0]
        when "UUID"
          if not @keybag_uuid
            @keybag_uuid = tmp_value
          else
            # We have a new protection class
            @protection_classes.push(tmp_protection_class) if tmp_protection_class
            tmp_protection_class = AppleProtectionClass.new(tmp_value)
          end
        when "CLAS"
          tmp_protection_class.clas = tmp_value.unpack("N")[0]
        when "KTYP"
          tmp_protection_class.ktyp = tmp_value.unpack("N")[0]
        when "WPKY"
          tmp_protection_class.wrapped_key = tmp_value
        when "WRAP"
          if not @keybag_wrap
            @keybag_wrap = tmp_value
          else
            tmp_protection_class.wrap = tmp_value
          end
      end
    end

    @protection_classes.push(tmp_protection_class) if tmp_protection_class

    if self.key_values_present

      # First use a SHA256 round with DPSL and DPIC
      @logger.debug("AppleBackupHashedManifestPlist: Generating key, step 1")
      initial_key_size = 32
      initial_unwrapped_key = nil
      puts "Checking #{@decrypter.passwords.length} passwords, be aware that the initial step for each password is computationally intensive."
      @decrypter.passwords.each do |password|
        initial_unwrapped_key = @decrypter.generate_key_encrypting_key(password, @pbkdf2_double_protection_salt, @pbkdf2_double_protection_iter, '', initial_key_size) if !initial_unwrapped_key
      end

      return if !initial_unwrapped_key
      puts "Successfully generated encrypted iTunes key encrypting key using password"

      # then a SHA1 round with ITER and SALT
      @logger.debug("AppleBackupHashedManifestPlist: Generating key, step 2")
      @unwrapped_key = @decrypter.generate_key_encrypting_key(initial_unwrapped_key, @pbkdf2_salt, @pbkdf2_iter, '', initial_key_size, OpenSSL::Digest::SHA1.new)

      # Unwrap every key
      @protection_classes.each do |protection_class|
        protection_class.unwrapped_key = @decrypter.aes_key_unwrap(protection_class.wrapped_key, @unwrapped_key)
        @logger.debug("AppleBackupHashedManifestPlist: Unwrapped key for protection class #{protection_class.clas}")
      end
    end

  end

  ##
  # This method takes an Integer +class_id+ and returns the AppleProtectionClass that corresponds to that
  # class id. Returns nil if not found.
  def get_class_by_id(class_id)
    @protection_classes.each do |protection_class|
      return protection_class if protection_class.clas == class_id
    end

    return nil
  end

  def key_values_present
    (@pbkdf2_iter and @pbkdf2_salt and @pbkdf2_double_protection_iter and @pbkdf2_double_protection_salt)
  end

  ##
  # This method returns the @encrypted variable.
  def encrypted?
    @encrypted
  end

  ##
  # This method identifies if we can decrypt the file. It solely checks if an +@unwrapped_key+ exists.
  def can_decrypt?
    return @unwrapped_key != nil
  end

end
