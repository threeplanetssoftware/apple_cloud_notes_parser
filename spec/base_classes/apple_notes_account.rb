require_relative '../../lib/AppleNotesAccount.rb'
require_relative '../../lib/AppleNotesFolder.rb'
require 'securerandom'

describe AppleNotesAccount do

  let(:tmp_account) { AppleNotesAccount.new(1, "Account Name", SecureRandom.uuid) }
  let(:tmp_folder) { AppleNotesFolder.new(1, "Folder Name", tmp_account) }

  context "file paths" do
    it "removes any dirty characters from a potential filename" do
      expect(AppleNotesAccount.new(1, "C:\\Users\\Testing\\password.txt", "44198920-571d-467a-b96b-e3e9ccdce13e").clean_name).to eql("C__Users_Testing_password.txt")
      expect(AppleNotesAccount.new(1, "/etc/passwd", "44198920-571d-467a-b96b-e3e9ccdce13e").clean_name).to eql("_etc_passwd")
    end

    it "faithfully carries non-dirty account names through to the clean_name" do
      random_account_name = SecureRandom.alphanumeric(10)
      expect(AppleNotesAccount.new(1, random_account_name, "44198920-571d-467a-b96b-e3e9ccdce13e").clean_name).to eql(random_account_name)
    end

    it "appropriately creates an account's filepath" do
      tmp_uuid = SecureRandom.uuid
      expect(AppleNotesAccount.new(1, "Account Name", tmp_uuid).account_folder).to eql("Accounts/#{tmp_uuid}/")
    end
  end

  context "folders" do

    let(:tmp_folder2) { AppleNotesFolder.new(2, "Folder Name 2", tmp_account) }
    let(:tmp_folder3) { AppleNotesFolder.new(1, "Folder Name 3", tmp_account) }

    it "uses the order folders were added if retain_order is false" do 
      tmp_folder.sort_order = 6
      tmp_folder2.sort_order = 5
      expect(tmp_account.retain_order).to be false
      expect(tmp_account.sorted_folders).to eql([tmp_folder, tmp_folder2])
    end

    it "uses the order folders were sorted if retain_order is true" do 
      tmp_account.retain_order = true
      tmp_folder.sort_order = 6
      tmp_folder2.sort_order = 5
      expect(tmp_account.retain_order).to be true
      expect(tmp_account.sorted_folders).to eql([tmp_folder2, tmp_folder])
    end

    it "adds a folder" do
      tmp_account.add_folder(tmp_folder)
      expect(tmp_account.add_folder(tmp_folder2).length).to be 2
    end

    it "overwrites a folder if it has the same ID as an existing folder" do
      tmp_account.add_folder(tmp_folder)
      expect(tmp_account.add_folder(tmp_folder3).length).to be 1
    end

  end

  context "notes" do 
    it "starts with no notes" do
      expect(tmp_account.notes.length).to be 0
    end

    it "adds a note to its list" do
      tmp_note = AppleNote.new(1, 1, "Note Title", "", 0, 0, tmp_account, tmp_folder)
      tmp_account.add_note(tmp_note)
      expect(tmp_account.notes.length).to be 1
    end
  end

  context "output" do
    it "has no pre-cached HTML" do
      expect(tmp_account.instance_variable_get(:@html)).to be nil
    end

    it "caches results to make things quicker" do
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        if tmp_account.instance_variable_get(:@html)
          expect(tmp_account.instance_variable_get(:@html)[option]).to be nil
        end
        tmp_account.generate_html(individual_files: option[0], use_uuid: option[1])
        expect(tmp_account.instance_variable_get(:@html)[option]).to be_a Nokogiri::XML::Element
      end
    end

    it "correctly counts the number of notes" do
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        expect(tmp_account.generate_html(individual_files: option[0], use_uuid: option[1]).text).to include "Number of Notes: #{tmp_account.notes.length}"
      end
    end

    it "correctly lists the account name" do
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        expect(tmp_account.generate_html(individual_files: option[0], use_uuid: option[1]).text).to include "#{tmp_account.name}"
      end
    end

    it "correctly lists the account ID" do
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        expect(tmp_account.generate_html(individual_files: option[0], use_uuid: option[1]).text).to include "Account Identifier: #{tmp_account.identifier}"
      end
    end

    it "correctly lists the account's folders" do
      tmp_account.add_folder(tmp_folder)
      expect(tmp_account.generate_html(individual_files: false, use_uuid: false).to_html).to include "<li class=\"folder\"><a href=\"#{tmp_folder.anchor_link(use_uuid: false)}\">#{tmp_folder.name}</a></li>"
      expect(tmp_account.generate_html(individual_files: false, use_uuid: true).to_html).to include "<li class=\"folder\"><a href=\"#{tmp_folder.anchor_link(use_uuid: true)}\">#{tmp_folder.name}</a></li>"
      expect(tmp_account.generate_html(individual_files: true, use_uuid: false).to_html).to include "<li class=\"folder\"><a href=\"Account%20Name-Folder%20Name/index.html\">#{tmp_folder.name}</a></li>"
      expect(tmp_account.generate_html(individual_files: true, use_uuid: true).to_html).to include "<li class=\"folder\"><a href=\"Account%20Name-Folder%20Name/index.html\">#{tmp_folder.name}</a></li>"
    end

  end

end
