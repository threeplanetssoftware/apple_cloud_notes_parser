require 'json'
require 'keyed_archive'

##
# This class represents a public.url object embedded
# in an AppleNote. This means you used another application to 'share' something that 
# resolved to a URL, such as a website in Safari, or a place in Maps.
class AppleNotesEmbeddedPublicURL < AppleNotesEmbeddedObject

  attr_accessor :primary_key,
                :uuid,
                :type,
                :url

  ## 
  # Creates a new AppleNotesEmbeddedURL object. 
  # Expects an Integer +primary_key+ from ZICCLOUDSYNCINGOBJECT.Z_PK, String +uuid+ from ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, 
  # String +uti+ from ZICCLOUDSYNCINGOBJECT.ZTYPEUTI, and an AppleNote +note+ object representing the parent AppleNote. 
  # Immediately sets the URL variable to where this points at.
  def initialize(primary_key, uuid, uti, note)
    # Set this folder's variables
    super(primary_key, uuid, uti, note)

    @url = get_referenced_url
  end

  ##
  # This method just returns a readable String for the object. 
  # Adds to the AppleNotesEmbeddedObject.to_s by pointing to where the media is.
  def to_s
    return super + " pointing to #{@url}"
  end

  ##
  # Uses database calls to fetch the object's ZICCLOUDSYNCINGOBJECT.ZURLSTRING +url+. 
  # This requires taking the ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER field on the entry with this object's +uuid+ 
  # and reading the ZICCOUDSYNCINGOBJECT.ZURLSTRING of the row identified by that number.
  def get_referenced_url
    referenced_url = nil

    
    # If this URL is password protected, fetch the URL from the 
    # ZICCLOUDSYNCINGOBJECT.ZENCRYPTEDVALUESJSON column and decrypt it. 
    if @is_password_protected
      unapplied_encrypted_record_column = "ZUNAPPLIEDENCRYPTEDRECORD"
      unapplied_encrypted_record_column = unapplied_encrypted_record_column + "DATA" if @version >= AppleNoteStoreVersion::IOS_VERSION_18
    
      @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZENCRYPTEDVALUESJSON, ZICCLOUDSYNCINGOBJECT.#{unapplied_encrypted_record_column} " +
                        "FROM ZICCLOUDSYNCINGOBJECT " +
                        "WHERE ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER=?",
                        @uuid) do |row|

        encrypted_values = row["ZENCRYPTEDVALUESJSON"]

        if row[unapplied_encrypted_record_column]
          keyed_archive = KeyedArchive.new(:data => row[unapplied_encrypted_record_column])
          unpacked_top = keyed_archive.unpacked_top()
          ns_keys = unpacked_top["root"]["ValueStore"]["RecordValues"]["NS.keys"]
          ns_values = unpacked_top["root"]["ValueStore"]["RecordValues"]["NS.objects"]
          encrypted_values = ns_values[ns_keys.index("EncryptedValues")]
        end

        decrypt_result = @backup.decrypter.decrypt_with_password(@crypto_password,
                                                                 @crypto_salt,
                                                                 @crypto_iterations,
                                                                 @crypto_key,
                                                                 @crypto_iv,
                                                                 @crypto_tag,
                                                                 encrypted_values,
                                                                 "#{self.class} #{@uuid}")
        parsed_json = JSON.parse(decrypt_result[:plaintext])
        referenced_url = parsed_json["urlString"]
      end
    else

      @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZURLSTRING " +
                        "FROM ZICCLOUDSYNCINGOBJECT " +
                        "WHERE ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER=?",
                        @uuid) do |row|
        referenced_url = row["ZURLSTRING"]
      end

    end
    return referenced_url
  end

  ##
  # This method generates the HTML necessary to display the image inline.
  def generate_html(individual_files=false)
    builder = Nokogiri::HTML::Builder.new(encoding: "utf-8") do |doc|
      root = @note.folder.to_relative_root(individual_files)
      doc.span {
        if (@thumbnails.length > 0 and @thumbnails.first.reference_location)
          doc.img(src: "#{root}#{@thumbnails.first.reference_location}")
        end

        doc.a(href: @url) {
          doc.text @url
        }
      }
    end

    return builder.doc.root
  end

  ##
  # Generates the data structure used lated by JSON to create a JSON object.
  def prepare_json
    to_return = super()
    to_return[:url] = @url

    to_return
  end

end
