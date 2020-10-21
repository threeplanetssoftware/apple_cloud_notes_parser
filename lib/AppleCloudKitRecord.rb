require 'keyed_archive'
require_relative 'AppleCloudKitShareParticipant'

##
# This class represents a generic CloudKit Record. 
class AppleCloudKitRecord

  attr_accessor :share_participants,
                :server_record_data,
                :cloudkit_last_modified_device

  ##
  # Creates a new AppleCloudKitRecord.
  # Requires nothing and initializes the share_participants. 
  def initialize()
    # Tracks the AppleCloudKitParticipants this is shared with
    @share_participants = Array.new()
    @server_record_data = nil
    @cloudkit_last_modified_device = nil
    @cloudkit_creator_record_id = nil
    @cloudkit_modifier_record_id = nil
  end

  ##
  # This method adds CloudKit Share data to an AppleCloudKitRecord. It requires 
  # a binary String +cloudkit_data+ from the ZSERVERSHAREDATA column. 
  def add_cloudkit_sharing_data(cloudkit_data)
    keyed_archive = KeyedArchive.new(:data => cloudkit_data)
    unpacked_top = keyed_archive.unpacked_top()
    if unpacked_top
      unpacked_top["Participants"]["NS.objects"].each do |participant|

        # Pull out the relevant values
        participant_email = participant["UserIdentity"]["LookupInfo"]["EmailAddress"]
        participant_phone = participant["UserIdentity"]["LookupInfo"]["PhoneNumber"]
        participant_record = participant["UserIdentity"]["UserRecordID"]["RecordName"]
        participant_name_components = participant["UserIdentity"]["NameComponents"]["NS.nameComponentsPrivate"]

        # Initialize a new AppleCloudKitShareParticipant
        tmp_participant = AppleCloudKitShareParticipant.new()
        tmp_participant.record_id = participant_record
        tmp_participant.email = participant_email
        tmp_participant.phone = participant_phone

        # Read in name components
        tmp_participant.name_prefix = participant_name_components["NS.namePrefix"]
        tmp_participant.first_name = participant_name_components["NS.givenName"]
        tmp_participant.middle_name = participant_name_components["NS.middleName"]
        tmp_participant.last_name = participant_name_components["NS.familyName"]
        tmp_participant.name_suffix = participant_name_components["NS.nameSuffix"]
        tmp_participant.nickname = participant_name_components["NS.nickname"]
        tmp_participant.name_phonetic = participant_name_components["NS.phoneticRepresentation"]

        # Add them to this object
        @share_participants.push(tmp_participant)
      end
    end
  end

  ##
  # This method takes a the binary String +server_record_data+ which is stored 
  # in ZSERVERRECORDDATA. Currently just pulls out the last modified device. 
  def add_cloudkit_server_record_data(server_record_data)
    @server_record_data = server_record_data

    keyed_archive = KeyedArchive.new(:data => server_record_data)
    unpacked_top = keyed_archive.unpacked_top()
    if unpacked_top
      @cloudkit_last_modified_device = unpacked_top["ModifiedByDevice"]
      @cloudkit_creator_record_id = unpacked_top["CreatorUserRecordID"]["RecordName"]
      @cloudkit_modifier_record_id = unpacked_top["LastModifiedUserRecordID"]["RecordName"]
    end
  end

end
