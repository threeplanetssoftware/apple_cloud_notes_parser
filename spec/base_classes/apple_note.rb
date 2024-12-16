require_relative '../../lib/AppleNote.rb'

describe AppleNote do

  before(:context) do
    TEST_OUTPUT_DIR.mkpath
  end
  after(:context) do
    TEST_OUTPUT_DIR.rmtree
  end

  let(:tmp_backup) {AppleBackup.new(TEST_DATA_DIR, 0, TEST_OUTPUT_DIR)}
  let(:tmp_version) {AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_17, AppleNoteStoreVersion::VERSION_PLATFORM_IOS)}
  let(:tmp_notestore) {AppleNoteStore.new("", tmp_version)}
  let(:tmp_account) {AppleNotesAccount.new(1, "Note Account", SecureRandom.uuid)}
  let(:tmp_folder) {AppleNotesFolder.new(2, "Note Folder", tmp_account)}
  let(:sample_time) {Time.new(2020, 04, 12, 19, 49, 50, "UTC")}
  let(:tmp_note) {AppleNote.new(3, 
                               22, 
                               "Note Title", 
                               File.read(TEST_BLOB_DATA_DIR + "simple_note_protobuf_gzipped.bin"), 
                               608413790, 
                               608413790, 
                               tmp_account, 
                               tmp_folder)}
  let(:note_uuid) {SecureRandom.uuid}
  let(:old_note) {AppleNote.new(4, 
                               23, 
                               "Legacy Note", 
                               "Legacy notes have plaintext data", 
                               608413790, 
                               608413790, 
                               tmp_account, 
                               tmp_folder)}
  let(:parent_folder) {AppleNotesFolder.new(5, "Parent Note Folder", tmp_account)}
  let(:parent_folder2) {AppleNotesFolder.new(6, "Parent Note Folder 2", tmp_account)}

  context "creation" do
    it "is an unknown version at creation" do
      expect(tmp_note.version.version_number).to be AppleNoteStoreVersion::IOS_VERSION_UNKNOWN
    end

    it "is has an account at creation" do
      expect(tmp_note.account).to be tmp_account
    end

    it "is has a folder at creation" do
      expect(tmp_note.folder).to be tmp_folder
    end

    it "allows its version to be set" do
      tmp_note.version=(AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_17))
      expect(tmp_note.version.version_number).to be AppleNoteStoreVersion::IOS_VERSION_17
    end

    it "returns the UUID as unique identifier if desired" do
      tmp_note.uuid = note_uuid
      expect(tmp_note.unique_id(true)).to be note_uuid
    end

    it "returns the note ID as unique identifier if desired" do
      tmp_note.uuid = note_uuid
      expect(tmp_note.unique_id(false)).to be 22
    end

    it "correctly changes the core time to a Time object" do 
      expect(tmp_note.creation_time).to eql sample_time
      expect(tmp_note.modify_time).to eql sample_time
    end

    it "starts with gzipped data" do 
      expect(tmp_note.is_gzip(tmp_note.instance_variable_get(:@compressed_data))).to be true
    end
  end

  context "helpers" do

    let(:gzipped_data) { "\x1f\x8Bdata_goes_here" }

    it "recognizes GZIP'd data" do
      expect(tmp_note.is_gzip(gzipped_data)).to be true
    end

    it "does not recognize non-GZIP'd data" do
      expect(tmp_note.is_gzip("Sqlite3")).to be false
    end

    it "does not blow up with nil data" do
      expect(tmp_note.is_gzip(nil)).to be false
    end

    it "does not blow up with non-String data" do
      expect(tmp_note.is_gzip(Hash.new)).to be false
    end

    it "correctly converts core time" do
      expect(tmp_note.convert_core_time(608413790)).to eql(sample_time)
    end

    it "nicely handles negative core time" do
      expect(tmp_note.convert_core_time(nil)).to eql(Time.new(1970, 01, 01, 0, 0, 0, 'UTC') )
    end

  end

  context "decryption" do

    it "starts without cryptographic settings" do
      expect(tmp_note.has_cryptographic_variables?).to be false
    end

  end

  context "contents" do
    it "politely warns if the text has not yet been decompressed" do
      expect(tmp_note.get_note_contents).to eql "Error, note not yet decompressed"
    end

    it "politely warns if the text has not yet been turned into plaintext" do
      tmp_note.decompress_data
      expect(tmp_note.get_note_contents).to eql "Error, note not yet plaintexted"
    end
  
    it "keeps legacy note text unchanged" do
      old_note.version=(AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_LEGACY_VERSION))
      old_note.process_note
      expect(old_note.plaintext).to eql("Legacy notes have plaintext data")
      expect(old_note.instance_variable_get(:@compressed_data)).to be nil
    end
  
    it "properly decompresses the gzipped copy of modern notes" do
      tmp_note.decompress_data
      expected_data = File.read(TEST_BLOB_DATA_DIR + "simple_note_protobuf.bin")
      expect(tmp_note.decompressed_data.force_encoding("UTF-8")).to eql(expected_data)
    end
  
    it "properly extracts text from the protobuf of modern notes" do
      tmp_note.decompress_data
      tmp_note.extract_plaintext
      expect(tmp_note.plaintext).to eql("Title")
    end
  
    it "can one-shot the text extraction process" do
      tmp_notestore.backup=(tmp_backup)
      tmp_note.notestore=(tmp_notestore)
      tmp_note.process_note
      expect(tmp_note.plaintext).to eql("Title")
    end
  end

  context "specific examples" do
    it "handles different colors appropriately" do
      binary_plist = File.read(TEST_BLOB_DATA_DIR + "color_formatting_gzipped.bin")
      tmp_note = AppleNote.new(13,
                               310, 
                               "Color Formatting",
                               binary_plist,
                               608413790, 
                               608413790, 
                               tmp_account, 
                               tmp_folder)
      tmp_note.version=(AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_16))
      tmp_notestore.backup=(tmp_backup)
      tmp_note.notestore=(tmp_notestore)
      tmp_note.process_note
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        html = tmp_note.generate_html(individual_files: option[0], use_uuid: option[1]).to_html
        expect(html).not_to include("<b></b>")
        expect(html).not_to include("<i></i>")
        expect(html).not_to include("<u></u>")
        expect(html).not_to include("<sup></sup>")
        expect(html).to include "<span style=\"color: #FF0000\">Red</span>"
        expect(html).to include "<span style=\"color: #42A9FF\">Blue</span>"
        expect(html).to include "<li class=\"unchecked\">Checklist, unchecked, <span style=\"color: #FF561C\">red</span> in the middle</li>"
        expect(html).to include "<sup><span style=\"color: #FF2121\">red</span></sup>"
        expect(html).to include "<b><span style=\"color: #FF4A1D\">bold red</span></b>"
      end
    end

    it "handles wide characters appropriately" do
      binary_plist = File.read(TEST_BLOB_DATA_DIR + "wide_characters_gzipped.bin")
      tmp_note = AppleNote.new(14,
                               151, 
                               "Wide Characters",
                               binary_plist,
                               608413790, 
                               608413790, 
                               tmp_account, 
                               tmp_folder)
      tmp_note.version=(AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_16))
      tmp_notestore.backup=(tmp_backup)
      tmp_note.notestore=(tmp_notestore)
      tmp_note.process_note
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        html = tmp_note.generate_html(individual_files: option[0], use_uuid: option[1]).to_html
        expect(html).to include "但他還是希望"
        expect(html).to include "體驗看法覺得很大"
      end
    end

    it "escapes HTML appropriately" do
      binary_plist = File.read(TEST_BLOB_DATA_DIR + "html_gzipped.bin")
      tmp_note = AppleNote.new(15,
                               312, 
                               "HTML Test",
                               binary_plist,
                               608413790, 
                               608413790, 
                               tmp_account, 
                               tmp_folder)
      tmp_note.version=(AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_16))
      tmp_notestore.backup=(tmp_backup)
      tmp_note.notestore=(tmp_notestore)
      tmp_note.process_note
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        html = tmp_note.generate_html(individual_files: option[0], use_uuid: option[1]).to_html
        expect(html).not_to include "<HTML>"
        expect(html).not_to include "<script src=‘evil.js’>"
        expect(html).to include "&lt;HTML&gt;"
      end
    end

    it "handles emojis and text formatting" do
      binary_plist = File.read(TEST_BLOB_DATA_DIR + "emoji_formatting_1_gzipped.bin")
      tmp_note = AppleNote.new(16,
                               443, 
                               "Emoji Formatting 1",
                               binary_plist,
                               608413790, 
                               608413790, 
                               tmp_account, 
                               tmp_folder)
      tmp_note.version=(AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_16))
      tmp_notestore.backup=(tmp_backup)
      tmp_note.notestore=(tmp_notestore)
      tmp_note.process_note
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        html = tmp_note.generate_html(individual_files: option[0], use_uuid: option[1]).to_html
        expect(html).to include("<b>1🚀2🕹️3💻4🖥️5🧑</b>").once
        expect(html).to include("🚀1🚀2🕹️3💻4🖥️5🧑‍💻6👩‍💻7").once
        expect(html).to include("<i>👩‍💻7</i>").once
        expect(html).to include("<u>🚀1🚀2🕹️3💻4🖥</u>").once
        expect(html).to include("<pre>🧑‍💻6👩‍💻7\n\n🚀1🚀2🕹️3💻4</pre>").once
        expect(html).not_to include "<b></b>"
        expect(html).not_to include "<u></u>"
        expect(html).not_to include "<i></i>"
      end
    end

    it "handles emojis and links" do
      binary_plist = File.read(TEST_BLOB_DATA_DIR + "emoji_formatting_2_gzipped.bin")
      tmp_note = AppleNote.new(17,
                               455, 
                               "Emoji Formatting 2",
                               binary_plist,
                               608413790, 
                               608413790, 
                               tmp_account, 
                               tmp_folder)
      tmp_note.version=(AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_16))
      tmp_notestore.backup=(tmp_backup)
      tmp_note.notestore=(tmp_notestore)
      tmp_note.process_note
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        html = tmp_note.generate_html(individual_files: option[0], use_uuid: option[1]).to_html
        expect(html).to include "<a href=\"https://ciofecaforensics.com\" target=\"_blank\">projects</a>"
        expect(html).to include "<b>Graphic Designer 💻 from Stockport, UK</b>"
        expect(html).to include "<blockquote class=\"block-quote\" data-apple-notes-indent-amount=\"1\">"
        expect(html).to include "<br>Email<br>"
        expect(html).not_to include "<b></b>"
        expect(html).not_to include "<u></u>"
        expect(html).not_to include "<i></i>"
      end
    end

    it "handles emojis and formatting offsets" do
      binary_plist = File.read(TEST_BLOB_DATA_DIR + "emoji_formatting_3_gzipped.bin")
      tmp_note = AppleNote.new(16,
                               445, 
                               "Emoji Formatting 3",
                               binary_plist,
                               608413790, 
                               608413790, 
                               tmp_account, 
                               tmp_folder)
      tmp_note.version=(AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_16))
      tmp_notestore.backup=(tmp_backup)
      tmp_note.notestore=(tmp_notestore)
      tmp_note.process_note
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        html = tmp_note.generate_html(individual_files: option[0], use_uuid: option[1]).to_html
        expect(html).to include("<b>bold</b>").at_least(3).times
        expect(html).to include("<i>italic</i>").at_least(3).times
        expect(html).to include("<u>underlined</u>").at_least(3).times
        expect(html).to include("<br>🖤 🖤 <br>")
        expect(html).to include("<br>🖤 <br>")
        expect(html).not_to include "<b></b>"
        expect(html).not_to include "<u></u>"
        expect(html).not_to include "<i></i>"
      end
    end

    # This reflects a missing list marker. The issue appears to be that the 
    # class for the dashed list gets overridden to "none", likely from this 
    # code in protoPatches.rb: level_tag_attrs[:class] = "none"
    xit "shows lists properly" do
      pending("Need to fix indents in ProtoPatches.rb")
      binary_plist = File.read(TEST_BLOB_DATA_DIR + "list_indents_gzipped.bin")
      tmp_note = AppleNote.new(17,
                               318, 
                               "List Indents",
                               binary_plist,
                               608413790, 
                               608413790, 
                               tmp_account, 
                               tmp_folder)
      tmp_note.version=(AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_16))
      tmp_notestore.backup=(tmp_backup)
      tmp_note.notestore=(tmp_notestore)
      tmp_note.process_note
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        html = tmp_note.generate_html(individual_files: option[0], use_uuid: option[1]).to_html
        expect(html).to include "<ul class=\"dotted\" data-apple-notes-indent-amount=\"1\"><li>Dotted list second indent</li></ul>"
        expect(html).to include "<li><ul class=\"dashed\" data-apple-notes-indent-amount=\"1\"><li>Dashed list indent 2</li></ul></li>"
        expect(html).to include "<ol data-apple-notes-indent-amount=\"1\"><li>Numbers list indent 2</li></ol>"
        expect(html).to include("data-apple-notes-indent-amount=\"0\"").exactly(4).times
        expect(html).to include("data-apple-notes-indent-amount=\"1\"").exactly(4).times
        expect(html).to include("data-apple-notes-indent-amount=\"2\"").once
        expect(html).not_to include("<ul class=\"none\"") 
      end
    end

    # It appears ProtoPatches.rb doesn't include a blockquote tag if the 
    # active node is monostyled (if paragraph_style&.normalized_indent_amount.to_i 
    # > 0 && @active_html_node.node_name != "pre"). Need to fix that.
    xit "shows blockquotes properly" do
      pending("Need to fix blockquotes in monostyle")
      binary_plist = File.read(TEST_BLOB_DATA_DIR + "block_quotes_gzipped.bin")
      tmp_note = AppleNote.new(18,
                               366, 
                               "Block Quotes",
                               binary_plist,
                               608413790, 
                               608413790, 
                               tmp_account, 
                               tmp_folder)
      tmp_note.version=(AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_16))
      tmp_notestore.backup=(tmp_backup)
      tmp_note.notestore=(tmp_notestore)
      tmp_note.process_note
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        html = tmp_note.generate_html(individual_files: option[0], use_uuid: option[1]).to_html
        expect(html).to include("<blockquote class=\"block-quote\" data-apple-notes-indent-amount=\"1\">This is a block quote<br>")
        expect(html).to include("<pre>This is monostyled\n</pre>")
        expect(html).to include("<blockquote class=\"block-quote\" data-apple-notes-indent-amount=\"1\"><pre>This is a monostyled blockquote\n</pre></blockquote>")
      end
    end

    it "handles links as text decoration" do
      binary_plist = File.read(TEST_BLOB_DATA_DIR + "url_gzipped.bin")
      tmp_note = AppleNote.new(18,
                               349, 
                               "URL Decoration",
                               binary_plist,
                               608413790, 
                               608413790, 
                               tmp_account, 
                               tmp_folder)
      tmp_note.version=(AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_16))
      tmp_notestore.backup=(tmp_backup)
      tmp_note.notestore=(tmp_notestore)
      tmp_note.process_note
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        html = tmp_note.generate_html(individual_files: option[0], use_uuid: option[1]).to_html
        expect(html).to include "<b><a href=\"https://en.m.wikipedia.org/wiki/Jim_Nettles\" target=\"_blank\">Jim Nettles</a></b>"
        expect(html).to include "<a href=\"https://en.m.wikipedia.org/wiki/Graig_Nettles\" target=\"_blank\">his older brother</a>"
        expect(html).to include("_blank").exactly(4).times
      end
    end
  end

  context "output" do
    it "caches results to make things quicker" do
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        if tmp_note.instance_variable_get(:@html)
          expect(tmp_note.instance_variable_get(:@html)[option]).to be nil
        end
        tmp_note.generate_html(individual_files: option[0], use_uuid: option[1])
        expect(tmp_note.instance_variable_get(:@html)[option]).to be_a Nokogiri::XML::Element
      end
    end

    it "creates a JSON Hash even if the note text hasn't processed" do
      expect(tmp_note.prepare_json).to be_a(Hash)
    end

    it "creates HTML even if the note text hasn't processed" do
      expect(tmp_note.generate_html).to be_a(Nokogiri::XML::Element)
    end

    it "includes the UUID instead of the note ID if use_uuid is passed" do
      tmp_note.uuid = note_uuid
      expect(tmp_note.generate_html(individual_files: false, use_uuid: true).to_html).to include("Note #{note_uuid}")
      expect(tmp_note.generate_html(individual_files: true, use_uuid: true).to_html).to include("Note #{note_uuid}")
    end

    it "includes the Note ID instead of the UUID if use_uuid is false" do
      tmp_note.uuid = note_uuid
      expect(tmp_note.generate_html(individual_files: true, use_uuid: false).to_html).to include("Note #{tmp_note.note_id}")
      expect(tmp_note.generate_html(individual_files: false, use_uuid: false).to_html).to include("Note #{tmp_note.note_id}")
    end

    it "includes the Account name in the HTML" do
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        expect(tmp_note.generate_html(individual_files: option[0], use_uuid: option[1]).text).to include("Account: #{tmp_note.account.name}")
      end
    end

    # This should really be tested in Account since the link may be further up
    it "includes the Account name in the HTML if individual_files is chosen" do
      expect(tmp_note.generate_html(individual_files: true).to_html).to include("<b>Account:</b> <a href=\"../index.html\">#{tmp_note.account.name}</a>")
    end

    it "includes the Folder name in the HTML" do
      expect(tmp_note.generate_html.text).to include("Folder: #{tmp_note.folder.name}")
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        expect(tmp_note.generate_html(individual_files: option[0], use_uuid: option[1]).text).to include("Folder: #{tmp_note.folder.name}")
      end
    end

    it "includes the note title in the HTML" do
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        expect(tmp_note.generate_html(individual_files: option[0], use_uuid: option[1]).to_html).to include("<b>Title:</b> #{tmp_note.title}")
      end
    end

    it "includes the note creation time in the HTML" do
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        expect(tmp_note.generate_html(individual_files: option[0], use_uuid: option[1]).to_html).to include("<b>Created:</b> #{tmp_note.creation_time.to_s}")
      end
    end

    it "includes the note modify time in the HTML" do
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        expect(tmp_note.generate_html(individual_files: option[0], use_uuid: option[1]).to_html).to include("<b>Modified:</b> #{tmp_note.modify_time.to_s}")
      end
    end

    it "includes a pin if the note is pinned" do
      tmp_note.is_pinned=(true)
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        expect(tmp_note.generate_html(individual_files: option[0], use_uuid: option[1]).to_html).to include("📌")
      end
    end

    it "does not include a pin if the note is not pinned" do
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        expect(tmp_note.generate_html(individual_files: option[0], use_uuid: option[1]).to_html).not_to include("📌")
      end
    end

    it "links to the anchor link if individual_files is not set" do
      tmp_uuid = SecureRandom.uuid
      tmp_folder.uuid = tmp_uuid
      expect(tmp_note.generate_html(individual_files: false).to_html).to include("<b>Folder:</b> <span><a href=\"#folder_2\">#{tmp_note.folder.name}</a></span>")
      expect(tmp_note.generate_html(individual_files: false, use_uuid: true).to_html).to include("<b>Folder:</b> <span><a href=\"#folder_#{tmp_uuid}\">#{tmp_note.folder.name}</a></span>")
    end

    it "includes a link to the Folder index HTML if individual files are chosen" do
      expect(tmp_note.generate_html(individual_files: true).to_html).to include("<b>Folder:</b> <span><a href=\"index.html\">#{tmp_note.folder.name}</a></span>")
    end

    it "appropriately reflects the heirarchy of folders that have parents" do
      parent_folder.add_child(parent_folder2)
      parent_folder2.add_child(tmp_folder)
      expect(tmp_note.generate_html.text).to include("Folder: #{parent_folder.name} -> #{parent_folder2.name} -> #{tmp_note.folder.name}")
    end

    it "does not include the Cloudkit Creator section if one does not exist" do
      expect(tmp_note.generate_html.text).not_to include("Cloudkit Creator")
    end

    xit "includes the Cloudkit Creator section if one exists" do
      tmp_notestore.backup=(tmp_backup)
      tmp_note.notestore=(tmp_notestore)
      binary_plist = File.read(TEST_BLOB_DATA_DIR + "ZSERVERSHAREDATA.bin")
      tmp_note.add_cloudkit_server_record_data(binary_plist)
      tmp_note.share_participants.each do |participant|
        tmp_notestore.cloud_kit_participants[participant.record_id] = participant
      end
      expect(tmp_note.generate_html.text).to include("Cloudkit Creator: asd")
    end

    it "does not include the Cloudkit Modifier section if one does not exist" do
      expect(tmp_note.generate_html.text).not_to include("Cloudkit Last Modified User")
    end

    xit "includes the Cloudkit Modifier section if one exists" do
      binary_plist = File.read(TEST_BLOB_DATA_DIR + "ZSERVERSHAREDATA.bin")
      tmp_note.add_cloudkit_server_record_data(binary_plist)
      expect(tmp_note.generate_html.text).to include("Cloudkit Modifier: asd")
    end

    it "does not include the last modified device section if one does not exist" do
      expect(tmp_note.generate_html.text).not_to include("CloudKit Last Modified Device")
    end

    it "includes the last modified device section if one exists" do
      binary_plist = File.read(TEST_BLOB_DATA_DIR + "ZSERVERRECORDDATA.bin")
      tmp_note.add_cloudkit_server_record_data(binary_plist)
      expect(tmp_note.generate_html.text).to include("CloudKit Last Modified Device: Tester’s iPhone")
    end
  end

end
