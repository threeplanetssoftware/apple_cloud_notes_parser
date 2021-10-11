require_relative 'AppleCloudKitRecord'

##
# This class represents an Apple Notes Account. 
# Generally this is just a local and an iCloud account. 
# This class has an Array of the AppleNote objects that 
# belong to this account.
class AppleNotesAccount < AppleCloudKitRecord

  attr_accessor :primary_key,
                :name,
                :notes,
                :identifier,
                :user_record_name

  ##
  # This creates a new AppleNotesAccount. 
  # It requires an Integer +primary_key+, a String +name+, 
  # and a String +identifier+ representing the ZIDENTIFIER column.
  def initialize(primary_key, name, identifier)
    # Initialize some variables we may need later
    @crypto_salt = nil
    @crypto_iterations = nil
    @crypto_key = nil
    @password = nil
    @server_record_data = nil

    # Initialize notes for this account
    @notes = Array.new()

    # Set this account's variables
    @primary_key = primary_key
    @name = name
    @identifier = identifier
    @user_record_name = ""
    # Uncomment the below line if you want to see the account names during creation
    # puts "Account #{@primary_key} is called #{@name}"
  end

  ##
  # This method adds the cryptographic variables to the account. 
  # This is outside of initialize as older Apple Notes didn't have this functionality. 
  # This requires a String of binary +crypto_salt+, an Integer of the number of +iterations+, 
  # and a String of binary +crypto_key+. Do not feed in hex.
  def add_crypto_variables(crypto_salt, crypto_iterations, crypto_key)
    @crypto_salt = crypto_salt
    @crypto_iterations = crypto_iterations
    @crypto_key = crypto_key
  end

  ## 
  # This function takes a String +password+.
  # It is unclear how or if this password matters right now.
  def add_password(password)
    @password = password
  end

  ##
  # This method requies an AppleNote object as +note+ and adds it to the folder's Array.
  def add_note(note)
    @notes.push(note)
  end

  ##
  # This class method spits out an Array containing the CSV headers needed to describe all of these objects.
  def self.to_csv_headers
    ["Account Primary Key", 
     "Account Name", 
     "Account Cloudkit Identifier",
     "Account Identifier",
     "Last Modified Device",
     "Number of Notes",
     "Crypto Salt (hex)",
     "Crypto Iteration Count (hex)",
     "Crypto Key (hex)"]
  end

  ##
  # This method generates an Array containing the information needed for CSV generation.
  def to_csv
    [@primary_key, 
     @name, 
     @user_record_name,
     @identifier,
     @cloudkit_last_modified_device,
     @notes.length,
     get_crypto_salt_hex,
     @crypto_iterations,
     get_crypto_key_hex]
  end

  ##
  # This returns the account's cryptowrapped key, if one exists, in hex.
  def get_crypto_key_hex
    return @crypto_key if ! @crypto_key
    @crypto_key.unpack("H*")
  end

  ##
  # This returns the account's salt, if one exists, in hex.
  def get_crypto_salt_hex
    return @crypto_salt if ! @crypto_salt
    @crypto_salt.unpack("H*")
  end

end
