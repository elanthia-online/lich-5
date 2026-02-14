# Let's have fun updating Lich5!

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
      GITHUB_REPO = 'elanthia-online/lich-5'

      # Simple in-memory cache for GitHub API responses
      @_http_cache = {}
      @_http_cache_ttl = 60 # seconds

      @current = LICH_VERSION
      @snapshot_core_script = ["alias.lic", "autostart.lic", "dependency.lic", "ewaggle.lic", "foreach.lic",
                               "go2.lic", "infomon.lic", "jinx.lic", "lnet.lic", "log.lic", "logxml.lic",
                               "map.lic", "repository.lic", "vars.lic", "version.lic"]

      #
      # Process update commands and route to appropriate handlers
      #
      # @param type [String] the command type to execute
      # @return [void]
      #
      def self.request(type = '--announce')
        case type
        when /^(?:--announce|-a)\b/
          announce
        when /^--branch=(.+)$/
          download_branch_update($1)
        when /^--(?:beta|test)(?: --(?:(script|library|data))=(.+))?\b/
          prep_betatest($1&.dup, $2&.dup)
        when /^(?:--help|-h)\b/
          help
        when /^(?:--update|-u)\b/
          download_release_update
        when /^--refresh\b/
          respond
          respond "This command has been removed."
        when /^(?:--revert|-r)\b/
          revert
        when /^--(?:(script|library|data))=(.+)\b/
          update_file($1&.dup, $2&.dup)
        when /^(?:--snapshot|-s)\b/
          snapshot
        else
          respond
          respond "Command '#{type}' unknown, illegitimate and ignored.  Exiting . . ."
          respond
        end
      end

      #
      # Display announcement about available updates
      #
      # @return [void]
      #
      def self.announce
        prep_update
        if "#{LICH_VERSION}".chr == '5'
          if Gem::Version.new(@current) < Gem::Version.new(@update_to)
            unless @new_features.empty?
              respond ''
              _respond monsterbold_start() + "*** NEW VERSION AVAILABLE ***" + monsterbold_end()
              respond ''
              respond ''
              respond ''
              respond @new_features
              respond ''
              respond ''
              respond "If you are interested in updating, run '#{$clean_lich_char}lich5-update --update' now."
              respond ''
            end
          else
            respond ''
            respond "Lich version #{LICH_VERSION} is good.  Enjoy!"
            respond ''
          end
        else
          # lich version 4 - just say 'no'
          respond "This script does not support Lich #{LICH_VERSION}."
        end
      end

      #
      # Display help information for available commands
      #
      # @return [void]
      #
      def self.help
        respond "
    --help                   Display this message
    --announce               Get summary of changes for next version
    --update                 Update all changes for next version
    --branch=<name>          Update to a specific GitHub branch
    --snapshot               Grab current snapshot of Lich5 ecosystem and put in backup
    --revert                 Roll the Lich5 ecosystem back to the most recent snapshot

  Example usage:

  [One time suggestions]
    #{$clean_lich_char}autostart add --global lich5-update --announce    Check for new version at login
    #{$clean_lich_char}autostart add --global lich5-update --update      To auto accept all updates at login

  [On demand suggestions]
    #{$clean_lich_char}lich5-update --announce                  Check to see if a new version is available
    #{$clean_lich_char}lich5-update --update                    Update the Lich5 ecosystem to the current release
    #{$clean_lich_char}lich5-update --branch=<name>             Update to a specific GitHub branch (advanced)
    #{$clean_lich_char}lich5-update --revert                    Roll the Lich5 ecosystem back to latest snapshot
    #{$clean_lich_char}lich5-update --script=<name>             Update an individual script file found in Lich-5
    #{$clean_lich_char}lich5-update --library=<name>            Update an individual library file found in Lich-5
    #{$clean_lich_char}lich5-update --data=<name>               Update an individual data file found in Lich-5

  [Branch update examples]
    #{$clean_lich_char}lich5-update --branch=main               Update to the main stable branch
    #{$clean_lich_char}lich5-update --branch=some_branch_name   Update to a different branch

    *NOTE* If you use '--snapshot' in '#{$clean_lich_char}autostart' you will create a new
                snapshot folder every time you log a character in.  NOT recommended.
    "
      end

      #
      # Create a snapshot backup of current Lich core files
      #
      # @return [void]
      #
      def self.snapshot
        respond
        respond 'Creating a snapshot of current Lich core files ONLY.'
        respond
        respond 'You may also wish to copy your entire Lich5 folder to'
        respond 'another location for additional safety, after any'
        respond 'additional requested updates are completed.'

        # Create the snapshot folder
        snapshot_subdir = File.join(BACKUP_DIR, "L5-snapshot-#{Time.now.strftime("%Y-%m-%d-%H-%M-%S")}")
        FileUtils.mkdir_p(snapshot_subdir)

        # Backup lich.rbw main file
        FileUtils.cp(File.join(LICH_DIR, File.basename($PROGRAM_NAME)),
                     File.join(snapshot_subdir, File.basename($PROGRAM_NAME)))

        # Backup LIB folder and its subfolders
        FileUtils.mkdir_p(File.join(snapshot_subdir, "lib"))
        FileUtils.cp_r(LIB_DIR, snapshot_subdir)

        # Backup core scripts
        FileUtils.mkdir_p(File.join(snapshot_subdir, "scripts"))
        @snapshot_core_script.each do |file|
          source = File.join(SCRIPT_DIR, file)
          FileUtils.cp(source, File.join(snapshot_subdir, "scripts", file)) if File.exist?(source)
        end

        respond
        respond 'Current Lich ecosystem files (only) backed up to:'
        respond "    #{snapshot_subdir}"
      end

      #
      # Prepare and optionally install beta test version
      #
      # @param type [String, nil] the file type to update (script, library, data)
      # @param requested_file [String, nil] the specific file to update
      # @return [void]
      #
      def self.prep_betatest(type = nil, requested_file = nil)
        if type.nil?
          respond 'You are electing to participate in the beta testing of the next Lich release.'
          respond 'This beta test will include only Lich code, and does not include Ruby upates.'
          respond 'While we will do everything we can to ensure you have a smooth experience, '
          respond 'it is a test, and untoward things can result.  Please confirm your choice:'
          respond "Please confirm your participation:  #{$clean_lich_char}send Y or #{$clean_lich_char}send N"
          respond "You have 10 seconds to confirm, otherwise will be cancelled."

          # Get user confirmation
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
            ref = resolve_channel_ref(:beta)
            if ref.nil?
              respond 'No viable beta found. Aborting beta update.'
              return
            end

            releases_url = "https://api.github.com/repos/#{GITHUB_REPO}/releases"
            update_info = URI.parse(releases_url).open.read
            releases = JSON.parse(update_info)
            record = releases.find { |r| r['prerelease'] && r['tag_name'] == (ref.start_with?('v') ? ref : "v#{ref}") }

            if record
              record.each do |entry, value|
                if entry.include? 'tag_name'
                  @update_to = value.sub('v', '')
                elsif entry.include? 'assets'
                  @holder = value
                elsif entry.include? 'body'
                  @new_features = value.gsub(/\#\# What's Changed.+$/m, '').gsub(/<!--[\s\S]*?-->/, '')
                end
              end
              release_asset = @holder && @holder.find { |x| x['name'] =~ /\b#{ASSET_TARBALL_NAME}\b/ }
              if release_asset
                @zipfile = release_asset.fetch('browser_download_url')
              else
                @zipfile = "https://codeload.github.com/#{GITHUB_REPO}/tar.gz/#{ref}"
              end
            else
              @update_to = ref.sub(/^v/, '')
              @zipfile = "https://codeload.github.com/#{GITHUB_REPO}/tar.gz/#{ref}"
            end
            download_release_update
          elsif @beta_response =~ /rejected/
            nil
          else
            respond 'This is not where I want to be on a beta test request.'
            respond
          end
        else
          update_file(type, requested_file, 'beta')
        end
      end

      #
      # Resolve a Git ref for stable/beta channels
      #
      # @param channel [Symbol, String] the channel to resolve (:stable, :beta, 'production')
      # @return [String, nil] the resolved Git reference or nil if not found
      #
      def self.resolve_channel_ref(channel)
        case channel
        when :stable, 'production'
          STABLE_REF
        when :beta
          # Determine latest stable (non-prerelease) to enforce version comparison
          stable_tag = latest_stable_tag # e.g., "v5.14.3"
          stable_major, stable_minor, stable_patch = major_minor_patch_from(stable_tag)
          env = ENV['LICH_BETA_REF']
          return env unless env.nil? || env.empty?
          tag = latest_prerelease_tag_greater_than(stable_major, stable_minor, stable_patch)
          return tag if tag
          branch = latest_prefixed_branch_greater_than(BETA_BRANCH_PREFIX, stable_major, stable_minor, stable_patch)
          return branch if branch
          nil
        else
          STABLE_REF
        end
      end

      #
      # Fetch and cache GitHub JSON API responses
      #
      # @param url [String] the GitHub API URL to fetch
      # @return [Hash, Array, nil] parsed JSON data or nil on error
      #
      def self.fetch_github_json(url)
        now = Time.now.to_i
        entry = @_http_cache[url]
        if entry && (now - entry[:ts] < @_http_cache_ttl)
          return entry[:data]
        end
        begin
          raw = URI.parse(url).open.read
          data = JSON.parse(raw)
          @_http_cache[url] = { ts: now, data: data }
          data
        rescue => e
          respond "Update notice: network error fetching #{url.split('/repos/').last || url} (fetch_github_json): #{e.message}"
          nil
        end
      end

      #
      # Get the latest stable (non-prerelease) tag from GitHub
      #
      # @return [String, nil] the latest stable tag or nil if not found
      #
      def self.latest_stable_tag
        releases = fetch_github_json("https://api.github.com/repos/#{GITHUB_REPO}/releases")
        return nil unless releases.is_a?(Array)
        stable = releases.select { |r| !r['prerelease'] && r['tag_name'] }.max_by { |r| version_key(r['tag_name']) }
        stable && stable['tag_name']
      end

      #
      # Find the latest prerelease tag with version greater than stable
      #
      # @param stable_major [Integer] the stable major version number
      # @param stable_minor [Integer] the stable minor version number
      # @param stable_patch [Integer] the stable patch version number
      # @return [String, nil] the latest prerelease tag or nil if not found
      #
      def self.latest_prerelease_tag_greater_than(stable_major, stable_minor, stable_patch = 0)
        releases = fetch_github_json("https://api.github.com/repos/#{GITHUB_REPO}/releases")
        return nil unless releases.is_a?(Array)
        prereleases = releases.select { |r| r['prerelease'] && r['tag_name'] }
        return nil if prereleases.empty?
        candidates = prereleases.select do |r|
          maj, min, patch = major_minor_patch_from(r['tag_name'])
          next false unless maj && min
          # Accept if: major > stable, OR (major == stable AND minor > stable),
          # OR (major == stable AND minor == stable AND patch > stable)
          (maj > stable_major) ||
            (maj == stable_major && min > stable_minor) ||
            (maj == stable_major && min == stable_minor && patch > stable_patch)
        end
        return nil if candidates.empty?
        tag = candidates.max_by { |r| version_key(r['tag_name']) }['tag_name']
        tag.sub(/^v/, '')
      end

      #
      # Find the latest prefixed branch with version greater than stable
      # Optional fallback for branches like "pre/beta/5.15" or "pre/beta-5.15.0"
      #
      # @param prefix [String] the branch name prefix to search for
      # @param stable_major [Integer] the stable major version number
      # @param stable_minor [Integer] the stable minor version number
      # @param stable_patch [Integer] the stable patch version number
      # @return [String, nil] the latest matching branch name or nil if not found
      #
      def self.latest_prefixed_branch_greater_than(prefix, stable_major, stable_minor, stable_patch = 0)
        branches = fetch_github_json("https://api.github.com/repos/#{GITHUB_REPO}/branches?per_page=100")
        return nil unless branches.is_a?(Array)
        names = branches.map { |b| b['name'] }.compact
        candidates = names.select { |n| n.start_with?(prefix) }
        filtered = candidates.select do |n|
          maj, min, patch = major_minor_patch_from(n)
          maj && min && (
            (maj > stable_major) ||
            (maj == stable_major && min > stable_minor) ||
            (maj == stable_major && min == stable_minor && patch > stable_patch)
          )
        end
        return nil if filtered.empty?
        begin
          filtered.max_by { |n| version_key(n) }
        rescue => e
          respond "Update notice: ordering branches (latest_prefixed_branch_greater_than): #{e.message}"
          filtered.sort.last
        end
      end

      #
      # Convert version string to comparable Gem::Version key
      #
      # @param tag_or_name [String] the tag or branch name containing version info
      # @return [Gem::Version] comparable version object
      #
      def self.version_key(tag_or_name)
        s = tag_or_name.to_s
        # strip leading 'v'
        s = s.sub(/^v/, '')
        # if this looks like a branch or path (e.g., "pre/beta/5.15.0" or "pre/beta-5.15.0"),
        # extract the first version-looking substring to avoid prefix text interfering
        if s =~ /(\d+\.\d+(?:\.\d+)?(?:-[0-9A-Za-z\.]+)?)/ # captures 1.2 or 1.2.3 and optional suffix like -beta.
          s = Regexp.last_match(1)
        end
        # normalize beta prerelease so beta.10 > beta.9
        s = s.gsub('-beta.', '.beta.').gsub(/-beta(?!\.)/, '.beta')
        Gem::Version.new(s)
      end

      #
      # Extract major, minor, and patch version numbers from version string
      #
      # @param str [String] the version string to parse
      # @return [Array<Integer, Integer, Integer>] array of [major, minor, patch] or [nil, nil, nil] if not parseable
      #
      def self.major_minor_patch_from(str)
        return [nil, nil, nil] if str.nil?
        s = str.to_s
        s = s.sub(/^v/, '')
        if s =~ /(\d+)\.(\d+)\.(\d+)/
          [$1.to_i, $2.to_i, $3.to_i]
        elsif s =~ /(\d+)\.(\d+)/
          [$1.to_i, $2.to_i, 0]
        else
          [nil, nil, nil]
        end
      end

      #
      # Extract major and minor version numbers from version string (legacy compatibility)
      #
      # @param str [String] the version string to parse
      # @return [Array<Integer, Integer>] array of [major, minor] or [nil, nil] if not parseable
      #
      def self.major_minor_from(str)
        maj, min, _patch = major_minor_patch_from(str)
        [maj, min]
      end

      #
      # Prepare update metadata from latest GitHub release
      #
      # @return [void]
      #
      def self.prep_update
        latest = fetch_github_json("https://api.github.com/repos/#{GITHUB_REPO}/releases/latest")
        if latest.is_a?(Hash) && latest['prerelease']
          all = fetch_github_json("https://api.github.com/repos/#{GITHUB_REPO}/releases")
          if all.is_a?(Array)
            stable = all.select { |r| !r['prerelease'] && r['tag_name'] }.max_by { |r| version_key(r['tag_name']) }
            latest = stable if stable
          end
        end
        unless latest.is_a?(Hash)
          respond "Update notice: could not read latest release payload (prep_update)."
          return
        end

        @update_to = latest['tag_name'].to_s.sub('v', '')
        @holder = latest['assets']
        @new_features = latest['body'].to_s.gsub(/\#\# What's Changed.+$/m, '').gsub(/<!--[\s\S]*?-->/, '')
        release_asset = @holder && @holder.find { |x| x['name'] =~ /\b#{ASSET_TARBALL_NAME}\b/ }
        @zipfile = release_asset.fetch('browser_download_url')
      end

      #
      # Download and install a specific branch from GitHub
      #
      # @param branch_name [String] the name of the branch to download
      # @return [void]
      #
      def self.download_branch_update(branch_name)
        branch_name = branch_name.strip
        if branch_name.empty?
          respond
          respond "Error: Branch name cannot be empty."
          respond "Usage: #{$clean_lich_char}lich5-update --branch=<branch_name>"
          respond
          return
        end

        respond
        respond "Attempting to update to branch: #{branch_name}"
        respond "This will download from GitHub and extract over your current installation."
        respond

        # Create snapshot before attempting update
        snapshot

        # Construct the GitHub tar.gz download URL
        tarball_url = "https://github.com/#{GITHUB_REPO}/archive/refs/heads/#{branch_name}.tar.gz"
        filename = "lich5-branch-#{branch_name}"

        begin
          # Download the branch tarball
          respond
          respond "Downloading branch '#{branch_name}' from GitHub..."
          respond
          tarball_path = File.join(TEMP_DIR, "#{filename}.tar.gz")
          File.open(tarball_path, "wb") do |file|
            file.write URI.parse(tarball_url).open.read
          end

          # Extract the tarball using the same method as release updates
          extract_dir = File.join(TEMP_DIR, filename)
          FileUtils.mkdir_p(extract_dir)
          Gem::Package.new("").extract_tar_gz(File.open(tarball_path, "rb"), extract_dir)

          # GitHub creates a nested directory in the format: lich-5-<branch_name>
          # Find the extracted directory
          extracted_dirs = Dir.children(extract_dir)
          if extracted_dirs.empty?
            raise StandardError, "No directories found in extracted tarball"
          end

          source_dir = File.join(extract_dir, extracted_dirs[0])

          # Verify this looks like a Lich installation
          unless validate_lich_structure(source_dir)
            raise StandardError, "Downloaded branch does not appear to be a valid Lich installation"
          end

          # Perform the update
          perform_update(source_dir, branch_name)

          # Clean up
          FileUtils.remove_dir(extract_dir) if File.directory?(extract_dir)
          FileUtils.rm(tarball_path) if File.exist?(tarball_path)

          respond
          respond "Successfully updated to branch: #{branch_name}"
          respond "You should exit the game, then log back in to use the updated version."
          respond "Enjoy!"
        rescue OpenURI::HTTPError => e
          respond
          respond "Error: Could not download branch '#{branch_name}'"
          respond "HTTP Error: #{e.message}"
          respond "Please verify the branch name exists on GitHub."
          respond
        rescue StandardError => e
          respond
          respond "Error during branch update: #{e.message}"
          respond "Your installation has been preserved."
          respond "You may want to run '#{$clean_lich_char}lich5-update --revert' if needed."
          respond

          # Clean up on error
          begin
            FileUtils.remove_dir(File.join(TEMP_DIR, filename)) if File.directory?(File.join(TEMP_DIR, filename))
            FileUtils.rm(File.join(TEMP_DIR, "#{filename}.tar.gz")) if File.exist?(File.join(TEMP_DIR, "#{filename}.tar.gz"))
          rescue => cleanup_error
            respond "Warning: Could not clean up temporary files: #{cleanup_error.message}"
          end
        end
      end

      #
      # Download and install a release update (tarball)
      #
      # @return [void]
      #
      def self.download_release_update
        # This is the workhorse routine that does the file moves from an update
        prep_update if @update_to.nil? || @update_to.empty?
        if Gem::Version.new("#{@update_to}") <= Gem::Version.new("#{@current}")
          respond ''
          respond "Lich version #{LICH_VERSION} is good.  Enjoy!"
          respond ''
        else
          respond
          respond 'Getting ready to update.  First we will create a'
          respond 'snapshot in case there are problems with the update.'

          snapshot

          # Download the requested update (can be prod release, or beta)
          respond
          respond "Downloading Lich5 version #{@update_to}"
          respond
          filename = "lich5-#{@update_to}"
          File.open(File.join(TEMP_DIR, "#{filename}.tar.gz"), "wb") do |file|
            file.write URI.parse(@zipfile).open.read
          end

          # Unpack and prepare to use the requested update
          FileUtils.mkdir_p(File.join(TEMP_DIR, filename))
          Gem::Package.new("").extract_tar_gz(File.open(File.join(TEMP_DIR, "#{filename}.tar.gz"), "rb"),
                                              File.join(TEMP_DIR, filename))
          new_target = Dir.children(File.join(TEMP_DIR, filename))
          FileUtils.cp_r(File.join(TEMP_DIR, filename, new_target[0]), TEMP_DIR)
          FileUtils.remove_dir(File.join(TEMP_DIR, filename))
          FileUtils.mv(File.join(TEMP_DIR, new_target[0]), File.join(TEMP_DIR, filename))

          source_dir = File.join(TEMP_DIR, filename)

          # Check Ruby version compatibility before updating
          unless check_ruby_compatibility(source_dir, @update_to)
            # Clean up downloaded files
            FileUtils.remove_dir(source_dir) if File.directory?(source_dir)
            FileUtils.rm(File.join(TEMP_DIR, "#{filename}.tar.gz")) if File.exist?(File.join(TEMP_DIR, "#{filename}.tar.gz"))
            return
          end

          # Perform the update
          perform_update(source_dir, @update_to)

          # Clean up after ourselves
          FileUtils.remove_dir(source_dir) # we know these exist because
          FileUtils.rm(File.join(TEMP_DIR, "#{filename}.tar.gz")) # we just processed them

          respond
          respond "Lich5 has been updated to Lich5 version #{@update_to}"
          respond "You should exit the game, then log back in.  This will start the game"
          respond "with your updated Lich.  Enjoy!"
        end
      end

      #
      # Validate that a directory contains a Lich installation structure
      #
      # @param dir [String] directory to validate
      # @return [Boolean] true if structure is valid
      #
      def self.validate_lich_structure(dir)
        required_items = ['lib', 'lich.rbw']
        required_items.all? { |item| File.exist?(File.join(dir, item)) }
      end

      #
      # Check if the update requires a newer Ruby version
      #
      # @param source_dir [String] directory containing the update
      # @param version [String] version being installed
      # @return [Boolean] true if Ruby version is compatible, false otherwise
      #
      def self.check_ruby_compatibility(source_dir, version)
        version_file_path = File.join(source_dir, "lib", "version.rb")
        if File.exist?(version_file_path)
          version_file_content = File.read(version_file_path)
          if (match = version_file_content.match(/REQUIRED_RUBY\s*=\s*["']([^"']+)["']/))
            required_ruby_version = match[1]
            current_ruby_version = RUBY_VERSION
            if Gem::Version.new(current_ruby_version) < Gem::Version.new(required_ruby_version)
              respond
              respond "*** UPDATE ABORTED ***"
              respond
              respond "Lich version #{version} requires Ruby #{required_ruby_version} or higher."
              respond "Your current Ruby version is #{current_ruby_version}."
              respond
              respond "Please update your Ruby installation before updating Lich."
              respond
              respond "DragonRealms - https://github.com/elanthia-online/lich-5/wiki/Documentation-for-Installing-and-Upgrading-Lich"
              respond "Gemstone IV  - https://gswiki.play.net/Lich:Software/Installation"
              respond
              return false
            end
          end
        end
        true
      end

      #
      # Perform the actual update by copying files from source to installation
      #
      # @param source_dir [String] directory containing the update files
      # @param version [String] version being installed
      # @return [void]
      #
      def self.perform_update(source_dir, version)
        # Delete all existing lib files to not leave old ones behind
        FileUtils.rm_rf(Dir.glob(File.join(LIB_DIR, "*")))

        respond
        respond 'Copying updated lich files to their locations.'

        # We do not care about local edits from players in the Lich5 / lib location
        FileUtils.copy_entry(File.join(source_dir, "lib"), File.join(LIB_DIR))
        respond
        respond "All Lich lib files have been updated."
        respond

        # Use new method so can be reused to do a blanket update of core data & scripts
        update_core_data_and_scripts(version)

        # Finally we move the lich.rbw file into place to complete the update
        # We do not need to save a copy of this in the TEMP_DIR as previously done,
        # since we took the snapshot at the beginning
        lich_to_update = File.join(LICH_DIR, File.basename($PROGRAM_NAME))
        update_to_lich = File.join(source_dir, "lich.rbw")
        File.open(update_to_lich, 'rb') { |r| File.open(lich_to_update, 'wb') { |w| w.write(r.read) } }
      end

      #
      # Revert to the most recent snapshot
      #
      # @return [void]
      #
      def self.revert
        # Since the request is to roll-back, we will do so destructively
        # without another snapshot and without worrying about saving files
        # that can be reinstalled with the lich5-update --update command

        respond
        respond 'Reverting Lich5 to previously installed version.'

        revert_array = Dir.glob(File.join(BACKUP_DIR, "*")).sort.reverse
        restore_snapshot = revert_array[0]
        if restore_snapshot.empty? || /L5-snapshot/ !~ restore_snapshot
          respond "No prior Lich5 version found. Seek assistance."
        else
          # Delete all lib files
          FileUtils.rm_rf(Dir.glob(File.join(LIB_DIR, "*")))
          # Copy all backed up lib files
          FileUtils.cp_r(File.join(restore_snapshot, "lib", "."), LIB_DIR)
          # Delete array of core scripts
          @snapshot_core_script.each do |file|
            File.delete(File.join(SCRIPT_DIR, file)) if File.exist?(File.join(SCRIPT_DIR, file))
          end
          # Copy all backed up core scripts (array to save, only array files in backup)
          FileUtils.cp_r(File.join(restore_snapshot, "scripts", "."), SCRIPT_DIR)

          # Skip gameobj-data and spell-list (non-functional logically, previous versions
          # already present and current files may contain local edits)

          # Update lich.rbw in stream because it is active (we hope)
          lich_to_update = File.join(LICH_DIR, File.basename($PROGRAM_NAME))
          update_to_lich = File.join(restore_snapshot, "lich.rbw")
          File.open(update_to_lich, 'rb') { |r| File.open(lich_to_update, 'wb') { |w| w.write(r.read) } }

          # As a courtesy to the player, remind which version they were rev'd back to
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

      #
      # Update a specific file (script, library, or data)
      #
      # @param type [String] the file type ('script', 'library', or 'data')
      # @param rf [String] the requested filename
      # @param version [String] the version channel ('production', 'beta', etc.)
      # @return [void]
      #
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
          requested_file_ext = requested_file =~ /\.lic$/ ? ".lic" : "bad extension"
        when "library"
          location = LIB_DIR
          case version
          when "production"
            remote_repo = "https://raw.githubusercontent.com/#{GITHUB_REPO}/#{resolve_channel_ref(:stable)}/lib"
          when "beta"
            ref = resolve_channel_ref(:beta)
            if ref.nil?
              respond 'No viable beta found. Aborting beta update.'
              return
            end
            remote_repo = "https://raw.githubusercontent.com/#{GITHUB_REPO}/#{ref}/lib"
          end
          requested_file_ext = requested_file =~ /\.rb$/ ? ".rb" : "bad extension"
        when "data"
          location = DATA_DIR
          remote_repo = "https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts"
          requested_file_ext = requested_file =~ /(\.(?:xml|ui))$/ ? $1&.dup : "bad extension"
        end

        unless requested_file_ext == "bad extension"
          file_path = File.join(location, requested_file)
          tmp_file_path = file_path + ".tmp"
          old_file_path = file_path + ".old"

          # Rename existing file to .old if it exists
          File.rename(file_path, old_file_path) if File.exist?(file_path)

          begin
            # Download to .tmp file first
            File.open(tmp_file_path, "wb") do |file|
              file.write URI.parse(File.join(remote_repo, requested_file)).open.read
            end

            # If successful, move .tmp to final location
            File.rename(tmp_file_path, file_path)

            # Clean up .old file if everything succeeded
            File.delete(old_file_path) if File.exist?(old_file_path)

            respond
            respond "#{requested_file} has been updated."
          rescue StandardError => e
            # Log the actual error for debugging
            respond
            respond "Error updating #{requested_file}: #{e.class} - #{e.message}"
            respond "Backtrace: #{e.backtrace.first(3).join(' | ')}" if $debug

            # Clean up the .tmp file if it exists
            if File.exist?(tmp_file_path)
              begin
                File.delete(tmp_file_path)
                respond "Cleaned up incomplete temporary file."
              rescue => cleanup_error
                respond "Warning: Could not delete temporary file: #{cleanup_error.message}"
              end
            end

            # Restore the .old file if it exists
            if File.exist?(old_file_path)
              begin
                File.rename(old_file_path, file_path)
                respond "Restored original file."
              rescue => restore_error
                respond "Warning: Could not restore original file: #{restore_error.message}"
              end
            end

            respond
            respond "The filename #{requested_file} is not available via lich5-update."
            respond "Check the spelling of your requested file, or use '#{$clean_lich_char}jinx' to"
            respond "download #{requested_file} from another repository."
          end
        else
          respond
          respond "The requested file #{requested_file} has an incorrect extension."
          respond "Valid extensions are '.lic' for scripts, '.rb' for library files,"
          respond "and '.xml' or '.ui' for data files. Please correct and try again."
        end
      end

      #
      # Update core data files and scripts to match the Lich version
      #
      # @param version [String] the Lich version to update to
      # @return [void]
      #
      def self.update_core_data_and_scripts(version = LICH_VERSION)
        if XMLData.game !~ /^GS|^DR/
          respond "invalid game type, unsure what scripts to update via Update.update_core_scripts"
          return
        end

        updatable_scripts = {
          "all" => ["alias.lic", "autostart.lic", "go2.lic", "jinx.lic", "log.lic",
                    "logxml.lic", "map.lic", "repository.lic", "vars.lic", "version.lic"],
          "gs"  => ["ewaggle.lic", "foreach.lic"],
          "dr"  => ["dependency.lic"]
        }

        # We DO care about local edits from players to the Lich5 / data files
        # specifically gameobj-data.xml and spell-list.xml.
        # Let's be a little more purposeful and gentle with these two files.
        ["effect-list.xml"].each do |file|
          transition_filename = "#{file}".sub(".xml", '')
          newfilename = File.join(DATA_DIR, "#{transition_filename}-#{Time.now.to_i}.xml")
          if File.exist?(File.join(DATA_DIR, file))
            File.open(File.join(DATA_DIR, file), 'rb') { |r| File.open(newfilename, 'wb') { |w| w.write(r.read) } }
            respond "The prior version of #{file} was renamed to #{newfilename}."
          end
          update_file('data', file)
        end

        # We do not care about local edits from players to the Lich5 / script location
        # for CORE scripts (those required to run Lich5 properly)
        updatable_scripts["all"].each { |script| update_file('script', script) }
        updatable_scripts["gs"].each { |script| update_file('script', script) } if XMLData.game =~ /^GS/
        updatable_scripts["dr"].each { |script| update_file('script', script) } if XMLData.game =~ /^DR/

        # Update Lich.db value with last updated version
        Lich.core_updated_with_lich_version = version
      end
      # End module definitions
    end
  end
end
