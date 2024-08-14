require_relative '../../lib/AppleNotesAccount.rb'
require_relative '../../lib/AppleNotesSmartFolder.rb'
require 'securerandom'

describe AppleNotesSmartFolder do

  let(:tmp_account) { AppleNotesAccount.new(1, "Account Name", SecureRandom.uuid) }
  let(:tmp_query) { "{\"entity\":\"note\",\"type\":{\"and\":[{\"deleted\":false},{\"and\":[{\"mention\":true}]}]}}" }
  let(:tmp_folder) { AppleNotesSmartFolder.new(1, "SmartFolder Name", tmp_account, tmp_query) }

  context "output" do
    it "includes the query in JSON" do
      expect(tmp_folder.prepare_json()[:query]).to eql(tmp_query)
    end

    it "includes the query in CSV" do
      expect(tmp_folder.to_csv[AppleNotesFolder.csv_smart_folder_query_column]).to eql(tmp_query)
    end
  end
end
