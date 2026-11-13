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
  installed once for the whole Ruby. docs/scripting/gem-packages.md describes
  the contract, what is refused, and the trust model.
=end

require 'digest'
require 'json'
require 'open-uri'
require 'rubygems/installer'
require 'rubygems/package'
require 'rubygems/uninstaller'

module Lich
  module Util
    module Update
      class GemPackages
        SETTING_NAME = 'gem_packages'
        METADATA_KEY = 'lich_install'
        OWNER_REPO = %r{\A[A-Za-z0-9._-]+/[A-Za-z0-9._-]+\z}

        # Owners whose new releases install automatically at login and on
        # --sync. A followed repository under any other owner is announced
        # instead, and installs only when the player runs --update-gem for
        # it. Decided on #2322 / #2323 (option c). Add an owner here to trust
        # it.
        TRUSTED_OWNERS = %w[elanthia-online].freeze
        ASSET_NAME = /\A(?<name>[A-Za-z0-9_-]+)-(?<version>\d[\w.]*)\.gem\z/

        # A script package is scripts and an installer; anything near this
        # size is not one, and the download is refused before it starts.
        MAX_ASSET_BYTES = 10 * 1024 * 1024

        # How long a sync waits for another Lich session's install of a
        # package to finish before giving up until the next sync.
        INSTALL_LOCK_WAIT = 60

        # The gem home directories Gem::Installer#install writes into, as
        # dependency recovery probes them.
        GEM_HOME_WRITE_DIRS = %w[gems specifications extensions cache build_info].freeze

        # A file RubyGems would register as a plugin: rubygems_plugin with
        # any suffix it loads (.rb, .so, .dll, .bundle ...), in any folder,
        # in any case, since Windows matches file names without case.
        PLUGIN_FILE = %r{(?:\A|[/\\])rubygems_plugin(?:\.[^/\\.]+)?\z}i

        # Path components Windows would change or treat specially when the
        # archive is extracted: a trailing dot or space (dropped, so
        # 'rubygems_plugin.rb..' lands as 'rubygems_plugin.rb'), characters
        # Windows reserves (':' also opens an alternate data stream),
        # control characters, '.' and '..', and device names.
        WINDOWS_AMBIGUOUS = /[. ]\z|[<>:"|?*\x00-\x1f]|\A\.{1,2}\z|\A(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\..*)?\z/i

        # Raised by .with_lock when +wait+ runs out.
        class LockBusy < StandardError; end

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

        # Whether +owner_repo+'s releases update without asking. The owner
        # is compared whole and without case: Elanthia-Online/x is trusted,
        # elanthia-online-fork/x is not.
        #
        # @param owner_repo [String] "owner/repo"
        # @return [Boolean]
        def self.trusted?(owner_repo)
          owner = owner_repo.to_s.split('/', 2).first.to_s
          TRUSTED_OWNERS.any? { |trusted| trusted.casecmp?(owner) }
        end

        # @param gem_name [String]
        # @return [Gem::Version, nil] the newest installed version, if any
        def self.installed_version(gem_name)
          Gem::Specification.reset
          Gem::Specification.find_all_by_name(gem_name).map(&:version).max
        end

        # Runs +block+ holding an exclusive lock on +path+, across processes
        # and threads.
        #
        # @param path [String] the lock file
        # @param wait [Numeric, nil] seconds to wait for the lock; nil waits
        #   as long as it takes
        # @return [Object] the block's value
        # @raise [LockBusy] when +wait+ runs out
        def self.with_lock(path, wait: nil)
          FileUtils.mkdir_p(File.dirname(path))
          File.open(path, File::RDWR | File::CREAT, 0o644) do |file|
            if wait
              deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + wait
              until file.flock(File::LOCK_EX | File::LOCK_NB)
                raise LockBusy, path if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

                sleep 0.25
              end
            else
              file.flock(File::LOCK_EX)
            end
            begin
              yield
            ensure
              file.flock(File::LOCK_UN)
            end
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

        # Where gem executables are linked. Lich runs a package's installer
        # in-process and never needs its commands, so they go here rather
        # than into Ruby's bin directory, where they could take over another
        # gem's command.
        #
        # @return [String]
        def self.bin_dir
          File.join(DATA_DIR, 'gem-packages', 'bin')
        end

        # Verified .gem files, kept so a failed deploy is retried by
        # reinstalling these exact bytes rather than by finding a gem of
        # that name and version in Ruby's shared gem path.
        #
        # @return [String]
        def self.artifact_dir
          File.join(DATA_DIR, 'gem-packages', 'artifacts')
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
          result = sync_gem(owner_repo, retried_by: :user, first_add: true)
          StatusReporter.respond_mono("[lich5-update: #{owner_repo} is already up to date.]") if result == :current
          unless result == :refused
            unless self.class.trusted?(owner_repo)
              StatusReporter.respond_mono("[lich5-update: #{owner_repo} is not from a trusted owner, so its later releases are announced at login " \
                                          "rather than installed. Install one with #{$clean_lich_char}lich5-update --update-gem=#{owner_repo}]")
            end
            return
          end

          # A refusal at the first sync would otherwise repeat at every login.
          self.class.update_registry { |data| data.delete(owner_repo) }
          StatusReporter.respond_mono("[lich5-update: '#{owner_repo}' was not registered.]")
        end

        # Installs the latest release of a followed repository now: the
        # player's go-ahead for an owner that is not trusted, whose releases
        # are otherwise only announced.
        #
        # @param owner_repo [String] "owner/repo"
        # @return [void]
        def update_gem(owner_repo)
          unless self.class.all.key?(owner_repo)
            StatusReporter.respond_mono("[lich5-update: '#{owner_repo}' is not a registered gem package. Use --add-gem=#{owner_repo} to follow it.]")
            return
          end

          result = sync_gem(owner_repo, retried_by: :user, consent: true)
          StatusReporter.respond_mono("[lich5-update: #{owner_repo} is already up to date.]") if result == :current
        end

        # Stops following a repository. The gem and the scripts its installer
        # copied stay; the message names the command that removes the gem.
        #
        # @param owner_repo [String]
        # @return [void]
        def remove_gem(owner_repo)
          reg = self.class.update_registry { |data| data.delete(owner_repo) }
          unless reg
            StatusReporter.respond_mono("[lich5-update: '#{owner_repo}' is not a registered gem package.]")
            return
          end

          note = ''
          if reg['gem']
            note = " The #{reg['gem']} gem and its scripts stay installed. " \
                   "To remove the gem from Lich's Ruby: gem uninstall #{reg['gem']} --all --executables"
          end
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
            status = installed ? installed.to_s : 'none'
            status += " (#{reg['refused'].split.first} refused)" if reg['refused']
            rows << [owner_repo, gem_name || '?', status, reg['added_at'] || '?']
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
        # @param first_add [Boolean] this sync is the one --add-gem runs, so
        #   a refused release ends the registration rather than being skipped
        #   at later syncs. The player named the repository, so it installs
        #   whoever the owner is
        # @param consent [Boolean] the player asked for this repository's
        #   release (--update-gem), so it installs whoever the owner is
        # @return [Symbol] :updated, :current, :skipped, :failed, :refused (the
        #   release's gem name is not this repository's to use, or its
        #   contents are not a script package), :announced (a new release from
        #   an owner that is not trusted, waiting for --update-gem) or
        #   :github_unavailable
        def sync_gem(owner_repo, retried_by: :login, first_add: false, consent: false)
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

          refusal = claim_gem_name(owner_repo, asset[:name])
          if refusal
            StatusReporter.respond_mono("[lich5-update: #{owner_repo}: #{refusal}]")
            return :refused
          end

          # This exact release was downloaded and refused for its contents
          # before, under this Ruby. It is not downloaded again until the
          # release, its asset, or the Ruby changes; --gems shows it.
          return :refused if self.class.all.dig(owner_repo, 'refused') == refusal_signature(asset)

          state, = local_state(owner_repo, asset)
          return :current if state == :current

          # A new release from an owner that is not trusted waits for the
          # player. A :reinstall retry is not new code: it reinstalls the
          # exact bytes the player already installed, so it goes ahead.
          if state == :install && !first_add && !consent && !self.class.trusted?(owner_repo)
            StatusReporter.respond_mono("[lich5-update: #{owner_repo} has #{asset[:name]} #{asset[:version]} available. " \
                                        "Its owner is not trusted for automatic updates; install it with #{$clean_lich_char}lich5-update --update-gem=#{owner_repo}]")
            return :announced
          end

          problem = gem_home_problem
          if problem
            StatusReporter.respond_mono("[lich5-update: #{asset[:name]} #{asset[:version]} not installed: #{problem}]")
            return :failed
          end

          if state == :install
            # Downloaded before taking the install lock, so a slow transfer
            # does not hold up other sessions' updates.
            gem_path = download(asset)
            return :failed unless gem_path
          end

          # Every Lich session using this Ruby shares one gem directory, and
          # RubyGems clears a gem's directory before extracting into it. The
          # recheck, install and deploy run under one lock so a second
          # session cannot pull files out from under the first.
          self.class.with_lock(install_lock_path, wait: INSTALL_LOCK_WAIT) { sync_locked(owner_repo, asset, gem_path, first_add: first_add) }
        rescue LockBusy
          StatusReporter.respond_mono("[lich5-update: Another Lich session is installing a gem package; #{asset[:name]} will be checked at the next sync.]")
          :failed
        ensure
          FileUtils.rm_f(gem_path) if gem_path
        end

        private

        # The part of #sync_gem that touches the shared gem directory. The
        # state is checked again here, since another session may have
        # installed the release while this one waited for the lock.
        #
        # @param owner_repo [String]
        # @param asset [Hash] from #find_gem_asset
        # @param gem_path [String, nil] the downloaded gem, if one was needed
        # @param first_add [Boolean] see #sync_gem
        # @return [Symbol] :updated, :current or :failed
        def sync_locked(owner_repo, asset, gem_path, first_add: false)
          state, installed, artifact = local_state(owner_repo, asset)
          case state
          when :current
            :current
          when :reinstall
            install(owner_repo, asset, artifact, installed, first_add: first_add)
          else
            unless gem_path
              StatusReporter.respond_mono("[lich5-update: #{asset[:name]} changed while waiting for another session; it will be checked at the next sync.]")
              return :failed
            end
            install(owner_repo, asset, gem_path, installed, first_add: first_add)
          end
        end

        # Where this Lich install stands with the release.
        #
        # Only the exact version the release advertises counts, and only
        # when this registration installed it after verifying the download.
        # A higher version of the same name from anywhere else in Ruby's gem
        # path (another Lich install, a hand-run gem install) is never
        # adopted: its installer would run as if this repository had
        # published it. Such a release is downloaded, verified and installed
        # over instead.
        #
        # @param owner_repo [String]
        # @param asset [Hash] from #find_gem_asset
        # A retry never looks the gem up by name and version: another
        # publisher's gem of the same name and version could have replaced
        # or shadowed it in the shared gem path. It reinstalls from the .gem
        # this registration verified, kept in .artifact_dir and checked
        # against the SHA-256 recorded when it was installed.
        #
        # @return [Array(Symbol, Gem::Version, String)] the state, the newest
        #   installed version (for the report line), and the verified .gem
        #   for :reinstall. :current when this registration installed and
        #   deployed the release; :reinstall when it installed it but the
        #   deploy failed and its verified .gem is intact; :install otherwise
        def local_state(owner_repo, asset)
          name = asset[:name]
          version = asset[:version]
          installed = self.class.installed_version(name)
          reg = self.class.all[owner_repo] || {}
          return [:install, installed, nil] unless reg['installed_gem'] == name && reg['installed'] == version.to_s

          deployed = reg['deployed_gem'] == name ? reg['deployed'] : nil
          present = Gem::Specification.find_all_by_name(name, "= #{version}").any?
          return [:current, installed, nil] if deployed == version.to_s && present

          artifact = verified_artifact(reg, name, version)
          artifact ? [:reinstall, installed, artifact] : [:install, installed, nil]
        end

        # @param reg [Hash] the registration
        # @param name [String]
        # @param version [Gem::Version]
        # @return [String, nil] the kept .gem, when its SHA-256 still matches
        def verified_artifact(reg, name, version)
          path = artifact_path(name, version)
          return nil unless reg['artifact_sha256'] && File.file?(path)

          Digest::SHA256.file(path).hexdigest == reg['artifact_sha256'] ? path : nil
        end

        # @param name [String]
        # @param version [Gem::Version]
        # @return [String]
        def artifact_path(name, version)
          File.join(self.class.artifact_dir, "#{name}-#{version}.gem")
        end

        # Ties a gem name to the registration that first installs it, in one
        # registry update so two sessions cannot both claim it. The sync
        # checks the name before downloading, without pinning it; the name is
        # pinned only once the downloaded gem has passed #refusal_for, so a
        # refused release does not hold the name.
        #
        # A release may not change its gem name, use a name another
        # registration holds, or take over a gem already in Lich's Ruby that
        # no registration installed, such as one of Lich's own dependencies.
        # A gem already installed by hand is accepted when its
        # source_code_uri or homepage is this repository.
        #
        # @param owner_repo [String]
        # @param name [String] the gem name the release publishes
        # @param pin [Boolean] whether to record the name as this
        #   registration's when it is accepted
        # @return [String, nil] why the release is refused, or nil
        def claim_gem_name(owner_repo, name, pin: false)
          self.class.update_registry do |data|
            reg = data[owner_repo]
            next 'it is no longer registered.' unless reg

            pinned = reg['gem']
            next nil if pinned == name

            if pinned
              next "its release now publishes the gem '#{name}', but it was added for '#{pinned}'. " \
                   "If that change is intended, run #{$clean_lich_char}lich5-update --remove-gem=#{owner_repo}, then --add-gem=#{owner_repo}."
            end

            claimant = data.find { |repo, other| repo != owner_repo && other['gem'] == name }&.first
            next "it publishes the gem '#{name}', which #{claimant} already provides; skipped." if claimant

            unless self.class.installed_version(name).nil? || from_repository?(name, owner_repo)
              next "it publishes the gem '#{name}', which is already installed in Lich's Ruby and was not installed by this package; refused. " \
                   "The package's next release can set source_code_uri (or homepage) to https://github.com/#{owner_repo}, " \
                   "or uninstall the gem (gem uninstall #{name} --all --executables) and add the package again."
            end

            reg['gem'] = name if pin
            nil
          end
        end

        # What identifies a refused release: its version and asset (the
        # digest GitHub publishes, or the size when there is none), and the
        # Ruby and RubyGems it was refused under, since an upgrade can meet a
        # requirement that refused it.
        #
        # @param asset [Hash] from #find_gem_asset
        # @return [String]
        def refusal_signature(asset)
          [asset[:version], asset[:digest] || "size:#{asset[:size]}", "ruby:#{Gem.ruby_version}", "rubygems:#{Gem.rubygems_version}"].join(' ')
        end

        # @param name [String]
        # @param owner_repo [String]
        # @return [Boolean] whether the installed gem names this repository
        #   as its source
        def from_repository?(name, owner_repo)
          spec = Gem::Specification.find_all_by_name(name).max_by(&:version)
          return false unless spec

          expected = "github.com/#{owner_repo}".downcase
          [spec.metadata['source_code_uri'], spec.homepage].compact.any? do |uri|
            uri.downcase.sub(%r{\Ahttps?://(www\.)?}, '').sub(/\.git\z/, '').chomp('/') == expected
          end
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
        # @return [Hash, nil] :name, :version, :filename, :url, :size, :digest
        def find_gem_asset(release)
          Array(release['assets']).each do |asset|
            filename = asset['name'].to_s
            m = ASSET_NAME.match(filename) or next
            # The pattern admits strings like '1..2' that Gem::Version rejects.
            next unless Gem::Version.correct?(m[:version])

            return { name: m[:name], version: Gem::Version.new(m[:version]), filename: filename,
                     url: asset['browser_download_url'], size: asset['size'], digest: asset['digest'] }
          end
          nil
        end

        # @param owner_repo [String]
        # @param fields [Hash]
        # @return [void]
        def remember(owner_repo, fields)
          self.class.update_registry { |data| data[owner_repo]&.merge!(fields) }
        end

        # Downloads the asset to a file unique to this process and thread.
        # GitHub serves release assets through a redirect, which open-uri
        # follows and GitHubClient#http_get does not. The size GitHub reports
        # is checked first, the copy stops one byte past the cap, and the
        # SHA-256 GitHub publishes is compared when the release has one.
        #
        # @param asset [Hash] from #find_gem_asset
        # @return [String, nil] the downloaded file
        def download(asset)
          filename = asset[:filename]
          if asset[:size].to_i > MAX_ASSET_BYTES
            StatusReporter.respond_mono("[lich5-update: #{filename} is #{asset[:size]} bytes, over the #{MAX_ASSET_BYTES}-byte limit for a script package; not downloaded.]")
            return nil
          end

          # Every Lich session on an install shares TEMP_DIR.
          path = File.join(TEMP_DIR, "#{Process.pid}-#{Thread.current.object_id}-#{filename}")
          FileUtils.mkdir_p(TEMP_DIR)
          # open-uri reads the whole response before returning, so the cap is
          # enforced during the transfer: a declared length over it, or
          # progress past it, aborts the request.
          too_big = ->(bytes) { raise "over the #{MAX_ASSET_BYTES}-byte limit" if bytes && bytes > MAX_ASSET_BYTES }
          File.open(path, 'wb') do |file|
            body = URI.parse(asset[:url]).open(**GitHubClient.open_uri_timeouts,
                                               content_length_proc: too_big, progress_proc: too_big)
            begin
              IO.copy_stream(body, file, MAX_ASSET_BYTES + 1)
            ensure
              body.close
            end
          end
          raise "over the #{MAX_ASSET_BYTES}-byte limit" if File.size(path) > MAX_ASSET_BYTES

          expected = asset[:digest].to_s[/\Asha256:(\h{64})\z/, 1]
          if expected && Digest::SHA256.file(path).hexdigest != expected.downcase
            raise 'its SHA-256 does not match the digest GitHub published for it'
          end

          path
        rescue StandardError => e
          # File.open created the file before the request failed.
          FileUtils.rm_f(path) if path
          StatusReporter.respond_mono("[lich5-update: Could not download #{filename}: #{e.class}: #{e.message}]")
          nil
        end

        # @param owner_repo [String]
        # @param asset [Hash] from #find_gem_asset
        # @param gem_path [String] the downloaded gem
        # @param installed [Gem::Version, nil] the version installed before
        # @param first_add [Boolean] see #sync_gem
        # @return [Symbol] :updated or :failed
        def install(owner_repo, asset, gem_path, installed, first_add: false)
          name = asset[:name]
          version = asset[:version]
          package = Gem::Package.new(gem_path)
          spec = package.spec
          refusal = refusal_for(spec, name, version, package.contents)
          if refusal
            remember(owner_repo, 'refused' => refusal_signature(asset))
            # On --add-gem the registration is dropped next, and says so; a
            # followed package skips this release until refusal_signature
            # changes.
            line = "[lich5-update: #{owner_repo}: #{refusal}; not installed."
            line += ' It will not be downloaded again until the release, its asset, or Ruby changes.' unless first_add
            StatusReporter.respond_mono("#{line}]")
            return :refused
          end

          # The name is the registration's from here on.
          refusal = claim_gem_name(owner_repo, name, pin: true)
          if refusal
            StatusReporter.respond_mono("[lich5-update: #{owner_repo}: #{refusal}]")
            return :refused
          end

          unless spec.runtime_dependencies.empty?
            StatusReporter.respond_mono("[lich5-update: Note: #{name} declares gem dependencies (#{spec.runtime_dependencies.map(&:name).join(', ')}), which Lich does not install.]")
          end

          # The verified bytes are kept, and installed from the kept copy, so a
          # retry reinstalls exactly what was checked here.
          artifact = artifact_path(name, version)
          unless File.expand_path(gem_path) == File.expand_path(artifact)
            FileUtils.mkdir_p(self.class.artifact_dir)
            FileUtils.cp(gem_path, artifact)
          end
          sha = Digest::SHA256.file(artifact).hexdigest

          installer = Gem::Installer.at(artifact, install_dir: Gem.dir, bin_dir: self.class.bin_dir,
                                                  ignore_dependencies: true, wrappers: false)
          installed_spec = installer.install
          Gem::Specification.reset
          # Provenance: this version is one this registration verified and
          # installed, from the kept copy whose SHA-256 is recorded.
          self.class.update_registry do |data|
            reg = data[owner_repo]
            next unless reg

            reg.delete('refused')
            reg.merge!('installed_gem' => name, 'installed' => version.to_s, 'artifact_sha256' => sha)
          end
          result = deploy(owner_repo, installed_spec, spec.metadata[METADATA_KEY], version, installed)
          remove_older_versions(name, version) if result == :updated
          result
        rescue Errno::EACCES, Errno::EPERM, Errno::EROFS, Gem::FilePermissionError => e
          StatusReporter.respond_mono("[lich5-update: #{name} #{version} not installed: cannot write to #{Gem.dir} (#{e.message}). " \
                                      'Run Lich as a user who can write there, or set GEM_HOME to a writable directory.]')
          :failed
        rescue StandardError => e
          StatusReporter.respond_mono("[lich5-update: #{name} #{version} failed to install (#{owner_repo}): #{e.class}: #{e.message}]")
          :failed
        end

        # What a script package may not be.
        #
        # @param spec [Gem::Specification] the downloaded gem's spec
        # @param name [String] the name in the asset filename
        # @param version [Gem::Version] the version in the asset filename
        # @param entries [Array<String>] the files actually in the gem's archive
        # @return [String, nil] why the gem is refused, or nil
        def refusal_for(spec, name, version, entries)
          return "the asset is named #{name} #{version} but contains #{spec.name} #{spec.version}" unless spec.name == name && spec.version == version
          return "#{name} #{version} builds native extensions, which a script package may not" unless spec.extensions.empty?
          ambiguous = entries.find { |f| f.include?('\\') || f.split('/').any? { |part| WINDOWS_AMBIGUOUS.match?(part) } }
          return "#{name} #{version} has an archive path Windows would change on extraction (#{ambiguous.inspect})" if ambiguous

          # A RubyGems plugin would run on every later gem command, outside
          # Lich. RubyGems finds plugins in the extracted files, not in
          # spec.files, so the archive's own entries are checked.
          return "#{name} #{version} ships a RubyGems plugin, which a script package may not" if entries.any? { |f| PLUGIN_FILE.match?(f) }
          return "#{name} #{version} has no '#{METADATA_KEY}' metadata, so Lich cannot install its scripts" unless spec.metadata[METADATA_KEY]

          # RubyGems' installer does not check these itself (its resolver
          # does, and this install bypasses the resolver).
          unless spec.required_ruby_version.satisfied_by?(Gem.ruby_version)
            return "#{name} #{version} needs Ruby #{spec.required_ruby_version}, and this Lich runs #{Gem.ruby_version}"
          end
          unless spec.required_rubygems_version.satisfied_by?(Gem.rubygems_version)
            return "#{name} #{version} needs RubyGems #{spec.required_rubygems_version}, and this Lich has #{Gem.rubygems_version}"
          end

          nil
        end

        # Uninstalls the versions of +name+ older than +version+ once the
        # new one is installed and deployed. Other Lich installs on this Ruby
        # keep working: their scripts are copies, and their next sync
        # deploys the new version. A version that cannot be removed is
        # reported and left.
        #
        # @param name [String]
        # @param version [Gem::Version] the version just deployed
        # @return [void]
        def remove_older_versions(name, version)
          # Gem::Uninstaller resolves install_dir with File.realpath, loads
          # specs from the path it was given, and removes only those whose
          # base_dir equals the resolved path. Passing the resolved gem home
          # makes the two agree when Gem.dir goes through a symlink. Copies
          # in other gem directories on GEM_PATH are left alone.
          home = real_path(Gem.dir)
          Gem::Specification.find_all_by_name(name).select { |s| s.version < version && real_path(s.base_dir) == home }.each do |old|
            Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) do
              Gem::Uninstaller.new(name, version: "= #{old.version}", install_dir: home, bin_dir: self.class.bin_dir,
                                         executables: true, ignore: true, force: true).uninstall
            end
          rescue StandardError => e
            StatusReporter.respond_mono("[lich5-update: Note: could not remove #{name} #{old.version}: #{e.message}]")
          end
          Gem::Specification.reset

          # The kept .gem files of older versions are no longer needed for a retry.
          Dir[File.join(self.class.artifact_dir, "#{name}-*.gem")].each do |path|
            kept = File.basename(path, '.gem').delete_prefix("#{name}-")
            FileUtils.rm_f(path) if Gem::Version.correct?(kept) && Gem::Version.new(kept) < version
          end
        end

        # @param path [String]
        # @return [String] +path+ with symlinks resolved, or as given when it
        #   does not exist
        def real_path(path)
          File.realpath(path)
        rescue SystemCallError
          path
        end

        # Checks, before anything is downloaded, every gem home directory
        # Gem::Installer#install writes into, as dependency recovery does
        # (lib/dependency_recovery.rb, #2306). plugins is also checked for
        # the read-only flag, which Gem::Installer refuses even where
        # Windows would allow the write.
        #
        # @return [String, nil] the problem, or nil when writable
        def gem_home_problem
          home = Gem.dir
          plugins = Gem.plugindir(home)
          if File.directory?(plugins) && !File.writable?(plugins)
            return read_only_dir_message(plugins)
          end

          ([home] + GEM_HOME_WRITE_DIRS.map { |d| File.join(home, d) } + [plugins]).uniq.each do |dir|
            dir = File.dirname(dir) until File.directory?(dir) || File.dirname(dir) == dir
            probe = File.join(dir, ".lich5-update-#{Process.pid}-#{rand(1 << 32)}")
            begin
              File.write(probe, '')
            rescue SystemCallError => e
              return "cannot write to #{dir} (#{e.message}). Run Lich as a user who can write there, or set GEM_HOME to a writable directory."
            ensure
              FileUtils.rm_f(probe)
            end
          end
          nil
        end

        # @param dir [String]
        # @return [String] one line naming +dir+ and how to clear the flag
        def read_only_dir_message(dir)
          if Gem.win_platform?
            native = dir.tr('/', '\\')
            "#{native} is marked read-only, so gems cannot be installed. Open a Command Prompt and run: attrib -R \"#{native}\""
          else
            "#{dir} is not writable, so gems cannot be installed. Make it writable for your user (chmod u+w \"#{dir}\")."
          end
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

        # Runs the gem's installer and records the deployed gem and version
        # for this Lich install, so a failed deployment is retried at the
        # next sync instead of being taken for current.
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
          line = if previous && previous < version
                   "#{name} updated to #{version}"
                 elsif previous == version
                   "#{name} #{version} reinstalled"
                 else
                   "#{name} #{version} installed"
                 end
          line += "; restart #{name} to use it" if defined?(Script) && Script.respond_to?(:running?) && Script.running?(name)
          StatusReporter.respond_mono("[lich5-update: #{line}.]")
          :updated
        end
      end
    end
  end
end
