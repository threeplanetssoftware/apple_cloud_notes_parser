#Copyright (c) 2014 Paul Young (https://github.com/paulyoung/keyed_archive)

#MIT License

#Permission is hereby granted, free of charge, to any person obtaining
#a copy of this software and associated documentation files (the
#"Software"), to deal in the Software without restriction, including
#without limitation the rights to use, copy, modify, merge, publish,
#distribute, sublicense, and/or sell copies of the Software, and to
#permit persons to whom the Software is furnished to do so, subject to
#the following conditions:

#The above copyright notice and this permission notice shall be
#included in all copies or substantial portions of the Software.

#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
#LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
#OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
#WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Note: 
# Inlining KeyedArchive directly into this repo to cut down on external dependancies. 
# The source code has been stable for a number of years and continuing to cut release
# to keep up with changes in Ruby default gems does not appear likely.

require 'cfpropertylist'

class KeyedArchive

  attr_accessor :archiver, :objects, :top, :version

  # 
  # Take the same sort of arguments as CFPropertyList
  # :file => filename to load
  # :data => variable with the data to load directly
  def initialize(opts={})
    blob = opts[:data]
    filename = opts[:file]

    plist = CFPropertyList::List.new(:file => filename) unless filename.nil? or !File.exist?(filename)
    plist = CFPropertyList::List.new(:data => blob) unless blob.nil? or blob.length < 1

    if !plist.nil?
      data = CFPropertyList.native_types(plist.value)

      @archiver = data['$archiver']
      @objects = data['$objects']
      @top = data['$top']
      @version = data['$version']
    else
      raise "Plist not created"
    end
  end

  # Loops through the entries within '$top' 
  # to replace any values that are pointers to objects.
  def unpacked_top

    # Create the return value
    unpacked_top = Hash.new

    # Loop over each pair in the '$top' hash
    # to recursively replace the values
    @top.each_pair do |key, value|
      unpacked_top[key] = recursive_replace(value, -1, [])
    end

    # Politely return, our job is done
    return unpacked_top
  end

  private

  # Handles the recursive replacement of values within the 
  # '$objects' array. Tracks the object locations it has 
  # already touched to prevent infinite loops. 
  def recursive_replace(value, current_location, locations)
    # By default we just return the value itself, usually a String
    to_return = value

    # If the value is really representing nil, change it to nil
    if value.is_a? String and value == "$null"
      to_return = nil
    end

    # If we have an Integer, we want to bring in the object 
    # that Integer points to
    if value.is_a? Integer

      # If we ever find a reference to one of our parents, just stop where we are
      if locations.include?(current_location)
        to_return = value
      else
        to_return = recursive_replace(@objects[value], value, locations.clone.push(current_location)) 
      end

    # If we have a Hash, we want to check each entry 
    # and replace any values which need it
    elsif value.is_a? Hash

      # Build up a new Hash
      to_return = Hash.new

      # Loop over the pairs to check the key, value, or both
      value.each_pair do |tmp_key, tmp_value|

        # If this points to an array of objects, 
        # then we should bring those values in
        if tmp_key == "NS.objects" or tmp_key == "NS.keys"
          new_array = Array.new
          tmp_value.each do |entry|
            new_array.push(recursive_replace(entry, entry, locations.clone.push(current_location)))
          end
          to_return[tmp_key] = new_array

        # Otherwise, we just want to replace the value with
        # its recursive version
        else
          to_return[tmp_key] = recursive_replace(tmp_value, tmp_value, locations.clone.push(current_location))
        end
      end
    end

    # Give back the value, politely
    return to_return
  end
end

