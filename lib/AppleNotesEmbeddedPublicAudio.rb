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

    add_possible_location(@filepath)

    # Find where on this computer that file is stored
    tmp_stored_file_result = find_valid_file_path

    if tmp_stored_file_result
      @backup_location = tmp_stored_file_result.backup_location
      @filepath = tmp_stored_file_result.filepath
      @filename = tmp_stored_file_result.filename
      
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
  end

  ##
  # This method just returns a readable String for the object. 
  # Adds to the AppleNotesEmbeddedObject.to_s by pointing to where the media is.
  def to_s
    to_s_with_data("audio")
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
    get_media_filepath_with_uuid_and_filename
  end

  ##
  # Uses database calls to fetch the actual media object's ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER +uuid+. 
  # This requires taking the ZICCLOUDSYNCINGOBJECT.ZMEDIA field on the entry with this object's +uuid+ 
  # and reading the ZICCOUDSYNCINGOBJECT.ZFILENAME of the row identified by that number 
  # in the ZICCLOUDSYNCINGOBJECT.Z_PK field.
  def get_media_filename
    get_media_filename_from_zfilename
  end

  ##
  # This method generates the HTML necessary to display the image inline.
  def generate_html(individual_files=false)
    generate_html_with_link("Audio", individual_files)
  end

end
