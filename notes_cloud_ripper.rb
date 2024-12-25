require 'csv'
require 'json'
require 'logger'
require 'io/console'
require 'optparse'
require 'pathname'
require_relative 'lib/AppleBackup.rb'
require_relative 'lib/AppleBackupHashed.rb'
require_relative 'lib/AppleBackupPhysical.rb'
require_relative 'lib/AppleBackupMac.rb'
require_relative 'lib/AppleBackupFile.rb'
require_relative 'lib/AppleNote.rb'
require_relative 'lib/AppleNoteStore.rb'

# Set up variables for the run
options = {}
backup_type = nil
one_output_folder = false
output_directory = Pathname.new("./output")
password_file = nil
password_success_display = false
password_to_add = nil
retain_order = false
target_directory = nil
range_start = nil
range_end = nil
individual_files = false
use_uuid = false

#
# Options Parser setup
#

option_parser = OptionParser.new 

# Support iTunes sync directories
option_parser.on("-i", "--itunes-dir DIRECTORY", "Root directory of an iTunes backup folder (i.e. where Manifest.db is). These normally have hashed filenames.") do |dir|
  target_directory = Pathname.new(dir)
  backup_type = AppleBackup::HASHED_BACKUP_TYPE
end

# Support individual SQLite files
option_parser.on("-f", "--file FILE", "Single NoteStore.sqlite file.") do |file|
  target_directory = Pathname.new(file)
  backup_type = AppleBackup::SINGLE_FILE_BACKUP_TYPE
end

# Always overwrite the same folder
option_parser.on("-g", "--one-output-folder", "Always write to the same output folder.") do
  one_output_folder = true
end

# Support physical backups
option_parser.on("-p", "--physical DIRECTORY", "Root directory of a physical backup (i.e. right above /private).") do |dir|
  target_directory = Pathname.new(dir)
  backup_type = AppleBackup::PHYSICAL_BACKUP_TYPE
end

# Support ripping right from a Mac
option_parser.on("-m", "--mac DIRECTORY", "Root directory of a Mac application (i.e. /Users/{username}/Library/Group Containers/group.com.apple.notes).") do |dir|
  target_directory = Pathname.new(dir)
  backup_type = AppleBackup::MAC_BACKUP_TYPE
end

# Change the output folder from the default value
option_parser.on("-o", "--output-dir DIRECTORY", "Change the output directory from the default #{output_directory}") do |dir|
  output_directory = Pathname.new(dir)
end

# Add in a password file for encrypted notes
option_parser.on("-w", "--password-file FILE", "File with plaintext passwords, one per line.") do |file|
  password_file = Pathname.new(file)
end

# Retain Notes' folder and note displayed ordering, vice database ordering
option_parser.on("-r", "--retain-display-order", "Retain the display order for folders and notes, not the database's order.") do
  retain_order = true
end

# Display password successes on the console
option_parser.on("--show-password-successes", "Toggle the display of password success ON.") do 
  password_success_display = true
end

# Provider terminal prompt to input a password to avoid keeping it on disk
option_parser.on("--manual-password", "Input a password manually at the start of the script") do 
  password_to_add = IO::console.getpass("Please enter the password, followed by enter: ")
end

# Add in a start date to bound the notes that are extracted
option_parser.on("--range-start DATE", "Set the start date of the date range to extract. Must use YYYY-MM-DD format, defaults to 1970-01-01.") do |date|
  begin
    range_start = Time.parse(date)
    puts "Setting the range_start to be #{range_start}"
  rescue Exception
    range_start = nil
    puts "Invalid date format #{date} given for --range-start. Please us the format YYYY-MM-DD."
    exit
  end
end

# Add in an end date to bound the notes that are extracted
option_parser.on("--range-end DATE", "Set the end date of the date range to extract. Must use YYYY-MM-DD format, defaults to #{(Time.now + 86401).strftime("%Y-%m-%d")}.") do |date|
  begin
    range_end = Time.parse(date)
    puts "Setting the range_end to be #{range_end}"
  rescue Exception
    range_end = nil
    puts "Invalid date format #{date} given for --range-end. Please us the format YYYY-MM-DD."
    exit
  end
end

# Output individual HTML files for each note instead of one large file
option_parser.on("--individual-files", "Output individual HTML files for each note, organized in folders mirroring the Notes folder structure.") do
  individual_files = true
end

# Prefer UUIDs instead of local database IDs
option_parser.on("--uuid", "Use UUIDs in HTML output rather than local database IDs.") do
  use_uuid = true
end

# Help information, only displayed if we haven't hit on other options
option_parser.on("-h", "--help", "Print help information") do
  puts option_parser
  exit
end

# Check to see if we have any arguments, display help if not
if option_parser.getopts.length < 1
  options = option_parser.parse! %w[--help]
else
  options = option_parser.parse!
end

puts "\nStarting Apple Notes Parser at #{DateTime.now.strftime("%c")}\n\n"

#
# Prepare the output folder
#

if one_output_folder
  # Add "notes_rip to the folder name
  output_directory = output_directory + "notes_rip"
else
  # Add a DTG to the output folder
  output_directory = output_directory + DateTime.now().strftime("%Y_%m_%d-%H_%M_%S")
end

# Delete the old copy if we want just one output folder every time
if one_output_folder and output_directory.exist?
  output_directory.rmtree
end

# Create the output folder if it doesn't exist
if !output_directory.exist?
  output_directory.mkpath()
end

puts "Running on Ruby: #{RUBY_DESCRIPTION}\n"
puts "Storing the results in #{output_directory}\n\n"


# Create the Logger
logger = Logger.new(output_directory + "debug_log.txt")

logger.debug("Ruby version: #{RUBY_DESCRIPTION}")

#
# Start dealing with the backup
#

# Create the decrypter backups will use. 
# We do this here to ensure we have appropriate credentials upon creation of a new
# AppleBackup
decrypter = AppleDecrypter.new
decrypter.add_passwords_from_file(password_file)
decrypter.add_password(password_to_add) if password_to_add

# Create a new AppleBackup object, based on the appropriate type
apple_backup = nil
case backup_type
  when AppleBackup::HASHED_BACKUP_TYPE
    logger.debug("User asserted this is a HASHED_BACKUP")
    apple_backup = AppleBackupHashed.new(target_directory, output_directory, decrypter)
  when AppleBackup::PHYSICAL_BACKUP_TYPE
    logger.debug("User asserted this is a PHYSICAL_BACKUP")
    apple_backup = AppleBackupPhysical.new(target_directory, output_directory, decrypter)
  when AppleBackup::SINGLE_FILE_BACKUP_TYPE
    logger.debug("User asserted this is a SINGLE_FILE_BACKUP")
    apple_backup = AppleBackupFile.new(target_directory, output_directory, decrypter)
  when AppleBackup::MAC_BACKUP_TYPE
    logger.debug("User asserted this is a MAC_BACKUP")
    apple_backup = AppleBackupMac.new(target_directory, output_directory, decrypter)
end

# Check for a valid AppleBackup, if it is ready, rip the notes and spit out CSVs
if apple_backup and apple_backup.valid? and apple_backup.note_stores.first.valid_notes?

  apple_backup.set_range_start(range_start.to_i) if range_start
  apple_backup.set_range_end(range_end.to_i) if range_end

  logger.debug("Backup is valid, ripping notes")

  apple_backup.retain_order = retain_order

  # Tell the backup to rip notes
  apple_backup.rip_notes

  # Tell the AppleNoteStore to add plaintext to the database
  apple_backup.note_stores.each do |note_store|
    logger.debug("Adding plaintext to #{note_store}")
    begin
      note_store.add_plain_text_to_database
    rescue SQLite3::CorruptException
      logger.error("Error writing plaintext into the database, it seems to be corrupt, so you'll need to rely on the other output.")
      puts "------------------------------"
      puts "SQLite3::CorruptException encountered while trying to write plaintext to database, this may be a result of a Notes migration, try opening the application and saving it again."
      puts "------------------------------"
    rescue SQLite3::SQLException
      logger.error("Error adding columns to database, this likely was already done.")
    end
  end

  #
  # If appropriate, display the passwords we used
  #

  if password_success_display and apple_backup.decrypter.successful_passwords.length > 0
    puts "------------------------------"
    puts "Successfully decrypted notes using passwords: #{apple_backup.decrypter.successful_passwords.uniq.sort.join(", ")}"
    puts "These are NOT logged, note it down now if you need it."
    puts "------------------------------"
  end

  #
  # Create the output folder
  #

  # Make a separate folder to hold the CSVs for cleanliness
  csv_directory = output_directory + "csv"
  logger.debug("Creating CSV output folder: #{csv_directory}")
  csv_directory.mkpath

  # Make a separate folder to hold the HTML
  html_directory = output_directory + "html"
  logger.debug("Creating HTML output folder: #{html_directory}")
  html_directory.mkpath

  # Make a separate folder to hold the JSON file for cleanliness
  json_directory = output_directory + "json"
  logger.debug("Creating JSON output folder: #{json_directory}")
  json_directory.mkpath

  backup_number = 1
  apple_backup.note_stores.each do |note_store|

    logger.debug("Working on output for version #{note_store.version} note store #{note_store}")

    # Write out the HTML summary
    logger.debug("Writing HTML for Note Store")
    if individual_files
      note_store_subdirectory = html_directory + "note_store#{backup_number}"
      note_store_subdirectory.mkpath
      note_store.write_individual_html(note_store_subdirectory, use_uuid: use_uuid)
    else
      File.open(html_directory + "all_notes_#{backup_number}.html", "wb") do |file|
        file.write(note_store.generate_html(use_uuid: use_uuid))
      end
    end

    # Write out the JSON summary
    logger.debug("Writing JSON for Note Store")
    File.open(json_directory + "all_notes_#{backup_number}.json", "wb") do |file|
      file.write(JSON.generate(note_store.prepare_json))
    end

    # Create a CSV of the AppleNotesAccount objects
    logger.debug("Writing CSV for accounts")
    CSV.open(csv_directory + "note_store_accounts_#{backup_number}.csv", "wb", force_quotes: true) do |csv|
      note_store.get_account_csv.each do |csv_line|
        csv << csv_line
      end
    end

    # Create a CSV of the AppleNotesFolder objects
    logger.debug("Writing CSV for folders")
    CSV.open(csv_directory + "note_store_folders_#{backup_number}.csv", "wb", force_quotes: true) do |csv|
      note_store.get_folder_csv.each do |csv_line|
        csv << csv_line
      end
    end

    # Create a CSV of the AppleNote objects
    logger.debug("Writing CSV for notes")
    CSV.open(csv_directory + "note_store_notes_#{backup_number}.csv", "wb", force_quotes: true) do |csv|
      note_store.get_note_csv.each do |csv_line|
        csv << csv_line
      end
    end

    # Create a CSV of the AppleNotesEmbeddedObject objects
    logger.debug("Writing CSV for embedded objects")
    CSV.open(csv_directory + "note_store_embedded_objects_#{backup_number}.csv", "wb", force_quotes: true) do |csv|
      note_store.get_embedded_object_csv.each do |csv_line|
        csv << csv_line
      end
    end

    # Create a CSV of the AppleCloudKitShareParticipant objects
    logger.debug("Writing CSV for cloud kit participants")
    CSV.open(csv_directory + "note_store_cloudkit_participants_#{backup_number}.csv", "wb", force_quotes: true) do |csv|
      note_store.get_cloudkit_participants_csv.each do |csv_line|
        csv << csv_line
      end
    end

    # Close the note store for cleanliness  
    logger.debug("Closing version #{note_store.version} note store #{note_store}")
    note_store.close

    # Increment counter to prevent overwriting our stuff
    backup_number += 1
  end

else

  # If this backup failed to create, or is invalid, die with a good warning
  # and clean up the folder we created
  output_directory.rmtree
  puts "This is not a valid Apple Backup with Notes: #{target_directory}"
  exit
end

logger.debug("Finished")
puts "\nSuccessfully finished at #{DateTime.now.strftime("%c")}"
