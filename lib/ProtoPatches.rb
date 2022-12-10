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
end

class Color
  def red_hex_string
    (red * 255).round().to_s(16).upcase
  end

  def green_hex_string
    (green * 255).round().to_s(16).upcase
  end

  def blue_hex_string
    (blue * 255).round().to_s(16).upcase
  end

  def full_hex_string
    "##{red_hex_string}#{green_hex_string}#{blue_hex_string}"    
  end
end

class AttributeRun

  attr_accessor :previous_run, :next_run

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

    no_attachment_info = !attachment_info # We don't want to get so greedy with attachments

    return (same_paragraph and same_font and same_font_weight and same_underlined and same_strikethrough and same_superscript and same_link and same_color and same_attachment_info and no_attachment_info)
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
  # Helper function to tell if a given AttributeRun is any sort of AppleNote::STYLE_TYPE_X_LIST.
  def is_any_list?
    return (is_numbered_list? or is_dotted_list? or is_dashed_list?)
  end

  ##
  # This method calculates the total indentation of a given AttributeRun. It caches the result since
  # it has to recursively check the previous AttributeRuns.
  def total_indent

    to_return = 0

    # Determine what this AttributeRun's indent amount is on its own
    my_indent = 0
    if paragraph_style and paragraph_style.indent_amount
      my_indent = paragraph_style.indent_amount
    end

    # If there is no previous AttributeRun, the answer is just this AttributeRun's indent amount
    if !previous_run
      to_return = my_indent
    # If there is something previous, add our indent to its total indent
    else
      to_return = my_indent + previous_run.total_indent
    end
    
    return to_return
  end

  ##
  # This method generates the HTML for a given AttributeRun. It expects a String as +text_to_insert+
  def generate_html(text_to_insert)
    html = ""
  
    initial_run = false
    initial_run = true if !previous_run
    final_run = false
    final_run = true if !next_run
 
    # Deal with the style type 
    if has_style_type and !same_style_type_previous?
      case paragraph_style.style_type
      when AppleNote::STYLE_TYPE_TITLE
        html += "<h1>"
      when AppleNote::STYLE_TYPE_HEADING
        html += "<h2>"
      when AppleNote::STYLE_TYPE_SUBHEADING
        html += "<h3>"
      when AppleNote::STYLE_TYPE_MONOSPACED
        html += "<code>"
      when AppleNote::STYLE_TYPE_NUMBERED_LIST
        html += "<ol><li>"
      when AppleNote::STYLE_TYPE_DOTTED_LIST
        html += "<ul><li>"
      when AppleNote::STYLE_TYPE_DASHED_LIST
        html += "<ul><li>"
      end
    end

    #if (!is_any_list? and !is_checkbox? and total_indent > 0)
    #  puts "Total indent: #{total_indent}"
    #  html += "\t-"
    #end
  
    # Handle AppleNote::STYLE_TYPE_CHECKBOX separately because they're special
    if is_checkbox?
      # Set the style to apply to the list item
      style = "unchecked"
      style = "checked" if paragraph_style.checklist.done == 1

      if (initial_run or !previous_run.is_checkbox?)
        html += "<ul class='checklist'><li class='#{style}'>"
      elsif previous_run.paragraph_style.checklist.uuid != paragraph_style.checklist.uuid
        html += "</li><li class='#{style}'>"
      end
    end

    # Deal with the font
    if font_weight and !same_font_weight_previous?
      case font_weight
      when AppleNote::FONT_TYPE_DEFAULT
        # Do nothing
      when AppleNote::FONT_TYPE_BOLD
        html += "<b>"
      when AppleNote::FONT_TYPE_ITALIC
        html += "<i>"
      when AppleNote::FONT_TYPE_BOLD_ITALIC
        html += "<b><i>"
      end
    end

    # Add in underlined
    if underlined == 1
      html += "<u>" if (initial_run or previous_run.underlined != 1)
    end

    # Add in strikethrough
    if strikethrough == 1
      html += "<s>" if (initial_run or previous_run.strikethrough != 1)
    end

    # Add in superscript
    if superscript == 1
      html += "<sup>" if (initial_run or previous_run.superscript != 1)
    end

    # Add in subscript
    if superscript == -1
      html += "<sub>" if (initial_run or previous_run.superscript != -1)
    end
  
    # Handle fonts and colors 
    font_style = ""
    color_style = ""

    if font and font.font_name
      font_style = "face='#{font.font_name}'"
    end

    if color
      color_style = "color='#{color.full_hex_string}'"
    end
 
    if font_style.length > 0 and color_style.length > 0
      html +="<font #{font_style} #{color_style}>"
    elsif font_style.length > 0
      html +="<font #{font_style}>"
    elsif color_style.length > 0
      html +="<font #{color_style}>"
    end

    # Escape HTML in the actual text of the note
    text_to_insert = CGI::escapeHTML(text_to_insert)

    closed_font = false
    need_to_close_li = false
    # Edit the text if we need to make small changes based on the paragraph style
    if is_any_list?
      need_to_close_li = text_to_insert.end_with?("\n")
      text_to_insert = text_to_insert.split("\n").join("</li><li>")

      # Check it see if we have an open list element...
      if need_to_close_li

        # Also if we're going to need to close a font element...
        if (font_style.length > 0 or color_style.length > 0)
          # ... if so close the font and remember we did so
          #text_to_insert += "</font>"
          #closed_font = true
        end

        # ... then close the list element tag
        #text_to_insert += "</li><li>"
      end
    end

    # Clean up checkbox newlines
    if is_checkbox?
      text_to_insert.gsub!("\n","")
    end

    # Add in links that are part of the text itself, doing this after cleaning the note so the <a> tag lives
    if link and link.length > 0
      text_to_insert = "<a href='#{link}' target='_blank'>#{text_to_insert}</a>"
    end

    # Add the text into HTML finally and start closing things up
    html += text_to_insert

    # Handle fonts
    if font_style.length > 0 or color_style.length > 0
      html +="</font>" if !closed_font
    end

    # Add in subscript
    if superscript == -1
      html += "</sub>" if (final_run or next_run.superscript != -1)
    end

    # Add in superscript
    if superscript == 1
      html += "</sup>" if (final_run or next_run.superscript != 1)
    end

    # Add in strikethrough
    if strikethrough == 1
      html += "</s>" if (final_run or next_run.underlined != 1)
    end

    # Add in underlined
    if underlined == 1
      html += "</u>" if (final_run or next_run.underlined != 1)
    end

    # Close the font if this is the last AttributeRun or if the next is different
    if font_weight and !same_font_weight_next?
      case font_weight
      when AppleNote::FONT_TYPE_DEFAULT
        # Do nothing
      when AppleNote::FONT_TYPE_BOLD
        html += "</b>"
      when AppleNote::FONT_TYPE_ITALIC
        html += "</i>"
      when AppleNote::FONT_TYPE_BOLD_ITALIC
        html += "</i></b>"
      end
    end

    if need_to_close_li
      html += "</li><li>"
    end

    # Close the style type if this is the last AttributeRun or if the next is different
    if has_style_type and !same_style_type_next?
      case paragraph_style.style_type
      when AppleNote::STYLE_TYPE_TITLE
        html += "</h1>" 
      when AppleNote::STYLE_TYPE_HEADING
        html += "</h2>" 
      when AppleNote::STYLE_TYPE_SUBHEADING
        html += "</h3>" 
      when AppleNote::STYLE_TYPE_MONOSPACED
        html += "</code>" 
      when AppleNote::STYLE_TYPE_NUMBERED_LIST
        html += "</li></ol>" 
      when AppleNote::STYLE_TYPE_DOTTED_LIST
        html += "</li></ul>" 
      when AppleNote::STYLE_TYPE_DASHED_LIST
        html += "</li></ul>" 
      when AppleNote::STYLE_TYPE_CHECKBOX
        html += "</li></ul>" 
      end
    end

    html.gsub!(/<h1>\s*<\/h1>/,'') # Remove empty titles
    html.gsub!(/<li><\/li>/,'') # Remove empty list elements
    html.gsub!(/\n<\/h1>/,'</h1>') # Remove extra line breaks in front of h1
    html.gsub!(/\n<\/h2>/,'</h2>') # Remove extra line breaks in front of h2
    html.gsub!(/\n<\/h3>/,'</h3>') # Remove extra line breaks in front of h3
    html.gsub!("\u2028",'<br/>') # Translate \u2028 used to denote newlines in lists into an actual HTML line break

    return html
  end
end

