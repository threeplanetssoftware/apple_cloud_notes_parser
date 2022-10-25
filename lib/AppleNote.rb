require 'cgi'
require 'keyed_archive'
require 'sqlite3'
require 'zlib'
require_relative 'notestore_pb.rb'
require_relative 'AppleCloudKitRecord'
require_relative 'AppleNotesEmbeddedObject.rb'
require_relative 'AppleDecrypter.rb'
require_relative 'AppleNotesEmbeddedInlineAttachment.rb'
require_relative 'AppleNotesEmbeddedInlineHashtag.rb'
require_relative 'AppleNotesEmbeddedInlineMention.rb'
require_relative 'AppleNotesEmbeddedDeletedObject.rb'
require_relative 'AppleNotesEmbeddedDocument.rb'
require_relative 'AppleNotesEmbeddedDrawing.rb'
require_relative 'AppleNotesEmbeddedGallery.rb'
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
                :backup,
                :crypto_password,
                :cloudkit_creator_record_id,
                :cloudkit_modify_device,
                :notestore,
                :is_pinned

  ##
  # Creates a new AppleNote. Expects an Integer +z_pk+, an Integer +znote+ representing the ZICNOTEDATA.ZNOTE field, 
  # a String +ztitle+ representing the ZICCLOUDSYNCINGOBJECT.ZTITLE field, a binary String +zdata+ representing the 
  # ZICNOTEDATA.ZDATA field, an Integer +creation_time+ representing the iOS CoreTime number found in ZICCLOUDSYNCINGOBJECT.ZCREATIONTIME1 field, 
  # an Integer +modify_time+ representing the iOS CoreTime number found in ZICCLOUDSYNCINGOBJECT.ZMODIFICATIONTIME1 field, 
  # an AppleNotesAccount +account+ representing the owning account, an AppleNotesFolder +folder+ representing the holding folder, 
  # and an AppleNoteStore +notestore+ representing the actual NoteStore
  # representing the full backup.
  def initialize(z_pk, znote, ztitle, zdata, creation_time, modify_time, account, folder, notestore)
    super()
    # Initialize some other variables while we're here
    @plaintext = nil
    @decompressed_data = nil
    @encrypted_data = nil
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
    @notestore = notestore
    @database = @notestore.database
    @backup = @notestore.backup
    @logger = @backup.logger

    # Handle pinning, added in iOS 11
    @is_pinned = false

    # Cache HTML once generated, useful for multiple outputs that all want the HTML
    @html = nil

    # Treat legacy stuff different
    if @notestore.version == AppleNoteStore::IOS_LEGACY_VERSION
      @plaintext = @compressed_data
      @compressed_data = nil
    else
      # Unpack what we can
      @is_compressed = is_gzip(zdata) 
      decompress_data if @is_compressed
      extract_plaintext if @decompressed_data
      replace_embedded_objects if @plaintext
    end
  end

  ##
  # This method returns the appropriate version for the AppleNote. 
  # It does this by checking the AppleNoteStore +@notestore+ and returning that.
  def version
    return @notestore.version if @notestore
    return AppleNoteStore::IOS_VERSION_UNKNOWN
  end

  ##
  # This method takes the +decompressed_data+ as an AppleNotesProto protobuf and 
  # assigned the plaintext from that protobuf into the +plaintext+ variable.
  def extract_plaintext
    if @decompressed_data
      begin
        tmp_note_store_proto = NoteStoreProto.decode(@decompressed_data)
        @plaintext = tmp_note_store_proto.document.note.note_text
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
    if @plaintext
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
     "Is Password protected",
     "Crypto Interations",
     "Crypto Salt (hex)",
     "Crypto Tag (hex)",
     "Crypto Key (hex)",
     "Crypto IV (hex)",
     "Encrypted Data (hex)"]
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
     @is_password_protected,
     @crypto_iterations,
     get_crypto_salt_hex,
     get_crypto_tag_hex,
     get_crypto_key_hex,
     get_crypto_iv_hex,
     get_encrypted_data_hex]
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
    /^\x1F\x8B/n.match(data) != nil
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
      @decompressed_data = zlib_inflater.inflate(@compressed_data)
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
      replace_embedded_objects if @plaintext
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
  # This method generates HTML to represent this Note, its 
  # metadata, and its contents, if applicable. It does not generate 
  # full HTML, just enough for this note's card to be displayed.
  def generate_html

    # Bail quickly if we've ever taken the time to build this before
    return @html if @html

    html = "<a id='note_#{@note_id}'><h1>Note #{@note_id}#{" (📌)" if @is_pinned}</h1></a>\n"
    html += "<b>Account:</b> #{@account.name} <br />\n"
    html += "<b>Folder:</b> <a href='#folder_#{@folder.primary_key}'>#{@folder.name}</a> <br/>\n"
    html += "<b>Title:</b> #{@title} <br/>\n"
    html += "<b>Created:</b> #{@creation_time} <br/>\n"
    html += "<b>Modified:</b> #{@modify_time} <br />\n"
    html += "<b>CloudKit Creator:</b> #{@notestore.cloud_kit_participants[@cloudkit_creator_record_id].email} <br />\n" if cloud_kit_record_known?(@cloudkit_creator_record_id, @notestore.cloud_kit_participants)
    html += "<b>CloudKit Last Modified User:</b> #{@notestore.cloud_kit_participants[@cloudkit_modifier_record_id].email} <br />\n" if cloud_kit_record_known?(@cloudkit_modifier_record_id, @notestore.cloud_kit_participants)
    html += "<b>CloudKit Last Modified Device:</b> #{@cloudkit_last_modified_device} <br />\n" if @cloudkit_last_modified_device
    html += "<b>Tags:</b> #{self.get_all_tags.join(", ")}<br />\n" if self.has_tags
    html += "<div class='note-content'>\n"

    # Handle the text to insert, only if we have plaintext to run
    if @plaintext
      html += "#{plaintext}" if @notestore.version == AppleNoteStore::IOS_LEGACY_VERSION
      html += generate_html_text if @notestore.version > AppleNoteStore::IOS_VERSION_9
    else
      html += "{Contents not decrypted}" if @encrypted_data
    end
    html += "</div> <!-- Close the 'note-content' div -->\n"

    @html = html
  end

  ##
  # This helper function takes a MergableDataProto or NoteStoreProto as +document_proto+ and 
  # a Hash of AppleNotesEmbeddedObjects as +embedded_objects+. It returns a String containing 
  # appropriate HTML for the document.
  def self.htmlify_document(document_proto, embedded_objects)
    html = ""

    # Tables cells will be a MergableDataProto
    root_node = document_proto
    # Note objects will be a NoteStoreProto
    if document_proto.is_a? NoteStoreProto
      root_node = document_proto.document
    end

    # Set up variables for the run
    embedded_object_index = 0
    current_index = 0
    current_style = -1

    # Create a copy of the text, which is frozen
    note_text = root_node.note.note_text.dup

    # Capture if we're in a checkbox, because they're special
    current_checkbox = nil

    # Iterate over the attribute runs to display stuffs
    root_node.note.attribute_run.each_with_index do |note_part, attribute_run_index|

      # Clean up open style tags
      stale_style = (!note_part.paragraph_style or (note_part.paragraph_style.style_type != current_style))
      if stale_style
        case current_style
        when STYLE_TYPE_TITLE
          html += "</h1>"
        when STYLE_TYPE_HEADING
          html += "</h2>"
        when STYLE_TYPE_SUBHEADING
          html += "</h3>"
        when STYLE_TYPE_MONOSPACED
          html += "</code>"
        when STYLE_TYPE_NUMBERED_LIST
          html += "</li></ol>"
        when STYLE_TYPE_DOTTED_LIST
          html += "</li></ul>"
        when STYLE_TYPE_DASHED_LIST
          html += "</li></ul>"
        end
      end

      # Check for something embedded, if so, don't put in the characters, replace them with the object
      if note_part.attachment_info

        if embedded_objects[embedded_object_index]
          html += embedded_objects[embedded_object_index].generate_html
        else
          html += "[Object missing, this is common for deleted notes]"
        end
        embedded_object_index += 1
        current_index += note_part.length
        current_style = -1

      else # We must have text to parse

        # Deal with styling
        if note_part.paragraph_style

          # Remember if we have a checkbox
          note_part_is_checkbox = note_part.paragraph_style.style_type == STYLE_TYPE_CHECKBOX

          # Remember if we have a list
          note_part_is_list = (note_part.paragraph_style.style_type == STYLE_TYPE_DASHED_LIST or note_part.paragraph_style.style_type == STYLE_TYPE_NUMBERED_LIST or note_part.paragraph_style.style_type == STYLE_TYPE_DOTTED_LIST)

          # Because similar checkboxes carry over past a line break, 
          # need to close it when we hit a different type
          if current_checkbox and !note_part_is_checkbox
            html += "</li></ul>\n"
            current_checkbox = nil
          end

          # Add in indents, this doesn't work so well
          indents = 0
          while indents < note_part.paragraph_style.indent_amount and !note_part_is_checkbox and !note_part_is_list do
            html += "\t"
            indents += 1
          end

          # Add new style
          needs_new_style = (attribute_run_index == 0 or (note_part.paragraph_style.style_type != current_style) or current_style == STYLE_TYPE_CHECKBOX)
          if needs_new_style
            case note_part.paragraph_style.style_type
            when STYLE_TYPE_TITLE
              html += "<h1>"
            when STYLE_TYPE_HEADING
              html += "<h2>"
            when STYLE_TYPE_SUBHEADING
              html += "<h3>"
            when STYLE_TYPE_MONOSPACED
              html += "<code>"
            when STYLE_TYPE_NUMBERED_LIST
              html += "<ol><li>"
            when STYLE_TYPE_DOTTED_LIST
              html += "<ul><li>"
            when STYLE_TYPE_DASHED_LIST
              html += "<ul><li>"
            when STYLE_TYPE_CHECKBOX

              # Set the style to apply to the list item
              style = "unchecked"
              style = "checked" if note_part.paragraph_style.checklist.done == 1

              # Open a list if we don't have a current one going
              if !current_checkbox
                html += "<ul class='checklist'><li class='#{style}'>"

              # Or just open a new list element
              elsif current_checkbox != note_part.paragraph_style.checklist.uuid
                html += "</li><li class='#{style}'>"
              end
              # Update our knowledge of the current checkbox
              current_checkbox = note_part.paragraph_style.checklist.uuid
            end
          end
          current_style = note_part.paragraph_style.style_type

        else
          # Clear the current style if we did NOT have any paragraph style information
          current_style = -1
        end

        # Add in font stuff
        case note_part.font_weight
        when FONT_TYPE_DEFAULT
          # Do nothing
        when FONT_TYPE_BOLD 
          html += "<b>"
        when FONT_TYPE_ITALIC
          html += "<i>"
        when FONT_TYPE_BOLD_ITALIC
          html += "<b><i>"
        end

        # Add in underlined
        if note_part.underlined == 1
          html += "<u>"
        end

        # Add in strikethrough
        if note_part.strikethrough == 1
          html += "<del>"
        end

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

        # Escape HTML in the actual text of the note
        slice_to_add = CGI::escapeHTML(slice_to_add)
        
        # Deal with newlines
        if (current_style == STYLE_TYPE_NUMBERED_LIST or current_style == STYLE_TYPE_DOTTED_LIST or current_style == STYLE_TYPE_DASHED_LIST)
          need_to_close_li = slice_to_add.end_with?("\n")
          slice_to_add = slice_to_add.split("\n").join("</li><li>")
          slice_to_add += "</li><li>" if need_to_close_li
        elsif current_style == STYLE_TYPE_CHECKBOX
          slice_to_add.gsub!("\n","")
        end

        # Add in links that are part of the text itself, doing this after cleaning the note so the <a> tag lives
        if note_part.link and note_part.link.length > 0
          slice_to_add = "<a href='#{note_part.link}' target='_blank'>#{slice_to_add}</a>"
        end

        html += slice_to_add

        # Increment our counter to be sure we don't loop infinitely
        current_index += (note_part.length - double_characters)

        # Close strikethrough
        if note_part.strikethrough == 1
          html += "</del>"
        end

        # Close underlined
        if note_part.underlined == 1
          html += "</u>"
        end

        # Close font stuff
        case note_part.font_weight
        when FONT_TYPE_DEFAULT
          # Do nothing
        when FONT_TYPE_BOLD
          html += "</b>"
        when FONT_TYPE_ITALIC
          html += "</i>"
        when FONT_TYPE_BOLD_ITALIC
          html += "</i></b>"
        end

      end

    end

    # Close any remaining styles
    case current_style
    when STYLE_TYPE_TITLE
      html += "</h1>"
    when STYLE_TYPE_HEADING
      html += "</h2>"
    when STYLE_TYPE_SUBHEADING
      html += "</h3>"
    when STYLE_TYPE_MONOSPACED
      html += "</code>"
    when STYLE_TYPE_NUMBERED_LIST
      html += "</li></ol>"
    when STYLE_TYPE_DOTTED_LIST
      html += "</li></ul>"
    when STYLE_TYPE_DASHED_LIST
      html += "</li></ul>"
    when STYLE_TYPE_CHECKBOX
      html += "</li></ul>"
    end

    # Remove any doubled tags
    html.gsub!('</h1><h1>','')
    html.gsub!('</h2><h2>','')
    html.gsub!('</h3><h3>','')
    html.gsub!('</code><code>','')
    html.gsub!('</b><b>','')
    html.gsub!('</i><i>','')
    html.gsub!('</u><u>','')
    html.gsub!('</del><del>','')
    html.gsub!('<li></li>','')
    html.gsub!('</ul><ul>','')
    html.gsub!(/<h1>\s*<\/h1>/,'') # Remove empty titles
    html.gsub!(/\n<\/h1>/,'</h1>') # Remove extra line breaks in front of h1
    html.gsub!(/\n<\/h2>/,'</h2>') # Remove extra line breaks in front of h2
    html.gsub!(/\n<\/h3>/,'</h3>') # Remove extra line breaks in front of h3
    html.gsub!("\u2028",'<br/>') # Translate \u2028 used to denote newlines in lists into an actual HTML line break

    html
  end

  ##
  # This function generates the HTML text to represent an overall AppleNote
  def generate_html_text
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
    html = AppleNote.htmlify_document(tmp_note_store_proto, @embedded_objects)
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
    to_return[:primary_key] = @primary_key
    to_return[:creation_time] = @creation_time
    to_return[:modify_time] = @modify_time
    to_return[:cloudkit_creator_id] = @cloudkit_creator_record_id
    to_return[:cloudkit_modifier_id] = @cloudkit_modifier_record_id
    to_return[:cloudkit_last_modified_device] = @cloudkit_last_modified_device
    to_return[:is_pinned] = @is_pinned
    to_return[:is_password_protected] = @is_password_protected
    to_return[:title] = @title
    to_return[:plaintext] = @plaintext
    to_return[:html] = generate_html

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
