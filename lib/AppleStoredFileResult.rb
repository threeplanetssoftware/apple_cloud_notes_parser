##
# This class is a helper to represent the filepaths on the phone and on disk for 
# files that have been backed up. 
class AppleStoredFileResult

  attr_accessor :original_filepath,
                :original_filename,
                :storage_filepath

  ##
  # Creates a new AppleStoredFileResilt. 
  # Requires nothing and initiailizes some variables
  def initialize()
    original_filepath = nil # The filepath, as it was originally stored on the phone or Mac
    original_filename = nil # The filename, as it was originally stored on the phone or Mac
    storage_filepath = nil  # The filepath of the file on disk in the backup
  end

  ##
  # Helper function that returns true only if this has 
  # the paths needed for success
  def has_paths?
    return (original_filepath and original_filename and storage_filepath)
  end

  ##
  # Helper function that returns true only if the original filepath exists
  def exist?
    return storage_filepath.exist?
  end

  ##
  # Because of the common typoe
  def exists?
    return self.exist?
  end

  ##
  # To make it in line with legacy calls to variable names
  def backup_location
    return storage_filepath
  end

  ##
  # To make it in line with legacy calls to variable names
  def filepath
    return original_filepath
  end

  ##
  # To make it in line with legacy calls to variable names
  def filename
    return original_filename
  end

end
