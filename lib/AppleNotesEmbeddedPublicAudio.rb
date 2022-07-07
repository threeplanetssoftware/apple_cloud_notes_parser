require_relative 'AppleNotesEmbeddedThumbnail.rb'

##
# This class represents a public.audio object embedded
# in an AppleNote. Todo: Add the ZDURATION column to the output. 
class AppleNotesEmbeddedPublicAudio < AppleNotesEmbeddedObject

  attr_accessor :reference_location

  ## 
  # Creates a new AppleNotesEmbeddedPublicAudio object. 
  # Expects an Integer +primary_key+ from ZICCLOUDSYNCINGOBJECT.Z_PK, String +uuid+ from ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, 
  # String +uti+ from ZICCLOUDSYNCINGOBJECT.ZTYPEUTI, AppleNote +note+ object representing the parent AppleNote, 
  # AppleBackup +backup+ from the parent AppleNote, and AppleEmbeddedObject +parent+ (or nil). 
  # Immediately sets the +filename+ and +filepath+ to point to were the media is stored. 
  # Finally, it attempts to copy the file to the output folder.
  def initialize(primary_key, uuid, uti, note, backup, parent)
    # Set this object's variables

    @parent = parent # Do this first so thumbnails don't break

    super(primary_key, uuid, uti, note)

    @filename = get_media_filename
    @filepath = get_media_filepath

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
                                               @crypto_asset_iv,
                                               @crypto_asset_tag)

  end

  ##
  # This function overrides the default AppleNotesEmbeddedObject add_cryptographic_settings 
  # to use the media's settings. It also adds the ZASSETCRYPTOTAG and ZASSETCRYPTOINITIALIZATIONVECTOR 
  # fields for the content on disk. 
  def add_cryptographic_settings
    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZMEDIA " +
                      "FROM ZICCLOUDSYNCINGOBJECT " +
                      "WHERE ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER=?",
                      @uuid) do |row|
      @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZCRYPTOINITIALIZATIONVECTOR, ZICCLOUDSYNCINGOBJECT.ZCRYPTOTAG, " +
                        "ZICCLOUDSYNCINGOBJECT.ZCRYPTOSALT, ZICCLOUDSYNCINGOBJECT.ZCRYPTOITERATIONCOUNT, " + 
                        "ZICCLOUDSYNCINGOBJECT.ZCRYPTOVERIFIER, ZICCLOUDSYNCINGOBJECT.ZCRYPTOWRAPPEDKEY, " + 
                        "ZICCLOUDSYNCINGOBJECT.ZASSETCRYPTOTAG, ZICCLOUDSYNCINGOBJECT.ZASSETCRYPTOINITIALIZATIONVECTOR " + 
                        "FROM ZICCLOUDSYNCINGOBJECT " + 
                        "WHERE Z_PK=?",
                        row["ZMEDIA"]) do |media_row|
        @crypto_iv = media_row["ZCRYPTOINITIALIZATIONVECTOR"]
        @crypto_tag = media_row["ZCRYPTOTAG"]
        @crypto_asset_iv = media_row["ZASSETCRYPTOINITIALIZATIONVECTOR"]
        @crypto_asset_tag = media_row["ZASSETCRYPTOTAG"]
        @crypto_salt = media_row["ZCRYPTOSALT"]
        @crypto_iterations = media_row["ZCRYPTOITERATIONCOUNT"]
        @crypto_key = media_row["ZCRYPTOVERIFIER"] if media_row["ZCRYPTOVERIFIER"]
        @crypto_key = media_row["ZCRYPTOWRAPPEDKEY"] if media_row["ZCRYPTOWRAPPEDKEY"]
      end
    end

    @crypto_password = @note.crypto_password
  end

  ##
  # This method just returns a readable String for the object. 
  # Adds to the AppleNotesEmbeddedObject.to_s by pointing to where the media is.
  def to_s
    return super + " with media in #{@backup_location}" if @backup_location
    return super + " with media in #{@filepath}"
  end

  ##
  # Uses database calls to fetch the actual media object's ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER +uuid+. 
  # This requires taking the ZICCLOUDSYNCINGOBJECT.ZMEDIA field on the entry with this object's +uuid+ 
  # and reading the ZICCOUDSYNCINGOBJECT.ZIDENTIFIER of the row identified by that number 
  # in the ZICCLOUDSYNCINGOBJECT.Z_PK field.
  def get_media_uuid
    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZMEDIA " +
                      "FROM ZICCLOUDSYNCINGOBJECT " +
                      "WHERE ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER=?",
                      @uuid) do |row|
      @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER " +
                        "FROM ZICCLOUDSYNCINGOBJECT " +
                        "WHERE ZICCLOUDSYNCINGOBJECT.Z_PK=?",
                        row["ZMEDIA"]) do |media_row|
        return media_row["ZIDENTIFIER"]
      end
    end
  end

  ##
  # This method returns the +filepath+ of this object. 
  # This is computed based on the assumed default storage location.
  def get_media_filepath
    return "Accounts/#{@note.account.identifier}/Media/#{get_media_uuid}/#{get_media_uuid}" if @is_password_protected
    return "Accounts/#{@note.account.identifier}/Media/#{get_media_uuid}/#{@filename}"
  end

  ##
  # Uses database calls to fetch the actual media object's ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER +uuid+. 
  # This requires taking the ZICCLOUDSYNCINGOBJECT.ZMEDIA field on the entry with this object's +uuid+ 
  # and reading the ZICCOUDSYNCINGOBJECT.ZFILENAME of the row identified by that number 
  # in the ZICCLOUDSYNCINGOBJECT.Z_PK field.
  def get_media_filename
    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZMEDIA " +
                      "FROM ZICCLOUDSYNCINGOBJECT " +
                      "WHERE ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER=?",
                      @uuid) do |row|
      @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZFILENAME, " + 
                        "ZICCLOUDSYNCINGOBJECT.ZENCRYPTEDVALUESJSON, " +
                        "ZICCLOUDSYNCINGOBJECT.ZCRYPTOWRAPPEDKEY, " +
                        "ZICCLOUDSYNCINGOBJECT.ZCRYPTOINITIALIZATIONVECTOR, " +
                        "ZICCLOUDSYNCINGOBJECT.ZCRYPTOSALT, " +
                        "ZICCLOUDSYNCINGOBJECT.ZCRYPTOTAG, " +
                        "ZICCLOUDSYNCINGOBJECT.ZCRYPTOITERATIONCOUNT, " +
                        "ZICCLOUDSYNCINGOBJECT.ZUNAPPLIEDENCRYPTEDRECORD " +
                        "FROM ZICCLOUDSYNCINGOBJECT " +
                        "WHERE ZICCLOUDSYNCINGOBJECT.Z_PK=?",
                        row["ZMEDIA"]) do |media_row|

        # Initialize the return value
        filename = nil

        if @is_password_protected
          # Need to snag the values from this row's columns as they are different than the original note
          encrypted_values = media_row["ZENCRYPTEDVALUESJSON"]
          crypto_tag = media_row["ZCRYPTOTAG"]
          crypto_salt = media_row["ZCRYPTOSALT"]
          crypto_iterations = media_row["ZCRYPTOITERATIONCOUNT"]
          crypto_key = media_row["ZCRYPTOWRAPPEDKEY"]
          crypto_iv = media_row["ZCRYPTOINITIALIZATIONVECTOR"]

          if media_row["ZUNAPPLIEDENCRYPTEDRECORD"]
            keyed_archive = KeyedArchive.new(:data => media_row["ZUNAPPLIEDENCRYPTEDRECORD"])
            unpacked_top = keyed_archive.unpacked_top()
            ns_keys = unpacked_top["root"]["ValueStore"]["RecordValues"]["NS.keys"]
            ns_values = unpacked_top["root"]["ValueStore"]["RecordValues"]["NS.objects"]
            encrypted_values = ns_values[ns_keys.index("EncryptedValues")]
            crypto_iv = ns_values[ns_keys.index("CryptoInitializationVector")]
            crypto_tag = ns_values[ns_keys.index("CryptoTag")]
            crypto_salt = ns_values[ns_keys.index("CryptoSalt")]
            crypto_iterations = ns_values[ns_keys.index("CryptoIterationCount")]
            crypto_key = ns_values[ns_keys.index("CryptoWrappedKey")]
          end

          decrypt_result = @backup.decrypter.decrypt_with_password(@crypto_password,
                                                                   crypto_salt,
                                                                   crypto_iterations,
                                                                   crypto_key,
                                                                   crypto_iv,
                                                                   crypto_tag,
                                                                   encrypted_values,
                                                                   "#{self.class} #{@uuid}")
          parsed_json = JSON.parse(decrypt_result[:plaintext])
          filename = parsed_json["filename"]
        else
          filename = media_row["ZFILENAME"]
        end
        @logger.debug("#{self.class} #{@uuid}: Filename is #{filename}")
        return filename
      end
    end
  end

  ##
  # This method generates the HTML necessary to display the image inline.
  def generate_html
    return "<a href='../#{@reference_location}'>#{@filename}</a>"
  end

end
