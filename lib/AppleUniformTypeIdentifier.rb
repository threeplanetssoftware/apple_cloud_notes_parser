##
# This class represents a uniform type identifier which Apple uses
# to identify the type of materials being described. Apple documents 
# its UTIs here: 
# https://developer.apple.com/documentation/uniformtypeidentifiers/system_declared_uniform_type_identifiers
class AppleUniformTypeIdentifier

    attr_accessor :uti

  ##
  # Creates a new AppleUniformTypeIdentifier.
  # Expects a String +uti+ from ZICCLOUDSYNCINGOBJECT.ZTYPEUTI.
  def initialize(uti)
    # Set this object's variables
    @uti = uti
  end

  ##
  # This method returns a string indicating roughly how this UTI 
  # should be treated. 
  def get_conforms_to_string
    return "bad_uti" if bad_uti?
    return "audio" if conforms_to_audio
    return "document" if conforms_to_document
    return "dynamic" if is_dynamic?
    return "image" if conforms_to_image
    return "inline" if conforms_to_inline_attachment
    return "other public" if is_public?
    return "video" if conforms_to_audiovisual
    return "uti: #{@uti}"
  end

  ##
  # Checks for a UTI that shouldn't exist or won't behave nicely.
  def bad_uti?
    return false if @uti.is_a?(String)
    return true
  end

  ##
  # This method returns true if the UTI represented is dynamic.
  def is_dynamic?
    return false if bad_uti?
    return @uti.start_with?("dyn.")
  end

  ##
  # This method returns true if the UTI represented is public.
  def is_public?
    return false if bad_uti?
    return @uti.start_with?("public.")
  end

  ##
  # This method returns true if the UTI conforms to public.audio
  def conforms_to_audio
    return false if bad_uti?
    return true if @uti == "com.apple.m4a-audio"
    return true if @uti == "com.microsoft.waveform-audio"
    return true if @uti == "public.aiff-audio"
    return true if @uti == "public.midi-audio"
    return true if @uti == "public.mp3"
    return true if @uti == "org.xiph.ogg-audio"
    return false
  end

  ##
  # This method returns true if the UTI conforms to public.video 
  # or public.movie. 
  def conforms_to_audiovisual
    return false if bad_uti?
    return true if @uti == "com.apple.m4v-video"
    return true if @uti == "com.apple.protected-mpeg-4-video"
    return true if @uti == "com.apple.protected-mpeg-4-audio"
    return true if @uti == "com.apple.quicktime-movie"
    return true if @uti == "public.avi"
    return true if @uti == "public.mpeg"
    return true if @uti == "public.mpeg-2-video"
    return true if @uti == "public.mpeg-2-transport-stream"
    return true if @uti == "public.mpeg-4"
    return true if @uti == "public.mpeg-4-audio"
    return false
  end

  ##
  # This method returns true if the UTI conforms to public.data objets that are likely documents
  def conforms_to_document
    return false if bad_uti?
    return true if @uti == "com.apple.iwork.numbers.sffnumbers"
    return true if @uti == "com.apple.log"
    return true if @uti == "com.apple.rtfd"
    return true if @uti == "com.microsoft.word.doc"
    return true if @uti == "com.microsoft.excel.xls"
    return true if @uti == "com.microsoft.powerpoint.ppt"
    return true if @uti == "com.netscape.javascript-source"
    return true if @uti == "net.openvpn.formats.ovpn"
    return true if @uti == "org.idpf.epub-container"
    return true if @uti == "org.oasis-open.opendocument.text"
    return true if @uti == "org.openxmlformats.wordprocessingml.document"
    return false
  end

  ##
  # This method returns true if the UTI conforms to public.image
  def conforms_to_image
    return false if bad_uti?
    return true if @uti == "com.adobe.illustrator.ai-image"
    return true if @uti == "com.adobe.photoshop-image"
    return true if @uti == "com.adobe.raw-image"
    return true if @uti == "com.apple.icns"
    return true if @uti == "com.apple.macpaint-image"
    return true if @uti == "com.apple.pict"
    return true if @uti == "com.apple.quicktime-image"
    return true if @uti == "com.apple.notes.sketch"
    return true if @uti == "com.compuserve.gif"
    return true if @uti == "com.ilm.openexr-image"
    return true if @uti == "com.kodak.flashpix.image"
    return true if @uti == "com.microsoft.bmp"
    return true if @uti == "com.microsoft.ico"
    return true if @uti == "com.sgi.sgi-image"
    return true if @uti == "com.truevision.tga-image"
    return true if @uti == "public.camera-raw-image"
    return true if @uti == "public.fax"
    return true if @uti == "public.heic"
    return true if @uti == "public.jpeg"
    return true if @uti == "public.jpeg-2000"
    return true if @uti == "public.png"
    return true if @uti == "public.svg-image"
    return true if @uti == "public.tiff"
    return true if @uti == "public.xbitmap-image"
    return true if @uti == "org.webmproject.webp"
    return false
  end

  ##
  # This method returns true if the UTI represents Apple text enrichment.
  def conforms_to_inline_attachment
    return false if bad_uti?
    return true if @uti.start_with?("com.apple.notes.inlinetextattachment")
    return false
  end

  ##
  # This method just returns a readable String for the object.
  def to_s
    "#{@uti}"
  end

end
