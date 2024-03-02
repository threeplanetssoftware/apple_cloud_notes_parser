require 'base64'
require 'json'
require 'keyed_archive'
require_relative 'AppleNoteStore.rb'

##
# This class represents a com.apple.notes.table object embedded
# in an AppleNote. These tables are simple formatting that don't allow for 
# any additional formatting or embedded objects in them, as of iOS 13.
class AppleNotesEmbeddedTable < AppleNotesEmbeddedObject

  attr_accessor :primary_key,
                :uuid,
                :type

  # Constant to more obviously represent left to right tables
  LEFT_TO_RIGHT_DIRECTION = "CRTableColumnDirectionLeftToRight"
  # Constant to more obviously represent right to left tables
  RIGHT_TO_LEFT_DIRECTION = "CRTableColumnDirectionRightToLeft"

  ## 
  # Creates a new AppleNotesEmbeddedTable object. 
  # Expects an Integer +primary_key+ from ZICCLOUDSYNCINGOBJECT.Z_PK, String +uuid+ from ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, 
  # String +uti+ from ZICCLOUDSYNCINGOBJECT.ZTYPEUTI, and AppleNote +note+ object representing the parent AppleNote. 
  def initialize(primary_key, uuid, uti, note)
    # Set this objects's variables
    super(primary_key, uuid, uti, note)

    # This will hold our reconstructed table, plaintext and HTML
    @reconstructed_table = Array.new
    @reconstructed_table_html = Array.new

    # These variables hold different parts of the protobuf
    @row_items = Array.new
    @table_objects = Array.new
    @uuid_items = Array.new
    @type_items = Array.new

    @total_rows = 0
    @total_columns = 0

    # This will hold a mapping of UUID index number to row Array index in @reconstructed_table
    @row_indices = Hash.new

    # This will hold a mapping of UUID index number to column Array index in @reconstructed_table
    @column_indices = Hash.new

    # This will hold the table's direction, it defaults to left-to-right, will be changed during rebuild_table if needed
    @table_direction = LEFT_TO_RIGHT_DIRECTION
    #rebuild_table
  end

  ##
  # This method just returns a readable String for the object. 
  # Adds to the default to include the text of the table, with each 
  # row on a new line.
  def to_s
    string_to_add = " with cells: "
    @reconstructed_table.each do |row|
      string_to_add += "\n"
      row.each do |column|
        string_to_add += "\t#{column}"
      end
    end
    super + string_to_add
  end

  ##
  # This method takes a MergeableDataObjectEntry +object_entry+ which should have a MergeableDataObjectMap inside of it.
  # It looks at the MergeableDataObjectMap to find the UUID pointer, and returns the UUID index.
  def get_target_uuid_from_object_entry(object_entry)
    object_entry.custom_map.map_entry.first.value.unsigned_integer_value
  end

  ##
  # This method initializes the reconstructed table. It loops over the +total_columns+ 
  # and +total_columns+ that were assessed for the table and builds a two dimensional array of 
  # empty strings.
  def initialize_table
    @total_rows.times do |row|
      @reconstructed_table.push(Array.new(@total_columns, ""))
      @reconstructed_table_html.push(Array.new(@total_columns, ""))
    end
  end

  ##
  # This method takes a MergeableDataObjectEntry +object_entry+ that it expects to include an 
  # OrderedSet with type +crRows+. It loops over each attachment to identify the UUIDs that represent 
  # table rows and puts them in the appropriate order. It then adds indices to +@row_indices+ to 
  # let later code look up where a given row falls in the +@reconstructed_table+.
  def parse_rows(object_entry)
    @total_rows = 0
    object_entry.ordered_set.ordering.array.attachment.each do |attachment|
      @row_indices[@uuid_items.index(attachment.uuid)] = @total_rows
      @total_rows += 1
    end

    # Figure out the translations for where each row points to in the @reconstructed_table
    object_entry.ordered_set.ordering.contents.element.each do |dictionary_element|
      key_object = get_target_uuid_from_object_entry(@table_objects[dictionary_element.key.object_index])
      value_object = get_target_uuid_from_object_entry(@table_objects[dictionary_element.value.object_index])
      @row_indices[value_object] = @row_indices[key_object]
    end
  end

  ##
  # This method takes a MergeableDataObjectEntry +object_entry+ that it expects to include an 
  # OrderedSet with type +crColumns+. It loops over each attachment to identify the UUIDs that represent 
  # table columns and puts them in the appropriate order. It then adds indices to +@column_indices+ to 
  # let later code look up where a given column falls in the +@reconstructed_table+.
  def parse_columns(object_entry)
    @total_columns = 0
    object_entry.ordered_set.ordering.array.attachment.each do |attachment|
      @column_indices[@uuid_items.index(attachment.uuid)] = @total_columns
      @total_columns += 1
    end

    # Figure out the translations for where each row points to in the @reconstructed_table
    object_entry.ordered_set.ordering.contents.element.each do |dictionary_element|
      key_object = get_target_uuid_from_object_entry(@table_objects[dictionary_element.key.object_index])
      value_object = get_target_uuid_from_object_entry(@table_objects[dictionary_element.value.object_index])
      @column_indices[value_object] = @column_indices[key_object]
    end
  end

  ##
  # This method does the hard work of building the rows and columns with cells in them. It 
  # expects a MergeableDataObjectEntry +object_entry+ which should have a type of +cellColumns+.
  # It loops over each of its Dictionary elements, which represent each column. Inside of each Dictionary 
  # element is a key that ends up pointing to a UUID index representing the column and a value 
  # that points to a separate object which is a Dictionary of row UUIDs to cell (Note) objects. 
  # This calls get_target_uuid_from_table_object on the first key to get th column's index and
  # then does that for each of the rows it points to. With this information, it can look up 
  # where in the +@reconstructed_table+ the Note it is pointing to goes.
  def parse_cell_columns(object_entry)

    # Loop over each of the dictionary elements in the cellColumns object, these are all column pointers
    object_entry.dictionary.element.each do |column|
      current_column = get_target_uuid_from_object_entry(@table_objects[column.key.object_index])
      target_dictionary_object = @table_objects[column.value.object_index]

      # Loop over each of the dictionary elements in the Dictionary that was referenced in the prior value, these are rows
      target_dictionary_object.dictionary.element.each do |row|
        current_row = get_target_uuid_from_object_entry(@table_objects[row.key.object_index])
        target_cell = @table_objects[row.value.object_index]
        
        # Check for any embedded objects and generate them if they exist
        replaced_objects = AppleNotesEmbeddedObject.generate_embedded_objects(@note, target_cell)
        cell_string_html = AppleNote.htmlify_document(target_cell, replaced_objects[:objects])

        cell_string = ""
        cell_string = replaced_objects[:to_string] if replaced_objects[:to_string]
        @reconstructed_table[@row_indices[current_row]][@column_indices[current_column]] = cell_string if (@row_indices[current_row] and @column_indices[current_column])
        @reconstructed_table_html[@row_indices[current_row]][@column_indices[current_column]] = cell_string_html if (@row_indices[current_row] and @column_indices[current_column])

        # Push any embedded objects into the AppleNote's recursive array, pushing onto the regular array would overwrite the table
        replaced_objects[:objects].each do |replaced_object|
          @note.embedded_objects_recursive.push(replaced_object)
        end
      end
    end
  end

  ##
  # This method takes a MergeableDataObjectEntry +object_entry+ that it expects to be of type 
  # +com.apple.notes.ICTable+, representing the actual table. It looks over each of the MapEntry 
  # objects within to handle each as it needs to be, using the aforecreated fucntions. The +crTableColumnDirection+ 
  # object isn't quite understood yet and is handled elsewhere. As this gets enough information, it initializes 
  # the +reconstructed_table+ and flips the tabl's direction if the order changes. 
  def parse_table(object_entry)
    if object_entry.custom_map and @type_items[object_entry.custom_map.type] == "com.apple.notes.ICTable"

      # Variable to make sure we don't try to parse cell columns prior to doing rows or columns
      need_to_parse_cell_columns = false
      object_entry.custom_map.map_entry.each do |map_entry|
        case @key_items[map_entry.key]
        when "crTableColumnDirection"
          #puts "Column Direction: #{object_entrys[map_entry.value.object_index]}"
        when "crRows"
          parse_rows(@table_objects[map_entry.value.object_index])
        when "crColumns"
          parse_columns(@table_objects[map_entry.value.object_index])
        when "cellColumns"
           # parse_cell_columns(@table_objects[map_entry.value.object_index])
           need_to_parse_cell_columns = @table_objects[map_entry.value.object_index]
        end

        # Check if we have both rows, and columns, and the cell_columns not yet run
        if @total_rows > 0 and @total_columns > 0 and need_to_parse_cell_columns
          # If we know how many rows and columns we have, we can initialize the table
          initialize_table if (@total_columns > 0 and @total_rows > 0 and @reconstructed_table.length < 1)

          # Actually parse through the values
          parse_cell_columns(need_to_parse_cell_columns)
          need_to_parse_cell_columns = false
        end        
      end

      # We need to reverse the table if it is right to left
      if @table_direction == RIGHT_TO_LEFT_DIRECTION
        @reconstructed_table.each do |row|
          row.reverse!
        end
        @reconstructed_table_html.each do |row|
          row.reverse!
        end
      end
    end
  end


  ##
  # This method rebuilds the embedded table. It extracts the gzipped data, gunzips it, and builds a 
  # MergableDataProto from the result. It then loops over each of the key, type, and UUID items 
  # in the proto to build an index for reference. Then it loops over all the objects in the proto 
  # to do similar, as well as identifying the table's direction. Finally, it finds the root table 
  # and calls parse_table on it.
  def rebuild_table

    if !@gzipped_data
      @gzipped_data = fetch_mergeable_data_by_uuid(@uuid)
    end

    if @gzipped_data and @gzipped_data.length > 0
  
      # Inflate the GZip
      zlib_inflater = Zlib::Inflate.new(Zlib::MAX_WBITS + 16)
      mergeable_data = zlib_inflater.inflate(@gzipped_data)

      # Read the protobuff
      mergabledata_proto = MergableDataProto.decode(mergeable_data)

      # Build list of key items
      @key_items = Array.new
      mergabledata_proto.mergable_data_object.mergeable_data_object_data.mergeable_data_object_key_item.each do |key_item|
        @key_items.push(key_item)
      end

      # Build list of type items
      @type_items = Array.new
      mergabledata_proto.mergable_data_object.mergeable_data_object_data.mergeable_data_object_type_item.each do |type_item|
        @type_items.push(type_item)
      end

      # Build list of uuid items
      @uuid_items = Array.new
      mergabledata_proto.mergable_data_object.mergeable_data_object_data.mergeable_data_object_uuid_item.each do |uuid_item|
        @uuid_items.push(uuid_item)
      end

      # Build Array of objects
      @table_objects = Array.new
      mergabledata_proto.mergable_data_object.mergeable_data_object_data.mergeable_data_object_entry.each do |mergeable_data_object_entry|
        @table_objects.push(mergeable_data_object_entry)

        # Best way I've found to set the table direction
        if mergeable_data_object_entry.custom_map
          if mergeable_data_object_entry.custom_map.map_entry.first.key == @key_items.index("crTableColumnDirection") + 1 #Oddly seems to correspond to 'self'
            @table_direction = mergeable_data_object_entry.custom_map.map_entry.first.value.string_value
          end
        end
      end

      # Find the first ICTable, which shuld be the root, and execute
      mergabledata_proto.mergable_data_object.mergeable_data_object_data.mergeable_data_object_entry.each do |mergeable_data_object_entry|
        if mergeable_data_object_entry.custom_map and @type_items[mergeable_data_object_entry.custom_map.type] == "com.apple.notes.ICTable"
          parse_table(mergeable_data_object_entry)
        end
      end
    else
      # May want to catch this scenario
    end

  end

  ##
  # This method generates the HTML necessary to display the table. 
  # For display purposes, if a cell would be completely empty, it is 
  # displayed as having one space in it.
  def generate_html(individual_files=false)

    # Return our to_string function if we aren't reconstructed yet
    return self.to_s if (!@reconstructed_table_html or @reconstructed_table_html.length == 0)

    # Create an HTML table
    builder = Nokogiri::HTML::Builder.new(encoding: "utf-8") do |doc|
      doc.table {
        # Loop over each row and create a new table row
        @reconstructed_table_html.each do |row|
          doc.tr {
            # Loop over each column and place the cell value into a td
            row.each do |column|
              doc.td {
                doc << column
              }
            end
          }
        end
      }
    end

    return builder.doc.root
  end

  ##
  # This method prepares the data structure that JSON will use to generate a JSON object later.
  def prepare_json
    to_return = super()
    to_return[:table] = Array.new()

    return to_return if (!@reconstructed_table or @reconstructed_table.length == 0)

    @reconstructed_table.each_with_index do |row, row_index|
      to_return[:table][row_index] = Array.new()
      row.each_with_index do |column, column_index|
        to_return[:table][row_index][column_index] = column
      end
    end
    
    to_return
  end

end
