=begin
util.rb: Core lich file for collection of utilities to extend Lich capabilities.
Entries added here should always be accessible from Lich::Util.feature namespace.
=end

require 'securerandom'
require_relative 'deep_freeze'

module Lich
  module Util
    include Enumerable

    # Normalizes and performs a lookup for an effect based on the provided value.
    #
    # Depending on the type of `val`, this method will:
    # - For String: Check if the normalized string matches any key in the effect's hash (case-insensitive, underscores/colons replaced with spaces).
    # - For Integer: Check if the effect is active for the given integer value.
    # - For Symbol: Check if the normalized symbol matches any key in the effect's hash (case-insensitive, underscores/colons replaced with spaces).
    #
    # Both the lookup value and the effect's hash keys are normalized the same way, so a
    # punctuation-free lookup (e.g. PSM feat names like "covert_art_escape_artist") still
    # matches an effect key that contains punctuation (e.g. "Covert Art: Escape Artist").
    #
    # @param effect [String] The name of the effect class (without the "Effects::" prefix).
    # @param val [String, Integer, Symbol] The value to look up; can be a string, integer, or symbol.
    # @return [Boolean] True if the lookup is successful, false otherwise.
    # @raise [RuntimeError] If `val` is not a String, Integer, or Symbol.
    def self.normalize_lookup(effect, val)
      caller_type = "Effects::#{effect}"
      case val
      when String, Symbol
        normalize = ->(str) { str.to_s.downcase.gsub(':', ' ').gsub('_', ' ').squeeze(' ').strip }
        (eval caller_type).to_h.transform_keys { |k| normalize.call(k) }.include?(normalize.call(val))
      when Integer
        #      seek = mappings.fetch(val, nil)
        (eval caller_type).active?(val)
      else
        fail "invalid lookup case #{val.class.name}"
      end
    end

    # Normalizes a given name by converting it to a lowercase string and replacing or removing certain characters.
    #
    # The normalization process handles the following cases:
    # - Converts spaces and hyphens to underscores.
    # - Removes colons and apostrophes.
    # - Converts symbols to strings.
    # - Converts all characters to lowercase.
    #
    # Examples:
    #   normalize_name("vault_kick")      #=> "vault_kick"
    #   normalize_name("vault kick")      #=> "vault_kick"
    #   normalize_name("vault-kick")      #=> "vault_kick"
    #   normalize_name(:vault_kick)       #=> "vault_kick"
    #   normalize_name(:vaultkick)        #=> "vaultkick"
    #   normalize_name("predator's eye")  #=> "predators_eye"
    #
    # @param name [String, Symbol] The name to normalize.
    # @return [String] The normalized name.
    def self.normalize_name(name)
      normal_name = name.to_s.downcase
      normal_name.gsub!(' ', '_') if name =~ (/\s/)
      normal_name.gsub!('-', '_') if name =~ (/-/)
      normal_name.gsub!(":", '') if name =~ (/:/)
      normal_name.gsub!("'", '') if name =~ (/'/)
      normal_name
    end

    # Generates a unique anonymous hook identifier string.
    #
    # @param prefix [String] an optional prefix to include in the identifier (default: '')
    # @return [String] a unique identifier in the format "Util::<prefix>-<timestamp>-<random_number>"
    # @example
    #   Util.anon_hook('event') #=> "Util::event-2024-06-13 12:34:56 +0000-1234"
    def self.anon_hook(prefix = '')
      now = Time.now
      "Util::#{prefix}-#{now}-#{Random.rand(10000)}"
    end

    # Self-closing tags that toggle persistent client display state (as
    # opposed to e.g. <prompt>, which self-heals on the next prompt). The raw
    # server chunk handed to a DownstreamHook proc is not split on line
    # boundaries, so the server is free to bundle one of these onto the same
    # chunk as text that quiet: true is about to drop. Silently discarding
    # that chunk would discard the tag with it -- e.g. dropping a trailing
    # mono-closing <output class=""/> that rode in on the same chunk as the
    # <prompt> a quiet-filtered range ends on leaves the frontend stuck in
    # mono mode until an unrelated, later mono tag happens to close it.
    #
    # Only the mono/formatting <output> tag is confirmed to hit this in
    # practice today. The list is deliberately an array of patterns (not a
    # single regex) so a future confirmed case -- e.g. pushBold/popBold or
    # pushStream/popStream -- can be added as its own entry without touching
    # the filtering logic below. Keep each pattern anchored to a single
    # self-closing `<tag .../>`, with no capturing groups (String#scan
    # returns captured subgroups instead of full matches when a pattern has
    # any, which would silently change what preserve_quiet_state_tags
    # returns), so a scan can't accidentally absorb surrounding text or
    # change shape.
    QUIET_STATE_TAGS = [
      /<output class="[^"]*"\s*\/>/ # mono/formatting state toggle
    ].freeze

    # Combines QUIET_STATE_TAGS into a single alternation, scanned once per
    # chunk. Scanning each pattern separately and concatenating the results
    # (the original approach) groups matches by pattern rather than by where
    # they actually appear -- invisible with a single pattern, but as soon as
    # a second entry is added, two tags from different patterns on the same
    # chunk would come back in pattern order instead of source order, which
    # matters when the tags are an open/close pair. A single combined scan
    # preserves the chunk's real left-to-right order regardless of how many
    # patterns are registered.
    QUIET_STATE_TAG_PATTERN = Regexp.union(QUIET_STATE_TAGS).freeze

    # Pulls any QUIET_STATE_TAGS matches out of a chunk that quiet: true is
    # about to drop, so callers can forward just the tags instead of the
    # whole chunk.
    #
    # The returned string is newline-terminated even though the matched tags
    # themselves never include one. Every other chunk that reaches this
    # pipeline is newline/CRLF-terminated as part of the game server's
    # line-oriented stream framing; a bare, unterminated tag is not a shape
    # of line this pipeline produced before this method existed. For
    # sentinel-supporting sessions (Saga, or any frontend run with
    # --sentinel -- see Frontend::ORIGIN_SENTINEL and
    # Game#prefix_origin_sentinel), every
    # forwarded line gets a leading origin-marker byte that the client is
    # expected to consume as routing metadata and strip before display. That
    # worked here once the segment was given the same line termination as
    # everything else the client already handles; without it, the client had
    # nothing to delimit an otherwise content-only segment, and the marker
    # byte fell through to the display as a literal, visible character.
    #
    # @param chunk [String] the raw stream chunk being suppressed.
    # @return [String, nil] the concatenated tag matches, in the order they
    #   appeared, terminated with a newline; or nil if none were found
    #   (signals DownstreamHook to drop the chunk entirely, same as before
    #   this method existed).
    def self.preserve_quiet_state_tags(chunk)
      tags = chunk.to_s.scan(QUIET_STATE_TAG_PATTERN)
      return nil if tags.empty?

      "#{tags.join}\n"
    end

    # The outcome of {capture_command}.
    #
    # @!attribute [r] lines
    #   @return [Array<String>] the captured lines; partial when not complete
    # @!attribute [r] status
    #   @return [Symbol] :complete, :no_start (timed out before start_pattern
    #     matched), :no_end (start_pattern matched, end_pattern never did) or
    #     :error (matching raised; logged, and the capture stopped at once)
    CommandCapture = Struct.new(:lines, :status, keyword_init: true) do
      # @return [Boolean] true when both the start and the end line were seen
      def complete?
        status == :complete
      end
    end

    # Hook priorities for {capture_command}. The observer runs before every
    # other hook so it sees each server string as the server sent it -- the
    # same view the script's downstream buffer gets, which is filled before
    # any hook runs. The suppressor runs after every other hook so that,
    # under quiet: true, other scripts' hooks still see the lines being hidden
    # from the frontend.
    CAPTURE_OBSERVER_PRIORITY = 1_000_000_000
    # See {CAPTURE_OBSERVER_PRIORITY}.
    CAPTURE_SUPPRESSOR_PRIORITY = -1_000_000_000

    # Text of the marker pushed onto the calling script's downstream buffer
    # right after the end line, so the script thread can consume exactly the
    # reply and nothing after it. A String (not a bare Object) so a stray
    # read can never raise on =~. Each capture, and each restart of one,
    # pushes its own copy and the drain matches it by identity, so a marker
    # left by an earlier send is consumed rather than taken as the end.
    CAPTURE_END_MARKER = "\u0000Lich::Util.capture_command:end\u0000".freeze

    # A prompt tag and its text. Removed from the start line before that
    # line is tested against end_pattern, so a prompt that shares the start
    # line's server string does not end the capture on that string (the
    # capture then ends at the next prompt, as before capture_command).
    CAPTURE_PROMPT_TAG = %r{<prompt\b[^>]*>.*?</prompt>}m

    # Longest time, in seconds, the calling script waits after the reply for
    # the suppressor to hide the end line when a hook between the observer
    # and the suppressor is slow; a hook slower than this still lets the end
    # line through. Kept short: if another hook squelches the end line the
    # suppressor never sees it, and every such call waits this long.
    CAPTURE_QUIET_SETTLE = 0.1

    # Issues a command and captures its reply, from the first line matching
    # start_pattern through the first line matching end_pattern.
    #
    # One state machine, run synchronously on the game thread by a downstream
    # hook, decides both what is captured and (with quiet: true) what is hidden
    # from the frontend. With quiet: true the call waits for up to
    # {CAPTURE_QUIET_SETTLE} seconds for the end line to be hidden before it
    # returns, so a slow hook between the two does not let the end line
    # through unless it takes longer than that. The start line is also tested
    # against end_pattern (with any prompt on its server string removed), so a
    # reply that is sometimes one line and sometimes several needs no special
    # casing.
    #
    # With use_fput, the capture restarts each time fput sends: on a refusal
    # fput resends ("...wait", "you may only type ahead") or stands first
    # ("struggle to stand"), so only the reply to the last send is captured,
    # as before capture_command. Lines already hidden under quiet: true stay
    # hidden.
    #
    # Lines are matched in the form the caller asked for: each server string
    # with its line terminator removed, as the script's buffer holds it, with
    # usexml: true; or each stripped text line with usexml: false. With
    # usexml: false an end_pattern that contains "<" is taken as markup and
    # is also matched against the raw server string of each line after the
    # start line, so the default /<prompt/ ends a text-mode capture at the
    # next prompt. Text mode relies on Lich::Common::Markup, which Lich loads
    # at boot.
    #
    # Unrelated game output that arrives between the start and end lines is
    # captured (and, with quiet: true, hidden) along with the reply.
    #
    # @param command [String] the command to send
    # @param start_pattern [Regexp] marks the first line of the reply
    # @param end_pattern [Regexp, Symbol] marks the last line of the reply;
    #   :ignore captures the start line only
    # @param include_end [Boolean] whether a separate end line is kept in the
    #   result (a start line that is also the end line is always kept; a
    #   text-mode capture that ends on a markup-only string has no end line)
    # @param timeout [Numeric] seconds to wait for the whole reply; 0 or nil
    #   returns at once (status :no_start), unlike the unlimited wait
    #   Timeout.timeout gave those values before capture_command. The command
    #   is still sent, and its reply is neither captured nor hidden.
    # @param silent [Boolean, nil] the script's silent flag for the duration
    #   (nil: unchanged)
    # @param usexml [Boolean] match and return raw XML (true) or stripped text
    # @param quiet [Boolean] hide the reply, start through end line, from the
    #   frontend (formatting state tags on hidden lines are still forwarded)
    # @param use_fput [Boolean] send with fput (true) or put
    # @return [CommandCapture]
    def self.capture_command(command, start_pattern, end_pattern = /<prompt/, include_end: true, timeout: 5, silent: nil, usexml: true, quiet: false, use_fput: true)
      single_line = end_pattern.eql?(:ignore)
      # Stripped text never contains markup, so in text mode a markup
      # end_pattern is also matched against the raw server string. A "<"
      # that only opens a named group or lookbehind ("(?<") is not markup.
      markup_end = !usexml && end_pattern.is_a?(Regexp) && end_pattern.source.gsub('(?<', '').include?('<')

      script = Script.current
      name = "Util::capture_command-#{SecureRandom.uuid}"
      strip_key = name # private strip_xml multiline buffer; never "main"
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout.to_f
      lock = Mutex.new
      settled = ConditionVariable.new # signalled when the suppressor takes the flag
      done = Queue.new
      lines = []
      marker = CAPTURE_END_MARKER.dup # replaced on every restart
      phase = :waiting # -> :capturing -> :done, or -> :abandoned on timeout
      suppress_current = false

      line_matches = lambda do |text, pattern|
        !pattern.eql?(:ignore) && text.match?(pattern)
      end

      # Advance the state machine over one text line. Returns true when this
      # line was part of the reply.
      advance = lambda do |text|
        case phase
        when :waiting
          return false unless text.match?(start_pattern)

          lines << text.rstrip
          phase = (single_line || line_matches.call(text.gsub(CAPTURE_PROMPT_TAG, ''), end_pattern)) ? :done : :capturing
          true
        when :capturing
          if line_matches.call(text, end_pattern)
            lines << text.rstrip if include_end
            phase = :done
          else
            lines << text.rstrip
          end
          true
        else
          false
        end
      end

      # Never raises: DownstreamHook.run removes a raising hook (and reports
      # the error to the frontend), which would leave the caller to wait out
      # the timeout with quiet output leaking.
      observer = proc do |chunk|
        lock.synchronize do
          suppress_current = false
          if %i[waiting capturing].include?(phase)
            begin
              # The script's buffer holds each XML server string chomped
              # (Script.new_downstream_xml); match the same view, so a pattern
              # anchored with $ behaves as it does against the buffer.
              texts = if usexml
                        [chunk.chomp]
                      else
                        Lich::Common::Markup.strip_xml(chunk, type: strip_key).to_s.split("\r\n").reject(&:empty?)
                      end
              was_capturing = phase == :capturing
              in_reply = texts.map { |text| advance.call(text) }.any?
              # Only after the start line's server string, as the start
              # line itself is never ended by a prompt riding on it.
              phase = :done if markup_end && was_capturing && phase == :capturing && chunk.chomp.match?(end_pattern)
              suppress_current = quiet && (was_capturing || in_reply)
            rescue StandardError => e
              Lich.log "error: Util.capture_command(#{command.inspect}): #{e.class}: #{e.message}"
              phase = :error
            end
            if %i[done error].include?(phase)
              # Also on :error, so a waiting fput reads a line and returns.
              script&.downstream_buffer&.push(marker)
              done << phase
            end
          end
        end
        chunk
      end

      suppressor = proc do |chunk|
        suppress = lock.synchronize do
          s = suppress_current
          suppress_current = false
          settled.broadcast
          s
        end
        suppress ? preserve_quiet_state_tags(chunk) : chunk
      end

      if script
        save_script_silent = script.silent
        save_want_downstream = script.want_downstream
        save_want_downstream_xml = script.want_downstream_xml
        script.silent = silent unless silent.nil?
        script.want_downstream = !usexml
        script.want_downstream_xml = usexml
      end

      completed = false
      begin
        DownstreamHook.add(name, observer, persist: false, priority: CAPTURE_OBSERVER_PRIORITY)
        DownstreamHook.add("#{name}-quiet", suppressor, persist: false, priority: CAPTURE_SUPPRESSOR_PRIORITY) if quiet

        remaining = -> { deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        if use_fput && script
          # fput calls on_send before every send, resends and 'stand'
          # included, after clearing the script's buffer. Restart the capture
          # there: whatever it matched so far answered an earlier send. The
          # game thread can complete that earlier capture between fput's
          # clear and this restart, leaving its marker in the buffer, so the
          # restart takes a fresh marker and the drain skips the stale one.
          # fput is not interrupted when the capture completes, so a refusal
          # that matched cannot cancel the resend.
          restart = lambda do |_sent|
            lock.synchronize do
              next if phase == :error

              phase = :waiting
              lines.clear
              marker = CAPTURE_END_MARKER.dup
              suppress_current = false
              done.clear
              $strip_xml_multiline&.delete(strip_key)
            end
          end
          sent = fput(command, timeout: [remaining.call, 0.001].max, interrupt: -> { remaining.call <= 0 },
                               on_send: restart, failures: :symbol)
          # Out of time before fput saw a reply to its last send (a roundtime
          # longer than the timeout): anything captured answered a refusal.
          restart.call(nil) if sent == :interrupted
        else
          put(command)
        end
        # A guarded script is checked for cancellation while it waits, as
        # Script#gets does; anything it raises reaches the ensure below.
        guarded = script.respond_to?(:execution_guard_active?) && script.execution_guard_active?
        outcome = nil
        loop do
          script.check_execution_guard! if guarded
          left = [remaining.call, 0].max
          outcome = done.pop(timeout: guarded ? [left, script.class::EXECUTION_GUARD_POLL_INTERVAL].min : left)
          break if outcome || remaining.call <= 0
        end
        completed = outcome == :done
      ensure
        begin
          if quiet
            # The observer releases this thread from the top of the hook
            # chain; give the suppressor at the bottom up to
            # CAPTURE_QUIET_SETTLE to hide the line the observer flagged.
            settle_until = Process.clock_gettime(Process::CLOCK_MONOTONIC) + CAPTURE_QUIET_SETTLE
            lock.synchronize do
              while suppress_current && (left = settle_until - Process.clock_gettime(Process::CLOCK_MONOTONIC)).positive?
                settled.wait(lock, left)
              end
            end
          end
        ensure
          # Runs however the settle wait ends, an interrupt included.
          DownstreamHook.remove(name)
          DownstreamHook.remove("#{name}-quiet")
          status = lock.synchronize do
            # The reply may have completed in the instant the wait timed out.
            completed ||= phase == :done
            failed = phase == :error
            phase = :abandoned unless completed
            suppress_current = false
            if completed then :complete
            elsif failed then :error
            elsif lines.empty? then :no_start
            else :no_end
            end
          end
          $strip_xml_multiline&.delete(strip_key)
          if script
            begin
              # Consume the reply from the script's own buffer, as the old
              # get-loop did: through this capture's end marker when complete
              # (a stale one from an earlier send is consumed on the way),
              # else all of it. Before the restore: with both want flags off, gets? sleeps.
              while (line = script.gets?)
                break if completed && line.equal?(marker)
              end
            ensure
              script.silent = save_script_silent unless silent.nil?
              script.want_downstream = save_want_downstream
              script.want_downstream_xml = save_want_downstream_xml
            end
          end
        end
      end
      CommandCapture.new(lines: lock.synchronize { lines.dup }, status: status)
    end

    # Issues a command and returns its captured reply lines. See
    # {capture_command} for the matching rules; use that method directly to
    # tell a complete reply from a timed-out one.
    #
    # @param command [String] the command to send
    # @param start_pattern [Regexp] marks the first line of the reply
    # @param end_pattern [Regexp, Symbol] marks the last line of the reply;
    #   :ignore captures the start line only
    # @param include_end [Boolean] whether a separate end line is kept in the
    #   result (a start line that is also the end line is always kept; a
    #   text-mode capture that ends on a markup-only string has no end line)
    # @param timeout [Numeric] seconds to wait for the whole reply; 0 or nil
    #   returns at once with an empty result (the command is still sent)
    # @param silent [Boolean, nil] the script's silent flag for the duration
    #   (nil: unchanged)
    # @param usexml [Boolean] match and return raw XML (true) or stripped text
    # @param quiet [Boolean] hide the reply, start through end line, from the
    #   frontend (formatting state tags on hidden lines are still forwarded)
    # @param use_fput [Boolean] send with fput (true) or put
    # @return [Array<String>] the captured lines (partial or empty on timeout)
    def self.issue_command(command, start_pattern, end_pattern = /<prompt/, include_end: true, timeout: 5, silent: nil, usexml: true, quiet: false, use_fput: true)
      capture_command(command, start_pattern, end_pattern, include_end: include_end, timeout: timeout, silent: silent,
                                                           usexml: usexml, quiet: quiet, use_fput: use_fput).lines
    end

    def self.quiet_command_xml(command, start_pattern, end_pattern = /<prompt/, include_end = true, timeout = 5, silent = true)
      return issue_command(command, start_pattern, end_pattern, include_end: include_end, timeout: timeout, silent: silent, usexml: true, quiet: true)
    end

    def self.quiet_command(command, start_pattern, end_pattern, include_end = true, timeout = 5, silent = true)
      return issue_command(command, start_pattern, end_pattern, include_end: include_end, timeout: timeout, silent: silent, usexml: false, quiet: true)
    end

    # Retrieves the current silver count from the game output by issuing the 'info' command
    # and parsing the response. Uses a downstream hook to filter and extract the silver value.
    #
    # @param timeout [Integer] the maximum number of seconds to wait for a response (default: 3)
    # @return [Integer] the amount of silver, or 0 if not found or on timeout
    #
    # @example
    #   silver = Util.silver_count
    #
    # This method temporarily silences output, sets up a downstream hook to capture the relevant
    # lines, and restores the previous silence state after completion.
    def self.silver_count(timeout = 3)
      silence_me unless (undo_silence = silence_me)
      result = ''
      name = self.anon_hook
      filter = false

      start_pattern = /^\s*Name\:/
      end_pattern = /^\s*Mana\:\s+\-?[0-9]+\s+Silver\:\s+([0-9,]+)/
      ttl = Time.now + timeout
      begin
        # main thread
        DownstreamHook.add(name, proc { |line|
          if filter
            if line =~ end_pattern
              result = $1.dup
              DownstreamHook.remove(name)
              filter = false
            else
              next(nil)
            end
          elsif line =~ start_pattern
            filter = true
            next(nil)
          else
            line
          end
        }, persist: false) # scoped to this command; removed in the ensure below
        # script thread
        fput 'info'
        loop {
          # non-blocking check, this allows us to
          # check the time even when the buffer is empty
          line = get?
          break if line && line =~ end_pattern
          break if Time.now > ttl
          sleep(0.01) # prevent a tight-loop
        }
      ensure
        DownstreamHook.remove(name)
        silence_me if undo_silence
      end
      return result.gsub(',', '').to_i
    end

    # Installs and optionally requires a set of Ruby gems specified in a Hash.
    #
    # @param gems_to_install [Hash{String => Boolean}]
    #   A hash where each key is the name of a gem to install (as a String),
    #   and each value is a Boolean indicating whether to require the gem after installation.
    #
    # @raise [ArgumentError]
    #   If the argument is not a Hash, or if the hash contains keys that are not Strings
    #   or values that are not TrueClass/FalseClass.
    #
    # @raise [RuntimeError]
    #   If any gems fail to install, raises an error listing the failed gems.
    #
    # @example
    #   install_gem_requirements({ "json" => true, "colorize" => false })
    #
    # This method will attempt to install any gems that are not already installed.
    # If a gem is installed and its value is true, it will be required.
    # If installation fails for any gem, an error will be raised listing all failed gems.
    def self.install_gem_requirements(gems_to_install, user_install: false)
      raise ArgumentError, "install_gem_requirements must be passed a Hash" unless gems_to_install.is_a?(Hash)
      require "rubygems"
      require "rubygems/dependency_installer"
      installer = Gem::DependencyInstaller.new({ :user_install => user_install, :document => nil })
      installed_gems = Gem::Specification.map { |gem| gem.name }.sort.uniq
      failed_gems = []

      gems_to_install.each do |gem_name, should_require|
        unless gem_name.is_a?(String) && (should_require.is_a?(TrueClass) || should_require.is_a?(FalseClass))
          raise ArgumentError, "install_gem_requirements must be passed a Hash with String key and TrueClass/FalseClass as value"
        end
        begin
          unless installed_gems.include?(gem_name)
            respond("--- Lich: Installing missing ruby gem '#{gem_name}' now, please wait!") if defined?(Script)
            Lich.log("--- Lich: Installing missing ruby gem '#{gem_name}' now, please wait!")
            result = installer.install(gem_name)
            Gem.clear_paths
            Gem::Specification.reset
            Gem::Specification.find_by_name(gem_name).activate
            Lich.log("RubyGem Installer Result: #{result.inspect}")
            unless Gem::Specification.map { |gem| gem.name }.sort.uniq.include?(gem_name)
              Lich.log("RubyGems failed, attempting system method instead!")
              result = system(File.join(RbConfig::CONFIG['bindir'], 'gem'), 'install', gem_name)
              Lich.log("SYSTEM Call Result: #{result.inspect}")
              Gem.clear_paths
              Gem::Specification.reset
              Gem::Specification.find_by_name(gem_name).activate
            end
            respond("--- Lich: Done installing '#{gem_name}' gem!") if defined?(Script)
            Lich.log("--- Lich: Done installing '#{gem_name}' gem!")
          end
          require gem_name if should_require
        rescue LoadError, StandardError
          respond("--- Lich: error: Failed to install/require Ruby gem: #{gem_name}") if defined?(Script)
          respond("--- Lich: error: #{$!}") if defined?(Script)
          Lich.log("installed_gems.include?(#{gem_name}): #{installed_gems.include?(gem_name)} - #{installed_gems.find_all { |gem| gem == gem_name }.inspect}")
          Lich.log("error: Failed to install/require Ruby gem: #{gem_name}")
          Lich.log("error: #{$!}")
          failed_gems.push(gem_name)
        end
      end
      unless failed_gems.empty?
        if defined?(Script.current.name) && Script.current.name != "unknown"
          raise("Please install the failed gems: #{failed_gems.join(', ')} manually to run #{$lich_char}#{Script.current.name}")
        else
          raise("Please install the failed gems: #{failed_gems.join(', ')} manually to continue.")
        end
      end
    end
  end
end
