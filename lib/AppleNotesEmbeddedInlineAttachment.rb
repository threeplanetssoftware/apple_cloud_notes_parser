require 'keyed_archive'
require 'sqlite3'
require_relative 'AppleCloudKitRecord'

##
# This class represents an inline text enhancement embedded in an AppleNote. 
# These were added in iOS 15 and represent things like hashtags and @ mentions.
class AppleNotesEmbeddedInlineAttachment < AppleCloudKitRecord

  attr_accessor :primary_key,
                :uuid,
                :type,
                :parent

  ##
  # Creates a new AppleNotesEmbeddedInlineAttachment. 
  # Expects an Integer +primary_key+ from ZICCLOUDSYNCINGOBJECT.Z_PK, String +uuid+ from ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, 
  # String +uti+ from ZICCLOUDSYNCINGOBJECT.ZTYPEUTI1, AppleNote +note+ object representing the parent AppleNote, 
  # a String +alt_text+ from ZICCLOUDSYNCINGOBJECT.ZALTTEXT, and a String +token_identifier+ from 
  # ZICCLOUDSYNCINGOBJECT.ZTOKENCONTENTIDENTIFIER representing what the text stands for.
  def initialize(primary_key, uuid, uti, note, alt_text, token_identifier)
    # Set this object's variables
    @primary_key = primary_key
    @uuid = uuid
    @type = uti
    @note = note
    @alt_text = alt_text
    @token_identifier = token_identifier
    @is_password_protected = @note.is_password_protected
    @backup = @note.backup
    @database = @note.database
    @logger = @backup.logger
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

    @logger.debug("Note #{@note.note_id}: Created a new Embedded Inline Attachment of type #{@type}")
  end

  ##
  # This function adds cryptographic settings to the AppleNoteEmbeddedInlineAttachment. 
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
  # This method just returns a readable String for the object.
  # By default it just lists the +alt_text+. Subclasses 
  # should override this.
  def to_s
    @alt_text
  end

  ##
  # Class method to return an Array of the headers used on CSVs for this class
  def self.to_csv_headers
    ["Object Primary Key", 
     "Note ID",
     "Object UUID", 
     "Object Type",
     "Object Alt Text",
     "Object Token Identifier"]
  end

  ##
  # This method returns an Array of the fields used in CSVs for this class
  # Currently spits out the +primary_key+, AppleNote +note_id+, AppleNotesEmbeddedObject parent +primary_key+, 
  # +uuid+, +type+, +filepath+, +filename+, and +backup_location+  on the computer. Also computes these for 
  # any children and thumbnails.
  def to_csv
    to_return =[[@primary_key, 
                   @note.note_id,
                   @uuid, 
                   @type,
                   @alt_text,
                   @token_identifier]]

    return to_return
  end

  ##
  # This method generates the HTML to be embedded into an AppleNote's HTML.
  def generate_html
    return self.to_s
  end

end
