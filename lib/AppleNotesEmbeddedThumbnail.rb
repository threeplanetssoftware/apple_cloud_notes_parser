##
# This class represents the thumbnail generated for embedded pictures in an  
# in an AppleNote. 
class AppleNotesEmbeddedThumbnail < AppleNotesEmbeddedObject

  attr_accessor :primary_key,
                :uuid,
                :type,
                :height,
                :width,
                :reference_location

  ## 
  # Creates a new AppleNotesEmbeddedThumbnail object. 
  # Expects an Integer +primary_key+ from ZICCLOUDSYNCINGOBJECT.Z_PK, String +uuid+ from ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, 
  # String +uti+ from ZICCLOUDSYNCINGOBJECT.ZTYPEUTI, AppleNote +note+ object representing the parent AppleNote, and 
  # AppleBackup +backup+ from the parent AppleNote. Immediately sets the +filename+ and +filepath+ to point to were the media is stored. 
  # Finally, it attempts to copy the file to the output folder.
  def initialize(primary_key, uuid, uti, note, backup, height, width, parent)
    # Set this folder's variables
    super(primary_key, uuid, uti, note)
    @height = height
    @width = width
    @parent = parent
    @filename = get_media_filename
    @filepath = get_media_filepath
    @backup = backup

    # Find where on this computer that file is stored
    @backup_location = @backup.get_real_file_path(@filepath)
    
    # Copy the file to our output directory if we can
    @reference_location = @backup.back_up_file(@filepath, 
                                               @filename, 
                                               @backup_location, 
                                               @is_password_protected,
                                               @crypto_password,
                                               @crypto_salt,
                                               @crypto_iterations,
                                               @crypto_key,
                                               @crypto_iv,
                                               @crypto_tag)
  end

  ##
  # This method just returns a readable String for the object. 
  # Adds to the AppleNotesEmbeddedObject.to_s by pointing to where the media is.
  def to_s
    return super + " with thumbnail in #{@backup_location}" if @backup_location
    return super + " with thumbnail in #{@filepath}"
  end

  ##
  # This method returns the +filepath+ of this object. 
  # This is computed based on the assumed default storage location.
  def get_media_filepath
    "Accounts/#{@note.account.identifier}/Previews/#{@filename}"
  end

  ##
  # As these are created by Notes, it is just the UUID. These are either 
  # .png (apparently created by com.apple.notes.gallery) or .jpg (rest) 
  # Encrypted thumbnails just have .encrypted added to the end. 
  def get_media_filename
    return "#{@uuid}.#{get_thumbnail_extension}.encrypted" if @is_password_protected
    return "#{@uuid}.#{get_thumbnail_extension}"
  end


  ##
  # This method returns the thumbnail's extension. These are either 
  # .jpg (apparently created by com.apple.notes.gallery) or .png (rest).
  def get_thumbnail_extension
    return "jpg" if (@parent.type == "com.apple.notes.gallery")
    return "jpg" if (@parent.parent and @parent.parent.type == "com.apple.notes.gallery")
    return "png"
  end

  ##
  # This method generates the HTML necessary to display the image inline.
  def generate_html
    return "<a href='../#{@parent.reference_location}'><img src='../#{@reference_location}' /></a>" if @parent.reference_location
    return "{Image missing due to not having file reference point}"
  end

end
