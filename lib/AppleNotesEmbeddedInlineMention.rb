require 'keyed_archive'
require 'sqlite3'
require_relative 'AppleCloudKitRecord'

##
# This class represents an inline text mention embedded in an AppleNote. 
# These were added in iOS 15 and allow users with shared notes to '@' other users that the note is shared with.
class AppleNotesEmbeddedInlineMention < AppleNotesEmbeddedInlineAttachment

  attr_accessor :target_account

  ##
  # Creates a new AppleNotesEmbeddedInlineMention. 
  # Expects an Integer +primary_key+ from ZICCLOUDSYNCINGOBJECT.Z_PK, String +uuid+ from ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, 
  # String +uti+ from ZICCLOUDSYNCINGOBJECT.ZTYPEUTI1, AppleNote +note+ object representing the parent AppleNote, 
  # a String +alt_text+ from ZICCLOUDSYNCINGOBJECT.ZALTTEXT, and a String +token_identifier+ from 
  # ZICCLOUDSYNCINGOBJECT.ZTOKENCONTENTIDENTIFIER representing what the text stands for.
  def initialize(primary_key, uuid, uti, note, alt_text, token_identifier)
    super(primary_key, uuid, uti, note, alt_text, token_identifier)

    @target_account = nil
    @target_account = @note.notestore.cloud_kit_participants[@token_identifier]

    # Fall back to just displaying a local account, this generally appears as __default_owner__
    @target_account = @note.notestore.get_account_by_user_record_name(@token_identifier) if !@target_account
  end

  ##
  # This method just returns a readable String for the object.
  # By default it just lists the +alt_text+. Subclasses 
  # should override this.
  def to_s
    return "#{@alt_text} [#{@target_account.email}]" if @target_account and @target_account.is_a?(AppleCloudKitShareParticipant) and @target_account.email
    return "#{@alt_text} [Local Account: #{@target_account.name}]" if @target_account and @target_account.is_a?(AppleNotesAccount) and @target_account.name
    return "#{@alt_text} [#{@token_identifier}]"
  end

  ##
  # This method generates the HTML to be embedded into an AppleNote's HTML.
  def generate_html
    return self.to_s
  end

end
