require_relative 'AppleCloudKitRecord'

##
# This class represents a folder within Apple Notes.
# It understands which AppleNotesAccount it belongs to and has
# an array of AppleNote objects that belong to it.
class AppleNotesFolder < AppleCloudKitRecord

  attr_accessor :primary_key,
                :name,
                :account,
                :notes,
                :retain_order,
                :sort_order,
                :parent

  ##
  # Creates a new AppleNotesFolder.
  # Requires the folder's +primary_key+ as an Integer, +name+ as a String, and +account+ as an AppleNotesAccount.
  def initialize(folder_primary_key, folder_name, folder_account)
    super()
    # Initialize notes for this account
    @notes = Array.new()
    
    # Set this folder's variables
    @primary_key = folder_primary_key
    @name = folder_name
    @account = folder_account
    @retain_order = false

    # By default we have no children
    @child_folders = Array.new()

    # By default we have no parent folder
    @parent = nil

    # Pre-bake the sort order to a nice high value
    @sort_order = (0 - Float::INFINITY)

    # Uncomment the below line if you want to see the folder names during creation
    #puts "Folder #{@primary_key} is called #{@name}"
  end

  ##
  # This method requires an AppleNote object as +note+ and adds it to the folder's Array.
  def add_note(note)
    @notes.push(note)
  end

  ##
  # This method requires an AppleNotesFolder object as +folder+ and adds it to the folder's @child_folders Array
  def add_child(folder)
    @child_folders.push(folder)
  end

  ##
  # This is a helper function to tell if a folder is a child folder or not
  def is_child?
    return @parent != nil
  end

  ##
  # This method sorts the child folders.
  def sort_children
    @child_folders.sort_by!(&:name)
  end

  ##
  # This class method spits out an Array containing the CSV headers needed to describe all of these objects
  def self.to_csv_headers
    ["Folder Primary Key", "Folder Name", "Number of Notes", "Owning Account ID", "Owning Account Name", "Cloudkit Participants", "Parent Folder Primary Key", "Parent Folder Name"]
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
    to_return = [@primary_key, @name, @notes.length, @account.primary_key, @account.name, participant_emails, parent_id, parent_name]

    return to_return
  end

  def full_name
    return @name if !@parent
    return "#{@parent.full_name} -> #{@name}"
  end

  def generate_html
    html = "<a id='folder_#{@primary_key}'><h1>#{@account.name} - #{full_name}</h1></a>"
    html += "<ul>\n";

    # Sort the array if we want to retain the order
    note_order = @notes
    note_order = @notes.sort_by { |note| [note.is_pinned ? 1 : 0, note.modify_time] }.reverse if @retain_order

    # Now display whatever we ended up with
    note_order.each do |note|
      html += "<li><a href='#note_#{note.note_id}'>Note #{note.note_id}</a>: #{note.title}#{" (📌)" if note.is_pinned}</li>\n";
    end
    html += "</ul>\n";

    # Recursively genererate HTML for each child folder
    @child_folders.each do |child_folder|
      html += child_folder.generate_html
    end

    return html
  end

end
