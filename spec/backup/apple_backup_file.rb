require_relative '../../lib/AppleBackupFile.rb'

describe AppleBackupFile, :expensive => true do
  before(:context) do
    TEST_OUTPUT_DIR.mkpath
  end
  after(:context) do 
    TEST_OUTPUT_DIR.rmtree
  end

  let(:valid_backup) { AppleBackupFile.new(TEST_FORMATTING_FILE, TEST_OUTPUT_DIR) }

  context "validations" do
    it "validates a NoteStore.sqlite file", :missing_data => !TEST_FORMATTING_FILE_EXIST do
      expect(valid_backup.valid?).to be true
    end

    xit "fails to validate a non-NoteStore sqlite file", :missing_data => !TEST_FALSE_SQLITE_FILE_EXIST do
      backup = AppleBackupFile.new(TEST_FALSE_SQLITE_FILE, TEST_OUTPUT_DIR)
      expect(backup.valid?).to be false
    end

    it "fails to validate a non-sqlite file", :missing_data => !TEST_README_FILE_EXIST do
      backup = AppleBackupFile.new(TEST_README_FILE, TEST_OUTPUT_DIR)
      expect(backup.valid?).to be false
    end

    it "fails to validate an itunes backup folder", :missing_data => !TEST_ITUNES_DIR_EXIST do
      backup = AppleBackupFile.new(TEST_ITUNES_DIR, TEST_OUTPUT_DIR)
      expect(backup.valid?).to be false
    end

    it "fails to validate a physical backup folder", :missing_data => !TEST_PHYSICAL_DIR_EXIST do
      backup = AppleBackupFile.new(TEST_PHYSICAL_DIR, TEST_OUTPUT_DIR)
      expect(backup.valid?).to be false
    end

    it "fails to validate a mac backup folder", :missing_data => !TEST_MAC_DIR_EXIST do
      backup = AppleBackupFile.new(TEST_MAC_DIR, TEST_OUTPUT_DIR)
      expect(backup.valid?).to be false
    end
  end

  context "versions" do

    it "correctly identifies all major versions" do
      # To do: acquire iOS 11 sample for here
      TEST_FILE_VERSIONS.each_pair do |version, version_file|
        backup = AppleBackupFile.new(version_file, TEST_OUTPUT_DIR)
        expect(backup.note_stores[0].version.version_number).to be version
      end
    end
  end

  context "files", :missing_data => !TEST_FORMATTING_FILE_EXIST do 
    it "does not try to assert where a file is" do
      backup = AppleBackupFile.new(TEST_FORMATTING_FILE, TEST_OUTPUT_DIR)
      expect(valid_backup.get_real_file_path("NoteStore.sqlite")).to be nil
    end
  end

  context "note stores", :missing_data => !TEST_FORMATTING_FILE_EXIST do
    it "knows how to find just a modern note store" do 
      expect(valid_backup.note_stores.length).to be 1
    end
  end
end
