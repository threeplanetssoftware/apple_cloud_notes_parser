require 'keyed_archive'
require 'sqlite3'
require_relative 'AppleCloudKitRecord'

##
# This class represents an inline link pointing to another note, or the like. 
# These were added in iOS 17 and allow users to directly link to other notes from the GUI.
class AppleNotesEmbeddedInlineLink < AppleNotesEmbeddedInlineAttachment

  ##
  # Creates a new AppleNotesEmbeddedInlineLink. 
  # Expects an Integer +primary_key+ from ZICCLOUDSYNCINGOBJECT.Z_PK, String +uuid+ from ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, 
  # String +uti+ from ZICCLOUDSYNCINGOBJECT.ZTYPEUTI1, AppleNote +note+ object representing the parent AppleNote, 
  # a String +alt_text+ from ZICCLOUDSYNCINGOBJECT.ZALTTEXT, and a String +token_identifier+ from 
  # ZICCLOUDSYNCINGOBJECT.ZTOKENCONTENTIDENTIFIER representing what the text stands for.
  def initialize(primary_key, uuid, uti, note, alt_text, token_identifier)
    super(primary_key, uuid, uti, note, alt_text, token_identifier)
  end

  ##
  # This method just returns a readable String for the object.
  def to_s
    return "#{@alt_text} [#{@token_identifier}]"
  end

  ##
  # This method generates the HTML to be embedded into an AppleNote's HTML.
  def generate_html(individual_files=false)
    return self.to_s
  end

end
