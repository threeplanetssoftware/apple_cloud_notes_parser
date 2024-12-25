gem 'openssl'
require 'openssl'

require_relative '../../lib/AppleBackup.rb'
require_relative '../../lib/AppleDecrypter.rb'

TEST_PASSWORD_DIR = TEST_DATA_DIR + "password_examples"
TEST_PASSWORD_FILE = TEST_PASSWORD_DIR + "multiple_passwords"

describe AppleDecrypter do

  before(:context) do
    TEST_OUTPUT_DIR.mkpath
  end
  after(:context) do 
    TEST_OUTPUT_DIR.rmtree
  end

  before(:all) do
    @backup = AppleBackup.new(Pathname.new(""), 0, TEST_OUTPUT_DIR)
    @decrypter = AppleDecrypter.new()
    @decrypter.add_passwords_from_file(TEST_PASSWORD_FILE)

    @test_password = "password"
    @test_salt = "\x11\x65\x10\x6b\x6b\x28\x8b\xda\x1e\x6e\xcb\x18\xe6\x5c\x78\x76".force_encoding("US-ASCII")
    @test_bad_salt = "\x11\x65\x10\x6b\x6b\x28\x8b\xda\x1e\x6e\xcb\x18\xe6\x5c\x78\x75".force_encoding("US-ASCII")
    @test_iterations = 20000
    @test_key_encrypting_key = "\x65\x2b\xe8\x61\x43\x34\x8a\x6e\x01\x06\x09\x58\x80\xbc\xf3\x1b".force_encoding("US-ASCII")
    @test_bad_key_encrypting_key = "\xC5\x15\xE6\x55\x61\xDD\xE6\x9D\x9E\xB9\xC3\xF8\x4A\x22\x56\xA0".force_encoding("US-ASCII")
    @test_wrapped_key = "\x98\xc0\xe5\x6b\x43\xb5\x07\xe6\x0c\x54\x65\xec\x5e\x1b\xb0\xc7\x4b\x75\x6f\x7d\x4f\x4a\x9b\xff".force_encoding("US-ASCII")
    @test_bad_wrapped_key = "\x98\xc0\xe5\x6b\x43\xb5\x07\xe6\x0c\x54\x65\xec\x5e\x1b\xb0\xc7\x4b\x75\x6f\x7d\x4f\x4a\x9c\xff".force_encoding("US-ASCII")
    @test_unwrapped_key = "\x02\x3a\xae\x7c\x45\x0a\x28\x3b\x23\xe3\xd7\xc1\x41\x6a\xd6\x44".force_encoding("US-ASCII")
    @test_iv = "\x15\x1f\x64\xde\x7b\xe3\x4d\x15\xda\xcd\xae\xa9\xb3\x34\x71\xf9".force_encoding("US-ASCII")
    @test_tag = "\x80\x6b\xf2\xbb\xd3\xbf\x83\xcf\x12\x40\xb0\x3e\x7c\x4d\x6a\xb1".force_encoding("US-ASCII")
    @test_encrypted_blob = ("\x13\x1b\x03\x57\x1f\xc9\xec\x47\xef\x58\xe5\x8e\x21\xfc\xe5\xc1" + 
                           "\x0a\xa7\x3a\x62\xb9\xe5\x8a\x74\x3b\xcd\xcc\x3a\xff\x1e\xa8\xab" + 
                           "\x99\x64\xf4\x53\x5b\x85\x97\x73\x5f\x3d\xa5\xf6\xae\x63\xb9\x37" + 
                           "\x06\x25\xa2\x0d\x63\x3e\x9c\xf2\x98\x6d\x4d\x11\x89\x89\x12\x4f" + 
                           "\x0d\xdf\xee\x95\x6e\x47\xcb\x5c\xbc\x36\x17\xc5\x20\xb0\x75\x62" + 
                           "\x0b\x37\xae\x40\x56\xf3\xa1\xaf\x83\x35\x1f\xda\x63\x4d\xfb\x44" + 
                           "\x60\x55\xc7\x5f\x71\x43\xa5\x60\x01\x49\xdb\x33\x38\x93\xc0\xec" + 
                           "\xb0\xef\x39\x44\xe2\xa6\x45\x42\xe9\xa4\x37\x5b\xf1\x52\x68\x98" + 
                           "\x58\xfe\xd8\xb2\x1a\xde\xd0\xea\xb0\xaf\xb1\x11\x90").force_encoding("US-ASCII")
    @test_decrypted_blob = ("\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x13\xe3\x60\x10\x9a" + 
                           "\xc1\xc8\xc1\x20\xc0\x20\x35\x91\x51\x48\xde\x35\x2f\xb9" + 
                           "\xa8\xb2\xa0\x24\x35\x45\xa1\x24\xb3\x24\x27\x95\x8b\x0b" + 
                           "\x21\x90\x94\x9f\x52\x29\x25\xc0\xc5\x02\x52\x0b\x54\x0d" + 
                           "\xa6\x35\x18\xc1\x22\x8c\x40\x11\x79\x29\x30\xad\xc1\x24" + 
                           "\x25\xc6\xc5\x01\x94\xfb\x0f\x04\xfc\x40\x75\x70\xb6\x92" + 
                           "\x0c\x97\x14\x97\xc0\xbb\x7f\x02\xb7\xa2\x2a\x9d\x55\x3b" + 
                           "\x76\xe5\x9e\x7a\xf4\x72\xfb\x1b\x21\x26\x0e\x79\x20\x66" + 
                           "\xd4\xe2\xe0\x10\x10\x02\x9a\x29\xc1\xa8\x05\xe2\xb1\x71" + 
                           "\xf0\x09\x31\x49\x30\x02\x00\xd1\x69\x5a\x2d\x9d\x00\x00\x00").force_encoding("US-ASCII")

    #AES 256 CBC Test Vectors
    # https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Algorithm-Validation-Program/documents/aes/AESAVS.pdf
    @aes_266_key = Array.new(40, 0x00)
    #@aes_256_iv = 
  end

  #let!(:decrypter) {AppleDecrypter.new(AppleBackup.new(Pathname.new(""), 0, TEST_OUTPUT_DIR))}

  #let(:password_file) { "password\nroot\nsuper_secret" }
  #before { allow(File).to receive(:readlines).with("passwords") { StringIO.new(password_file) }}

  context "passwords" do
    it "loads passwords from a file" do
      tmp_decrypter = AppleDecrypter.new()
      expect(tmp_decrypter.add_passwords_from_file(TEST_PASSWORD_FILE)).to be 3
    end

    it "doesn't truncate passwords" do
      expect(@decrypter.instance_variable_get(:@passwords)[0]).to eql("password")
      expect(@decrypter.instance_variable_get(:@passwords)[1]).to eql("root")
      expect(@decrypter.instance_variable_get(:@passwords)[2]).to eql("super_secret")
    end

    it "handles passwords with right to left languages well" do 
      tmp_decrypter = AppleDecrypter.new()
      expect(tmp_decrypter.add_passwords_from_file(TEST_PASSWORD_DIR + "right_to_left_password")).to be 1
      expect(tmp_decrypter.instance_variable_get(:@passwords)[0].bytes).to eql([217, 131, 217, 132, 217, 133, 216, 169, 32, 216, 167, 217, 132, 217, 133, 216, 177, 217, 136, 216, 177])
    end

    it "handles passwords with wide characters well" do 
      tmp_decrypter = AppleDecrypter.new()
      expect(tmp_decrypter.add_passwords_from_file(TEST_PASSWORD_DIR + "wide_character_password")).to be 1
      expect(tmp_decrypter.instance_variable_get(:@passwords)[0].bytes).to eql([229, 175, 134, 231, 160, 129])
    end

    # Please, please, please, do not ever use emojis in passwords. You really never know what character codes
    # your device of choice is going to use.
    it "handles passwords with emojis well" do 
      tmp_decrypter = AppleDecrypter.new()
      expect(tmp_decrypter.add_passwords_from_file(TEST_PASSWORD_DIR + "emoji_password")).to be 1
      expect(tmp_decrypter.instance_variable_get(:@passwords)[0].bytes).to eql([226, 140, 155, 239, 184, 142, 226, 157, 164, 239, 184, 142, 226, 156, 146, 239, 184, 142])
    end

    it "doesn't split password at spaces" do 
      tmp_decrypter = AppleDecrypter.new()
      expect(tmp_decrypter.add_passwords_from_file(TEST_PASSWORD_DIR + "spaces_in_password")).to be 1
      expect(tmp_decrypter.instance_variable_get(:@passwords)[0].length).to be 23
    end
  end

  context "encryption functions" do

    it "properly generates a key encrypting key" do
      expect(@decrypter.generate_key_encrypting_key(@test_password, @test_salt, @test_iterations).force_encoding("US-ASCII")).to eql(@test_key_encrypting_key)
    end

    it "properly unwraps a wrapped key" do
      expect(@decrypter.aes_key_unwrap(@test_wrapped_key, @test_key_encrypting_key).force_encoding("US-ASCII")).to eql(@test_unwrapped_key)
    end

    it "properly returns nil when unable to unwrap a key" do
      expect(@decrypter.aes_key_unwrap(@test_wrapped_key, @test_bad_key_encrypting_key)).to eql(nil)
    end

    it "properly identifies good cryptographic settings as good" do
      expect(@decrypter.check_cryptographic_settings(@test_password, @test_salt, @test_iterations, @test_wrapped_key)).to be true
    end

    it "properly identifies bad cryptographic settings (salt) as bad" do
      expect(@decrypter.check_cryptographic_settings(@test_password, @test_bad_salt, @test_iterations, @test_wrapped_key)).to be false
    end

    it "properly identifies bad cryptographic settings (iterations) as bad" do
      expect(@decrypter.check_cryptographic_settings(@test_password, @test_salt, @test_iterations - 1, @test_wrapped_key)).to be false
    end

    it "properly identifies bad cryptographic settings (key) as bad" do
      expect(@decrypter.check_cryptographic_settings(@test_password, @test_salt, @test_iterations, @test_bad_wrapped_key)).to be false
    end

    it "properly uses an unwrapped key to decrypt a blob" do
      expect(@decrypter.aes_gcm_decrypt(@test_unwrapped_key, @test_iv, @test_tag, @test_encrypted_blob).force_encoding("US-ASCII")).to eql(@test_decrypted_blob)
    end

    it "returns false if it does not decrypt" do
      expect(@decrypter.decrypt_with_password(@test_password + "fake", @test_salt, @test_iterations, @test_wrapped_key, @test_iv, @test_tag, @test_encrypted_blob)).to be false
    end

    it "returns a hash if it successfully decrypts" do
      results = @decrypter.decrypt_with_password(@test_password, @test_salt, @test_iterations, @test_wrapped_key, @test_iv, @test_tag, @test_encrypted_blob)
      expect(results).to be_a Hash
      expect(results[:plaintext].force_encoding("US-ASCII")).to eql(@test_decrypted_blob)
      expect(results[:password]).to eql(@test_password)
    end
  end
end
