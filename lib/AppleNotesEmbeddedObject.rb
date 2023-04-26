require 'cgi'
require 'keyed_archive'
require 'sqlite3'
require_relative 'notestore_pb.rb'
require_relative 'AppleCloudKitRecord.rb'

##
# This class represents an object embedded in an AppleNote.
class AppleNotesEmbeddedObject < AppleCloudKitRecord

  attr_accessor :primary_key,
                :uuid,
                :type,
                :filepath,
                :filename,
                :backup_location,
                :parent,
                :conforms_to

  ##
  # Creates a new AppleNotesEmbeddedObject. 
  # Expects an Integer +primary_key+ from ZICCLOUDSYNCINGOBJECT.Z_PK, String +uuid+ from ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, 
  # String +uti+ from ZICCLOUDSYNCINGOBJECT.ZTYPEUIT, and AppleNote +note+ object representing the parent AppleNote.
  def initialize(primary_key, uuid, uti, note)
    # Set this object's variables
    @primary_key = primary_key
    @uuid = uuid
    @type = uti
    @conforms_to = uti
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
  # This method provides the +to_s+ method used by most 
  # objects with actual data.
  def to_s_with_data(data_type="media")
    return "Embedded Object #{@type}: #{@uuid} with #{data_type} in #{@backup_location}" if @backup_location
    "Embedded Object #{@type}: #{@uuid} with #{data_type} in #{@filepath}"
  end

  ##
  # By default this returns its own +uuid+. 
  # Subclasses will override this if they have other pointers to media objects.
  def get_media_uuid
    @uuid
  end

  ##
  # Handily pulls the UUID of media from ZIDENTIFIER of the ZMEDIA row
  def get_media_uuid_from_zidentifier
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
  # By default this returns its own +filepath+. 
  # Subclasses will override this if they have other pointers to media objects.
  def get_media_filepath
    @filepath
  end

  ##
  # This handles a striaght forward mapping of UUID and filename
  def get_media_filepath_with_uuid_and_filename
    return "#{@note.account.account_folder}Media/#{get_media_uuid}/#{get_media_uuid}" if @is_password_protected
    "#{@note.account.account_folder}Media/#{get_media_uuid}/#{@filename}"
  end

  ##
  # By default this returns its own +filename+. 
  # Subclasses will override this if they have other pointers to media objects.
  def get_media_filename
    @filename
  end

  ##
  # This handles how the media filename is pulled for most "data" objects
  def get_media_filename_from_zfilename
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
  # This method returns either nil, if there is no parent object, 
  # or the parent object's primary_key.
  def get_parent_primary_key
    return nil if !@parent
    return @parent.primary_key
  end

  ## 
  # This method handles spawning embedded objects based on the ZTypeUti or ZTypeUti1
  # field in the database. It expects an AppleNote +note+ which is the genesis of the object 
  # and a NoteStoreProto +note_proto+ that contains attribute runs. This returns a +Hash+ 
  # containing the resulting String and an array of objects. 
  def self.generate_embedded_objects(note, note_proto)
    to_return = Hash.new()
    to_return[:to_string] = ""
    to_return[:objects] = Array.new()

    notestore = note.notestore
    database = note.database
    note_id = note.note_id
    backup = note.backup
    logger = backup.logger

    # Tables cells will be a MergableDataProto
    root_node = note_proto
    # Note objects will be a NoteStoreProto
    if note_proto.is_a? NoteStoreProto
      root_node = note_proto.document
    end
 
    to_return[:to_string] = root_node.note.note_text
    root_node.note.attribute_run.each do |note_part|

      # Check for something embedded
      if note_part.attachment_info
        tmp_embedded_object = nil

        z_type_uti = "ZICCLOUDSYNCINGOBJECT.ZTYPEUTI, ZICCLOUDSYNCINGOBJECT.ZTYPEUTI1, ZICCLOUDSYNCINGOBJECT.ZALTTEXT, ZICCLOUDSYNCINGOBJECT.ZTOKENCONTENTIDENTIFIER"

        # For versions older than iOS 15
        if notestore.version < AppleNoteStore::IOS_VERSION_15
          z_type_uti = "ZICCLOUDSYNCINGOBJECT.ZTYPEUTI"
        end

        tmp_query = "SELECT ZICCLOUDSYNCINGOBJECT.Z_PK, ZICCLOUDSYNCINGOBJECT.ZNOTE, " + 
                    "ZICCLOUDSYNCINGOBJECT.ZCREATIONDATE, ZICCLOUDSYNCINGOBJECT.ZMODIFICATIONDATE, " +
                    "#{z_type_uti}, ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER " + 
                    "FROM ZICCLOUDSYNCINGOBJECT " +
                    "WHERE ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER=?"

        # If the note was "deleted", the obects will have been deleted, and this will turn up nothing
        database.execute(tmp_query, note_part.attachment_info.attachment_identifier) do |row|
          logger.debug("AppleNote: Note #{note_id} replacing attachment #{row["ZIDENTIFIER"]}")
          
          # Pull the right field to make a new UTI object
          tmp_uti_string = row["ZTYPEUTI"]
          if row["ZTYPEUTI1"]
            tmp_uti_string = row["ZTYPEUTI1"]
          end
          tmp_uti = AppleUniformTypeIdentifier.new(tmp_uti_string)

          # Handle inline text attachments
          if tmp_uti.conforms_to_inline_attachment
            if tmp_uti.uti == "com.apple.notes.inlinetextattachment.hashtag"
              tmp_embedded_object = AppleNotesEmbeddedInlineHashtag.new(row["Z_PK"],
                                                                           row["ZIDENTIFIER"],
                                                                           row["ZTYPEUTI1"],
                                                                           note,
                                                                           row["ZALTTEXT"],
                                                                           row["ZTOKENCONTENTIDENTIFIER"])
            elsif tmp_uti.uti == "com.apple.notes.inlinetextattachment.mention"
              tmp_embedded_object = AppleNotesEmbeddedInlineMention.new(row["Z_PK"],
                                                                           row["ZIDENTIFIER"],
                                                                           row["ZTYPEUTI1"],
                                                                           note,
                                                                           row["ZALTTEXT"],
                                                                           row["ZTOKENCONTENTIDENTIFIER"])
            else
              puts "#{row["ZTYPEUTI1"]} is unrecognized ZTYPEUTI1, please submit a bug report to this project's GitHub repo to report this: https://github.com/threeplanetssoftware/apple_cloud_notes_parser/issues"
              logger.debug("#{row["ZTYPEUTI1"]} is unrecognized ZTYPEUTI1, check ZICCLOUDSYNCINGOBJECT Z_PK: #{row["Z_PK"]}")
              tmp_embedded_object = AppleNotesEmbeddedInlineAttachment.new(row["Z_PK"],
                                                                           row["ZIDENTIFIER"],
                                                                           row["ZTYPEUTI1"],
                                                                           note,
                                                                           row["ZALTTEXT"],
                                                                           row["ZTOKENCONTENTIDENTIFIER"])
            end
          # Handle actual objects
          elsif tmp_uti.conforms_to_image
            tmp_embedded_object = AppleNotesEmbeddedPublicJpeg.new(row["Z_PK"],
                                                                   row["ZIDENTIFIER"],
                                                                   row["ZTYPEUTI"],
                                                                   note,
                                                                   backup,
                                                                   nil)
          elsif tmp_uti.conforms_to_audiovisual 
            tmp_embedded_object = AppleNotesEmbeddedPublicVideo.new(row["Z_PK"],
                                                                    row["ZIDENTIFIER"],
                                                                    row["ZTYPEUTI"],
                                                                    note,
                                                                    backup,
                                                                    nil)
          elsif tmp_uti.conforms_to_audio
            tmp_embedded_object = AppleNotesEmbeddedPublicAudio.new(row["Z_PK"],
                                                                    row["ZIDENTIFIER"],
                                                                    row["ZTYPEUTI"],
                                                                    note,
                                                                    backup,
                                                                    nil)
          elsif tmp_uti.uti == "public.vcard"
            tmp_embedded_object = AppleNotesEmbeddedPublicVCard.new(row["Z_PK"],
                                                                    row["ZIDENTIFIER"],
                                                                    row["ZTYPEUTI"],
                                                                    note,
                                                                    backup)
            tmp_embedded_object.conforms_to = "vcard"
          elsif tmp_uti.uti == "com.apple.ical.ics"
            tmp_embedded_object = AppleNotesEmbeddedCalendar.new(row["Z_PK"],
                                                                 row["ZIDENTIFIER"],
                                                                 row["ZTYPEUTI"],
                                                                 note,
                                                                 backup)
            tmp_embedded_object.conforms_to = "ical"
          elsif tmp_uti.conforms_to_document
            tmp_embedded_object = AppleNotesEmbeddedDocument.new(row["Z_PK"],
                                                                 row["ZIDENTIFIER"],
                                                                 row["ZTYPEUTI"],
                                                                 note,
                                                                 backup)
          elsif tmp_uti.uti == "com.adobe.pdf"
            tmp_embedded_object = AppleNotesEmbeddedPDF.new(row["Z_PK"],
                                                            row["ZIDENTIFIER"],
                                                            row["ZTYPEUTI"],
                                                            note,
                                                            backup)
            tmp_embedded_object.conforms_to = "PDF"
          elsif tmp_uti.uti == "public.url"
            tmp_embedded_object = AppleNotesEmbeddedPublicURL.new(row["Z_PK"],
                                                                  row["ZIDENTIFIER"],
                                                                  row["ZTYPEUTI"],
                                                                  note)
            tmp_embedded_object.conforms_to = "url"
          elsif tmp_uti.uti == "com.apple.notes.gallery"
            tmp_embedded_object = AppleNotesEmbeddedGallery.new(row["Z_PK"],
                                                                row["ZIDENTIFIER"],
                                                                row["ZTYPEUTI"],
                                                                note,
                                                                backup)
            tmp_embedded_object.conforms_to = "gallery"
          elsif tmp_uti.uti == "com.apple.notes.table"
            tmp_embedded_object = AppleNotesEmbeddedTable.new(row["Z_PK"],
                                                              row["ZIDENTIFIER"],
                                                              row["ZTYPEUTI"],
                                                              note)
            tmp_embedded_object.conforms_to = "table"
          elsif tmp_uti.uti == "com.apple.drawing.2" or tmp_uti.uti == "com.apple.drawing" or tmp_uti.uti == "com.apple.paper"
            tmp_embedded_object = AppleNotesEmbeddedDrawing.new(row["Z_PK"],
                                                                row["ZIDENTIFIER"],
                                                                row["ZTYPEUTI"],
                                                                note,
                                                                backup)
            tmp_embedded_object.conforms_to = "drawing"
          # Catch any other public.* types that likely represent something stored on disk
          elsif tmp_uti.is_public? or tmp_uti.uti == "com.apple.macbinary-archive"
            tmp_embedded_object = AppleNotesEmbeddedPublicObject.new(row["Z_PK"],
                                                                     row["ZIDENTIFIER"],
                                                                     row["ZTYPEUTI"],
                                                                     note,
                                                                     backup)
          # Deal with dynamic entries
          elsif tmp_uti.is_dynamic?
            tmp_embedded_object = AppleNotesEmbeddedPublicObject.new(row["Z_PK"],
                                                                     row["ZIDENTIFIER"],
                                                                     row["ZTYPEUTI"],
                                                                     note,
                                                                     backup)
          else
            tmp_embedded_object = AppleNotesEmbeddedObject.new(row["Z_PK"],
                                                               row["ZIDENTIFIER"],
                                                               row["ZTYPEUTI"],
                                                               note)
            puts "#{row["ZTYPEUTI"]} is unrecognized ZTYPEUTI, please submit a bug report to this project's GitHub repo to report this: https://github.com/threeplanetssoftware/apple_cloud_notes_parser/issues"
            logger.debug("#{row["ZTYPEUTI"]} is unrecognized ZTYPEUTI, check ZICCLOUDSYNCINGOBJECT Z_PK: #{row["Z_PK"]}")
          end
        
          # Set a string on the object to remember what it conforms to
          tmp_embedded_object.conforms_to = tmp_uti.get_conforms_to_string if (tmp_embedded_object.conforms_to == tmp_uti.to_s)
        end

        # If we still have't created an embedded object, we likely had something that was previously deleted
        if !tmp_embedded_object
          tmp_embedded_object = AppleNotesEmbeddedDeletedObject.new(note_part.attachment_info.attachment_identifier,
                                                                    note_part.attachment_info.type_uti,
                                                                    note)
          tmp_embedded_object.conforms_to = "deleted"
        end


        # Update plaintext to note something else is here
        to_return[:to_string] = to_return[:to_string].sub(/\ufffc/, "{#{tmp_embedded_object.to_s}}")
        to_return[:objects].push(tmp_embedded_object)
      end
    end

    to_return
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

  ##
  # This method generates the HTML to be embedded into an AppleNote's HTML for objects that use thumbnails.
  def generate_html_with_images
    return @thumbnails.first.generate_html if @thumbnails.length > 0
    if @reference_location
      builder = Nokogiri::HTML::Builder.new(encoding: "utf-8") do |doc|
        doc.img(src: "../#{@reference_location}")
      end

      return builder.doc.root
    end

    return "{#{type} missing due to not having a file reference location}"
  end

  ##
  # This method generates the HTML to be embedded into an AppleNote's HTML for objects that are just downloadable.
  def generate_html_with_link(type="Media")
    if @reference_location
      builder = Nokogiri::HTML::Builder.new(encoding: "utf-8") do |doc|
        doc.a(href: "../#{@reference_location}") {
          doc.text "#{type} #{@filename}"
        }
      end

      return builder.doc.root
    end

    return "{#{type} missing due to not having a file reference location}"
  end

  ##
  # This method prepares the data structure that JSON will use to generate JSON later.
  def prepare_json
    to_return = Hash.new()
    to_return[:primary_key] = @primary_key
    to_return[:parent_primary_key] = @parent_primary_key
    to_return[:note_id] = @note.note_id
    to_return[:uuid] = @uuid
    to_return[:type] = @type
    to_return[:conforms_to] = @conforms_to
    to_return[:filename] = @filename if (@filename != "")
    to_return[:filepath] = @filepath if (@filepath != "")
    to_return[:backup_location] = @backup_location if @backup_location
    to_return[:is_password_protected] = @is_password_protected
    to_return[:html] = generate_html

    # Add in thumbnails in case folks want smaller pictures
    if @thumbnails.length > 0
      to_return[:thumbnails] = Array.new()
      @thumbnails.each do |thumbnail|
        to_return[:thumbnails].push(thumbnail.prepare_json)
      end
    end

    if @child_objects.length > 0
      to_return[:child_objects] = Array.new()
      @child_objects.each do |child|
        to_return[:child_objects].push(child.prepare_json)
      end
    end

    to_return
  end

end
