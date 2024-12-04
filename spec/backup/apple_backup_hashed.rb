require_relative '../../lib/AppleBackupHashed.rb'

describe AppleBackupHashed, :expensive => true do
  before(:context) do
    TEST_OUTPUT_DIR.mkpath
  end
  after(:context) do 
    TEST_OUTPUT_DIR.rmtree
  end

  let(:valid_backup) { AppleBackupHashed.new(TEST_ITUNES_DIR, TEST_OUTPUT_DIR) }
  let(:no_account_backup) { AppleBackupHashed.new(TEST_ITUNES_NO_ACCOUNT_DIR, TEST_OUTPUT_DIR) }
  let(:test_files_to_find) { ["Accounts/LocalAccount/FallbackImages/8FD55434-3E94-4818-8784-132F41B480DD.jpg"] }

  context "validations" do
    it "validates an itunes backup folder", :missing_data => !TEST_ITUNES_DIR_EXIST do
      expect(valid_backup.valid?).to be true
    end

    it "validates an itunes backup folder without accounts", :missing_data => !TEST_ITUNES_NO_ACCOUNT_DIR_EXIST do
      expect(no_account_backup.valid?).to be true
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

  context "files with account folders", :missing_data => !TEST_ITUNES_DIR_EXIST do 
    it "knows how to find an appropriate file" do
      expect(valid_backup.get_real_file_path("NoteStore.sqlite").to_s).to match(/spec\/data\/itunes_backup\/4f\/4f98687d8ab0d6d1a371110e6b7300f6e465bef2/)
      expect(valid_backup.find_valid_file_path(test_files_to_find).backup_location.to_s).to match(/spec\/data\/itunes_backup\/10\/1097c74e05dccdf5bd77ca48d22f6116854b78d2/)
    end

    it "correctly identifies the use of an accounts folder when one exists" do
      expect(valid_backup.uses_account_folder).to be true
    end
  end

  context "files without account folders", :missing_data => !TEST_ITUNES_NO_ACCOUNT_DIR_EXIST do 
    it "knows how to find an appropriate file" do
      expect(no_account_backup.get_real_file_path("NoteStore.sqlite").to_s).to match(/spec\/data\/itunes_backup_no_account\/4f\/4f98687d8ab0d6d1a371110e6b7300f6e465bef2/)
      expect(no_account_backup.find_valid_file_path(test_files_to_find).backup_location.to_s).to match(/spec\/data\/itunes_backup_no_account\/fc\/fc97b386b2a39b503682d5fb9c20f684dfe1ed93/)
    end

    it "correctly identifies the lack of an accounts folder when one doesn't exist" do
      expect(no_account_backup.uses_account_folder).to be false
    end
  end

  context "note stores", :missing_data => !TEST_ITUNES_DIR_EXIST do
    it "knows how to find both legacy and modern note stores" do 
      expect(valid_backup.note_stores.length).to be 2
    end
  end
end
