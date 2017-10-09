# Apple Cloud Notes Parser
By: Jon Baumann, Three Planets Software

## About
This script is a parser for Apple Notes data stored on the Cloud as seen on Apple handsets. It was tested with sample data pulled from an iOS 11 device with entries made via iCloud. This script was made in response to the lack of parsing of iCloud Notes in major mobile forensic tools and a misunderstanding that the data was "encrypted". Data that was stored in plaintext in Apple's Notes' database `notes.sqlite` is gzipped before storage in the iCloud Notes database `NoteStore.sqlite`. So while the data is not actually encrypted, it is not as searchable, given its compressed nature.

## How It Works
First and foremost, this script immediately makes a copy of the original database before running, "just in case." This will be the same name as the original database, but will have `.decompressed` inserted, such as `NoteStore.decompressed.sqlite`. It then pulls the gzip blobs out of the `ZICNOTEDATA` table's `ZDATA` column (the rough equivalent of the `ZCONTENT` column of the `ZNOTEBODY` table in `notes.sqlite`), gunzips each, and inserts them back into the database on top of the original gzipped data. It also looks for the plaintext portion of the note and inserts that in a new column `ZDECOMPRESSEDTEXT` right next to the original data. While not all notes have plaintext (some are pictures, tables, etc), this is a quick way to gain access and searchability to that data.

It is important to note that this script is not a final answer for parsing Apple's iCloud Notes format, merely a start to get support up to at least that which exists for regular Notes.

## Usage
### Base
This script is run by perl on a command line. The easiest use is to drop your exported `NoteStore.sqlite` into the same directory as this script and then run `perl notes_cloud_ripper.pl --file=NoteStore.sqlite`. If you are more comfortable with the command line, you can point the script anywhere you would like on your computer.

### Options
The files that are currently supported are:
1. `--file=`: This option is required and it tells the script where to find your relevant NoteStore.sqlite.
2. `--dirty`: This option tells the script to "show its work" and leave the gzipped blobs and gunzipped blobs in the script's directory for the forensics examiner to have better access to them.
3. `--help`: This option prints the usage information.

## Requirements
This script requires the following Perl packages:
1. DBI
2. FILE::Copy
3. IO::Uncompress
4. Getopt

