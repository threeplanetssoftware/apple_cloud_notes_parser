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
    @note_stores = Array.new
    @note_store_modern_location = @output_folder + "NoteStore.sqlite"
    @note_store_legacy_location = @output_folder + "notes.sqlite"
    @note_store_temporary_location = @output_folder + "test.sqlite"
  end

  ##
  # No backup on its own is valid, it must be a abckup type that is recognized. In those cases, 
  # instantiate the appropriate child (such as AppleBackupHashed).
  def valid?
    return false
  end

  ##
  # This method returns a Pathname that represents the location on this disk of the requested file or nil.
  # It expects a String +filename+ to look up. This returns nil by default, and specific types of backups
  # will override this to provide the correct location. 
  def get_real_file_path(filename)
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
