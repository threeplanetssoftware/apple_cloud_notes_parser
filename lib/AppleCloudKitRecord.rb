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
    total_added = 0
    if unpacked_top
      unpacked_top["Participants"]["NS.objects"].each do |participant|

        # Pull out the relevant values
        if participant["UserIdentity"]
          participant_user_identity = participant["UserIdentity"]

          # Initialize a new AppleCloudKitShareParticipant
          tmp_participant = AppleCloudKitShareParticipant.new()

          # Read in the user's contact information
          if participant_user_identity["LookupInfo"]
            tmp_participant.email = participant_user_identity["LookupInfo"]["EmailAddress"]
            tmp_participant.phone = participant_user_identity["LookupInfo"]["PhoneNumber"]
          end

          # Read in user's record id
          if participant_user_identity["UserRecordID"]
            tmp_participant.record_id = participant_user_identity["UserRecordID"]["RecordName"]
          end

          # Read in name components
          if participant_user_identity["NameComponents"]
            participant_name_components = participant["UserIdentity"]["NameComponents"]["NS.nameComponentsPrivate"]

            # Split the name up into its components
            tmp_participant.name_prefix = participant_name_components["NS.namePrefix"]
            tmp_participant.first_name = participant_name_components["NS.givenName"]
            tmp_participant.middle_name = participant_name_components["NS.middleName"]
            tmp_participant.last_name = participant_name_components["NS.familyName"]
            tmp_participant.name_suffix = participant_name_components["NS.nameSuffix"]
            tmp_participant.nickname = participant_name_components["NS.nickname"]
            tmp_participant.name_phonetic = participant_name_components["NS.phoneticRepresentation"]
          end

          # Add them to this object
          @share_participants.push(tmp_participant)
          total_added += 1
        end
      end
    end
    total_added
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

      # Sometimes folders don't have their parent reflected in the ZPARENT column and instead
      # are reflected in this field. Let's set the parent_uuid field and let AppleNoteStore 
      # play cleanup later.
      if unpacked_top["RecordType"] == "Folder" and unpacked_top["ParentReference"]
        @parent_uuid = unpacked_top["ParentReference"]["recordID"]["RecordName"]
      end
    end
  end

  ##
  # This method takes a String +record_id+ to determine if the particular cloudkit 
  # record is known. It returns an AppleCloudKitParticipant object, or False.
  def cloud_kit_record_known?(record_id)
    @share_participants.each do |participant|
      return participant if participant.record_id.eql?(record_id)
    end
    return false
  end

  

end
