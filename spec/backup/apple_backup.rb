require_relative '../../lib/AppleBackup.rb'

describe AppleBackup, :expensive => true do
  before(:context) do
    TEST_OUTPUT_DIR.mkpath
  end
  after(:context) do 
    TEST_OUTPUT_DIR.rmtree
  end

  let(:backup) { AppleBackup.new(TEST_DATA_DIR, 0, TEST_OUTPUT_DIR) }

  context "validations" do
    it "raises an error rather than failing validation" do
      expect{backup.valid?}.to raise_error("AppleBackup cannot stand on its own")
    end

  end
  
  context "files" do 
    it "raises an error since it has no real file path" do
      expect{backup.get_real_file_path("test.tmp")}.to raise_error("Cannot return file_path for AppleBackup")
    end
  end
end
