require_relative '../../lib/AppleUniformTypeIdentifier.rb'

describe AppleUniformTypeIdentifier do

  context "types" do
    it "refuses to recognize anything that is not a String" do
      tmp_uti = AppleUniformTypeIdentifier.new(Array.new())
      expect(tmp_uti.bad_uti?).to be true
    end

    it "identifies the UTI if it doesn't know what it is" do
      tmp_uti = AppleUniformTypeIdentifier.new("thisisamadeuputi")
      expect(tmp_uti.get_conforms_to_string).to eql("uti: thisisamadeuputi")
    end

    it "recognizes 'public' UTIs" do
      tmp_uti = AppleUniformTypeIdentifier.new("public.thisisamadeuputi")
      expect(tmp_uti.get_conforms_to_string).to eql("other public")
      expect(tmp_uti.is_public?).to be true
    end

    it "recognizes dynamic UTIs" do
      tmp_uti = AppleUniformTypeIdentifier.new("dyn.thisisamadeuputi")
      expect(tmp_uti.get_conforms_to_string).to eql("dynamic")
      expect(tmp_uti.is_dynamic?).to be true
    end 
  end
end
