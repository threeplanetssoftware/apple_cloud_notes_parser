require 'keyed_archive'
require 'sqlite3'
require_relative 'AppleCloudKitRecord'

##
# This class represents an object embedded in an AppleNote.
class AppleNotesEmbeddedObject < AppleCloudKitRecord

  attr_accessor :primary_key,
                :uuid,
                :type,
                :filepath,
                :filename,
                :backup_location,
                :parent

  ##
  # Creates a new AppleNotesEmbeddedObject. 
  # Expects an Integer +primary_key+ from ZICCLOUDSYNCINGOBJECT.Z_PK, String +uuid+ from ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, 
  # String +uti+ from ZICCLOUDSYNCINGOBJECT.ZTYPEUIT, and AppleNote +note+ object representing the parent AppleNote.
  def initialize(primary_key, uuid, uti, note)
    # Set this object's variables
    @primary_key = primary_key
    @uuid = uuid
    @type = uti
    @note = note
    @is_password_protected = @note.is_password_protected
    @backup = @note.backup
    @database = @note.database
    @logger = @backup.logger
    @filepath = ""
    @filename = ""
    @backup_location = nil

    # Zero out cryptographic settings
    @crypto_iv = nil
    @crypto_tag = nil
    @crypto_key = nil
    @crypto_salt = nil
    @crypto_iterations = nil
    @crypto_password = nil

    if @is_password_protected
      add_cryptographic_settings
    end

    @logger.debug("Note #{@note.note_id}: Created a new Embedded Object of type #{@type}")
  
    # Create an Array to hold Thumbnails and add them
    @thumbnails = Array.new
    search_and_add_thumbnails

    # Create an Array to hold child objects, such as for a gallery
    @child_objects = Array.new
  end

  ##
  # This function adds cryptographic settings to the AppleNoteEmbeddedObject. 
  def add_cryptographic_settings
    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZCRYPTOINITIALIZATIONVECTOR, ZICCLOUDSYNCINGOBJECT.ZCRYPTOTAG, " +
                      "ZICCLOUDSYNCINGOBJECT.ZCRYPTOSALT, ZICCLOUDSYNCINGOBJECT.ZCRYPTOITERATIONCOUNT, " + 
                      "ZICCLOUDSYNCINGOBJECT.ZCRYPTOVERIFIER, ZICCLOUDSYNCINGOBJECT.ZCRYPTOWRAPPEDKEY, " + 
                      "ZICCLOUDSYNCINGOBJECT.ZUNAPPLIEDENCRYPTEDRECORD " + 
                      "FROM ZICCLOUDSYNCINGOBJECT " + 
                      "WHERE Z_PK=?",
                      @primary_key) do |row|

      # If there is a blob in ZUNAPPLIEDENCRYPTEDRECORD, we need to use it instead of the database values
      if row["ZUNAPPLIEDENCRYPTEDRECORD"]
        keyed_archive = KeyedArchive.new(:data => row["ZUNAPPLIEDENCRYPTEDRECORD"])
        unpacked_top = keyed_archive.unpacked_top()
        ns_keys = unpacked_top["root"]["ValueStore"]["RecordValues"]["NS.keys"]
        ns_values = unpacked_top["root"]["ValueStore"]["RecordValues"]["NS.objects"]
        @crypto_iv = ns_values[ns_keys.index("CryptoInitializationVector")]
        @crypto_tag = ns_values[ns_keys.index("CryptoTag")]
        @crypto_salt = ns_values[ns_keys.index("CryptoSalt")]
        @crypto_iterations = ns_values[ns_keys.index("CryptoIterationCount")]
        @crypto_key = ns_values[ns_keys.index("CryptoWrappedKey")]
      else 
        @crypto_iv = row["ZCRYPTOINITIALIZATIONVECTOR"]
        @crypto_tag = row["ZCRYPTOTAG"]
        @crypto_salt = row["ZCRYPTOSALT"]
        @crypto_iterations = row["ZCRYPTOITERATIONCOUNT"]
        @crypto_key = row["ZCRYPTOVERIFIER"] if row["ZCRYPTOVERIFIER"]
        @crypto_key = row["ZCRYPTOWRAPPEDKEY"] if row["ZCRYPTOWRAPPEDKEY"]
      end
    end

    @crypto_password = @note.crypto_password
    #@logger.debug("#{self.class} #{@uuid}: Added crypto password #{@crypto_password}")
    #@logger.debug("#{self.class} #{@uuid}: Added crypto iv #{@crypto_iv.unpack("H*")}")
    #@logger.debug("#{self.class} #{@uuid}: Added crypto tag #{@crypto_tag.unpack("H*")}")
    #@logger.debug("#{self.class} #{@uuid}: Added crypto salt #{@crypto_salt.unpack("H*")}")
    #@logger.debug("#{self.class} #{@uuid}: Added crypto iterations #{@crypto_iterations}")
    #@logger.debug("#{self.class} #{@uuid}: Added crypto wrapped key #{@crypto_key.unpack("H*")}")
  end

  ##
  # This method adds a +child_object+ to this object.
  def add_child(child_object)
    child_object.parent = self # Make sure the parent is set
    @child_objects.push(child_object)
  end

  ##
  # This method queries ZICCLOUDSYNCINGOBJECT to find any thumbnails for 
  # this object. Each one it finds, it adds to the thumbnails Array.
  def search_and_add_thumbnails
    @thumbnails = Array.new
    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.Z_PK, ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, " +
                      "ZICCLOUDSYNCINGOBJECT.ZHEIGHT, ZICCLOUDSYNCINGOBJECT.ZWIDTH " + 
                      "FROM ZICCLOUDSYNCINGOBJECT " + 
                      "WHERE ZATTACHMENT=?",
                      @primary_key) do |row|
      tmp_thumbnail = AppleNotesEmbeddedThumbnail.new(row["Z_PK"], 
                                                      row["ZIDENTIFIER"], 
                                                      "thumbnail", 
                                                      @note, 
                                                      @backup,
                                                      row["ZHEIGHT"],
                                                      row["ZWIDTH"],
                                                      self)
      @thumbnails.push(tmp_thumbnail)
    end

    # Sort the thumbnails so the largest overall size is at the end
    @thumbnails.sort_by!{|thumbnail| thumbnail.height * thumbnail.width}
  end


  ##
  # This method just returns a readable String for the object.
  # By default it just lists the +type+ and +uuid+. Subclasses 
  # should override this.
  def to_s
    "Embedded Object #{@type}: #{@uuid}"
  end

  ##
  # By default this returns its own +uuid+. 
  # Subclasses will override this if they have other pointers to media objects.
  def get_media_uuid
    @uuid
  end

  ##
  # By default this returns its own +filepath+. 
  # Subclasses will override this if they have other pointers to media objects.
  def get_media_filepath
    @filepath
  end

  ##
  # By default this returns its own +filename+. 
  # Subclasses will override this if they have other pointers to media objects.
  def get_media_filename
    @filename
  end

  ##
  # This method returns either nil, if there is no parent object, 
  # or the parent object's primary_key.
  def get_parent_primary_key
    return nil if !@parent
    return @parent.primary_key
  end

  ##
  # Class method to return an Array of the headers used on CSVs for this class
  def self.to_csv_headers
    ["Object Primary Key", 
     "Note ID",
     "Parent Object ID",
     "Object UUID", 
     "Object Type",
     "Object Filename",
     "Object Filepath on Phone",
     "Object Filepath on Computer"]
  end

  ##
  # This method returns an Array of the fields used in CSVs for this class
  # Currently spits out the +primary_key+, AppleNote +note_id+, AppleNotesEmbeddedObject parent +primary_key+, 
  # +uuid+, +type+, +filepath+, +filename+, and +backup_location+  on the computer. Also computes these for 
  # any children and thumbnails.
  def to_csv
    to_return =[[@primary_key, 
                   @note.note_id,
                   get_parent_primary_key,
                   @uuid, 
                   @type,
                   @filename,
                   @filepath,
                   @backup_location]]

    # Add in any child objects
    @child_objects.each do |child_object|
      to_return += child_object.to_csv
    end

    # Add in any thumbnails
    @thumbnails.each do |thumbnail|
      to_return += thumbnail.to_csv
    end

    return to_return
  end

  ##
  # This method generates the HTML to be embedded into an AppleNote's HTML.
  def generate_html
    return self.to_s
  end

end
