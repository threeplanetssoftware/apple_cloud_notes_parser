require 'fileutils'
require 'pathname'
require_relative 'AppleBackup.rb'
require_relative 'AppleNote.rb'
require_relative 'AppleNoteStore.rb'

##
# This class represents running Cloud Notes Parser on a logical backup of an Apple computer's Notes application, not the mobile version.  
# This class expects to be pointed at the root of the Notes folder, generally /Users/{username}/Library/Group Containers/group.com.apple.notes/. 
# This class will abstract away figuring out how to get the right media files to embed back into an AppleNote.
class AppleBackupMac < AppleBackup

  ##
  # Creates a new AppleBackupMac. Expects a Pathname +root_folder+ that represents the root 
  # of the physical backup and a Pathname +output_folder+ which will hold the results of this run.
  # Immediately sets the NoteStore database file to be the appropriate application's NoteStore.sqlite. 
  def initialize(root_folder, output_folder)

    super(root_folder, AppleBackup::MAC_BACKUP_TYPE, output_folder)

    # Check to make sure we're all good
    if self.valid?
      puts "Created a new AppleBackup from Mac backup: #{@root_folder}"

      # Copy the modern NoteStore to our output directory
      copy_notes_database(@root_folder + "NoteStore.sqlite", @note_store_modern_location)
      modern_note_version = AppleNoteStore.guess_ios_version(@note_store_modern_location)

      # Create the AppleNoteStore objects
      @note_stores.push(AppleNoteStore.new(@note_store_modern_location, self, modern_note_version))
    end
  end

  ##
  # This method returns true if it is a value backup of the specified type. For MAC_BACKUP_TYPE this means 
  # that the +root_folder+ given is where the root of the directory structure is and the NoteStore.sqlite 
  # file is directly underneath. 
  def valid?
    return (@root_folder.directory? and (@root_folder + "NoteStore.sqlite").file?)
  end

  ##
  # This method returns a Pathname that represents the location on this disk of the requested file or nil.
  # It expects a String +filename+ to look up. 
  def get_real_file_path(filename)
    return @root_folder + filename
  end

end
