require 'fileutils'
require 'logger'
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
                :output_folder,
                :logger,
                :decrypter,
                :retain_order,
                :range_start,
                :range_end

  # For backups that are created by iTunes and hash the files
  HASHED_BACKUP_TYPE = 1
  # For actual logical representations of the disk
  LOGICAL_BACKUP_TYPE = 2
  # For times you only have one file
  SINGLE_FILE_BACKUP_TYPE = 3
  # For times you have a physical backup (i.e. /, /private, etc)
  PHYSICAL_BACKUP_TYPE = 4
  # For times you have a copy of the Mac version of notes (i.e. /Users/{username}/Library/Group Containers/group.com.apple.notes)
  MAC_BACKUP_TYPE = 5
  
  ##
  # Creates a new AppleBackup. Expects a Pathname +root_folder+ that represents the root 
  # of the backup, an Integer +type+ that represents the type of backup, and a Pathname +output_folder+ 
  # which will hold the results of this run. Backup +types+ 
  # are defined in this class. The child classes will immediately set the NoteStore database file, based on the +type+ 
  # of backup.
  def initialize(root_folder, type, output_folder)
    @root_folder = root_folder
    @type = type
    @output_folder = output_folder
    @logger = Logger.new(@output_folder + "debug_log.txt")
    @note_stores = Array.new
    @note_store_modern_location = @output_folder + "NoteStore.sqlite"
    @note_store_legacy_location = @output_folder + "notes.sqlite"
    @note_store_temporary_location = @output_folder + "test.sqlite"
    @decrypter = AppleDecrypter.new(self)

    # Set up date ranges, if desired
    @range_start = 0
    @range_end = Time.now.to_i

    @retain_order = false
  end

  ## 
  # Explicitly sets the range start of the notestores
  def set_range_start(range_start)
    @range_start = range_start
    @note_stores.each do |notestore|
      notestore.range_start = @range_start
    end
  end

  ## 
  # Explicitly sets the range end of the notestores
  def set_range_end(range_end)
    @range_end = range_end
    @note_stores.each do |notestore|
      notestore.range_end = @range_end
    end
  end
  
  ##
  # This method handles creating and adding a new AppleNoteStore. 
  # it expects a Pathname +location+ for the location of the NoteStore.sqlite 
  # database and an Integer +version+ representing the version of the AppleNoteStore.
  def create_and_add_notestore(location, version)
    tmp_notestore = AppleNoteStore.new(location, version)
    tmp_notestore.backup=(self)
    @note_stores.push(tmp_notestore)
    @logger.debug("Guessed Notes Version: #{version.to_s}")
    puts "Guessed Notes Version: #{version.to_s}"
  end

  ##
  # No backup on its own is valid, it must be a abckup type that is recognized. In those cases, 
  # instantiate the appropriate child (such as AppleBackupHashed).
  def valid?
    @logger.error("Returning 'invalid' as no specific type of backup was specified")
    raise "AppleBackup cannot stand on its own"
    return false
  end

  ##
  # This method copies a notes database and checks for any journals that also need to be copied. 
  # It expects a Pathname +filepath+ that represents the location of a notes database
  # file and a Pathname +destination+ that represents the name the database file should end up as. 
  # It copies the database to our expected output location. It also checks for WAL and SHM files for 
  # inclusion. Note: the AppleBackupHashed class does *not* use this because the filenames aren't 
  # computed the same. 
  def copy_notes_database(filepath, destination)

    begin
      # Copy the actual NoteStore.sqlite file
      FileUtils.cp(filepath, destination)

      # Compute the paths to the WAL and SHM files
      tmp_path, tmp_name = filepath.split
      wal_filename = tmp_name.to_s + "-wal"
      shm_filename = tmp_name.to_s + "-shm"
      wal_filepath = tmp_path + wal_filename
      shm_filepath = tmp_path + shm_filename

      # Copy the WAL and SHM files if they exist
      FileUtils.cp(wal_filepath, @output_folder) if wal_filepath.exist?
      FileUtils.cp(shm_filepath, @output_folder) if shm_filepath.exist?
    rescue
      @logger.error("Failed to copy #{filepath} or its journals to #{destination}.")
    end

  end

  ##
  # This method returns a Pathname that represents the location on this disk of the requested file or nil.
  # It expects a String +filename+ to look up. This returns nil by default, and specific types of backups
  # will override this to provide the correct location. 
  def get_real_file_path(filename)
    @logger.error("Returning nil for get_real_file_path as no specific type of backup was specified")
    raise "Cannot return file_path for AppleBackup"
    return nil
  end

  ##
  # This method copies a file from the backup into the output directory. It expects 
  # a String +filepath_on_phone+ representing where it came from, a String +filename_on_phone+ 
  # representing the actual filename on the phone, and a Pathname +filepath_on_disk+ 
  # representing where on this computer the file can be found. Takes an optional boolean 
  # +is_password_protected+ and all the cryptographic settings to indicate if the file 
  # needs to be decrypted. Returns a Pathname  representing the relative position of 
  # the file in the output folder. If the file was encrypted, reads the original, decrypts 
  # and writes the decrypted content to the new file name. 
  def back_up_file(filepath_on_phone, filename_on_phone, filepath_on_disk, 
    is_password_protected=false, password=nil, salt=nil, iterations=nil, key=nil, 
    iv=nil, tag=nil, debug_text=nil)

    # Fail out if we do not have a filepath to copy and log appropriately
    if !filepath_on_disk
      @logger.error("Can't call back_up_file with filepath_on_disk that is nil") if @type != SINGLE_FILE_BACKUP_TYPE
      return
    end

    # Fail out if we do not have a filename to copy and log appropriately
    if !filename_on_phone
      @logger.error("Can't call back_up_file with filename_on_phone that is nil") if @type != SINGLE_FILE_BACKUP_TYPE
      return
    end

    # Fail out if the file simply can't be found and log appropriately
    if !File.exist?(filepath_on_disk)
      @logger.error("Can't call back_up_file with filepath_on_disk that does not exist: #{filepath_on_disk}") if @type != SINGLE_FILE_BACKUP_TYPE
      return
    end
 
    # Turn the filepath on the phone into a Pathname object for manipulation
    phone_filepath = Pathname.new(filepath_on_phone)

    # Create the output folder of output/[datetime]/files/[filepath]/filename
    file_output_directory = @output_folder + "files" + phone_filepath.parent

    # Create a relative link for the file to reference in HTML
    file_relative_output_path = Pathname.new("files") + phone_filepath.parent + filename_on_phone

    # Create the output directory
    file_output_directory.mkpath

    # Decrypt and write a new file, or copy the file depending on if we are password protected
    tmp_target_filepath = file_output_directory + filename_on_phone
    @logger.debug("Copying #{filepath_on_disk} to #{tmp_target_filepath}")
    if is_password_protected
      File.open(filepath_on_disk, 'rb') do |file|
        encrypted_data = file.read
        decrypt_result = @decrypter.decrypt_with_password(password, salt, iterations, key, iv, tag, encrypted_data, "Apple Backup encrypted file")
        File.write(file_output_directory + filename_on_phone.sub(/\.encrypted$/,""), decrypt_result[:plaintext])
      end
    else
      begin
        FileUtils.cp(filepath_on_disk, tmp_target_filepath)
      rescue
        @logger.error("Failed to copy #{filepath_on_disk} to #{tmp_target_filepath}")
      end
    end

    # return where we put it 
    return file_relative_output_path.sub(/\.encrypted$/,"")
  end

  ##
  # This method takes a FilePath +file+ and checks the first 15 bytes 
  # to see if there is a SQLite magic number at the start. Not perfect, but good enough.
  def is_sqlite?(file)
    File.open(file, 'rb') do |file_handle|
      return true if file_handle.gets(nil, 15) == "SQLite format 3"
    end

    return false
  end

  ##
  # This method takes a FilePath +file+ and checks to make sure the list of tables looks 
  # a bit like what we expect from a NoteStore.
  def has_correct_columns?(file)
    database = SQLite3::Database.new(file.to_s, {results_as_hash: true})
    results = database.execute("PRAGMA table_list;")

    legacy_columns = ['ZACCOUNT', 'ZNOTE', 'ZNOTEBODY', 'ZSTORE']
    modern_columns = ['ACHANGE', 'ZICCLOUDSYNCINGOBJECT','ZICLOCATION', 'ZICNOTEDATA']
    results.each do |result|
      legacy_columns.delete(result["name"])
      modern_columns.delete(result["name"])
    end

    # This should be an iOS 9+ database
    if modern_columns.length == 0
      return true
    end

    # This is a legacy database
    if legacy_columns.length == 0
      return true
    end

    return false
  end

  ##
  # This function kicks off the parsing of notes
  def rip_notes
    @note_stores.each do |note_store|
      note_store.retain_order = @retain_order
      @logger.debug("Apple Backup: Ripping notes from Note Store version #{note_store.version}")
      note_store.rip_all_objects()
    end
  end

end
