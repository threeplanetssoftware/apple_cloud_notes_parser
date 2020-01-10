# By default, execute "run"
task default: %w[run]

# By default "run" is the same as the old script's default option, 
# which looks for NoteStore.sqlite in this folder and executes.
task :run do
  ruby "notes_cloud_ripper.rb --file NoteStore.sqlite"
end

# rake help will display the help message
task :help do
  ruby "notes_cloud_ripper.rb --help"
end

# "rake clean" will delete the output folder
task :clean do 
  FileUtils.rm_rf('output')
end
