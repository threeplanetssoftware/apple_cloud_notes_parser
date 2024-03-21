require_relative 'AppleNotesEmbeddedThumbnail.rb'

#
# This class represents a com.apple.paper.scan.doc object embedded
# in an AppleNote. This comes from scanning a paper and then editing
# the scan.
class AppleNotesEmbeddedPaperDocScan < AppleNotesEmbeddedObject

  attr_accessor :primary_key,
                :uuid,
                :type,
                :reference_location

  ## 
  # Creates a new AppleNotesEmbeddedPaperDocScan object. 
  # Expects an Integer +primary_key+ from ZICCLOUDSYNCINGOBJECT.Z_PK, String +uuid+ from ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, 
  # String +uti+ from ZICCLOUDSYNCINGOBJECT.ZTYPEUTI, AppleNote +note+ object representing the parent AppleNote, and 
  # AppleBackup +backup+ from the parent AppleNote. Immediately sets the +filename+ and +filepath+ to point to were the media is stored. 
  # Finally, it attempts to copy the file to the output folder.
  def initialize(primary_key, uuid, uti, note, backup)
    # Set this objects's variables
    super(primary_key, uuid, uti, note)
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
                                               @crypto_fallback_iv,
                                               @crypto_fallback_tag)
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
    to_s_with_data("scan")
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
  def get_zgeneration_for_fallback_pdf
    return "" if @note.notestore.version < AppleNoteStoreVersion::IOS_VERSION_17

    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZFALLBACKPDFGENERATION " +
                      "FROM ZICCLOUDSYNCINGOBJECT " +
                      "WHERE ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER=?",
                      @uuid) do |row|
      return row["ZFALLBACKPDFGENERATION"]
    end
  end

  ##
  # This method returns the +filepath+ of this object. 
  # This is computed based on the assumed default storage location.
  def get_media_filepath
    zgeneration = get_zgeneration_for_fallback_pdf
    zgeneration = "#{@uuid}/#{zgeneration}/" if (zgeneration and zgeneration.length > 0)

    return "#{@note.account.account_folder}FallbackPDFs/#{zgeneration}#{@filename}"
  end

  ##
  # Determine filename based on iOS version
  def get_media_filename
    return get_media_filename_ios17 if @note.notestore.version >= AppleNoteStoreVersion::IOS_VERSION_17
    return get_media_filename_ios16_and_prior
  end

  ##
  # Unsure how this will look on legacy devices, assuming it will be the same?
  def get_media_filename_ios16_and_prior
    return "FallbackPDF.pdf.encrypted" if @is_password_protected
    return "FallbackPDF.pdf"
  end

  ##
  # Starting with iOS 17 this is created as a PNG using the "FallbackImage.png" as the filename.
  def get_media_filename_ios17
    return "FallbackPDF.pdf.encrypted" if @is_password_protected
    return "FallbackPDF.pdf"
  end

  ##
  # This method generates the HTML necessary to display the image inline.
  def generate_html(individual_files=false)
    generate_html_with_images(individual_files)
  end

end
