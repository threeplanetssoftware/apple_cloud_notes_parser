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
    @filename = ""
    @filepath = ""
    @backup = backup 
    @zgeneration = get_zgeneration_for_thumbnail

    # Find where on this computer that file is stored
    back_up_file if @backup 
  end

  ##
  # This method handles setting the relevant +@backup_location+ variable
  # and then backing up the file, if it exists.
  def back_up_file
    return if !@backup 

    compute_all_filepaths
    tmp_stored_file_result = find_valid_file_path

    if tmp_stored_file_result
      @logger.debug("Embedded Thumbnail #{@uuid}: \n\tExpected Filepath: '#{@filepath}' (length: #{@filepath.length}), \n\tExpected location: '#{@backup_location}'")
      @filepath = tmp_stored_file_result.filepath
      @filename = tmp_stored_file_result.filename
      @backup_location = tmp_stored_file_result.backup_location

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
  end

  ##
  # This method sets the thumbnail's Note object. It expects an AppleNote +note+
  # and immediately calls AppleNotesEmbeddedObjects note= function before firing 
  # the thumbnail's get_zgeneration_for_thumbnail.
  def note=(note)
    super(note)
    @zgeneration = get_zgeneration_for_thumbnail
    back_up_file
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
    return get_media_filepath_ios16_and_earlier if @version < AppleNoteStoreVersion::IOS_VERSION_17
    return get_media_filepath_ios17
  end

  ##
  # This method returns the +filepath+ of this object. 
  # This is computed based on the assumed default storage location.
  # Examples of valid iOS 16 paths:
  # Accounts/{account_uuid}/Previews/{parent_uuid}-1-192x144-0.png
  # Accounts/{account_uuid}/Previews/{parent_uuid}-1-768x768-0.png.encrypted
  # Accounts/{account_uuid}/Previews/{parent_uuid}-1-216x384-0-oriented.png
  # Accounts/{account_uuid}/Previews/{parent_uuid}-1-144x192-0.jpg
  # Accounts/{account_uuid}/Previews/{parent_uuid}-1-288x384-0.jpg.encrypted
  def get_media_filepath_ios16_and_earlier
    return "[Unknown Account]/Previews/#{@filename}" if !@note
    return "#{@note.account.account_folder}Previews/#{@filename}"
  end

  ##
  # This method returns the +filepath+ of this object. 
  # This is computed based on the assumed default storage location.
  # Examples of valid iOS 17 paths:
  # Accounts/{account_uuid}/Previews/{parent_uuid}-1-272x384-0.png
  # Accounts/{account_uuid}/Previews/{parent_uuid}-1-768x768-0.png.encrypted
  # Accounts/{account_uuid}/Previews/{parent_uuid}-1-192x144-0/{zgeneration}/Preview.png
  # Accounts/{account_uuid}/Previews/{parent_uuid}-1-2384x3360-0/{zgeneration}/OrientedPreview.jpeg
  def get_media_filepath_ios17
    zgeneration_string = ""
    zgeneration_string = "#{@uuid}/#{@zgeneration}/" if (@zgeneration and @zgeneration.length > 0)

    return "[Unknown Account]/Previews/#{@filename}" if !@note
    return "#{@note.account.account_folder}Previews/#{zgeneration_string}#{@filename}"
  end

  ##
  # This method computes the various filename permutations seen in iOS. 
  def compute_all_filepaths

    # Set up account folder location, default to no where
    tmp_account_string = "[Unknown Account]/Previews/"
    tmp_account_string = "#{@note.account.account_folder}Previews/" if @note # Update to somewhere if we know where

    ["jpg","png", "jpeg"].each do |extension| 
      add_possible_location("#{tmp_account_string}#{@uuid}.#{extension}.encrypted") if @is_password_protected
      add_possible_location("#{tmp_account_string}#{@uuid}/#{@zgeneration}/OrientedPreview.#{extension}") if (!@is_password_protected and @zgeneration)
      add_possible_location("#{tmp_account_string}#{@uuid}/#{@zgeneration}/Preview.#{extension}") if (!@is_password_protected and @zgeneration)
      add_possible_location("#{tmp_account_string}#{@uuid}.#{extension}") if !@is_password_protected
      add_possible_location("#{tmp_account_string}#{@uuid}-oriented.#{extension}") if !@is_password_protected
    end
  end

  ##
  # As these are created by Notes, it is just the UUID. These are either 
  # .png (apparently created by com.apple.notes.gallery) or .jpeg/.jpg (rest) 
  # Encrypted thumbnails just have .encrypted added to the end. 
  def get_media_filename
    return get_media_filename_ios16_and_earlier if @version < AppleNoteStoreVersion::IOS_VERSION_17
    return get_media_filename_ios17
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
  # Examples of valid paths:
  # Accounts/{account_uuid}/Previews/{parent_uuid}-1-768x768-0.png.encrypted
  # Accounts/{account_uuid}/Previews/{parent_uuid}-1-2384x3360-0/{zgeneration}/OrientedPreview.jpeg
  # Accounts/{account_uuid}/Previews/{parent_uuid}-1-192x144-0/{zgeneration}/Preview.png
  # Accounts/{account_uuid}/Previews/{parent_uuid}-1-272x384-0.png
  def get_media_filename_ios17
    #zgeneration = get_zgeneration_for_thumbnail

    #return "#{@uuid}.png.encrypted" if @is_password_protected
    return "#{@uuid}.#{get_thumbnail_extension_ios17}.encrypted" if @is_password_protected
    return "Preview.#{get_thumbnail_extension_ios17}" if @zgeneration
    return "#{@uuid}.#{get_thumbnail_extension_ios17}"
  end  

  ##
  # This method fetches the appropriate ZFALLBACKGENERATION string to compute
  # media location for iOS 17 and later.
  def get_zgeneration_for_thumbnail
    return nil if @version < AppleNoteStoreVersion::IOS_VERSION_17 or !@database
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
    return get_thumbnail_extension_ios16_and_earlier if @version < AppleNoteStoreVersion::IOS_VERSION_17
    return get_thumbnail_extension_ios17
  end

  ##
  # This method returns the thumbnail's extension. This is apparently png for iOS 
  # 17 and later and jpeg for Galleries.
  def get_thumbnail_extension_ios17
    return "jpeg" if (@parent and @parent.type == "com.apple.notes.gallery")
    return "jpeg" if (@parent and @parent.parent and @parent.parent.type == "com.apple.notes.gallery")
    return "png"
  end

  ##
  # This method returns the thumbnail's extension. These are either 
  # .jpg (apparently created by com.apple.notes.gallery) or .png (rest) for iOS 16 and earlier.
  def get_thumbnail_extension_ios16_and_earlier
    return "jpg" if (@parent and @parent.type == "com.apple.notes.gallery")
    return "jpg" if (@parent and @parent.parent and @parent.parent.type == "com.apple.notes.gallery")
    return "png"
  end

  ##
  # This method generates the HTML necessary to display the image inline.
  def generate_html(individual_files)
    if (@parent and @reference_location)

      # We default to the thumbnail's location to link to...
      href_target = @reference_location 
      # ...but if possible, we use the parent's location to get the real file
      href_target = @parent.reference_location if @parent.reference_location 

      root = @note.folder.to_relative_root(individual_files)
      builder = Nokogiri::HTML::Builder.new(encoding: "utf-8") do |doc|
        doc.a(href: "#{root}#{href_target}") {
          doc.img(src: "#{root}#{@reference_location}")
        }.attr("data-apple-notes-zidentifier" => "#{@parent.uuid}")
      end
      return builder.doc.root
    end

    return "{Thumbnail missing due to not having file reference point}"
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
