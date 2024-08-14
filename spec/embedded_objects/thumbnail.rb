require_relative '../../lib/AppleNotesEmbeddedThumbnail.rb'

describe AppleNotesEmbeddedThumbnail do

  let(:primary_key) {1}
  let(:uuid) {SecureRandom.uuid}
  let(:uti) {"thumbnail"}
  let(:note) {nil}
  let(:backup) {nil}
  let(:height) {640}
  let(:width) {480}
  let(:parent) {nil}
  let(:gallery_parent) {double(AppleNotesEmbeddedGallery)}
  let(:mocked_note) {double(AppleNote)}
  let(:mocked_account) {double(AppleNotesAccount)}
  let(:account_uuid) {SecureRandom.uuid}

  context "creation" do
    it "creates a thumbnail without needing other classes" do
      tmp_thumbnail = AppleNotesEmbeddedThumbnail.new(primary_key, uuid, uti, note, backup, height, width, parent)
      expect(tmp_thumbnail).to be_a AppleNotesEmbeddedThumbnail
    end
  end

  context "filepaths" do

    let(:version_16) {AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_16)}
    let(:version_17) {AppleNoteStoreVersion.new(AppleNoteStoreVersion::IOS_VERSION_17)}

    it "guesses the right filepath for iOS 16 thumbnails without a note" do
      tmp_thumbnail = AppleNotesEmbeddedThumbnail.new(primary_key, uuid, uti, note, backup, height, width, parent)
      tmp_thumbnail.instance_variable_set(:@version,version_16)
      expect(tmp_thumbnail.get_media_filepath).to eql "[Unknown Account]/Previews/#{uuid}.png"
    end

    it "guesses the right filepath for iOS 17 thumbnails with an account" do
      tmp_thumbnail = AppleNotesEmbeddedThumbnail.new(primary_key, uuid, uti, note, backup, height, width, parent)
      tmp_thumbnail.instance_variable_set(:@note, mocked_note)

      allow(mocked_note).to receive(:account).and_return(mocked_account)
      allow(mocked_account).to receive(:account_folder).and_return("Accounts/#{account_uuid}/")

      tmp_thumbnail.instance_variable_set(:@version,version_16)
      expect(tmp_thumbnail.get_media_filepath).to eql "Accounts/#{account_uuid}/Previews/#{uuid}.png"
    end

    it "guesses the right filename for iOS 16 normal thumbnails" do
      tmp_thumbnail = AppleNotesEmbeddedThumbnail.new(primary_key, uuid, uti, note, backup, height, width, parent)
      tmp_thumbnail.instance_variable_set(:@version,version_16)
      expect(tmp_thumbnail.get_media_filename).to eql "#{uuid}.png"
    end

    it "guesses the right filename for iOS 16 gallery thumbnails" do
      allow(gallery_parent).to receive(:type).and_return("com.apple.notes.gallery")
      tmp_thumbnail = AppleNotesEmbeddedThumbnail.new(primary_key, uuid, uti, note, backup, height, width, gallery_parent)
      tmp_thumbnail.instance_variable_set(:@version,version_16)
      expect(tmp_thumbnail.get_media_filename).to eql "#{uuid}.jpg"
    end

    it "guesses the right filename for iOS 16 encrypted note thumbnails" do
      tmp_thumbnail = AppleNotesEmbeddedThumbnail.new(primary_key, uuid, uti, note, backup, height, width, parent)
      tmp_thumbnail.instance_variable_set(:@version,version_16)
      tmp_thumbnail.instance_variable_set(:@is_password_protected,true)
      expect(tmp_thumbnail.get_media_filename).to eql "#{uuid}.png.encrypted"
    end

    it "guesses the right filename for iOS 16 encrypted gallery thumbnails" do
      allow(gallery_parent).to receive(:type).and_return("com.apple.notes.gallery")
      tmp_thumbnail = AppleNotesEmbeddedThumbnail.new(primary_key, uuid, uti, note, backup, height, width, gallery_parent)
      tmp_thumbnail.instance_variable_set(:@version,version_16)
      tmp_thumbnail.instance_variable_set(:@is_password_protected,true)
      expect(tmp_thumbnail.get_media_filename).to eql "#{uuid}.jpg.encrypted"
    end

    ## iOS 17 follows

    it "guesses the right filepath for iOS 17 thumbnails without a note" do
      tmp_thumbnail = AppleNotesEmbeddedThumbnail.new(primary_key, uuid, uti, note, backup, height, width, parent)
      tmp_thumbnail.instance_variable_set(:@version,version_17)
      expect(tmp_thumbnail.get_media_filepath).to eql "[Unknown Account]/Previews/#{uuid}.png"
    end

    it "guesses the right filepath for iOS 17 thumbnails with zgeneration" do
      tmp_thumbnail = AppleNotesEmbeddedThumbnail.new(primary_key, uuid, uti, note, backup, height, width, parent)
      tmp_thumbnail.instance_variable_set(:@note, mocked_note)

      allow(mocked_note).to receive(:account).and_return(mocked_account)
      allow(mocked_account).to receive(:account_folder).and_return("Accounts/#{account_uuid}/")

      tmp_thumbnail.instance_variable_set(:@version,version_17)
      expect(tmp_thumbnail.get_media_filepath).to eql "Accounts/#{account_uuid}/Previews/#{uuid}.png"
    end

    it "guesses the right filepath for iOS 17 thumbnails without zgeneration" do
      tmp_thumbnail = AppleNotesEmbeddedThumbnail.new(primary_key, uuid, uti, note, backup, height, width, parent)
      tmp_thumbnail.instance_variable_set(:@version,version_17)
      expect(tmp_thumbnail.get_media_filepath).to eql "[Unknown Account]/Previews/#{uuid}.png"
    end

    it "guesses the right filename for iOS 17 normal thumbnails" do
      tmp_thumbnail = AppleNotesEmbeddedThumbnail.new(primary_key, uuid, uti, note, backup, height, width, parent)
      tmp_thumbnail.instance_variable_set(:@version,version_17)
      expect(tmp_thumbnail.get_media_filename).to eql "#{uuid}.png"
    end

    it "guesses the right filename for iOS 17 gallery thumbnails" do
      allow(gallery_parent).to receive(:type).and_return("com.apple.notes.gallery")
      tmp_thumbnail = AppleNotesEmbeddedThumbnail.new(primary_key, uuid, uti, note, backup, height, width, gallery_parent)
      tmp_thumbnail.instance_variable_set(:@version,version_17)
      expect(tmp_thumbnail.get_media_filename).to eql "#{uuid}.jpeg"
    end

    it "guesses the right filename for iOS 17 encrypted note thumbnails" do
      tmp_thumbnail = AppleNotesEmbeddedThumbnail.new(primary_key, uuid, uti, note, backup, height, width, parent)
      tmp_thumbnail.instance_variable_set(:@version,version_17)
      tmp_thumbnail.instance_variable_set(:@is_password_protected,true)
      expect(tmp_thumbnail.get_media_filename).to eql "#{uuid}.png.encrypted"
    end


  end

end
