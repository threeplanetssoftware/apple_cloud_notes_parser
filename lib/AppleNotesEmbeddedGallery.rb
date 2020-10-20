require 'zlib'
require_relative 'notestore_pb.rb'
require_relative 'AppleNotesEmbeddedThumbnail.rb'

##
# This class represents a com.apple.notes.gallery object embedded
# in an AppleNote. This means you scanned a document in (via taking a picture).
class AppleNotesEmbeddedGallery < AppleNotesEmbeddedObject

  ## 
  # Creates a new AppleNotesEmbeddedGallery object. 
  # Expects an Integer +primary_key+ from ZICCLOUDSYNCINGOBJECT.Z_PK, String +uuid+ from ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, 
  # String +uti+ from ZICCLOUDSYNCINGOBJECT.ZTYPEUTI, AppleNote +note+ object representing the parent AppleNote, and 
  # AppleBackup +backup+ from the parent AppleNote. Immediately finds the children picture objects and adds them.
  def initialize(primary_key, uuid, uti, note, backup)
    # Set this folder's variables
    super(primary_key, uuid, uti, note)

    # Gallery has no direct filename or path, just pointers to other pictures
    @filename = nil
    @filepath = nil
    @backup = backup

    # Add all the children
    add_gallery_children
  end

  ##
  # This method just returns a readable String for the object. 
  # Adds to the AppleNotesEmbeddedObject.to_s by pointing to where the media is.
  def to_s
    return super
  end

  ##
  # Uses database calls to fetch the actual child objects' ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER +uuid+. 
  # This requires opening the protobuf inside of ZICCLOUDSYNCINGOBJECT.ZMERGEABLEDATA1 or 
  # ZICCLOUDSYNCINGOBJECT.ZMERGEABLEDATA column (if older than iOS13) 
  # and returning the referenced ZIDENTIFIER in that object.
  def add_gallery_children

    gzipped_data = nil

    # If this Gallery is password protected, fetch the mergeable data from the 
    # ZICCLOUDSYNCINGOBJECT.ZENCRYPTEDVALUESJSON column and decrypt it. 
    if @is_password_protected
      @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZENCRYPTEDVALUESJSON, ZICCLOUDSYNCINGOBJECT.ZUNAPPLIEDENCRYPTEDRECORD " +
                        "FROM ZICCLOUDSYNCINGOBJECT " +
                        "WHERE ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER=?",
                        @uuid) do |row|

        encrypted_values = row["ZENCRYPTEDVALUESJSON"]

        if row["ZUNAPPLIEDENCRYPTEDRECORD"]
          keyed_archive = KeyedArchive.new(:data => row["ZUNAPPLIEDENCRYPTEDRECORD"])
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
                                                                 "AppleNotesEmbeddedGallery #{@uuid}")
        parsed_json = JSON.parse(decrypt_result[:plaintext])
        gzipped_data = Base64.decode64(parsed_json["mergeableData"])
      end

    # Otherwise, pull from the ZICCLOUDSYNCINGOBJECT.ZMERGEABLEDATA column
    else
      # Set the appropriate column to find the data in
      mergeable_column = "ZMERGEABLEDATA1"
      mergeable_column = "ZMERGEABLEDATA" if @note.version < AppleNoteStore::IOS_VERSION_13

      @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.#{mergeable_column} " +
                        "FROM ZICCLOUDSYNCINGOBJECT " +
                        "WHERE ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER=?",
                        @uuid) do |row|

        # Extract the blob
        gzipped_data = row[mergeable_column]

      end
    end

    # Inflate the GZip
    zlib_inflater = Zlib::Inflate.new(Zlib::MAX_WBITS + 16)
    gunzipped_data = zlib_inflater.inflate(gzipped_data)

    # Read the protobuff
    mergabledata_proto = MergableDataProto.decode(gunzipped_data)
    mergabledata_proto.mergable_data_object.mergeable_data_object_data.mergeable_data_object_entry.each do |mergeable_data_object_entry|
      if mergeable_data_object_entry.custom_map
        create_child_from_uuid(mergeable_data_object_entry.custom_map.map_entry.first.value.string_value)
      end

    end
    nil
  end

  ##
  # This method takes a String +uuid+ and looks up the necessary information in 
  # ZICCLOUDSYNCINGOBJECTs to make a new child object of the appropriate type. 
  def create_child_from_uuid(uuid)
    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.Z_PK, ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, " + 
                      "ZICCLOUDSYNCINGOBJECT.ZTYPEUTI " + 
                      "FROM ZICCLOUDSYNCINGOBJECT " + 
                      "WHERE ZIDENTIFIER=?", uuid) do |row|
      tmp_child = AppleNotesEmbeddedPublicJpeg.new(row["Z_PK"],
                                                   row["ZIDENTIFIER"],
                                                   row["ZTYPEUTI"],
                                                   @note,
                                                   @backup,
                                                   self)
      tmp_child.search_and_add_thumbnails # This will cause it to regenerate the thumbnail array knowing that this is the parent
      add_child(tmp_child)
    end
  end

  ##
  # This method generates the HTML necessary to display the image inline.
  def generate_html
    to_return = ""

    @child_objects.each do |child_object|
      to_return += child_object.generate_html
    end

    return to_return
  end

end
