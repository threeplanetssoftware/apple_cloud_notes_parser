require 'digest'
require 'sqlite3'
require_relative 'AppleCloudKitShareParticipant'
require_relative 'AppleNote.rb'
require_relative 'AppleNotesAccount.rb'
require_relative 'AppleNotesFolder.rb'

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
                :cloud_kit_participants

  IOS_VERSION_15 = 15
  IOS_VERSION_14 = 14
  IOS_VERSION_13 = 13
  IOS_VERSION_12 = 12
  IOS_VERSION_11 = 11
  IOS_VERSION_10 = 10
  IOS_VERSION_9 = 9
  IOS_LEGACY_VERSION = 8
  IOS_VERSION_UNKNOWN = -1

  ##
  # Creates a new AppleNoteStore. Expects a FilePath +file_path+ to the NoteStore.sqlite
  # database itself. Uses that to create a SQLite3::Database object to query into it. Immediately 
  # creates an Array to hold the +notes+, an Array to hold the +folders+ and an Array to hold 
  # the +accounts+. Then it calls +rip_accounts+ and +rip_folders+ to populate them. Also 
  # expects an AppleBackup +backup+ object to interact with finding files of interest and an 
  # Integer +version+ to know what type it is.
  def initialize(file_path, backup, version)
    @file_path = file_path
    @backup = backup
    @database = SQLite3::Database.new(@file_path.to_s, {results_as_hash: true})
    @logger = @backup.logger
    @version = version
    @notes = Hash.new()
    @folders = Hash.new()
    @accounts = Hash.new()
    @cloud_kit_participants = Hash.new()
    puts "Guessed Notes Version: #{@version}"
    @logger.debug("Guessed Notes Version: #{@version}")
  end

  ##
  # This method does a set of database calls to try to guess the version of Apple Notes we are ripping. 
  # It tries to structure the checks to bail out as each specific version is recognized and then assume we are not it.
  # Helpful changelogs: 
  # 14 (): ??
  # 13 (https://www.apple.com/ios/ios-13/): Added checklists and shared folders, better search, and gallery 
  # 12 (https://web.archive.org/web/20190909033052/https://www.apple.com/ios/ios-12/): Nothing major 
  # 11 (https://web.archive.org/web/20180828212252/https://www.apple.com/ios/ios-11/): Added document scanner, added tables 
  # 10 (https://web.archive.org/web/20170912052423/https://www.apple.com/ios/ios-10): Added collaboration features 
  # 9 (https://web.archive.org/web/20160906075542/https://www.apple.com/ios/): Added sketches, ability to insert images inline, websites, and maps. Added iCLoud support
  # 8 (https://web.archive.org/web/20150905181128/http://www.apple.com/ios/): Added rich text support, and adding images
  def self.guess_ios_version(database_to_check)
    database_tables = get_database_tables(database_to_check)

    ziccloudsyncingobject_columns = get_database_table_columns(database_to_check, "ZICCLOUDSYNCINGOBJECT")
    zicnotedata_columns = get_database_table_columns(database_to_check, "ZICNOTEDATA")

    # If ZICNOTEDATA has no columns, this is a legacy copy
    if zicnotedata_columns.length == 0
      return IOS_LEGACY_VERSION
    end

    # It appears ZACCOUNT5 showed up in iOS 15's updates
    if ziccloudsyncingobject_columns.include?("ZACCOUNT5: INTEGER")
      return IOS_VERSION_15
    end

    # It appears ZLASTOPENEDDATE showed up in iOS 14's updates
    if ziccloudsyncingobject_columns.include?("ZLASTOPENEDDATE: TIMESTAMP")
      return IOS_VERSION_14
    end

    # It appears ZACCOUNT4 showed up in iOS 13's updates, as it is tied to shared folders
    if ziccloudsyncingobject_columns.include?("ZACCOUNT4: INTEGER")
      return IOS_VERSION_13
    end

    # ZSERVERRECORDDATA showed up in iOS 12, prior to that it was just ZSERVERRECORD
    if ziccloudsyncingobject_columns.include?("ZSERVERRECORDDATA: BLOB")
      return IOS_VERSION_12
    end

    # This table was *likely* new in iOS 11, based on the name
    if database_tables.include?("Z_11NOTES")
      return IOS_VERSION_11
    end

    # When in doubt, return unknown
    return IOS_VERSION_UNKNOWN
  end

  ##
  # This class method hashes the table names within a database to compare them. It 
  # expects a Pathname pointing to the database file.
  def self.get_database_tables(database_to_check)
    to_return = Array.new

    @database = SQLite3::Database.new(database_to_check.to_s, {results_as_hash: true})

    @database.execute("SELECT name FROM sqlite_master WHERE type='table'") do |row|
      to_return.push(row["name"])
    end

    @database.close

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

    @database = SQLite3::Database.new(database_to_check.to_s, {results_as_hash: true})

    # Need to ensure we're sorting everywhere possible to keep things in order
    @database.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name=? ORDER BY name ASC", table) do |row|
      to_return = to_return + rip_columns_from_sql(row["sql"]).sort
    end

    @database.close

    # Return back an MD5 hash of the Array, sorted and joined
    return to_return
  end

  ## 
  # This method nicely closes the database handle.
  def close
    @database.close if @database
  end

  ##
  # This method ensures that the SQLite3::Database is a valid iCloud version of Apple Notes.
  def valid_notes?
    return true if @version >= 8 # Easy out if we've already identified the version

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

    return if @version < IOS_VERSION_9 # Fail out if we're prior to the compressed data age

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
                        note.plaintext, note.decompressed_data, note.primary_key) if note.plaintext
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
      note.embedded_objects.each do |embedded_object|

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
    @folders.each do |key, folder|
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
  # This method looks up an AppleNote based on the given +note_id+. 
  # ID should be an Integer that represents the ZICNOTEDATA.ZNOTE of the note.
  def get_note(note_id)
    @notes[note_id]
  end

  ##
  # This function identifies all AppleNotesAccount potential 
  # objects in ZICCLOUDSYNCINGOBJECTS and calls +rip_account+ on each.
  def rip_accounts()
    if @version >= IOS_VERSION_9
      @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.Z_PK " +
                        "FROM ZICCLOUDSYNCINGOBJECT " + 
                        "WHERE ZICCLOUDSYNCINGOBJECT.ZNAME IS NOT NULL") do |row|
        rip_account(row["Z_PK"])
      end 
    end

    if @version == IOS_LEGACY_VERSION
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
    server_record_column = server_record_column + "DATA" if @version >= 12 # In iOS 11 this was ZSERVERRECORD, in 12 and later it became ZSERVERRECORDDATA

    # Set the ZSERVERSHARE column to look at
    server_share_column = "ZSERVERSHARE"
    server_share_column = server_share_column + "DATA" if @version >= 12 # In iOS 11 this was ZSERVERRECORD, in 12 and later it became ZSERVERRECORDDATA

    @logger.debug("Rip Account: Using server_record_column of #{server_record_column}")

    # Set the query
    query_string = "SELECT ZICCLOUDSYNCINGOBJECT.ZNAME, ZICCLOUDSYNCINGOBJECT.Z_PK, " + 
                   "ZICCLOUDSYNCINGOBJECT.#{server_record_column}, ZICCLOUDSYNCINGOBJECT.ZCRYPTOITERATIONCOUNT, " + 
                   "ZICCLOUDSYNCINGOBJECT.ZCRYPTOVERIFIER, ZICCLOUDSYNCINGOBJECT.ZCRYPTOSALT, " + 
                   "ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, ZICCLOUDSYNCINGOBJECT.#{server_share_column}, " +
                   "ZICCLOUDSYNCINGOBJECT.ZUSERRECORDNAME " +
                   "FROM ZICCLOUDSYNCINGOBJECT " + 
                   "WHERE ZICCLOUDSYNCINGOBJECT.Z_PK=?"
    
    # Change the query for legacy IOS
    if @version == IOS_LEGACY_VERSION
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

      # Add server-side data, if relevant
      tmp_account.user_record_name = row["ZUSERRECORDNAME"] if row["ZUSERRECORDNAME"]
      tmp_account.add_cloudkit_server_record_data(row[server_record_column]) if row[server_record_column]

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

      @logger.debug("Rip Account: Created account #{tmp_account.name}")

      @accounts[account_id] = tmp_account
    end 
  end

  ##
  # This function identifies all AppleNotesFolder potential 
  # objects in ZICCLOUDSYNCINGOBJECTS and calls +rip_folder+ on each.
  def rip_folders()
    if @version >= IOS_VERSION_9
      @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.Z_PK " + 
                        "FROM ZICCLOUDSYNCINGOBJECT " + 
                        "WHERE ZICCLOUDSYNCINGOBJECT.ZTITLE2 IS NOT NULL") do |row|
        rip_folder(row["Z_PK"])
      end
    end

    # In legacy Notes the "folders" were "stores"
    if @version == IOS_LEGACY_VERSION
      @database.execute("SELECT ZSTORE.Z_PK FROM ZSTORE") do |row|
        rip_folder(row["Z_PK"])
      end
    end

    @folders.each_pair do |key, folder|
      @logger.debug("Rip Folders final array: #{key} corresponds to #{folder.name}")
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
    server_record_column = server_record_column + "DATA" if @version >= 12 # In iOS 11 this was ZSERVERRECORD, in 12 and later it became ZSERVERRECORDDATA

    # Set the ZSERVERSHARE column to look at
    server_share_column = "ZSERVERSHARE"
    server_share_column = server_share_column + "DATA" if @version >= 12 # In iOS 11 this was ZSERVERRECORD, in 12 and later it became ZSERVERRECORDDATA
  
    query_string = "SELECT ZICCLOUDSYNCINGOBJECT.ZTITLE2, ZICCLOUDSYNCINGOBJECT.ZOWNER, " + 
                   "ZICCLOUDSYNCINGOBJECT.#{server_record_column}, ZICCLOUDSYNCINGOBJECT.#{server_share_column}, " +
                   "ZICCLOUDSYNCINGOBJECT.Z_PK " +
                   "FROM ZICCLOUDSYNCINGOBJECT " + 
                   "WHERE ZICCLOUDSYNCINGOBJECT.Z_PK=?"

    #Change things up for the legacy version
    if @version == IOS_LEGACY_VERSION
      query_string = "SELECT ZSTORE.Z_PK, ZSTORE.ZNAME as ZTITLE2, " +
                     "ZSTORE.ZACCOUNT as ZOWNER " + 
                     "FROM ZSTORE " +
                     "WHERE ZSTORE.Z_PK=?"
    end

    @database.execute(query_string, folder_id) do |row|
      tmp_folder = AppleNotesFolder.new(row["Z_PK"],
                                        row["ZTITLE2"],
                                        get_account(row["ZOWNER"]))

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

      @folders[folder_id] = tmp_folder
    end 
  end

  ##
  # This function identifies all AppleNote potential 
  # objects in ZICNOTEDATA and calls +rip_note+ on each.
  def rip_notes()
    if @version >= IOS_VERSION_9
      @database.execute("SELECT ZICNOTEDATA.ZNOTE FROM ZICNOTEDATA") do |row|
        self.rip_note(row["ZNOTE"])
      end
    end

    if @version == IOS_LEGACY_VERSION
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
    server_record_column = server_record_column + "DATA" if @version >= 12 # In iOS 11 this was ZSERVERRECORD, in 12 and later it became ZSERVERRECORDDATA

    # Set the ZSERVERSHARE column to look at
    server_share_column = "ZSERVERSHARE"
    server_share_column = server_share_column + "DATA" if @version >= 12 # In iOS 11 this was ZSERVERRECORD, in 12 and later it became ZSERVERRECORDDATA

    folder_field = "ZFOLDER"
    account_field = "ZACCOUNT4"
    note_id_field = "ZNOTE"
    creation_date_field = "ZCREATIONDATE1"
 
    # In version 13 and 14, what is now in ZACCOUNT4 as of iOS 15 (the account ID) was in ZACCOUNT3
    if @version < IOS_VERSION_15
      account_field = "ZACCOUNT3"
    end

    # In iOS 15 it appears ZCREATIONDATE1 moved to ZCREATIONDATE3 for notes
    if @version > IOS_VERSION_14
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
                   "ZICCLOUDSYNCINGOBJECT.#{server_record_column}, ZICCLOUDSYNCINGOBJECT.ZUNAPPLIEDENCRYPTEDRECORD, " + 
                   "ZICCLOUDSYNCINGOBJECT.#{server_share_column} " + 
                   "FROM ZICNOTEDATA, ZICCLOUDSYNCINGOBJECT " + 
                   "WHERE ZICNOTEDATA.ZNOTE=? AND ZICCLOUDSYNCINGOBJECT.Z_PK=ZICNOTEDATA.ZNOTE"

    # In version 12, what is now in ZACCOUNT3 (the account ID) was in ZACCOUNT2
    if @version == IOS_VERSION_12
      account_field = "ZACCOUNT2"
    end

    # In version 11, what is now in ZACCOUNT3 was in ZACCOUNT2 and the ZFOLDER field was in a completely separate table
    if @version == IOS_VERSION_11
      query_string = "SELECT ZICNOTEDATA.Z_PK, ZICNOTEDATA.ZNOTE, " + 
                     "ZICNOTEDATA.ZCRYPTOINITIALIZATIONVECTOR, ZICNOTEDATA.ZCRYPTOTAG, " + 
                     "ZICNOTEDATA.ZDATA, ZICCLOUDSYNCINGOBJECT.ZCRYPTOVERIFIER, " + 
                     "ZICCLOUDSYNCINGOBJECT.ZCRYPTOSALT, ZICCLOUDSYNCINGOBJECT.ZCRYPTOITERATIONCOUNT, " + 
                     "ZICCLOUDSYNCINGOBJECT.ZCRYPTOWRAPPEDKEY, ZICCLOUDSYNCINGOBJECT.ZISPASSWORDPROTECTED, " +
                     "ZICCLOUDSYNCINGOBJECT.ZMODIFICATIONDATE1, ZICCLOUDSYNCINGOBJECT.ZCREATIONDATE1, " +
                     "ZICCLOUDSYNCINGOBJECT.ZTITLE1, ZICCLOUDSYNCINGOBJECT.ZACCOUNT2, " +
                     "Z_11NOTES.Z_11FOLDERS, ZICCLOUDSYNCINGOBJECT.#{server_record_column}, " + 
                     "ZICCLOUDSYNCINGOBJECT.ZUNAPPLIEDENCRYPTEDRECORD, ZICCLOUDSYNCINGOBJECT.#{server_share_column} " + 
                     "FROM ZICNOTEDATA, ZICCLOUDSYNCINGOBJECT, Z_11NOTES " + 
                     "WHERE ZICNOTEDATA.ZNOTE=? AND ZICCLOUDSYNCINGOBJECT.Z_PK=ZICNOTEDATA.ZNOTE AND Z_11NOTES.Z_8NOTES=ZICNOTEDATA.ZNOTE"
      folder_field = "Z_11FOLDERS"
      account_field = "ZACCOUNT2"
    end

    # In the legecy version, everything is different
    if @version == IOS_LEGACY_VERSION
      query_string = "SELECT ZNOTE.Z_PK, ZNOTE.ZCREATIONDATE as ZCREATIONDATE1, " + 
                     "ZNOTE.ZMODIFICATIONDATE as ZMODIFICATIONDATE1, ZNOTE.ZTITLE as ZTITLE1, " + 
                     "ZNOTEBODY.ZCONTENT as ZDATA, ZSTORE.Z_PK as ZFOLDER, ZSTORE.ZACCOUNT " +
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
                               tmp_folder,
                               self)
      tmp_account.add_note(tmp_note) if tmp_account
      tmp_folder.add_note(tmp_note) if tmp_folder

      # Add server-side data, if relevant
      tmp_note.add_cloudkit_server_record_data(row[server_record_column]) if row[server_record_column]

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

        # If they aren't there, we need to use the ZUNAPPLIEDENCRYPTEDRECORD

        if row["ZUNAPPLIEDENCRYPTEDRECORD"]
          keyed_archive = KeyedArchive.new(:data => row["ZUNAPPLIEDENCRYPTEDRECORD"])
          unpacked_top = keyed_archive.unpacked_top()
          ns_keys = unpacked_top["root"]["ValueStore"]["RecordValues"]["NS.keys"]
          ns_values = unpacked_top["root"]["ValueStore"]["RecordValues"]["NS.objects"]
          crypto_iv = ns_values[ns_keys.index("CryptoInitializationVector")]
          crypto_tag = ns_values[ns_keys.index("CryptoTag")]
          crypto_salt = ns_values[ns_keys.index("CryptoSalt")]
          crypto_iterations = ns_values[ns_keys.index("CryptoIterationCount")]
          crypto_wrapped_key = ns_values[ns_keys.index("CryptoWrappedKey")]
        end

        tmp_note.add_cryptographic_settings(crypto_iv, 
                                            crypto_tag, 
                                            crypto_salt,
                                            crypto_iterations,
                                            crypto_verifier,
                                            crypto_wrapped_key)

        # Try each password and see if any generate a decrypt.
        found_password = tmp_note.decrypt

        if !found_password
          @logger.debug("Apple Note Store: Note #{tmp_note.note_id} could not be decrypted with our passwords.")
        end
      end
      
      # Only add the note if we have both a folder and account for it, otherwise things blow up
      if tmp_account and tmp_folder
        @notes[tmp_note.note_id] = tmp_note
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

  def generate_html
    html = "<!DOCTYPE html>\n"
    html += "<html>\n"
    html += "<head>\n"
    html += "<style>\n"
    html += ".note-cards {\n"
    html += "\tdisplay: grid;\n"
    html += "\tgrid-template-columns: repeat(1, 1fr);\n"
    html += "\tgrid-auto-rows: auto;\n"
    html += "\tgrid-gap: 1rem;\n"
    html += "}\n"
    html += ".note-card {\n"
    html += "\tborder: 2px solid black;\n"
    html += "\tborder-radius: 3px;\n"
    html += "\tpadding: .5rem;\n"
    html += "}\n"
    html += ".note-content {\n"
    html += "\twhite-space: pre-wrap;\n"
    html += "\toverflow-wrap: break-word;\n"
    html += "}\n"
    html += ".checklist {\n"
    html += "\tposition: relative;\n"
    html += "\tlist-style: none;\n"
    html += "\tmargin-left: 0;\n"
    html += "\tpadding-left: 1.2em;\n"
    html += "}\n"
    html += ".checklist li.checked:before {\n"
    html += "\tcontent: '✓';\n"
    html += "\tposition: absolute;\n"
    html += "\tleft: 0;\n"
    html += "}\n"
    html += ".checklist li.unchecked:before {\n"
    html += "\tcontent: '○';\n"
    html += "\tposition: absolute;\n"
    html += "\tleft: 0;\n"
    html += "}\n"
    html += "</style>\n"
    html += "</head>\n"
    html += "<body>\n"
    @folders.each do |folder_id, folder|
      html += folder.generate_html + "\n"
    end
  
    html += "<div class='note-cards'>\n"
    @notes.each do |note_id, note|
      html += "<div class='note-card'>\n"
      html += note.generate_html
      html += "</div> <!-- Close the 'note-card' div -->\n"
    end
    html += "</div> <!-- Close the 'note-cards' div -->\n"

    html += "</body></html>\n";

    return html
  end

end
