# This has been used to quickly prototype the .proto file.
# This file is messy, but if you check out the https://github.com/jmendeth/protobuf-inspector 
# repo and use this as your config, it will nominally parse specific notes or embedded objects.
# To parse a note (if this file is in the root of protobuf-inspector): python3 main.py < your_extracted_note.pb
# To parse an embedded object: python3 main.py mergeabledata1_proto < your_extracted_object.pb

types = {
  # Main Note Data protobuf
  "root": { 
    2: ("document"),
  },

  # Related to a Note
  "document": { #
    # 1: unknown?
    2: ("varint", "Version"),
    3: ("note", "Note"),
  },

  "note": { # 
    2: ("string", "Note Text"),
    3: ("unknown_chunk", "Unknown Chunk"),
    4: ("unknown_note_stuff", "Unknown Stuff"),
    5: ("attribute_run", "Attribute Run"),
  },

  "unknown_chunk": {
    5: ("varint", "One-up ID"),
  },

  "unknown_note_stuff": {
    1: ("unknown_note_stuff_entry"),
  },

  "unknown_note_stuff_entry": {
  },

  "attribute_run": { #
    1: ("varint", "Length"),
    2: ("paragraph_style", "Paragraph Style"),
    3: ("note_font", "Font"),
    5: ("enum formatting_enum", "Font Hints"), # 1 is bold, 2 is italics, 3 is both
    6: ("varint", "Underlined"),
    7: ("varint", "Strikethrough"),
    8: ("int32", "superscript"), # Sign indicates super/sub
    9: ("string", "Link"),
    10: ("color", "Color"),
    12: ("attachment_info", "Attachment Info"),
  },

  "paragraph_style": { #
    1: ("enum style_enum", "Style Type"),
    # 3: unknown?
    4: ("varint", "Indent Number"),
    5: ("paragraph_todo", "Todo"),
  },

  "enum style_enum": { #
    0: "0: Title",
    1: "1: Heading",
    2: "2: Subheading",
    4: "4: Monospaced",
    100: "100: Dotted list",
    101: "101: Dashed list",
    102: "102: Ordered list",
    103: "103: Checkbox",
  },

  "paragraph_todo": { #
    1: ("bytes", "Todo UUID"),
    2: ("varint", "Done"),
  },

  "note_font": { #
    1: ("string", "Font Name"),
    2: ("varint", "Point Size"),
    3: ("varint", "Font Hints"),
  },

  "attachment_info": { #
    1: ("string", "Attachment Identifier"),
    2: ("string", "Type UTI"),
  },

  "enum formatting_enum": { #
    0: "0: --UNKNOWN--",
    1: "1: BOLD",
    2: "2: ITALIC",
    3: "3: BOLD ITALIC",
  },

  # Common types

  "color": {
    1: ("32bit", "Red"),
    2: ("32bit", "Green"),
    3: ("32bit", "Blue"),
    4: ("32bit", "Alpha"),
  },

  "object_id": {
    2: ("varint", "Unsigned Integer Value"),
    4: ("string", "String Value"),
    6: ("varint", "Object Index"),
  },

  "dictionary": { 
    1: ("dictionary_element", "Dictionary Element"),
  },

  "dictionary_element": { #
    1: ("object_id", "Key"),
    2: ("object_id", "Value"),
  },

  "map_entry": { #
    1: ("varint", "Key"),
    2: ("object_id", "Value"),
  },

  "ordered_set": { #
    1: ("ordered_set_ordering", "Ordering"),
    2: ("dictionary", "Elements"),
  },

  "ordered_set_ordering": { #
    1: ("ordered_set_ordering_array", "Array"),
    2: ("dictionary", "Contents"),
  },

  "ordered_set_ordering_array": {
    1: ("note", "Contents"),
    2: ("ordered_set_ordering_array_attachments", "Attachments"),
  },

  "ordered_set_ordering_array_attachments": {
    1: ("varint", "Index"),
    2: ("bytes", "UUID"),
  },

  "register_latest": {
    2: ("object_id", "Contents"),
  },

  # Mergeabledata1 blob for a ZICCLOUDSYNCINGOBJECTS.ZMERGEABLEDATA1 object
  "mergeabledata1_proto": { #
    2: ("mergeable_data_object", "Mergeable Data Object"),
  },

  "mergeable_data_object": { #
    3: ("mergeable_data_object_data", "Mergeable Data Object Data"),
  },

  "mergeable_data_object_data": { #
    3: ("mergeable_data_object_entry", "Mergeable Data Object Entry"),
    4: ("string", "Mergeable Data Object Key Item"),
    5: ("string", "Mergeable Data Object Type Item"),
    6: ("bytes", "Mergeable Data Object UUID Item"),
    # 7: unknown?
  },

  "mergeable_data_object_entry": { #
    1: ("register_latest", "Register Latest"),
    5: ("list", "List"),
    6: ("dictionary", "Dictionary"),
    # 9: unknown?
    10: ("note", "Note"),
    13: ("mergeable_data_object_custom_map", "Object Map"),
    16: ("ordered_set", "Ordered Set"),
  },

  "list": {
    1: ("list_entry", "List Entry"),
  },

  "list_entry": {
    2: ("object_id", "Object ID"),
    4: ("list_entry_details", "List Entry Details"),
  },

  "list_entry_details": {
    2: ("object_id", "Object ID"),
  },

  "mergeable_data_object_custom_map": {
    1: ("varint", "Type"),
    3: ("map_entry", "Map Entry"),
  },
}
