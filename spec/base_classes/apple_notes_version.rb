require_relative '../../lib/AppleNoteStoreVersion.rb'

describe AppleNoteStoreVersion do
    
  let(:high_version) {AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_17, AppleNoteStoreVersion::VERSION_PLATFORM_IOS)}
  let(:low_version) {AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_12, AppleNoteStoreVersion::VERSION_PLATFORM_IOS)}
  let(:mac_version) {AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_17, AppleNoteStoreVersion::VERSION_PLATFORM_MAC)}
  let(:legacy_version) {AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_LEGACY_VERSION, AppleNoteStoreVersion::VERSION_PLATFORM_IOS)}

  context "creation" do

    it "defaults the version to a negative value if the version isn't given" do
      expect(AppleNoteStoreVersion.new.version_number).to be < 0
    end

    it "defaults the platform to iOS if it isn't given" do
      expect(AppleNoteStoreVersion.new.platform).to be == AppleNoteStoreVersion::VERSION_PLATFORM_IOS
    end

    it "can take a version number alone in initialization" do
      expect(AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_17)).to be_a AppleNoteStoreVersion
    end

    it "sets both version_number and platform if both are given" do
      tmp_version = AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_17, AppleNoteStoreVersion::VERSION_PLATFORM_MAC)
      expect(tmp_version.version_number).to be == AppleNoteStoreVersion::IOS_VERSION_17
      expect(tmp_version.platform).to be == AppleNoteStoreVersion::VERSION_PLATFORM_MAC
    end

  end

  context "comparison" do

    it "orders lower version numbers less than greater ones" do
      expect(low_version < high_version).to be true
    end
    
    it "orders higher version numbers more than lesser ones" do
      expect(high_version > low_version).to be true
    end

    it "identifies the same version numbers as equal" do
      expect(high_version == mac_version).to be true
    end

    it "identifies that iOS and MAC platforms are different" do
      expect(high_version.same_platform(mac_version)).to be false
    end

    it "identifies that iOS and iOS platforms are the same" do
      expect(high_version.same_platform(low_version)).to be true
    end

  end

  context "helpers" do 
    it "identifies as legacy if the version is prior to 9" do
      expect(legacy_version.legacy?).to be true
    end

    it "does not identify as legacy if the version is 9 or later" do
      expect(high_version.legacy?).to be false
    end
  end

end
