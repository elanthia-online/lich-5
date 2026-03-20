# Let's have fun updating Lich5!

module Lich
  module Util
    module Update
      require 'digest'
      require 'json'
      require 'net/http'
      require 'open-uri'
      require 'rubygems/package'
      require 'zlib'

      # Update channel constants
      STABLE_REF = 'main'
      BETA_BRANCH_PREFIX = 'pre/beta' # fallback branch prefix for beta
      ASSET_TARBALL_NAME = 'lich-5.tar.gz'
      GITHUB_REPO = 'elanthia-online/lich-5'

      # Script repository registry -- defines which repos to sync and how
      SCRIPT_REPOS = {
        'dr-scripts' => {
          display_name: 'DR Scripts',
          api_url: 'https://api.github.com/repos/elanthia-online/dr-scripts/git/trees/main?recursive=1',
          raw_base_url: 'https://raw.githubusercontent.com/elanthia-online/dr-scripts/main',
          tracking_mode: :all,
          script_pattern: /^[^\/]+\.lic$/,
          game_filter: /^DR/,
          subdirs: {
            'profiles' => { pattern: /^profiles\/base(?:-empty)?\.yaml$/, dest: File.join(SCRIPT_DIR, 'profiles') },
            'data'     => { pattern: /^data\/base.+yaml$/, dest: File.join(SCRIPT_DIR, 'data') }
          }
        }.freeze,
        'scripts'    => {
          display_name: 'GS Scripts',
          api_url: 'https://api.github.com/repos/elanthia-online/scripts/git/trees/master?recursive=1',
          raw_base_url: 'https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts',
          tracking_mode: :explicit,
          script_pattern: /^scripts\/[^\/]+\.lic$/,
          game_filter: nil,
          default_tracked: %w[
            alias.lic autostart.lic ewaggle.lic go2.lic jinx.lic
            lich5-update.lic log.lic map.lic repository.lic vars.lic version.lic
          ].freeze,
          subdirs: {}
        }.freeze
      }.freeze

      # Simple in-memory cache for GitHub API responses
      @_http_cache = {}
      @_http_cache_ttl = 60 # seconds

      # GitHub personal access token (loaded lazily)
      @_github_token = nil
      @_github_token_loaded = false

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
        when /^--status\b/
          show_status
        when /^(?:--update|-u)\b/
          download_release_update
        when /^--refresh\b/
          respond
          respond "This command has been removed."
        when /^(?:--revert|-r)\b/
          revert
        when /^--sync(?:=(\S+))?$/
          if $1
            sync_repo($1)
          else
            sync_all_repos
          end
        when /^--track=(\S+):(\S+)$/
          track_script($1, $2)
        when /^--untrack=(\S+):(\S+)$/
          untrack_script($1, $2)
        when /^--tracked(?:=(\S+))?$/
          show_tracked($1)
        when /^--(?:(script|library|data))=(?:(\S+):)?(.+)\b/
          type_name = $1&.dup
          repo = $2&.dup
          file = $3&.dup
          if repo
            update_file_from_repo(type_name, repo, file)
          else
            update_file(type_name, file)
          end
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
      # Display current version and branch status information
      #
      # @return [void]
      #
      def self.show_status
        respond
        respond "Lich5 Version Information:"
        respond "  Version: #{LICH_VERSION}"

        branch_info = get_branch_info
        if branch_info
          respond "  Type: Branch (Development)"
          respond "  Branch: #{branch_info[:branch_name]}"
          respond "  Repository: #{branch_info[:repository] || GITHUB_REPO}"
          if branch_info[:updated_at]
            updated = Time.at(branch_info[:updated_at])
            days_ago = ((Time.now - updated) / 86400).to_i
            respond "  Updated: #{updated.strftime('%Y-%m-%d %H:%M:%S')} (#{days_ago} day#{days_ago == 1 ? '' : 's'} ago)"
          end
          respond
          respond "You are running a development branch, not a release package."
        else
          respond "  Type: Release Package"
          respond
          respond "To check for updates: #{$clean_lich_char}lich5-update --announce"
        end
        respond
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
    --status                 Show current version and branch tracking info
    --snapshot               Grab current snapshot of Lich5 ecosystem and put in backup
    --revert                 Roll the Lich5 ecosystem back to the most recent snapshot

  [Script repository sync]
    #{$clean_lich_char}lich5-update --sync                              Sync all repos for current game
    #{$clean_lich_char}lich5-update --sync=dr-scripts                   Sync only dr-scripts repo
    #{$clean_lich_char}lich5-update --sync=scripts                      Sync only EO/scripts repo
    #{$clean_lich_char}lich5-update --tracked                           List tracked scripts for all repos
    #{$clean_lich_char}lich5-update --tracked=scripts                   List tracked scripts for one repo
    #{$clean_lich_char}lich5-update --track=scripts:bigshot.lic         Add a script to tracked list
    #{$clean_lich_char}lich5-update --untrack=scripts:bigshot.lic       Remove from tracked list

  [Individual file updates]
    #{$clean_lich_char}lich5-update --script=<name>                     Update script (auto-detects repo)
    #{$clean_lich_char}lich5-update --script=dr-scripts:<name>          Update script from specific repo
    #{$clean_lich_char}lich5-update --data=dr-scripts:base-hunting.yaml Update data file from specific repo
    #{$clean_lich_char}lich5-update --library=<name>                    Update library file from lich-5

  [One time suggestions]
    #{$clean_lich_char}autostart add --global lich5-update --announce    Check for new version at login
    #{$clean_lich_char}autostart add --global lich5-update --sync        Sync script repos at login (GS)

  [On demand suggestions]
    #{$clean_lich_char}lich5-update --status                    Show current version and branch info
    #{$clean_lich_char}lich5-update --announce                  Check to see if a new version is available
    #{$clean_lich_char}lich5-update --update                    Update the Lich5 ecosystem to the current release
    #{$clean_lich_char}lich5-update --branch=<name>             Update to a specific GitHub branch (advanced)
    #{$clean_lich_char}lich5-update --revert                    Roll the Lich5 ecosystem back to latest snapshot

  [Branch update examples]
    #{$clean_lich_char}lich5-update --branch=main               Update to the main stable branch
    #{$clean_lich_char}lich5-update --branch=some_branch_name   Update to a different branch
    #{$clean_lich_char}lich5-update --branch=owner:branch_name  Update to a fork's branch

    *NOTE* DR users: script repos sync automatically on login.
           GS users: add --sync to autostart for automatic sync.
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
          raw = http_get(url)
          return nil unless raw

          data = JSON.parse(raw)
          @_http_cache[url] = { ts: now, data: data }
          data
        rescue => e
          respond "Update notice: network error fetching #{url.split('/repos/').last || url} (fetch_github_json): #{e.message}"
          nil
        end
      end

      #
      # Perform an HTTP GET request using Net::HTTP
      #
      # @param url [String] the URL to fetch
      # @param auth [Boolean] whether to include GitHub token if available
      # @return [String, nil] response body or nil on error
      #
      def self.http_get(url, auth: true)
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER

        request = Net::HTTP::Get.new(uri.request_uri)
        if auth
          token = github_token
          request['Authorization'] = token if token
        end

        response = http.request(request)
        unless response.code == '200'
          respond "[lich5-update: HTTP #{response.code} fetching #{uri.path}]"
          return nil
        end
        response.body
      rescue => e
        respond "[lich5-update: Network error: #{e.message}]"
        nil
      end

      #
      # Load GitHub personal access token from data directory
      #
      # @return [String, nil] the authorization header value or nil
      #
      def self.github_token
        return @_github_token if @_github_token_loaded

        @_github_token_loaded = true
        token_path = File.join(DATA_DIR, 'githubtoken.txt')
        return nil unless File.exist?(token_path)

        token = File.read(token_path).strip
        if token.empty?
          respond "[lich5-update: GitHub token file is empty. Using unauthenticated access.]"
          return nil
        end

        @_github_token = "Bearer #{token}"
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
      # Extract version from a version.rb file
      #
      # @param version_file_path [String] path to the version.rb file
      # @return [String, nil] the extracted version string or nil if not found
      #
      def self.extract_version_from_file(version_file_path)
        return nil unless File.exist?(version_file_path)

        version_file_content = File.read(version_file_path)
        if version_file_content =~ /LICH_VERSION\s*=\s*['"]([^'"]+)['"]/
          return $1
        end
        nil
      end

      #
      # Download and install a specific branch from GitHub
      #
      # @param branch_spec [String] the branch specification - either "branch_name" or "owner:branch_name"
      # @return [void]
      #
      def self.download_branch_update(branch_spec)
        branch_spec = branch_spec.strip
        if branch_spec.empty?
          respond
          respond "Error: Branch specification cannot be empty."
          respond "Usage: #{$clean_lich_char}lich5-update --branch=<branch_name>"
          respond "   Or: #{$clean_lich_char}lich5-update --branch=<owner>:<branch_name>"
          respond
          return
        end

        # Parse owner:branch or just branch format
        if branch_spec.include?(':')
          owner, branch_name = branch_spec.split(':', 2)
          repo = "#{owner}/lich-5"
        else
          owner = nil
          branch_name = branch_spec
          repo = GITHUB_REPO
        end

        # Check if already on this branch
        current_branch = get_branch_info
        if current_branch &&
           current_branch[:branch_name] == branch_name &&
           (current_branch[:repository] || GITHUB_REPO) == repo
          respond
          respond "Already on branch '#{branch_name}' from '#{repo}'."
          respond "Scripts and data are up to date (verified by checksums)."
          applicable = SCRIPT_REPOS.select { |_, c| c[:game_filter].nil? || XMLData.game =~ c[:game_filter] }
          names = applicable.values.map { |c| c[:display_name] }.compact.join(', ')
          respond "To re-sync scripts (#{names}): #{$clean_lich_char}lich5-update --sync"
          respond
          return
        end

        respond
        respond "Attempting to update to branch: #{branch_name}"
        respond "Repository: #{repo}" if owner
        respond "This will download from GitHub and extract over your current installation."
        respond

        # Create snapshot before attempting update
        snapshot

        # Construct the GitHub tar.gz download URL
        # URL-encode only special characters that would break the URL
        # Don't encode '/' since it's part of the path structure GitHub expects
        require 'erb'
        encoded_branch_name = ERB::Util.url_encode(branch_name)
        tarball_url = "https://github.com/#{repo}/archive/refs/heads/#{encoded_branch_name}.tar.gz"

        # GitHub creates directory name as: repo-name + '-' + branch-name-with-slashes-replaced
        # Example: lich-5-fix-update.rb-allow-bugfix-betas-and-branch-updates
        # Note: The directory name uses the ORIGINAL branch name with only / replaced by -
        repo.split('/').last # Get 'lich-5' from 'owner/lich-5'
        sanitized_branch = branch_name.gsub('/', '-')

        # Use a simpler filename for our temporary storage (also sanitize for filesystem)
        filename = "lich5-branch-#{sanitized_branch}"

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

          # Extract the actual version from the downloaded branch's version.rb file
          version_file_path = File.join(source_dir, "lib", "version.rb")
          extracted_version = extract_version_from_file(version_file_path)

          if extracted_version.nil?
            respond
            respond "Warning: Could not extract version from branch's version.rb file."
            respond "Using existing Lich version identifier: #{LICH_VERSION}"
            extracted_version = LICH_VERSION
          else
            respond
            respond "Detected version from branch: #{extracted_version}"
          end

          # Perform the update with the extracted version
          perform_update(source_dir, extracted_version)

          # Store branch tracking in version.rb
          store_branch_tracking(branch_name, repo, extracted_version)

          # Clean up
          FileUtils.remove_dir(extract_dir) if File.directory?(extract_dir)
          FileUtils.rm(tarball_path) if File.exist?(tarball_path)

          respond
          respond "Successfully updated to branch: #{branch_name} (version #{extracted_version})"
          respond "Branch tracking: This installation is now tracking branch '#{branch_name}'"
          respond "                 from repository '#{repo}'" if owner
          respond "You should exit the game, then log back in to use the updated version."
          respond
          respond "To check your current branch status, run: #{$clean_lich_char}lich5-update --status"
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
        if Gem::Version.new("#{@update_to}") <= Gem::Version.new("#{@current}") && !defined?(LICH_BRANCH)
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

          # Clear branch tracking - we're back on stable
          clear_branch_tracking

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

          # Clear branch tracking - we've reverted
          clear_branch_tracking

          respond
          respond "Lich5 has been reverted to Lich5 version #{targetversion}"
          respond "You should exit the game, then log back in.  This will start the game"
          respond "with your previous version of Lich.  Enjoy!"
        end
      end

      #
      # Update a specific file from a named repository (repo:filename syntax)
      #
      # @param type [String] the file type ('script' or 'data')
      # @param repo_key [String] the repository key (e.g. 'dr-scripts', 'scripts')
      # @param filename [String] the filename to download
      # @return [void]
      #
      def self.update_file_from_repo(type, repo_key, filename)
        config = SCRIPT_REPOS[repo_key]
        unless config
          respond "[lich5-update: Unknown repository '#{repo_key}'. Known: #{SCRIPT_REPOS.keys.join(', ')}]"
          return
        end

        case type
        when "script"
          location = SCRIPT_DIR
        when "data"
          # For data files, use the 'data' subdirectory config
          data_subdir = (config[:subdirs] || {})['data']
          location = data_subdir ? data_subdir[:dest] : File.join(SCRIPT_DIR, 'data')
          FileUtils.mkdir_p(location)
        else
          respond "[lich5-update: repo:filename syntax is only supported for --script= and --data=.]"
          return
        end

        # Check SHA against remote tree before downloading
        raw_path = type == "data" ? "data/#{filename}" : filename
        tree_data = fetch_github_json(config[:api_url])
        if tree_data && tree_data['tree']
          remote_entry = tree_data['tree'].find { |e| e['path'] == raw_path }
          if remote_entry
            local_path = File.join(location, filename)
            if File.exist?(local_path)
              local_sha = Digest::SHA1.hexdigest("blob #{File.binread(local_path).bytesize}\0#{File.binread(local_path)}")
              if local_sha == remote_entry['sha']
                respond_mono("[lich5-update: #{filename} is already up to date.]")
                return
              end
            end
          else
            name = config[:display_name] || repo_key
            respond_mono("[lich5-update: #{filename} not found in #{name} repository.]")
            return
          end
        end

        name = config[:display_name] || repo_key
        url = "#{config[:raw_base_url]}/#{raw_path}"
        content = http_get(url, auth: false)
        if content
          safe_write(File.join(location, filename), content)
          respond_mono("[lich5-update: #{filename} has been updated from #{name}.]")
        else
          respond_mono("[lich5-update: Failed to download #{filename} from #{name}.]")
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

        # Use SHA-based sync for core scripts -- only downloads files that actually changed
        sync_all_repos

        # Update Lich.db value with last updated version
        Lich.core_updated_with_lich_version = version
      end

      #
      # Store branch tracking information in version.rb
      #
      # @param branch_name [String] the branch name
      # @param repo [String] the repository (owner/repo-name)
      # @param version [String] the version from the branch
      # @return [void]
      #
      def self.store_branch_tracking(branch_name, repo, _version)
        version_file_path = File.join(LIB_DIR, "version.rb")
        version_content = File.read(version_file_path)

        # Remove any existing branch tracking section
        version_content.gsub!(/\n# Branch tracking \(added by lich5-update --branch\).*?\n(?:LICH_BRANCH[^\n]*\n)*/m, '')

        # Build branch tracking section
        branch_tracking = <<~RUBY

          # Branch tracking (added by lich5-update --branch)
          LICH_BRANCH = '#{branch_name}'
          LICH_BRANCH_REPO = '#{repo}'
          LICH_BRANCH_UPDATED_AT = #{Time.now.to_i}
        RUBY

        # Append to end of file (after stripping trailing whitespace)
        version_content = version_content.rstrip + branch_tracking

        File.write(version_file_path, version_content)
      end

      #
      # Clear branch tracking information from version.rb
      #
      # @return [void]
      #
      def self.clear_branch_tracking
        version_file_path = File.join(LIB_DIR, "version.rb")
        return unless File.exist?(version_file_path)

        version_content = File.read(version_file_path)

        # Remove branch tracking section
        version_content.gsub!(/\n# Branch tracking \(added by lich5-update --branch\).*?\n(?:LICH_BRANCH[^\n]*\n)*/m, '')

        # Clean up trailing whitespace
        version_content = version_content.rstrip + "\n"

        File.write(version_file_path, version_content)
      end

      #
      # Get branch tracking information (if present)
      #
      # @return [Hash, nil] hash with branch info or nil if not on a branch
      #
      def self.get_branch_info
        # Check if constants are defined
        if defined?(LICH_BRANCH) && LICH_BRANCH && !LICH_BRANCH.empty?
          {
            branch_name: LICH_BRANCH,
            repository: (defined?(LICH_BRANCH_REPO) ? LICH_BRANCH_REPO : nil),
            updated_at: (defined?(LICH_BRANCH_UPDATED_AT) ? LICH_BRANCH_UPDATED_AT : nil)
          }
        else
          nil
        end
      end

      # ---------------------------------------------------------------
      # Script Repository Sync
      # ---------------------------------------------------------------
      #
      # SHA-based bulk synchronization for script repositories.
      # Replaces dependency.lic's ScriptManager download infrastructure.
      #

      #
      # Sync all registered repositories applicable to the current game
      #
      # @return [void]
      #
      def self.sync_all_repos
        SCRIPT_REPOS.each_key { |repo_key| sync_repo(repo_key) }
      end

      #
      # Sync a single repository -- downloads only files whose SHA differs from local
      #
      # @param repo_key [String] key into SCRIPT_REPOS
      # @param force [Boolean] download all files regardless of SHA match
      # @return [void]
      #
      def self.sync_repo(repo_key, force: false)
        config = SCRIPT_REPOS[repo_key]
        unless config
          respond "[lich5-update: Unknown repository '#{repo_key}'. Known: #{SCRIPT_REPOS.keys.join(', ')}]"
          return
        end

        if config[:game_filter] && XMLData.game !~ config[:game_filter]
          return
        end

        tree_data = fetch_github_json(config[:api_url])
        unless tree_data && tree_data['tree']
          respond "[lich5-update: Failed to fetch tree for #{repo_key}.]"
          return
        end
        tree = tree_data['tree']

        # Sync scripts
        name = config[:display_name] || repo_key
        syncable = filter_syncable_scripts(tree, config)
        respond_mono("[lich5-update: Syncing #{name} (#{syncable.length} scripts)...]")

        local_shas = build_local_sha_map(SCRIPT_DIR)
        downloaded_scripts = []
        syncable.each do |entry|
          filename = File.basename(entry['path'])
          next if !force && local_shas[filename] == entry['sha']

          content = http_get("#{config[:raw_base_url]}/#{entry['path']}", auth: false)
          next unless content

          safe_write(File.join(SCRIPT_DIR, filename), content)
          downloaded_scripts << filename
        end

        # Sync subdirectories (profiles, data)
        downloaded_other = {}
        (config[:subdirs] || {}).each do |subdir_name, subconfig|
          files = sync_subdir(tree, config, subdir_name, subconfig)
          downloaded_other[subdir_name] = files unless files.empty?
        end

        # Render sync summary
        render_sync_summary(name, syncable.length, downloaded_scripts, downloaded_other, config[:subdirs]&.keys || [])
      end

      #
      # Sync a subdirectory (e.g. profiles/, data/) from a repository
      #
      # @param tree [Array<Hash>] the full repository tree
      # @param config [Hash] the repository config
      # @param subdir_name [String] human-readable name for messaging
      # @param subconfig [Hash] with :pattern (Regexp) and :dest (String path)
      # @return [Array<String>] list of downloaded filenames
      #
      def self.sync_subdir(tree, config, _subdir_name, subconfig)
        pattern = subconfig[:pattern]
        dest = subconfig[:dest]
        return [] unless pattern && dest

        FileUtils.mkdir_p(dest)
        entries = tree.select { |e| e['path'] =~ pattern && e['type'] == 'blob' }
        return [] if entries.empty?

        local_shas = build_local_sha_map(dest, '*.yaml')
        downloaded = []
        entries.each do |entry|
          filename = File.basename(entry['path'])
          next if local_shas[filename] == entry['sha']

          content = http_get("#{config[:raw_base_url]}/#{entry['path']}", auth: false)
          next unless content

          safe_write(File.join(dest, filename), content)
          downloaded << filename
        end
        downloaded
      end

      #
      # Filter tree entries to only syncable scripts based on repo config
      #
      # @param tree [Array<Hash>] the repository tree
      # @param config [Hash] the repository config
      # @return [Array<Hash>] filtered tree entries
      #
      def self.filter_syncable_scripts(tree, config)
        candidates = tree.select { |e| e['path'] =~ config[:script_pattern] && e['type'] == 'blob' }

        case config[:tracking_mode]
        when :all
          candidates.reject { |e| File.basename(e['path']).include?('-setup') }
        when :explicit
          tracked = tracked_scripts(config)
          candidates.select { |e| tracked.include?(File.basename(e['path'])) }
        else
          candidates
        end
      end

      #
      # Build a map of filename -> git blob SHA for local files
      #
      # @param dir [String] directory to scan
      # @param pattern [String] glob pattern for files
      # @return [Hash<String, String>] filename -> SHA map
      #
      def self.build_local_sha_map(dir, pattern = '*.lic')
        Dir[File.join(dir, pattern)].each_with_object({}) do |path, map|
          body = File.binread(path)
          map[File.basename(path)] = Digest::SHA1.hexdigest("blob #{body.size}\0#{body}")
        end
      end

      #
      # Write file atomically with rollback support
      #
      # @param path [String] destination file path
      # @param content [String] file content to write
      # @return [void]
      #
      def self.safe_write(path, content)
        tmp = "#{path}.tmp"
        old = "#{path}.old"
        File.rename(path, old) if File.exist?(path)
        begin
          File.binwrite(tmp, content)
          File.rename(tmp, path)
          File.delete(old) if File.exist?(old)
        rescue StandardError
          File.rename(old, path) if File.exist?(old)
          File.delete(tmp) if File.exist?(tmp)
          raise
        end
      end

      #
      # Get the list of tracked scripts for a repository
      #
      # @param config [Hash] the repository config
      # @return [Array<String>] list of tracked script filenames
      #
      def self.tracked_scripts(config)
        defaults = config[:default_tracked] || []
        repo_key = SCRIPT_REPOS.key(config)
        user_additions = UserVars.tracked_scripts&.dig(repo_key) || [] rescue []
        (defaults + user_additions).uniq
      end

      #
      # Add a script to the user's tracked list for a repository
      #
      # @param repo_key [String] repository key
      # @param script_name [String] script filename (e.g. 'foo.lic')
      # @return [void]
      #
      def self.track_script(repo_key, script_name)
        config = SCRIPT_REPOS[repo_key]
        unless config
          respond "[lich5-update: Unknown repository '#{repo_key}'.]"
          return
        end
        UserVars.tracked_scripts ||= {}
        UserVars.tracked_scripts[repo_key] ||= []
        name = config[:display_name] || repo_key
        if UserVars.tracked_scripts[repo_key].include?(script_name)
          respond_mono("[lich5-update: '#{script_name}' is already tracked in #{name}.]")
        else
          UserVars.tracked_scripts[repo_key].push(script_name)
          respond_mono("[lich5-update: Added '#{script_name}' to #{name} tracked list.]")
        end
      end

      #
      # Remove a script from the user's tracked list (cannot remove defaults)
      #
      # @param repo_key [String] repository key
      # @param script_name [String] script filename
      # @return [void]
      #
      def self.untrack_script(repo_key, script_name)
        config = SCRIPT_REPOS[repo_key]
        unless config
          respond "[lich5-update: Unknown repository '#{repo_key}'.]"
          return
        end
        name = config[:display_name] || repo_key
        if (config[:default_tracked] || []).include?(script_name)
          respond_mono("[lich5-update: '#{script_name}' is a default script and cannot be removed.]")
          return
        end
        if UserVars.tracked_scripts&.dig(repo_key)&.delete(script_name)
          respond_mono("[lich5-update: Removed '#{script_name}' from #{name} tracked list.]")
        else
          respond_mono("[lich5-update: '#{script_name}' was not in your #{name} tracked list.]")
        end
      end

      #
      # Display tracked scripts for a repository (or all repositories)
      #
      # @param repo_key [String, nil] specific repo or nil for all
      # @return [void]
      #
      def self.show_tracked(repo_key = nil)
        repos = repo_key ? { repo_key => SCRIPT_REPOS[repo_key] } : SCRIPT_REPOS
        table_rows = []

        repos.each do |key, config|
          unless config
            respond "[lich5-update: Unknown repository '#{key}'.]"
            next
          end

          name = config[:display_name] || key
          table_rows << :separator unless table_rows.empty?
          table_rows << [{ value: "#{name} (#{key})", colspan: 3, alignment: :center }]
          table_rows << :separator

          if config[:tracking_mode] == :all
            table_rows << [{ value: "All .lic files synced automatically", colspan: 3 }]
          else
            table_rows << ['Script', 'Type', 'Status']
            table_rows << :separator
            scripts = tracked_scripts(config)
            defaults = config[:default_tracked] || []
            scripts.sort.each do |s|
              type = defaults.include?(s) ? 'default' : 'user-added'
              exists = File.exist?(File.join(SCRIPT_DIR, s))
              status = exists ? 'installed' : 'not installed'
              table_rows << [s, type, status]
            end
          end
        end

        table = Terminal::Table.new(rows: table_rows, title: 'Tracked Scripts')
        respond_mono(table.to_s)
      end

      #
      # Render a sync summary table
      #
      # @param repo_name [String] display name of the repository
      # @param script_count [Integer] total scripts checked
      # @param downloaded_scripts [Array<String>] scripts that were downloaded
      # @param downloaded_other [Hash<String, Array<String>>] subdir => filenames downloaded
      # @param subdir_names [Array<String>] all subdir names (for "up to date" reporting)
      # @return [void]
      #
      def self.render_sync_summary(repo_name, script_count, downloaded_scripts, downloaded_other, subdir_names)
        total_downloaded = downloaded_scripts.length + downloaded_other.values.flatten.length

        if total_downloaded == 0
          table = Terminal::Table.new(
            title: "#{repo_name} Sync",
            rows: [
              ['Scripts', "#{script_count} checked, all up to date"],
              *subdir_names.map { |s| [s.capitalize, 'up to date'] }
            ]
          )
          respond_mono(table.to_s)
          return
        end

        table_rows = []
        table_rows << ['Category', 'File', 'Status']
        table_rows << :separator

        downloaded_scripts.each do |f|
          table_rows << ['script', f, 'downloaded']
        end

        downloaded_other.each do |subdir, files|
          files.each do |f|
            table_rows << [subdir, f, 'downloaded']
          end
        end

        subdir_names.each do |s|
          next if downloaded_other.key?(s)

          table_rows << [s, '--', 'up to date']
        end

        if downloaded_scripts.empty?
          table_rows << ['scripts', '--', "#{script_count} checked, all up to date"]
        end

        table_rows << :separator
        table_rows << [{ value: "Total: #{total_downloaded} file#{total_downloaded == 1 ? '' : 's'} updated", colspan: 3 }]

        table = Terminal::Table.new(title: "#{repo_name} Sync", rows: table_rows)
        respond_mono(table.to_s)
      end

      #
      # Output text in monospace format for all frontends
      #
      # @param text [String] the text to display
      # @return [void]
      #
      def self.respond_mono(text)
        if defined?(Lich::Messaging) && Lich::Messaging.respond_to?(:mono)
          Lich::Messaging.mono(text)
        else
          respond text
        end
      end

      # End module definitions
    end
  end
end
