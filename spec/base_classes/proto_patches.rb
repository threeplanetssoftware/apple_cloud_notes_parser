require_relative '../../lib/ProtoPatches.rb'

describe Color do

  context "hex strings" do
    it "correctly creates a 100% red hex string" do
      tmp_color = Color.new({red: 1, green: 0, blue: 0, alpha: 0})
      expect(tmp_color.red_hex_string).to eql "FF"
      expect(tmp_color.green_hex_string).to eql "00"
      expect(tmp_color.blue_hex_string).to eql "00"
      expect(tmp_color.full_hex_string).to eql "#FF0000"
    end

    it "correctly creates and pads a 0% hex string" do
      tmp_color = Color.new({red: 0, green: 0, blue: 0, alpha: 0})
      expect(Color.new({red: 0, green: 0, blue: 0, alpha: 0}).red_hex_string).to eql "00"
      expect(tmp_color.red_hex_string).to eql "00"
      expect(tmp_color.green_hex_string).to eql "00"
      expect(tmp_color.blue_hex_string).to eql "00"
      expect(tmp_color.full_hex_string).to eql "#000000"
    end

    it "correctly creates a 100% blue hex string" do
      tmp_color = Color.new({red: 0, green: 0, blue: 1, alpha: 0})
      expect(tmp_color.red_hex_string).to eql "00"
      expect(tmp_color.green_hex_string).to eql "00"
      expect(tmp_color.blue_hex_string).to eql "FF"
      expect(tmp_color.full_hex_string).to eql "#0000FF"
    end

    it "correctly creates a 100% green hex string" do
      tmp_color = Color.new({red: 0, green: 1, blue: 0, alpha: 0})
      expect(tmp_color.red_hex_string).to eql "00"
      expect(tmp_color.green_hex_string).to eql "FF"
      expect(tmp_color.blue_hex_string).to eql "00"
      expect(tmp_color.full_hex_string).to eql "#00FF00"
    end
  end

end

describe AttributeRun do

  context "comparison" do
    it "considers two runs without any style to be the same style" do
      tmp_run = AttributeRun.new({length: 1})
      tmp_run2 = AttributeRun.new({length: 1})
      expect(tmp_run.same_style?(tmp_run2)).to be true
    end

    it "considers two runs with different font weights to be different styles" do
      tmp_run = AttributeRun.new({length: 1, font_weight: 2})
      tmp_run2 = AttributeRun.new({length: 1, font_weight: 4})
      expect(tmp_run.same_style?(tmp_run2)).to be false
    end

    it "considers two runs with different underlined values to be different styles" do
      tmp_run = AttributeRun.new({length: 1, underlined: 2})
      tmp_run2 = AttributeRun.new({length: 1, underlined: 3})
      expect(tmp_run.same_style?(tmp_run2)).to be false
    end

    it "considers two runs with different strikethrough values to be different styles" do
      tmp_run = AttributeRun.new({length: 1, strikethrough: 2})
      tmp_run2 = AttributeRun.new({length: 1, strikethrough: 3})
      expect(tmp_run.same_style?(tmp_run2)).to be false
    end

    it "considers two runs with different superscript values to be different styles" do
      tmp_run = AttributeRun.new({length: 1, superscript: 2})
      tmp_run2 = AttributeRun.new({length: 1, superscript: 3})
      expect(tmp_run.same_style?(tmp_run2)).to be false
    end

    it "considers two runs with different link values to be different styles" do
      tmp_run = AttributeRun.new({length: 1, link: "https://google.com"})
      tmp_run2 = AttributeRun.new({length: 1, link: "http://yahoo.com"})
      expect(tmp_run.same_style?(tmp_run2)).to be false
    end

    it "considers two runs with different, but similar ParagraphStyles be the same" do
      style_1 = ParagraphStyle.new({indent_amount: 1})
      style_2 = ParagraphStyle.new({indent_amount: 1})
      tmp_run = AttributeRun.new({length: 1, paragraph_style: style_1})
      tmp_run2 = AttributeRun.new({length: 1, paragraph_style: style_2})
      expect(tmp_run.same_style?(tmp_run2)).to be true
    end

    it "considers two runs with different ParagraphStyles be different" do
      style_1 = ParagraphStyle.new({indent_amount: 1})
      style_2 = ParagraphStyle.new({indent_amount: 2})
      tmp_run = AttributeRun.new({length: 1, paragraph_style: style_1})
      tmp_run2 = AttributeRun.new({length: 1, paragraph_style: style_2})
      expect(tmp_run.same_style?(tmp_run2)).to be false
    end

    it "considers two runs with different, but similar Fonts be the same" do
      font_1 = Font.new({font_name: "Consolas"})
      font_2 = Font.new({font_name: "Consolas"})
      tmp_run = AttributeRun.new({length: 1, font: font_1})
      tmp_run2 = AttributeRun.new({length: 1, font: font_2})
      expect(tmp_run.same_style?(tmp_run2)).to be true
    end

    it "considers two runs with different Fonts be different" do
      font_1 = Font.new({font_name: "Consolas"})
      font_2 = Font.new({font_name: "Times New Roman"})
      tmp_run = AttributeRun.new({length: 1, font: font_1})
      tmp_run2 = AttributeRun.new({length: 1, font: font_2})
      expect(tmp_run.same_style?(tmp_run2)).to be false
    end

    it "considers two runs with different, but similar Colors be the same" do
      color_1 = Color.new({red: 1, green: 1, blue: 1, alpha: 1})
      color_2 = Color.new({red: 1, green: 1, blue: 1, alpha: 1})
      tmp_run = AttributeRun.new({length: 1, color: color_1})
      tmp_run2 = AttributeRun.new({length: 1, color: color_2})
      expect(tmp_run.same_style?(tmp_run2)).to be true
    end

    it "considers two runs with different Colors be different" do
      color_1 = Color.new({red: 1, green: 1, blue: 1, alpha: 1})
      color_2 = Color.new({red: 0, green: 0, blue: 0, alpha: 0})
      tmp_run = AttributeRun.new({length: 1, color: color_1})
      tmp_run2 = AttributeRun.new({length: 1, color: color_2})
      expect(tmp_run.same_style?(tmp_run2)).to be false
    end

    it "correctly identifies the next and previous tags as being the same style when the same" do
      tmp_style = ParagraphStyle.new({style_type: AppleNote::STYLE_TYPE_TITLE})

      tmp_run = AttributeRun.new({length: 2, paragraph_style: tmp_style})
      tmp_run2 = AttributeRun.new({length: 2, paragraph_style: tmp_style})

      tmp_run.next_run = tmp_run2
      tmp_run2.previous_run = tmp_run

      expect(tmp_run.same_style_type_next?).to be true
      expect(tmp_run2.same_style_type_previous?).to be true
    end

    it "correctly identifies the next and previous tags as NOT being the same style when different" do
      tmp_style = ParagraphStyle.new({style_type: AppleNote::STYLE_TYPE_TITLE})
      tmp_style2 = ParagraphStyle.new({style_type: AppleNote::STYLE_TYPE_HEADING})

      tmp_run = AttributeRun.new({length: 2, paragraph_style: tmp_style})
      tmp_run2 = AttributeRun.new({length: 2, paragraph_style: tmp_style2})

      tmp_run.next_run = tmp_run2
      tmp_run2.previous_run = tmp_run

      expect(tmp_run.same_style_type_next?).to be false
      expect(tmp_run2.same_style_type_previous?).to be false
    end
  end

  context "indents" do
    it "caches indent amount" do
      tmp_run = AttributeRun.new({length: 1})
      expect(tmp_run.instance_variable_get(:@indent)).to be nil
      total_indent = tmp_run.total_indent
      expect(tmp_run.instance_variable_get(:@indent)).to be 0
    end

    it "considers the indent from previous runs in its calculations" do
      one_indent = ParagraphStyle.new({indent_amount: 1})
      two_indents = ParagraphStyle.new({indent_amount: 2})
      tmp_run = AttributeRun.new({length: 1, paragraph_style: one_indent})
      tmp_second_run = AttributeRun.new({length: 1, paragraph_style: two_indents})
      tmp_second_run.previous_run = tmp_run
      expect(tmp_second_run.total_indent).to be 3
    end
  end

  context "alignment" do
    it "adds a justify tag when not the default" do
      center_alignment = ParagraphStyle.new({alignment: AppleNote::STYLE_ALIGNMENT_CENTER})
      right_alignment = ParagraphStyle.new({alignment: AppleNote::STYLE_ALIGNMENT_RIGHT})
      justify_alignment = ParagraphStyle.new({alignment: AppleNote::STYLE_ALIGNMENT_JUSTIFY})

      center_run = AttributeRun.new({length: 1, paragraph_style: center_alignment})
      right_run = AttributeRun.new({length: 1, paragraph_style: right_alignment})
      justify_run = AttributeRun.new({length: 1, paragraph_style: justify_alignment})

      center_doc = Nokogiri::HTML5::Document.parse("", nil, "utf-8")
      right_doc = Nokogiri::HTML5::Document.parse("", nil, "utf-8")
      justify_doc = Nokogiri::HTML5::Document.parse("", nil, "utf-8")

      center_node = center_doc.at_css("body")
      right_node = right_doc.at_css("body")
      justify_node = justify_doc.at_css("body")

      expect(center_run.generate_html("a", center_node).to_html).to eql "<body><div style=\"text-align: center\">a</div></body>"
      expect(right_run.generate_html("a", right_node).to_html).to eql "<body><div style=\"text-align: right\">a</div></body>"
      expect(justify_run.generate_html("a", justify_node).to_html).to eql "<body><div style=\"text-align: justify\">a</div></body>"
    end

    it "doesn't add a justify tag if no alignment is given" do
      tmp_run = AttributeRun.new({length: 1, paragraph_style: ParagraphStyle.new({})})
      tmp_doc = Nokogiri::HTML5::Document.parse("", nil, "utf-8")
      tmp_node = tmp_doc.at_css("body")
      expect(tmp_run.generate_html("a", tmp_node).to_html).not_to include "text-align"
    end
  end

  context "block tags" do 
    it "handles titles properly" do
      tmp_style = ParagraphStyle.new({style_type: AppleNote::STYLE_TYPE_TITLE})
      tmp_run = AttributeRun.new({length: 4, paragraph_style: tmp_style})
      tmp_doc = Nokogiri::HTML5::Document.parse("", nil, "utf-8")
      tmp_node = tmp_doc.at_css("body")
      expect(tmp_run.generate_html("test", tmp_node).to_html).to eql "<body><h1>test</h1></body>"
    end

    it "handles headings properly" do
      tmp_style = ParagraphStyle.new({style_type: AppleNote::STYLE_TYPE_HEADING})
      tmp_run = AttributeRun.new({length: 4, paragraph_style: tmp_style})
      tmp_doc = Nokogiri::HTML5::Document.parse("", nil, "utf-8")
      tmp_node = tmp_doc.at_css("body")
      expect(tmp_run.generate_html("test", tmp_node).to_html).to eql "<body><h2>test</h2></body>"
    end

    it "handles subheadings properly" do
      tmp_style = ParagraphStyle.new({style_type: AppleNote::STYLE_TYPE_SUBHEADING})
      tmp_run = AttributeRun.new({length: 4, paragraph_style: tmp_style})
      tmp_doc = Nokogiri::HTML5::Document.parse("", nil, "utf-8")
      tmp_node = tmp_doc.at_css("body")
      expect(tmp_run.generate_html("test", tmp_node).to_html).to eql "<body><h3>test</h3></body>"
    end

    it "handles monospaced properly" do
      tmp_style = ParagraphStyle.new({style_type: AppleNote::STYLE_TYPE_MONOSPACED})
      tmp_run = AttributeRun.new({length: 4, paragraph_style: tmp_style})
      tmp_doc = Nokogiri::HTML5::Document.parse("", nil, "utf-8")
      tmp_node = tmp_doc.at_css("body")
      expect(tmp_run.generate_html("test", tmp_node).to_html).to eql "<body><pre>test</pre></body>"
    end

    # This doesn't appear to be an issue since AppleNote prunes the AttributeRuns down 
    # to just one per style. However, it should work and at some point needs to be fixed so
    # AttributeRun can stand on its own. The issue is it doesn't open a new tag,
    # but it does CLOSE the previous tag. This will be tested in AppleNote.
    xit "doesn't open new tags for adjacent runs of the same type" do
      tmp_style = ParagraphStyle.new({style_type: AppleNote::STYLE_TYPE_TITLE})

      tmp_run = AttributeRun.new({length: 2, paragraph_style: tmp_style})
      tmp_run2 = AttributeRun.new({length: 2, paragraph_style: tmp_style})

      tmp_run.next_run = tmp_run2
      tmp_run2.previous_run = tmp_run

      tmp_doc = Nokogiri::HTML5::Document.parse("", nil, "utf-8")
      tmp_node = tmp_doc.at_css("body")

      expect(tmp_run.generate_html("te", tmp_node).to_html).to eql "<body><h1>te</h1></body>"
      
      expect(tmp_run2.generate_html("st", tmp_node).to_html).to eql "<body><h1>test</h1></body>"
    end
  end

  context "checklists" do
    it "adds the checked class to checked items" do
      tmp_checklist = Checklist.new({uuid: SecureRandom.uuid, done: 1})
      tmp_style = ParagraphStyle.new({style_type: AppleNote::STYLE_TYPE_CHECKBOX, checklist: tmp_checklist})
      tmp_run = AttributeRun.new({length: 14, paragraph_style: tmp_style})
      doc = Nokogiri::HTML5::Document.parse("", nil, "utf-8")
      node = doc.at_css("body")
      expect(tmp_run.generate_html("This is a test", node).to_html).to include "<li class=\"checked\">This is a test</li>"
    end

    it "allows newlines in list items identified by u2028" do
      tmp_checklist = Checklist.new({uuid: SecureRandom.uuid, done: 1})
      tmp_style = ParagraphStyle.new({style_type: AppleNote::STYLE_TYPE_CHECKBOX, checklist: tmp_checklist})
      tmp_run = AttributeRun.new({length: 15, paragraph_style: tmp_style})
      doc = Nokogiri::HTML5::Document.parse("", nil, "utf-8")
      node = doc.at_css("body")
      expect(tmp_run.generate_html("This is\u2028 a test", node).to_html).to include "This is<br> a test"
    end

    it "creates new list items when newlines are included" do
      tmp_checklist = Checklist.new({uuid: SecureRandom.uuid, done: 1})
      tmp_style = ParagraphStyle.new({style_type: AppleNote::STYLE_TYPE_CHECKBOX, checklist: tmp_checklist})
      tmp_run = AttributeRun.new({length: 15, paragraph_style: tmp_style})
      doc = Nokogiri::HTML5::Document.parse("", nil, "utf-8")
      node = doc.at_css("body")
      expect(tmp_run.generate_html("This is\n a test", node).to_html).to include("><li class=\"checked\">").twice
    end

    it "adds the unchecked class to checked items" do
      tmp_checklist = Checklist.new({uuid: SecureRandom.uuid, done: 0})
      tmp_style = ParagraphStyle.new({style_type: AppleNote::STYLE_TYPE_CHECKBOX, checklist: tmp_checklist})
      tmp_run = AttributeRun.new({length: 14, paragraph_style: tmp_style})
      #tmp_run.add_list_text("This is a test")
      doc = Nokogiri::HTML5::Document.parse("", nil, "utf-8")
      node = doc.at_css("body")
      expect(tmp_run.generate_html("This is a test", node).to_html).to include "<li class=\"unchecked\">This is a test</li>"
    end
  end

end
