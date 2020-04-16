##
# This class represents an embedded object which was part of a deleted 
# AppleNote. Apple does not delete the note text, just the objects from the 
# ZICCLOUDSYNCINGOBJECTS table.
class AppleNotesEmbeddedDeletedObject < AppleNotesEmbeddedObject

  attr_accessor :primary_key,
                :uuid,
                :type,
                :url

  ## 
  # Creates a new AppleNotesEmbeddedDeletedObject object. 
  # Expects a +uuid+ that would have been the ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, 
  # String +uti+ that would have been the ZICCLOUDSYNCINGOBJECT.ZTYPEUTI, and an AppleNote +note+ object representing the parent AppleNote. 
  def initialize(uuid, uti, note)
    # Set this object's variables
    super("Deleted", uuid, uti, note)
  end

  ##
  # This method just returns a readable String for the object. 
  # Adds to the AppleNotesEmbeddedObject.to_s by pointing to where the media is.
  def to_s
    return "{Deleted embedded #{@type} object which had ZICCLOUDSYNCINGOBJECTS.ZIDENTIFIER: #{uuid}}" 
  end

end
