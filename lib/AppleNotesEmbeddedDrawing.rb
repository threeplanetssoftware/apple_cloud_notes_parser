require_relative 'AppleNotesEmbeddedThumbnail.rb'

#
# This class represents a com.apple.drawing2 object embedded
# in an AppleNote. This means you drew on the screen
class AppleNotesEmbeddedDrawing < AppleNotesEmbeddedObject

  attr_accessor :primary_key,
                :uuid,
                :type,
                :reference_location

  ## 
  # Creates a new AppleNotesEmbeddedDrawing object. 
  # Expects an Integer +primary_key+ from ZICCLOUDSYNCINGOBJECT.Z_PK, String +uuid+ from ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, 
  # String +uti+ from ZICCLOUDSYNCINGOBJECT.ZTYPEUTI, AppleNote +note+ object representing the parent AppleNote, and 
  # AppleBackup +backup+ from the parent AppleNote. Immediately sets the +filename+ and +filepath+ to point to were the media is stored. 
  # Finally, it attempts to copy the file to the output folder.
  def initialize(primary_key, uuid, uti, note, backup)
    # Set this folder's variables
    super(primary_key, uuid, uti, note)
    @filename = ""
    @filepath = ""
    @backup = backup 
    @zgeneration = get_zgeneration_for_fallback_image

    compute_all_filepaths
    tmp_stored_file_result = find_valid_file_path

    if tmp_stored_file_result
      @filepath = tmp_stored_file_result.filepath
      @filename = tmp_stored_file_result.filename
      @backup_location = tmp_stored_file_result.backup_location
      @reference_location = @backup.back_up_file(@filepath, 
                                                 @filename, 
                                                 @backup_location, 
                                                 @is_password_protected,
                                                 @crypto_password,
                                                 @crypto_salt,
                                                 @crypto_iterations,
                                                 @crypto_key,
                                                 @crypto_fallback_iv,
                                                 @crypto_fallback_tag)
    end  
  end

  ##
  # This function overrides the default AppleNotesEmbeddedObject add_cryptographic_settings 
  # to include the fallback image settings from ZFALLBACKIMAGECRYPTOTAG and 
  # ZFALLBACKIMAGECRYPTOINITIALIZATIONVECTOR for content on disk. 
  def add_cryptographic_settings
    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZCRYPTOINITIALIZATIONVECTOR, ZICCLOUDSYNCINGOBJECT.ZCRYPTOTAG, " +
                      "ZICCLOUDSYNCINGOBJECT.ZCRYPTOSALT, ZICCLOUDSYNCINGOBJECT.ZCRYPTOITERATIONCOUNT, " + 
                      "ZICCLOUDSYNCINGOBJECT.ZCRYPTOVERIFIER, ZICCLOUDSYNCINGOBJECT.ZCRYPTOWRAPPEDKEY, " + 
                      "ZICCLOUDSYNCINGOBJECT.ZFALLBACKIMAGECRYPTOTAG, ZICCLOUDSYNCINGOBJECT.ZFALLBACKIMAGECRYPTOINITIALIZATIONVECTOR " + 
                      "FROM ZICCLOUDSYNCINGOBJECT " + 
                      "WHERE Z_PK=?",
                      @primary_key) do |media_row|
      @crypto_iv = media_row["ZCRYPTOINITIALIZATIONVECTOR"]
      @crypto_tag = media_row["ZCRYPTOTAG"]
      @crypto_fallback_iv = media_row["ZFALLBACKIMAGECRYPTOINITIALIZATIONVECTOR"]
      @crypto_fallback_tag = media_row["ZFALLBACKIMAGECRYPTOTAG"]
      @crypto_salt = media_row["ZCRYPTOSALT"]
      @crypto_iterations = media_row["ZCRYPTOITERATIONCOUNT"]
      @crypto_key = media_row["ZCRYPTOVERIFIER"] if media_row["ZCRYPTOVERIFIER"]
      @crypto_key = media_row["ZCRYPTOWRAPPEDKEY"] if media_row["ZCRYPTOWRAPPEDKEY"]
    end

    @crypto_password = @note.crypto_password
  end

  ##
  # This method just returns a readable String for the object. 
  # Adds to the AppleNotesEmbeddedObject.to_s by pointing to where the media is.
  def to_s
    to_s_with_data("drawing")
  end

  ##
  # Uses database calls to fetch the actual media object's ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER +uuid+. 
  # This requires taking the ZICCLOUDSYNCINGOBJECT.ZMEDIA field on the entry with this object's +uuid+ 
  # and reading the ZICCOUDSYNCINGOBJECT.ZIDENTIFIER of the row identified by that number 
  # in the ZICCLOUDSYNCINGOBJECT.Z_PK field.
  def get_media_uuid
    return get_media_uuid_from_zidentifer(@uuid)
  end

  ##
  # This method fetches the appropriate ZFALLBACKGENERATION string to compute
  # media location for iOS 17 and later.
  def get_zgeneration_for_fallback_image
    return "" if @note.notestore.version < AppleNoteStoreVersion::IOS_VERSION_17

    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZFALLBACKIMAGEGENERATION " +
                      "FROM ZICCLOUDSYNCINGOBJECT " +
                      "WHERE ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER=?",
                      @uuid) do |row|
      return row["ZFALLBACKIMAGEGENERATION"]
    end
  end

  ##
  # This method computes the various filename permutations seen in iOS. 
  def compute_all_filepaths

    # Set up account folder location, default to no where
    tmp_account_string = "[Unknown Account]/FallbackImages/"
    tmp_account_string = "#{@note.account.account_folder}FallbackImages/" if @note # Update to somewhere if we know where

    ["jpeg","png", "jpg"].each do |extension| 
      add_possible_location("#{tmp_account_string}#{@uuid}.#{extension}.encrypted") if @is_password_protected
      add_possible_location("#{tmp_account_string}#{@uuid}.#{extension}") if !@is_password_protected
      add_possible_location("#{tmp_account_string}#{@uuid}/#{@zgeneration}/FallbackImage.#{extension}.encrypted") if @is_password_protected
      add_possible_location("#{tmp_account_string}#{@uuid}/#{@zgeneration}/FallbackImage.#{extension}") if !@is_password_protected
    end
  end

  ##
  # This method generates the HTML necessary to display the image inline.
  def generate_html(individual_files=false)
    generate_html_with_images(individual_files)
  end

end
