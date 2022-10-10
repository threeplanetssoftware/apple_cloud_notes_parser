#require_relative 'AppleCloudKitRecord'
require_relative 'AppleNotesFolder.rb'

##
# This class represents a smart folder within Apple Notes.
# It subclasses AppleNotesFolder and is mainly used to represent
# the difference in output since a smart folder doesn't have 
# any AppleNotes within it directly.
class AppleNotesSmartFolder < AppleNotesFolder

  attr_accessor :query

  ##
  # Creates a new AppleNotesSmartFolder.
  # Requires the folder's +primary_key+ as an Integer, +name+ as a String, 
  # +account+ as an AppleNotesAccount, and +query+ as a String representing 
  # how this folder selects notes to display.
  def initialize(folder_primary_key, folder_name, folder_account, query)
    super(folder_primary_key, folder_name, folder_account)

    @query = query
  end

  ##
  # This method generates an Array containing the information needed for CSV generation
  def to_csv
    participant_emails = @share_participants.map {|participant| participant.email}.join(",")
    parent_id = ""
    parent_name = ""
    if is_child?
      parent_id = @parent.primary_key
      parent_name = @parent.name
    end

    to_return = [@primary_key, @name, @notes.length, @account.primary_key, @account.name, participant_emails, parent_id, parent_name, @query]

    return to_return
  end

  def generate_html
    html = "<a id='folder_#{@primary_key}'><h1>#{@account.name} - #{full_name}</h1></a>"
    html += "<code>#{query}</code>"

    return html
  end

end
