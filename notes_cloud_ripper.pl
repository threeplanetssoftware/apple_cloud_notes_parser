use DBI;
use File::Copy;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);

# Rudimentary check to make sure we have a file to parse
if($ARGV != 1) {
  die print_usage();
}

# Make sure we don't mess up our original
my $original_file = @ARGV[0];
my $output_db_file = $original_file;
$output_db_file =~ s/.sqlite/.decompressed.sqlite/;
copy($original_file, $output_db_file);
print "Copying original file to preserve it, working from $output_db_file\n";

# Set up database connection
my $dsn = "DBI:SQLite:dbname=$output_db_file";
my $dbh = DBI->connect($dsn) or die "Cannot open $output_db_file\n";

# Define query to pull the note identifier and the note data from ZICNOTEDATA
my $query = "SELECT Z_PK, ZDATA FROM ZICNOTEDATA;";
my $query_handler = $dbh->prepare($query);
my $return_value = $query_handler->execute();

print "Extracting original notes\n";

# Iterate over results
while(my @row = $query_handler->fetchrow_array()) {
  # Get results
  my $z_pk = $row[0];
  my $binary = $row[1];

  # Create filename
  my $output_file = "note_".$z_pk.".blob.gz";
  print "\tSaving note $z_pk\n";

  # Save results off to show our work
  open(OUTPUT, ">$output_file");
  binmode(OUTPUT);
  print OUTPUT $binary;
  close(OUTPUT);
}

# Gunzip all saved blobs
print "Extracting gzipped notes\n";
gunzip '<./note_*.blob.gz>' => '<./note_#1.blob>' or die "Error gunzipping: $GunzipError\n";

# Create decompressed data column
print "Modifying table to hold our content\n";
my $decompressed_text_column = "ZDECOMPRESSEDTEXT";
my $column_addition_query = "ALTER TABLE ZICNOTEDATA ADD COLUMN $decompressed_text_column TEXT";
my $column_addition_handler = $dbh->prepare($column_addition_query);
$column_addition_handler->execute();
print "\tAdded column $decompressed_text_column to store extracted text\n";

print "Parsing and updating Notes\n";

# Work through all the decompressed blob to update the database and do Anything Else
for $file (glob "note_*.blob") {
  # Open the file
  open(NOTE_INPUT, "<$file");
  binmode(NOTE_INPUT);

  # Get our number
  my $note_number = $1 if $file =~ /note_(\d+).blob/;
  print "\tWorking on note $note_number\n";

  # Make sure we snag the entire fil in one go
  local $/;

  # Read in the binary and close the file
  my $binary = <NOTE_INPUT>;
  close(NOTE_INPUT);

  # Valid notes appear to start with 08 00 12
  if(is_valid_note($binary)) {
    # print "$file appears to be a valid note: $binary_header\n";

    # Parse out any plaintext at the start
    my $decompressed_text;
    $decompressed_text = get_plaintext($binary);

    # Create update query
    my $update_query = "UPDATE ZICNOTEDATA SET ZDATA=?,$decompressed_text_column=? WHERE Z_PK=?";
    my $query_handler = $dbh->prepare($update_query);
    $query_handler->execute($binary, $decompressed_text, $note_number);
    print "\t\tUpdated $note_number with decompressed data\n";
  } else {
    print "\t\tSkipping note $note_number as it appears to be encrypted or otherwise not parsed correctly\n";
  }
}

# Close database handle
$dbh->disconnect();

sub get_plaintext {
  my $input_string = @_[0];
  my $plain_text;

  # Find the apparent magic string 08 00 10 00 1a
  $pointer = index($input_string, "\x08\x00\x10\x00\x1a");

  # Find the next byte after 0x12
  $pointer = index($input_string, "\x12", $pointer + 1) + 1;

  # Read the next byte as the length of plain text
  $string_length = ord substr($input_string, $pointer, 1);

  # Fetch the plain text
  $plain_text = substr($input_string, $pointer + 1, $string_length);
  return $plain_text;
}

# Function to check the first three bytes of decompressed data to see if it is a real note
sub is_valid_note {
  my $input_string = @_[0];
  if(substr($input_string, 0, 3) eq "\x08\x00\x12") {
    return 1;
  } else {
    return 0;
  }
}

# Function to print the usage
sub print_usage {
  print "\nUsage: perl notes_cloud_ripper.pl <path to NoteStore.sqlite>\n";
  print "Example: perl notes_cloud_ripper.pl ../NoteStore.sqlite\n\n";
}
