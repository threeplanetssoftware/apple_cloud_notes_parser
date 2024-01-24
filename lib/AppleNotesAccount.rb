require 'fileutils'
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
                :user_record_name,
                :sort_order_name,
                :retain_order,
                :account_folder

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

    # Initialize notes and folders Arrays for this account
    @notes = Array.new()
    @folders = Array.new()
    @retain_order = false

    # Set this account's variables
    @primary_key = primary_key
    @name = name

    # Default html to empty until we build it
    @html = nil

    # Defaulting to the same value as the name, this can be overridden if the sort order is known
    @sort_order_name = name
    @identifier = identifier
    @user_record_name = ""

    # Figure out the Account's folder for attachments
    @account_folder = "Accounts/#{@identifier}/"

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
  # Returns a name with things removed that might allow for poorly placed files
  def clean_name
    @name.tr('/:\\', '_')
  end

  ## 
  # This function takes a String +password+.
  # It is unclear how or if this password matters right now.
  def add_password(password)
    @password = password
  end

  ##
  # This method requies an AppleNote object as +note+ and adds it to the accounts's Array.
  def add_note(note)
    @notes.push(note)
  end

  ##
  # This method requies an AppleNotesFolder object as +folder+ and adds it to the accounts's Array.
  def add_folder(folder)
    # Remove any copy if we already have it
    @folders.delete_if {|old_folder| old_folder.primary_key == folder.primary_key}
    @folders.push(folder)
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

  ##
  # This method returns an Array containing the AppleNotesFolders for the account, sorted in appropriate order
  def sorted_folders
    return @folders if !@retain_order
    @folders.sort_by{|folder| [folder.sort_order]}
  end

  ##
  # This method generates HTML to display on the overall output.
  def generate_html(individual_files: false, use_uuid: false)
    params = [individual_files, use_uuid]
    if @html && @html[params]
      return @html[params]
    end

    builder = Nokogiri::HTML::Builder.new(encoding: "utf-8") do |doc|
      doc.div {
        doc.h1 {
          doc.a(id: "account_#{@primary_key}") {
            doc.text @name
          }
        }

        if @user_record_name.length > 0
          doc.div {
            doc.b {
              doc.text "Cloudkit Identifier:"
            }

            doc.text " "
            doc.text @user_record_name
          }
        end

        doc.div {
          doc.b {
            doc.text "Account Identifier:"
          }

          doc.text " "
          doc.text @identifier
        }

        if @cloudkit_last_modified_device
          doc.div {
            doc.b {
              doc.text "Last Modified Device:"
            }

            doc.text " "
            doc.text @cloudkit_last_modified_device
          }
        end

        doc.div {
          doc.b {
            doc.text "Number of Notes:"
          }

          doc.text " "
          doc.text @notes.length
        }

        doc.div {
          doc.b {
            doc.text "Folders:"
          }

          doc.ul {
            sorted_folders.each do |folder|
              doc << folder.generate_folder_hierarchy_html(individual_files: individual_files, use_uuid: use_uuid) if !folder.is_child?
            end
          }
        }
      }
    end

    @html ||= {}
    @html[params] = builder.doc.root
  end

  ##
  # This method prepares the data structure that JSON will use to generate JSON later.
  def prepare_json
    to_return = Hash.new()
    to_return[:primary_key] = @primary_key
    to_return[:name] = @name
    to_return[:identifier] = @identifier
    to_return[:cloudkit_identifier] = @user_record_name
    to_return[:cloudkit_last_modified_device] = @cloudkit_last_modified_device
    to_return[:html] = generate_html

    to_return
  end

end
