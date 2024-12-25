require 'fileutils'
require 'cfpropertylist'
require 'pathname'
require_relative 'AppleBackup.rb'
require_relative 'AppleBackupHashedManifestPlist.rb'
require_relative 'AppleNote.rb'
require_relative 'AppleNoteStore.rb'

##
# This class represents an Apple backup created by iTunes (i.e. hashed files with a Manifest.db). 
# This class will abstract away figuring out how to get the right media files to embed back into an AppleNote.
class AppleBackupHashed < AppleBackup

  ##
  # Creates a new AppleBackupHashed. Expects a Pathname +root_folder+ that represents the root 
  # of the backup, a Pathname +output_folder+ which will hold the results of this run, and 
  # an AppleDecrypter +decrypter+ to assist in decrypting files. 
  # Immediately sets the NoteStore database file to be the appropriate hashed file.
  def initialize(root_folder, output_folder, decrypter=AppleDecrypter.new)

    super(root_folder, AppleBackup::HASHED_BACKUP_TYPE, output_folder, decrypter)

    @hashed_backup_manifest_database = nil

    # Check to make sure we're all good
    if self.valid?

        puts "Created a new AppleBackup from iTunes backup: #{@root_folder}"

        # Snag the manifest.plist file
        @manifest_plist = AppleBackupHashedManifestPlist.new((@root_folder + "Manifest.plist"), @decrypter, @logger)

        if (@manifest_plist.encrypted? and !@manifest_plist.can_decrypt?)
          @logger.error("Manifest Plist file cannot be decrypted, likely due to a bad password.")
          puts "Manifest PList file cannot be decrypted, have you included any passwords?"
          exit
        end

        # Define where the modern notes live
        hashed_note_store = @root_folder + "4f" + "4f98687d8ab0d6d1a371110e6b7300f6e465bef2"
        hashed_note_store_wal = @root_folder + "7d" + "7dc1d0fa6cd437c0ad9b9b573ea59c5e62373e92"
        hashed_note_store_shm = @root_folder + "55" + "55901f4cbd89916628b4ec30bf19717aca78fb2c"

        # Define where the Manifest file lives
        manifest_db = @root_folder + "Manifest.db"
        manifest_db_wal = @root_folder + "Manifest.db-wal"
        manifest_db_shm = @root_folder + "Manifest.db-shm"

        # Define where the legacy notes live
        hashed_legacy_note_store = @root_folder + "ca" + "ca3bc056d4da0bbf88b5fb3be254f3b7147e639c"
        hashed_legacy_note_store_wal = @root_folder + "12" + "12be33d156731173c5ec6ea09ab02f07a98179ed"
        hashed_legacy_note_store_shm = @root_folder + "ef" + "efaa1bfb59fcb943689733e2ca1595db52462fb9"

        # Copy the NoteStore.sqlite file
        FileUtils.cp(hashed_note_store, @note_store_modern_location)
        FileUtils.cp(hashed_note_store_wal, @output_folder + "NoteStore.sqlite-wal") if hashed_note_store_wal.exist?
        FileUtils.cp(hashed_note_store_shm, @output_folder + "NoteStore.sqlite-shm") if hashed_note_store_shm.exist?

        # Copy the legacy NoteStore to our output directory
        FileUtils.cp(hashed_legacy_note_store, @note_store_legacy_location)
        FileUtils.cp(hashed_legacy_note_store_wal, @output_folder + "notes.sqlite-wal") if hashed_legacy_note_store_wal.exist?
        FileUtils.cp(hashed_legacy_note_store_shm, @output_folder + "notes.sqlite-shm") if hashed_legacy_note_store_shm.exist?

        # Copy the Manifest.db to our output directory in case we want to look up files
        FileUtils.cp(manifest_db, @output_folder + "Manifest.db")
        FileUtils.cp(manifest_db_wal, @output_folder + "Manifest.db-wal") if manifest_db_wal.exist?
        FileUtils.cp(manifest_db_shm, @output_folder + "manifest.db-shm") if manifest_db_shm.exist?

        # Check if we have to decrypt the relevant file(s)
        if @manifest_plist.encrypted?
          @logger.debug("Detected encrypted iTunes backup. Attempting to decrypt.")

          # Snag the encrypted database into memory
          encrypted_data = ''
          File.open(@output_folder + "Manifest.db", 'rb') do |file|
            encrypted_data = file.read
          end

          # Fetch the right AppleProtectionClass from the manifest plist
          protection_class = @manifest_plist.get_class_by_id(@manifest_plist.manifest_key_class)

          # Bail out if we don't have the right key for some reason
          if !protection_class
            @logger.error("Unable to locate the appropriate protection class to decrypt the Manifest.db. Unfortunately, this is the end.")
            puts "Unable to decrypt the Manifest.db file, we cannot continue."
            exit
          end

          # Unwrap the key protecting the Manifest.db file
          manifest_key = @decrypter.aes_key_unwrap(@manifest_plist.manifest_key, protection_class.unwrapped_key)

          # Decrypt the database into memory
          decrypted_manifest = @decrypter.aes_cbc_decrypt(manifest_key, encrypted_data)

          # Write the file out to where we expect the manifest to be
          File.open(@output_folder + "Manifest.db", 'wb') do |output|
            @logger.debug("Wrote out decrypted Manifest database to #{@output_folder + "Manifest.db"}")
            output.write(decrypted_manifest)
          end

          @hashed_backup_manifest_database = SQLite3::Database.new((@output_folder + "Manifest.db").to_s, {results_as_hash: true})

          # Overwrite the other critical files
          decrypt_in_place("NoteStore.sqlite")
          decrypt_in_place("notes.sqlite")
        else
          @hashed_backup_manifest_database = SQLite3::Database.new((@output_folder + "Manifest.db").to_s, {results_as_hash: true})
        end
  
        modern_note_version = AppleNoteStore.guess_ios_version(@note_store_modern_location)
        legacy_note_version = AppleNoteStore.guess_ios_version(@note_store_legacy_location)


        # Create the AppleNoteStore objects
        create_and_add_notestore(@note_store_modern_location, modern_note_version)
        create_and_add_notestore(@note_store_legacy_location, legacy_note_version)

        # Rerun the check for an Accounts folder now that the database is open
        @uses_account_folder = check_for_accounts_folder
    end
  end

  ## 
  # This method is a helper to identify if this is an encrypted iTunes backup.
  def is_encrypted?
    return (@manifest_plist and @manifest_plist.encrypted?)
  end

  ##
  # This method returns true if it is a valid backup of the specified type. For a HASHED_BACKUP_TYPE, 
  # that means it has a Manifest.db at the root level. 
  def valid?
    return (@root_folder.directory? and (@root_folder + "Manifest.db").file?)
  end


  ##
  # This method overrides the default check_for_accounts_folder to determine 
  # if this backup uses an accounts folder or not. It takes no arguments and 
  # returns true if an accounts folder is used and false if not.
  def check_for_accounts_folder
    return true if !@hashed_backup_manifest_database

    # Check for any files that have Accounts in front of them, if so this should be true
    @hashed_backup_manifest_database.execute("SELECT fileID FROM Files WHERE relativePath LIKE 'Accounts/%' AND domain='AppDomainGroup-group.com.apple.notes' LIMIT 1") do |row|
      return true
    end

    # If we get here, there isn't an accounts folder
    return false
  end

  ##
  # This method returns a Pathname that represents the location on this disk of the requested file or nil.
  # It expects a String +filename+ to look up. For hashed backups, that involves checking Manifest.db 
  # to get the appropriate hash value.
  def get_real_file_path(filename)

    @hashed_backup_manifest_database.execute("SELECT fileID FROM Files WHERE relativePath=? AND domain='AppDomainGroup-group.com.apple.notes'", filename) do |row|
      tmp_filename = row["fileID"]
      tmp_filefolder = tmp_filename[0,2]
      return @root_folder + tmp_filefolder + tmp_filename
    end

    #@logger.debug("AppleBackupHashed: Could not find a real file path for #{filename}")
    return nil
  end

  ##
  # This method returns a binary plist object that represents the data in the Files.file column. 
  # It expects a String +filename+ to look up. For hashed backups, that involves checking Manifest.db 
  # to get the appropriate hash value.
  def get_file_plist(filename)
    @hashed_backup_manifest_database.execute("SELECT file FROM Files WHERE (relativePath=? AND domain='AppDomainGroup-group.com.apple.notes') OR (relativePath LIKE ? AND domain='HomeDomain')", filename) do |row|
      file_plist = row["file"]
      tmp_plist = CFPropertyList::List.new
      tmp_plist.load_binary_str(file_plist)
      return CFPropertyList.native_types(tmp_plist.value)
    end

    # If we get this far, consider if it is a legacy notes file, unsure if this is the best way to go about it
    filename = "Library/Notes/#{filename}"
    @hashed_backup_manifest_database.execute("SELECT file FROM Files WHERE relativePath=? AND domain='HomeDomain'", filename) do |row|
      file_plist = row["file"]
      tmp_plist = CFPropertyList::List.new
      tmp_plist.load_binary_str(file_plist)
      return CFPropertyList.native_types(tmp_plist.value)
    end

    # If we get here, we just need to give up
    return nil
  end

  ##
  # This method fetches the encryption key for a file from the file's plist in Manifest.db. 
  # It expects a CFProperty +plist+ and returns the wrapped encryption key as a binary string.
  def get_file_encryption_key(plist)
    # Find the root object ID
    tmp_root = plist["$top"]["root"]

    # Use the root object ID to find the Encryption Key index
    tmp_key_position = plist["$objects"][tmp_root]["EncryptionKey"]

    # Get the data for the encryption key, this has the protection class at the start
    tmp_wrapped_key = plist["$objects"][tmp_key_position]["NS.data"]

    # Return the key itself
    return tmp_wrapped_key[4,tmp_wrapped_key.length - 4]
  end

  ##
  # This method pulls the relevant protection class from the Manifest.db file plist
  # for an encrypted file. It expects a CFPropertyList +plist+ and returns the protection 
  # class as an Integer.
  def get_file_protection_class(plist)
    # Find the root object ID
    tmp_root = plist["$top"]["root"]

    # Use the root object ID to find the Encryption Key index
    tmp_key_position = plist["$objects"][tmp_root]["EncryptionKey"]

    # Get the data for the encryption key, this has the protection class at the start
    tmp_wrapped_key = plist["$objects"][tmp_key_position]["NS.data"]

    # Return the key itself
    return tmp_wrapped_key[0,4].reverse.unpack("N")[0]
  end

  ##
  # This method pulls the expected file size from the Manifest.db file plist
  # for an encrypted file. It expects a CFPropertyList +plist+ and returns the file size 
  # as an Integer.
  def get_file_expected_size(plist)
    # Find the root object ID
    tmp_root = plist["$top"]["root"]

    # Use the root object ID to find the Encryption Key index
    return plist["$objects"][tmp_root]["Size"]
  end

  ##
  # This method is used to decrypt an iTunes encrypted backup file in place. 
  # It expects the file to already have been copied to the output folder and to receive the
  # +filename+ as a String. It checks the filename in Manifest.db, looks up the corresponding 
  # encryption key, and uses that to decrypt the file contents, overwriting was was in output.
  def decrypt_in_place(filename, folder='')
    @logger.debug("Attempting to decrypt in place #{filename}")

    target_destination = @output_folder + folder + filename
    return if !target_destination.exist?

    # Snag the File Plist for this file from the Manifest.db file
    tmp_plist = get_file_plist(filename)
    if !tmp_plist
      @logger.error("Unable to find the file plist for #{filename}.")
      return
    end

    tmp_wrapped_key = get_file_encryption_key(tmp_plist)
    tmp_class = get_file_protection_class(tmp_plist)
    tmp_size = get_file_expected_size(tmp_plist)
 
    # Fetch the protection class from the manifest Plist to get its unwrapped key
    tmp_protection_class = @manifest_plist.get_class_by_id(tmp_class)
    tmp_unwrapped_key = @decrypter.aes_key_unwrap(tmp_wrapped_key, tmp_protection_class.unwrapped_key)

    # Actually decrypt the file itself
    decrypted_file = @decrypter.aes_cbc_decrypt(tmp_unwrapped_key, File.read(@output_folder + folder + filename))

    if !decrypted_file
      @logger.error("Failed to decrypt #{target_destination}")
      return
    end

    # Overwrite the results
    File.open(target_destination, 'wb') do |output|
      @logger.debug("Wrote out decrypted #{filename} to #{target_destination}")
      # Only write the first tmp_size bytes, don't write the padding that decrypting introduced. 
      # This ensures encrypted files can be decrypted, as they were encrypted prior to the padding 
      # being introduced. 
      output.write(decrypted_file[0, tmp_size])
    end
  end

end
