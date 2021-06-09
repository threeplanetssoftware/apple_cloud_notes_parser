require 'fileutils'
require 'pathname'
require_relative 'AppleBackup.rb'
require_relative 'AppleNote.rb'
require_relative 'AppleNoteStore.rb'

##
# This class represents an Apple physical backup.  
# This class will abstract away figuring out how to get the right media files to embed back into an AppleNote.
class AppleBackupPhysical < AppleBackup

  ##
  # Creates a new AppleBackupPhysical. Expects a Pathname +root_folder+ that represents the root 
  # of the physical backup and a Pathname +output_folder+ which will hold the results of this run.
  # Immediately sets the NoteStore database file to be the appropriate application's NoteStore.sqlite. 
  def initialize(root_folder, output_folder)

    super(root_folder, AppleBackup::PHYSICAL_BACKUP_TYPE, output_folder)

    @physical_backup_app_folder = nil
    @physical_backup_app_uuid = find_physical_backup_app_uuid

    # Check to make sure we're all good
    if self.valid?
      puts "Created a new AppleBackup from physical backup: #{@root_folder}"

      # Set the app's folder for ease of reference later
      @physical_backup_app_folder = (@root_folder + "private" + "var" + "mobile" + "Containers" + "Shared" + "AppGroup" + @physical_backup_app_uuid)

      # Copy the modern NoteStore to our output directory
      copy_notes_database(@physical_backup_app_folder + "NoteStore.sqlite", @note_store_modern_location)
      modern_note_version = AppleNoteStore.guess_ios_version(@note_store_modern_location)

      # Copy the legacy notes.sqlite to our output directory
      copy_notes_database(@root_folder + "private" + "var" + "mobile" + "Library" + "Notes" + "notes.sqlite", @note_store_legacy_location)
      legacy_note_version = AppleNoteStore.guess_ios_version(@note_store_legacy_location)

      # Create the AppleNoteStore objects
      @note_stores.push(AppleNoteStore.new(@note_store_modern_location, self, modern_note_version))
      @note_stores.push(AppleNoteStore.new(@note_store_legacy_location, self, legacy_note_version))
    end
  end

  ##
  # This method returns true if it is a value backup of the specified type. For PHYSICAL_BACKUP_TYPE this means 
  # that the +root_folder+ given is where the root of the directory structure is, i.e one step above private. 
  def valid?
    return (@physical_backup_app_uuid != nil)
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
  # It expects a String +filename+ to look up. 
  def get_real_file_path(filename)
    return @physical_backup_app_folder + filename
  end

end
