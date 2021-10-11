require_relative 'AppleNotesEmbeddedInlineAttachment'

##
# This class represents an inline hashtag enhancement embedded in an AppleNote. 
# These were added in iOS 15.
class AppleNotesEmbeddedInlineHashtag < AppleNotesEmbeddedInlineAttachment

  ##
  # Creates a new AppleNotesEmbeddedInlineHashtag. 
  # Expects an Integer +primary_key+ from ZICCLOUDSYNCINGOBJECT.Z_PK, String +uuid+ from ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, 
  # String +uti+ from ZICCLOUDSYNCINGOBJECT.ZTYPEUTI1, AppleNote +note+ object representing the parent AppleNote, 
  # a String +alt_text+ from ZICCLOUDSYNCINGOBJECT.ZALTTEXT, and a String +token_identifier+ from 
  # ZICCLOUDSYNCINGOBJECT.ZTOKENCONTENTIDENTIFIER representing what the text stands for.
  def initialize(primary_key, uuid, uti, note, alt_text, token_identifier)
    super(primary_key, uuid, uti, note, alt_text, token_identifier)
  end

  ##
  # This method just returns the hashtag's text, which is found in alt_text.
  def to_s
    @alt_text
  end

end
