require_relative '../../lib/AppleBackupHashed.rb'

describe AppleBackupHashed, :expensive => true do
  before(:context) do
    TEST_OUTPUT_DIR.mkpath
  end
  after(:context) do 
    TEST_OUTPUT_DIR.rmtree
  end

  let(:valid_backup) { AppleBackupHashed.new(TEST_ITUNES_DIR, TEST_OUTPUT_DIR) }

  context "validations" do
    it "validates an itunes backup folder", :missing_data => !TEST_ITUNES_DIR_EXIST do
      expect(valid_backup.valid?).to be true
    end

    it "fails to validate a physical backup folder", :missing_data => !TEST_PHYSICAL_DIR_EXIST do
      backup = AppleBackupHashed.new(TEST_PHYSICAL_DIR, TEST_OUTPUT_DIR)
      expect(backup.valid?).to be false
    end

    it "fails to validate a mac backup folder", :missing_data => !TEST_MAC_DIR_EXIST do
      backup = AppleBackupHashed.new(TEST_MAC_DIR, TEST_OUTPUT_DIR)
      expect(backup.valid?).to be false
    end

    it "fails to validate a valid NoteStore.sqlite file", :missing_data => !TEST_FORMATTING_FILE_EXIST do
      backup = AppleBackupHashed.new(TEST_FORMATTING_FILE, TEST_OUTPUT_DIR)
      expect(backup.valid?).to be false
    end
  end

  context "files", :missing_data => !TEST_ITUNES_DIR_EXIST do 
    it "knows how to find an appropriate file" do
      expect(valid_backup.get_real_file_path("NoteStore.sqlite").to_s).to match(/spec\/data\/itunes_backup\/4f\/4f98687d8ab0d6d1a371110e6b7300f6e465bef2/)
    end
  end

  context "note stores", :missing_data => !TEST_ITUNES_DIR_EXIST do
    it "knows how to find both legacy and modern note stores" do 
      expect(valid_backup.note_stores.length).to be 2
    end
  end
end
