require_relative 'notestore_pb.rb'

# A little monkey patching never hurt anyone
class ParagraphStyle
  def ==(other_paragraph_style)
    return false if !other_paragraph_style
    same_style_type = (style_type == other_paragraph_style.style_type)
    same_alignment = (alignment == other_paragraph_style.alignment)
    same_indent = (indent_amount == other_paragraph_style.indent_amount)
    same_checklist = (checklist == other_paragraph_style.checklist)

    return (same_style_type and same_alignment and same_indent and same_checklist)
  end

  def normalized_indent_amount
    indent = indent_amount&.to_i

    # The special "block quote" type doesn't have its own `indent_amount` set
    # at the root level (but it does for nested indents). So in order to
    # leverage the rest of our indent/blockquote logic, treat the special
    # "block quote" types as though it were indented.
    if block_quote == AppleNote::STYLE_TYPE_BLOCK_QUOTE
      indent += 1
    end

    indent
  end
end

class Color
  def red_hex_string
    (red * 255).round().to_s(16).upcase.rjust(2, "0")
  end

  def green_hex_string
    (green * 255).round().to_s(16).upcase.rjust(2, "0")
  end

  def blue_hex_string
    (blue * 255).round().to_s(16).upcase.rjust(2, "0")
  end

  def full_hex_string
    "##{red_hex_string}#{green_hex_string}#{blue_hex_string}"    
  end
end

class AttributeRun

  attr_accessor :previous_run, :next_run, :tag_is_open

  def has_style_type
    paragraph_style and paragraph_style.style_type
  end

  def same_style?(other_attribute_run)
    return false if !other_attribute_run
    same_paragraph = (paragraph_style == other_attribute_run.paragraph_style)
    same_font = (font == other_attribute_run.font)
    same_font_weight = (font_weight == other_attribute_run.font_weight)
    same_underlined = (underlined == other_attribute_run.underlined)
    same_strikethrough = (strikethrough == other_attribute_run.strikethrough)
    same_superscript = (superscript == other_attribute_run.superscript)
    same_link = (link == other_attribute_run.link)
    same_color = (color == other_attribute_run.color)
    same_attachment_info = (attachment_info == other_attribute_run.attachment_info)
    same_block_quote = (is_block_quote? == other_attribute_run.is_block_quote?)
    same_emphasis_style = (emphasis_style == other_attribute_run.emphasis_style)

    no_attachment_info = !attachment_info # We don't want to get so greedy with attachments

    return (same_paragraph and 
            same_font and 
            same_font_weight and 
            same_underlined and 
            same_strikethrough and 
            same_superscript and 
            same_link and 
            same_color and 
            same_attachment_info and 
            no_attachment_info and 
            same_block_quote and 
            same_emphasis_style)
  end

  ##
  # This method checks if the previous AttributeRun had the same style_type
  def same_style_type_previous?
    same_style_type?(previous_run)
  end

  ##
  # This method checks if the next AttributeRun had the same style_type
  def same_style_type_next?
    same_style_type?(next_run)
  end

  ##
  # This method compares the paragraph_style.style_type integer of two AttributeRun 
  # objects to see if they have the same style_type.
  def same_style_type?(other_attribute_run)
    return false if !other_attribute_run

    # We clearly aren't the same if one or the other lacks a style type completely
    return false if (other_attribute_run.has_style_type and !has_style_type)
    return false if (!other_attribute_run.has_style_type and has_style_type)

    # If neither has a style type, that is the same
    return true if (!other_attribute_run.has_style_type and !has_style_type)

    # If the indent levels are different, then the styles are different.
    return false if (other_attribute_run.paragraph_style.indent_amount != paragraph_style.indent_amount)

    # If the block-quotedness are different, then the styles are different.
    return false if (other_attribute_run.paragraph_style.block_quote != paragraph_style.block_quote)

    # If both are checkboxes, but they belong to different checklist UUIDs,
    # then the styles are different.
    return false if (is_checkbox? && other_attribute_run.is_checkbox? && other_attribute_run.paragraph_style.checklist.uuid != paragraph_style.checklist.uuid)

    # Compare our style_type to the other style_type and return the result
    return (other_attribute_run.paragraph_style.style_type == paragraph_style.style_type)  
  end

  ##
  # Helper function to tell if a given AttributeRun has the same font weight as this one.
  def same_font_weight?(other_attribute_run)
    return false if !other_attribute_run
    return (other_attribute_run.font_weight == font_weight)
  end

  ##
  # Helper function to tell if the previous AttributeRun has the same font weight as this one.
  def same_font_weight_previous?
    same_font_weight?(previous_run)
  end

  ##
  # Helper function to tell if the next AttributeRun has the same font weight as this one.
  def same_font_weight_next?
    same_font_weight?(next_run)
  end

  ##
  # Helper function to tell if a given AttributeRun is an AppleNote::STYLE_TYPE_CHECKBOX.
  def is_checkbox?
    return (has_style_type and paragraph_style.style_type == AppleNote::STYLE_TYPE_CHECKBOX)
  end

  ##
  # Helper function to tell if a given AttributeRun is an AppleNote::STYLE_TYPE_NUMBERED_LIST.
  def is_numbered_list?
    return (has_style_type and paragraph_style.style_type == AppleNote::STYLE_TYPE_NUMBERED_LIST)
  end

  ##
  # Helper function to tell if a given AttributeRun is an AppleNote::STYLE_TYPE_DOTTED_LIST.
  def is_dotted_list?
    return (has_style_type and paragraph_style.style_type == AppleNote::STYLE_TYPE_DOTTED_LIST)
  end

  ##
  # Helper function to tell if a given AttributeRun is an AppleNote::STYLE_TYPE_DASHED_LIST.
  def is_dashed_list?
    return (has_style_type and paragraph_style.style_type == AppleNote::STYLE_TYPE_DASHED_LIST)
  end

  ##
  # Helper function to tell if a given AttributeRun is an AppleNote::STYLE_TYPE_BLOCK_QUOTE.
  def is_block_quote?
    return (has_style_type and paragraph_style.block_quote == AppleNote::STYLE_TYPE_BLOCK_QUOTE)
  end

  ##
  # Helper function to tell if a given AttributeRun is any sort of AppleNote::STYLE_TYPE_X_LIST.
  def is_any_list?
    return (is_numbered_list? or is_dotted_list? or is_dashed_list? or is_checkbox?)
  end

  ##
  # This method calculates the total indentation of a given AttributeRun. It caches the result since
  # it has to recursively check the previous AttributeRuns.
  def total_indent

    return @indent if @indent

    @indent = 0

    # Determine what this AttributeRun's indent amount is on its own
    my_indent = 0
    if paragraph_style and paragraph_style.indent_amount
      my_indent = paragraph_style.indent_amount
    end

    # If there is no previous AttributeRun, the answer is just this AttributeRun's indent amount
    if !previous_run
      @indent = my_indent
    # If there is something previous, add our indent to its total indent
    else
      @indent = my_indent + previous_run.total_indent
    end
    
    return @indent
  end

  def open_html_tag(tag_name, attributes = {})
    tag = Nokogiri::XML::Node.new(tag_name, @active_html_node.document)
    attributes.each do |key, value|
      tag[key] = value
    end

    @active_html_node = @active_html_node.add_child(tag)
  end

  def close_html_tag
    unless @active_html_node.parent.nil?
      @active_html_node = @active_html_node.parent
    end
  end

  def add_text_style_html(text_to_insert)
    original_active_html_node = @active_html_node

    # Deal with the font
    if font_weight
      case font_weight
      when AppleNote::FONT_TYPE_DEFAULT
        # Do nothing
      when AppleNote::FONT_TYPE_BOLD
        if @active_html_node.node_name != "h1" && @active_html_node.node_name != "h2" && @active_html_node.node_name != "h3"
          open_html_tag("b")
        end
      when AppleNote::FONT_TYPE_ITALIC
        open_html_tag("i")
      when AppleNote::FONT_TYPE_BOLD_ITALIC
        if @active_html_node.node_name != "h1" && @active_html_node.node_name != "h2" && @active_html_node.node_name != "h3"
          open_html_tag("b")
        end
        open_html_tag("i")
      end
    end

    # Add in underlined
    if underlined == 1
      open_html_tag("u")
    end

    # Add in strikethrough
    if strikethrough == 1
      open_html_tag("s")
    end

    # Add in superscript
    if superscript == 1
      open_html_tag("sup")
    end

    # Add in subscript
    if superscript == -1
      open_html_tag("sub")
    end

    # Handle fonts and colors
    style_attrs = {}
    if font
      if font.font_name
        style_attrs["font-family"] = "'#{font.font_name.gsub("'", "\\\\'")}'"
      end
      if font.point_size && font.point_size != 0
        style_attrs["font-size"] = "#{font.point_size}px"
      end
    end
    if color
      style_attrs["color"] = color.full_hex_string
    end
    if emphasis_style
      if emphasis_style == 1 # Purple
        style_attrs["color"] = "#FF00FF"
        style_attrs["background-color"] = "#BA55D333"
      elsif emphasis_style == 2 # Pink
        style_attrs["color"] = "#FF4081"
        style_attrs["background-color"] = "#D5000044"
      elsif emphasis_style == 3 # Orange
        style_attrs["color"] = "#FBC02D"
        style_attrs["background-color"] = "#FF6F0022"
      elsif emphasis_style == 4 # Mint
        style_attrs["color"] = "#8DE5DB"
        style_attrs["background-color"] = "#289C8ECC"
      elsif emphasis_style == 5 # Blue
        style_attrs["color"] = "#BBDEFB"
        style_attrs["background-color"] = "#2196F3"
      end
    end
    if style_attrs.any?
      open_html_tag("span", { style: style_attrs.map { |k, v| "#{k}: #{v}" }.join("; ") })
    end

    if link and link.length > 0
      open_html_tag("a", { href: link, target: "_blank" })
    end

    # Change any null characters into the appropriate Unicode symbol indicating one existed.
    text_to_insert.gsub!("\u0000", "\u2400")
    @active_html_node.add_child(Nokogiri::XML::Text.new(text_to_insert, @active_html_node.document))

    @active_html_node = original_active_html_node
  end

  def add_html_text(text_to_insert)
    parts = text_to_insert.split(/(\u2028|\n)/)
    parts.each_with_index do |line, index|
      case line
      # New lines in headers or check lists.
      when "\u2028"
        @active_html_node.add_child(Nokogiri::XML::Node.new("br", @active_html_node.document))

      # Normal new lines
      when "\n"
        node_name = @active_html_node.node_name

        # Always add a normal new line if inside a <pre> tag.
        if node_name == "pre" || @active_html_node.ancestors("pre").any?
          @active_html_node.add_child(Nokogiri::XML::Text.new("\n", @active_html_node.document))

        # Add <br> tags for any other new line.
        else
          @active_html_node.add_child(Nokogiri::XML::Node.new("br", @active_html_node.document))
        end
      else
        add_text_style_html(line) if line.length > 0
      end
    end
  end

  def open_alignment_tag
    # Open a new div if the text alignment is not the default.
    style_attrs = {}
    case paragraph_style&.alignment
    when AppleNote::STYLE_ALIGNMENT_CENTER
      style_attrs["text-align"] = "center"
    when AppleNote::STYLE_ALIGNMENT_RIGHT
      style_attrs["text-align"] = "right"
    when AppleNote::STYLE_ALIGNMENT_JUSTIFY
      style_attrs["text-align"] = "justify"
    end

    if style_attrs.any?
      open_html_tag("div", { style: style_attrs.map { |k, v| "#{k}: #{v}" }.join("; ") })
    end
  end

  def open_block_tag
    # Open a new block-level tag if the current attribute run is of a different
    # type than the previous.
    if has_style_type and !same_style_type_previous?
      case paragraph_style.style_type
      when AppleNote::STYLE_TYPE_TITLE
        open_html_tag("h1")
      when AppleNote::STYLE_TYPE_HEADING
        open_html_tag("h2")
      when AppleNote::STYLE_TYPE_SUBHEADING
        open_html_tag("h3")
      when AppleNote::STYLE_TYPE_MONOSPACED
        open_html_tag("pre")
      end
    end
  end

  def open_indent_tag
    tag_name = nil
    tag_attrs = {}

    # Determine which tag to open for indenting the list or block.
    case paragraph_style&.style_type
    when AppleNote::STYLE_TYPE_NUMBERED_LIST
      tag_name = "ol"
    when AppleNote::STYLE_TYPE_DOTTED_LIST
      tag_name = "ul"
      tag_attrs = { class: "dotted" }
    when AppleNote::STYLE_TYPE_DASHED_LIST
      tag_name = "ul"
      tag_attrs = { class: "dashed" }
    when AppleNote::STYLE_TYPE_CHECKBOX
      tag_name = "ul"
      tag_attrs = { class: "checklist" }
    else
      # If the text isn't a list, but is still marked as indented, then use a
      # <blockquote> tag to perform the indenting. The exception is if the text
      # is monospaced, in which case, there are explicit space characters that
      # provide the indentation.
      if paragraph_style&.normalized_indent_amount.to_i > 0 && @active_html_node.node_name != "pre"
        tag_name = "blockquote"

        # For the special block quote styles, add a CSS class to distinguish
        # this from blockquotes tags used only for indents. Only apply this to
        # the first level, since Notes only styles these differently at the
        # first level (nested levels inside are treated as normal indents).
        if is_block_quote? && paragraph_style&.normalized_indent_amount.to_i == 1
          tag_attrs = { class: "block-quote" }
        end
      end
    end

    # Open up the indentation tag if we've determined one is necessary.
    if tag_name
      indent_amount = paragraph_style&.normalized_indent_amount.to_i
      previous_indent_amount = previous_run&.paragraph_style&.normalized_indent_amount.to_i

      # If this is the same style as the previous indent, or if the indentation
      # is nested more deeply, then we need to look for the previous list
      # that's already present in the HTML that we should possibly continue.
      if paragraph_style&.style_type == previous_run&.paragraph_style&.style_type || indent_amount > 0
        # If the indent level needs to go deeper than the previous run, or the
        # previous list tag was never closed, then find the existing list tag
        # to nest things inside of. Otherwise, look for an existing tag at the
        # same level to continue.
        if indent_amount > previous_indent_amount || (indent_amount == previous_indent_amount && previous_run&.tag_is_open)
          child_tag_name = "li"
          if tag_name == "blockquote"
            child_tag_name = "blockquote"
          end

          # Look for the last, inner-most list tag to continue.
          @active_html_node = @active_html_node.last_element_child&.at_xpath("(.//#{child_tag_name}[not(.//#{child_tag_name})])[last()]", "(self::node()[self::#{child_tag_name}])") || @active_html_node
        else
          # Look for the last list container tag at the same indent level.
          @active_html_node = @active_html_node.last_element_child&.at_xpath("(.//*[@data-apple-notes-indent-amount=#{indent_amount}])[last()]", "self::node()[@data-apple-notes-indent-amount=#{indent_amount}]") || @active_html_node
        end
      end

      # Determine what the current list indent level is for any opened tags we
      # are nested inside of, and then determine how many new indent levels
      # need to be opened to reach our target indent amount.
      current_indent_amount = @active_html_node.attr("data-apple-notes-indent-amount")&.to_i || @active_html_node.ancestors("[data-apple-notes-indent-amount]")&.first&.attr("data-apple-notes-indent-amount")&.to_i
      if current_indent_amount
        indent_range = (current_indent_amount + 1)..indent_amount
      elsif tag_name == "blockquote"
        indent_range = 1..indent_amount
      else
        indent_range = 0..indent_amount
      end

      # For each indent level that's missing, open up new tags for each level.
      indent_range.each_with_index do |indent_amount, index|
        level_tag_attrs = tag_attrs.merge({
          "data-apple-notes-indent-amount" => indent_amount,
        })

        if tag_name != "blockquote"
          if index > 0
            open_html_tag("li")
          end

          if indent_amount != indent_range.last
            level_tag_attrs[:class] = "none"
          end
        end

        open_html_tag(tag_name, level_tag_attrs)
      end
    end
  end

  def add_list_text(text_to_insert)
    li_attrs = {}
    if is_checkbox?
      li_attrs["class"] = (paragraph_style.checklist.done == 1) ? "checked" : "unchecked"
    end

    list_items = text_to_insert.split(/(\n)/)
    list_items.each_with_index do |list_item_text, index|
      if list_item_text == "\n"
        if index != list_items.length - 1
          close_html_tag
        end
      else
        if @active_html_node.node_name != "li"
          open_html_tag("li", li_attrs)
        end

        add_html_text(list_item_text)
      end
    end
  end

  ##
  # This method generates the HTML for a given AttributeRun. It expects a String as +text_to_insert+
  def generate_html(text_to_insert, root_node)
    @active_html_node = root_node
    @tag_is_open = !text_to_insert.end_with?("\n")

    open_alignment_tag
    open_block_tag
    open_indent_tag

    case @active_html_node.node_name
    when "ol", "ul", "li"
      add_list_text(text_to_insert)
    else
      add_html_text(text_to_insert)
    end

    return root_node
  end
end

