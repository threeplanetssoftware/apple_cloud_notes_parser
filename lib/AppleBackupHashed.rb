require 'fileutils'
require 'pathname'
require_relative 'AppleBackup.rb'
require_relative 'AppleNote.rb'
require_relative 'AppleNoteStore.rb'

##
# This class represents an Apple backup created by iTunes (i.e. hashed files with a Manifest.db). 
# This class will abstract away figuring out how to get the right media files to embed back into an AppleNote.
class AppleBackupHashed < AppleBackup

#  attr_accessor :note_stores,
#                :root_folder,
#                :type,
#                :output_folder

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
  end

end
