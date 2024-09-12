require_relative '../../lib/AppleNotesEmbeddedObject.rb'

describe AppleNotesEmbeddedObject, :missing_data => !TEST_FILE_VERSIONS_CURRENT_FILE_EXIST do

  before(:context) do
    TEST_OUTPUT_DIR.mkpath
  end
  after(:context) do
    TEST_OUTPUT_DIR.rmtree
  end

  before(:context) do
    @tmp_backup = AppleBackupFile.new(TEST_FILE_VERSIONS[TEST_CURRENT_VERSION], TEST_OUTPUT_DIR)
    @tmp_notestore = AppleNoteStore.new(TEST_FILE_VERSIONS[TEST_CURRENT_VERSION], TEST_CURRENT_VERSION)
    @tmp_account = AppleNotesAccount.new(1, "Note Account", SecureRandom.uuid)
    @tmp_folder = AppleNotesFolder.new(2, "Note Folder", @tmp_account)
    @tmp_notestore.backup = @tmp_backup
    @tmp_notestore.open
    @tmp_note =  AppleNote.new(1, 
                               1, 
                               "Note Title", 
                               File.read(TEST_BLOB_DATA_DIR + "simple_note_protobuf_gzipped.bin"), 
                               608413790, 
                               608413790, 
                               @tmp_account, 
                               @tmp_folder)
    @tmp_note.notestore = @tmp_notestore
    @simple_table = AppleNotesEmbeddedTable.new(1, SecureRandom.uuid, "com.apple.notes.table", @tmp_note)
    @simple_table.instance_variable_set(:@gzipped_data, File.read(TEST_BLOB_DATA_DIR + "table_gzipped.bin"))
    @simple_table.rebuild_table
    @rectangular_table = AppleNotesEmbeddedTable.new(2, SecureRandom.uuid, "com.apple.notes.table", @tmp_note)
    @rectangular_table.instance_variable_set(:@gzipped_data, File.read(TEST_BLOB_DATA_DIR + "table_formats_gzipped.bin"))
    @rectangular_table.rebuild_table
    @right_to_left_table = AppleNotesEmbeddedTable.new(3, SecureRandom.uuid, "com.apple.notes.table", @tmp_note)
    @right_to_left_table.instance_variable_set(:@gzipped_data, File.read(TEST_BLOB_DATA_DIR + "right_to_left_table_gzipped.bin"))
    @right_to_left_table.rebuild_table
  end

  context "table creation" do
   
    it "reconstructs the whole table" do
      expect(@simple_table.instance_variable_get(:@total_rows)).to be 2
      expect(@simple_table.instance_variable_get(:@total_columns)).to be 2
      expect(@rectangular_table.instance_variable_get(:@total_rows)).to be 3
      expect(@rectangular_table.instance_variable_get(:@total_columns)).to be 2
    end
 
    it "properly orders rows" do
      (0..1).each do |row|
        expect(@simple_table.instance_variable_get(:@reconstructed_table)[row]).to be_a Array
        expect(@simple_table.instance_variable_get(:@reconstructed_table_html)[row]).to be_a Array
        (0..1).each do |column|
          expect(@simple_table.instance_variable_get(:@reconstructed_table)[row][column]).to eql "Row #{row + 1} Column #{column + 1}"
          expect(@simple_table.instance_variable_get(:@reconstructed_table_html)[row][column].text).to eql @simple_table.instance_variable_get(:@reconstructed_table)[row][column]
        end
      end
      expect(@right_to_left_table.instance_variable_get(:@reconstructed_table)[0][1]).to eql "اول"
      expect(@right_to_left_table.instance_variable_get(:@reconstructed_table)[1][0]).to eql "نهاية"
    end

    it "has different values for the html table" do
      expect(@simple_table.instance_variable_get(:@reconstructed_table)).not_to eql @simple_table.instance_variable_get(:@reconstructed_table_html)
    end

  end

  context "output" do 
    it "only has plain text in its to_s output" do
      tmp_string = @simple_table.to_s
      expect(tmp_string).to be_a String
      expect(tmp_string).to eql "Embedded Object com.apple.notes.table: #{@simple_table.uuid} with cells: \n\tRow 1 Column 1\tRow 1 Column 2\n\tRow 2 Column 1\tRow 2 Column 2"
      expect(@right_to_left_table.to_s).to eql "Embedded Object com.apple.notes.table: #{@right_to_left_table.uuid} with cells: \n\t\tاول\n\tنهاية\t"
    end

    it "displays right-to-left tables in the right direction in to_s output" do
      expect(@right_to_left_table.to_s).to eql "Embedded Object com.apple.notes.table: #{@right_to_left_table.uuid} with cells: \n\t\tاول\n\tنهاية\t"
    end

    it "generates decent looking HTML" do
      [true, false].each do |option|
        tmp_html = @simple_table.generate_html(individual_files: option)
        expect(tmp_html).to be_a Nokogiri::XML::Element
        expect(tmp_html.to_html).to eql "<table>\n<tr>\n<td>Row 1 Column 1</td>\n<td>Row 1 Column 2</td>\n</tr>\n<tr>\n<td>Row 2 Column 1</td>\n<td>Row 2 Column 2</td>\n</tr>\n</table>"
      end
    end

    it "respects text formatting in HTML output" do
      [true, false].each do |option|
        tmp_html = @rectangular_table.generate_html(individual_files: option).to_html
        expect(tmp_html).to include "<td><b><i>Bold italics</i></b></td>"
        expect(tmp_html).to include "<td><u>Underline</u></td>"
        expect(tmp_html).to include "<td><b>Bold</b></td>"
        expect(tmp_html).to include "<td><i>Italics</i></td>"
        expect(tmp_html).to include "<td>Mixed <b>bold</b> <i>italics</i> <u>underline</u>\n</td>"
        expect(tmp_html).to include("<td></td>").once
      end
    end

    it "properly includes data in its JSON" do
      tmp_json = @simple_table.prepare_json
      expect(tmp_json).to be_a Hash
      expect(tmp_json[:type]).to eql "com.apple.notes.table"
      expect(tmp_json[:html]).to be_a Nokogiri::XML::Element
      expect(tmp_json[:table]).to eql [["Row 1 Column 1", "Row 1 Column 2"], ["Row 2 Column 1", "Row 2 Column 2"]]
    end

  end

end
