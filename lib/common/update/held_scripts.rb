# frozen_string_literal: true

=begin
  Remembers what the sync decided for scripts whose newest version needs a
  newer Lich than the one running.

  Without it, every login downloads such a script again, and may walk its
  history again, only to reach the same decision. A decision is reused while
  nothing it rests on has changed: the repository's newest version of the
  file, the running Lich version, and the local copy.

  Kept with the tracked-script lists, in UserVars (per game and character):

    UserVars.held_scripts = {
      'scripts' => {
        'foo.lic' => {
          'remote_sha'   => blob SHA of the repository's newest version,
          'lich_version' => LICH_VERSION when the decision was made,
          'local_sha'    => blob SHA of the local copy then, nil if absent,
          'required'     => the floor of the repository's newest version,
          'outcome'      => 'held', 'installed' or 'none',
          'commit'       => the commit installed instead ('installed' only)
        }
      }
    }

  Outcomes:
    held      - a local copy that runs on this Lich was kept
    installed - the newest version this Lich can run was installed
    none      - no version this Lich can run was found, nothing was written
=end

module Lich
  module Util
    module Update
      class HeldScripts
        OUTCOMES = %w[held installed none].freeze

        # Starts with nothing to save; decisions already stored are read
        # from UserVars as they are asked for.
        def initialize
          @changed = false
        end

        # Returns the remembered decision for a script, if it still stands.
        #
        # @param repo_key [String] repository key
        # @param filename [String] script filename
        # @param remote_sha [String] blob SHA of the repository's newest version now
        # @param local_sha [String, nil] blob SHA of the local copy now, nil if absent
        # @return [Hash, nil] the stored entry, or nil when there is none or
        #   the remote version, the running Lich or the local copy has changed
        def lookup(repo_key, filename, remote_sha:, local_sha:)
          entry = entries(repo_key)[filename]
          return nil unless entry.is_a?(Hash) && OUTCOMES.include?(entry['outcome'])
          return nil unless entry['remote_sha'] == remote_sha && entry['lich_version'] == LICH_VERSION
          return nil unless entry['local_sha'] == local_sha

          entry
        end

        # Records a decision for the running Lich version.
        #
        # @param repo_key [String] repository key
        # @param filename [String] script filename
        # @param remote_sha [String] blob SHA of the repository's newest version
        # @param local_sha [String, nil] blob SHA of the local copy the decision
        #   leaves in place, nil when there is none
        # @param required [String] the floor of the repository's newest version
        # @param outcome [String] one of OUTCOMES
        # @param commit [String, nil] the commit installed, for 'installed'
        # @return [void]
        def remember(repo_key, filename, remote_sha:, local_sha:, required:, outcome:, commit: nil)
          entry = {
            'remote_sha' => remote_sha, 'lich_version' => LICH_VERSION, 'local_sha' => local_sha,
            'required' => required, 'outcome' => outcome
          }
          entry['commit'] = commit if commit
          return if entries(repo_key)[filename] == entry

          store = writable_store
          store[repo_key] = {} unless store[repo_key].is_a?(Hash)
          store[repo_key][filename] = entry
          @changed = true
        end

        # Drops the decision for a script, once its newest version installs.
        #
        # @param repo_key [String] repository key
        # @param filename [String] script filename
        # @return [void]
        def forget(repo_key, filename)
          return unless entries(repo_key).key?(filename)

          writable_store[repo_key].delete(filename)
          @changed = true
        end

        # Drops decisions for scripts the repository's sync no longer covers
        # (untracked since, or gone from the repository).
        #
        # @param repo_key [String] repository key
        # @param filenames [Array<String>] the scripts this sync covers
        # @return [void]
        def prune(repo_key, filenames)
          (entries(repo_key).keys - filenames).each { |filename| forget(repo_key, filename) }
        end

        # Persists the decisions if any changed since the last save.
        #
        # @return [void]
        def save
          return unless @changed

          Vars.save
          @changed = false
        end

        private

        # @param repo_key [String] repository key
        # @return [Hash] filename => stored entry; empty when nothing is stored
        # @api private
        def entries(repo_key)
          store = UserVars.held_scripts
          repo = store.is_a?(Hash) ? store[repo_key] : nil
          repo.is_a?(Hash) ? repo : {}
        end

        # Created only when a decision is written, so a sync that holds
        # nothing leaves the user's vars as they were.
        #
        # @return [Hash] the stored decisions, to change in place
        # @api private
        def writable_store
          UserVars.held_scripts = {} unless UserVars.held_scripts.is_a?(Hash)
          UserVars.held_scripts
        end
      end
    end
  end
end
