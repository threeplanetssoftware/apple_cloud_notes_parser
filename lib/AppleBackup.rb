require 'fileutils'
require 'pathname'
require_relative 'AppleNote.rb'
require_relative 'AppleNoteStore.rb'

##
# This class represents an Apple backup. It might be an iTunes backup, or a logical backup. 
# This class will abstract away figuring out how to get the right media files to embed back into an AppleNote.
class AppleBackup

  attr_accessor :note_stores,
                :root_folder,
                :type,
                :output_folder

  # For backups that are created by iTunes and hash the files
  HASHED_BACKUP_TYPE = 1
  # For actual logical representations of the disk
  LOGICAL_BACKUP_TYPE = 2
  # For times you only have one file
  SINGLE_FILE_BACKUP_TYPE = 3
  # For times you have a physical backup (i.e. /, /private, etc)
  PHYSICAL_BACKUP_TYPE = 4

  ##
  # Creates a new AppleBackup. Expects a Pathname +root_folder+ that represents the root 
  # of the backup, an Integer +type+ that represents the type of backup, and a Pathname +output_folder+ 
  # which will hold the results of this run. Backup +types+ 
  # are defined in this class. Immediately sets the NoteStore database file, based on the +type+ 
  # of backup.
  def initialize(root_folder, type, output_folder)
    @root_folder = root_folder
    @type = type
    @output_folder = output_folder
    @note_stores = Array.new
    @note_store_modern_location = @output_folder + "NoteStore.sqlite"
    @note_store_legacy_location = @output_folder + "notes.sqlite"
    @note_store_temporary_location = @output_folder + "test.sqlite"

    # Some variables that will be used by different types of backups
    @hashed_backup_manifest_database = nil
    @physical_backup_app_uuid = nil
    @physical_backup_app_folder = nil

    # Check to make sure we're all good
    if self.valid?

      # Check each type of file to handle them individually. Need to make a copy to leave the original intact
      case @type
        when HASHED_BACKUP_TYPE 
          puts "Created a new AppleBackup from iTunes backup: #{@root_folder}"

          # Copy the modern NoteStore to our output directory
          FileUtils.cp(@root_folder + "4f" + "4f98687d8ab0d6d1a371110e6b7300f6e465bef2", @note_store_modern_location)
          modern_note_version = AppleNoteStore.guess_ios_version(@note_store_modern_location)

          # Copy the legacy NoteStore to our output directory
          FileUtils.cp(@root_folder + "ca" + "ca3bc056d4da0bbf88b5fb3be254f3b7147e639c", @note_store_legacy_location)
          legacy_note_version = AppleNoteStore.guess_ios_version(@note_store_legacy_location)

          # Copy the Manifest.db to our output directry in case we want to look up files
          FileUtils.cp(@root_folder + "Manifest.db", @output_folder + "Manifest.db")

          # Create the AppleNoteStore objects
          @note_stores.push(AppleNoteStore.new(@note_store_modern_location, self, modern_note_version))
          @note_stores.push(AppleNoteStore.new(@note_store_legacy_location, self, legacy_note_version))
          @hashed_backup_manifest_database = SQLite3::Database.new((@output_folder + "Manifest.db").to_s, {results_as_hash: true})
        when SINGLE_FILE_BACKUP_TYPE
          puts "Created a new AppleBackup from single file: #{@root_folder}"

          # Copy the database to a temporary spot to fingerprint
          FileUtils.cp(@root_folder, @note_store_temporary_location)

          # Fingerprint it
          note_version = AppleNoteStore.guess_ios_version(@note_store_temporary_location)

          # Move that to the right name, based on the version
          note_store_new_location = @note_store_modern_location if note_version >= AppleNoteStore::IOS_VERSION_9
          note_store_new_location = @note_store_legacy_location if note_version == AppleNoteStore::IOS_LEGACY_VERSION
          
          # Clean up any temporary files that were created
          FileUtils.rm(@note_store_temporary_location.to_s + "-shm", :force => true)
          FileUtils.rm(@note_store_temporary_location.to_s + "-wal", :force => true)

          # Rename the file to be the right database
          FileUtils.mv(@note_store_temporary_location, note_store_new_location)

          # Create the AppleNoteStore object
          @note_stores.push(AppleNoteStore.new(@note_store_modern_location, self, note_version))
        when PHYSICAL_BACKUP_TYPE 
          puts "Created a new AppleBackup from physical backup: #{@root_folder}"
  
          # Set the app's folder for ease of reference later
          @physical_backup_app_folder = (@root_folder + "private" + "var" + "mobile" + "Containers" + "Shared" + "AppGroup" + @physical_backup_app_uuid)

          # Copy the modern NoteStore to our output directory
          FileUtils.cp(@physical_backup_app_folder + "NoteStore.sqlite", @note_store_modern_location)
          modern_note_version = AppleNoteStore.guess_ios_version(@note_store_modern_location)

          # Copy the legacy notes.sqlite to our output directory
          FileUtils.cp(@root_folder + "private" + "var" + "mobile" + "Library" + "Notes" + "notes.sqlite", @note_store_legacy_location)
          legacy_note_version = AppleNoteStore.guess_ios_version(@note_store_legacy_location)

          # Create the AppleNoteStore objects
          @note_stores.push(AppleNoteStore.new(@note_store_modern_location, self, modern_note_version))
          @note_stores.push(AppleNoteStore.new(@note_store_legacy_location, self, legacy_note_version))
      end

    end
  end

  ##
  # This method returns true if it is a value backup of the specified type. For a HASHED_BACKUP_TYPE, 
  # that means it has a Manifest.db at the root level. For the SINGLE_FILE_BACKUP_TYPE this means 
  # that the +root_folder+ given is the NoteStore.sqlite directly. For PHYSICAL_BACKUP_TYPE this means 
  # that the +root_folder+ given is where the root of the directory structure is, i.e one step above private. 
  # Of note, this might be called more than once, so side effects aren't a terribly smart decision unless it 
  # is setting variables that will be set consistently.
  def valid?
    case @type
      when nil
        return false
      when HASHED_BACKUP_TYPE
        return (@root_folder.directory? and (@root_folder + "Manifest.db").file?)
      when SINGLE_FILE_BACKUP_TYPE
        return (@root_folder.file? and is_sqlite?(@root_folder))
      when PHYSICAL_BACKUP_TYPE
        @physical_backup_app_uuid = find_physical_backup_app_uuid
        return (@physical_backup_app_uuid != nil)
    end
    return false
  end

  ##
  # This method iterates through the app UUIDs of a physical backup to 
  # identify which one contains Notes. It does it this way to ensure that all 
  # files were correctly pulled. It returns the String representing the UUID or 
  # nil if not appropriate.
  def find_physical_backup_app_uuid

    # Bail out if this doesn't look obviously right
    return nil if (!@root_folder or !@root_folder.directory? or !(@root_folder + "private" + "var" + "mobile" + "Containers" + "Shared" + "AppGroup").directory?)

    # Create a variable to return
    app_uuid = nil

    # Create a variable for simplicity
    app_folder = @root_folder + "private" + "var" + "mobile" + "Containers" + "Shared" + "AppGroup"

    # Loop over each child entry to check them for what we want
    app_folder.children.each do |child_entry|
      if child_entry.directory? and (child_entry + "NoteStore.sqlite").exist?
        app_uuid = child_entry.basename
      end
    end

    return app_uuid
  end

  ##
  # This method returns a Pathname that represents the location on this disk of the requested file or nil.
  # It expects a String +filename+ to look up. For hashed backups, that involves checking Manifest.db 
  # to get the appropriate hash value.
  def get_real_file_path(filename)
    case @type
      when HASHED_BACKUP_TYPE
        @hashed_backup_manifest_database.execute("SELECT fileID FROM Files WHERE relativePath=?", filename) do |row|
          tmp_filename = row["fileID"]
          tmp_filefolder = tmp_filename[0,2]
          return @root_folder + tmp_filefolder + tmp_filename
        end
      when PHYSICAL_BACKUP_TYPE
        return @physical_backup_app_folder + filename
    end
    return nil
  end

  ##
  # This method copies a file from the backup into the output directory. It expects 
  # a String +filepath_on_phone+ representing where it came from, a String +filename_on_phone+ 
  # representing the actual filename on the phone, and a Pathname +filepath_on_disk+ 
  # representing where on this computer the file can be found. Returns a Pathname 
  # representing the relative position of the file in the backup folder.
  def back_up_file(filepath_on_phone, filename_on_phone, filepath_on_disk)
    return if !filepath_on_disk
 
    # Turn the filepath on the phone into a Pathname object for manipulation
    phone_filepath = Pathname.new(filepath_on_phone)

    # Create the output folder of output/[datetime]/files/[filepath]/filename
    file_output_directory = @output_folder + "files" + phone_filepath.parent

    # Create a relative link for the file to reference in HTML
    file_relative_output_path = Pathname.new("files") + filepath_on_phone

    # Create the output directory
    file_output_directory.mkpath

    # Copy the file
    FileUtils.cp(filepath_on_disk, file_output_directory + filename_on_phone)

    # return where we put it 
    return file_relative_output_path
  end

  ##
  # This method takes a FilePath +file+ and checks the first 15 bytes 
  # to see if there is a SQLite magic number at the start. Not perfect, but good enough.
  def is_sqlite?(file)
    to_test = ""
    File.open(file, 'rb') do |file_handle|
      to_test = file_handle.gets(nil, 15)
    end
    return /^SQLite format 3/.match(to_test)
  end

  ##
  # This function kicks off the parsing of notes
  def rip_notes
    @note_stores.each do |note_store|
      note_store.rip_all_objects()
    end
  end

end
