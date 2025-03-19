require 'cgi'
require 'keyed_archive'
require 'sqlite3'
require 'nokogiri'
require 'zlib'
require_relative 'ProtoPatches.rb'
require_relative 'AppleCloudKitRecord.rb'
require_relative 'AppleNotesEmbeddedObject.rb'
require_relative 'AppleDecrypter.rb'
require_relative 'AppleNotesEmbeddedInlineAttachment.rb'
require_relative 'AppleNotesEmbeddedInlineCalculateGraphExpression.rb'
require_relative 'AppleNotesEmbeddedInlineCalculateResult.rb'
require_relative 'AppleNotesEmbeddedInlineHashtag.rb'
require_relative 'AppleNotesEmbeddedInlineLink.rb'
require_relative 'AppleNotesEmbeddedInlineMention.rb'
require_relative 'AppleNotesEmbeddedCalendar.rb'
require_relative 'AppleNotesEmbeddedDeletedObject.rb'
require_relative 'AppleNotesEmbeddedDocument.rb'
require_relative 'AppleNotesEmbeddedDrawing.rb'
require_relative 'AppleNotesEmbeddedGallery.rb'
require_relative 'AppleNotesEmbeddedPaperDocScan.rb'
require_relative 'AppleNotesEmbeddedPDF.rb'
require_relative 'AppleNotesEmbeddedPublicAudio.rb'
require_relative 'AppleNotesEmbeddedPublicObject.rb'
require_relative 'AppleNotesEmbeddedPublicJpeg.rb'
require_relative 'AppleNotesEmbeddedPublicURL.rb'
require_relative 'AppleNotesEmbeddedPublicVCard.rb'
require_relative 'AppleNotesEmbeddedPublicVideo.rb'
require_relative 'AppleNotesEmbeddedTable.rb'
require_relative 'AppleNoteStore.rb'
require_relative 'AppleUniformTypeIdentifier.rb'

##
#
# This class represents an Apple Note.
# It should support both classic Apple Notes and the iCloud version
class AppleNote < AppleCloudKitRecord

  # Constants to reflect the types of styling in an AppleNote
  STYLE_TYPE_DEFAULT = -1
  STYLE_TYPE_TITLE = 0
  STYLE_TYPE_HEADING = 1
  STYLE_TYPE_SUBHEADING = 2
  STYLE_TYPE_MONOSPACED = 4
  STYLE_TYPE_DOTTED_LIST = 100
  STYLE_TYPE_DASHED_LIST = 101
  STYLE_TYPE_NUMBERED_LIST = 102
  STYLE_TYPE_CHECKBOX = 103

  STYLE_TYPE_BLOCK_QUOTE = 1

  STYLE_ALIGNMENT_LEFT = 0
  STYLE_ALIGNMENT_CENTER = 1
  STYLE_ALIGNMENT_RIGHT = 2
  STYLE_ALIGNMENT_JUSTIFY = 3

  # Constants that reflect the types of font weighting
  FONT_TYPE_DEFAULT = 0
  FONT_TYPE_BOLD = 1
  FONT_TYPE_ITALIC = 2
  FONT_TYPE_BOLD_ITALIC = 3

  attr_accessor :creation_time, 
                :modify_time, 
                :data, 
                :note_id,
                :is_compressed,
                :title,
                :is_password_protected,
                :embedded_objects,
                :embedded_objects_recursive,
                :plaintext,
                :primary_key,
                :database,
                :decompressed_data,
                :account,
                :folder,
                :backup,
                :crypto_password,
                :cloudkit_creator_record_id,
                :cloudkit_modify_device,
                :notestore,
                :is_pinned,
                :uuid,
                :widget_snippet

  ##
  # Creates a new AppleNote. Expects an Integer +z_pk+, an Integer +znote+ representing the ZICNOTEDATA.ZNOTE field, 
  # a String +ztitle+ representing the ZICCLOUDSYNCINGOBJECT.ZTITLE field, a binary String +zdata+ representing the 
  # ZICNOTEDATA.ZDATA field, an Integer +creation_time+ representing the iOS CoreTime number found in ZICCLOUDSYNCINGOBJECT.ZCREATIONTIME1 field, 
  # an Integer +modify_time+ representing the iOS CoreTime number found in ZICCLOUDSYNCINGOBJECT.ZMODIFICATIONTIME1 field, 
  # an AppleNotesAccount +account+ representing the owning account, an AppleNotesFolder +folder+ representing the holding folder, 
  # and an AppleNoteStore +notestore+ representing the actual NoteStore
  # representing the full backup.
  def initialize(z_pk, znote, ztitle, zdata, creation_time, modify_time, account, folder)
    super()
    # Initialize some other variables while we're here
    @plaintext = nil
    @decompressed_data = nil
    @encrypted_data = nil
    @widget_snippet = nil
    @note_proto = nil
    @crypto_iv = nil
    @crypto_tag = nil
    @crypto_key = nil
    @crypto_salt = nil
    @crypto_iterations = nil
    @crypto_password = nil
    @is_password_protected = false

    # This holds objects directly in the note itself
    @embedded_objects = Array.new()
    # This holds objets embedded in other objects
    @embedded_objects_recursive = Array.new()

    # Feed in our arguments
    @primary_key = z_pk
    @note_id = znote
    @title = ztitle
    @compressed_data = zdata
    @creation_time = convert_core_time(creation_time)
    @modify_time = convert_core_time(modify_time)
    @account = account
    @folder = folder
    @notestore = nil
    @database = nil
    @backup = nil
    @logger = Logger.new(STDOUT)
    @uuid = ""
    @version = AppleNoteStoreVersion.new # Default to unknown, override this with version=

    # Handle pinning, added in iOS 11
    @is_pinned = false

    # Cache HTML once generated, useful for multiple outputs that all want the HTML
    @html = nil
  end

  ##
  # This method adds an AppleNoteStore object as a parent reference. 
  # It expects an AppleNoteStore +notestore+. 
  def notestore=(notestore)
    @notestore = notestore
    @database = @notestore.database
    @backup = @notestore.backup
    @logger = @backup.logger
  end

  ##
  # This method handles processing the AppleNote's text. 
  # For legacy notes that is fairly straightforward and for 
  # modern notes that means decompressing and parsing the protobuf.
  def process_note
    # Treat legacy stuff different
    if @version.legacy?
      @plaintext = @compressed_data
      @compressed_data = nil
    else
      # Unpack what we can
      @is_compressed = is_gzip(@compressed_data) 
      decompress_data if @is_compressed
      extract_plaintext if @decompressed_data
      replace_embedded_objects if (@plaintext and @database)
    end
  end

  ##
  # This method sets the Note's version. It expects an Integer +version+.
  def version=(version)
    @version = version
  end

  ##
  # This method returns the appropriate version for the AppleNote. 
  def version
    @version
  end

  ##
  # This method takes the +decompressed_data+ as an AppleNotesProto protobuf and 
  # assigned the plaintext from that protobuf into the +plaintext+ variable.
  def extract_plaintext
    if @decompressed_data
      begin
        tmp_note_store_proto = NoteStoreProto.decode(@decompressed_data)
        @plaintext = tmp_note_store_proto.document.note.note_text
        @note_proto = tmp_note_store_proto
      rescue Exception
        puts "Error parsing the protobuf for Note #{@note_id}, have to skip it, see the debug log for more details"
        @logger.error("Error parsing the protobuf for Note #{@note_id}, have to skip it")
        @logger.error("Run the following sqlite query to find the appropriate note data, export the ZDATA column as #{@note_id}.blob.gz, gunzip it, and the resulting #{@note_id}.blob contains your protobuf to check with protoc.")
        @logger.error("\tSELECT ZDATA FROM ZICNOTEDATA WHERE ZNOTE=#{@note_id}")
      end
    end
  end

  ##
  # This method takes the +plaintext+ that is stored and the +decompressed_data+ 
  # as an AppleNotesProto protobuf and loops over all the embedded objects. 
  # For each embedded object it finds, it creates a new AppleNotesEmbeddedObject and 
  # replaces the "obj" placeholder wth the new object's to_s method. This method 
  # creates sub-classes of AppleNotesEmbeddedObject depending on the ZICCLOUDSYNCINGOBJECT.ZTYPEUTI 
  # column.
  def replace_embedded_objects
    if (@plaintext and @account and @folder)
      tmp_note_store_proto = NoteStoreProto.decode(@decompressed_data)
      replaced_objects = AppleNotesEmbeddedObject.generate_embedded_objects(self, tmp_note_store_proto)
      @plaintext = replaced_objects[:to_string]
      replaced_objects[:objects].each do |replaced_object|
        @embedded_objects.push(replaced_object)
      end
    end
  end

  ##
  # This class method returns an Array representing the headers needed for an AppleNote CSV export.
  def self.to_csv_headers
    ["Note Primary Key", 
     "Note ID",
     "Pinned?", 
     "Owning Account Name", 
     "Owning Folder Name",
     "Modify By Device", 
     "Cloudkit Creator Record ID", 
     "Title", 
     "Creation Time", 
     "Modify Time", 
     "Note Plaintext", 
     "Widget Snippet", 
     "Is Password protected",
     "Crypto Interations",
     "Crypto Salt (hex)",
     "Crypto Tag (hex)",
     "Crypto Key (hex)",
     "Crypto IV (hex)",
     "Encrypted Data (hex)",
     "UUID"]
  end

  ##
  # This method returns an Array representing the AppleNote CSV export row of this object. 
  # Currently that is the +primary_key+, +note_id+, AppleNotesAccount name, AppleNotesFolder name, 
  # +title+, +creation_time+, +modify_time+, +plaintext+, and +is_password_protected+. If there 
  # are cryptographic variables, it also includes the +crypto_salt+, +crypto_tag+, +crypto_key+, 
  # +crypto_iv+, and +encrypted_data+, all as hex, vice binary.
  def to_csv
    tmp_pinned = "N"
    tmp_pinned = "Y" if @is_pinned
    [@primary_key, 
     @note_id, 
     tmp_pinned,
     @account.name, 
     @folder.name, 
     @cloudkit_last_modified_device, 
     @cloudkit_creator_record_id, 
     @title, 
     @creation_time, 
     @modify_time, 
     @plaintext, 
     @widget_snippet,
     @is_password_protected,
     @crypto_iterations,
     get_crypto_salt_hex,
     get_crypto_tag_hex,
     get_crypto_key_hex,
     get_crypto_iv_hex,
     get_encrypted_data_hex,
     @uuid]
  end

  ## 
  # This function returns the +crypto_iv+ as hex, if it exists.
  def get_crypto_iv_hex
    return @crypto_iv if ! @crypto_iv
    @crypto_iv.unpack("H*")
  end

  ## 
  # This function returns the +crypto_key+ as hex, if it exists.
  def get_crypto_key_hex
    return @crypto_key if ! @crypto_key
    @crypto_key.unpack("H*")
  end

  ## 
  # This function returns the +crypto_tag+ as hex, if it exists.
  def get_crypto_tag_hex
    return @crypto_tag if ! @crypto_tag
    @crypto_tag.unpack("H*")
  end

  ## 
  # This function returns the +crypto_salt+ as hex, if it exists.
  def get_crypto_salt_hex
    return @crypto_salt if ! @crypto_salt
    @crypto_salt.unpack("H*")
  end

  ## 
  # This function returns the +encrypted_data+ as hex, if it exists.
  def get_encrypted_data_hex
    return @encrypted_data if ! @encrypted_data
    @encrypted_data.unpack("H*")
  end

  ## 
  # This function returns the +plaintext+ for the note.
  def get_note_contents
    return "Error, note not yet decrypted" if @encrypted_data and !@decompressed_data
    return "Error, note not yet decompressed" if !@decompressed_data
    return "Error, note not yet plaintexted" if !@plaintext
    @plaintext
  end

  ##
  # This function checks if specified +data+ is a GZip object by matching the first two bytes.
  def is_gzip(data)
    return false if !data.is_a?(String)
    return (data.length > 2 and data.bytes[0] == 0x1f and data.bytes[1] == 0x8B)
  end

  ##
  # This function converts iOS Core Time, specified as an Integer +core_time+, to a Time object.
  def convert_core_time(core_time)
    return Time.at(0) unless core_time
    return Time.at(core_time + 978307200)
  end

  ## 
  # This function decompresses the orginally GZipped data present in +compressed_data+.
  # It stores the result in +decompressed_data+
  def decompress_data
    @decompressed_data = nil

    # Check for GZip magic number
    if is_gzip(@compressed_data)
      zlib_inflater = Zlib::Inflate.new(Zlib::MAX_WBITS + 16)
      begin
        @decompressed_data = zlib_inflater.inflate(@compressed_data)
      rescue StandardError => error
        # warn "\033[101m#{error}\033[m" # Prettified colors
        @logger.error("AppleNote: Note #{@note_id} somehow tried to decompress something that was GZIP but had to rescue error: #{error}")
      end
    else
      @logger.error("AppleNote: Note #{@note_id} somehow tried to decompress something that was not a GZIP")
    end
  end

  ##
  # This function adds cryptographic settings to the AppleNote. 
  # It expects a +crypto_iv+ as a binary String, a +crypto_tag+ as a binary String, a +crypto_salt+ as a binary String, 
  # the +crypto_iterations+ as an Integer, a +crypto_verifier+ as a binary String, and a +crypto_wrapped_key+ as a binary String.
  # No AppleNote should ahve both a +crypto_verifier+ and a +crypto_wrapped_key+. 
  def add_cryptographic_settings(crypto_iv, crypto_tag, crypto_salt, crypto_iterations, crypto_verifier, crypto_wrapped_key)
    @encrypted_data = @compressed_data # Move what was in compressed by default over to encrypted
    @compressed_data = nil
    @is_password_protected = true
    @crypto_iv = crypto_iv
    @crypto_tag = crypto_tag
    @crypto_salt = crypto_salt
    @crypto_iterations = crypto_iterations
    @crypto_key = crypto_verifier if crypto_verifier
    @crypto_key = crypto_wrapped_key if crypto_wrapped_key
  end

  ##
  # This function ensures all cryptographic variables are set.
  def has_cryptographic_variables?
    return (@is_password_protected and @encrypted_data and @crypto_iv and @crypto_tag and @crypto_salt and @crypto_iterations and @crypto_key)
  end

  ##
  # This function attempts to decrypt the note by providing its cryptographic variables to the AppleDecrypter.
  def decrypt
    return false if !has_cryptographic_variables?

    decrypt_result = @backup.decrypter.decrypt(@crypto_salt, 
                                               @crypto_iterations, 
                                               @crypto_key, 
                                               @crypto_iv, 
                                               @crypto_tag, 
                                               @encrypted_data, 
                                               "Apple Note: #{@note_id}")

    # If we made a decrypt, then kick the result into our normal process to extract everything
    if decrypt_result
      @crypto_password = decrypt_result[:password]
      @compressed_data = decrypt_result[:plaintext]
      decompress_data
      extract_plaintext if @decompressed_data
      replace_embedded_objects if (@plaintext and @database)
    end

    return (plaintext != false)
  end

  ## 
  # This method returns true if the AppleNote has any tags on it.
  def has_tags
    @embedded_objects.each do |embedded_object|
      return true if embedded_object.is_a? AppleNotesEmbeddedInlineHashtag
    end

    return false
  end

  ## 
  # This method returns an Array of each AppleNotesEmbeddedInlineHashtag on the AppleNote.
  def get_all_tags
    to_return = []
    @embedded_objects.each do |embedded_object|
      to_return.push(embedded_object) if embedded_object.is_a? AppleNotesEmbeddedInlineHashtag
    end

    return to_return
  end

  ## 
  # This method returns all the embedded objects in an AppleNote as an Array.
  def all_embedded_objects
    @embedded_objects + @embedded_objects_recursive
  end

  ##
  # Unique ID for the note — prefer UUID if available, fall back to database ID
  def unique_id(use_uuid)
    if use_uuid && !uuid.empty?
      @uuid
    else
      note_id
    end
  end

  ##
  # Generate a file name for exporting this note to an HTML file
  def title_as_filename(ext = '', use_uuid = false)
    file_title = title ? title.tr('[\\/*"<>?|:]\'', '_') : "Untitled"
    "#{unique_id(use_uuid)} - #{file_title}#{ext}"
  end

  ##
  # This method generates HTML to represent this Note, its 
  # metadata, and its contents, if applicable. It does not generate 
  # full HTML, just enough for this note's card to be displayed.
  def generate_html(individual_files: false, use_uuid: false)
    params = [individual_files, use_uuid]
    if @html && @html[params]
      return @html[params]
    end

    folder_href = "#folder_#{@folder.unique_id(use_uuid)}"
    if individual_files
      folder_href = Pathname.new("index.html")
    end

    builder = Nokogiri::HTML::Builder.new(encoding: "utf-8") do |doc|
      doc.div {
        doc.h1 {
          doc.a(id: "note_#{unique_id(use_uuid)}") {
            doc.text "Note #{unique_id(use_uuid)}#{" (📌)" if @is_pinned}"
          }
        }

        doc.div {
          doc.b {
            doc.text "Account:"
          }

          doc.text " "
          if individual_files
            doc.a(href: "#{@folder.to_account_root}index.html") {
              doc.text @account.name
            }
          else
            doc.text @account.name
          end
        }

        doc.div {
          doc.b {
            doc.text "Folder:"
          }

          doc.text " "
          doc << @folder.full_name_with_links(individual_files: individual_files, use_uuid: use_uuid, include_id: false)
        }

        doc.div {
          doc.b {
            doc.text "Title:"
          }

          doc.text " "
          doc.text @title
        }

        doc.div {
          doc.b {
            doc.text "Created:"
          }

          doc.text " "
          doc.text @creation_time
        }

        doc.div {
          doc.b {
            doc.text "Modified:"
          }

          doc.text " "
          doc.text @modify_time
        }

        tmp_cloudkit_creator = @notestore.cloud_kit_record_known?(@cloudkit_creator_record_id) if @notestore
        if tmp_cloudkit_creator
          doc.div {
            doc.b {
              doc.text "CloudKit Creator:"
            }

            doc.text " "
            doc.text tmp_cloudkit_creator.email
          }
        end

        tmp_cloudkit_modifier = @notestore.cloud_kit_record_known?(@cloudkit_modifier_record_id) if @notestore
        if tmp_cloudkit_modifier
          doc.div {
            doc.b {
              doc.text "CloudKit Last Modified User:"
            }

            doc.text " "
            doc.text tmp_cloudkit_modifier.email
          }
        end

        if @cloudkit_last_modified_device
          doc.div {
            doc.b {
              doc.text "CloudKit Last Modified Device:"
            }

            doc.text " "
            doc.text @cloudkit_last_modified_device
          }
        end

        if self.has_tags
          doc.div {
            doc.b {
              doc.text "Tags:"
            }

            doc.text " "
            doc.text self.get_all_tags.join(", ")
          }
        end

        if @widget_snippet
          doc.div {
            doc.b {
              doc.text "Widget Snippet:"
            }

            doc.text " "
            doc.text @widget_snippet
          }
        end

        doc.div(class: "note-content") {
          # Handle the text to insert, only if we have plaintext to run
          if @plaintext
            if @version.legacy?
              doc.text plaintext
            end

            if @version.modern?
              doc << generate_html_text(individual_files)
            end
          elsif @encrypted_data
            doc.text "{Contents not decrypted}"
          end
        }
      }
    end

    @html ||= {}
    @html[params] = builder.doc.root
  end

  ##
  # This helper function takes a MergableDataProto or NoteStoreProto as +document_proto+ and 
  # a Hash of AppleNotesEmbeddedObjects as +embedded_objects+. It returns a String containing 
  # appropriate HTML for the document.
  def self.htmlify_document(document_proto, embedded_objects, individual_files=false)
    node = Nokogiri::HTML5::DocumentFragment.parse("", nil, encoding: "utf-8")

    # Tables cells will be a MergableDataProto
    root_node = document_proto
    # Note objects will be a NoteStoreProto
    if document_proto.is_a? NoteStoreProto
      root_node = document_proto.document
    end

    # Set up variables for the run
    embedded_object_index = 0
    current_index = 0

    # Create a copy of the text, which is frozen
    note_text = root_node.note.note_text.dup

    # Create an Array to condense similar attribute runs into
    condensed_attribute_runs = Array.new()

    # Preprocess array to combine disparate parts that can be shoved together
    root_node.note.attribute_run.reverse!
    previous_run = nil
    while root_node.note.attribute_run.length > 0
      current_node = root_node.note.attribute_run.pop()

      # Start greedily grabbing every attribute run that looks like it matches the same style
      while current_node.same_style?(root_node.note.attribute_run.last)
        next_node = root_node.note.attribute_run.pop()
        # Extend the length by the length of the node we're removing
        current_node.length += next_node.length
      end

      # Add the lengthened attribute run to the Array
      condensed_attribute_runs.push(current_node)

      # Update the linked list pointers
      current_node.previous_run = previous_run
      previous_run.next_run = current_node if previous_run

      # Update the counter so we remember the "last" previous run
      previous_run = current_node
    end

    # Iterate over this smaller set when we know each attribute run can be self-contained
    condensed_attribute_runs.each_with_index do |note_part, attribute_run_index|

      # Check for something embedded, if so, don't put in the characters, replace them with the object
      if note_part.attachment_info

        if embedded_objects[embedded_object_index]
          node << embedded_objects[embedded_object_index].generate_html(individual_files)
        else
          node << Nokogiri::XML::Text.new("[Object missing, this is common for deleted notes]", node.document)
        end
        embedded_object_index += 1
        current_index += note_part.length

      else # We must have text to parse

        # Add in the slice of text represented by this run
        slice_to_add = note_text.slice(current_index, note_part.length)

        # Apple seems to be making Emojis and some other characters two characters
        # this breaks stuff. This is a really hacky solution.
        double_characters = 0
        slice_to_add.each_codepoint do |codepoint|
          double_characters += 1 if codepoint > 65535
        end

        if double_characters > 0
          slice_to_add = note_text.slice(current_index, note_part.length - double_characters)
        end
       
        # Calculate what the previous and next attribute runs are 
        previous_run = nil
        previous_run = condensed_attribute_runs[attribute_run_index - 1] if attribute_run_index > 0
        next_run = nil
        next_run = condensed_attribute_runs[attribute_run_index + 1] if attribute_run_index < condensed_attribute_runs.length - 1

        # Pull the HTML to insert
        note_part.generate_html(slice_to_add, node)

        # Increment our counter to be sure we don't loop infinitely
        current_index += (note_part.length - double_characters)

      end

    end

    node
  end

  ##
  # This function generates the HTML text to represent an overall AppleNote
  def generate_html_text(individual_files=false)
    # Bail out if we don't have anything to decode
    return html if !@decompressed_data

    # Decode the proto
    begin
      tmp_note_store_proto = NoteStoreProto.decode(@decompressed_data)
    rescue Exception
    end

    # Bail out if we don't have anything to decode
    return html if !tmp_note_store_proto
  
    # Now using a function designed specifically for turning attribute runs into HTML from anyy source  
    html = AppleNote.htmlify_document(tmp_note_store_proto, @embedded_objects, individual_files)
    return html
  end

  ##
  # This function prepares the data structure that JSON will use to create a JSON object. It does 
  # not directly create the JSON object in case this structure needs to be embedded somewhere else.
  def prepare_json
    to_return = Hash.new()
    to_return[:account_key] = @account.primary_key
    to_return[:account] = @account.name
    to_return[:folder_key] = @folder.primary_key
    to_return[:folder] = @folder.name
    to_return[:note_id] = @note_id
    to_return[:uuid] = @uuid
    to_return[:primary_key] = @primary_key
    to_return[:creation_time] = @creation_time
    to_return[:modify_time] = @modify_time
    to_return[:cloudkit_creator_id] = @cloudkit_creator_record_id
    to_return[:cloudkit_modifier_id] = @cloudkit_modifier_record_id
    to_return[:cloudkit_last_modified_device] = @cloudkit_last_modified_device
    to_return[:is_pinned] = @is_pinned
    to_return[:is_password_protected] = @is_password_protected
    to_return[:title] = @title
    to_return[:plaintext] = @plaintext if @plaintext
    to_return[:widget_snippet] = @widget_snippet if @widget_snippet
    to_return[:html] = generate_html
    to_return[:note_proto] = @note_proto if @note_proto

    # Add in any embedded objects of various types
    to_return[:embedded_objects] = Array.new()
    to_return[:hashtags] = Array.new()
    to_return[:mentions] = Array.new()
    @embedded_objects.each do |embedded_object|
      to_return[:embedded_objects].push(embedded_object.prepare_json)
      to_return[:hashtags].push(embedded_object.to_s) if embedded_object.is_a? AppleNotesEmbeddedInlineHashtag
      to_return[:mentions].push(embedded_object.to_s) if embedded_object.is_a? AppleNotesEmbeddedInlineMention
    end
  
    to_return
  end

end
