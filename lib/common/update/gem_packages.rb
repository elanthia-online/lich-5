# frozen_string_literal: true

=begin
  Scripts shipped as a gem attached to a GitHub release.

  A registered package names a GitHub repository. At login and on --sync,
  the newest release's .gem is compared with the installed copy, and a newer
  one is downloaded, installed into Lich's Ruby, and asked to install its
  own scripts through the entry point its gemspec names:

    spec.metadata['lich_install'] = 'eohunter/install#EOHunter::Install'

  The part before '#' is a file under the gem's lib/, loaded fresh each time
  so a second update in one session runs the new version's code. The part
  after is a constant whose .install(lich_dir) copies the scripts into Lich.
  Lich never knows what a package copies or where.

  The list is kept for the whole install, in lich_settings, because a gem is
  installed once for the whole Ruby.
=end

require 'json'
require 'open-uri'
require 'rubygems/installer'
require 'rubygems/package'

module Lich
  module Util
    module Update
      class GemPackages
        SETTING_NAME = 'gem_packages'
        METADATA_KEY = 'lich_install'
        OWNER_REPO = %r{\A[A-Za-z0-9._-]+/[A-Za-z0-9._-]+\z}
        ASSET_NAME = /\A(?<name>[A-Za-z0-9_-]+)-(?<version>\d[\w.]*)\.gem\z/

        # @param client [GitHubClient]
        def initialize(client)
          @client = client
        end

        # ---------------------------------------------------------------
        # The registry
        # ---------------------------------------------------------------

        # @return [Hash] owner_repo => registration hash
        def self.all
          raw = Lich.db.get_first_value("SELECT value FROM lich_settings WHERE name='#{SETTING_NAME}';")
          data = raw ? JSON.parse(raw) : {}
          data.is_a?(Hash) ? data : {}
        rescue JSON::ParserError
          {}
        end

        # @param data [Hash]
        # @return [void]
        def self.save(data)
          Lich.db.execute("INSERT OR REPLACE INTO lich_settings(name, value) VALUES('#{SETTING_NAME}', ?);",
                          [JSON.generate(data)])
        end

        # @param gem_name [String]
        # @return [Gem::Version, nil] the newest installed version, if any
        def self.installed_version(gem_name)
          Gem::Specification.reset
          Gem::Specification.find_all_by_name(gem_name).map(&:version).max
        end

        # ---------------------------------------------------------------
        # Commands
        # ---------------------------------------------------------------

        # Registers a repository and installs its latest release now.
        #
        # @param owner_repo [String] "owner/repo"
        # @return [void]
        def add_gem(owner_repo)
          unless owner_repo =~ OWNER_REPO
            StatusReporter.respond_mono("[lich5-update: Invalid format '#{owner_repo}'. Use owner/repo (e.g. elanthia-online/eohunter).]")
            return
          end

          added = self.class.update_registry do |data|
            next false if data[owner_repo]

            data[owner_repo] = { 'added_at' => Time.now.strftime('%Y-%m-%d') }
            true
          end
          unless added
            StatusReporter.respond_mono("[lich5-update: '#{owner_repo}' is already registered.]")
            return
          end

          StatusReporter.respond_mono("[lich5-update: Registered gem package '#{owner_repo}'.]")
          result = sync_gem(owner_repo, retried_by: :user)
          StatusReporter.respond_mono("[lich5-update: #{owner_repo} is already up to date.]") if result == :current
        end

        # Stops following a repository. The installed gem and its scripts
        # stay where they are.
        #
        # @param owner_repo [String]
        # @return [void]
        def remove_gem(owner_repo)
          reg = self.class.update_registry { |data| data.delete(owner_repo) }
          unless reg
            StatusReporter.respond_mono("[lich5-update: '#{owner_repo}' is not a registered gem package.]")
            return
          end

          note = reg['gem'] ? " The #{reg['gem']} gem and its scripts stay installed." : ''
          StatusReporter.respond_mono("[lich5-update: Removed gem package '#{owner_repo}'.#{note}]")
        end

        # @return [void]
        def list_gems
          data = self.class.all
          if data.empty?
            StatusReporter.respond_mono("[lich5-update: No gem packages registered. Use --add-gem=owner/repo to add one.]")
            return
          end

          rows = [['Repository', 'Gem', 'Installed', 'Added'], :separator]
          data.each do |owner_repo, reg|
            gem_name = reg['gem']
            installed = gem_name ? self.class.installed_version(gem_name) : nil
            rows << [owner_repo, gem_name || '?', installed ? installed.to_s : 'none', reg['added_at'] || '?']
          end
          StatusReporter.respond_mono(Terminal::Table.new(title: 'Gem Packages', rows: rows).to_s)
        end

        # ---------------------------------------------------------------
        # Sync
        # ---------------------------------------------------------------

        # Checks every registered repository. Stops at the first GitHub-wide
        # failure, as the script repository sync does.
        #
        # @return [void]
        def sync_all
          self.class.all.each_key do |owner_repo|
            break if sync_gem(owner_repo) == :github_unavailable
          end
        end

        # Installs the latest release of one repository if it is newer than
        # the installed gem.
        #
        # @param owner_repo [String]
        # @param retried_by [Symbol] :login or :user, for the failure message
        # @return [Symbol] :updated, :current, :skipped, :failed or :github_unavailable
        def sync_gem(owner_repo, retried_by: :login)
          release = @client.fetch_github_json("https://api.github.com/repos/#{owner_repo}/releases/latest")
          unless release
            error = @client.last_error
            StatusReporter.respond_github_failure(error, "#{owner_repo} was not checked for a new release.",
                                                  subject: "#{owner_repo} releases", retried_by: retried_by)
            return %i[not_found rejected].include?(error&.kind) ? :failed : :github_unavailable
          end

          asset = find_gem_asset(release)
          unless asset
            StatusReporter.respond_mono("[lich5-update: #{owner_repo}: release #{release['tag_name']} has no .gem attached; skipped.]")
            return :skipped
          end

          name = asset[:name]
          # A gem is installed once for the whole Ruby, so two registrations
          # publishing the same gem name would deploy each other's scripts.
          claimant = self.class.all.find { |repo, reg| repo != owner_repo && reg['gem'] == name }&.first
          if claimant
            StatusReporter.respond_mono("[lich5-update: #{owner_repo} publishes the gem '#{name}', which #{claimant} already provides; skipped.]")
            return :failed
          end
          remember(owner_repo, 'gem' => name)

          # Every Lich session using this Ruby shares one gem directory, and
          # RubyGems clears a gem's directory before extracting into it. The
          # recheck, install and deploy run under one lock so a second
          # session cannot pull files out from under the first.
          self.class.with_lock(install_lock_path) { sync_locked(owner_repo, asset) }
        end

        # Runs +block+ holding an exclusive lock on +path+, across processes
        # and threads.
        #
        # @param path [String] the lock file
        # @return [Object] the block's value
        def self.with_lock(path)
          FileUtils.mkdir_p(File.dirname(path))
          File.open(path, File::RDWR | File::CREAT, 0o644) do |file|
            file.flock(File::LOCK_EX)
            yield
          ensure
            file.flock(File::LOCK_UN)
          end
        end

        # Reads the registry, lets +block+ change it, and saves it, under a
        # lock, so another session's add, remove or sync in between is not
        # overwritten.
        #
        # @yieldparam data [Hash] the registry, to change in place
        # @return [Object] the block's value
        def self.update_registry
          with_lock(registry_lock_path) do
            data = all
            result = yield data
            save(data)
            result
          end
        end

        # @return [String] the registry lock, one per Lich install
        def self.registry_lock_path
          File.join(DATA_DIR, 'gem_packages.lock')
        end

        private

        # The part of #sync_gem that touches the shared gem directory.
        #
        # @param owner_repo [String]
        # @param asset [Hash] from #find_gem_asset
        # @return [Symbol] :updated, :current or :failed
        def sync_locked(owner_repo, asset)
          name = asset[:name]
          version = asset[:version]
          installed = self.class.installed_version(name)
          reg = self.class.all[owner_repo] || {}
          deployed = reg['deployed_gem'] == name ? reg['deployed'] : nil
          return :current if installed && installed >= version && deployed == installed.to_s

          # The gem is installed but its scripts never were here (its
          # installer failed, or another session installed it): run the
          # installer without downloading.
          if installed && installed >= version
            spec = Gem::Specification.find_all_by_name(name, "= #{installed}").first
            return deploy(owner_repo, spec, spec.metadata[METADATA_KEY], installed, nil) if spec
          end

          problem = gem_home_problem
          if problem
            StatusReporter.respond_mono("[lich5-update: #{name} #{version} not installed: #{problem}]")
            return :failed
          end

          gem_path = download(asset[:url], asset[:filename])
          return :failed unless gem_path

          install(owner_repo, name, version, gem_path, installed)
        ensure
          FileUtils.rm_f(gem_path) if gem_path
        end

        # The install lock sits beside the gem directory it protects, which
        # Lich installs sharing one Ruby share too. When that directory
        # cannot hold it, the lock falls back to this Lich install's TEMP_DIR.
        #
        # @return [String]
        def install_lock_path
          path = File.join(Gem.dir, '.lich5-gem-packages.lock')
          File.open(path, File::RDWR | File::CREAT, 0o644) {} # rubocop:disable Lint/EmptyBlock
          path
        rescue SystemCallError
          File.join(TEMP_DIR, 'gem-packages-install.lock')
        end

        # @param release [Hash] releases/latest payload
        # @return [Hash, nil] :name, :version, :filename, :url
        def find_gem_asset(release)
          Array(release['assets']).each do |asset|
            filename = asset['name'].to_s
            m = ASSET_NAME.match(filename) or next
            # The pattern admits strings like '1..2' that Gem::Version rejects.
            next unless Gem::Version.correct?(m[:version])

            return { name: m[:name], version: Gem::Version.new(m[:version]), filename: filename, url: asset['browser_download_url'] }
          end
          nil
        end

        # @param owner_repo [String]
        # @param fields [Hash]
        # @return [void]
        def remember(owner_repo, fields)
          self.class.update_registry { |data| data[owner_repo]&.merge!(fields) }
        end

        # GitHub serves release assets through a redirect, which open-uri
        # follows and GitHubClient#http_get does not.
        #
        # @return [String, nil] the downloaded file
        def download(url, filename)
          # Every Lich session on an install shares TEMP_DIR, so the name is
          # made unique to this process and thread.
          path = File.join(TEMP_DIR, "#{Process.pid}-#{Thread.current.object_id}-#{filename}")
          FileUtils.mkdir_p(TEMP_DIR)
          File.open(path, 'wb') { |file| file.write URI.parse(url).open(**GitHubClient.open_uri_timeouts).read }
          path
        rescue StandardError => e
          # File.open created the file before the request failed.
          FileUtils.rm_f(path) if path
          StatusReporter.respond_mono("[lich5-update: Could not download #{filename}: #{e.class}: #{e.message}]")
          nil
        end

        # @return [Symbol] :updated or :failed
        def install(owner_repo, name, version, gem_path, installed)
          package = Gem::Package.new(gem_path)
          spec = package.spec
          unless spec.name == name && spec.version == version
            StatusReporter.respond_mono("[lich5-update: #{owner_repo}: the asset is named #{name} #{version} but contains #{spec.name} #{spec.version}; not installed.]")
            return :failed
          end
          unless spec.extensions.empty?
            StatusReporter.respond_mono("[lich5-update: #{name} #{version} builds native extensions, which a script package may not; not installed.]")
            return :failed
          end

          entry = spec.metadata[METADATA_KEY]
          unless entry
            StatusReporter.respond_mono("[lich5-update: #{name} #{version} has no '#{METADATA_KEY}' metadata, so Lich cannot install its scripts; not installed.]")
            return :failed
          end

          unless spec.runtime_dependencies.empty?
            StatusReporter.respond_mono("[lich5-update: Note: #{name} declares gem dependencies (#{spec.runtime_dependencies.map(&:name).join(', ')}), which Lich does not install.]")
          end

          # RubyGems' installer does not check these itself (its resolver
          # does, and this install bypasses the resolver), so a release built
          # for a newer Ruby is refused here instead of overwriting working
          # scripts with code this Lich cannot run.
          unless spec.required_ruby_version.satisfied_by?(Gem.ruby_version)
            StatusReporter.respond_mono("[lich5-update: #{name} #{version} needs Ruby #{spec.required_ruby_version}, and this Lich runs #{Gem.ruby_version}; not installed.]")
            return :failed
          end
          unless spec.required_rubygems_version.satisfied_by?(Gem.rubygems_version)
            StatusReporter.respond_mono("[lich5-update: #{name} #{version} needs RubyGems #{spec.required_rubygems_version}, and this Lich has #{Gem.rubygems_version}; not installed.]")
            return :failed
          end

          installer = Gem::Installer.at(gem_path, install_dir: Gem.dir, ignore_dependencies: true, wrappers: false)
          installed_spec = installer.install
          Gem::Specification.reset
          deploy(owner_repo, installed_spec, entry, version, installed)
        rescue Errno::EACCES, Errno::EROFS => e
          StatusReporter.respond_mono("[lich5-update: #{name} #{version} not installed: cannot write to #{Gem.dir} (#{e.message}).]")
          :failed
        rescue StandardError => e
          StatusReporter.respond_mono("[lich5-update: #{name} #{version} failed to install (#{owner_repo}): #{e.class}: #{e.message}]")
          :failed
        end

        # A write probe of the gem home, done before anything is downloaded
        # into it. Reports the directory and the fix when it fails.
        #
        # @return [String, nil] the problem, or nil when writable
        def gem_home_problem
          dir = Gem.dir
          probe_dir = File.directory?(File.join(dir, 'gems')) ? File.join(dir, 'gems') : dir
          probe = File.join(probe_dir, ".lich5-update-#{Process.pid}-#{rand(1 << 32)}")
          File.write(probe, '')
          nil
        rescue SystemCallError => e
          "cannot write to #{probe_dir} (#{e.message}). Run Lich as a user who can write there, or set GEM_HOME to a writable directory."
        ensure
          FileUtils.rm_f(probe) if probe
        end

        # Loads the gem's installer file and calls Constant.install(LICH_DIR).
        #
        # @param spec [Gem::Specification] the installed gem
        # @param entry [String] "path/under/lib#Constant"
        # @return [Boolean] whether it succeeded
        def run_entry_point(spec, entry)
          path, const_name = entry.split('#', 2)
          if path.nil? || path.empty? || const_name.nil? || const_name.empty?
            StatusReporter.respond_mono("[lich5-update: #{spec.name}: '#{METADATA_KEY}' must be 'file#Constant', got '#{entry}'; scripts not installed.]")
            return false
          end

          file = spec.require_paths.map { |rp| File.join(spec.full_gem_path, rp, "#{path}.rb") }.find { |f| File.file?(f) }
          unless file
            StatusReporter.respond_mono("[lich5-update: #{spec.name}: installer file '#{path}' not found in the gem; scripts not installed.]")
            return false
          end

          load file
          installer = Object.const_get(const_name)
          installer.install(LICH_DIR)
          true
        rescue StandardError, ScriptError => e
          # ScriptError covers a LoadError from a missing dependency and a
          # SyntaxError in the installer file: one broken package must not
          # end the sync for the others.
          StatusReporter.respond_mono("[lich5-update: #{spec.name}: its installer failed: #{e.class}: #{e.message}. The gem is installed but its scripts were not copied; the next sync tries again.]")
          false
        end

        # Runs the gem's installer and records the deployed version for this
        # Lich install, so a failed deployment is retried at the next sync
        # instead of being taken for current.
        #
        # @param owner_repo [String]
        # @param spec [Gem::Specification] the installed gem
        # @param entry [String, nil] the lich_install metadata
        # @param version [Gem::Version] the version being deployed
        # @param previous [Gem::Version, nil] the version installed before, if any
        # @return [Symbol] :updated or :failed
        def deploy(owner_repo, spec, entry, version, previous)
          unless entry
            StatusReporter.respond_mono("[lich5-update: #{spec.name} #{version} has no '#{METADATA_KEY}' metadata, so Lich cannot install its scripts.]")
            return :failed
          end
          return :failed unless run_entry_point(spec, entry)

          remember(owner_repo, 'deployed_gem' => spec.name, 'deployed' => version.to_s)
          name = spec.name
          line = previous ? "#{name} updated to #{version}" : "#{name} #{version} installed"
          line += "; restart #{name} to use it" if defined?(Script) && Script.respond_to?(:running?) && Script.running?(name)
          StatusReporter.respond_mono("[lich5-update: #{line}.]")
          :updated
        end
      end
    end
  end
end
