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
                :parent,
                :parent_id,
                :parent_uuid,
                :uuid

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
    @account.add_folder(self)
    @retain_order = false

    # By default we have no children
    @child_folders = Array.new()

    # By default we have no parent folder
    @parent = nil # Expects an AppleFolder object
    @parent_id = nil # Expects a z_pk value for a folder
    @parent_uuid = nil # Expects the zidentifier value for a folder

    # Pre-bake the sort order to a nice low value
    @sort_order = (0 - Float::INFINITY)

    @uuid = ""

    # Uncomment the below line if you want to see the folder names during creation
    #puts "Folder #{@primary_key} is called #{@name}"
  end

  ##
  # This method requires an AppleNote object as +note+ and adds it to the folder's Array.
  def add_note(note)
    @notes.push(note)
  end

  ##
  # This method identifies if an AppleNotesFolder has notes in it.
  def has_notes
    return (@notes.length > 0)
  end

  ##
  # This method requires an AppleNotesFolder object as +folder+ and adds it to the folder's @child_folders Array.
  # It also sets the child's parent variables to make sure the relationship goes both ways.
  def add_child(folder)
    folder.parent_id = @primary_key
    folder.parent = self
    @child_folders.push(folder)
  end

  ##
  # This is a helper function to tell if a folder is a child folder or not
  def is_child?
    return (@parent != nil)
  end

  ##
  # This is a helper function to tell if a folder is a parent of any folders
  def is_parent?
    return (@child_folders.length > 0)
  end

  ##
  # This is a helper function to identify child folders that need their parent set
  def is_orphan?
    return (@parent == nil and (@parent_id != nil or @parent_uuid != nil))
  end

  ##
  # This method sorts the child folders.
  def sort_children
    @child_folders.sort_by!(&:name)
  end

  ##
  # This class method spits out an Array containing the CSV headers needed to describe all of these objects. 
  # If you update this, PLEASE make sure you update the following definition as well. 
  def self.to_csv_headers
    ["Folder Primary Key", 
     "Folder Name", 
     "Number of Notes", 
     "Owning Account ID", 
     "Owning Account Name", 
     "Cloudkit Participants", 
     "Parent Folder Primary Key", 
     "Parent Folder Name", 
     "Smart Folder Query",
     "UUID"]
  end

  ##
  # This class method points to which column the Smart Folder query should go in.
  def self.csv_smart_folder_query_column
    return 8
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

    to_return = [@primary_key, @name, @notes.length, @account.primary_key, @account.name, participant_emails, parent_id, parent_name, "", @uuid]

    return to_return
  end

  def full_name
    return @name if !is_child?
    return "#{@parent.full_name} -> #{@name}"
  end

  #
  # This method prepares the folder name, as displayed in HTML, with links 
  # to each of its parents via a recursive approach. 
  def full_name_with_links(individual_files: false, use_uuid: false, relative_root: to_uri, include_id: false)

    builder = Nokogiri::HTML::Builder.new(encoding: "utf-8") do |doc|

      current_node = self
      parents = Array.new
      doc.span {

        # Build the list of folders we need to traverse
        while current_node.is_child?
          current_node = current_node.parent
          parents.push current_node
        end

        # traverse the list, creating a link for each
        parents.reverse.each do |parent|
          tmp_folder = parent.anchor_link(use_uuid: use_uuid)
          if individual_files
            tmp_folder = parent.to_uri.join("index.html").relative_path_from(relative_root)
          end
          options = {href: tmp_folder}
          options[:id] = "folder_#{parent.unique_id(use_uuid)}" if include_id
          doc.a(options) {
            doc.text parent.name
          }
          doc.text " -> "
        end

        tmp_folder = anchor_link(use_uuid: use_uuid)
        if individual_files
          tmp_folder = relative_root.join("index.html").relative_path_from(relative_root)
        end
        options = {href: tmp_folder}
        options[:id] = "folder_#{unique_id(use_uuid)}" if include_id
        doc.a(options) {
          doc.text @name
        }
      }
    end

    return builder.doc.root
  end

  ##
  # This method returns an Array of AppleNote objects in the appropriate order based on current sort settings.
  def sorted_notes
    return @notes if !@retain_order
    @notes.sort_by { |note| [note.is_pinned ? 1 : 0, note.modify_time] }.reverse
  end

  ## 
  # Returns a name with things removed that might allow for poorly placed files
  def clean_name
    @name.tr('/:\\', '_')
  end

  def to_relative_root(individual_files=false)
    return "../" if !individual_files
    return (@parent.to_relative_root(individual_files) + "../") if @parent
    return "../../../"
  end

  #
  # This method computes the path to get to the account root folder. It only 
  # has meaning when using the --individual-files switch at runtime.
  def to_account_root(individual_files=false)
    return "../" if !individual_files
    return (@parent.to_account_root(individual_files) + "../") if @parent
    return "../"
  end

  # 
  # This method is used to generate the filepath on disk for a folder, if the 
  # --individual-files switch is passed at run time.
  def to_path
    # If this folder has a parent, we do NOT want to embed the account name every time
    if @parent
      return @parent.to_path.join(Pathname.new("#{clean_name}"))
    end

    # If we get here, the folder is a root folder and we DO want to preface it with the account namespace
    return Pathname.new("#{@account.clean_name}-#{clean_name}")
  end

  #
  # This method is used to generate the actual clickable URI to get to a specific folder 
  # if the --individual-files switch is passed at runtime
  def to_uri
    # If this folder has a parent, we do NOT want to embed the account name every time
    if @parent
      return @parent.to_uri.join(Pathname.new(CGI.escapeURIComponent(clean_name)))
    end

    # If we get here, the folder is a root folder and we DO want to preface it with the account namespace
    return Pathname.new(CGI.escapeURIComponent("#{@account.clean_name}-#{clean_name}"))
  end

  def unique_id(use_uuid)
    if use_uuid && !@uuid.empty?
      @uuid
    else
      @primary_key
    end
  end

  ## 
  # This method generates a link to the anchor used if individual files are not desired.
  def anchor_link(use_uuid: false)
    "#folder_#{unique_id(use_uuid)}"
  end

  def generate_folder_hierarchy_html(individual_files: false, use_uuid: false, relative_root: '')
    folder_href = anchor_link(use_uuid: use_uuid)
    if individual_files
      folder_href = to_uri.join("index.html").relative_path_from(relative_root)
    end

    builder = Nokogiri::HTML::Builder.new(encoding: "utf-8") do |doc|
      doc.li(class: "folder") {
        doc.a(href: folder_href) {
          doc.text @name
        }

        if (is_parent? or has_notes)
          doc.ul(class: "folder_list") {
            @child_folders.each do |child_folder|
              doc << child_folder.generate_folder_hierarchy_html(individual_files: individual_files, use_uuid: use_uuid, relative_root: relative_root)
            end
          }
        end
      }
    end

    return builder.doc.root
  end

  def generate_html(individual_files: false, use_uuid: false)
    params = [individual_files, use_uuid]
    if @html && @html[params]
      return @html[params]
    end

    builder = Nokogiri::HTML::Builder.new(encoding: "utf-8") do |doc|
      doc.div {
        doc.h1 {

          if individual_files
            # If we're kicking out individual files, we need a way to browse the file structure
            doc.a(href: "#{to_account_root(individual_files)}index.html") {
              doc.text "#{@account.name}"
            }
            doc.text " -> "
            doc << full_name_with_links(individual_files: individual_files, use_uuid: use_uuid, include_id: true)
          else
            # If we have one big long output, we don't need to generate individual links, just add anchors
            doc.a(id: "folder_#{unique_id(use_uuid)}") {
              doc.text "#{@account.name} - #{full_name}"
            }
          end
        }

        if individual_files && is_parent?
          doc.ul(class: "folder_list") {
            @child_folders.each do |child_folder|
              doc << child_folder.generate_folder_hierarchy_html(individual_files: individual_files, use_uuid: use_uuid, relative_root: to_path)
            end
          }
        end

        doc.ul {
          # Now display whatever we ended up with
          sorted_notes.each do |note|
            href = "#note_#{note.unique_id(use_uuid)}"
            if individual_files
              href = CGI.escapeURIComponent(note.title_as_filename('.html', use_uuid: use_uuid))
            end
            doc.li {
              doc.a(href: href) {
                doc.text "Note #{note.unique_id(use_uuid)}"
              }

              doc.text ": #{note.title}#{" (📌)" if note.is_pinned}"
            }
          end
        }

        if !individual_files
          # Recursively genererate HTML for each child folder
          @child_folders.each do |child_folder|
            doc << child_folder.generate_html(individual_files: individual_files, use_uuid: use_uuid)
          end
        end
      }
    end

    @html ||= {}
    @html[params] = builder.doc.root
  end

  ##
  # This method prepares the data structure that JSON will use to generate JSON later.
  def prepare_json
    to_return = Hash.new()
    to_return[:primary_key] = @primary_key
    to_return[:uuid] = @uuid
    to_return[:name] = @name
    to_return[:account_id] = @account.primary_key
    to_return[:account] = @account.name
    to_return[:parent_folder_id] = @parent_id
    to_return[:child_folders] = Hash.new()
    @child_folders.each do |child_folder|
      to_return[:child_folders][child_folder.primary_key] = child_folder.prepare_json
    end
    to_return[:html] = generate_html

    to_return
  end

end
