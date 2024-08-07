
# JSON Format

## AppleNoteStore

The JSON file's overall output is what is generated by the `AppleNoteStore` class, as noted below.

``` json
{
  "version": "[integer listing iOS version]",
  "file_path": "[filepath to OUTPUT database]",
  "backup_type": "[integer indicating the type of backup]",
  "html": "[full HTML goes here]",
  "accounts": {
    "[account z_pk]": "[AppleNotesAccount object JSON]"
  },
  "cloudkit_participants": {
    "[cloudkit identifier]": "[AppleCloudKitShareParticipant object JSON]"
  },
  "folders": {
    "[folder z_pk]": "[AppleNotesFolder object JSON]"
  },
  "notes": {
    "[note id]": "[AppleNote object JSON]"
  }
}
```
The JSON output of `AppleNotesAccount` is as follows.

``` json
{
  "primary_key": "[integer account z_pk]",
  "name": "[account name]",
  "identifier": "[account ZIDENTIFIER]",
  "cloudkit_identifier": "[account Cloudkit identifier]",
  "cloudkit_last_modified_device": "[account last modified device]",
  "html": "[HTML generated for the specific account goes here]"
}
```

## AppleCloudKitShareParticipant

The JSON output of `AppleCloudKitShareParticipant` is as follows.

``` json
{
  "email": "[user's email, if available]",
  "record_id": "cloudkit identifier",
  "first_name": "[user's first name, if available]",
  "last_name": "[user's last name, if available]",
  "middle_name": "[user's middle name, if available]",
  "name_prefix": "[user's name prefix, if available]",
  "name_suffix": "[user's name suffix, if available]",
  "name_phonetic": "[user's name pronunciation, if available]",
  "phone": "[user's phone number, if available]"
}
```

## AppleNotesFolder

The JSON output of `AppleNotesFolder` is as follows.

``` json
{
  "primary_key": "[integer folder z_pk]",
  "uuid": "[folder uuid from ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER]",
  "name": "[folder name]",
  "account_id": "[integer z_pk for the account this belongs to]",
  "account": "[account name]",
  "parent_folder_id": "[integer of parent folder's z_pk, if applicable]",
  "child_folders": {
    "[folder z_pk]": "[AppleNotesFolder object JSON]"
  },
  "html": "[folder HTML output]",
  "query": "[query string if folder is a smart folder]"
}
```

## AppleNote

The JSON output of `AppleNote` is as follows.

``` json
{
  "account_key": "[z_pk of the account]",
  "account": "[account name]",
  "folder_key": "[z_pk of the folder]",
  "folder": "[Folder name]",
  "note_id": "[note ID]",
  "uuid": "[note uuid from ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER]",
  "primary_key": "[z_pk of the note]",
  "creation_time": "[creation time in YYYY-MM-DD HH:MM:SS TZ format]",
  "modify_time": "[modify time in YYYY-MM-DD HH:MM:SS TZ format]",
  "cloudkit_creator_id": "[cloudkit ID of the note creator, if applicable]",
  "cloudkit_modifier_id": "[cloudkit ID of the last note modifier, if applicable]",
  "cloudkit_last_modified_device": "[last modified device, according to CloudKit]",
  "is_pinned": "[boolean, whether pinned or not]",
  "is_password_protected": "[boolean, whether password protected or not]",
  "title": "[Note title]",
  "plaintext": "[plaintext of the note",
  "html": "[HTML of the note]",
  "note_proto": "[NoteStoreProto dump of the decoded protobuf]",
  "embedded_objects": [
    "[Array of AppleNotesEmbeddedObject object JSON]"
  ],
  "hashtags": [
    "#Test"
  ],
  "mentions": [
    "@FirstName [CloudKit Email]"
  ]
}
```

## AppleNotesEmbeddedObject

The JSON output of `AppleNotesEmbeddedObject` is as follows.

``` json
{
  "primary_key": "[z_pk of the object]",
  "parent_primary_key": "[z_pk of the object's parent, if applicable]",
  "note_id": "[note ID]",
  "uuid": "[ZIDENTIFIER of the object]",
  "type": "[ZTYPEUTI of the object]",
  "filename": "[filename of the object, if applicable]",
  "filepath": "[filepath of the object, including filename, if applicable]",
  "backup_location": "[Filepath of the original backup location, if applicable]",
  "user_title": "[The alternate filename given by the user, if applicable]",
  "is_password_protected": "[boolean, whether password protected or not]",
  "html": "[generated HTML for the object]",
  "thumbnails": [
    "[Array of AppleNotesEmbeddedObject object JSON, if applicable]"
  ],
  "child_objects": [
    "[Array of AppleNotesEmbeddedObject object JSON, if applicable]"
  ],
  "table": [
    [
      "row 0", "column 0",
      "row 0", "column 1... etc"
    ]
  ],
  "url": "[url, if applicable]"
}
```

