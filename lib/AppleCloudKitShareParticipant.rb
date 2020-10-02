##
# This class represents a member of the CKShareParticipant class, 
# which is used to track who is a participant on items shared with 
# Apple's Cloud Kit. 
class AppleCloudKitShareParticipant

  attr_accessor :email,
                :first_name,
                :last_name,
                :record_id
  ##
  # Creates a new AppleCloudKitShareParticipant. 
  def initialize()
    @email = nil
    @first_name = nil
    @last_name = nil
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
      ["Account Record ID", "Account Email", "First Name", "Last Name"]
  end

  ##
  # This method generates an Array containing the information necessary to build a CSV
  def to_csv
    [@record_id, @email, @first_name, @last_name]
  end

end
