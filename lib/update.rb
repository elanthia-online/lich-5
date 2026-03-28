# frozen_string_literal: true

=begin
  Composition root for the Lich5 update system.

  Provides the public API surface for updating Lich5 core, managing snapshots,
  syncing script repositories, and tracking individual files. Wires together
  internal classes and manages lazy initialization of dependencies.

  Supports both release-based updates and branch-based development workflows.
=end

require 'digest'
require 'json'
require 'net/http'
require 'open-uri'
require 'rubygems/package'
require 'zlib'

require_relative 'common/update/file_writer'
require_relative 'common/update/status_reporter'
require_relative 'common/update/github_client'
require_relative 'common/update/channel_resolver'
require_relative 'common/update/snapshot_manager'
require_relative 'common/update/tracked_scripts'
require_relative 'common/update/custom_repos'
require_relative 'common/update/script_sync'
require_relative 'common/update/file_updater'
require_relative 'common/update/release_installer'
require_relative 'common/update/branch_installer'

module Lich
  module Util
    module Update
      # Update channel constants
      STABLE_REF = 'main'
      BETA_BRANCH_PREFIX = 'pre/beta'
      ASSET_TARBALL_NAME = 'lich-5.tar.gz'
      GITHUB_REPO = 'elanthia-online/lich-5'

      # Script repository registry
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
          display_name: 'Core Scripts',
          api_url: 'https://api.github.com/repos/elanthia-online/scripts/git/trees/master?recursive=1',
          raw_base_url: 'https://raw.githubusercontent.com/elanthia-online/scripts/master',
          tracking_mode: :explicit,
          script_pattern: /^scripts\/[^\/]+\.lic$/,
          script_prefix: 'scripts',
          game_filter: nil,
          default_tracked: %w[
            alias.lic autostart.lic go2.lic jinx.lic log.lic
            logxml.lic map.lic repository.lic vars.lic version.lic
          ].freeze,
          subdirs: {}
        }.freeze,
        'gs-scripts' => {
          display_name: 'GS Scripts',
          api_url: 'https://api.github.com/repos/elanthia-online/scripts/git/trees/master?recursive=1',
          raw_base_url: 'https://raw.githubusercontent.com/elanthia-online/scripts/master',
          tracking_mode: :explicit,
          script_pattern: /^scripts\/[^\/]+\.lic$/,
          script_prefix: 'scripts',
          game_filter: /^GS/,
          default_tracked: %w[
            ewaggle.lic
          ].freeze,
          subdirs: {
            'data' => { pattern: /^scripts\/(gameobj-data|effect-list)\.xml$/, dest: DATA_DIR, glob: '*.xml' }
          }
        }.freeze
      }.freeze

      # ---------------------------------------------------------------
      # Public API -- called by games.rb and global_defs.rb
      # ---------------------------------------------------------------

      # Routes update commands to appropriate handler classes.
      #
      # @param type [String] command flag (e.g. '--announce', '--update', '--sync')
      # @return [void]
      def self.request(type = '--announce')
        case type
        when /^(?:--announce|-a)\b/
          release_installer.announce
        when /^--branch=(.+)$/
          branch_installer.download_branch_update($1)
        when /^--(?:beta|test)(?: --(?:(script|library|data))=(.+))?\b/
          release_installer.prep_betatest($1&.dup, $2&.dup)
        when /^(?:--help|-h)\b/
          help
        when /^--status\b/
          show_status
        when /^(?:--update|-u)\b/
          release_installer.download_release_update
        when /^--refresh\b/
          respond
          respond "This command has been removed."
        when /^(?:--revert|-r)\b/
          snapshot_manager.revert
        when /^--add-custom=(\S+?)(?::(\S+))?$/
          custom_repos_manager.add_custom_repo($1, $2)
        when /^--remove-custom=(\S+)$/
          custom_repos_manager.remove_custom_repo($1)
        when /^--custom-repos$/
          custom_repos_manager.list_custom_repos
        when /^--sync(?:=(\S+))?$/
          if $1
            script_sync.sync_repo($1)
          else
            script_sync.sync_all_repos
          end
        when /^--track=(\S+):(\S+)$/
          tracked_scripts_manager.track_script($1, $2)
        when /^--untrack=(\S+):(\S+)$/
          tracked_scripts_manager.untrack_script($1, $2)
        when /^--tracked(?:=(\S+))?$/
          tracked_scripts_manager.show_tracked($1)
        when /^--(?:(script|library|data))=(?:(\S+):)?(.+)\b/
          type_name = $1&.dup
          repo = $2&.dup
          file = $3&.dup
          if repo
            file_updater.update_file_from_repo(type_name, repo, file)
          else
            file_updater.update_file(type_name, file)
          end
        when /^(?:--snapshot|-s)\b/
          snapshot_manager.snapshot
        else
          respond
          respond "Command '#{type}' unknown, illegitimate and ignored.  Exiting . . ."
          respond
        end
      end

      # Syncs all script repositories for current game.
      #
      # @return [void]
      def self.sync_all_repos
        script_sync.sync_all_repos
      end

      # Updates core data files and scripts to specified version.
      #
      # @param version [String] version string (default: current LICH_VERSION)
      # @return [void]
      def self.update_core_data_and_scripts(version = LICH_VERSION)
        file_updater.update_core_data_and_scripts(version)
      end

      # ---------------------------------------------------------------
      # Help and status display
      # ---------------------------------------------------------------

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

  [Custom 3rd-party repositories]
    #{$clean_lich_char}lich5-update --add-custom=owner/repo             Register a custom repo (default branch)
    #{$clean_lich_char}lich5-update --add-custom=owner/repo:branch      Register with specific branch
    #{$clean_lich_char}lich5-update --remove-custom=owner/repo          Unregister a custom repo
    #{$clean_lich_char}lich5-update --custom-repos                      List registered custom repos
    #{$clean_lich_char}lich5-update --track=owner/repo:script.lic       Track a script from custom repo
    #{$clean_lich_char}lich5-update --sync=owner/repo                   Sync a custom repo
    Custom scripts are installed to #{$clean_lich_char}scripts/custom/<owner-repo>/

  [Individual file updates]
    #{$clean_lich_char}lich5-update --script=<name>                     Update script (auto-detects repo)
    #{$clean_lich_char}lich5-update --script=dr-scripts:<name>          Update script from specific repo
    #{$clean_lich_char}lich5-update --data=dr-scripts:base-hunting.yaml Update data file from specific repo
    #{$clean_lich_char}lich5-update --library=<name>                    Update library file from lich-5

  [One time suggestions]
    #{$clean_lich_char}autostart add --global lich5-update --announce    Check for new version at login

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

    *NOTE* Script repos sync automatically on login for both DR and GS.
    "
      end

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

      # ---------------------------------------------------------------
      # Branch tracking utilities (shared across installer classes)
      # ---------------------------------------------------------------

      # Persists branch tracking info to version.rb.
      #
      # @param branch_name [String] branch name
      # @param repo [String] repository identifier (e.g. 'owner/lich-5')
      # @param _version [String] version string (unused)
      # @return [void]
      def self.store_branch_tracking(branch_name, repo, _version)
        version_file_path = File.join(LIB_DIR, "version.rb")
        version_content = File.read(version_file_path)

        version_content.gsub!(/\n# Branch tracking \(added by lich5-update --branch\).*?\n(?:LICH_BRANCH[^\n]*\n)*/m, '')

        branch_tracking = <<~RUBY

          # Branch tracking (added by lich5-update --branch)
          LICH_BRANCH = '#{branch_name}'
          LICH_BRANCH_REPO = '#{repo}'
          LICH_BRANCH_UPDATED_AT = #{Time.now.to_i}
        RUBY

        version_content = version_content.rstrip + branch_tracking
        File.write(version_file_path, version_content)
      end

      # Removes branch tracking constants from version.rb.
      #
      # @return [void]
      def self.clear_branch_tracking
        version_file_path = File.join(LIB_DIR, "version.rb")
        return unless File.exist?(version_file_path)

        version_content = File.read(version_file_path)
        version_content.gsub!(/\n# Branch tracking \(added by lich5-update --branch\).*?\n(?:LICH_BRANCH[^\n]*\n)*/m, '')
        version_content = version_content.rstrip + "\n"
        File.write(version_file_path, version_content)
      end

      # Reads current branch tracking info if defined.
      #
      # @return [Hash, nil] hash with :branch_name, :repository, :updated_at or nil
      def self.get_branch_info
        if defined?(LICH_BRANCH) && LICH_BRANCH && !LICH_BRANCH.empty?
          {
            branch_name: LICH_BRANCH,
            repository: (defined?(LICH_BRANCH_REPO) ? LICH_BRANCH_REPO : nil),
            updated_at: (defined?(LICH_BRANCH_UPDATED_AT) ? LICH_BRANCH_UPDATED_AT : nil)
          }
        end
      end

      # ---------------------------------------------------------------
      # Lazy-initialized wiring (private)
      # ---------------------------------------------------------------

      def self.client
        @client ||= GitHubClient.new
      end

      def self.resolver
        @resolver ||= ChannelResolver.new(client)
      end

      def self.snapshot_manager
        @snapshot_manager ||= SnapshotManager.new
      end

      def self.release_installer
        @release_installer ||= ReleaseInstaller.new(client, resolver, snapshot_manager)
      end

      def self.branch_installer
        @branch_installer ||= BranchInstaller.new(snapshot_manager, release_installer)
      end

      def self.script_sync
        @script_sync ||= ScriptSync.new(client)
      end

      def self.tracked_scripts_manager
        @tracked_scripts_manager ||= TrackedScripts.new
      end

      def self.custom_repos_manager
        @custom_repos_manager ||= CustomRepos.new
      end

      def self.file_updater
        @file_updater ||= FileUpdater.new(client, resolver)
      end

      private_class_method :client, :resolver, :snapshot_manager,
                           :release_installer, :branch_installer,
                           :script_sync, :tracked_scripts_manager,
                           :custom_repos_manager, :file_updater
    end
  end
end
