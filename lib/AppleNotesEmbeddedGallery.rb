require 'zlib'
require_relative 'notestore_pb.rb'
require_relative 'AppleNotesEmbeddedThumbnail.rb'

##
# This class represents a com.apple.notes.gallery object embedded
# in an AppleNote. This means you scanned a document in (via taking a picture).
class AppleNotesEmbeddedGallery < AppleNotesEmbeddedObject

  attr_accessor :primary_key,
                :uuid,
                :type,
                :filepath,
                :filename,
                :reference_location

  ## 
  # Creates a new AppleNotesEmbeddedGallery object. 
  # Expects an Integer +primary_key+ from ZICCLOUDSYNCINGOBJECT.Z_PK, String +uuid+ from ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, 
  # String +uti+ from ZICCLOUDSYNCINGOBJECT.ZTYPEUTI, AppleNote +note+ object representing the parent AppleNote, and 
  # AppleBackup +backup+ from the parent AppleNote. Immediately sets the +filename+ and +filepath+ to point to were the media is stored. 
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
    @reference_location = @backup.back_up_file(@filepath, @filename, @backup_location)

    # Find any thumbnails and add them
    @thumbnails = Array.new
    search_and_add_thumbnails
  end

  ##
  # This method queries ZICCLOUDSYNCINGOBJECT to find any thumbnails for 
  # this image. Each one it finds, it adds to the thumbnails Array.
  def search_and_add_thumbnails
    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.Z_PK " +
                      "FROM ZICCLOUDSYNCINGOBJECT " +
                      "WHERE ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER=?",
                      get_media_uuid) do |media_row|
      @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.Z_PK, ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, " +
                        "ZICCLOUDSYNCINGOBJECT.ZHEIGHT, ZICCLOUDSYNCINGOBJECT.ZWIDTH " + 
                        "FROM ZICCLOUDSYNCINGOBJECT " + 
                        "WHERE ZATTACHMENT=?",
                        media_row["Z_PK"]) do |row|
        tmp_thumbnail = AppleNotesEmbeddedThumbnail.new(row["Z_PK"], 
                                                        row["ZIDENTIFIER"], 
                                                        @type, 
                                                        @note, 
                                                        @backup,
                                                        row["ZHEIGHT"],
                                                        row["ZWIDTH"])
        @thumbnails.push(tmp_thumbnail)
      end
    end
  end

  ##
  # This method just returns a readable String for the object. 
  # Adds to the AppleNotesEmbeddedObject.to_s by pointing to where the media is.
  def to_s
    return super + " with media in #{@backup_location}" if @backup_location
    return super + " with media in #{@filepath}"
  end

  ##
  # Uses database calls to fetch the actual media objects ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER +uuid+. 
  # This requires opening the protobuf inside of ZICCLOUDSYNCINGOBJECT.ZMERGEABLEDATA1 
  # and returning the referenced ZIDENTIFIER in that object.
  def get_media_uuid
    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZMERGEABLEDATA1 " +
                      "FROM ZICCLOUDSYNCINGOBJECT " +
                      "WHERE ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER=?",
                      @uuid) do |row|

      # Extract the blob
      gzipped_data = row["ZMERGEABLEDATA1"]
      zlib_inflater = Zlib::Inflate.new(Zlib::MAX_WBITS + 16)
      gunzipped_data = zlib_inflater.inflate(gzipped_data)

      # Read the protobuff
      mergabledata_proto = MergableDataProto.decode(gunzipped_data)
      mergabledata_proto.mergable_data_object.mergeable_data_object_data.mergeable_data_object_entry.each do |mergeable_data_object_entry|
        if mergeable_data_object_entry.custom_map
          return mergeable_data_object_entry.custom_map.map_entry.first.value.string_value
        end
      end

    end
    nil
  end

  ##
  # This method returns the +filepath+ of this object. 
  # This is computed based on the assumed default storage location.
  def get_media_filepath
    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZMEDIA " +
                      "FROM ZICCLOUDSYNCINGOBJECT " +
                      "WHERE ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER=?",
                      get_media_uuid) do |row|
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
  # identified by +get_media_uuid+. After that, the ZICCLOUDSYNCINGOBJECT.ZFILENAME 
  # field holds the answer.
  def get_media_filename
    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZMEDIA " +
                      "FROM ZICCLOUDSYNCINGOBJECT " +
                      "WHERE ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER=?",
                      get_media_uuid) do |row|
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
    return @thumbnails.last.generate_html if @thumbnails.length > 0
    return "<img src='../#{@reference_location}' />"
  end

end
