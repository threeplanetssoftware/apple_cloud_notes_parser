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
    to_s_with_data("thumbnail")
  end

  ##
  # This method returns the +filepath+ of this object. 
  # This is computed based on the assumed default storage location.
  def get_media_filepath
    return get_media_filepath_ios16_and_earlier if @note.notestore.version < AppleNoteStore::IOS_VERSION_17
    return get_media_filepath_ios17
  end

  ##
  # This method returns the +filepath+ of this object. 
  # This is computed based on the assumed default storage location.
  def get_media_filepath_ios16_and_earlier
    return "#{@note.account.account_folder}Previews/#{@uuid}.#{get_thumbnail_extension}.encrypted" if @is_password_protected
    return "#{@note.account.account_folder}Previews/#{@uuid}.#{get_thumbnail_extension}"
  end

  ##
  # This method returns the +filepath+ of this object. 
  # This is computed based on the assumed default storage location.
  def get_media_filepath_ios17
    zgeneration = get_zgeneration_for_thumbnail
    zgeneration = "#{@uuid}/#{zgeneration}/" if zgeneration and zgeneration.length > 0

    return "#{@note.account.account_folder}Previews/#{@uuid}.png.encrypted" if @is_password_protected
    return "#{@note.account.account_folder}Previews/#{@uuid}.#{get_thumbnail_extension}" if !zgeneration
    return "#{@note.account.account_folder}Previews/#{zgeneration}#{@filename}"
  end

  ##
  # As these are created by Notes, it is just the UUID. These are either 
  # .png (apparently created by com.apple.notes.gallery) or .jpg (rest) 
  # Encrypted thumbnails just have .encrypted added to the end. 
  def get_media_filename
    return get_media_filename_ios17 if @note.notestore.version >= AppleNoteStore::IOS_VERSION_17
    return get_media_filename_ios16_and_earlier
  end

  ##
  # Prior to iOS 17, it is just the UUID. These are either 
  # .png (apparently created by com.apple.notes.gallery) or .jpg (rest) 
  # Encrypted thumbnails just have .encrypted added to the end. 
  def get_media_filename_ios16_and_earlier
    return "#{@uuid}.#{get_thumbnail_extension_ios16_and_earlier}.encrypted" if @is_password_protected
    return "#{@uuid}.#{get_thumbnail_extension_ios16_and_earlier}"
  end

  ##
  # As of iOS 17, these appear to be called Preview.png if there is a zgeneration.
  def get_media_filename_ios17
    zgeneration = get_zgeneration_for_thumbnail

    return "#{@uuid}.png.encrypted" if @is_password_protected
    return "Preview.png" if zgeneration
    return "#{@uuid}.#{get_thumbnail_extension_ios17}"
  end  

  ##
  # This method fetches the appropriate ZFALLBACKGENERATION string to compute
  # media location for iOS 17 and later.
  def get_zgeneration_for_thumbnail
    return nil if @note.notestore.version < AppleNoteStore::IOS_VERSION_17
    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZGENERATION " +
                      "FROM ZICCLOUDSYNCINGOBJECT " +
                      "WHERE ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER=?",
                      @uuid) do |row|
      return row["ZGENERATION"]
    end
  end

  ##
  # This method returns the thumbnail's extension. These are either 
  # .jpg (apparently created by com.apple.notes.gallery) or .png (rest).
  def get_thumbnail_extension
    return get_thumbnail_extension_ios17 if @note.notestore.version >= AppleNoteStore::IOS_VERSION_17
    return get_thumbnail_extension_ios16_and_earlier
  end

  ##
  # This method returns the thumbnail's extension. This is apparently png for iOS 
  # 17 and later.
  def get_thumbnail_extension_ios17
    return "jpeg" if (@parent.type == "com.apple.notes.gallery")
    return "jpeg" if (@parent.parent and @parent.parent.type == "com.apple.notes.gallery")
    return "png"
  end

  ##
  # This method returns the thumbnail's extension. These are either 
  # .jpg (apparently created by com.apple.notes.gallery) or .png (rest) for iOS 16 and earlier.
  def get_thumbnail_extension_ios16_and_earlier
    return "jpg" if (@parent.type == "com.apple.notes.gallery")
    return "jpg" if (@parent.parent and @parent.parent.type == "com.apple.notes.gallery")
    return "png"
  end

  ##
  # This method generates the HTML necessary to display the image inline.
  def generate_html(individual_files)
    if (@parent.reference_location and @reference_location)
      root = @note.folder.to_relative_root(individual_files)
      builder = Nokogiri::HTML::Builder.new(encoding: "utf-8") do |doc|
        doc.a(href: "#{root}#{@parent.reference_location}") {
          doc.img(src: "#{root}#{@reference_location}")
        }
      end

      return builder.doc.root
    end

    return "{Image missing due to not having file reference point}"
  end

  ##
  # This method prepares the data structure that will be used by JSON to generate a JSON object later.
  def prepare_json
    to_return = Hash.new()
    to_return[:primary_key] = @primary_key
    to_return[:parent_primary_key] = @parent_primary_key
    to_return[:note_id] = @note.note_id
    to_return[:uuid] = @uuid
    to_return[:type] = @type
    to_return[:filename] = @filename if (@filename != "")
    to_return[:filepath] = @filepath if (@filepath != "")
    to_return[:backup_location] = @backup_location if @backup_location
    to_return[:is_password_protected] = @is_password_protected

    to_return   
  end

end
