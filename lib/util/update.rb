## Let's have fun updating Lich5!

module Lich
  module Util
    module Update
      require 'json'
      require 'open-uri'
      require 'rubygems/package'
      require 'zlib'

      @current = LICH_VERSION
      @back_rev = false
      @snapshot_core_script = ["alias.lic", "autostart.lic", "dependency.lic",
                               "ewaggle.lic", "foreach.lic", "go2.lic", "infomon.lic",
                               "jinx.lic", "lnet.lic", "log.lic", "logxml.lic", "map.lic", "repository.lic", "vars.lic", "version.lic"]

      INSTALL_REGEX = %r[--install(?:\s+--version=(?<tag>(?:v)?[\d\.]+(?:-[\w\d\.]+)?))?(?:\s+--(?<type>script|lib(?:rary)?|data)=(?<file>.*\.(?:lic|rb|xml|json|yaml|ui)))?]
      BETA_REGEX = %r[--(?:beta|test)(?:\s+--(?<type>script|lib(?:rary)?|data)=(?<file>.*\.(?:lic|rb|xml|json|yaml|ui)))?]
      VERSION_REGEX = %r[(?:v)?[\d\.]+(?:-[\w\d\.]+)?]

      def self.request(type = '--announce')
        case type
        when /--announce|-a/
          self.announce
        when BETA_REGEX
          unless Regexp.last_match[:type].nil?
            self.update_file(Regexp.last_match[:type], Regexp.last_match[:file], 'beta')
          else
            self.check_beta_participation
            self.prep_request('beta') if @beta_response == "accepted"
          end
        when /--help|-h/
          self.help # Ok, that's just wrong.
        when /--update|-u/
          self.prep_request('latest')
        when /--refresh/
          _respond; Lich::Messaging.mono(Lich::Messaging.monsterbold("This command has been removed.\r\n"))
        when INSTALL_REGEX
          if Gem::Version.new(LICH_VERSION) > Gem::Version.new('5.10.4')
            unless Regexp.last_match[:tag].nil?
              if Regexp.last_match[:type].nil?
                self.prep_request(Regexp.last_match[:tag])
              else
                self.update_file(Regexp.last_match[:type], Regexp.last_match[:file], Regexp.last_match[:tag])
              end
            else
              _respond; Lich::Messaging.mono(Lich::Messaging.monsterbold("This feature does not work without specifying an existing version.\r\n"))
            end
          else
            Lich::Messaging.mono(Lich::Messaging.monsterbold("This feature is only available for Lich versions 5.11 and greater.\r\n"))
          end
        when /--revert|-r/
          self.revert
        when /^--(?<type>(?:script|lib(?:rary)?|data))=(?<file>.*\.(?:lic|rb|xml|json|yaml|ui))$/
          self.update_file(Regexp.last_match[:type], Regexp.last_match[:file])
        when /--snapshot|-s/ # this one needs to be after --script
          self.snapshot
        else
          _respond; Lich::Messaging.mono(Lich::Messaging.monsterbold("Command '#{type}' unknown, illegitimate and ignored.  Exiting . . .\r\n")); _respond
        end
      end

      def self.announce
        self.prep_request('latest')
        if "#{LICH_VERSION}".chr == '5'
          if Gem::Version.new(@current) < Gem::Version.new(@update_to)
            if !@new_features.empty?
              _respond; Lich::Messaging.mono(Lich::Messaging.monsterbold("*** NEW VERSION AVAILABLE ***\r\n"))
              _respond ''; _respond ''
              _respond ''; _respond @new_features
              _respond ''
              _respond ''; _respond "If you are interested in updating, run ';lich5-update --update' now."
              _respond ''
            end
          end
        else
          # lich version 4 - just say 'no'
          _respond "This script does not support Lich #{LICH_VERSION}."
        end
      end

      def self.check_beta_participation
        Lich::Messaging.mono("You are electing to participate in the beta testing of the next Lich release. This beta test will include only Lich code, and does not include Ruby upates. While we will do everything we can to ensure you have a smooth experience, it is a test, and untoward things can result.  Please confirm your choice:\r\n")
        Lich::Messaging.mono(Lich::Messaging.monsterbold("Please confirm your participation:  ;send Y or ;send N\r\n"))
        # we are only going to get the next client-input line, and if it does not confirm, we bail
        # we are doing this to prevent hanging the client with various other inputs by the user
        sync_thread = $_CLIENT_ || $_DETACHABLE_CLIENT_
        line = sync_thread.gets until line.strip =~ /^(?:<c>)?(?:;send|;s) /i
        if line =~ /send Y|s Y/i
          @beta_response = 'accepted'
          Lich::Messaging.mono("Beta test installation accepted.  Thank you for assisting!\r\n")
        else
          @beta_response = 'rejected'
          Lich::Messaging.mono("Aborting beta test installation request.  Thank you for considering!\r\n")
        end
      end

      def self.snapshot
        _respond
        _respond 'Creating a snapshot of current Lich core files ONLY.'
        _respond
        _respond 'You may also wish to copy your entire Lich5 folder to'
        _respond 'another location for additional safety, after any'
        _respond 'additional requested updates are completed.'

        ## Let's make the snapshot folder

        snapshot_subdir = File.join(BACKUP_DIR, "L5-snapshot-#{Time.now.strftime("%Y-%m-%d-%H-%M-%S")}")
        FileUtils.mkdir_p(snapshot_subdir)

        ## lich.rbw main file backup

        FileUtils.cp(File.join(LICH_DIR, File.basename($PROGRAM_NAME)), File.join(snapshot_subdir, File.basename($PROGRAM_NAME)))

        ## LIB folder backup and it's subfolders

        FileUtils.mkdir_p(File.join(snapshot_subdir, "lib"))
        FileUtils.cp_r(LIB_DIR, snapshot_subdir)

        ## here we should maintain a discrete array of script files (450K versus 10M plus)
        ## we need to find a better way without hving to maintain this list

        FileUtils.mkdir_p(File.join(snapshot_subdir, "scripts"))
        @snapshot_core_script.each { |file|
          FileUtils.cp(File.join(SCRIPT_DIR, file), File.join(snapshot_subdir, "scripts", file)) if File.exist?(File.join(SCRIPT_DIR, file))
        }

        _respond
        _respond 'Current Lich ecosystem files (only) backed up to:'
        _respond "    #{snapshot_subdir}"
      end

      def self.prep_request(version = 'latest') # default to simple update
        case version
        when 'latest'
          filename = "https://api.github.com/repos/elanthia-online/lich-5/releases/latest"
          update_info = URI.parse(filename).open.read
          record = JSON::parse(update_info) # latest always contains one record
        when 'beta'
          filename = "https://api.github.com/repos/elanthia-online/lich-5/releases"
          update_info = URI.parse(filename).open.read
          record = JSON::parse(update_info).first # assumption: Latest beta release always first record in API
        when VERSION_REGEX
          requested_version = version.gsub(/v/, '') # if present, remove 'v' to standardize on version numbers
          if Gem::Version.new(requested_version) > Gem::Version.new('5.10.4')
            filename = "https://api.github.com/repos/elanthia-online/lich-5/releases"
            update_info = URI.parse(filename).open.read
            temp_record = JSON::parse(update_info).select { |h1| h1['tag_name'] == "v#{requested_version}" }
            unless temp_record.nil? or temp_record.empty?
              record = temp_record.first
              @back_rev = true
            else
              Lich::Messaging.mono(Lich::Messaging.monsterbold("The version you are requesting is not a valid Lich release.\r\n"))
              record = nil
            end
          else
            Lich::Messaging.mono(Lich::Messaging.monsterbold("Only requests for Lich 5.11 or greater are supported.  There is no going back from here.\r\n"))
          end
        end
        unless record.nil?
          record.each { |entry, value|
            if entry.include? 'tag_name'
              @update_to = value.sub('v', '')
            elsif entry.include? 'assets'
              @holder = value
            elsif entry.include? 'body'
              @new_features = value.gsub(/\#\# What's Changed.+$/m, '')
            end
          }
          requested_asset = @holder.find { |x| x['name'] =~ /lich-5.tar.gz/ }
          @zipfile = requested_asset.fetch('browser_download_url')
          self.download_update
        end
      end

      def self.download_update
        ## This is the workhorse routine that does the file moves from an update
        self.prep_request if @update_to.nil? or @update_to.empty?
        if Gem::Version.new("#{@update_to}") <= Gem::Version.new("#{@current}")
          unless @back_rev && (Gem::Version.new("#{update_to}") > Gem::Version.new('5.10.4'))
            _respond; Lich::Messaging.mono(Lich::Messaging.monsterbold("Lich version #{LICH_VERSION} is good.  Enjoy!\r\n"))
          end
        else
          _respond; _respond 'Getting reaady to update.  First we will create a'
          _respond 'snapshot in case there are problems with the update.'

          self.snapshot

          # download the requested update (can be prod release, or beta)
          _respond; _respond "Downloading Lich5 version #{@update_to}"; _respond
          filename = "lich5-#{@update_to}"
          File.open(File.join(TEMP_DIR, "#{filename}.tar.gz"), "wb") do |file|
            file.write URI.parse(@zipfile).open.read
          end

          # unpack and prepare to use the requested update
          FileUtils.mkdir_p(File.join(TEMP_DIR, filename))
          Gem::Package.new("").extract_tar_gz(File.open(File.join(TEMP_DIR, "#{filename}.tar.gz"), "rb"), File.join(TEMP_DIR, filename))
          new_target = Dir.children(File.join(TEMP_DIR, filename))
          FileUtils.cp_r(File.join(TEMP_DIR, filename, new_target[0]), TEMP_DIR)
          FileUtils.remove_dir(File.join(TEMP_DIR, filename))
          FileUtils.mv(File.join(TEMP_DIR, new_target[0]), File.join(TEMP_DIR, filename))

          # delete all existing lib files and directories to not leave old ones behind
          FileUtils.rm_rf(Dir.glob(File.join(LIB_DIR, "*")))

          _respond; _respond 'Copying updated lich files to their locations.'

          ## We do not care about local edits from players in the Lich5 / lib location
          FileUtils.copy_entry(File.join(TEMP_DIR, filename, "lib"), File.join(LIB_DIR))
          _respond; _respond "All Lich lib files have been updated."; _respond

          ## Use new method so can be reused to do a blanket update of core data & scripts
          self.update_core_data_and_scripts(@update_to)

          ## Finally we move the lich.rbw file into place to complete the update.  We do
          ## not need to save a copy of this in the TEMP_DIR as previously done, since we
          ## took the snapshot at the beginning.
          lich_to_update = File.join(LICH_DIR, File.basename($PROGRAM_NAME))
          update_to_lich = File.join(TEMP_DIR, filename, "lich.rbw")
          File.open(update_to_lich, 'rb') { |r| File.open(lich_to_update, 'wb') { |w| w.write(r.read) } }

          ## And we clen up after ourselves
          FileUtils.remove_dir(File.join(TEMP_DIR, filename)) # we know these exist because
          FileUtils.rm(File.join(TEMP_DIR, "#{filename}.tar.gz")) # we just processed them

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
          FileUtils.rm_rf(Dir.glob(File.join(LIB_DIR, "*")))
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

      def self.validate_url_request(url)
        response = nil
        begin
          parsed_url = URI(url)
          response = Net::HTTP.get_response(parsed_url)
          if response.code[0, 1] == "2" || response.code[0, 1] == "3"
            return true
          else
            return false
          end
        rescue OpenURI::HTTPError # => error
          # test = 'Error in URL.  Most likely a non-existant version.'
          _respond "The version or file you are requesting is not available.  Check your "
          _respond "version or file name.  If the request is for the latest beta or release "
          _respond "candidate use --beta --lib=<filename.rb>"
          _respond
        end
        # test
      end

      def self.update_file(type, rf, version = 'production')
        requested_file = rf
        case type
        when "script"
          location = SCRIPT_DIR
          if requested_file.downcase == 'dependency.lic'
            remote_repo = "https://raw.githubusercontent.com/elanthia-online/dr-scripts/main"
          else
            remote_repo = "https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts"
          end
          requested_file =~ /\.lic$/ ? requested_file_ext = ".lic" : requested_file_ext = "bad extension for script file"
        when "data"
          location = DATA_DIR
          remote_repo = "https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts"
          requested_file =~ /(\.(?:xml|json|yaml|ui))$/ ? requested_file_ext = $1.dup : requested_file_ext = "bad extension for data file"
        when "library", "lib"
          location = LIB_DIR
          case version
          when "production"
            remote_repo = "https://raw.githubusercontent.com/elanthia-online/lich-5/master/lib"
          when "beta" # FIXME: need to correct to releases?
            remote_repo = "https://raw.githubusercontent.com/elanthia-online/lich-5/staging/lib"
          when VERSION_REGEX # user asked for a file from a particular release
            version.gsub!(/^v/, '') # if present, remove 'v' to standardize on version numbers
            if Gem::Version.new(version) > Gem::Version.new('5.10.4')
              remote_repo = "https://raw.githubusercontent.com/elanthia-online/lich-5/refs/tags/v#{version}/lib"
              remote_repo = nil unless validate_url_request(File.join(remote_repo, requested_file))
            else
              Lich::Messaging.mono(Lich::Messaging.monsterbold("Only requests for Lich 5.11 or greater are supported.  There is no going back from here.\r\n"))
            end
          end
          requested_file =~ /\.rb$/ ? requested_file_ext = ".rb" : requested_file_ext = "bad extension for lib file"
        end
        unless requested_file_ext =~ /bad extension/ || remote_repo.nil?
          # we remove any file that is found at a specific location, whether we can download the updated version or not.  To avoid that, we will rename the file first, attempt the operation, and if the operation fails, we'll rename the file back to the original file.
          # File.rename(File.join(location, requested_file), File.join(location, "temp_#{requested_file}")) if File.exist?(File.join(location, requested_file))

          file_available = self.validate_url_request(File.join(remote_repo, requested_file))

          unless file_available
            Lich::Messaging.mono("The version or file you are requesting is not available.  Possible causes:\r\n")
            Lich::Messaging.mono("  1) A request for a non-Elanthia-Online script or data file was made.\r\n")
            Lich::Messaging.mono("  Fix: use ;repo download <filename> for files not maintained by Elanthia Online.\r\n")
            _respond
            Lich::Messaging.mono("  2) A request for a non-existent or deprecated Lich version was made.\r\n")
            Lich::Messaging.mono("  Fix: Double check your request to ensure you have a good Lich version number.\r\n")
            _respond
            Lich::Messaging.mono("  3) The server may be down or non-responsive.\r\n")
            Lich::Messaging.mono("  Fix: check in with the Elanthia-Online team in Discord:scripting to verify.\r\n")
          else
            File.delete(File.join(location, requested_file)) if File.exist?(File.join(location, requested_file))
            begin
              File.open(File.join(location, requested_file), "wb") do |file|
                file.write URI.parse(File.join(remote_repo, requested_file)).open.read
              end
              _respond
              _respond "#{requested_file} has been updated."
            rescue
              # we created a garbage file (zero bytes filename) so let's clean it up and inform.
              sleep 1
              File.delete(File.join(location, requested_file)) if File.exist?(File.join(location, requested_file))
              _respond; _respond "The filename #{requested_file} is not available via lich5-update."
              _respond "Check the spelling of your requested file, or use ';jinx' to"
              _respond "to download #{requested_file} from another respository."
            end
          end
        else
          _respond
          _respond "The requested file #{requested_file} has an incorrect extension."
          _respond "Valid extensions are '.lic' for scripts, '.rb' for library files,"
          _respond "and '.xml' or '.ui' for data files. Please correct and try again."
        end
      end

      def self.update_core_data_and_scripts(version = LICH_VERSION)
        if XMLData.game !~ /^GS|^DR/
          Lich::Messaging.mono(Lich::Messaging.monsterbold("Invalid game type, unsure what scripts to update via Update.update_core_scripts.\r\n"))
          return
        end

        updatable_scripts = {
          "all" => ["alias.lic", "autostart.lic", "go2.lic", "jinx.lic", "log.lic", "logxml.lic", "map.lic", "repository.lic", "vars.lic", "version.lic"],
          "gs"  => ["ewaggle.lic", "foreach.lic"],
          "dr"  => ["dependency.lic"]
        }

        ## We DO care about local edits from players to the Lich5 / data files
        ## specifically gameobj-data.xml and spell-list.xml.
        ## Let's be a little more purposeful and gentle with these two files.
        ["effect-list.xml"].each { |file|
          transition_filename = "#{file}".sub(".xml", '')
          newfilename = File.join(DATA_DIR, "#{transition_filename}-#{Time.now.to_i}.xml")
          if File.exist?(File.join(DATA_DIR, file))
            File.open(File.join(DATA_DIR, file), 'rb') { |r| File.open(newfilename, 'wb') { |w| w.write(r.read) } }
            _respond "The prior version of #{file} was renamed to #{newfilename}."
          end
          self.update_file('data', file)
        }

        ## We do not care about local edits from players to the Lich5 / script location
        ## for CORE scripts (those required to run Lich5 properly)
        updatable_scripts["all"].each { |script| self.update_file('script', script) }
        updatable_scripts["gs"].each { |script| self.update_file('script', script) } if XMLData.game =~ /^GS/
        updatable_scripts["dr"].each { |script| self.update_file('script', script) } if XMLData.game =~ /^DR/

        ## Update Lich.db value with last updated version
        Lich.core_updated_with_lich_version = version
      end

      # Moving this here because it doesn't collapse in IDE
      def self.help
        Lich::Messaging.mono("
      --help                   Display this message
      --announce               Get summary of changes for next version
      --update                 Update all changes for next version
      --snapshot               Grab current snapshot of Lich5 ecosystem and put in backup
      --revert                 Roll the Lich5 ecosystem back to the most recent snapshot

      --install --version=<VERSION>     Installs the requested version of Lich

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

      ;lich5-update --version=<VERSION> --library=<NAME>  Updates lib file to specific version

      *NOTE* If you use '--snapshot' in ';autostart' you will create a new
                snapshot folder every time you log a character in.  NOT recommended.
      \r\n")
      end

      # End module definitions
    end
  end
end
