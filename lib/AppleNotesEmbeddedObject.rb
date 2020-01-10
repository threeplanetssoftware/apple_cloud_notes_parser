require 'sqlite3'

#
# Type: com.apple.notes.table
# This UUID has a ZMERGABLEDATA1 that is a gzipped protobuf. 
# The protobuf appears to use the same structure as the com.apple.notes.gallery, 
# but instead of providing a different UUID, it holds the data with in it. Plaintext 
# for the cells can be found in: 2->3->3->10->2 as a string. Structure is as yet unknown.

#
# Type: com.apple.drawing.2
# This UUID has a ZMERGABLEDATA1 that is a protobuf with an extra 6 bytes on the front 
# (consistently 0x77 0x72 0x64 0xf0 0x01 0x00). This protobuf likely holds the drawing directly. 
# Parsing this is not yet implemented.

#
# Type: com.apple.notes.gallery (pictures already taken on the phone)
# This UUID has a ZMERGABLEDATA1 that is a gzipped protobuf.
# In that protobuf is a UUID which represents the ZIDENTIFIER of the media
# That ZIDENTIFIER's ZMEDIA column has the Z_PK of the actual file to look up
# The ZFILENAME column of that Z_PK has the actual image's filename and the folder in ZIDENTIFIER
# Test file was found in Manifest.db in: Accounts/LocalAccount/Media/B3E4576F-1BA5-4139-8C0C-43730D3D2A57/CB2F663E-6603-4B55-A8B8-AACEAC4482C9.jpg

#
# Type: public.jpeg / public.png (pictures taken in the Notes app)
# This ZIDENTIFIER's ZMEDIA column has the Z_PK of the actual file to look up.
# The ZIDENTIFIER from that Z_PK is the folder that holds the filename in ZFILENAME
# For example: Accounts/LocalAccount/Media/D72E0056-F9A3-40C1-BF9C-60EAECBC4F1B/Image.jpeg

##
# This class represents an object embedded in an AppleNote.
class AppleNotesEmbeddedObject

  attr_accessor :primary_key,
                :uuid,
                :type,
                :filepath,
                :filename,
                :backup_location

  ##
  # Creates a new AppleNotesEmbeddedObject. 
  # Expects an Integer +primary_key+ from ZICCLOUDSYNCINGOBJECT.Z_PK, String +uuid+ from ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, 
  # String +uti+ from ZICCLOUDSYNCINGOBJECT.ZTYPEUIT, and AppleNote +note+ object representing the parent AppleNote.
  def initialize(primary_key, uuid, uti, note)
    # Set this folder's variables
    @primary_key = primary_key
    @uuid = uuid
    @type = uti
    @note = note
    @database = @note.database
    @filepath = ""
    @filename = ""
    @backup_location = nil
    #puts self.to_s
  end

  ##
  # This method just returns a readable String for the object.
  # By default it just lists the +type+ and +uuid+. Subclasses 
  # should override this.
  def to_s
    "Embedded Object #{@type}: #{@uuid}"
  end

  ##
  # By default this returns its own +uuid+. 
  # Subclasses will override this if they have other pointers to media objects.
  def get_media_uuid
    @uuid
  end

  ##
  # By default this returns its own +filepath+. 
  # Subclasses will override this if they have other pointers to media objects.
  def get_media_filepath
    @filepath
  end

  ##
  # By default this returns its own +filename+. 
  # Subclasses will override this if they have other pointers to media objects.
  def get_media_filename
    @filename
  end

  ##
  # Class method to return an Array of the headers used on CSVs for this class
  def self.to_csv_headers
    ["Object Primary Key", 
     "Note ID",
     "Object UUID", 
     "Object Type",
     "Object Filename",
     "Object Filepath on Phone",
     "Object Filepath on Computer"]
  end

  ##
  # This method returns an Array of the fields used in CSVs for this class
  # Current spits out the +primary_key+, +uuid+, +type+, +filepath+, and +filename+.
  def to_csv
    [@primary_key, 
     @note.note_id,
     @uuid, 
     @type,
     @filename,
     @filepath,
     @backup_location]
  end

  ##
  # This method generates the HTML to be embedded into an AppleNote's HTML.
  def generate_html
    return self.to_s
  end

end
