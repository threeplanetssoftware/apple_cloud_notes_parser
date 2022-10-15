##
# This class represents a member of the CKShareParticipant class, 
# which is used to track who is a participant on items shared with 
# Apple's Cloud Kit. 
class AppleCloudKitShareParticipant

  attr_accessor :email,
                :first_name,
                :last_name,
                :middle_name,
                :nickname,
                :name_prefix,
                :name_suffix,
                :name_phonetic,
                :phone,
                :record_id
  ##
  # Creates a new AppleCloudKitShareParticipant. 
  def initialize()
    @email = nil
    @first_name = nil
    @last_name = nil
    @middle_name = nil
    @nickname = nil
    @name_prefix = nil
    @name_suffix = nil
    @name_phonetic = nil
    @phone = nil
    @record_id = nil
  end

  ## 
  # Compares to AppleCloudKitParticipant objects, based on their +record_id+. 
  def ==(other_participant)
    return (other_participant.is_a? AppleCloudKitShareParticipant and other_participant.record_id == @record_id)
  end

  ##
  # This class method spits out an Array containing the CSV headers needed to describe all of these objects
  def self.to_csv_headers
      ["Account Record ID", "Account Email", "Account Phone", "Prefix", "First Name", "Middle Name", "Last Name", "Suffix", "Phonetic"]
  end

  ##
  # This method generates an Array containing the information necessary to build a CSV
  def to_csv
    [@record_id, @email, @phone, @name_prefix, @first_name, @middle_name, @last_name, @name_suffix, @name_phonetic]
  end

  ##
  # This method prepares the data structure that JSON will use to generate JSON later.
  def prepare_json
    to_return = Hash.new()
    to_return[:email] = @email
    to_return[:record_id] = @record_id
    to_return[:first_name] = @first_name
    to_return[:last_name] = @last_name
    to_return[:middle_name] = @middle_name
    to_return[:name_prefix] = @name_prefix
    to_return[:name_suffix] = @name_suffix
    to_return[:name_phonetic] = @name_phonetic
    to_return[:phone] = @phone

    to_return
  end

end
