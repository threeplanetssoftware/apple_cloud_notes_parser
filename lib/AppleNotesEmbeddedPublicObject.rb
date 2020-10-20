##
# This class represents an object that is derived from public.data in https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/UTIRef/Articles/System-DeclaredUniformTypeIdentifiers.html#//apple_ref/doc/uid/TP40009259-SW1 
# embedded in an AppleNote. This has a host of types of data under it, 
# some of which will be handled by specific classes, such as URLs. 
class AppleNotesEmbeddedPublicObject < AppleNotesEmbeddedObject

  attr_accessor :primary_key,
                :uuid,
                :type,
                :filepath,
                :filename,
                :reference_location

  ## 
  # Creates a new AppleNotesEmbeddedPublicObject object. 
  # Expects an Integer +primary_key+ from ZICCLOUDSYNCINGOBJECT.Z_PK, String +uuid+ from ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, 
  # String +uti+ from ZICCLOUDSYNCINGOBJECT.ZTYPEUTI, AppleNote +note+ object representing the parent AppleNote, and 
  # AppleBackup +backup+ from the parent AppleNote. Immediately sets the +filename+ and +filepath+ to point to were the object is stored. 
  # Finally, it attempts to copy the file to the output folder.
  def initialize(primary_key, uuid, uti, note, backup)
    # Set this folder's variables
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
                                               @crypto_asset_iv,
                                               @crypto_asset_tag)
  end

  ##
  # This method just returns a readable String for the object. 
  # Adds to the AppleNotesEmbeddedObject.to_s by pointing to where the media is.
  def to_s
    return super + " with object saved in #{@backup_location}" if @backup_location
    return super + " with object saved in #{@filepath}"
  end
  ##
  # This method returns the +filepath+ of this object. 
  # This is computed based on the assumed default storage location.
  def get_media_filepath
    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZMEDIA " +
                      "FROM ZICCLOUDSYNCINGOBJECT " +
                      "WHERE ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER=?",
                      @uuid) do |row|
      @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZFILENAME, ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER " +
                        "FROM ZICCLOUDSYNCINGOBJECT " +
                        "WHERE ZICCLOUDSYNCINGOBJECT.Z_PK=?",
                        row["ZMEDIA"]) do |media_row|
        return "Accounts/#{@note.account.identifier}/Media/#{media_row["ZIDENTIFIER"]}/#{media_row["ZFILENAME"]}"
      end
    end
  end

  ##
  # This method returns the +filename+ of this object. 
  # This requires looking up the referenced ZICCLOUDSYNCINGOBJECT in the row 
  # identified by +uuid+. After that, the ZICCLOUDSYNCINGOBJECT.ZFILENAME 
  # field holds the answer.
  def get_media_filename
    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZMEDIA " +
                      "FROM ZICCLOUDSYNCINGOBJECT " +
                      "WHERE ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER=?",
                      @uuid) do |row|
      @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZFILENAME " +
                        "FROM ZICCLOUDSYNCINGOBJECT " +
                        "WHERE ZICCLOUDSYNCINGOBJECT.Z_PK=?",
                        row["ZMEDIA"]) do |media_row|
        return media_row["ZFILENAME"]
      end
    end
  end

  ##
  # This method generates the HTML necessary to display the image inline.
  def generate_html
    return "<a href='../#{@reference_location}'>#{@filename}</a>" if @reference_location
    "{File missing due to not having file reference point: #{@uuid}}"
  end

end
