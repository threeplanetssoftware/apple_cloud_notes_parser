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
                :possible_locations,
                :parent,
                :conforms_to,
                :thumbnails,
                :note

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

    # Set variables to defaults to be overridden later
    @version = AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_UNKNOWN)
    @is_password_protected = false
    @backup = nil
    @database = nil
    @logger = Logger.new(STDOUT)

    @user_title = ""
    @filepath = ""
    @filename = ""
    @backup_location = nil
    @possible_locations = Array.new

    # Variable to hold ZMERGEABLEDATA objects
    @gzipped_data = nil
  
    # Create an Array to hold Thumbnails
    @thumbnails = Array.new

    # Create an Array to hold child objects, such as for a gallery
    @child_objects = Array.new

    # Zero out cryptographic settings
    @crypto_iv = nil
    @crypto_tag = nil
    @crypto_key = nil
    @crypto_salt = nil
    @crypto_iterations = nil
    @crypto_password = nil

    # Override the variables if we were given a note
    self.note=(note) if note

    log_string = "Created a new Embedded Object of type #{@type}"
    log_string = "Note #{@note.note_id}: #{log_string}" if @note

    @logger.debug(log_string)
  end

  ##
  # This method sets the note that the object belongs to. It expects an AppleNote +note+.
  def note=(note)
    @note = note
    @version = @note.version
    @is_password_protected = @note.is_password_protected
    @backup = @note.backup
    @logger = @backup.logger
    @database = @note.database
    @user_title = get_media_zusertitle_for_row
    if @is_password_protected
      add_cryptographic_settings
    end
    search_and_add_thumbnails
  end

  ##
  # This method sets the version of the object. Typically this will be done directly from 
  # setting the note. It expects an Integer +version+
  def version=(version)
    @version = version
  end

  ##
  # This function adds cryptographic settings to the AppleNoteEmbeddedObject. 
  def add_cryptographic_settings
    @crypto_password = @note.crypto_password
    unapplied_encrypted_record_column = "ZUNAPPLIEDENCRYPTEDRECORD"
    unapplied_encrypted_record_column = unapplied_encrypted_record_column + "DATA" if @version >= AppleNoteStoreVersion::IOS_VERSION_18

    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZCRYPTOINITIALIZATIONVECTOR, ZICCLOUDSYNCINGOBJECT.ZCRYPTOTAG, " +
                      "ZICCLOUDSYNCINGOBJECT.ZCRYPTOSALT, ZICCLOUDSYNCINGOBJECT.ZCRYPTOITERATIONCOUNT, " + 
                      "ZICCLOUDSYNCINGOBJECT.ZCRYPTOVERIFIER, ZICCLOUDSYNCINGOBJECT.ZCRYPTOWRAPPEDKEY, " + 
                      "ZICCLOUDSYNCINGOBJECT.#{unapplied_encrypted_record_column} " + 
                      "FROM ZICCLOUDSYNCINGOBJECT " + 
                      "WHERE Z_PK=?",
                      @primary_key) do |row|

      @crypto_iv = row["ZCRYPTOINITIALIZATIONVECTOR"]
      @crypto_tag = row["ZCRYPTOTAG"]
      @crypto_salt = row["ZCRYPTOSALT"]
      @crypto_iterations = row["ZCRYPTOITERATIONCOUNT"]
      @crypto_key = row["ZCRYPTOVERIFIER"] if row["ZCRYPTOVERIFIER"]
      @crypto_key = row["ZCRYPTOWRAPPEDKEY"] if row["ZCRYPTOWRAPPEDKEY"]

      correct_settings = (@backup.decrypter.check_cryptographic_settings(@crypto_password,
                                                                        @crypto_salt,
                                                                        @crypto_iterations,
                                                                        @crypto_key) and 
                          @crypto_iv)

      # If there is a blob in ZUNAPPLIEDENCRYPTEDRECORD, we need to use it instead of the database values
      if row[unapplied_encrypted_record_column] and !correct_settings
        keyed_archive = KeyedArchive.new(:data => row[unapplied_encrypted_record_column])
        unpacked_top = keyed_archive.unpacked_top()
        ns_keys = unpacked_top["root"]["ValueStore"]["RecordValues"]["NS.keys"]
        ns_values = unpacked_top["root"]["ValueStore"]["RecordValues"]["NS.objects"]
        @crypto_iv = ns_values[ns_keys.index("CryptoInitializationVector")]
        @crypto_tag = ns_values[ns_keys.index("CryptoTag")]
        @crypto_salt = ns_values[ns_keys.index("CryptoSalt")]
        @crypto_iterations = ns_values[ns_keys.index("CryptoIterationCount")]
        @crypto_key = ns_values[ns_keys.index("CryptoWrappedKey")]
      end
    end

  end

  ##
  # This method fetches the gzipped ZMERGEABLE data from the database. It expects a String +uuid+ which defaults to the 
  # object's UUID. It returns the gzipped data as a String. 
  def fetch_mergeable_data_by_uuid(uuid = @uuid)
    gzipped_data = nil

    # Set the appropriate column to find the data in
    mergeable_column = "ZMERGEABLEDATA1"
    mergeable_column = "ZMERGEABLEDATA" if @version < AppleNoteStoreVersion::IOS_VERSION_13

    # If this object is password protected, fetch the mergeable data from the 
    # ZICCLOUDSYNCINGOBJECT.ZENCRYPTEDVALUESJSON column and decrypt it. 
    if @is_password_protected
      unapplied_encrypted_record_column = "ZUNAPPLIEDENCRYPTEDRECORD"
      unapplied_encrypted_record_column = unapplied_encrypted_record_column + "DATA" if @version >= AppleNoteStoreVersion::IOS_VERSION_18

      @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZENCRYPTEDVALUESJSON, ZICCLOUDSYNCINGOBJECT.#{unapplied_encrypted_record_column} " +
                        "FROM ZICCLOUDSYNCINGOBJECT " +
                        "WHERE ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER=?",
                        uuid) do |row|

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
                                                                 "#{self.class} #{uuid}")
        parsed_json = JSON.parse(decrypt_result[:plaintext])
        gzipped_data = Base64.decode64(parsed_json["mergeableData"])
      end

    # Otherwise, pull from the ZICCLOUDSYNCINGOBJECT.ZMERGEABLEDATA column
    else

      @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.#{mergeable_column} " +
                        "FROM ZICCLOUDSYNCINGOBJECT " +
                        "WHERE ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER=?",
                        uuid) do |row|

        # Extract the blob
        gzipped_data = row[mergeable_column]

      end
    end

    if !gzipped_data
      @logger.error("{self.class} #{@uuid}: Failed to find gzipped data to rebuild the object, check the #{mergeable_column} column for this UUID: \"SELECT hex(#{mergeable_column}) FROM ZICCLOUDSYNCINGOBJECT WHERE ZIDENTIFIER='#{@uuid}';\"")
    end

    return gzipped_data
  end

  ##
  # This method adds a +child_object+ to this object.
  def add_child(child_object)
    child_object.parent = self # Make sure the parent is set
    @child_objects.push(child_object)
  end

  ## 
  # This method adds a +possible_location+ to the +@possible_locations+ 
  # Array. 
  def add_possible_location(possible_location)
    possible_locations.push(possible_location)
  end

  ##
  # This method uses the object's +@backup.find_valid_file_path+ method 
  # to determine the right location on disk to find the file. 
  def find_valid_file_path
    return nil if !@backup
    @backup.find_valid_file_path(@possible_locations)
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
  def get_media_uuid_from_zidentifier(zidentifier=@uuid)
    zmedia = get_zmedia_from_zidentifier(zidentifier)
    return get_zidentifier_from_z_pk(zmedia)
  end

  ##
  # This method fetches the ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER column for 
  # a row identified by Integer z_pk.
  def get_zidentifier_from_z_pk(z_pk)
    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER " +
                      "FROM ZICCLOUDSYNCINGOBJECT " +
                      "WHERE ZICCLOUDSYNCINGOBJECT.Z_PK=?",
                      z_pk) do |row|
      return row["ZIDENTIFIER"]
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
    zgeneration = get_zgeneration_for_object
    zgeneration = "#{zgeneration}/" if (zgeneration and zgeneration.length > 0)

    return "#{@note.account.account_folder}Media/#{get_media_uuid}/#{zgeneration}#{get_media_uuid}" if @is_password_protected
    return "#{@note.account.account_folder}Media/#{get_media_uuid}/#{zgeneration}#{@filename}"
  end

  ##
  # By default this returns its own +filename+. 
  # Subclasses will override this if they have other pointers to media objects.
  def get_media_filename
    @filename
  end

  ##
  # This handles how the media filename is pulled for most "data" objects
  def get_media_filename_from_zfilename(zidentifier=@uuid)
    z_pk = get_zmedia_from_zidentifier(zidentifier)
    return get_media_filename_for_row(z_pk)
  end

  ##
  # This method returns the ZFILENAME column for a given row identified by 
  # Integer z_pk.
  def get_media_filename_for_row(z_pk)
    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZFILENAME " +
                      "FROM ZICCLOUDSYNCINGOBJECT " +
                      "WHERE ZICCLOUDSYNCINGOBJECT.Z_PK=?",
                      z_pk) do |media_row|
      return media_row["ZFILENAME"]
    end
  end

  ##
  # This method returns the ZUSERTITLE column for a given row identified by 
  # Integer z_pk. This represents the name a user gave an object, such as an image.
  def get_media_zusertitle_for_row(z_pk=@primary_key)
    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZUSERTITLE " +
                      "FROM ZICCLOUDSYNCINGOBJECT " +
                      "WHERE ZICCLOUDSYNCINGOBJECT.Z_PK=?",
                      z_pk) do |media_row|
      return media_row["ZUSERTITLE"]
    end
  end

  ##
  # This method returns the ZICCLOUDSYNCINGOBJECT.ZMEDIA column for a given row identified by 
  # String ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER. This represents the ZICCLOUDSYNCINGOBJECT.Z_PK of
  # another row.
  def get_zmedia_from_zidentifier(zidentifier=@uuid)
    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZMEDIA " +
                      "FROM ZICCLOUDSYNCINGOBJECT " +
                      "WHERE ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER=?",
                      zidentifier) do |row|
      return row["ZMEDIA"]
    end 
  end

  ##
  # 
  def get_zgeneration_for_object(zidentifier=@uuid)
    zmedia = get_zmedia_from_zidentifier(zidentifier)
    return get_zgeneration_for_row(zmedia)
  end

  ##
  # This method returns an array of all the "ZGENERATION" columns for a given row 
  # identified by Integer z_pk.
  def get_zgeneration_for_row(z_pk)
    # Bail early if we are below iOS 17 so we don't chuck an error on the query
    return "" if @note.notestore.version < AppleNoteStoreVersion::IOS_VERSION_17

    @database.execute("SELECT ZICCLOUDSYNCINGOBJECT.ZGENERATION, ZICCLOUDSYNCINGOBJECT.ZGENERATION1, " +
                      "ZICCLOUDSYNCINGOBJECT.ZFALLBACKIMAGEGENERATION, ZICCLOUDSYNCINGOBJECT.ZFALLBACKPDFGENERATION, " + 
                      "ZICCLOUDSYNCINGOBJECT.ZPAPERBUNDLEGENERATION " + 
                      "FROM ZICCLOUDSYNCINGOBJECT " +
                      "WHERE ZICCLOUDSYNCINGOBJECT.Z_PK=?",
                      z_pk) do |media_row|
      return media_row["ZGENERATION"] if media_row["ZGENERATION"]
      return media_row["ZGENERATION1"] if media_row["ZGENERATION1"]
      return media_row["ZFALLBACKIMAGEGENERATION"] if media_row["ZFALLBACKIMAGEGENERATION"]
      return media_row["ZFALLBACKPDFGENERATION"] if media_row["ZFALLBACKPDFGENERATION"]
      return media_row["ZPAPERBUNDLEGENERATION"] if media_row["ZPAPERBUNDLEGENERATION"]
      return ""
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
        if notestore.version < AppleNoteStoreVersion::IOS_VERSION_15
          z_type_uti = "ZICCLOUDSYNCINGOBJECT.ZTYPEUTI"
        end

        tmp_query = "SELECT ZICCLOUDSYNCINGOBJECT.Z_PK, ZICCLOUDSYNCINGOBJECT.ZNOTE, " + 
                    "ZICCLOUDSYNCINGOBJECT.ZCREATIONDATE, ZICCLOUDSYNCINGOBJECT.ZMODIFICATIONDATE, " +
                    "#{z_type_uti}, ZSIZEHEIGHT, ZSIZEWIDTH, ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER " + 
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
            elsif tmp_uti.uti == "com.apple.notes.inlinetextattachment.link"
              tmp_embedded_object = AppleNotesEmbeddedInlineLink.new(row["Z_PK"],
                                                                        row["ZIDENTIFIER"],
                                                                        row["ZTYPEUTI1"],
                                                                        note,
                                                                        row["ZALTTEXT"],
                                                                        row["ZTOKENCONTENTIDENTIFIER"])
            elsif tmp_uti.uti == "com.apple.notes.inlinetextattachment.calculateresult"
              tmp_embedded_object = AppleNotesEmbeddedInlineCalculateResult.new(row["Z_PK"],
                                                                                row["ZIDENTIFIER"],
                                                                                row["ZTYPEUTI1"],
                                                                                note,
                                                                                row["ZALTTEXT"],
                                                                                row["ZTOKENCONTENTIDENTIFIER"])
            elsif tmp_uti.uti == "com.apple.notes.inlinetextattachment.calculategraphexpression"
              tmp_embedded_object = AppleNotesEmbeddedInlineCalculateGraphExpression.new(row["Z_PK"],
                                                                                         row["ZIDENTIFIER"],
                                                                                         row["ZTYPEUTI1"],
                                                                                         note,
                                                                                         row["ZALTTEXT"],
                                                                                         row["ZTOKENCONTENTIDENTIFIER"])
            else
              puts "#{row["ZTYPEUTI1"]} is unrecognized ZTYPEUTI1, please submit a bug report to this project's GitHub repo to report this: https://github.com/threeplanetssoftware/apple_cloud_notes_parser/issues"
              logger.debug("Note #{note.note_id}: #{row["ZTYPEUTI1"]} is unrecognized ZTYPEUTI1, check ZICCLOUDSYNCINGOBJECT Z_PK: #{row["Z_PK"]}")
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
            tmp_embedded_object.height = row["ZSIZEHEIGHT"]
            tmp_embedded_object.width = row["ZSIZEWIDTH"]
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
          elsif tmp_uti.uti == "com.apple.paper.doc.scan" or tmp_uti.uti == "com.apple.paper.doc.pdf"
            tmp_embedded_object = AppleNotesEmbeddedPaperDocScan.new(row["Z_PK"],
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
            tmp_embedded_object.rebuild_table
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
            logger.debug("Note #{note.note_id}: #{row["ZTYPEUTI"]} is unrecognized ZTYPEUTI, check ZICCLOUDSYNCINGOBJECT Z_PK: #{row["Z_PK"]}")
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
     "Object Filepath on Computer",
     "Object User Title",
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
                   get_parent_primary_key,
                   @uuid, 
                   @type,
                   @filename,
                   @filepath,
                   @backup_location,
                   @user_title,
                   "", # Used by InlineAttachments
                   ""  # Used by InlineAttachments
                   ]]

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
  # This method finds the first thumbnail size, regardless of if the thumbnail's
  # reference location is real. Returns the answer as a Hash with keys 
  # {width: xxx, height: yyy}.
  def get_thumbnail_size
    return nil if (!@thumbnails or @thumbnails.length == 0)
    return {width: @thumbnails.first.width, height: @thumbnails.first.height}
  end

  ##
  # This method generates the HTML to be embedded into an AppleNote's HTML.
  def generate_html(individual_files=false)
    return self.to_s
  end

  ##
  # This method generates the HTML to be embedded into an AppleNote's HTML for objects that use thumbnails.
  def generate_html_with_images(individual_files=false)

    # If we have thumbnails, return the first one with a reference location
    @thumbnails.each do |thumbnail|
      return thumbnail.generate_html(individual_files) if thumbnail.reference_location
    end

    # If we don't have a thumbnail with a reference location, use ours
    if @reference_location
      root = @note.folder.to_relative_root(individual_files)
      href_target = "#{root}#{@reference_location}"
      builder = Nokogiri::HTML::Builder.new(encoding: "utf-8") do |doc|
        thumbnail_size = get_thumbnail_size
        doc.a(href: href_target) {
          if thumbnail_size and thumbnail_size[:width] > 0
            doc.img(src: href_target).attr("data-apple-notes-zidentifier" => "#{@uuid}").attr("width" => thumbnail_size[:width])
          else
            doc.img(src: href_target).attr("data-apple-notes-zidentifier" => "#{@uuid}")
          end
        }
      end

      return builder.doc.root
    end

    # If we get to here, neither our thumbnails, nor we had a reference location
    return "{#{type} missing due to not having a file reference location}"
  end

  ##
  # This method generates the HTML to be embedded into an AppleNote's HTML for objects that are just downloadable.
  def generate_html_with_link(type="Media", individual_files=false)
    if @reference_location
      root = @note.folder.to_relative_root(individual_files)
      builder = Nokogiri::HTML::Builder.new(encoding: "utf-8") do |doc|
        doc.a(href: "#{root}#{@reference_location}") {
          doc.text "#{type} #{@filename}"
        }.attr("data-apple-notes-zidentifier" => "#{@uuid}")
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
    to_return[:user_title] = @user_title
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
