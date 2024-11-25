require_relative '../lib/AppleNoteStore.rb'
require_relative '../lib/AppleNoteStoreVersion.rb'

# Edit RSpec configurations
RSpec.configure do |config|

  # Bounce out any AppleBackup* tests that have missing data so others can run the test suite
  config.filter_run_excluding :missing_data => true
end

# Create pathnames for various base locations
TEST_OUTPUT_DIR = Pathname.new("spec") + "tmp_output"
TEST_DATA_DIR = Pathname.new("spec") + "data"
TEST_BLOB_DATA_DIR = TEST_DATA_DIR + "exported_blobs"

# Remember where specific versions are kept so we can test for their existence and skip
# if they aren't around.
TEST_MAC_DIR = TEST_DATA_DIR + "mac_backup"
TEST_MAC_DIR_EXIST = TEST_MAC_DIR.exist?
TEST_MAC_NO_ACCOUNT_DIR = TEST_DATA_DIR + "mac_backup_no_account"
TEST_MAC_NO_ACCOUNT_DIR_EXIST = TEST_MAC_DIR.exist?
TEST_ITUNES_DIR = TEST_DATA_DIR + "itunes_backup"
TEST_ITUNES_DIR_EXIST = TEST_ITUNES_DIR.exist?
TEST_ITUNES_NO_ACCOUNT_DIR = TEST_DATA_DIR + "itunes_backup_no_account"
TEST_ITUNES_NO_ACCOUNT_DIR_EXIST = TEST_ITUNES_NO_ACCOUNT_DIR.exist?
TEST_PHYSICAL_DIR = TEST_DATA_DIR + "physical_backup"
TEST_PHYSICAL_DIR_EXIST = TEST_PHYSICAL_DIR.exist?
TEST_PHYSICAL_NO_ACCOUNT_DIR = TEST_DATA_DIR + "physical_backup_no_account"
TEST_PHYSICAL_NO_ACCOUNT_DIR_EXIST = TEST_PHYSICAL_NO_ACCOUNT_DIR.exist?

TEST_FORMATTING_FILE = TEST_DATA_DIR + "NoteStore-tests.sqlite"
TEST_FORMATTING_FILE_EXIST = TEST_FORMATTING_FILE.exist?

TEST_FALSE_SQLITE_FILE = TEST_DATA_DIR + "notta-NoteStore.sqlite"
TEST_FALSE_SQLITE_FILE_EXIST = TEST_FALSE_SQLITE_FILE.exist?

TEST_README_FILE = TEST_DATA_DIR + "README.md"
TEST_README_FILE_EXIST = TEST_README_FILE.exist?

# The latest version
TEST_CURRENT_VERSION = 18

# Build an array of all valid NoteStore.sqlite versions for testing
TEST_FILE_VERSIONS = Hash.new
versions_to_test = (12..TEST_CURRENT_VERSION).to_a
versions_to_test.each do |version|
  version_file = TEST_DATA_DIR + "NoteStore.#{version}.sqlite"
  TEST_FILE_VERSIONS[version] = version_file if version_file.exist?
end

TEST_FILE_VERSIONS_CURRENT_FILE = TEST_FILE_VERSIONS[TEST_CURRENT_VERSION]
TEST_FILE_VERSIONS_CURRENT_FILE_EXIST = (TEST_FILE_VERSIONS_CURRENT_FILE != nil)

legacy_version_file = TEST_DATA_DIR + "NoteStore.legacy.sqlite" 
TEST_FILE_VERSIONS[AppleNoteStoreVersion::IOS_LEGACY_VERSION] = legacy_version_file if legacy_version_file.exist?

# Used to indicate the various ways we can call generate_html
TEST_HTML_GENERATION_OPTIONS = [[false, false], [true, false], [false, true], [true, true]]

# Require this later so that it can use the globals we set above
require_relative 'backup/backup.rb'
require_relative 'base_classes/base_classes.rb'
require_relative 'embedded_objects/embedded_objects.rb'
require_relative 'integration/integration.rb'
require_relative 'utilities/utilities.rb'
