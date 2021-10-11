require 'keyed_archive'
require 'sqlite3'

##
# This class represents a uniform type identifier which Apple uses
# to identify the type of materials being described.
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
  # This method returns true if the UTI represented is dynamic.
  def is_dynamic?
    return @uti.start_with?("dyn.")
  end

  ##
  # This method returns true if the UTI represented is public.
  def is_public?
    return @uti.start_with?("public.")
  end

  ##
  # This method returns true if the UTI conforms to public.image
  def conforms_to_image
    return true if @uti == "com.adobe.photoshop-image"
    return true if @uti == "com.adobe.illustrator.ai-image"
    return true if @uti == "com.compuserve.gif"
    return true if @uti == "com.microsoft.bmp"
    return true if @uti == "com.microsoft.ico"
    return true if @uti == "com.truevision.tga-image"
    return true if @uti == "com.sgi.sgi-image"
    return true if @uti == "com.ilm.openexr-image"
    return true if @uti == "com.kodak.flashpix.image"
    return true if @uti == "public.fax"
    return true if @uti == "public.jpeg"
    return true if @uti == "public.jpeg-2000"
    return true if @uti == "public.tiff"
    return true if @uti == "public.camera-raw-image"
    return true if @uti == "com.apple.pict"
    return true if @uti == "com.apple.macpaint-image"
    return true if @uti == "public.png"
    return true if @uti == "public.xbitmap-image"
    return true if @uti == "com.apple.quicktime-image"
    return true if @uti == "com.apple.icns"
    return false
  end

  ##
  # This method returns true if the UTI represents Apple text enrichment.
  def conforms_to_inline_attachment
    return true if @uti.start_with?("com.apple.notes.inlinetextattachment")
    return false
  end

  ##
  # This method just returns a readable String for the object.
  def to_s
    "#{@uti}"
  end

end
