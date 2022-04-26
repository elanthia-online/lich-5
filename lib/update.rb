## Let's have fun updating Lich5!

module Lich
  module Util
    module Update
      require 'json'
      require 'open-uri'

      @current = LICH_VERSION
      @snapshot_core_script = ["alias.lic", "autostart.lic", "go2.lic", "infomon.lic",
                               "jinx.lic", "lnet.lic", "log.lic", "repository.lic",
                               "vars.lic", "version.lic", "xnarost.lic"]

      def self.request(type = '--announce')
        case type
        when /--announce|-a/
          self.announce
        when /--help|-h/
          self.help # Ok, that's just wrong.
        when /--update|-u/
          self.download_update
        when /--refresh/
          _respond; _respond "This command has been removed."
        when /--revert|-r/
          self.revert
        when /--(?:(script|library|data))=(.*)/
          self.update_file($1.dup, $2.dup)
        when /--snapshot|-s/ # this one needs to be after --script
          self.snapshot
        else
          _respond; _respond "Command '#{type}' unknown, illegitimate and ignored.  Exiting . . ."; _respond
        end
      end

      def self.announce
        self.prep_update
        if "#{LICH_VERSION}".chr == '5'
          if Gem::Version.new(@current) < Gem::Version.new(@update_to)
            if !@new_features.empty?
              _respond ''; _respond monsterbold_start() + "*** NEW VERSION AVAILABLE ***" + monsterbold_end()
              _respond ''; _respond ''
              _respond ''; _respond @new_features
              _respond ''
              _respond ''; _respond "If you are interested in updating, run ';lich5-update --update' now."
              _respond ''
            end
          else
            _respond ''; _respond "Lich version #{LICH_VERSION} is good.  Enjoy!"; _respond ''
          end
        else
          # lich version 4 - just say 'no'
          _respond "This script does not support Lich #{LICH_VERSION}."
        end
      end

      def self.help
        _respond "
    --help                   Display this message
    --announce               Get summary of changes for next version
    --update                 Update all changes for next version
    --snapshot               Grab current snapshot of Lich5 ecosystem and put in backup
    --revert                 Roll the Lich5 ecosystem back to the most recent snapshot

  Example usage:

  [One time suggestions]
    ;autostart add --global lich5-update --announce    Check for new version at login
    ;autostart add --global lich5-update --update      To auto accept all updates at login

  [On demand suggestions]
    ;lich5-update --announce                  Check to see if a new version is available
    ;lich5-update --update                    Update the Lich5 ecosystem to the current release
    ;lich5-update --revert                    Roll the Lich5 ecosystem back to latest snapshot
    ;lich5-update --script=<NAME>             Update an individual script file found in Lich-5
    ;lich5-update --library=<NAME>            Update an individual library file found in Lich-5
    ;lich5-update --data=<NAME>               Update an individual data file found in Lich-5

    *NOTE* If you use '--snapshot' in ';autostart' you will create a new
                snapshot folder every time you log a character in.  NOT recommended.
    "
      end

      def self.snapshot
        _respond; _respond 'Creating a snapshot of current Lich core files ONLY.'
        _respond; _respond 'You may also wish to copy your entire Lich5 folder to'
        _respond 'another location for additional safety, after any'
        _respond 'additional requested updates are completed.'
        snapshot_subdir = File.join(BACKUP_DIR, "L5-snapshot-#{Time.now.strftime("%Y-%m-%d-%H-%M-%S")}")
        unless File.exists?(snapshot_subdir)
          Dir.mkdir(snapshot_subdir)
        end
        filename = File.join(LICH_DIR, File.basename($PROGRAM_NAME))
        copyfilename = File.join(snapshot_subdir, File.basename($PROGRAM_NAME))
        File.open(filename, 'rb') { |r| File.open(copyfilename, 'wb') { |w| w.write(r.read) } }

        snapshot_lib_subdir = File.join(snapshot_subdir, "lib")
        unless File.exists?(snapshot_lib_subdir)
          Dir.mkdir(snapshot_lib_subdir)
        end
        ## let's just get the directory contents and back it up

        snapshot_lib_files = Dir.children(LIB_DIR)
        snapshot_lib_files.each { |file|
          File.open(File.join(LICH_DIR, "lib", file), 'rb') { |r|
            File.open(File.join(snapshot_lib_subdir, file), 'wb') { |w| w.write(r.read) }
          }
        }

        snapshot_script_subdir = File.join(snapshot_subdir, "scripts")
        unless File.exists?(snapshot_script_subdir)
          Dir.mkdir(snapshot_script_subdir)
        end
        ## here we should maintain a discrete array of script files (450K versus 10M plus)
        ## we need to find a better way without hving to maintain this list

        @snapshot_core_script.each { |file|
          if File.exist?(File.join(LICH_DIR, "scripts", file))
            File.open(File.join(LICH_DIR, "scripts", file), 'rb') { |r|
              File.open(File.join(snapshot_script_subdir, file), 'wb') { |w| w.write(r.read) }
            }
          else
            next
          end
        }

        _respond; _respond 'Current Lich ecosystem files (only) backed up to:'
        _respond "    #{snapshot_subdir}"
      end

      def self.prep_update
        installed = Gem::Version.new(@current)
        filename = "https://api.github.com/repos/elanthia-online/lich-5/releases/latest"
        update_info = open(filename).read

        JSON::parse(update_info).each { |entry|
          if entry.include? 'tag_name'
            @update_to = entry[1].sub('v', '')
          elsif entry.include? 'zipball_url'
            @zipfile = entry[1]
          elsif entry.include? 'body'
            @new_features = entry[1].gsub!(/\#\# What's Changed.+$/m, '')
          end
        }
      end

      def self.download_update
        ## This is the workhorse routine that does the file moves from an update

        _respond; _respond 'Getting reaady to update.  First we will create a'
        _respond 'snapshot in case there are problems with the update.'

        self.snapshot

        self.prep_update if @update_to.nil? or @update_to.empty?
        if Gem::Version.new("#{@update_to}") <= Gem::Version.new("#{@current}")
          _respond ''; _respond "Lich version #{LICH_VERSION} is good.  Enjoy!"; _respond ''
        else
          _respond; _respond "Downloading Lich5 version #{@update_to}"; _respond
          filename = "lich5-#{@update_to}"
          File.open(File.join(TEMP_DIR, "#{filename}.zip"), "wb") do |file|
            file.write open("#{@zipfile}").read
          end

          if defined?(Win32)
            Dir.chdir(TEMP_DIR)
            system("tar -xf #{File.join(TEMP_DIR, filename)}.zip")
            sleep 2
            system("move elanthia-online-lich* #{filename}")
            sleep 2
          else
            finish = spawn "unzip #{File.join(TEMP_DIR, filename)}.zip -d #{File.join(TEMP_DIR, filename)}"
          end
          unless defined?(Win32)
            50.times { break unless (Process.waitpid(finish, Process::WNOHANG)).nil?; sleep 0.1 }

            new_target = Dir.children(File.join(TEMP_DIR, filename))
            FileUtils.cp_r(File.join(TEMP_DIR, filename, new_target[0]), TEMP_DIR)
            FileUtils.remove_dir(File.join(TEMP_DIR, filename))
            FileUtils.mv(File.join(TEMP_DIR, new_target[0]), File.join(TEMP_DIR, filename))
          end
          ## These five lines may be deleted after zipfiles are created with .gitattributes
          cleanup_dir = Dir.children(File.join(TEMP_DIR, filename))
          FileUtils.remove_dir(File.join(TEMP_DIR, filename, "lich")) if cleanup_dir.include?("lich")
          FileUtils.rm(File.join(TEMP_DIR, filename, "netlify.toml")) if cleanup_dir.include?("netlify.toml")
          FileUtils.rm(File.join(TEMP_DIR, filename, "README.adoc")) if cleanup_dir.include?("README.adoc")
          FileUtils.rm(File.join(TEMP_DIR, filename, "data", "update-lich5.json")) if Dir.children(File.join(TEMP_DIR, filename, "data")).include?("update-lich5.json")

          _respond; _respond 'Copying updated lich files to their locations.'

          ## We do not care about local edits from players in the Lich5 / lib location

          lib_update = Dir.children("#{TEMP_DIR}/#{filename}/lib")
          lib_update.each { |file|
            File.delete("#{LIB_DIR}/#{file}") if File.exist?("#{LIB_DIR}/#{file}")
            File.open("#{TEMP_DIR}/#{filename}/lib/#{file}", 'rb') { |r|
              File.open("#{LIB_DIR}/#{file}", 'wb') { |w| w.write(r.read) }
            }
            _respond "lib #{file} has been updated."
          }

          ## We do not care about local edits from players to the Lich5 / script location
          ## for CORE scripts (those required to run Lich5 properly)

          core_update = Dir.children(File.join(TEMP_DIR, filename, "scripts"))
          core_update.each { |file|
            File.delete(File.join(SCRIPT_DIR, file)) if File.exist?(File.join(SCRIPT_DIR, file))
            File.open(File.join(TEMP_DIR, filename, "scripts", file), 'rb') { |r|
              File.open(File.join(SCRIPT_DIR, file), 'wb') { |w| w.write(r.read) }
            }
            _respond "script #{file} has been updated."
          }

          ## We DO care about local edits from players to the Lich5 / data files
          ## specifically gameobj-data.xml and spell-list.xml.
          ## Let's be a little more purposeful and gentle with these two files.

          data_update = Dir.children(File.join(TEMP_DIR, filename, "data"))
          data_update.each { |file|
            transition_filename = "#{file}".sub(".xml", '')
            newfilename = File.join(DATA_DIR, "#{transition_filename}-#{Time.now.to_i}.xml")
            File.open(File.join(DATA_DIR, file), 'rb') { |r| File.open(newfilename, 'wb') { |w| w.write(r.read) } }
            File.delete(File.join(DATA_DIR, file)) if File.exist?(File.join(DATA_DIR, file))
            File.open(File.join(TEMP_DIR, filename, "data", file), 'rb') { |r|
              File.open(File.join(DATA_DIR, file), 'wb') { |w| w.write(r.read) }
            }
            _respond "data #{file} has been updated. The prior version was renamed to #{newfilename}."
          }

          ## Finally we move the lich.rbw file into place to complete the update.  We do
          ## not need to save a copy of this in the TEMP_DIR as previously done, since we
          ## took the snapshot at the beginning.

          lich_to_update = File.join(LICH_DIR, File.basename($PROGRAM_NAME))
          update_to_lich = File.join(TEMP_DIR, filename, "lich.rbw")
          File.open(update_to_lich, 'rb') { |r| File.open(lich_to_update, 'wb') { |w| w.write(r.read) } }

          ## And we clen up after ourselves

          FileUtils.remove_dir(File.join(TEMP_DIR, filename))   # we know these exist because
          FileUtils.rm(File.join(TEMP_DIR, "#{filename}.zip"))       # we just processed them

          _respond; _respond "Lich5 has been updated to Lich5 version #{@update_to}"
          _respond "You should exit the game, then log back in.  This will start the game"
          _respond "with your updated Lich.  Enjoy!"
        end
      end

      def self.revert
        ## Since the request is to roll-back, we will do so destructively
        ## without another snapshot and without worrying about saving files
        ## that can be reinstalled with the lich5-update --update command

        _respond; _respond 'Reverting Lich5 to previously installed version.'
        revert_array = Dir.glob(File.join(BACKUP_DIR, "*")).sort.reverse
        restore_snapshot = revert_array[0]
        if restore_snapshot.empty? or /L5-snapshot/ !~ restore_snapshot
          _respond "No prior Lich5 version found. Seek assistance."
        else
          # delete all lib files
          FileUtils.rm_f(Dir.glob(File.join(LIB_DIR, "*")))
          # copy all backed up lib files
          FileUtils.cp_r(File.join(restore_snapshot, "lib", "."), LIB_DIR)
          # delete array of core scripts
          @snapshot_core_script.each { |file|
            File.delete(File.join(SCRIPT_DIR, file)) if File.exist?(File.join(SCRIPT_DIR, file))
          }
          # copy all backed up core scripts (array to save, only array files in backup)
          FileUtils.cp_r(File.join(restore_snapshot, "scripts", "."), SCRIPT_DIR)

          # skip gameobj-data and spell-list (non-functional logically, previous versions
          # already present and current files may contain local edits)

          # update lich.rbw in stream because it is active (we hope)
          lich_to_update = File.join(LICH_DIR, File.basename($PROGRAM_NAME))
          update_to_lich = File.join(restore_snapshot, "lich.rbw")
          File.open(update_to_lich, 'rb') { |r| File.open(lich_to_update, 'wb') { |w| w.write(r.read) } }

          # as a courtesy to the player, remind which version they were rev'd back to
          targetversion = ''
          targetfile = File.open(File.join(LIB_DIR, "version.rb")).read
          targetfile.each_line do |line|
            if line =~ /LICH_VERSION\s+?=\s+?/
              targetversion = line.sub(/LICH_VERSION\s+?=\s+?/, '').sub('"', '')
            end
          end
          _respond
          _respond "Lich5 has been reverted to Lich5 version #{targetversion}"
          _respond "You should exit the game, then log back in.  This will start the game"
          _respond "with your previous version of Lich.  Enjoy!"
        end
      end

      def self.update_file(type, rf)
        requested_file = rf
        requested_file_name = requested_file.sub(/\.(?:lic|rb|xml|ui)$/, '')
        case type
        when "script"
          location = SCRIPT_DIR
          remote_repo = "https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts"
          requested_file =~ /\.lic$/ ? requested_file_ext = ".lic" : requested_file_ext = "bad extension"
        when "library"
          location = LIB_DIR
          remote_repo = "https://raw.githubusercontent.com/elanthia-online/lich-5/master/lib"
          requested_file =~ /\.rb$/ ? requested_file_ext = ".rb" : requested_file_ext = "bad extension"
        when "data"
          location = DATA_DIR
          remote_repo = "https://raw.githubusercontent.com/elanthia-online/lich-5/master/data"
          requested_file =~ /(\.(?:xml|ui))$/ ? requested_file_ext = $1.dup : requested_file_ext = "bad extension"
        end
        unless requested_file_ext == "bad extension"
          File.delete(File.join(location, requested_file)) if File.exists?(File.join(location, requested_file))
          begin
            File.open(File.join(location, requested_file), "wb") do |file|
              file.write open(File.join(remote_repo, requested_file)).read
            end
            _respond
            _respond "#{requested_file} has been updated."
          rescue
            # we created a garbage file (zero bytes filename) so let's clean it up and inform.
            sleep 1
            File.delete(File.join(location, requested_file)) if File.exists?(File.join(location, requested_file))
            _respond; _respond "The filename #{requested_file} is not available via lich5-update."
            _respond "Check the spelling of your requested file, or use ';jinx' to"
            _respond "to download #{requested_file} from another respository."
          end
        else
          _respond
          _respond "The requested file #{requested_file} has an incorrect extension."
          _respond "Valid extensions are '.lic' for scripts, '.rb' for library files,"
          _respond "and '.xml' or '.ui' for data files. Please correct and try again."
        end
      end
      # End module definitions
    end
  end
end
