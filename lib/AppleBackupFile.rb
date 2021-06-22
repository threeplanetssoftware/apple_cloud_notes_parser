require 'fileutils'
require 'pathname'
require_relative 'AppleBackup.rb'
require_relative 'AppleNote.rb'
require_relative 'AppleNoteStore.rb'

##
# This class represents reading a single NoteStore.sqlite file.
# This class will abstract away figuring out how to get the right media files to embed back into an AppleNote.
class AppleBackupFile < AppleBackup

  ##
  # Creates a new AppleBackupFile. Expects a Pathname +root_folder+ that represents the root 
  # of the backup and a Pathname +output_folder+ which will hold the results of this run. 
  # Immediately sets the NoteStore database file.
  def initialize(root_folder, output_folder)
  
    super(root_folder, AppleBackup::SINGLE_FILE_BACKUP_TYPE, output_folder)

    # Check to make sure we're all good
    if self.valid?
      puts "Created a new AppleBackup from single file: #{@root_folder}"

      # Copy the database to a temporary spot to fingerprint
      copy_notes_database(@root_folder, @note_store_temporary_location)

      # Fingerprint it
      note_version = AppleNoteStore.guess_ios_version(@note_store_temporary_location)

      # Move that to the right name, based on the version
      note_store_new_location = @note_store_modern_location if note_version >= AppleNoteStore::IOS_VERSION_9
      note_store_new_location = @note_store_legacy_location if note_version == AppleNoteStore::IOS_LEGACY_VERSION

      # Rename the file to be the right database
      FileUtils.mv(@note_store_temporary_location, note_store_new_location)

      # Create the AppleNoteStore object
      @note_stores.push(AppleNoteStore.new(@note_store_modern_location, self, note_version))
    end
  end

  ##
  # This method returns true if it is a value backup of the specified type. For the SINGLE_FILE_BACKUP_TYPE this means 
  # that the +root_folder+ given is the NoteStore.sqlite directly. 
  def valid?
    return (@root_folder.file? and is_sqlite?(@root_folder))
  end

  ##
  # This method returns a Pathname that represents the location on this disk of the requested file or nil.
  # It expects a String +filename+ to look up. For single file backups, this will always be nil.
  def get_real_file_path(filename)
    return nil
  end

end
