require_relative '../../lib/AppleCloudKitRecord.rb'

describe AppleCloudKitRecord do

  let(:cloud_kit_record) { AppleCloudKitRecord.new }
  let(:empty_cloud_kit_record) { AppleCloudKitRecord.new }

  context "server record data" do
    it "identifies the last modified information" do 
      binary_plist = File.read(TEST_BLOB_DATA_DIR + "ZSERVERRECORDDATA.bin")
      cloud_kit_record.add_cloudkit_server_record_data(binary_plist)
      expect(cloud_kit_record.cloudkit_last_modified_device).to eql("Tester’s iPhone")
      expect(cloud_kit_record.instance_variable_get(:@cloudkit_modifier_record_id)).to eql("__defaultOwner__")
    end

    it "identifies the creator's information" do 
      binary_plist = File.read(TEST_BLOB_DATA_DIR + "ZSERVERRECORDDATA.bin")
      cloud_kit_record.add_cloudkit_server_record_data(binary_plist)
      expect(cloud_kit_record.instance_variable_get(:@cloudkit_creator_record_id)).to eql("__defaultOwner__")
    end
  end

  context "cloudkit sharing data" do
    it "reads participants from ZSERVERSHAREDATA" do
      binary_plist = File.read(TEST_BLOB_DATA_DIR + "ZSERVERSHAREDATA.bin")
      expect(cloud_kit_record.add_cloudkit_sharing_data(binary_plist)).to be 2
      expect(cloud_kit_record.cloud_kit_record_known?("__defaultOwner__")).to be_kind_of(AppleCloudKitShareParticipant)
    end

    it "parses user contact information" do
      binary_plist = File.read(TEST_BLOB_DATA_DIR + "ZSERVERSHAREDATA.bin")
      cloud_kit_record.add_cloudkit_sharing_data(binary_plist)
      expect(cloud_kit_record.share_participants[0].email).to eql("fake_email2@fake_domain.fake")
      expect(cloud_kit_record.share_participants[1].email).to eql("fake_email@fake_domain.fake")
    end

    it "parses user personal information" do
      binary_plist = File.read(TEST_BLOB_DATA_DIR + "ZSERVERSHAREDATA.bin")
      cloud_kit_record.add_cloudkit_sharing_data(binary_plist)
      expect(cloud_kit_record.share_participants[0].first_name).to eql("Mr")
      expect(cloud_kit_record.share_participants[0].last_name).to eql("Tester")
      expect(cloud_kit_record.share_participants[1].first_name).to eql("F")
      expect(cloud_kit_record.share_participants[1].last_name).to eql("P")
    end

    it "parses user record ids" do
      binary_plist = File.read(TEST_BLOB_DATA_DIR + "ZSERVERSHAREDATA.bin")
      cloud_kit_record.add_cloudkit_sharing_data(binary_plist)
      expect(cloud_kit_record.share_participants[0].record_id).to eql("__defaultOwner__")
      expect(cloud_kit_record.share_participants[1].record_id).to eql("_dfe6a1b5e8bc40359c323b0357e3f04d")
      expect(cloud_kit_record.cloud_kit_record_known?("__defaultOwner__")).to be_kind_of(AppleCloudKitShareParticipant)
    end
  end

  context "helper functions" do
    before(:each) do 
      @tmp_participant = AppleCloudKitShareParticipant.new
      @tmp_participant.record_id = "9c21782a-ec9e-424a-b8e4-6ab473b84cdb"
      cloud_kit_record.share_participants.push(@tmp_participant)
    end

    it "returns false if the Array is nil" do
      expect(empty_cloud_kit_record.cloud_kit_record_known?("9c21782a-ec9e-424a-b8e4-6ab473b84cdb")).to be false
    end

    it "returns false from an empty Array" do
      expect(empty_cloud_kit_record.cloud_kit_record_known?("9c21782a-ec9e-424a-b8e4-6ab473b84cdb")).to be false
    end

    it "returns flase if the id is nil" do
      expect(empty_cloud_kit_record.cloud_kit_record_known?(nil)).to be false
    end

    it "returns true if the given id is a hash key" do
      expect(cloud_kit_record.cloud_kit_record_known?("9c21782a-ec9e-424a-b8e4-6ab473b84cdb")).to be @tmp_participant
    end
  end

end
