# Apple Cloud Notes Parser
By: Jon Baumann, [Ciofeca Forensics](https://www.ciofecaforensics.com)

## About

This program is a parser for the current version of Apple Notes data syncable with iCloud as seen on Apple handsets in iOS 9 and later. 
This program is needed because Apple Notes data is stored in a series of protobufs and tables in the database and it is not always easy to piece them back together by hand. 
This program intends to make it easy for Apple users to backup Apple Notes of their own and to expose as much of the Apple Notes information as possible for forensic examiners.

This program was implemented in Ruby and currently requires Ruby 3.0 or newer.

## Features

This program will:
1. Parse legacy (pre-iOS9) Notes files (but those are already plaintext, so not much to be gained)
2. Parse iOS 9-15 Cloud Notes files
3. ... decrypting notes if the password is known and the device passcode is not used
3. ... generating CSV roll-ups of each account, folder, note, and embedded object within them
4. ... rebuilding the notes as an HTML file to browse and see as they would be displayed on the phone
5. ... amending the NoteStore.sqlite database to include plaintext and decompressed objects to interact with in other tools
6. ... from iTunes logical backups, physical backups, single files, and directly from Mac versions
7. ... displaying tables as actual tables and ripping the embedded images from the backup and putting them into a folder with the other output files for review
8. ... identifying the CloudKit participants involved in any shared items.
9. ... producing well-structured JSON for automated backups
10. ... actually run tests against its output after 5 years of YOLO.

## Usage

### Base

This program is run by Ruby on a command line, using either `rake` or `ruby`. 
The easiest use is to drop your exported `NoteStore.sqlite` into the same directory as this program and then run `rake`:

```shell
[notta@cuppa apple_cloud_notes_parser]$ rake
/home/notta/.rvm/rubies/ruby-2.7.0/bin/ruby notes_cloud_ripper.rb --file NoteStore.sqlite

Starting Apple Notes Parser at Thu Aug  8 06:33:21 2024
Storing the results in ./output/2024_08_08-06_33_21

Created a new AppleBackup from single file: NoteStore.sqlite
Guessed Notes Version: 15
Apple Decrypter: Attempting to decrypt objects without a password list set, check the -w option for more success
Updated AppleNoteStore object with 108 AppleNotes in 26 folders belonging to 2 accounts.
Adding the ZICNOTEDATA.ZPLAINTEXT and ZICNOTEDATA.ZDECOMPRESSEDDATA columns, this takes a few seconds

Successfully finished at Thu Aug  8 06:33:22 2024
```

If you are more comfortable with the command line, you can point the program anywhere you would like on your computer and specify the type of backup you are looking at, see the Options section below for specifics.  
The benefit of pointing at full backups is this program can pull embedded files out of the notes, such as drawings and pictures.

### Options

The options that are currently supported are:

|Short Switch|Long Switch|Purpose|
|------------|-----------|-------|
|-i|--itunes-dir DIRECTORY|Root directory of an iTunes backup folder (i.e. where Manifest.db is). These normally have hashed filenames.|
|-f|--file FILE|Single NoteStore.sqlite file.|
|-g|--one-output-folder|Always write to the same output folder.|
|-p|--physical DIRECTORY|Root directory of a physical backup (i.e. right above /private).|
|-m|--mac DIRECTORY|Root directory of a Mac application (i.e. /Users/{username}/Library/Group Containers/group.com.apple.notes).|
|-o|--output-dir DIRECTORY|Change the output directory from the default ./output|
|-w|--password-file FILE|File with plaintext passwords, one per line.|
|-r|--retain-display-order|Retain the display order for folders and notes, not the database's order.|
||--show-password-successes|Toggle the display of password success ON.|
||--range-start DATE|Set the start date of the date range to extract. Must use YYYY-MM-DD format, defaults to 1970-01-01.|
||--range-end DATE|Set the end date of the date range to extract. Must use YYYY-MM-DD format, defaults to 2024-08-09.|
||--individual-files|Output individual HTML files for each note, organized in folders mirroring the Notes folder structure.|
||--uuid|Use UUIDs in HTML output rather than local database IDs.|
|-h|--help|Print help information|


### Docker

Thanks to @jareware, if you have [Docker installed already](https://docs.docker.com/get-docker/) you can run this program as a docker container.
This is a great way to ensure you will not run into any dependancy issues or have to have Ruby installed. 
Shell scripts have been provided in the `docker_scripts` folder to cover the most common use cases. 
Each of these uses the present working directory to create the output folder.
 
|Script|Purpose|
|------|-------|
|linux\_run\_file.sh|This script will run the program on a NoteStore.sqlite file found in the present working directory (as if you ran `--file NoteStore.sqlite`).|
|mac\_run\_file.sh|This script will run the program on a NoteStore.sqlite file found in the present working directory (as if you ran `--file NoteStore.sqlite`).|
|mac\_run\_itunes.sh|This script will run the program on the local user's Mobile Backups(as if you used `--itunes ~/Library/Application\ Support/MobileSync/Backup/[your backup]`).|
|mac\_run\_notes.sh|This script will run the program on the local user's Apple Notes directory (as if you used `--mac ~/Library/Group\ Containers/group.com.apple.notes`).|

If you are more experienced with Docker, you can use the base image with any of the below options the same as if you ran the program with Ruby. 
The basic command to use would be: 

``` shell
docker run --rm \
  -v [path to your data folder or file]:/data:ro \
  -v $(pwd)/output:/app/output \
  ghcr.io/threeplanetssoftware/apple_cloud_notes_parser \
  [your command line options]
```

As an example, to run a NoteStore.sqlite file that is in your current directory you would type:

``` shell
docker run --rm \
  -v "$(pwd)":/data:ro \
  -v "$(pwd)"/output:/app/output \
  ghcr.io/threeplanetssoftware/apple_cloud_notes_parser \
  --file /data/NoteStore.sqlite --one-output-folder
```

**Important Caveats**: 
 - While Docker can make things easier in some respects, it does so at the cost of additional complexity. It is harder to troubleshoot and adds more memory overhead.  It is my hope that the Docker image helps some use this program, but the first troubleshooting step that will be recommended is to use Ruby directly to see if that fixes the issue. 
 - The [base image](https://hub.docker.com/_/ruby/) that is used for the Docker container is published by Ruby. It relies on a Debian base layer and as of today has multiple "vulnerabilities" identified on Docker (i.e. packages that are out of date). Use the Docker container at your own risk and if you are uncomfortable with it, feel free to clone this repository and use Ruby to run it, instead. 
 - [MacOS permissions](https://docs.docker.com/desktop/mac/permission-requirements/) lead to read errors trying to mount the Notes and iTunes backups from elsewhere in the user's home folder. As a result, the shell scripts create a temporary folder in the present working directory and copy the relevant files into it. This is an ugly hack which will chew up extra disk space and time to perform the copy. If you dislike this tradeoff, feel free to clone this repository and use Ruby to run it, instead. 

## How It Works

### iTunes backup (-i option)

For backups created with iTunes MobileSync, that include a wide range of hashed files inside of folders named after the filename, this program expects to be given the root folder of that backup. With that, it will compute the path to the NoteStore.sqlite file. If it exists, that file will be copied to the output directory and the copy, not the original, will be opened.

For example, if you had an iTunes backup located in `/home/user/phone_rips/iphone/[deviceid]/` (Which means the Manifest.db is located at `/home/whatever/phone_rips/iphone/[deviceid]/Manifest.db`) you would run

```shell
ruby notes_cloud_ripper.rb -i /home/user/phone_rips/iphone/[deviceid]/
```

### Physical backup (-p option)

For backups created with a full file system (or at least the `/private` directory) from your tool of choice. This program expects to be given the root folder of that backup. With that, it will compute the path to the NoteStore.sqlite file. If it exists, that file will be copied to the output directory and the copy, not the original, will be opened.

For example, if you had a physical backup located in `/home/user/phone_rips/iphone/physical/` (Which means the phone's `/private` directory is located at `/home/whatever/phone_rips/iphone/physical/private/`) you would run:

```shell
ruby notes_cloud_ripper.rb -p /home/user/phone_rips/iphone/physical
```

### Single File (-f option)

For single file "backups", this program expects to be given the path of the NoteStore.sqlite file directly, although filename does not matter. If it exists, that file will be copied to the output directory and the copy, not the original, will be opened.

For example, if you had a NoteStore.sqlite file located in `/home/user/phone_rips/iphone/files/NoteStore.sqlite` you would run:

```shell
ruby notes_cloud_ripper.rb -f /home/user/phone_rips/iphone/files/NoteStore.sqlite
```

### Mac backup (-m option)

For backups created from the Notes app as installed on a Mac. This program expects to be given the group.com.apple.notes folder of that Mac. With that, it will compute the path to the NoteStore.sqlite file. If it exists, that file will be copied to the output directory and the copy, not the original, will be opened.

For example, if you were running this on data from a Mac used by 'Logitech' and had the full file system available, you would run:

```shell
ruby notes_cloud_ripper.rb -m /Users/Logitech/Library/Group Containers/group.com.apple.notes/
```

### Password (-w | --password-file FILE option)

For backups that may have encrypted notes within them, this option tells the program where to find its password list. This list should have one password per row and any passwords that correctly decrypt an encrypted note will be tried before the rest for future encrypted notes. 

For example, if you were running this on data from a Mac used by 'Logitech,' had the full file system available, and wanted to use a file called "passwords.txt" you would run: 

```shell
ruby notes_cloud_ripper.rb -m /Users/Logitech/Library/Group Containers/group.com.apple.notes/ -w passwords.txt
```

Note: As of March 2021, all logging of passwords to the local debug_log.txt file and HTML output has been removed. If you need to see which passwords generated decrypted notes, use the `--show-password-successes` switch and read the console output after the run.

Note: As of iOS 16, users can use their device passcode instead of a spearate password within Notes. This program does not yet handle that case, it will simply fail to decrypt.

### Date Range Extraction

**Note: This feature is not intended to be robust. It does not smartly handle differences in timezones, nor convert to UTC. It is purely intended to help those with large Notes databases to better whittle down how much is processed.**

The `--range-start` and `--range-end` switches allow the user to specify starting and ending dates for which notes to extract. 
By default, these will cover "all time" (i.e. 1970 through to tomorrow) so all notes should match, assuming system time hasn't been messed with. 
Officially these switches request the date format in "YYYY-MM-DD" format, but technically as long as [Time.parse()](https://ruby-doc.org/stdlib-2.4.1/libdoc/time/rdoc/Time.html#method-c-parse) can understand the format, it should work.

These selections are made on the `ZICCLOUDSYNCINGOBJECT.ZMODIFIEDDATE1` field, which will capture any notes that have a modified date in that range. 
For example, if you wanted all notes modified after December 1, 2022, or all the notes modified in the month of June 2022, you could run: 

```shell
# All notes modified after December 1, 2022
ruby notes_cloud_ripper.rb -f NoteStore.sqlite --range-start "2022-12-01"

# All notes modified in the month of June 2022
ruby notes_cloud_ripper.rb -f NoteStore.sqlite --range-start "2022-06-01" --range-end "2022-07-01"
```

If you ever need to know what dates were used for a given backup, you can check the `debug_log.txt` file by looking for the line that has "Rip Notes" in it. 
For example:

```shell
[notta@cuppa apple_cloud_notes_parser]$ grep "Rip Notes" output/notes_rip/debug_log.txt 
D, [2024-05-04T10:26:27.076452 #4548] DEBUG -- : Rip Notes: Ripping notes between 1969-12-31 19:00:00 -0500 and 2024-05-04 10:26:26 -0400
D, [2024-05-04T10:26:28.552740 #4548] DEBUG -- : Rip Notes: Ripping notes between 1969-12-31 19:00:00 -0500 and 2024-05-04 10:26:26 -0400
```

### All Versions

Once the NoteStore file is opened, the program will create new AppleNotesAccount, AppleNotesFolder, and AppleNote objects based on the contents of that file. 
For each note, it takes the gzipped blob in the ZDATA field, gunzips it, and parses the protobuf that is inside. 
It will then add the plaintext from the protobuf of each note back into the NoteStore.sqlite file's `ZICNOTEDATA` table as a new column, `ZPLAINTEXTDATA` and create AppleNotesEmbeddedObject objects for each of the embedded objects it identifies.

### Output 

All of the output from this program will go into the output folder (it will be created if it doesn't exist), which defaults to `[location of this program]/output`. 
Within that folder, sub-folders will be created based on the current date and time, to the second. 
For example, if this program was run on December 17, 2019 at 10:24:28 local, the output for that run would be in `[location of this program]/output/2019_12_17-10_24_28/`. 
If the type of backup used has the original files referenced in attached media, this program will copy the file into the output directory, under `[location of this program]/output/[date of run]/files`, and beneath that following the file path on disk, relative to the Notes application folder. 

If the `-g` option is passed, this program will always save its output into the `[output location]/notes_rip` folder, overwriting the contents each time. 
This may be useful for version control, or for people only ever parsing the same set of notes each time. 

If the `-r` or `--retain-display-order` option is passed, then the HTML output will order the note entries under each folder at the top as Apple Notes displays them, not in the actual database order. 
This means that pinned notes will appear before unpinned notes and notes within the pinned and unpinned groups will be sorted according to modification time, newest to oldest. 
The order of note content at the bottom of the page will retain database order, by the note's ID (i.e. if Note 14 will come after Note 13 and before Note 15, regardless of which folders they are in). 
Soon the folder names themselves will also reflect the ordering as it appears in Apple Notes. 

If the `--individual-files` option is passed, then the HTML output will be produced as individual files for each note, organized in folders that mirror the Notes folder hierarchy. This can be useful for comparing successive exports to see which notes have changed.

If the `--uuid` option is passed, then the HTML output will refer to notes by their UUID (taken from `ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER`) rather than the integer ID used in the local database. These UUIDs should be consistent across devices synced with iCloud, whereas the integer IDs will be specific to each device.

This program will produce four CSV files summarizing the information stored in `[location of this program]/output/[date of run]/csv`: `note_store_accounts.csv`, `note_store_embedded_objects.csv`, `note_store_folders.csv`, and `note_store_notes.sqlite`. 
It will also produce an HTML dump of the notes to reflect the text and table formatting which may be meaningful in `[location of this program]/output/[date of run]/html`. 
Finally, it will produce a JSON dump for each of the NoteStore files, summarizing the accounts, folders, and notes within that NoteStore file. 
See [this file](JSON.md) for the JSON's schema.

Because Apple devices often have more than one version of Notes, it is important to note (pun intended) that all of the output is suffixed by a number, starting at 1, to identify which of the backups it corresponds to. 
In all cases where more than one is found, care is taken to produce output that assigns the suffix of 1 for the modern version, and the suffix of 2 for the legacy version. 

## Installation

Below are the general instructions for installing this program, OS-specific steps can be found [here](Install.md). 
The user can choose to use Git if they want to be able to keep up with changes, or just download the tool once, you do not need to do both. 
On each OS, you will want to:

1. Install Ruby, its development headers, and bundler if not already installed.
2. Install development headers for SQLite3 if not already installed.
3. Get this code
   1. Clone this repository with Git or
   2. Download the Zip file and unzip it
4. Enter the repository's directory.
5. Use bundler to install the required gems.
6. Run the program (see Usage section)!

## Tests

As of August 2024, tests have been added using [RSpec](https://rspec.info/). 
This test suite is not finished and has been in progress for a while, but in order to maintain consistent output with a few key additions, some tests are needed sooner than all tests.
Because a lot of the test data is inherently sensitive, coming from large Apple Notes backups that contain PII, the tests have been structured to [accept symlinks](spec/data/README.md) and skip tests that require data which is not shareable. 
While this means that not everyone can benefit from the full test suite, I felt it better to have some data available for tests for PRs rather than keep all of them private. 
To the extent that data can be extracted and committed into the repo, outside of full backups, that is the preference. 

By default, running `rake test` will skip any tests that are fairly "expensive", primarily in terms of disk IO. 
If you want to run just the expensive tests, use `rake test_expensive`.
If you want to run everything, use `rake test_all`. 

## FAQ

#### Where can I find (pick file X) to edit this?

See [this Markdown file](FolderStructure.md) for the overall folder structure of this program.

#### Why do I get a "No such column" error?

Example: `/var/lib/gems/2.3.0/gems/sqlite3-1.4.1/lib/sqlite3/database.rb:147:in 'initialize': no such column: ZICCLOUDSYNCINGOBJECT.ZSERVERRECORDDATA (SQLite3::SQLException)`

Apple changed the format of its Notes database in different versions of iOS. While the supported versions *should* be supported, interesting cases may come up. Please open an issue and include the stack trace and the following information:
* iOS version (including any versions it may have upgraded from)
* The results of `SELECT name,sql FROM sqlite_master WHERE type="table"` when the database is open in sqlitebrowser (or your editor of choice). This can be in any columned format (Excel, CSV, SQL, etc)
* If possible, the database file directly (I can receive it through other means if it needs to stay confidential). If this is possible, the above results are not needed.

#### Why do I get a "Zlib::DataError" error?

Example (from debug.log): `AppleNote: Note 123 somehow tried to decompress something that was GZIP but had to rescue error: Zlib::DataError`

There are instances where the NoteStore.sqlite database is corrupted or malformed for one reason or another. 
If the SQLite file can't open as a whole, it would be obvious, but individual records could also be individually affected, particularly fields that are compressed. 
Currently, this program will catch any errors when trying to inflate compressed data and provide a note in the `debug.log` file indicating such occurred, without crashing the entire program. 

Issue [#108](https://github.com/threeplanetssoftware/apple_cloud_notes_parser/issues/108) provides some very helpful debugging tips. 
However, it needs to be cautioned that these will actively change the database, which might not be acceptable for some use cases if file integrity must be maintained. 
To determine if there are structural issues, try this command: `sqlite3 [filename] pragma integrity_check`
To attempt to fix structural issues with the database file, try this command (this WILL change the database): `sqlite3 [filename] .recover`

#### Why Ruby instead of Python or Perl?

Programming languages are like human languages, there are many and which you choose (for those with multiple) can largely be a personal preference, assuming mutual intelligibility. I chose Ruby as the previous Perl code was a nice little script, but I wanted a bit more substance behind with with solid object oriented programming principals. For those new to Ruby, hopefully these classes will give you an idea of what Ruby has to offer and spark an interest in trying a new language.

## Known Bugs
If it is known, is it a bug, or a feature?
Kidding aside, if you believe you have found a bug, PLEASE open an issue and provide as much information as possible to help recreate the problem. 

## Acknowledgements

* MildSunrise's [protobuf-inspector](https://github.com/mildsunrise/protobuf-inspector) drove most of my analysis into the Notes protobufs.
* Previous work by [dunhamsteve](https://github.com/dunhamsteve/notesutils/blob/master/notes.md) proved invaluable to finally understanding the embedded table aspects.
