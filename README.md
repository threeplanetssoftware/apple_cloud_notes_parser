# Apple Cloud Notes Parser
By: Jon Baumann, [Ciofeca Forensics](https://www.ciofecaforensics.com)

## About

This program is a parser for the current version of Apple Notes data syncable with iCloud as seen on Apple handsets in iOS 9 and later. 
This program was made as an update to the [previous Perl script](https://github.com/threeplanetssoftware/apple_cloud_notes_parser) which did not well handle the protobufs used by Apple in Apple Notes. 
That script and this program are needed because data that was stored in plaintext in the versions of Apple's Notes prior to iOS 9 in its `notes.sqlite` database is now gzipped before storage in the iCloud Notes database `NoteStore.sqlite` and the amount of embedded objects inside of Notes is far higher.
While the data is not necessarily encrypted, although some is using the password feature, it is not as searchable to the examiner, given its compressed nature. 
This program intends to make the plaintext stored in the note and its embedded attachments far more usable.

This program was implemented in Ruby. 
The classes underlying this represent all the necessary features to write other programs to interface with an Apple Notes backup, including exporting data to another format, or writing better search functions. 
In addition, this program and its classes attempts to abstract away the work needed to understand the type of backup and how it stores files. 
While examiners must understand those backups, this will provide its own internal interfaces for identifying where media files are kept. 
For example, if the backup is from iTunes, this program will use the Manifest.db to identify the hashed name of the included file, and copy out/rename the image to the appropriate name, without the examiner having to do that manually.

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

## Usage

### Base

This program is run by Ruby on a command line, using either `rake` or `ruby`. 
The easiest use is to drop your exported `NoteStore.sqlite` into the same directory as this program and then run `rake` (which is the same as running `ruby notes_cloud_ripper.rb --file NoteStore.sqlite`). 

If you are more comfortable with the command line, you can point the program anywhere you would like on your computer and specify the type of backup you are looking at, such as: `ruby notes_cloud_ripper.rb --itunes-dir ~/.iTunes/backup1/` or `ruby notes_cloud_ripper.rb --file ~/.iTunes/backup1/4f/4f98687d8ab0d6d1a371110e6b7300f6e465bef2`. 
The benefit of pointing at full backups is this program can pull files out of them as needed, such as drawings and pictures.

### Docker

Thanks to @jareware, if you have [Docker installed already](https://docs.docker.com/get-docker/) you can run this program as a docker container.
This is a great way to ensure you will not run into any dependancy issues or have to have Ruby installed. 
Shell scripts have been provided in the `docker_scripts` folder which may help if they cover your use case. 
Each of these uses the present working directory to create the output folder. 
 - `linux_run_file.sh`: This script will run the program on a NoteStore.sqlite file found in the present working directory (as if you ran `-f NoteStore.sqlite`).
 - `mac_run_file.sh`: This script will run the program on a NoteStore.sqlite file found in the present working directory (as if you ran `-f NoteStore.sqlite`).
 - `mac_run_itunes.sh`: This script will run the program on the local user's Mobile Backups(as if you used `--itunes ~/Library/Application\ Support/MobileSync/Backup/[your backup]`).
 - `mac_run_notes.sh`: This script will run the program on the local user's Apple Notes directory (as if you used `--mac ~/Library/Group\ Containers/group.com.apple.notes`).

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
  -f /data/NoteStore.sqlite --one-output-folder
```

**Important Caveats**: 
 - While Docker can make things easier in some respects, it does so at the cost of additional complexity. It is harder to troubleshoot and adds more memory overhead.  It is my hope that the Docker image helps some use this program, but the first troubleshooting step that will be recommended is to use Ruby directly to see if that fixes the issue. 
 - The [base image](https://hub.docker.com/_/ruby/) that is used for the Docker container is published by Ruby. It relies on a Debian base layer and as of today has multiple "vulnerabilities" identified on Docker (i.e. packages that are out of date). Use the Docker container at your own risk and if you are uncomfortable with it, feel free to clone this repository and use Ruby to run it, instead. 
 - [MacOS permissions](https://docs.docker.com/desktop/mac/permission-requirements/) lead to read errors trying to mount the Notes and iTunes backups from elsewhere in the user's home folder. As a result, the shell scripts create a temporary folder in the present working directory and copy the relevant files into it. This is an ugly hack which will chew up extra disk space and time to perform the copy. If you dislike this tradeoff, feel free to clone this repository and use Ruby to run it, instead. 
 - Docker is a new feature for this program, there may be issues with the rollout. 

### Options

The options that are currently supported are:

1. `-f | --file FILE`: Tells the program to look only at a specific file that is identified. 
2. `-g | --one-output-folder`: Tells the program to always overwrite the same folder `[output]/notes_rip`.
2. `-i | --itunes-dir DIRECTORY`: Tells the program to look at an iTunes backup folder.
3. `-m | --mac DIRECTORY`: Tells the program to look at a folder from a Mac.
4. `-o | --output-dir DIRECTORY`: Changes the output folder from the default `./output` to the specified one.
5. `-p | --physical DIRECTORY`: Tells the program to look at a physical backup folder.
6. `-r | --retain-display-order`: Tells the program to display the HTML output in the order Apple Notes displays it, not the database's order. 
7. `-w | --password-file FILE`: Tells the program which password list to use 
8. `--show-password-successes`: Tells the program to display to the console which passwords generated decrypts at the end.
9. `--range-start DATE`: Set the start date of the date range to extract. Must use YYYY-MM-DD format, defaults to 1970-01-01.
10. `--range-end DATE`: Set the end date of the date range to extract. Must use YYYY-MM-DD format, defaults to [tomorrow].
11. `--individual-files`: Output individual HTML files for each note, organized in folders mirroring the Notes folder structure.
12. `--uuid`: Use UUIDs in HTML output rather than local database IDs.
13. `-h | --help`: Prints the usage information.

## How It Works

### iTunes backup (-i option)

For backups created with iTunes MobileSync, that include a wide range of hashed files inside of folders named after the filename, this program expects to be given the root folder of that backup. With that, it will compute the path to the NoteStore.sqlite file. If it exists, that file will be copied to the output directory and the copy, not the original, will be opened.

For example, if you had an iTunes backup located in `/home/user/phone_rips/iphone/[deviceid]/` (Which means the Manifest.db is located at `/home/whatever/phone_rips/iphone/[deviceid]/Manifest.db`) you would run: `ruby notes_cloud_ripper.rb -i /home/user/phone_rips/iphone/[deviceid]/`

### Physical backup (-p option)

For backups created with a full file system (or at least the `/private` directory) from your tool of choice. This program expects to be given the root folder of that backup. With that, it will compute the path to the NoteStore.sqlite file. If it exists, that file will be copied to the output directory and the copy, not the original, will be opened.

For example, if you had a physical backup located in `/home/user/phone_rips/iphone/physical/` (Which means the phone's `/private` directory is located at `/home/whatever/phone_rips/iphone/physical/private/`) you would run: `ruby notes_cloud_ripper.rb -p /home/user/phone_rips/iphone/physical`

### Single File (-f option)

For single file "backups", this program expects to be given the path of the NoteStore.sqlite file directly, although filename does not matter. If it exists, that file will be copied to the output directory and the copy, not the original, will be opened.

For example, if you had a NoteStore.sqlite file located in `/home/user/phone_rips/iphone/files/NoteStore.sqlite` you would run: `ruby notes_cloud_ripper.rb -f /home/user/phone_rips/iphone/files/NoteStore.sqlite`

### Mac backup (-m option)

For backups created from the Notes app as installed on a Mac. This program expects to be given the group.com.apple.notes folder of that Mac. With that, it will compute the path to the NoteStore.sqlite file. If it exists, that file will be copied to the output directory and the copy, not the original, will be opened.

For example, if you were running this on data from a Mac used by 'Logitech' and had the full file system available, you would run: `ruby notes_cloud_ripper.rb -m /Users/Logitech/Library/Group Containers/group.com.apple.notes/`

### Password (-w | --password-file FILE option)

For backups that may have encrypted notes within them, this option tells the program where to find its password list. This list should have one password per row and any passwords that correctly decrypt an encrypted note will be tried before the rest for future encrypted notes. 

For example, if you were running this on data from a Mac used by 'Logitech,' had the full file system available, and wanted to use a file called "passwords.txt" you would run: `ruby notes_cloud_ripper.rb -m /Users/Logitech/Library/Group Containers/group.com.apple.notes/` -w passwords.txt

Note: As of March 2021, all logging of passwords to the local debug_log.txt file and HTML output has been removed. If you need to see which passwords generated decrypted notes, use the `--show-password-successes` switch and read the console output after the run.

Note: As of iOS 16, users can use their device passcode instead of a spearate password within Notes. This program does not yet handle that case, it will simply fail to decrypt.

### Date Range Extraction

**Note: This feature is not intended to be robust. It does not smartly handle differences in timezones, nor convert to UTC. It is purely intended to help those with large Notes databases to better whittle down how much is processed.**

The `--range-start` and `--range-end` switches allow the user to specify starting and ending dates for which notes to extract. 
By default, these will cover "all time" (i.e. 1970 through to tomorrow) so all notes should match, assuming system time hasn't been messed with. 
Officially these switches request the date format in "YYYY-MM-DD" format, but technically as long as [Time.parse()](https://ruby-doc.org/stdlib-2.4.1/libdoc/time/rdoc/Time.html#method-c-parse) can understand the format, it should work.

These selections are made on the `ZICCLOUDSYNCINGOBJECT.ZMODIFIEDDATE1` field, which will capture any notes that have a modified date in that range. For example, if you wanted all notes modified after December 1, 2022, you could run: `ruby notes_cloud_ripper.rb -f NoteStore.sqlite --range-start "2022-12-01"`. As another example, if you wanted to look at just the notes that were modified in June of 2022, you could run: `ruby notes_cloud_ripper.rb -f NoteStore.sqlite --range-start "2022-06-01" --range-end "2022-07-01"`

If you ever need to know what dates were used for a given backup, you can check the `debug_log.txt` file by looking for the line that has "Rip Notes" in it. 
For example: `grep "Rip Notes" output/notes_rip/debug_log.txt`

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

Because Apple devices often have more than one version of Notes, it is important to note (pun intended) that all of the output is suffixed by a number, starting at 1, to identify which of the backups it corresponds to. 
In all cases where more than one is found, care is taken to produce output that assigns the suffix of 1 for the modern version, and the suffix of 2 for the legacy version. 

#### JSON Format

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

## Requirements


### Ruby Version

This program requires Ruby version 3.0 or later.

### Gems

This program requires the following Ruby gems which can be installed by running `bundle install` or `gem install [gemname]`:
1. fileutils
2. google-protobuf
3. sqlite3
4. zlib
5. openssl
6. aes_key_wrap
7. keyed_archive
8. nokogiri
9. cgi (0.3.3 or newer)

## Installation

Below are instructions, generally preferring the command line, for each of Linux, Mac, and Windows. The user can choose to use Git if they want to be able to keep up with changes, or just download the tool once, you do not need to do both. On each OS, you will want to:

1. Install Ruby (at least version 3.0), its development headers, and bundler if not already installed.
2. Install development headers for SQLite3 if not already installed.
3. Get this code
   1. Clone this repository with Git or
   2. Download the Zip file and unzip it
4. Enter the repository's directory.
5. Use bundler to install the required gems.
6. Run the program (see Usage section)!

### Debian-based Linux (Debian, Ubuntu, Mint, etc)

#### With Git (If you want to stay up to date)

```bash
sudo apt-get install build-essential libsqlite3-dev zlib1g-dev git ruby-full ruby-bundler
git clone https://github.com/threeplanetssoftware/apple_cloud_notes_parser.git
cd apple_cloud_notes_parser
bundle install
```

#### Without Git (If you want to download it every now and then)

```bash
sudo apt-get install build-essential libsqlite3-dev zlib1g-dev git ruby-full ruby-bundler
curl https://codeload.github.com/threeplanetssoftware/apple_cloud_notes_parser/zip/master -o apple_cloud_notes_parser.zip
unzip apple_cloud_notes_parser.zip
cd apple_cloud_notes_parser-master
bundle install
```
### Red Hat-based Linux (Red Hat, CentOS, etc)

#### With Git (If you want to stay up to date)

```bash
sudo yum groupinstall "Development Tools" 
sudo yum install sqlite sqlite-devel zlib zlib-devel openssl openssl-devel ruby ruby-devel rubygem-bundler
git clone https://github.com/threeplanetssoftware/apple_cloud_notes_parser.git
cd apple_cloud_notes_parser
bundle install
sudo gem pristine sqlite3 zlib openssl aes_key_wrap keyed_archive
```

#### Without Git (If you want to download it every now and then)

```bash
sudo yum groupinstall "Development Tools" 
sudo yum install sqlite sqlite-devel zlib zlib-devel openssl openssl-devel ruby ruby-devel rubygem-bundler
curl https://codeload.github.com/threeplanetssoftware/apple_cloud_notes_parser/zip/master -o apple_cloud_notes_parser.zip
unzip apple_cloud_notes_parser.zip
cd apple_cloud_notes_parser-master
bundle install
sudo gem pristine sqlite3 zlib openssl aes_key_wrap keyed_archive
```

### macOS 

#### With Git (If you want to stay up to date)

```bash
git clone https://github.com/threeplanetssoftware/apple_cloud_notes_parser.git
cd apple_cloud_notes_parser
bundle install
```

#### Without Git (If you want to download it every now and then)

```bash
curl https://codeload.github.com/threeplanetssoftware/apple_cloud_notes_parser/zip/master -o apple_cloud_notes_parser.zip
unzip apple_cloud_notes_parser.zip
cd apple_cloud_notes_parser-master
bundle install
```

### Windows

1. Download the 2.7.2 64-bit [RubyInstaller with DevKit](https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-2.7.2-1/rubyinstaller-2.7.2-1-x64.exe)
2. Run RubyInstaller using default settings.
3. Download the latest [SQLite amalgamation souce code](https://sqlite.org/2021/sqlite-amalgamation-3350200.zip) and [64-bit SQLite Precompiled DLL](https://sqlite.org/2021/sqlite-dll-win64-x64-3350200.zip)
4. Install SQLite
   1. Create a folder C:\sqlite
   2. Unzip the source code into C:\sqlite (you should now have C:\sqlite\sqlite3.c and C:\sqlite\sqlite.h, among others)
   3. Unzip the DLL into C:\sqlite (you should now have C:\sqlite\sqlite3.dll, among others)
5. Download [this Apple Cloud Notes Parser as a zip archive](https://github.com/threeplanetssoftware/apple_cloud_notes_parser/archive/master.zip)
6. Unzip the Zip archive
7. Launch a command prompt window with "Start a command prompt wqith ruby" from the Start menu and navigate to where you unzipped the archive
9. Execute the following commands (these set the PATH so SQLite files can be found install SQLite's Gem specifically pointing to them, and then installs the rest of the gems):

```powershell
powershell
$env:Path += ";C:\sqlite"
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\sqlite", "User")
gem install sqlite3 --platform=ruby -- --with-sqlite-3-dir=C:/sqlite --with-sqlite-3-include=C:/sqlite
bundle install
```

## Folder Structure

For reference, the structure of this program is as follows:

```
apple_cloud_notes_parser
  |
  |-docker_scripts
  |  |
  |  |-linux_run_file.sh: Execute the docker version on NoteStore.sqlite in the present working directory
  |  |-mac_run_file.sh: Execute the docker version on NoteStore.sqlite in the present working directory
  |  |-mac_run_itunes.sh: Execute the docker version on each of the local Mac user's mobile backups
  |  |-mac_run_notes.sh: Execute the docker version on the local Mac user's Notes folder
  |  
  |-lib
  |  |
  |  |-notestore_pb.rb: Protobuf representation generated with protoc
  |  |-Apple\*.rb: Ruby classes dealing with various aspects of Notes
  |
  |-output (created after run)
  |  |
  |  |-[folders for each date/time run]
  |     |
  |     |-csv: This folder holds the CSV output
  |     |-debug_log.txt: A more verbose log to assist with debugging
  |     |-files: This folder holds files copied out of the backup, such as pictures
  |     |-html: This folder holds the generated HTML copy of the Notestore
  |     |-json: This folder holds the generated JSON summary of the Notestore
  |     |-Manifest.db: If run on an iTunes backup, this is a copy of the Manifest.db
  |     |-NoteStore.sqlite: If run on a modern version, this copy of the target file will include plaintext versions of the Notes
  |     |-notes.sqlite: If run on a legacy version, this copy is just a copy for ease of use
  |
  |-.gitignore
  |-.travis.yml
  |-Dockerfile
  |-Gemfile
  |-LICENSE
  |-README.md
  |-Rakefile
  |-notes_cloud_ripper.rb: The main program itself
```

## FAQ

#### Why do I get a "No such column" error?

Example: `/var/lib/gems/2.3.0/gems/sqlite3-1.4.1/lib/sqlite3/database.rb:147:in 'initialize': no such column: ZICCLOUDSYNCINGOBJECT.ZSERVERRECORDDATA (SQLite3::SQLException)`

Apple changed the format of its Notes database in different versions of iOS. While the supported versions *should* be supported, interesting cases may come up. Please open an issue and include the stack trace and the following information:
* iOS version (including any versions it may have upgraded from)
* The results of `SELECT name,sql FROM sqlite_master WHERE type="table"` when the database is open in sqlitebrowser (or your editor of choice). This can be in any columned format (Excel, CSV, SQL, etc)
* If possible, the database file directly (I can receive it through other means if it needs to stay confidential). If this is possible, the above results are not needed.

#### Why Ruby instead of Python or Perl?

Programming languages are like human languages, there are many and which you choose (for those with multiple) can largely be a personal preference, assuming mutual intelligibility. I chose Ruby as the previous Perl code was a nice little script, but I wanted a bit more substance behind with with solid object oriented programming principals. For those new to Ruby, hopefully these classes will give you an idea of what Ruby has to offer and spark an interest in trying a new language.

## Known Bugs


## Acknowledgements

* MildSunrise's [protobuf-inspector](https://github.com/mildsunrise/protobuf-inspector) drove most of my analysis into the Notes protobufs.
* Previous work by [dunhamsteve](https://github.com/dunhamsteve/notesutils/blob/master/notes.md) proved invaluable to finally understanding the embedded table aspects.
