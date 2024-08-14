require_relative '../../lib/AppleNoteStore.rb'
require_relative '../../lib/AppleNote.rb'
require_relative '../../lib/AppleNotesFolder.rb'
require_relative '../../lib/AppleNotesAccount.rb'

describe AppleBackupHashed, :expensive => true, :missing_data => !TEST_ITUNES_DIR_EXIST do

  before(:context) do
    TEST_OUTPUT_DIR.mkpath
    @tmp_backup = AppleBackupHashed.new(TEST_ITUNES_DIR, TEST_OUTPUT_DIR)
    @tmp_notestore = @tmp_backup.note_stores[0]
  end

  after(:context) do 
    TEST_OUTPUT_DIR.rmtree
  end

  context "full iTunes integration test" do
    it "is a valid backup" do
      expect(@tmp_backup).to be_valid
    end

    it "is a valid backup" do
      expect(@tmp_backup).to be_valid
    end

    it "has two notestores" do
      expect(@tmp_backup.note_stores.length).to be 2
    end

    it "Copied NoteStore.sqlite to the output folder" do
      notestore_location = TEST_OUTPUT_DIR + "NoteStore.sqlite"
      expect(notestore_location.exist?).to be true
    end

    it "Copied NoteStore.sqlite to the output folder" do
      notestore_location = TEST_OUTPUT_DIR + "NoteStore.sqlite"
      expect(notestore_location.exist?).to be true
      expect(@tmp_backup.is_sqlite?(notestore_location)).to be true
    end

    it "successfully rips all the notes" do
      expect{@tmp_backup.rip_notes}.not_to raise_exception
    end

    it "doesn't have any empty tags in the html", :skip => "fix this one" do
      puts "Checking note html"
      expect(@tmp_backup.note_stores.first.valid_notes?).to be true
      expect(@tmp_backup.rip_notes).to be 5
      #@tmp_backup.rip_notes
      #expect(@tmp_notestore.notes.first.title).to be "asdasdasd"
      #aggregate_failures "checking note HTML" do
        #@tmp_notestore.notes.each do |note|
          #puts note.note_id
          #TEST_HTML_GENERATION_OPTIONS.each do |option|
            #html = note.generate_html(individual_files: option[0], use_uuid: option[1]).html
            #html = ""
            #expect(html).not_to include "<b></b>"
            #expect(html).not_to include "<i></i>"
            #expect(html).not_to include "<sup></sup>"
            #expect(html).not_to include "<u></u>"
          #end
        #end
      #end
    end
  end
end
