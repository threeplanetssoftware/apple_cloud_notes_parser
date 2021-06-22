require 'fileutils'
require 'pathname'
require_relative 'AppleBackup.rb'
require_relative 'AppleNote.rb'
require_relative 'AppleNoteStore.rb'

##
# This class represents an Apple backup created by iTunes (i.e. hashed files with a Manifest.db). 
# This class will abstract away figuring out how to get the right media files to embed back into an AppleNote.
class AppleBackupHashed < AppleBackup

  ##
  # Creates a new AppleBackupHashed. Expects a Pathname +root_folder+ that represents the root 
  # of the backup and a Pathname +output_folder+ which will hold the results of this run. 
  # Immediately sets the NoteStore database file to be the appropriate hashed file.
  def initialize(root_folder, output_folder)

    super(root_folder, AppleBackup::HASHED_BACKUP_TYPE, output_folder)

    @hashed_backup_manifest_database = nil

    # Check to make sure we're all good
    if self.valid?
        puts "Created a new AppleBackup from iTunes backup: #{@root_folder}"

        # Copy the modern NoteStore to our output directory
        hashed_note_store = @root_folder + "4f" + "4f98687d8ab0d6d1a371110e6b7300f6e465bef2"
        hashed_note_store_wal = @root_folder + "7d" + "7dc1d0fa6cd437c0ad9b9b573ea59c5e62373e92"
        hashed_note_store_shm = @root_folder + "55" + "55901f4cbd89916628b4ec30bf19717aca78fb2c"

        FileUtils.cp(hashed_note_store, @note_store_modern_location)
        FileUtils.cp(hashed_note_store_wal, @output_folder + "NoteStore.sqlite-wal") if hashed_note_store_wal.exist?
        FileUtils.cp(hashed_note_store_shm, @output_folder + "NoteStore.sqlite-shm") if hashed_note_store_shm.exist?
        modern_note_version = AppleNoteStore.guess_ios_version(@note_store_modern_location)

        # Copy the legacy NoteStore to our output directory
        hashed_legacy_note_store = @root_folder + "ca" + "ca3bc056d4da0bbf88b5fb3be254f3b7147e639c"
        hashed_legacy_note_store_wal = @root_folder + "12" + "12be33d156731173c5ec6ea09ab02f07a98179ed"
        hashed_legacy_note_store_shm = @root_folder + "ef" + "efaa1bfb59fcb943689733e2ca1595db52462fb9"

        FileUtils.cp(hashed_legacy_note_store, @note_store_legacy_location)
        FileUtils.cp(hashed_legacy_note_store_wal, @output_folder + "notes.sqlite-wal") if hashed_legacy_note_store_wal.exist?
        FileUtils.cp(hashed_legacy_note_store_shm, @output_folder + "notes.sqlite-shm") if hashed_legacy_note_store_shm.exist?
        legacy_note_version = AppleNoteStore.guess_ios_version(@note_store_legacy_location)

        # Copy the Manifest.db to our output directry in case we want to look up files
        manifest_db = @root_folder + "Manifest.db"
        manifest_db_wal = @root_folder + "Manifest.db-wal"
        manifest_db_shm = @root_folder + "Manifest.db-shm"
        FileUtils.cp(manifest_db, @output_folder)
        FileUtils.cp(manifest_db_wal, @output_folder) if manifest_db_wal.exist?
        FileUtils.cp(manifest_db_shm, @output_folder) if manifest_db_shm.exist?

        # Create the AppleNoteStore objects
        @note_stores.push(AppleNoteStore.new(@note_store_modern_location, self, modern_note_version))
        @note_stores.push(AppleNoteStore.new(@note_store_legacy_location, self, legacy_note_version))
        @hashed_backup_manifest_database = SQLite3::Database.new((@output_folder + "Manifest.db").to_s, {results_as_hash: true})
    end
  end

  ##
  # This method returns true if it is a valid backup of the specified type. For a HASHED_BACKUP_TYPE, 
  # that means it has a Manifest.db at the root level. 
  def valid?
    return (@root_folder.directory? and (@root_folder + "Manifest.db").file?)
  end

  ##
  # This method returns a Pathname that represents the location on this disk of the requested file or nil.
  # It expects a String +filename+ to look up. For hashed backups, that involves checking Manifest.db 
  # to get the appropriate hash value.
  def get_real_file_path(filename)

    @hashed_backup_manifest_database.execute("SELECT fileID FROM Files WHERE relativePath=?", filename) do |row|
      tmp_filename = row["fileID"]
      tmp_filefolder = tmp_filename[0,2]
      return @root_folder + tmp_filefolder + tmp_filename
    end

    # If we didn't find the file the first time, it might be bug #24 (https://github.com/threeplanetssoftware/apple_cloud_notes_parser/issues/24).
    # Let's check without the Account in front, if it exists, being slightly more careful with the domain
    filename.gsub!(/^Accounts\/.{36}\//,"")
    @hashed_backup_manifest_database.execute("SELECT fileID FROM Files WHERE relativePath=? AND domain='AppDomainGroup-group.com.apple.notes'", filename) do |row|
      tmp_filename = row["fileID"]
      tmp_filefolder = tmp_filename[0,2]
      @logger.debug("Found a filepath that lacked the account portion: #{tmp_filename}")
      return @root_folder + tmp_filefolder + tmp_filename
    end

  end

end
