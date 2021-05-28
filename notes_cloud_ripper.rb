require 'csv'
require 'logger'
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
target_directory = nil
backup_type = nil
password_file = nil
output_directory = Pathname.new("./output")
password_success_display = false

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

# Add in a password file for encrypted notes
option_parser.on("--show-password-successes", "Toggle the display of password success ON.") do |file|
  password_success_display = true
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

puts "\nStarting Apple Notes Parser at #{DateTime.now.strftime("%c")}"

#
# Prepare the output folder
#

# Add a DTG to the output folder
output_directory = output_directory + DateTime.now().strftime("%Y_%m_%d-%H_%M_%S")

# Create the output folder if it doesn't exist
if !output_directory.exist?
  output_directory.mkpath()
end

puts "Storing the results in #{output_directory}\n\n"

# Create the Logger
logger = Logger.new(output_directory + "debug_log.txt")

#
# Start dealing with the backup
#

# Create a new AppleBackup object, based on the appropriate type
apple_backup = nil
case backup_type
  when AppleBackup::HASHED_BACKUP_TYPE
    logger.debug("User asserted this is a HASHED_BACKUP")
    apple_backup = AppleBackupHashed.new(target_directory, output_directory)
  when AppleBackup::PHYSICAL_BACKUP_TYPE
    logger.debug("User asserted this is a PHYSICAL_BACKUP")
    apple_backup = AppleBackupPhysical.new(target_directory, output_directory)
  when AppleBackup::SINGLE_FILE_BACKUP_TYPE
    logger.debug("User asserted this is a SINGLE_FILE_BACKUP")
    apple_backup = AppleBackupFile.new(target_directory, output_directory)
  when AppleBackup::MAC_BACKUP_TYPE
    logger.debug("User asserted this is a MAC_BACKUP")
    apple_backup = AppleBackupMac.new(target_directory, output_directory)
end

# Check for a valid AppleBackup, if it is ready, rip the notes and spit out CSVs
if apple_backup and apple_backup.valid? and apple_backup.note_stores.first.valid_notes?

  logger.debug("Backup is valid, ripping notes")

  # Add the password file
  apple_backup.decrypter.add_passwords_from_file(password_file)

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
    puts "Successfully decrypted notes using passwords: #{apple_backup.decrypter.successful_passwords.sort.join(", ")}"
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

  backup_number = 1
  apple_backup.note_stores.each do |note_store|

    logger.debug("Working on output for version #{note_store.version} note store #{note_store}")

    # Write out the HTML summary
    logger.debug("Writing HTML for Note Store")
    File.open(html_directory + "all_notes_#{backup_number}.html", "wb") do |file|
      file.write(note_store.generate_html)
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
