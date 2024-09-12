require_relative '../../lib/AppleNotesEmbeddedInlineAttachment.rb'
require_relative '../../lib/AppleNotesEmbeddedInlineLink.rb'
require_relative '../../lib/AppleNotesEmbeddedInlineHashtag.rb'
require_relative '../../lib/AppleNotesEmbeddedInlineMention.rb'


describe AppleNotesEmbeddedInlineAttachment, :missing_data => !TEST_FILE_VERSIONS_CURRENT_FILE_EXIST do
  before(:context) do
    TEST_OUTPUT_DIR.mkpath
    @tmp_backup = AppleBackupFile.new(TEST_FILE_VERSIONS[TEST_CURRENT_VERSION], TEST_OUTPUT_DIR)
    @tmp_notestore = AppleNoteStore.new(TEST_FILE_VERSIONS[TEST_CURRENT_VERSION], TEST_CURRENT_VERSION)
    @tmp_account = AppleNotesAccount.new(1, "Note Account", SecureRandom.uuid)
    @tmp_folder = AppleNotesFolder.new(2, "Note Folder", @tmp_account)
    @tmp_notestore.backup = @tmp_backup
    @tmp_notestore.open
    @tmp_note =  AppleNote.new(13, 
                               15, 
                               "Note Title", 
                               "", 
                               608413790, 
                               608413790, 
                               @tmp_account, 
                               @tmp_folder)
    @tmp_note.notestore = @tmp_notestore
  end

  after(:context) do
    TEST_OUTPUT_DIR.rmtree
  end

  let(:tmp_uuid) {SecureRandom.uuid}
  let(:tmp_attachment) {AppleNotesEmbeddedInlineAttachment.new(2,
                                                               tmp_uuid,
                                                               "type.uti",
                                                               @tmp_note,
                                                               "alt text",
                                                               "token identifier")}

  context "output" do
                                                                 
    it "Uses its alt text as the to_s output" do
      expect(tmp_attachment.to_s).to eql "alt text"
    end
                                                                 
    it "Creates a CSV array with the right number of fields to align with other objects" do
      expect(tmp_attachment.to_csv[0].length).to eql 11
      expect(tmp_attachment.to_csv[0][0]).to eql 2 # Primary key
      expect(tmp_attachment.to_csv[0][1]).to eql 15 # Note ID
      expect(tmp_attachment.to_csv[0][2]).to eql "" # Parent ID
      expect(tmp_attachment.to_csv[0][3]).to eql tmp_uuid # UUID
      expect(tmp_attachment.to_csv[0][4]).to eql "type.uti" # Type
      expect(tmp_attachment.to_csv[0][5]).to eql "" # Filename
      expect(tmp_attachment.to_csv[0][6]).to eql "" # Filepath on phone
      expect(tmp_attachment.to_csv[0][7]).to eql "" # Filepath on computer
      expect(tmp_attachment.to_csv[0][8]).to eql "" # User title
      expect(tmp_attachment.to_csv[0][9]).to eql "alt text" # Alt Text
      expect(tmp_attachment.to_csv[0][10]).to eql "token identifier" # Token Identifier
    end
                                                                 
    it "Creates appropriate JSON" do
      json_hash = tmp_attachment.prepare_json
      expect(json_hash[:alt_text]).to eql "alt text"
      expect(json_hash[:type]).to eql "type.uti"
      expect(json_hash[:token_identifier]).to eql "token identifier"
    end
  end

end

describe AppleNotesEmbeddedInlineLink, :missing_data => !TEST_FILE_VERSIONS_CURRENT_FILE_EXIST do
  before(:context) do
    TEST_OUTPUT_DIR.mkpath
    @tmp_backup = AppleBackupFile.new(TEST_FILE_VERSIONS[TEST_CURRENT_VERSION], TEST_OUTPUT_DIR)
    @tmp_notestore = AppleNoteStore.new(TEST_FILE_VERSIONS[TEST_CURRENT_VERSION], TEST_CURRENT_VERSION)
    @tmp_account = AppleNotesAccount.new(1, "Note Account", SecureRandom.uuid)
    @tmp_folder = AppleNotesFolder.new(2, "Note Folder", @tmp_account)
    @tmp_notestore.backup = @tmp_backup
    @tmp_notestore.open
    @tmp_note =  AppleNote.new(13, 
                               15, 
                               "Note Title", 
                               "", 
                               608413790, 
                               608413790, 
                               @tmp_account, 
                               @tmp_folder)
    @tmp_note.notestore = @tmp_notestore
  end

  after(:context) do
    TEST_OUTPUT_DIR.rmtree
  end

  let(:tmp_uuid) {SecureRandom.uuid}
  let(:tmp_attachment) {AppleNotesEmbeddedInlineLink.new(4,
                                                         tmp_uuid,
                                                         "com.apple.notes.inlinetextattachment.link",
                                                         @tmp_note,
                                                         "Testing Lists",
                                                         "applenotes:note/52ba26ae-aca5-42a3-9367-d3e2b12cc28e?ownerIdentifier=_0dbca911510b44ad94e80960aaf6c820")}

  context "output" do

    it "conforms to an inline attachment" do
      tmp_uti = AppleUniformTypeIdentifier.new(tmp_attachment.type)
      expect(tmp_uti.conforms_to_inline_attachment).to be true
    end

    it "Uses its alt text as the to_s output" do
      expect(tmp_attachment.to_s).to eql "Testing Lists [applenotes:note/52ba26ae-aca5-42a3-9367-d3e2b12cc28e?ownerIdentifier=_0dbca911510b44ad94e80960aaf6c820]"
    end

  end
end

describe AppleNotesEmbeddedInlineHashtag, :missing_data => !TEST_FILE_VERSIONS_CURRENT_FILE_EXIST do

  before(:context) do
    TEST_OUTPUT_DIR.mkpath
    @tmp_backup = AppleBackupFile.new(TEST_FILE_VERSIONS[TEST_CURRENT_VERSION], TEST_OUTPUT_DIR)
    @tmp_notestore = AppleNoteStore.new(TEST_FILE_VERSIONS[TEST_CURRENT_VERSION], TEST_CURRENT_VERSION)
    @tmp_account = AppleNotesAccount.new(1, "Note Account", SecureRandom.uuid)
    @tmp_folder = AppleNotesFolder.new(2, "Note Folder", @tmp_account)
    @tmp_notestore.backup = @tmp_backup
    @tmp_notestore.open
    @tmp_note =  AppleNote.new(13, 
                               15, 
                               "Note Title", 
                               "", 
                               608413790, 
                               608413790, 
                               @tmp_account, 
                               @tmp_folder)
    @tmp_note.notestore = @tmp_notestore
  end

  after(:context) do
    TEST_OUTPUT_DIR.rmtree
  end

  let(:tmp_uuid) {SecureRandom.uuid}
  let(:tmp_attachment) {AppleNotesEmbeddedInlineHashtag.new(3,
                                                            tmp_uuid,
                                                            "com.apple.notes.inlinetextattachment.mention",
                                                            @tmp_note,
                                                            "#Hashtag",
                                                            "HASHTAG")}

  context "output" do

    it "conforms to an inline attachment" do
      tmp_uti = AppleUniformTypeIdentifier.new(tmp_attachment.type)
      expect(tmp_uti.conforms_to_inline_attachment).to be true
    end

    it "Uses its alt text as the to_s output" do
      expect(tmp_attachment.to_s).to eql "#Hashtag"
    end

  end
end

describe AppleNotesEmbeddedInlineMention, :missing_data => !TEST_FILE_VERSIONS_CURRENT_FILE_EXIST do

  before(:context) do
    TEST_OUTPUT_DIR.mkpath
    @tmp_backup = AppleBackupFile.new(TEST_FILE_VERSIONS[TEST_CURRENT_VERSION], TEST_OUTPUT_DIR)
    @tmp_notestore = AppleNoteStore.new(TEST_FILE_VERSIONS[TEST_CURRENT_VERSION], TEST_CURRENT_VERSION)
    @tmp_account = AppleNotesAccount.new(1, "Note Account", SecureRandom.uuid)
    @tmp_folder = AppleNotesFolder.new(2, "Note Folder", @tmp_account)
    @tmp_notestore.backup = @tmp_backup
    @tmp_notestore.open
    @tmp_note =  AppleNote.new(13, 
                               15, 
                               "Note Title", 
                               "", 
                               608413790, 
                               608413790, 
                               @tmp_account, 
                               @tmp_folder)
    @tmp_note.notestore = @tmp_notestore
  end

  after(:context) do
    TEST_OUTPUT_DIR.rmtree
  end

  let(:tmp_uuid) {SecureRandom.uuid}
  let(:tmp_attachment) {AppleNotesEmbeddedInlineMention.new(4,
                                                            tmp_uuid,
                                                            "com.apple.notes.inlinetextattachment.mention",
                                                            @tmp_note,
                                                            "@Joe",
                                                            "_0dbca911510b44ad94e80960aaf6c820")}

  context "output" do

    it "conforms to an inline attachment" do
      tmp_uti = AppleUniformTypeIdentifier.new(tmp_attachment.type)
      expect(tmp_uti.conforms_to_inline_attachment).to be true
    end

    it "Uses its alt text as the to_s output" do
      expect(tmp_attachment.to_s).to eql "@Joe [_0dbca911510b44ad94e80960aaf6c820]"
    end

  end
end
