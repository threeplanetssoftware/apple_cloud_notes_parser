
This folder contains a combination of actual test data and symlinks to data that cannot be checked into the repository. 
Any tests that require files which cannot be distributed have corresponding globals defined and will be filtered out of the run with the `missing_data` filter applied. 
The files that are needed and their corresponding globals are:

|File name|Purpose|Symlink?|Global|
|---------|-------|--------|------|
|NoteStore-tests.sqlite|Valid NoteStore file with some odd parsing examples hard coded into the fields.|Y|`TEST_FORMATTING_FILE`|
|notta-NoteStore.sqlite|Valid SQLite file that isn't a NoteStore.|N|`TEST_FALSE_SQLITE_FILE`|`
|itunes_backup|Folder containing an iTunes backup|Y|`TEST_ITUNES_DIR`|
|itunes_backup_no_account|Folder containing an iTunes backup without an Accounts folder|Y|`TEST_ITUNES_NO_ACCOUNT_DIR`|
|mac_backup|Folder containing a Mac backup of group.com.apple.notes|Y|`TEST_MAC_DIR`|
|mac_backup_no_account|Folder containing a Mac backup of group.com.apple.notes without an Accounts folder|Y|`TEST_MAC_NO_ACCOUNT_DIR`|
|physical_backup|Folder containing the contents of a physical backup|Y|`TEST_PHYSICAL_DIR`|
|physical_backup_no_account|Folder containing the contents of a physical backup without an Accounts folder|Y|`TEST_PHYSICAL_NO_ACCOUNT_DIR`|
|NoteStore.legacy.sqlite|Valid NoteStore file from a legacy iOS version|Y||
|NoteStore.11.sqlite|Valid NoteStore file from iOS 11|Y||
|NoteStore.12.sqlite|Valid NoteStore file from iOS 12|Y||
|NoteStore.13.sqlite|Valid NoteStore file from iOS 13|Y||
|NoteStore.14.sqlite|Valid NoteStore file from iOS 14|Y||
|NoteStore.15.sqlite|Valid NoteStore file from iOS 15|Y||
|NoteStore.16.sqlite|Valid NoteStore file from iOS 16|Y||
|NoteStore.17.sqlite|Valid NoteStore file from iOS 17|Y||

