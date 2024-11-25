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
  let(:test_files_to_find) { ["Accounts/LocalAccount/FallbackImages/8FD55434-3E94-4818-8784-132F41B480DD.jpg"] }

  context "validations" do
    it "validates a mac backup folder", :missing_data => !TEST_MAC_DIR_EXIST do
      expect(valid_backup.valid?).to be true
    end

    it "validates a mac backup folder without accounts", :missing_data => !TEST_MAC_NO_ACCOUNT_DIR_EXIST do
      expect(no_account_backup.valid?).to be true
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

  context "files with account folders", :missing_data => !TEST_MAC_DIR_EXIST do 
    it "knows how to find an appropriate file" do
      expect(valid_backup.get_real_file_path("NoteStore.sqlite").to_s).to match(/spec\/data\/mac_backup\/NoteStore.sqlite/)
      expect(valid_backup.find_valid_file_path(test_files_to_find).to_s).to match(/spec\/data\/mac_backup\/Accounts\/LocalAccount\/FallbackImages\/8FD55434-3E94-4818-8784-132F41B480DD.jpg/)
    end

    it "correctly identifies the use of an accounts folder when one exists" do
      expect(valid_backup.uses_account_folder).to be true
    end
  end

  context "files without account folders", :missing_data => !TEST_MAC_DIR_EXIST do 
    it "knows how to find an appropriate file" do
      expect(no_account_backup.get_real_file_path("NoteStore.sqlite").to_s).to match(/spec\/data\/mac_backup_no_account\/NoteStore.sqlite/)
      expect(no_account_backup.find_valid_file_path(test_files_to_find).to_s).to match(/spec\/data\/mac_backup_no_account\/FallbackImages\/8FD55434-3E94-4818-8784-132F41B480DD.jpg/)
    end

    it "correctly identifies the lack of an accounts folder when one doesn't exist" do
      expect(no_account_backup.uses_account_folder).to be false
    end
  end

  context "note stores", :missing_data => !TEST_MAC_DIR_EXIST do
    it "knows how to find just a modern note store" do 
      expect(valid_backup.note_stores.length).to be 1
    end
  end
end
