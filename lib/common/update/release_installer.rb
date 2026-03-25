# frozen_string_literal: true

module Lich
  module Util
    module Update
      class ReleaseInstaller
        def initialize(client, resolver, snapshot_manager)
          @client = client
          @resolver = resolver
          @snapshot_manager = snapshot_manager
          @current = LICH_VERSION
          @update_to = nil
          @holder = nil
          @new_features = nil
          @zipfile = nil
        end

        def announce
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
            respond "This script does not support Lich #{LICH_VERSION}."
          end
        end

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

          @update_to = latest['tag_name'].to_s.sub('v', '')
          @holder = latest['assets']
          @new_features = latest['body'].to_s.gsub(/\#\# What's Changed.+$/m, '').gsub(/<!--[\s\S]*?-->/, '')
          release_asset = @holder && @holder.find { |x| x['name'] =~ /\b#{ASSET_TARBALL_NAME}\b/ }
          @zipfile = release_asset.fetch('browser_download_url')
        end

        def prep_betatest(type = nil, requested_file = nil)
          if type.nil?
            respond 'You are electing to participate in the beta testing of the next Lich release.'
            respond 'This beta test will include only Lich code, and does not include Ruby upates.'
            respond 'While we will do everything we can to ensure you have a smooth experience, '
            respond 'it is a test, and untoward things can result.  Please confirm your choice:'
            respond "Please confirm your participation:  #{$clean_lich_char}send Y or #{$clean_lich_char}send N"
            respond "You have 10 seconds to confirm, otherwise will be cancelled."

            sync_thread = $_CLIENT_ || $_DETACHABLE_CLIENT_
            timeout = Time.now + 10
            line = nil
            loop do
              line = sync_thread.gets
              break if line.is_a?(String) && line.strip =~ /^(?:<c>)?(?:#{$clean_lich_char}send|#{$clean_lich_char}s) /i
              break if Time.now > timeout
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

            perform_update(source_dir, @update_to)

            FileUtils.remove_dir(source_dir)
            FileUtils.rm(File.join(TEMP_DIR, "#{filename}.tar.gz"))

            Lich::Util::Update.clear_branch_tracking

            respond
            respond "Lich5 has been updated to Lich5 version #{@update_to}"
            respond "You should exit the game, then log back in.  This will start the game"
            respond "with your updated Lich.  Enjoy!"
          end
        end

        def perform_update(source_dir, version)
          FileUtils.rm_rf(Dir.glob(File.join(LIB_DIR, "*")))

          respond
          respond 'Copying updated lich files to their locations.'

          FileUtils.copy_entry(File.join(source_dir, "lib"), File.join(LIB_DIR))
          respond
          respond "All Lich lib files have been updated."
          respond

          file_updater = FileUpdater.new(@client, @resolver)
          file_updater.update_core_data_and_scripts(version)

          lich_to_update = File.join(LICH_DIR, File.basename($PROGRAM_NAME))
          update_to_lich = File.join(source_dir, "lich.rbw")
          File.open(update_to_lich, 'rb') { |r| File.open(lich_to_update, 'wb') { |w| w.write(r.read) } }
        end

        def validate_lich_structure(dir)
          required_items = ['lib', 'lich.rbw']
          required_items.all? { |item| File.exist?(File.join(dir, item)) }
        end

        def check_ruby_compatibility(source_dir, version)
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
