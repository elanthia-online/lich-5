# frozen_string_literal: true

=begin
  Installs Lich5 from GitHub releases (stable and beta).

  Handles release announcements, tarball downloads, Ruby compatibility
  checks, and file extraction. Delegates to FileUpdater for data/script
  updates and SnapshotManager for backups.
=end

module Lich
  module Util
    module Update
      class ReleaseInstaller
        # Top-level files (besides lib/ and lich.rbw) copied verbatim from the
        # release/branch archive into LICH_DIR during a self-update. lich.rbw is
        # handled separately due to its dynamic target name.
        #
        # Gemfile.lock travels alongside Gemfile so the resolved dependency set
        # on disk stays consistent with the Gemfile after an update. Shipping a
        # new Gemfile without its lock would leave a stale lock that a later
        # `bundle install` (or any Bundler invocation) has to re-resolve.
        # Entries absent from the archive are skipped (see #copy_top_level_files).
        TOP_LEVEL_FILES = %w[Gemfile Gemfile.lock LICENSE].freeze

        # Archive entries that must exist for an extracted download to count as a
        # structurally valid Lich installation. Deliberately distinct from
        # TOP_LEVEL_FILES so that optional payload (e.g. Gemfile.lock, which older
        # release tarballs may omit) never gates an update.
        REQUIRED_ARCHIVE_ITEMS = %w[lib lich.rbw Gemfile LICENSE].freeze
        REQUIRED_RUBY_PATTERN = /REQUIRED_RUBY\s*=\s*["']([^"']+)["']/.freeze
        GEMSTONE_INSTALL_URL = 'https://gswiki.play.net/Lich:Software/Installation'.freeze

        # @param client [GitHubClient] GitHub API client instance
        # @param resolver [ChannelResolver] channel resolver instance
        # @param snapshot_manager [SnapshotManager] snapshot manager instance
        def initialize(client, resolver, snapshot_manager)
          @client = client
          @resolver = resolver
          @snapshot_manager = snapshot_manager
          @current = LICH_VERSION
          @update_to = nil
          @holder = nil
          @new_features = nil
          @zipfile = nil
          @release_tag = nil
          @required_ruby = nil
        end

        # Displays announcement if new version available.
        #
        # @return [void]
        def announce
          prep_update
          return unless @update_to

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
                if ruby_upgrade_required?
                  respond "Lich version #{@update_to} requires Ruby #{@required_ruby} or higher."
                  respond "Your current Ruby version is #{RUBY_VERSION}."
                  respond "Upgrade Ruby before updating Lich: #{GEMSTONE_INSTALL_URL}"
                else
                  respond "If you are interested in updating, run '#{$clean_lich_char}lich5-update --update' now."
                end
                respond ''
              end
            else
              respond ''
              respond "Lich version #{LICH_VERSION} is good.  Enjoy!"
              respond ''
            end
          else
            respond "This script does not support Lich #{LICH_VERSION}."
          end
        end

        # Fetches latest stable release metadata from GitHub.
        #
        # @return [void]
        def prep_update
          latest = @client.fetch_github_json("https://api.github.com/repos/#{GITHUB_REPO}/releases/latest")
          if latest.is_a?(Hash) && latest['prerelease']
            all = @client.fetch_github_json("https://api.github.com/repos/#{GITHUB_REPO}/releases")
            if all.is_a?(Array)
              stable = all.select { |r| !r['prerelease'] && r['tag_name'] }.max_by { |r| @resolver.version_key(r['tag_name']) }
              latest = stable if stable
            end
          end
          unless latest.is_a?(Hash)
            respond "Update notice: could not read latest release payload (prep_update)."
            return
          end

          @holder = latest['assets']
          release_asset = @holder && @holder.find { |x| x['name'] =~ /\b#{ASSET_TARBALL_NAME}\b/ }
          unless release_asset
            respond "Update notice: no release tarball found in assets (prep_update)."
            return
          end
          @release_tag = latest['tag_name'].to_s
          @update_to = @release_tag.sub(/^v/, '')
          @new_features = latest['body'].to_s.gsub(/\#\# What's Changed.+$/m, '').gsub(/<!--[\s\S]*?-->/, '')
          @zipfile = release_asset.fetch('browser_download_url')
        end

        # Reads the target release's Ruby floor without downloading its archive.
        # A failed metadata read must not suppress an otherwise valid update notice.
        #
        # @return [Boolean] true when the running Ruby is too old for the release
        def ruby_upgrade_required?
          return false if @release_tag.nil? || @release_tag.empty?

          version_url = "https://raw.githubusercontent.com/#{GITHUB_REPO}/#{@release_tag}/lib/version.rb"
          version_content = @client.http_get(version_url, auth: false)
          match = version_content&.match(REQUIRED_RUBY_PATTERN)
          return false unless match

          @required_ruby = match[1]
          Gem::Version.new(RUBY_VERSION) < Gem::Version.new(@required_ruby)
        rescue ArgumentError
          false
        end

        # Handles beta update requests (full install or individual file).
        #
        # @param type [String, nil] file type ('script', 'library', 'data') or nil for full beta
        # @param requested_file [String, nil] file name if type is set
        # @return [void]
        def prep_betatest(type = nil, requested_file = nil)
          if type.nil?
            respond 'You are electing to participate in the beta testing of the next Lich release.'
            respond 'This beta test will include only Lich code, and does not include Ruby upates.'
            respond 'While we will do everything we can to ensure you have a smooth experience, '
            respond 'it is a test, and untoward things can result.  Please confirm your choice:'
            respond "Please confirm your participation:  #{$clean_lich_char}send Y or #{$clean_lich_char}send N"
            respond "You have 10 seconds to confirm, otherwise will be cancelled."

            client_sock = $_CLIENT_ || $_DETACHABLE_CLIENT_
            unless client_sock
              respond 'No client connection available. Aborting beta test request.'
              return
            end
            deadline = Time.now + 10
            line = nil
            loop do
              remaining = deadline - Time.now
              break if remaining <= 0

              reader = Thread.new { client_sock.gets }
              if reader.join(remaining)
                line = reader.value
                break if line.is_a?(String) && line.strip =~ /^(?:<c>)?(?:#{$clean_lich_char}send|#{$clean_lich_char}s) /i
              else
                reader.kill
                break
              end
            end

            if line.is_a?(String) && line =~ /send Y|s Y/i
              beta_response = 'accepted'
              respond 'Beta test installation accepted.  Thank you for considering!'
            else
              beta_response = 'rejected'
              respond 'Aborting beta test installation request.  Thank you for considering!'
              respond
            end

            if beta_response =~ /accepted/
              ref = @resolver.resolve_channel_ref(:beta)
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
            elsif beta_response =~ /rejected/
              nil
            else
              respond 'This is not where I want to be on a beta test request.'
              respond
            end
          else
            file_updater = FileUpdater.new(@client, @resolver)
            file_updater.update_file(type, requested_file, 'beta')
          end
        end

        # Downloads and installs latest stable release.
        #
        # @return [void]
        def download_release_update
          prep_update if @update_to.nil? || @update_to.empty?
          if Gem::Version.new("#{@update_to}") <= Gem::Version.new("#{@current}") && !defined?(LICH_BRANCH)
            respond ''
            respond "Lich version #{LICH_VERSION} is good.  Enjoy!"
            respond ''
          else
            respond
            respond 'Getting ready to update.  First we will create a'
            respond 'snapshot in case there are problems with the update.'

            @snapshot_manager.snapshot

            respond
            respond "Downloading Lich5 version #{@update_to}"
            respond
            filename = "lich5-#{@update_to}"
            File.open(File.join(TEMP_DIR, "#{filename}.tar.gz"), "wb") do |file|
              file.write URI.parse(@zipfile).open.read
            end

            FileUtils.mkdir_p(File.join(TEMP_DIR, filename))
            Gem::Package.new("").extract_tar_gz(File.open(File.join(TEMP_DIR, "#{filename}.tar.gz"), "rb"),
                                                File.join(TEMP_DIR, filename))
            new_target = Dir.children(File.join(TEMP_DIR, filename))
            FileUtils.cp_r(File.join(TEMP_DIR, filename, new_target[0]), TEMP_DIR)
            FileUtils.remove_dir(File.join(TEMP_DIR, filename))
            FileUtils.mv(File.join(TEMP_DIR, new_target[0]), File.join(TEMP_DIR, filename))

            source_dir = File.join(TEMP_DIR, filename)

            unless check_ruby_compatibility(source_dir, @update_to)
              FileUtils.remove_dir(source_dir) if File.directory?(source_dir)
              FileUtils.rm(File.join(TEMP_DIR, "#{filename}.tar.gz")) if File.exist?(File.join(TEMP_DIR, "#{filename}.tar.gz"))
              return
            end

            unless perform_update(source_dir, @update_to)
              FileUtils.remove_dir(source_dir) if File.directory?(source_dir)
              FileUtils.rm(File.join(TEMP_DIR, "#{filename}.tar.gz")) if File.exist?(File.join(TEMP_DIR, "#{filename}.tar.gz"))
              return
            end

            FileUtils.remove_dir(source_dir)
            FileUtils.rm(File.join(TEMP_DIR, "#{filename}.tar.gz"))

            Lich::Util::Update.clear_branch_tracking

            respond
            respond "Lich5 has been updated to Lich5 version #{@update_to}"
            respond "You should exit the game, then log back in.  This will start the game"
            respond "with your updated Lich.  Enjoy!"
          end
        end

        # Copies lib files and lich.rbw from extracted source to install dirs.
        #
        # @param source_dir [String] extracted tarball directory
        # @param version [String] version string
        # @return [Boolean] true if update succeeded
        def perform_update(source_dir, version)
          unless validate_lich_structure(source_dir)
            respond "Error: extracted source is missing required files. Aborting update to protect installation."
            return false
          end

          FileUtils.rm_rf(Dir.glob(File.join(LIB_DIR, "*")))

          respond
          respond 'Copying updated lich files to their locations.'

          FileUtils.copy_entry(File.join(source_dir, "lib"), File.join(LIB_DIR))
          respond
          respond "All Lich lib files have been updated."
          respond

          copy_top_level_files(source_dir)

          file_updater = FileUpdater.new(@client, @resolver)
          file_updater.update_core_data_and_scripts(version)

          lich_to_update = File.join(LICH_DIR, File.basename($PROGRAM_NAME))
          update_to_lich = File.join(source_dir, "lich.rbw")
          File.open(update_to_lich, 'rb') { |r| File.open(lich_to_update, 'wb') { |w| w.write(r.read) } }
          true
        end

        # Copies each top-level file present in the extracted archive into
        # LICH_DIR. Files missing from the archive are skipped rather than
        # treated as errors, so a partial archive (e.g. one without Gemfile.lock)
        # updates cleanly instead of aborting.
        #
        # @param source_dir [String] extracted tarball directory
        # @return [void]
        def copy_top_level_files(source_dir)
          TOP_LEVEL_FILES.each do |filename|
            src = File.join(source_dir, filename)
            next unless File.exist?(src)

            FileUtils.cp(src, File.join(LICH_DIR, filename))
            respond "Updated #{filename}."
          end
        end

        # Validates the extracted directory contains every archive entry Lich
        # requires to install safely.
        #
        # @param dir [String] directory to check
        # @return [Boolean] true if all required entries are present
        def validate_lich_structure(dir)
          REQUIRED_ARCHIVE_ITEMS.all? { |item| File.exist?(File.join(dir, item)) }
        end

        # Checks if current Ruby meets minimum version requirement.
        #
        # @param source_dir [String] extracted tarball directory
        # @param version [String] version string
        # @return [Boolean] true if compatible
        def check_ruby_compatibility(source_dir, version)
          version_file_path = File.join(source_dir, "lib", "version.rb")
          if File.exist?(version_file_path)
            version_file_content = File.read(version_file_path)
            if (match = version_file_content.match(REQUIRED_RUBY_PATTERN))
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
                respond "Gemstone IV  - #{GEMSTONE_INSTALL_URL}"
                respond
                return false
              end
            end
          end
          true
        end

        # Extracts LICH_VERSION constant from version.rb file.
        #
        # @param version_file_path [String] path to version.rb
        # @return [String, nil] version string or nil
        def extract_version_from_file(version_file_path)
          return nil unless File.exist?(version_file_path)

          version_file_content = File.read(version_file_path)
          if version_file_content =~ /LICH_VERSION\s*=\s*['"]([^'"]+)['"]/
            return $1
          end
          nil
        end
      end
    end
  end
end
