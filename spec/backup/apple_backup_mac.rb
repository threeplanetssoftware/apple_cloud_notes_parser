require_relative '../../lib/AppleBackupMac.rb'

describe AppleBackupMac, :expensive => true do
  before(:context) do
    TEST_OUTPUT_DIR.mkpath
  end
  after(:context) do 
    TEST_OUTPUT_DIR.rmtree
  end

  let(:valid_backup) { AppleBackupMac.new(TEST_MAC_DIR, TEST_OUTPUT_DIR) }
  let(:no_account_backup) { AppleBackupMac.new(TEST_MAC_NO_ACCOUNT_DIR, TEST_OUTPUT_DIR) }

  context "validations" do
    it "validates a mac backup folder", :missing_data => !TEST_MAC_DIR_EXIST do
      expect(valid_backup.valid?).to be true
    end

    it "validates a mac backup folder without accounts", :missing_data => !TEST_MAC_NO_ACCOUNT_DIR_EXIST do
      expect(no_account_backup.valid?).to be true
    end

    it "fails to validate an itunes backup folder", :missing_data => !TEST_ITUNES_DIR_EXIST do
      backup = AppleBackupMac.new(TEST_ITUNES_DIR, TEST_OUTPUT_DIR)
      expect(backup.valid?).to be false
    end

    it "fails to validate a physical backup folder", :missing_data => !TEST_PHYSICAL_DIR_EXIST do
      backup = AppleBackupMac.new(TEST_PHYSICAL_DIR, TEST_OUTPUT_DIR)
      expect(backup.valid?).to be false
    end

    it "fails to validate a valid NoteStore.sqlite file", :missing_data => !TEST_FORMATTING_FILE_EXIST do
      backup = AppleBackupMac.new(TEST_FORMATTING_FILE, TEST_OUTPUT_DIR)
      expect(backup.valid?).to be false
    end
  end

  context "files", :missing_data => !TEST_MAC_DIR_EXIST do 
    it "knows how to find an appropriate file" do
      expect(valid_backup.get_real_file_path("NoteStore.sqlite").to_s).to match(/spec\/data\/mac_backup\/NoteStore.sqlite/)
    end
  end

  context "note stores", :missing_data => !TEST_MAC_DIR_EXIST do
    it "knows how to find just a modern note store" do 
      expect(valid_backup.note_stores.length).to be 1
    end
  end
end
