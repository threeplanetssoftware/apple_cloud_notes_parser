require_relative '../../lib/AppleNotesAccount.rb'
require_relative '../../lib/AppleNotesFolder.rb'
require 'securerandom'

describe AppleNotesFolder do

  let(:tmp_account) { AppleNotesAccount.new(1, "Account Name", SecureRandom.uuid) }
  let(:tmp_folder) { AppleNotesFolder.new(1, "Folder Name", tmp_account) }

  context "file paths" do
    it "removes any dirty characters from a potential filename" do
      expect(AppleNotesFolder.new(1, "C:\\Users\\Testing\\password.txt", tmp_account).clean_name).to eql("C__Users_Testing_password.txt")
      expect(AppleNotesFolder.new(1, "/etc/passwd", tmp_account).clean_name).to eql("_etc_passwd")
    end

    it "faithfully carries non-dirty folder names through to the clean_name" do
      random_folder_name = SecureRandom.alphanumeric(10)
      expect(AppleNotesFolder.new(1, random_folder_name, tmp_account).clean_name).to eql(random_folder_name)
    end

    it "appropriately creates a folder's filepath with no parent" do
      random_account_name = SecureRandom.alphanumeric(15)
      random_folder_name = SecureRandom.alphanumeric(15)
      tmp_account = AppleNotesAccount.new(1, random_account_name, SecureRandom.uuid)
      expect(AppleNotesFolder.new(1, random_folder_name, tmp_account).to_path.to_s).to eql("#{random_account_name}-#{random_folder_name}")
    end

    it "appropriately creates a folder's filepath with a parent" do
      random_account_name = SecureRandom.alphanumeric(15)
      random_folder_name = SecureRandom.alphanumeric(15)
      random_folder_name2 = SecureRandom.alphanumeric(15)
      tmp_account = AppleNotesAccount.new(1, random_account_name, SecureRandom.uuid)
      tmp_folder = AppleNotesFolder.new(1, random_folder_name, tmp_account)
      child_folder = AppleNotesFolder.new(2, random_folder_name2, tmp_account)
      tmp_folder.add_child(child_folder)
      expect(child_folder.to_path.to_s).to eql("#{random_account_name}-#{random_folder_name}/#{random_folder_name2}")
    end

    it "generates a folder anchor link with its UUID if use_uuid is passed" do
      tmp_uuid = SecureRandom.uuid
      tmp_folder.uuid = tmp_uuid
      expect(tmp_folder.anchor_link(use_uuid: true)).to eql("#folder_#{tmp_uuid}")
    end

    it "generates a folder anchor link with its regular ID if use_uuid is false" do
      expect(tmp_folder.anchor_link).to eql("#folder_1")
    end
  end

  context "notes" do
    it "has no notes to start with" do 
      expect(tmp_folder.has_notes).to be false
    end

    it "has notes once one is added" do
      tmp_note = AppleNote.new(56, 22, "Note Title", "", 0, 0, tmp_account, tmp_folder)
      tmp_folder.add_note(tmp_note)
      expect(tmp_folder.has_notes).to be true
    end
  end

  context "children" do

    let(:first_child) { AppleNotesFolder.new(2, "Child Folder", tmp_account) }

    it "has no children to start with" do
      expect(tmp_folder.instance_variable_get(:@child_folders).length).to be 0
    end

    it "is not a parent without children" do
      expect(tmp_folder.is_parent?).to be false
    end

    it "is a parent with children" do
      tmp_folder.add_child(first_child)
      expect(tmp_folder.is_parent?).to be true
    end

    it "correctly adds a child folder" do
      expect(tmp_folder.add_child(first_child).length).to be 1
    end

    it "correctly adds folders to children" do
      second_child = AppleNotesFolder.new(3, "Child Folder 2", tmp_account)
      tmp_folder.add_child(first_child)
      expect(first_child.add_child(second_child).length).to be 1
    end

    it "is not an orphan with a parent" do
      tmp_folder.add_child(first_child)
      expect(first_child.is_orphan?).to be false
    end

    it "is an orphan if only the parent id is set" do
      first_child.parent_id = 1
      expect(first_child.is_orphan?).to be true
    end

    it "uses its name as its full name if it isn't a child" do
      expect(tmp_folder.full_name).to eql(tmp_folder.name)
    end

    it "includes its parent's name in its full name" do
      tmp_folder.add_child(first_child)
      expect(first_child.full_name).to eql("#{tmp_folder.name} -> #{first_child.name}")
    end
  end

  context "output" do
    it "has no pre-cached HTML" do
      expect(tmp_folder.instance_variable_get(:@html)).to be nil
    end

    it "caches results to make things quicker" do
      TEST_HTML_GENERATION_OPTIONS.each do |option|
        if tmp_folder.instance_variable_get(:@html)
          expect(tmp_folder.instance_variable_get(:@html)[option]).to be nil
        end
        tmp_folder.generate_html(individual_files: option[0], use_uuid: option[1])
        expect(tmp_folder.instance_variable_get(:@html)[option]).to be_a Nokogiri::XML::Element
      end
    end

    it "returns just its name with an anchor link if it is not a child and does not have individual-files on" do
      tmp_uuid = SecureRandom.uuid
      tmp_folder.uuid = tmp_uuid

      tmp_result = tmp_folder.full_name_with_links(individual_files: false, use_uuid: false)
      tmp_result_uuid = tmp_folder.full_name_with_links(individual_files: false, use_uuid: true)

      expect(tmp_result.to_html).to eql("<span><a href=\"#folder_#{tmp_folder.primary_key}\">#{tmp_folder.name}</a></span>")
      expect(tmp_result_uuid.to_html).to eql("<span><a href=\"#folder_#{tmp_uuid}\">#{tmp_folder.name}</a></span>")
      expect(tmp_result.text).to eql("#{tmp_folder.name}")
      expect(tmp_result).to be_a(Nokogiri::XML::Element)
    end

    it "returns just a link if it is not a child and has individual_files on" do
      tmp_uuid = SecureRandom.uuid
      tmp_folder.uuid = tmp_uuid

      tmp_result = tmp_folder.full_name_with_links(individual_files: true, use_uuid: false)
      tmp_result_uuid = tmp_folder.full_name_with_links(individual_files: true, use_uuid: true)

      expect(tmp_result.to_html).to eql("<span><a href=\"index.html\">#{tmp_folder.name}</a></span>")
      expect(tmp_result_uuid.to_html).to eql("<span><a href=\"index.html\">#{tmp_folder.name}</a></span>")
      expect(tmp_result.text).to eql("#{tmp_folder.name}")
      expect(tmp_result).to be_a(Nokogiri::XML::Element)
    end

    it "returns its parents names with anchor links if it is a child and does not have individual_files on" do
      tmp_parent = AppleNotesFolder.new(5, "Parent Folder", tmp_account)
      tmp_parent2 = AppleNotesFolder.new(6, "Parent Folder 2", tmp_account)

      tmp_uuid = SecureRandom.uuid
      tmp_uuid2 = SecureRandom.uuid
      tmp_uuid3 = SecureRandom.uuid
      tmp_folder.uuid = tmp_uuid
      tmp_parent.uuid = tmp_uuid2
      tmp_parent2.uuid = tmp_uuid3

      tmp_parent2.add_child(tmp_parent)
      tmp_parent.add_child(tmp_folder)

      tmp_result = tmp_folder.full_name_with_links(individual_files: false, use_uuid: false)
      tmp_result_uuid = tmp_folder.full_name_with_links(individual_files: false, use_uuid: true)

      expect(tmp_result.to_html).to eql("<span><a href=\"#folder_#{tmp_parent2.primary_key}\">#{tmp_parent2.name}</a> -&gt; <a href=\"#folder_#{tmp_parent.primary_key}\">#{tmp_parent.name}</a> -&gt; <a href=\"#folder_#{tmp_folder.primary_key}\">#{tmp_folder.name}</a></span>")
      expect(tmp_result_uuid.to_html).to eql("<span><a href=\"#folder_#{tmp_uuid3}\">#{tmp_parent2.name}</a> -&gt; <a href=\"#folder_#{tmp_uuid2}\">#{tmp_parent.name}</a> -&gt; <a href=\"#folder_#{tmp_uuid}\">#{tmp_folder.name}</a></span>")
      expect(tmp_result.text).to eql("#{tmp_parent2.name} -> #{tmp_parent.name} -> #{tmp_folder.name}")
      expect(tmp_result).to be_a(Nokogiri::XML::Element)
    end

    it "returns its parents names with relative links if it is a child and has individual_files on" do
      tmp_parent = AppleNotesFolder.new(5, "Parent Folder", tmp_account)
      tmp_parent2 = AppleNotesFolder.new(6, "Parent Folder 2", tmp_account)

      tmp_uuid = SecureRandom.uuid
      tmp_uuid2 = SecureRandom.uuid
      tmp_uuid3 = SecureRandom.uuid
      tmp_folder.uuid = tmp_uuid
      tmp_parent.uuid = tmp_uuid2
      tmp_parent2.uuid = tmp_uuid3

      tmp_parent2.add_child(tmp_parent)
      tmp_parent.add_child(tmp_folder)

      tmp_result = tmp_folder.full_name_with_links(individual_files: true, use_uuid: false)
      tmp_result_uuid = tmp_folder.full_name_with_links(individual_files: true, use_uuid: true)

      expect(tmp_result.to_html).to eql("<span><a href=\"../../index.html\">#{tmp_parent2.name}</a> -&gt; <a href=\"../index.html\">#{tmp_parent.name}</a> -&gt; <a href=\"index.html\">#{tmp_folder.name}</a></span>")
      expect(tmp_result_uuid.to_html).to eql("<span><a href=\"../../index.html\">#{tmp_parent2.name}</a> -&gt; <a href=\"../index.html\">#{tmp_parent.name}</a> -&gt; <a href=\"index.html\">#{tmp_folder.name}</a></span>")
      expect(tmp_result.text).to eql("#{tmp_parent2.name} -> #{tmp_parent.name} -> #{tmp_folder.name}")
      expect(tmp_result).to be_a(Nokogiri::XML::Element)
    end

  end
end
