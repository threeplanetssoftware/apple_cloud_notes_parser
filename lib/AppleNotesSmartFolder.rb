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
    # Get the parent's CSV and overwrite the query field
    to_return = super()
    to_return[AppleNotesFolder.csv_smart_folder_query_column] = @query

    return to_return
  end

  def generate_html(individual_files: false, use_uuid: false)
    builder = Nokogiri::HTML::Builder.new(encoding: "utf-8") do |doc|
      doc.div {
        doc.h1 {
          doc.a(id: "folder_#{unique_id(use_uuid)}") {
            doc.text "#{@account.name} - #{full_name}"
          }
        }
        doc.div {
          doc.text "A smart folder looking for notes matching: "
          doc.code {
            doc.text query
          }
        }
      }
    end

    return builder.doc.children
  end

  def prepare_json
    to_return = super()
    to_return[:query] = @query

    to_return
  end

end
