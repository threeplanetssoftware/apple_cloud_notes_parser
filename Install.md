# OS-specific Installation Instructions

## Debian-based Linux (Debian, Ubuntu, Mint, etc)

### With Git (If you want to stay up to date)

```bash
sudo apt-get install build-essential libsqlite3-dev zlib1g-dev git ruby-full ruby-bundler
git clone https://github.com/threeplanetssoftware/apple_cloud_notes_parser.git
cd apple_cloud_notes_parser
bundle install
```

### Without Git (If you want to download it every now and then)

```bash
sudo apt-get install build-essential libsqlite3-dev zlib1g-dev git ruby-full ruby-bundler
curl https://codeload.github.com/threeplanetssoftware/apple_cloud_notes_parser/zip/master -o apple_cloud_notes_parser.zip
unzip apple_cloud_notes_parser.zip
cd apple_cloud_notes_parser-master
bundle install
```
## Red Hat-based Linux (Red Hat, CentOS, etc)

### With Git (If you want to stay up to date)

```bash
sudo yum groupinstall "Development Tools" 
sudo yum install sqlite sqlite-devel zlib zlib-devel openssl openssl-devel ruby ruby-devel rubygem-bundler
git clone https://github.com/threeplanetssoftware/apple_cloud_notes_parser.git
cd apple_cloud_notes_parser
bundle install
sudo gem pristine sqlite3 zlib openssl aes_key_wrap keyed_archive
```

### Without Git (If you want to download it every now and then)

```bash
sudo yum groupinstall "Development Tools" 
sudo yum install sqlite sqlite-devel zlib zlib-devel openssl openssl-devel ruby ruby-devel rubygem-bundler
curl https://codeload.github.com/threeplanetssoftware/apple_cloud_notes_parser/zip/master -o apple_cloud_notes_parser.zip
unzip apple_cloud_notes_parser.zip
cd apple_cloud_notes_parser-master
bundle install
sudo gem pristine sqlite3 zlib openssl aes_key_wrap keyed_archive
```

## MacOS 

### With Git (If you want to stay up to date)

```bash
git clone https://github.com/threeplanetssoftware/apple_cloud_notes_parser.git
cd apple_cloud_notes_parser
bundle install
```

### Without Git (If you want to download it every now and then)

```bash
curl https://codeload.github.com/threeplanetssoftware/apple_cloud_notes_parser/zip/master -o apple_cloud_notes_parser.zip
unzip apple_cloud_notes_parser.zip
cd apple_cloud_notes_parser-master
bundle install
```

## Windows

1. Download the 2.7.2 64-bit [RubyInstaller with DevKit](https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-3.2.5-1/rubyinstaller-3.2.5-1-x64.exe)
2. Run RubyInstaller using default settings.
3. Download the latest [SQLite amalgamation souce code](https://sqlite.org/2024/sqlite-amalgamation-3460000.zip) and [64-bit SQLite Precompiled DLL](https://sqlite.org/2024/sqlite-dll-win-x64-3460000.zip)
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

