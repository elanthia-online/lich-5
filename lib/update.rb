## Let's have fun updating Lich5!

module Lich
  module Util
    module Update
      require 'json'
      require 'open-uri'
      require 'rubygems/package'
      require 'zlib'

      # Update channel constants
      STABLE_REF = 'main'
      BETA_BRANCH_PREFIX = 'pre/beta' # fallback branch prefix for beta
      ASSET_TARBALL_NAME = 'lich-5.tar.gz'

      # simple in-memory cache for GitHub API responses
      @_http_cache = {}
      @_http_cache_ttl = 60 # seconds

      @current = LICH_VERSION
      @snapshot_core_script = ["alias.lic", "autostart.lic", "dependency.lic", "ewaggle.lic", "foreach.lic", "go2.lic", "infomon.lic",
                               "jinx.lic", "lnet.lic", "log.lic", "logxml.lic", "map.lic", "repository.lic", "vars.lic", "version.lic"]

      def self.request(type = '--announce')
        case type
        when /^(?:--announce|-a)\b/
          self.announce
        when /^--(?:beta|test)(?: --(?:(script|library|data))=(.+))?\b/
          self.prep_betatest($1&.dup, $2&.dup)
        when /^(?:--help|-h)\b/
          self.help # Ok, that's just wrong.
        when /^(?:--update|-u)\b/
          self.download_update
        when /^--refresh\b/
          respond; respond "This command has been removed."
        when /^(?:--revert|-r)\b/
          self.revert
        when /^--(?:(script|library|data))=(.+)\b/
          self.update_file($1&.dup, $2&.dup)
        when /^(?:--snapshot|-s)\b/ # this one needs to be after --script
          self.snapshot
        else
          respond; respond "Command '#{type}' unknown, illegitimate and ignored.  Exiting . . ."; respond
        end
      end

      def self.announce
        self.prep_update
        if "#{LICH_VERSION}".chr == '5'
          if Gem::Version.new(@current) < Gem::Version.new(@update_to)
            if !@new_features.empty?
              respond ''; _respond monsterbold_start() + "*** NEW VERSION AVAILABLE ***" + monsterbold_end()
              respond ''; respond ''
              respond ''; respond @new_features
              respond ''
              respond ''; respond "If you are interested in updating, run '#{$clean_lich_char}lich5-update --update' now."
              respond ''
            end
          else
            respond ''; respond "Lich version #{LICH_VERSION} is good.  Enjoy!"; respond ''
          end
        else
          # lich version 4 - just say 'no'
          respond "This script does not support Lich #{LICH_VERSION}."
        end
      end

      def self.help
        respond "
    --help                   Display this message
    --announce               Get summary of changes for next version
    --update                 Update all changes for next version
    --snapshot               Grab current snapshot of Lich5 ecosystem and put in backup
    --revert                 Roll the Lich5 ecosystem back to the most recent snapshot

  Example usage:

  [One time suggestions]
    #{$clean_lich_char}autostart add --global lich5-update --announce    Check for new version at login
    #{$clean_lich_char}autostart add --global lich5-update --update      To auto accept all updates at login

  [On demand suggestions]
    #{$clean_lich_char}lich5-update --announce                  Check to see if a new version is available
    #{$clean_lich_char}lich5-update --update                    Update the Lich5 ecosystem to the current release
    #{$clean_lich_char}lich5-update --revert                    Roll the Lich5 ecosystem back to latest snapshot
    #{$clean_lich_char}lich5-update --script=<NAME>             Update an individual script file found in Lich-5
    #{$clean_lich_char}lich5-update --library=<NAME>            Update an individual library file found in Lich-5
    #{$clean_lich_char}lich5-update --data=<NAME>               Update an individual data file found in Lich-5

    *NOTE* If you use '--snapshot' in '#{$clean_lich_char}autostart' you will create a new
                snapshot folder every time you log a character in.  NOT recommended.
    "
      end

      def self.snapshot
        respond
        respond 'Creating a snapshot of current Lich core files ONLY.'
        respond
        respond 'You may also wish to copy your entire Lich5 folder to'
        respond 'another location for additional safety, after any'
        respond 'additional requested updates are completed.'

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

        respond
        respond 'Current Lich ecosystem files (only) backed up to:'
        respond "    #{snapshot_subdir}"
      end

      def self.prep_betatest(type = nil, requested_file = nil)
        if type.nil?
          respond 'You are electing to participate in the beta testing of the next Lich release.'
          respond 'This beta test will include only Lich code, and does not include Ruby upates.'
          respond 'While we will do everything we can to ensure you have a smooth experience, '
          respond 'it is a test, and untoward things can result.  Please confirm your choice:'
          respond "Please confirm your participation:  #{$clean_lich_char}send Y or #{$clean_lich_char}send N"
          respond "You have 10 seconds to confirm, otherwise will be cancelled."
          # we are only going to get the next client-input line, and if it does not confirm, we bail
          # we are doing this to prevent hanging the client with various other inputs by the user
          sync_thread = $_CLIENT_ || $_DETACHABLE_CLIENT_
          timeout = Time.now + 10
          line = nil
          loop do
            line = sync_thread.gets
            break if line.is_a?(String) && line.strip =~ /^(?:<c>)?(?:#{$clean_lich_char}send|#{$clean_lich_char}s) /i
            break if Time.now > timeout
          end
          if line.is_a?(String) && line =~ /send Y|s Y/i
            @beta_response = 'accepted'
            respond 'Beta test installation accepted.  Thank you for considering!'
          else
            @beta_response = 'rejected'
            respond 'Aborting beta test installation request.  Thank you for considering!'
            respond
          end

          if @beta_response =~ /accepted/
            # Resolve a viable beta ref (enforces: prerelease minor > stable minor)
            ref = self.resolve_channel_ref(:beta)
            if ref.nil?
              respond 'No viable beta found. Aborting beta update.'
              return
            end
            releases_url = "https://api.github.com/repos/elanthia-online/lich-5/releases"
            update_info = URI.parse(releases_url).open.read
            releases = JSON::parse(update_info)
            record = releases.find { |r| r['prerelease'] && r['tag_name'] == (ref.start_with?('v') ? ref : "v#{ref}") }
            if record
              record.each { |entry, value|
                if entry.include? 'tag_name'
                  @update_to = value.sub('v', '')
                elsif entry.include? 'assets'
                  @holder = value
                elsif entry.include? 'body'
                  @new_features = value.gsub(/\#\# What's Changed.+$/m, '')
                end
              }
              release_asset = @holder && @holder.find { |x| x['name'] =~ /\b#{ASSET_TARBALL_NAME}\b/ }
              if release_asset
                @zipfile = release_asset.fetch('browser_download_url')
              else
                @zipfile = "https://codeload.github.com/elanthia-online/lich-5/tar.gz/#{ref}"
              end
            else
              @update_to = ref.sub(/^v/, '')
              @zipfile = "https://codeload.github.com/elanthia-online/lich-5/tar.gz/#{ref}"
            end
            Lich::Util::Update.download_update
          elsif @beta_response =~ /rejected/
            nil
          else
            respond 'This is not where I want to be on a beta test request.'
            respond
          end
        else
          self.update_file(type, requested_file, 'beta')
        end
      end

      # Resolve a Git ref for stable/beta everywhere it's needed
      def self.resolve_channel_ref(channel)
        case channel
        when :stable, 'production'
          STABLE_REF
        when :beta
          # Determine latest stable (non-prerelease) to enforce minor-bump rule
          stable_tag = self.latest_stable_tag # e.g., "v5.14.3"
          stable_major, stable_minor = self.major_minor_from(stable_tag)
          env = ENV['LICH_BETA_REF']
          return env unless env.nil? || env.empty?
          tag = self.latest_prerelease_tag_greater_than(stable_major, stable_minor)
          return tag if tag
          branch = self.latest_prefixed_branch_greater_than(BETA_BRANCH_PREFIX, stable_major, stable_minor)
          return branch if branch
          nil
        else
          STABLE_REF
        end
      end

      # Minimal GitHub JSON fetch with tiny cache and friendly errors
      def self.fetch_github_json(url)
        now = Time.now.to_i
        entry = @_http_cache[url]
        if entry && (now - entry[:ts] < @_http_cache_ttl)
          return entry[:data]
        end
        begin
          raw = URI.parse(url).open.read
          data = JSON::parse(raw)
          @_http_cache[url] = { ts: now, data: data }
          data
        rescue => e
          respond "Update notice: network error fetching #{url.split('/repos/').last || url} (fetch_github_json): #{e.message}"
          nil
        end
      end

      def self.latest_stable_tag
        releases = fetch_github_json('https://api.github.com/repos/elanthia-online/lich-5/releases')
        return nil unless releases.is_a?(Array)
        stable = releases.select { |r| !r['prerelease'] && r['tag_name'] }.max_by { |r| self.version_key(r['tag_name']) }
        stable && stable['tag_name']
      end

      def self.latest_prerelease_tag_greater_than(stable_major, stable_minor)
        releases = fetch_github_json('https://api.github.com/repos/elanthia-online/lich-5/releases')
        return nil unless releases.is_a?(Array)
        prereleases = releases.select { |r| r['prerelease'] && r['tag_name'] }
        return nil if prereleases.empty?
        candidates = prereleases.select do |r|
          maj, min = self.major_minor_from(r['tag_name'])
          next false unless maj && min
          (maj > stable_major) || (maj == stable_major && min > stable_minor)
        end
        return nil if candidates.empty?
        tag = candidates.max_by { |r| self.version_key(r['tag_name']) }['tag_name']
        tag.sub(/^v/, '')
      end

      # Optional fallback: newest branch whose name starts with prefix and encodes a version
      # Only branches with (major,minor) > stable's (major,minor) are considered.
      # Accepts names like "pre/beta/5.15" or "pre/beta-5.15.0".
      def self.latest_prefixed_branch_greater_than(prefix, stable_major, stable_minor)
        branches = fetch_github_json('https://api.github.com/repos/elanthia-online/lich-5/branches?per_page=100')
        return nil unless branches.is_a?(Array)
        names = branches.map { |b| b['name'] }.compact
        candidates = names.select { |n| n.start_with?(prefix) }
        filtered = candidates.select do |n|
          maj, min = self.major_minor_from(n)
          maj && min && ((maj > stable_major) || (maj == stable_major && min > stable_minor))
        end
        return nil if filtered.empty?
        begin
          filtered.max_by { |n| self.version_key(n) }
        rescue => e
          respond "Update notice: ordering branches (latest_prefixed_branch_greater_than): #{e.message}"
          filtered.sort.last
        end
      end

      def self.version_key(tag)
        Gem::Version.new(tag.to_s.sub(/^v/, '').gsub('-beta.', '.beta.'))
      end

      def self.major_minor_from(str)
        return [nil, nil] if str.nil?
        s = str.to_s
        s = s.sub(/^v/, '')
        if s =~ /(\d+)\.(\d+)\.(\d+)/
          return [$1.to_i, $2.to_i]
        elsif s =~ /(\d+)\.(\d+)/
          return [$1.to_i, $2.to_i]
        else
          [nil, nil]
        end
      end

      def self.prep_update
        latest = fetch_github_json("https://api.github.com/repos/elanthia-online/lich-5/releases/latest")
        if latest.is_a?(Hash) && latest['prerelease']
          all = fetch_github_json('https://api.github.com/repos/elanthia-online/lich-5/releases')
          if all.is_a?(Array)
            stable = all.select { |r| !r['prerelease'] && r['tag_name'] }.max_by { |r| self.version_key(r['tag_name']) }
            latest = stable if stable
          end
        end
        unless latest.is_a?(Hash)
          respond "Update notice: could not read latest release payload (prep_update)."
          return
        end

        @update_to = latest['tag_name'].to_s.sub('v', '')
        @holder = latest['assets']
        @new_features = latest['body'].to_s.gsub(/\#\# What's Changed.+$/m, '')
        release_asset = @holder && @holder.find { |x| x['name'] =~ /\b#{ASSET_TARBALL_NAME}\b/ }
        @zipfile = release_asset.fetch('browser_download_url')
      end

      def self.download_update
        ## This is the workhorse routine that does the file moves from an update
        self.prep_update if @update_to.nil? or @update_to.empty?
        if Gem::Version.new("#{@update_to}") <= Gem::Version.new("#{@current}")
          respond ''; respond "Lich version #{LICH_VERSION} is good.  Enjoy!"; respond ''
        else
          respond; respond 'Getting reaady to update.  First we will create a'
          respond 'snapshot in case there are problems with the update.'

          self.snapshot

          # download the requested update (can be prod release, or beta)
          respond; respond "Downloading Lich5 version #{@update_to}"; respond
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

          # delete all existing lib files to not leave old ones behind
          FileUtils.rm_rf(Dir.glob(File.join(LIB_DIR, "*")))

          respond; respond 'Copying updated lich files to their locations.'

          ## We do not care about local edits from players in the Lich5 / lib location
          FileUtils.copy_entry(File.join(TEMP_DIR, filename, "lib"), File.join(LIB_DIR))
          respond; respond "All Lich lib files have been updated."; respond

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

          respond; respond "Lich5 has been updated to Lich5 version #{@update_to}"
          respond "You should exit the game, then log back in.  This will start the game"
          respond "with your updated Lich.  Enjoy!"
        end
      end

      def self.revert
        ## Since the request is to roll-back, we will do so destructively
        ## without another snapshot and without worrying about saving files
        ## that can be reinstalled with the lich5-update --update command

        respond; respond 'Reverting Lich5 to previously installed version.'
        revert_array = Dir.glob(File.join(BACKUP_DIR, "*")).sort.reverse
        restore_snapshot = revert_array[0]
        if restore_snapshot.empty? or /L5-snapshot/ !~ restore_snapshot
          respond "No prior Lich5 version found. Seek assistance."
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
          respond
          respond "Lich5 has been reverted to Lich5 version #{targetversion}"
          respond "You should exit the game, then log back in.  This will start the game"
          respond "with your previous version of Lich.  Enjoy!"
        end
      end

      def self.update_file(type, rf, version = 'production')
        if version =~ /^(?:staging|master)$/i
          respond 'Requested channel %s mapped to main (stable).' % [version]
          version = 'production'
        end
        requested_file = rf
        case type
        when "script"
          location = SCRIPT_DIR
          if requested_file.downcase == 'dependency.lic'
            remote_repo = "https://raw.githubusercontent.com/elanthia-online/dr-scripts/main"
          else
            remote_repo = "https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts"
          end
          requested_file =~ /\.lic$/ ? requested_file_ext = ".lic" : requested_file_ext = "bad extension"
        when "library"
          location = LIB_DIR
          case version
          when "production"
            remote_repo = "https://raw.githubusercontent.com/elanthia-online/lich-5/#{resolve_channel_ref(:stable)}/lib"
          when "beta"
            ref = resolve_channel_ref(:beta)
            if ref.nil?
              respond 'No viable beta found. Aborting beta update.'
              return
            end
            remote_repo = "https://raw.githubusercontent.com/elanthia-online/lich-5/#{ref}/lib"
          end
          requested_file =~ /\.rb$/ ? requested_file_ext = ".rb" : requested_file_ext = "bad extension"
        when "data"
          location = DATA_DIR
          remote_repo = "https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts"
          requested_file =~ /(\.(?:xml|ui))$/ ? requested_file_ext = $1&.dup : requested_file_ext = "bad extension"
        end
        unless requested_file_ext == "bad extension"
          File.delete(File.join(location, requested_file)) if File.exist?(File.join(location, requested_file))
          begin
            File.open(File.join(location, requested_file), "wb") do |file|
              file.write URI.parse(File.join(remote_repo, requested_file)).open.read
            end
            respond
            respond "#{requested_file} has been updated."
          rescue
            # we created a garbage file (zero bytes filename) so let's clean it up and inform.
            sleep 1
            File.delete(File.join(location, requested_file)) if File.exist?(File.join(location, requested_file))
            respond; respond "The filename #{requested_file} is not available via lich5-update."
            respond "Check the spelling of your requested file, or use '#{$clean_lich_char}jinx' to"
            respond "to download #{requested_file} from another respository."
          end
        else
          respond
          respond "The requested file #{requested_file} has an incorrect extension."
          respond "Valid extensions are '.lic' for scripts, '.rb' for library files,"
          respond "and '.xml' or '.ui' for data files. Please correct and try again."
        end
      end

      def self.update_core_data_and_scripts(version = LICH_VERSION)
        if XMLData.game !~ /^GS|^DR/
          respond "invalid game type, unsure what scripts to update via Update.update_core_scripts"
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
            respond "The prior version of #{file} was renamed to #{newfilename}."
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
      # End module definitions
    end
  end
end
