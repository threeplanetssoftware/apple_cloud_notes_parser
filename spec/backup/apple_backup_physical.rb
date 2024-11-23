require_relative '../../lib/AppleBackupPhysical.rb'

describe AppleBackupPhysical, :expensive => true do
  before(:context) do
    TEST_OUTPUT_DIR.mkpath
  end
  after(:context) do 
    TEST_OUTPUT_DIR.rmtree
  end

  let(:valid_backup) { AppleBackupPhysical.new(TEST_PHYSICAL_DIR, TEST_OUTPUT_DIR) }
  let(:no_accounts_backup) { AppleBackupPhysical.new(TEST_PHYSICAL_NO_ACCOUNT_DIR, TEST_OUTPUT_DIR) }
  let(:test_files_to_find) { ["Accounts/LocalAccount/FallbackImages/8FD55434-3E94-4818-8784-132F41B480DD.jpg"] }

  context "validations" do
    it "validates a physical backup folder", :missing_data => !TEST_PHYSICAL_DIR_EXIST do
      expect(valid_backup.valid?).to be true
    end

    it "fails to validate an itunes backup folder", :missing_data => !TEST_ITUNES_DIR_EXIST do
      backup = AppleBackupPhysical.new(TEST_ITUNES_DIR, TEST_OUTPUT_DIR)
      expect(backup.valid?).to be false
    end

    it "fails to validate a mac backup folder", :missing_data => !TEST_MAC_DIR_EXIST do
      backup = AppleBackupPhysical.new(TEST_MAC_DIR, TEST_OUTPUT_DIR)
      expect(backup.valid?).to be false
    end

    it "fails to validate a valid NoteStore.sqlite file", :missing_data => !TEST_FORMATTING_FILE_EXIST do
      backup = AppleBackupPhysical.new(TEST_FORMATTING_FILE, TEST_OUTPUT_DIR)
      expect(backup.valid?).to be false
    end
  end

  context "files with accounts", :missing_data => !TEST_PHYSICAL_DIR_EXIST do 
    it "knows how to find an appropriate file" do
      expect(valid_backup.get_real_file_path("NoteStore.sqlite").to_s).to match(/private\/var\/mobile\/Containers\/Shared\/AppGroup\/[A-F0-9\-]{36}\/NoteStore.sqlite/)
      expect(valid_backup.find_valid_file_path(test_files_to_find).to_s).to match(/private\/var\/mobile\/Containers\/Shared\/AppGroup\/[A-F0-9\-]{36}\/Accounts\/LocalAccount\/FallbackImages\/8FD55434-3E94-4818-8784-132F41B480DD.jpg/)
    end

    it "correctly identifies the use of an accounts folder when one exists" do
      expect(valid_backup.uses_account_folder).to be true
    end
  end

  context "files without accounts", :missing_data => !TEST_PHYSICAL_NO_ACCOUNT_DIR_EXIST do 
    it "knows how to find an appropriate file" do
      expect(no_accounts_backup.get_real_file_path("NoteStore.sqlite").to_s).to match(/private\/var\/mobile\/Containers\/Shared\/AppGroup\/[A-F0-9\-]{36}\/NoteStore.sqlite/)
      expect(no_accounts_backup.find_valid_file_path(test_files_to_find).to_s).to match(/private\/var\/mobile\/Containers\/Shared\/AppGroup\/[A-F0-9\-]{36}\/FallbackImages\/8FD55434-3E94-4818-8784-132F41B480DD.jpg/)
    end

    it "correctly identifies the lack of an accounts folder when one does not exist" do
      expect(no_accounts_backup.uses_account_folder).to be false
    end
  end

  context "note stores", :missing_data => !TEST_PHYSICAL_DIR_EXIST do
    it "knows how to find both legacy and modern note stores" do 
      expect(valid_backup.note_stores.length).to be 2
    end
  end
end
