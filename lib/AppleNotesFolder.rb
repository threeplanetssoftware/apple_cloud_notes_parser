require 'keyed_archive'
require_relative 'AppleCloudKitShareParticipant'

##
# This class represents a folder within Apple Notes.
# It understands which AppleNotesAccount it belongs to and has
# an array of AppleNote objects that belong to it.
class AppleNotesFolder

  attr_accessor :primary_key,
                :name,
                :account,
                :notes,
                :share_participants

  ##
  # Creates a new AppleNotesFolder.
  # Requires the folder's +primary_key+ as an Integer, +name+ as a String, and +account+ as an AppleNotesAccount.
  def initialize(folder_primary_key, folder_name, folder_account)
    # Initialize notes for this account
    @notes = Array.new()
    
    # Set this folder's variables
    @primary_key = folder_primary_key
    @name = folder_name
    @account = folder_account
    # Uncomment the below line if you want to see the folder names during creation
    #puts "Folder #{@primary_key} is called #{@name}"

    # Tracks the AppleCloudKitParticipants this is shared with
    @share_participants = Array.new()
  end

  ##
  # This method adds CloudKit data to an AppleNotesFolder. It requires 
  # a binary String +cloudkit_data+ which should 
  def add_cloudkit_data(cloudkit_data)
    keyed_archive = KeyedArchive.new(:data => cloudkit_data)
    unpacked_top = keyed_archive.unpacked_top()
    if unpacked_top
      unpacked_top["Participants"]["NS.objects"].each do |participant|

        # Pull out the relevant values
        participant_email = participant["UserIdentity"]["LookupInfo"]["EmailAddress"]
        participant_record = participant["UserIdentity"]["UserRecordID"]["RecordName"]

        # Initialize a new AppleCloudKitShareParticipant
        tmp_participant = AppleCloudKitShareParticipant.new()
        tmp_participant.record_id = participant_record
        tmp_participant.email = participant_email

        # Add them to this folder
        @share_participants.push(tmp_participant)
      end
    end
  end

  ##
  # This method requies an AppleNote object as +note+ and adds it to the folder's Array.
  def add_note(note)
    @notes.push(note)
  end

  ##
  # This class method spits out an Array containing the CSV headers needed to describe all of these objects
  def self.to_csv_headers
    ["Folder Primary Key", "Folder Name", "Number of Notes", "Owning Account ID", "Owning Account Name", "Cloudkit Participants"]
  end

  ##
  # This method generates an Array containing the information needed for CSV generation
  def to_csv
    participant_emails = @share_participants.map {|participant| participant.email}.join(",")
    [@primary_key, @name, @notes.length, @account.primary_key, @account.name, participant_emails]
  end

  def generate_html
    html = "<a id='folder_#{@primary_key}'><h1>#{@account.name} - #{@name}</h1></a>"
    html += "<ul>\n";
    @notes.each do |note|
      html += "<li><a href='#note_#{note.note_id}'>Note #{note.note_id}</a>: #{note.title}</li>\n";
    end
    html += "</ul>\n";
    return html
  end

end
