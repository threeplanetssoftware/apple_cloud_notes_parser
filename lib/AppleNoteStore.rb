require 'digest'
require 'sqlite3'
require_relative 'AppleCloudKitShareParticipant'
require_relative 'AppleNote.rb'
require_relative 'AppleNotesAccount.rb'
require_relative 'AppleNotesFolder.rb'
require_relative 'AppleNotesSmartFolder.rb'
require_relative 'AppleNoteStoreVersion.rb'

##
# This class represents an Apple NoteStore file. It tries to handle the hard work of taking 
# any Apple Notes database, determining the proper version of it, and tailoring queries to 
# that version.
class AppleNoteStore 

  attr_accessor :folders,
                :accounts,
                :notes,
                :version,
                :backup,
                :database,
                :cloud_kit_participants,
                :retain_order,
                :range_start,
                :range_end

  ##
  # Creates a new AppleNoteStore. Expects a FilePath +file_path+ to the NoteStore.sqlite
  # database itself. Uses that to create a SQLite3::Database object to query into it. Immediately 
  # creates an Array to hold the +notes+, an Array to hold the +folders+ and an Array to hold 
  # the +accounts+. Then it calls +rip_accounts+ and +rip_folders+ to populate them. Also 
  # expects an Integer +version+ to know what type it is.
  def initialize(file_path, version)
    @file_path = file_path
    @database = nil
    @logger = Logger.new(STDOUT)
    @version = version
    @notes = Hash.new()
    @folders = Hash.new()
    @folder_order = Hash.new()
    @accounts = Hash.new()
    @cloud_kit_participants = Hash.new()
    @retain_order = false
    @html = nil
    @range_start = 0
    @range_end = Time.now.to_i
  end

  ##
  # This method sets the AppleBackup this AppleNoteStore belongs to. It
  # expects an AppleBackup +backup+ and uses that backup to set the date 
  # range and logger variables.
  def backup=(backup)
    @backup = backup
    @logger = @backup.logger
    @range_start = @backup.range_start
    @range_end = @backup.range_end
  end

  ##
  # This method opens the AppleNoteStore's database.
  def open
    return if @database
    @database = SQLite3::Database.new(@file_path.to_s, {results_as_hash: true})
  end

  ## 
  # This method nicely closes the database handle.
  def close
    @database.close if @database
  end

  ##
  # This method does a set of database calls to try to guess the version of Apple Notes we are ripping. 
  # It tries to structure the checks to bail out as each specific version is recognized and then assume we are not it.
  # Helpful changelogs: 
  # 18 (https://support.apple.com/en-mide/121161): Audio recordings inside notes, math auto-completion, text color highlighting
  # 17 (https://support.apple.com/en-us/HT213781): Tons of under-the-hood tweaks
  # 16 (https://support.apple.com/en-us/HT213407): No need for separate password to lock notes
  # 15 (https://support.apple.com/en-us/HT212788): Hashtags, mentions
  # 14 (https://support.apple.com/en-us/HT211808): Better scanning
  # 13 (https://support.apple.com/en-us/HT210393): Added checklists and shared folders, better search, and gallery 
  # 12 (https://support.apple.com/en-us/HT209084): Nothing major 
  # 11 (https://support.apple.com/en-us/HT208067): Added document scanner, added tables 
  # 10 (https://support.apple.com/en-us/HT208011): Added collaboration features 
  # 9 (https://support.apple.com/en-us/HT208010): Added sketches, ability to insert images inline, websites, and maps. Added iCLoud support
  # 8 (https://support.apple.com/en-us/HT208000): Added rich text support, and adding images
  def self.guess_ios_version(database_to_check)
    database_tables = get_database_tables(database_to_check)

    ziccloudsyncingobject_columns = get_database_table_columns(database_to_check, "ZICCLOUDSYNCINGOBJECT")
    zicnotedata_columns = get_database_table_columns(database_to_check, "ZICNOTEDATA")

    # If ZICNOTEDATA has no columns, this is a legacy copy
    if zicnotedata_columns.length == 0
      return AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_LEGACY_VERSION)
    end

    # It appears ZUNAPPLIEDENCRYPTEDRECORDDATA showed up in iOS 18's updates
    if ziccloudsyncingobject_columns.include?("ZUNAPPLIEDENCRYPTEDRECORDDATA: BLOB")
      return AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_18)
    end

    # It appears ZGENERATION showed up in iOS 17's updates
    if ziccloudsyncingobject_columns.include?("ZGENERATION: VARCHAR")
      return AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_17)
    end

    # It appears ZACCOUNT6 - ZACCOUNT8 showed up in iOS 16's updates
    if ziccloudsyncingobject_columns.include?("ZACCOUNT6: INTEGER")
      return AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_16)
    end

    # It appears ZACCOUNT5 showed up in iOS 15's updates
    if ziccloudsyncingobject_columns.include?("ZACCOUNT5: INTEGER")
      return AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_15)
    end

    # It appears ZLASTOPENEDDATE showed up in iOS 14's updates
    if ziccloudsyncingobject_columns.include?("ZLASTOPENEDDATE: TIMESTAMP")
      return AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_14)
    end

    # It appears ZACCOUNT4 showed up in iOS 13's updates, as it is tied to shared folders
    if ziccloudsyncingobject_columns.include?("ZACCOUNT4: INTEGER")
      return AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_13)
    end

    # ZSERVERRECORDDATA showed up in iOS 12, prior to that it was just ZSERVERRECORD
    if ziccloudsyncingobject_columns.include?("ZSERVERRECORDDATA: BLOB")
      return AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_12)
    end

    # This table was *likely* new in iOS 11, based on the name
    if database_tables.include?("Z_11NOTES")
      return AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_11)
    end

    # When in doubt, return unknown
    return AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_UNKNOWN)
  end

  ##
  # This class method hashes the table names within a database to compare them. It 
  # expects a Pathname pointing to the database file.
  def self.get_database_tables(database_to_check)
    to_return = Array.new

    database = SQLite3::Database.new(database_to_check.to_s, {results_as_hash: true})

    database.execute("SELECT name FROM sqlite_master WHERE type='table'") do |row|
      to_return.push(row["name"])
    end

    database.close

    return to_return
  end

  ##
  # This class.method takes the sql used by SQlite to create a table and extracts the column names and types.
  # This method expects a String +sql+ statement.
  def self.rip_columns_from_sql(sql)
    table_columns = Array.new

    # Regex to snag just the table definitions from the returned sql statement
    table_column_regex = Regexp.new(/^CREATE TABLE .* \((.*)\)/i)

    # Use a regular expression to pull out the column definitions
    table_column_regex.match(sql) do |match|
  
      # Split the column definitions by commas and loop over them
      match[1].split(',').each do |column|

        # Trim the column, then split it on spaces and build a String of the column name and type
        column.strip!
        column_parts = column.split(" ")
        table_columns.push(column_parts[0] + ": " + column_parts[1])
      end
    end

    # Return back the table_columns Array
    return table_columns
  end

  ##
  # This class method returns an MD5 hash of the concatenation of database columsn and types. It expects 
  # a Pathname +database_to_check+ pointing to the location on disk of the database to check. It also expects 
  # a String +table+, representing the table name to look up. It is useful to fingerprint a given table version.
  def self.get_database_table_columns(database_to_check, table)
    to_return = Array.new

    database = SQLite3::Database.new(database_to_check.to_s, {results_as_hash: true})

    # Need to ensure we're sorting everywhere possible to keep things in order
    database.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name=? ORDER BY name ASC", table) do |row|
      to_return = to_return + rip_columns_from_sql(row["sql"]).sort
    end

    database.close

    # Return back an MD5 hash of the Array, sorted and joined
    return to_return
  end

  ##
  # This method ensures that the SQLite3::Database is a valid iCloud version of Apple Notes.
  def valid_notes?
    return true if @version >= AppleNoteStoreVersion::IOS_LEGACY_VERSION # Easy out if we've already identified the version

    # Just because my fingerprinting isn't great yet, adding in a more manual check for the key tables we need
    expected_tables = ["ZICCLOUDSYNCINGOBJECT",
                       "ZICNOTEDATA"]
    @database.execute("SELECT name FROM sqlite_master WHERE type='table'") do |row|
      expected_tables.delete(row["name"])
    end

    return (expected_tables.length == 0)
  end

  ##
  # This method kicks off the parsing of all the objects
  def rip_all_objects
    open
    rip_accounts()
    rip_folders()
    rip_notes()
    puts "Updated AppleNoteStore object with #{@notes.length} AppleNotes in #{@folders.length} folders belonging to #{@accounts.length} accounts."
  end

  ##
  # This method returns an Array of rows to build the +accounts+ 
  # CSV object.
  def get_account_csv
    to_return = [AppleNotesAccount.to_csv_headers]
    @accounts.each do |key, account|
      to_return.push(account.to_csv)
    end
    to_return
  end

  ##
  # This method adds the ZPLAINTEXT column to ZICNOTEDATA 
  # and then populates it with each note's plaintext.
  def add_plain_text_to_database

    return if @version < AppleNoteStoreVersion::IOS_VERSION_9 # Fail out if we're prior to the compressed data age

    # Warn the user
    puts "Adding the ZICNOTEDATA.ZPLAINTEXT and ZICNOTEDATA.ZDECOMPRESSEDDATA columns, this takes a few seconds"

    # Add the new ZPLAINTEXT column
    @database.execute("ALTER TABLE ZICNOTEDATA ADD COLUMN ZPLAINTEXT TEXT")
    @database.execute("ALTER TABLE ZICNOTEDATA ADD COLUMN ZDECOMPRESSEDDATA TEXT")

    # Loop over each AppleNote
    @notes.each do |key, note|

      # Update the database to include the plaintext
      @database.execute("UPDATE ZICNOTEDATA " + 
                        "SET ZPLAINTEXT=?, ZDECOMPRESSEDDATA=? " + 
                        "WHERE Z_PK=?",
                        [note.plaintext, note.decompressed_data, note.primary_key]) if note.plaintext
    end
  end

  ##
  # This method returns an Array of rows to build the 
  # CSV object holding all AppleNotesEmbeddedObject instances in its +notes+.
  def get_embedded_object_csv
    to_return = [AppleNotesEmbeddedObject.to_csv_headers]

    # Loop over each AppleNote
    @notes.each do |key, note|
  
      # Loop over eac AppleNotesEmbeddedObject
      note.all_embedded_objects.each do |embedded_object|

        # Get the results of AppleNotesEmbeddedObject.to_csv
        embedded_object_csv = embedded_object.to_csv

        # Check to see if the first element is an Array
        if embedded_object_csv.first.is_a? Array

          # If it is, loop over each entry to add it to our results
          embedded_object_csv.each do |embedded_array|
            to_return.push(embedded_array)
          end
        else 
          to_return.push(embedded_object_csv)
        end
      end
    end
    to_return
  end

  ##
  # This method returns an Array of rows to build the +folders+ 
  # CSV object.
  def get_folder_csv
    to_return = [AppleNotesFolder.to_csv_headers]
    @folders.sort_by{|key, folder| key}.each do |key, folder|
      to_return.push(folder.to_csv)
    end
    to_return
  end

  ##
  # This method returns an Array of rows to build the +cloudkit_participants+ 
  # CSV object.
  def get_cloudkit_participants_csv
    to_return = [AppleCloudKitShareParticipant.to_csv_headers]
    @cloud_kit_participants.each do |key, participant|
      to_return.push(participant.to_csv)
    end
    to_return
  end

  ##
  # This method returns an Array of rows to build the +notes+ 
  # CSV object.
  def get_note_csv
    to_return = [AppleNote.to_csv_headers]
    @notes.each do |key, note|
      to_return.push(note.to_csv)
    end
    to_return
  end

  ##
  # This method takes a String +record_id+ to determine if the particular cloudkit 
  # record is known. It returns an AppleCloudKitParticipant object, or False.
  def cloud_kit_record_known?(record_id)
    return false if !@cloud_kit_participants.include?(record_id)    
    return @cloud_kit_participants[record_id]
  end

  ##
  # This method looks up an AppleNotesAccount based on the given +account_id+. 
  # ID should be an Integer that represents the ZICCLOUDSYNCINGOBJECT.Z_PK of the account.
  def get_account(account_id)
    @accounts[account_id]
  end

  ##
  # This method looks up an AppleNotesAccount based on the given +user_record_name+. 
  # User record nameshould be a String that represents the ZICCLOUDSYNCINGOBJECT.ZUSERRECORDNAME of the account.
  def get_account_by_user_record_name(user_record_name)
    @accounts.each_pair do |account_id, account|
      return account if (account.user_record_name == user_record_name)
    end

    return nil
  end

  ##
  # This method looks up an AppleNotesFolder based on the given +folder_id+. 
  # ID should be an Integer that represents the ZICCLOUDSYNCINGOBJECT.Z_PK of the folder.
  def get_folder(folder_id)
    @folders[folder_id]
  end

  ##
  # This method looks up an AppleNotesFolder based on the given +folder_uuid+. 
  # ID should be a String that represents the ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER of the folder.
  def get_folder_by_uuid(folder_uuid)
    @folders.each_value do |folder|
      return folder if folder.uuid == folder_uuid
    end
    return nil
  end

  ##
  # This method looks up an AppleNote based on the given +note_id+. 
  # ID should be an Integer that represents the ZICNOTEDATA.ZNOTE of the note.
  def get_note(note_id)
    @notes[note_id]
  end

  ##
  # This function identifies all AppleNotesAccount potential 
  # objects in ZICCLOUDSYNCINGOBJECTS and calls +rip_account+ on each.
  def rip_accounts()
    if @version.modern?
      @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.Z_PK " +
                        "FROM ZICCLOUDSYNCINGOBJECT " + 
                        "WHERE ZICCLOUDSYNCINGOBJECT.ZNAME IS NOT NULL") do |row|
        rip_account(row["Z_PK"])
      end 
    end

    if @version.legacy?
      @database.execute("SELECT ZACCOUNT.Z_PK FROM ZACCOUNT") do |row|
        rip_account(row["Z_PK"])
      end
    end

    @accounts.each_pair do |key, account|
      @logger.debug("Rip Accounts final array: #{key} corresponds to #{account.name}")
    end

  end

  ##
  # This function takes a specific AppleNotesAccount potential 
  # object in ZICCLOUDSYNCINGOBJECTS, identified by Integer +account_id+, and pulls the needed information to create the object.
  # If encryption information is present, it adds it with AppleNotesAccount.add_crypto_variables.
  def rip_account(account_id)
  
    @logger.debug("Rip Account: Calling rip_account on Account ID #{account_id}")

    # Set the ZSERVERRECORD column to look at
    server_record_column = "ZSERVERRECORD"
    server_record_column = server_record_column + "DATA" if @version >= AppleNoteStoreVersion::IOS_VERSION_12 # In iOS 11 this was ZSERVERRECORD, in 12 and later it became ZSERVERRECORDDATA

    # Set the ZSERVERSHARE column to look at
    server_share_column = "ZSERVERSHARE"
    server_share_column = server_share_column + "DATA" if @version >= AppleNoteStoreVersion::IOS_VERSION_12 # In iOS 11 this was ZSERVERRECORD, in 12 and later it became ZSERVERRECORDDATA

    # Set the ZACCOUNTDATA column to look at
    account_data_column = "-1 as ZACCOUNTDATA"
    account_data_column = "ZICCLOUDSYNCINGOBJECT.ZACCOUNTDATA" if @version >= AppleNoteStoreVersion::IOS_VERSION_13 # This column appears to show up in iOS 12

    @logger.debug("Rip Account: Using server_record_column of #{server_record_column}")

    # Set the query
    query_string = "SELECT ZICCLOUDSYNCINGOBJECT.ZNAME, ZICCLOUDSYNCINGOBJECT.Z_PK, " + 
                   "ZICCLOUDSYNCINGOBJECT.#{server_record_column}, ZICCLOUDSYNCINGOBJECT.ZCRYPTOITERATIONCOUNT, " + 
                   "ZICCLOUDSYNCINGOBJECT.ZCRYPTOVERIFIER, ZICCLOUDSYNCINGOBJECT.ZCRYPTOSALT, " + 
                   "ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, ZICCLOUDSYNCINGOBJECT.#{server_share_column}, " +
                   "ZICCLOUDSYNCINGOBJECT.ZUSERRECORDNAME, #{account_data_column}, " +
                   "ZICCLOUDSYNCINGOBJECT.ZACCOUNTNAMEFORACCOUNTLISTSORTING " +
                   "FROM ZICCLOUDSYNCINGOBJECT " + 
                   "WHERE ZICCLOUDSYNCINGOBJECT.Z_PK=?"
    
    # Change the query for legacy IOS
    if @version.legacy?
      query_string = "SELECT ZACCOUNT.ZNAME, ZACCOUNT.Z_PK, " + 
                     "ZACCOUNT.ZACCOUNTIDENTIFIER as ZIDENTIFIER " + 
                     "FROM ZACCOUNT " + 
                     "WHERE ZACCOUNT.Z_PK=?"
    end

    @logger.debug("Rip Account: Query is #{query_string}")

    # Run the query
    @database.execute(query_string, account_id) do |row|
  
      # Create account object
      tmp_account = AppleNotesAccount.new(row["Z_PK"],
                                          row["ZNAME"],
                                          row["ZIDENTIFIER"])

      tmp_account.retain_order = @retain_order

      # Handle LocalAccounts that are in odd places
      likely_location = @backup.root_folder + tmp_account.account_folder
      if tmp_account.identifier == "LocalAccount" and not likely_location.exist?
        tmp_account.account_folder = ""
        @logger.debug("Rip Account: LocalAccount found with files in the Notes root folder, not an account folder, this is fine.")
      end

      # Add server-side data, if relevant
      tmp_account.user_record_name = row["ZUSERRECORDNAME"] if row["ZUSERRECORDNAME"]
      tmp_account.add_cloudkit_server_record_data(row[server_record_column]) if row[server_record_column]

      # Set the sort order for the account so we can properly sort things later
      tmp_account.sort_order_name = row["ZACCOUNTNAMEFORACCOUNTLISTSORTING"] if row["ZACCOUNTNAMEFORACCOUNTLISTSORTING"]

      if(row[server_share_column]) 
        tmp_account.add_cloudkit_sharing_data(row[server_share_column])

        # Add any share participants to our overall list
        tmp_account.share_participants.each do |participant|
          @cloud_kit_participants[participant.record_id] = participant
        end
      end

      # Add cryptographic variables, if relevant
      if row["ZCRYPTOVERIFIER"]
        tmp_account.add_crypto_variables(row["ZCRYPTOSALT"],
                                         row["ZCRYPTOITERATIONCOUNT"],
                                         row["ZCRYPTOVERIFIER"])
      end

      # Store the folder structure if we have one
      if row["ZACCOUNTDATA"] and row["ZACCOUNTDATA"] > 0
        account_data_query_string = "SELECT ZICCLOUDSYNCINGOBJECT.ZMERGEABLEDATA " + 
                                    "FROM ZICCLOUDSYNCINGOBJECT " + 
                                    "WHERE Z_PK=?"
        @database.execute(account_data_query_string, row["ZACCOUNTDATA"]) do |account_data_row|
          gzipped_data = account_data_row["ZMERGEABLEDATA"]

          # Make sure this exists before we try to unpack it
          @logger.debug("Rip Account: row['ZMERGEABLEDATA'] is empty!") if !gzipped_data
          if gzipped_data

            # Inflate the GZip
            zlib_inflater = Zlib::Inflate.new(Zlib::MAX_WBITS + 16)
            mergeable_data = zlib_inflater.inflate(gzipped_data)

            # Read the protobuff
            mergabledata_proto = MergableDataProto.decode(mergeable_data)

            # Loop over all the mergeable data object entries to find the list
            mergabledata_proto.mergable_data_object.mergeable_data_object_data.mergeable_data_object_entry.each do |mergeable_data_object_entry|

              # Once you find the list, loop over each entry to...
              if mergeable_data_object_entry.list
                mergeable_data_object_entry.list.list_entry.each do |list_entry|

                  # Fetch the folder order, which is an int64 in the protobuf
                  additional_details_index = list_entry.additional_details.id.object_index
                  additional_details_object = mergabledata_proto.mergable_data_object.mergeable_data_object_data.mergeable_data_object_entry[additional_details_index]
                  tmp_folder_placement = additional_details_object.unknown_message.unknown_entry.unknown_int2

                  # Pull out the object index we can find the UUID at
                  list_index = list_entry.id.object_index

                  # Use that index to find the UUID's object
                  tmp_folder_uuid_object = mergabledata_proto.mergable_data_object.mergeable_data_object_data.mergeable_data_object_entry[list_index]

                  # Look inside that object to get the string value that is saved in the custom map
                  tmp_folder_uuid = tmp_folder_uuid_object.custom_map.map_entry.first.value.string_value

                  @folder_order[tmp_folder_uuid] = tmp_folder_placement
                end
              end
            end
          end
        end
      end

      @logger.debug("Rip Account: Created account #{tmp_account.name}")

      @accounts[account_id] = tmp_account
    end 
  end

  ##
  # This function identifies all AppleNotesFolder potential 
  # objects in ZICCLOUDSYNCINGOBJECTS and calls +rip_folder+ on each.
  def rip_folders()
    if @version.modern?
      @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.Z_PK " + 
                        "FROM ZICCLOUDSYNCINGOBJECT " + 
                        "WHERE ZICCLOUDSYNCINGOBJECT.ZTITLE2 IS NOT NULL") do |row|
        rip_folder(row["Z_PK"])
      end
    end

    # In legacy Notes the "folders" were "stores"
    if @version.legacy?
      @database.execute("SELECT ZSTORE.Z_PK FROM ZSTORE") do |row|
        rip_folder(row["Z_PK"])
      end
    end

    # Loop over all folders to do some clean up
    @folders.each_pair do |key, folder|
      if folder.is_orphan?
        tmp_parent_folder = get_folder(folder.parent_id) if folder.parent_id
        tmp_parent_folder = get_folder_by_uuid(folder.parent_uuid) if folder.parent_uuid
        @logger.debug("Rip Folder: Identified parent UUID #{folder.parent_uuid} for Folder #{folder.primary_key} (#{folder.name}) in ZSERVERRECORD data")
        if tmp_parent_folder
          tmp_parent_folder.add_child(folder) 
          @logger.debug("Rip Folder: Added folder #{folder.primary_key} (#{folder.full_name}) as child to #{tmp_parent_folder.name}")
        else
          @logger.debug("Rip Folder: Could not find parent folder for Folder #{folder.primary_key}")
        end
      end

      @logger.debug("Rip Folders final array: #{key} corresponds to #{folder.name}")
    end

    # Sort the folders if we want to retain the order, group each account together
    if @retain_order
      @folders = @folders.sort_by{|folder_id, folder| [folder.account.sort_order_name, folder.sort_order]}.to_h

      # Also organize the child folders nicely
      @folders.each do |folder_id, folder|
        folder.sort_children
      end
    end

  end

  ##
  # This function takes a specific AppleNotesFolder potential 
  # object in ZICCLOUDSYNCINGOBJECTS, identified by Integer +folder_id+, and pulls the needed information to create the object. 
  # This used to use ZICCLOUDSYNCINGOBJECT.ZACCOUNT4, but that value also appears to be duplicated in ZOWNER which goes back further.
  def rip_folder(folder_id)

    @logger.debug("Rip Folder: Calling rip_folder on Folder ID #{folder_id}")

    # Set the ZSERVERRECORD column to look at
    server_record_column = "ZSERVERRECORD"
    server_record_column = server_record_column + "DATA" if @version >= AppleNoteStoreVersion::IOS_VERSION_12 # In iOS 11 this was ZSERVERRECORD, in 12 and later it became ZSERVERRECORDDATA

    # Set the ZSERVERSHARE column to look at
    server_share_column = "ZSERVERSHARE"
    server_share_column = server_share_column + "DATA" if @version >= AppleNoteStoreVersion::IOS_VERSION_12 # In iOS 11 this was ZSERVERRECORD, in 12 and later it became ZSERVERRECORDDATA
 
    smart_folder_query = "'' as ZSMARTFOLDERQUERYJSON"
    smart_folder_query = "ZICCLOUDSYNCINGOBJECT.ZSMARTFOLDERQUERYJSON" if @version >= AppleNoteStoreVersion::IOS_VERSION_15
 
    query_string = "SELECT ZICCLOUDSYNCINGOBJECT.ZTITLE2, ZICCLOUDSYNCINGOBJECT.ZOWNER, " + 
                   "ZICCLOUDSYNCINGOBJECT.#{server_record_column}, ZICCLOUDSYNCINGOBJECT.#{server_share_column}, " +
                   "ZICCLOUDSYNCINGOBJECT.Z_PK, ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, " +
                   "ZICCLOUDSYNCINGOBJECT.ZPARENT, #{smart_folder_query} " +
                   "FROM ZICCLOUDSYNCINGOBJECT " + 
                   "WHERE ZICCLOUDSYNCINGOBJECT.Z_PK=?"

    #Change things up for the legacy version
    if @version.legacy?
      query_string = "SELECT ZSTORE.Z_PK, ZSTORE.ZNAME as ZTITLE2, " +
                     "ZSTORE.ZACCOUNT as ZOWNER, '' as ZIDENTIFIER " +
                     "FROM ZSTORE " +
                     "WHERE ZSTORE.Z_PK=?"
    end

    @database.execute(query_string, folder_id) do |row|

      tmp_folder = AppleNotesFolder.new(row["Z_PK"],
                                        row["ZTITLE2"],
                                        get_account(row["ZOWNER"]))

      # If this is a smart folder, instead build an AppleNotesSmartFolder
      if row["ZSMARTFOLDERQUERYJSON"] and row["ZSMARTFOLDERQUERYJSON"].length > 0
        tmp_folder = AppleNotesSmartFolder.new(row["Z_PK"],
                                               row["ZTITLE2"],
                                               get_account(row["ZOWNER"]),
                                               row["ZSMARTFOLDERQUERYJSON"])
      end

      if row["ZIDENTIFIER"]
        tmp_folder.uuid = row["ZIDENTIFIER"]
      end

      # Set whether the folder displays notes in numeric order, or by modification date
      tmp_folder.retain_order = @retain_order
      tmp_folder.sort_order = @folder_order[row["ZIDENTIFIER"]] if @folder_order[row["ZIDENTIFIER"]]

      # Remember folder heirarchy
      if row["ZPARENT"]
        tmp_parent_folder_id = row["ZPARENT"]
        tmp_folder.parent_id = tmp_parent_folder_id
      end

      # Add server-side data, if relevant
      tmp_folder.add_cloudkit_server_record_data(row[server_record_column]) if row[server_record_column]

      if(row[server_share_column]) 
        tmp_folder.add_cloudkit_sharing_data(row[server_share_column])

        # Add any share participants to our overall list
        tmp_folder.share_participants.each do |participant|
          @cloud_kit_participants[participant.record_id] = participant
        end
      end

      @logger.debug("Rip Folder: Created folder #{tmp_folder.name}")
 
      # Whether child or not, we add it to the overall tracker so we can look up by folder ID.
      # We'll clean up on output by testing to see if a folder has a parent.
      @folders[folder_id] = tmp_folder

    end
  end

  ##
  # This function identifies all AppleNote potential 
  # objects in ZICNOTEDATA and calls +rip_note+ on each.
  def rip_notes()
    range_start_core = (@range_start - 978307200)
    range_end_core = (@range_end - 978307200)
    @logger.debug("Rip Notes: Ripping notes between #{Time.at(range_start)} and #{Time.at(range_end)}")
    if @version.modern?
      tmp_query = "SELECT ZICNOTEDATA.ZNOTE " + 
                  "FROM ZICNOTEDATA, ZICCLOUDSYNCINGOBJECT " + 
                  "WHERE ZICNOTEDATA.ZDATA NOT NULL AND ZICCLOUDSYNCINGOBJECT.Z_PK=ZICNOTEDATA.ZNOTE AND " + 
                  "ZICCLOUDSYNCINGOBJECT.ZMODIFICATIONDATE1 >= ? AND " + 
                  "ZICCLOUDSYNCINGOBJECT.ZMODIFICATIONDATE1 <= ?"
      @database.execute(tmp_query, [range_start_core, range_end_core]) do |row|
        begin
          self.rip_note(row["ZNOTE"])
        rescue StandardError => error
          # warn "\033[101m#{e}\033[m"
          @logger.error("AppleNoteStore: NoteStore tried to rip Note #{row["ZNOTE"]} but had to rescue error: #{error}")
          @logger.error("Backtrace: #{error.backtrace.join("\n\t")}") # if error.is_a? FrozenError
        end
      end
    end

    if @version.legacy?
      @database.execute("SELECT ZNOTE.Z_PK FROM ZNOTE") do |row|
        self.rip_note(row["Z_PK"])
      end
    end
  end

  ##
  # This function takes a specific AppleNotesAccount potential 
  # object in ZICCLOUDSYNCINGOBJECTS and ZICNOTEDATA, identified by Integer +account_id+, 
  # and pulls the needed information to create the object. An AppleNote remembers the AppleNotesFolder 
  # and AppleNotesAccount it is part of. If encryption information is present, it adds 
  # it with AppleNotesAccount.add_crypto_variables.
  def rip_note(note_id)

    @logger.debug("Rip Note: Ripping note from Note ID #{note_id}")

    # Set the ZSERVERRECORD column to look at
    server_record_column = "ZSERVERRECORD"
    server_record_column = server_record_column + "DATA" if @version >= AppleNoteStoreVersion::IOS_VERSION_12 # In iOS 11 this was ZSERVERRECORD, in 12 and later it became ZSERVERRECORDDATA

    # Set the ZSERVERSHARE column to look at
    server_share_column = "ZSERVERSHARE"
    server_share_column = server_share_column + "DATA" if @version >= AppleNoteStoreVersion::IOS_VERSION_12 # In iOS 11 this was ZSERVERRECORD, in 12 and later it became ZSERVERRECORDDATA

    # Set the ZWIDGETSNIPPET column, blank if earlier than iOS 17
    widget_snippet_column = ""
    widget_snippet_column = ", ZWIDGETSNIPPET" if @version >= AppleNoteStoreVersion::IOS_VERSION_17

    # Set the ZUNAPPLIEDENCRYPTEDRECORD column to look at
    unapplied_encrypted_record_column = "ZUNAPPLIEDENCRYPTEDRECORD"
    unapplied_encrypted_record_column = unapplied_encrypted_record_column + "DATA" if @version >= AppleNoteStoreVersion::IOS_VERSION_18 # In iOS 17 this was ZUNAPPLIEDENCRYPTEDRECORD, in 18 and later it becomes ZUNAPPLIEDENCRYPTEDRECORDDATA

    folder_field = "ZFOLDER"
    account_field = "ZACCOUNT7"
    note_id_field = "ZNOTE"
    creation_date_field = "ZCREATIONDATE1"
 
    # In version 15, what is now in ZACCOUNT7 as of iOS 16 (the account ID) was in ZACCOUNT4
    if @version == AppleNoteStoreVersion::IOS_VERSION_15
      account_field = "ZACCOUNT4"
    end

    # In version 13 and 14, what is now in ZACCOUNT4 as of iOS 15 (the account ID) was in ZACCOUNT3
    if @version < AppleNoteStoreVersion::IOS_VERSION_15
      account_field = "ZACCOUNT3"
    end

    # In iOS 15 it appears ZCREATIONDATE1 moved to ZCREATIONDATE3 for notes
    if @version > AppleNoteStoreVersion::IOS_VERSION_14
      creation_date_field = "ZCREATIONDATE3"
    end

    query_string = "SELECT ZICNOTEDATA.Z_PK, ZICNOTEDATA.ZNOTE, " + 
                   "ZICNOTEDATA.ZCRYPTOINITIALIZATIONVECTOR, ZICNOTEDATA.ZCRYPTOTAG, " + 
                   "ZICNOTEDATA.ZDATA, ZICCLOUDSYNCINGOBJECT.ZCRYPTOVERIFIER, " + 
                   "ZICCLOUDSYNCINGOBJECT.ZCRYPTOSALT, ZICCLOUDSYNCINGOBJECT.ZCRYPTOITERATIONCOUNT, " + 
                   "ZICCLOUDSYNCINGOBJECT.ZCRYPTOWRAPPEDKEY, ZICCLOUDSYNCINGOBJECT.ZISPASSWORDPROTECTED, " +
                   "ZICCLOUDSYNCINGOBJECT.ZMODIFICATIONDATE1, ZICCLOUDSYNCINGOBJECT.#{creation_date_field}, " +
                   "ZICCLOUDSYNCINGOBJECT.ZTITLE1, ZICCLOUDSYNCINGOBJECT.#{account_field}, " +
                   "ZICCLOUDSYNCINGOBJECT.ZACCOUNT2, ZICCLOUDSYNCINGOBJECT.#{folder_field}, " + 
                   "ZICCLOUDSYNCINGOBJECT.#{server_record_column}, ZICCLOUDSYNCINGOBJECT.#{unapplied_encrypted_record_column}, " + 
                   "ZICCLOUDSYNCINGOBJECT.#{server_share_column}, ZICCLOUDSYNCINGOBJECT.ZISPINNED, " + 
                   "ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER #{widget_snippet_column} " + 
                   "FROM ZICNOTEDATA, ZICCLOUDSYNCINGOBJECT " + 
                   "WHERE ZICNOTEDATA.ZNOTE=? AND ZICCLOUDSYNCINGOBJECT.Z_PK=ZICNOTEDATA.ZNOTE"

    # In version 12, what is now in ZACCOUNT3 (the account ID) was in ZACCOUNT2
    if @version == AppleNoteStoreVersion::IOS_VERSION_12
      account_field = "ZACCOUNT2"
    end

    # In version 11, what is now in ZACCOUNT3 was in ZACCOUNT2 and the ZFOLDER field was in a completely separate table
    if @version == AppleNoteStoreVersion::IOS_VERSION_11
      query_string = "SELECT ZICNOTEDATA.Z_PK, ZICNOTEDATA.ZNOTE, " + 
                     "ZICNOTEDATA.ZCRYPTOINITIALIZATIONVECTOR, ZICNOTEDATA.ZCRYPTOTAG, " + 
                     "ZICNOTEDATA.ZDATA, ZICCLOUDSYNCINGOBJECT.ZCRYPTOVERIFIER, " + 
                     "ZICCLOUDSYNCINGOBJECT.ZCRYPTOSALT, ZICCLOUDSYNCINGOBJECT.ZCRYPTOITERATIONCOUNT, " + 
                     "ZICCLOUDSYNCINGOBJECT.ZCRYPTOWRAPPEDKEY, ZICCLOUDSYNCINGOBJECT.ZISPASSWORDPROTECTED, " +
                     "ZICCLOUDSYNCINGOBJECT.ZMODIFICATIONDATE1, ZICCLOUDSYNCINGOBJECT.ZCREATIONDATE1, " +
                     "ZICCLOUDSYNCINGOBJECT.ZTITLE1, ZICCLOUDSYNCINGOBJECT.ZACCOUNT2, " +
                     "Z_11NOTES.Z_11FOLDERS, ZICCLOUDSYNCINGOBJECT.#{server_record_column}, " + 
                     "ZICCLOUDSYNCINGOBJECT.#{unapplied_encrypted_record_column}, ZICCLOUDSYNCINGOBJECT.#{server_share_column}, " + 
                     "ZICCLOUDSYNCINGOBJECT.ZISPINNED, ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER " + 
                     "FROM ZICNOTEDATA, ZICCLOUDSYNCINGOBJECT, Z_11NOTES " + 
                     "WHERE ZICNOTEDATA.ZNOTE=? AND ZICCLOUDSYNCINGOBJECT.Z_PK=ZICNOTEDATA.ZNOTE AND Z_11NOTES.Z_8NOTES=ZICNOTEDATA.ZNOTE"
      folder_field = "Z_11FOLDERS"
      account_field = "ZACCOUNT2"
    end

    # In the legecy version, everything is different
    if @version.legacy?
      query_string = "SELECT ZNOTE.Z_PK, ZNOTE.ZCREATIONDATE as ZCREATIONDATE1, " + 
                     "ZNOTE.ZMODIFICATIONDATE as ZMODIFICATIONDATE1, ZNOTE.ZTITLE as ZTITLE1, " + 
                     "ZNOTEBODY.ZCONTENT as ZDATA, ZSTORE.Z_PK as ZFOLDER, ZSTORE.ZACCOUNT, " +
                     "0 as ZISPINNED " +
                     "FROM ZNOTE, ZNOTEBODY, ZSTORE " +
                     "WHERE ZNOTE.Z_PK=? AND ZNOTEBODY.Z_PK=ZNOTE.ZBODY AND ZSTORE.Z_PK=ZNOTE.ZSTORE"
      folder_field = "ZFOLDER"
      account_field = "ZACCOUNT"
      note_id_field = "Z_PK"
    end
  
    # Uncomment these lines if we ever think there is weirdness with using the wrong fields for the right version 
    #@logger.debug("Rip Note: Query string is #{query_string}") 
    #@logger.debug("Rip Note: account field is #{account_field}")
    #@logger.debug("Rip Note: folder field is #{folder_field}")
    #@logger.debug("Rip Note: Note ID is #{note_id}")

    # Execute the query
    @database.execute(query_string, note_id) do |row|
      # Create our note
      tmp_account_id = row[account_field]
      tmp_folder_id = row[folder_field]
      @logger.debug("Rip Note: Looking up account for #{tmp_account_id}")
      @logger.debug("Rip Note: Looking up folder for #{tmp_folder_id}")
      tmp_account = get_account(tmp_account_id)
      tmp_folder = get_folder(tmp_folder_id)
      @logger.error("Rip Note: Somehow could not find account!") if !tmp_account
      @logger.error("Rip Note: Somehow could not find folder!") if !tmp_folder
      tmp_note = AppleNote.new(row["Z_PK"], 
                               row[note_id_field],
                               row["ZTITLE1"], 
                               row["ZDATA"], 
                               row[creation_date_field], 
                               row["ZMODIFICATIONDATE1"],
                               tmp_account,
                               tmp_folder)

      # Set the note's version
      tmp_note.version=(@version)
      tmp_note.notestore=(self)

      # Set the pinned status
      if row["ZISPINNED"] == 1
        tmp_note.is_pinned = true
      end

      # Set the UUID, if it exists
      if row["ZIDENTIFIER"]
        tmp_note.uuid = row["ZIDENTIFIER"]
      end

      # Set the widget snippet, if it exists
      if row["ZWIDGETSNIPPET"]
        tmp_note.widget_snippet = row["ZWIDGETSNIPPET"]
      end

      tmp_account.add_note(tmp_note) if tmp_account
      tmp_folder.add_note(tmp_note) if tmp_folder

      # Add server-side data, if relevant
      if row[server_record_column]
        tmp_note.add_cloudkit_server_record_data(row[server_record_column])
      end

      if(row[server_share_column]) 
        tmp_note.add_cloudkit_sharing_data(row[server_share_column])

        # Add any share participants to our overall list
        tmp_note.share_participants.each do |participant|
          @cloud_kit_participants[participant.record_id] = participant
        end
      end

      # If this is protected, add the cryptographic variables
      if row["ZISPASSWORDPROTECTED"] == 1

        # Set values initially from the expected columns
        crypto_iv = row["ZCRYPTOINITIALIZATIONVECTOR"]
        crypto_tag = row["ZCRYPTOTAG"]
        crypto_salt = row["ZCRYPTOSALT"]
        crypto_iterations = row["ZCRYPTOITERATIONCOUNT"]
        crypto_verifier = row["ZCRYPTOVERIFIER"]
        crypto_wrapped_key = row["ZCRYPTOWRAPPEDKEY"]

        # Try the initial set of credentials, this is cheap if they are 
        # missing, decrypt just returns false.
        tmp_note.add_cryptographic_settings(crypto_iv, 
                                            crypto_tag, 
                                            crypto_salt,
                                            crypto_iterations,
                                            crypto_verifier,
                                            crypto_wrapped_key)

        # Try each password and see if any generate a decrypt.
        found_password = tmp_note.decrypt

        # If they aren't there, we need to use the ZUNAPPLIEDENCRYPTEDRECORD

        if row[unapplied_encrypted_record_column] and !found_password
          keyed_archive = KeyedArchive.new(:data => row[unapplied_encrypted_record_column])
          unpacked_top = keyed_archive.unpacked_top()
          ns_keys = unpacked_top["root"]["ValueStore"]["RecordValues"]["NS.keys"]
          ns_values = unpacked_top["root"]["ValueStore"]["RecordValues"]["NS.objects"]
          crypto_iv = ns_values[ns_keys.index("CryptoInitializationVector")]
          crypto_tag = ns_values[ns_keys.index("CryptoTag")]
          crypto_salt = ns_values[ns_keys.index("CryptoSalt")]
          crypto_iterations = ns_values[ns_keys.index("CryptoIterationCount")]
          crypto_wrapped_key = ns_values[ns_keys.index("CryptoWrappedKey")]

          tmp_note.add_cryptographic_settings(crypto_iv, 
                                              crypto_tag, 
                                              crypto_salt,
                                              crypto_iterations,
                                              crypto_verifier,
                                              crypto_wrapped_key)

          # Try each password and see if any generate a decrypt.
          found_password = tmp_note.decrypt
        end

        if !found_password
          @logger.debug("Apple Note Store: Note #{tmp_note.note_id} could not be decrypted with our passwords.")
        end
      end
      
      # Only add the note if we have both a folder and account for it, otherwise things blow up
      if tmp_account and tmp_folder
        @notes[tmp_note.note_id] = tmp_note
        tmp_note.process_note
      else
        @logger.error("Rip Note: Skipping note #{tmp_note.note_id} due to a missing account.") if !tmp_account
        @logger.error("Rip Note: Skipping note #{tmp_note.note_id} due to a missing folder.") if !tmp_folder
        
        if !tmp_account or !tmp_folder
          @logger.error("Consider running these sqlite queries to take a look yourself, if ZDATA is NULL, that means you aren't missing anything: ")
          @logger.error("\tSELECT Z_PK, #{account_field}, #{folder_field} FROM ZICCLOUDSYNCINGOBJECT WHERE Z_PK=#{tmp_note.primary_key}")
          @logger.error("\tSELECT #{note_id_field}, ZDATA FROM ZICNOTEDATA WHERE #{note_id_field}=#{tmp_note.note_id}")
        end
        puts "Skipping Note ID #{tmp_note.note_id} due to a missing folder or account, check the debug log for more details."
      end
    end
  end

  HTML_STYLES = <<~EOS
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol";
      font-size: 13px;
    }
    h1, h2, h3 {
      margin: 0px;
    }
    .note-cards {
      display: grid;
      grid-template-columns: repeat(1, 1fr);
      grid-auto-rows: auto;
      grid-gap: 1rem;
    }
    .note-card {
      border: 2px solid black;
      border-radius: 3px;
      padding: .5rem;
    }
    .note-content {
      margin-top: 1rem;
    }
    pre {
      margin: 0px;
    }
    ul, ol, blockquote {
      padding: 0px 0px 0px 2rem;
      margin: 0px;
    }
    ul.none, ol.none {
      list-style-type: none;
    }
    ul.dashed {
      list-style-type: '- ';
    }
    blockquote.block-quote {
      border-left: 3px solid #bdbdbd;
      padding-left: 0.4rem;
    }
    .checklist {
      position: relative;
      list-style: none;
      margin-left: 0;
      padding-left: 1.2em;
    }
    .checklist li.checked:before {
      content: '☑';
      position: absolute;
      left: 0;
    }
    .checklist li.unchecked:before {
      content: '☐';
      position: absolute;
      left: 0;
    }
    .folder_list {
      position: relative;
      list-style: none;
      margin-left: 0;
      padding-left: 1.2em;
    }
    .folder_list li.folder:before {
      content: '📁';
      position: absolute;
      left: 0;
    }
    .folder_list li.note:before {
      content: '📄';
      position: absolute;
      left: 0;
    }
    table {
      border-collapse: collapse;
    }
    table td {
      border: 1px solid black;
      padding: 0.3em;
    }
  EOS

  def generate_html(use_uuid: false)
    # Bail early if we can
    if @html && @html[use_uuid]
      return @html[use_uuid]
    end

    document = Nokogiri::HTML5::Document.new
    builder = Nokogiri::HTML::Builder.new({ encoding: "utf-8" }, document) do |doc|
      doc.html {
        doc.head {
          doc.meta(charset: "utf-8")
          doc.style(HTML_STYLES)
        }

        doc.body {
          @accounts.each do |key, account|
            doc << account.generate_html(use_uuid: use_uuid)
          end

          @folders.each do |folder_id, folder|
            # Only kick out results if the folder isn't a child folder
            doc << folder.generate_html(use_uuid: use_uuid) if !folder.is_child?
          end

          doc.div(class: "note-cards") {
            @notes.each do |note_id, note|
              doc.div(class: "note-card") {
                doc << note.generate_html(use_uuid: use_uuid)
              }
            end
          }
        }
      }
    end

    @html ||= {}
    @html[use_uuid] = builder.doc
  end

  def write_individual_html(backup_dir, use_uuid: false)
    write_html_content(backup_dir.join("index.html"), "Notes") do |doc|
      @accounts.each do |key, account|
        doc << account.generate_html(individual_files: true, use_uuid: use_uuid)
      end
    end

    @folders.each do |folder_id, folder|
      folder_path = backup_dir.join(folder.to_path)
      folder_path.mkpath
      write_html_content(folder_path.join("index.html"), folder.name) do |doc|
        doc << folder.generate_html(individual_files: true, use_uuid: use_uuid)
      end
    end

    @notes.each do |note_id, note|
      note_file_name = note.title_as_filename('.html', use_uuid: use_uuid)
      note_path = if note.folder
                    backup_dir.join(note.folder.to_path, note_file_name)
                  else
                    backup_dir.join(note_file_name)
                  end
      write_html_content(note_path, note.title) do |doc|
        doc.div(class: "note-card") {
          doc << note.generate_html(individual_files: true, use_uuid: use_uuid)
        }
      end
    end
  end

  def write_html_content(path, title)
    document = Nokogiri::HTML5::Document.new
    builder = Nokogiri::HTML::Builder.new({ encoding: "utf-8" }, document) do |doc|
      doc.html {
        doc.head {
          doc.meta(charset: "utf-8")
          doc.style(HTML_STYLES)
          doc.title(title)
        }

        doc.body {
          yield doc
        }
      }
    end

    File.open(path, "wb") do |file|
      file.write(builder.doc)
    end
  end

  ##
  # This method prepares the data structure that JSON will use to generate JSON later.
  def prepare_json
    to_return = Hash.new()
    to_return[:version] = @version
    to_return[:file_path] = @file_path
    to_return[:backup_type] = @backup.type
    to_return[:html] = generate_html

    # Add in AppleNotesAccounts
    to_return[:accounts] = Hash.new()
    @accounts.each do |account_id, account|
      to_return[:accounts][account_id] = account.prepare_json
    end

    # Add in AppleCloudKitShareParticipants
    to_return[:cloudkit_participants] = Hash.new()
    @cloud_kit_participants.each do |record_id, cloudkit_participant|
      to_return[:cloudkit_participants][record_id] = cloudkit_participant.prepare_json
    end

    # Add in AppleNotesFolders
    to_return[:folders] = Hash.new()
    @folders.each do |folder_id, folder|
      to_return[:folders][folder_id] = folder.prepare_json if !folder.is_child?
    end

    # Add in AppleNotes
    to_return[:notes] = Hash.new()
    @notes.each do |note_id, note|
      to_return[:notes][note_id] = note.prepare_json
    end

    to_return
  end

end
