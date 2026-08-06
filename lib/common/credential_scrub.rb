# frozen_string_literal: true

module Lich
  module Common
    # Redacts startup credentials once the login sequence no longer needs them.
    #
    # Lich keeps startup credentials where a running script can read them:
    # +@launch_data+ and +@argv_options+ are instance variables on the top-level
    # +main+ object, and +ARGV+ is a global constant. All three outlive login, so
    # the single-use eaccess key and the reusable account password stay readable
    # for the rest of the session.
    #
    # Values are overwritten in place rather than reassigned because other
    # objects hold references to the same Array, Hash, and String instances (the
    # login GUI keeps the launch data array; the argv option pipeline threads one
    # options hash through three stages). Replacing a container would leave those
    # references pointing at unscrubbed copies.
    #
    # Scope: this closes script-readable and log-readable paths. It does not
    # guarantee the bytes are gone from process memory. Earlier copies may
    # survive in socket write buffers, in a spawned frontend's argv, or in
    # unreclaimed heap.
    module CredentialScrub
      # Replacement text for a redacted value.
      REDACTED = '[scrubbed]'

      # launch_data entry holding the single-use eaccess key.
      LAUNCH_DATA_SECRET = /\AKEY=/i

      # argv entries of the form --flag=secret. Deliberately excludes
      # --account=, which is an account identifier rather than a credential.
      ARGV_SECRET = /\A(--(?:password|master-password)=)(.+)\z/i

      # argv_options keys holding reusable credentials.
      OPTION_SECRET_KEYS = [:password].freeze

      class << self
        # Overwrites the KEY= entry of a launch data array in place.
        #
        # @param launch_data [Array<String>, nil] launch lines; nil is tolerated
        #   because direct host/port and --pipe startups never build one
        # @return [Integer] number of entries rewritten
        def scrub_launch_data!(launch_data)
          return 0 unless launch_data.is_a?(Array)

          scrubbed = 0
          launch_data.each_with_index do |line, index|
            next unless line.is_a?(String) && line.match?(LAUNCH_DATA_SECRET)

            scrubbed += 1 if overwrite(launch_data, index, "KEY=#{REDACTED}")
          end
          scrubbed
        end

        # Overwrites secret-bearing argv values in place, preserving the flag
        # prefix so later ARGV.include? and ARGV.find checks behave unchanged.
        #
        # @param argv [Array<String>, nil] argument vector, normally ARGV
        # @return [Integer] number of entries rewritten
        def scrub_argv!(argv)
          return 0 unless argv.is_a?(Array)

          scrubbed = 0
          argv.each_with_index do |arg, index|
            next unless arg.is_a?(String)

            match = ARGV_SECRET.match(arg)
            next if match.nil?

            scrubbed += 1 if overwrite(argv, index, "#{match[1]}#{REDACTED}")
          end
          scrubbed
        end

        # Overwrites secret values in an options hash in place.
        #
        # @param options [Hash, nil] the argv options hash
        # @return [Array<Symbol>] keys that were rewritten
        def scrub_options!(options)
          return [] unless options.is_a?(Hash)

          OPTION_SECRET_KEYS.select do |key|
            value = options[key]
            next false unless value.is_a?(String) && value != REDACTED

            begin
              options[key] = REDACTED
              true
            rescue FrozenError
              false
            end
          end
        end

        # Overwrites a file's contents and removes it. Never raises.
        #
        # Overwrite-then-delete is best effort: copy-on-write, journaling, and
        # flash translation layers may retain the original blocks. The retry loop
        # exists because Windows refuses deletion while a spawned frontend still
        # holds the file open.
        #
        # @param path [String, nil] file to remove
        # @param attempts [Integer] delete attempts before giving up
        # @return [Boolean] true when the file is gone
        def shred_file(path, attempts: 3)
          path = path.to_s
          return false if path.empty?

          overwrite_contents(path)
          attempts.times do |attempt|
            begin
              File.delete(path) if File.exist?(path)
              return true unless File.exist?(path)
            rescue StandardError
              nil
            end
            sleep 0.05 unless attempt == attempts - 1
          end
          !File.exist?(path)
        rescue StandardError
          false
        end

        private

        # Rewrites container[index], mutating the existing String when possible so
        # that other holders of that String also lose the secret.
        #
        # @return [Boolean] true when the value changed
        def overwrite(container, index, value)
          current = container[index]
          return false if current == value

          begin
            current.replace(value)
          rescue FrozenError
            container[index] = value
          end
          true
        end

        # @return [void]
        def overwrite_contents(path)
          return unless File.file?(path)

          size = File.size(path)
          return if size.zero?

          File.open(path, 'r+b') do |file|
            file.write("\x00" * size)
            file.flush
            file.fsync
          end
        rescue StandardError, NotImplementedError
          nil
        end
      end
    end
  end
end
