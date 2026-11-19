# frozen_string_literal: true

module Lich
  module Genie
    # The global gag and substitute lists (Remix Globals.GagRegExp / Globals.SubstituteRegExp,
    # Lists/Globals.cs:1414-1850 R) and what they do to DISPLAYED text (Game.cs:3075-3103,
    # 3173-3206 R). Model A (design Decision 6): Lich applies them to the client-bound downstream
    # line in a DownstreamHook ({#apply}); scripts and #triggers never see the change (Remix
    # gags and substitutes after TriggerParse, Game.cs:3062-3101 R). The game-state capture asks
    # {#displayed} what the main window would show (a gagged line, or one substituted to blank,
    # leaves m_bLastRowWasPrompt alone).
    #
    # List semantics (ported, not approximated):
    #   * Add strips a leading `/` and a trailing `/i` (ignore case) or `/`, rejects a text
    #     ValidateRegExp refuses ({NetRegex}; Add returns false and the router echoes "Invalid
    #     regexp in gag/substitute"), and replaces an entry with the same text IN PLACE, else
    #     appends -- list order is add order (Globals.cs:1444-1478, 1667-1701 R); an empty text
    #     is a valid regex that matches every line;
    #   * a new or replaced entry is active, whatever its class's state (the Gag/Substitute ctor
    #     defaults; only the next class event switches it off, {ClassList});
    #   * Remove drops EVERY entry whose text equals the argument exactly -- no `/`..`/i`
    #     stripping (Globals.cs:1506-1517, 1729-1740 R);
    #   * ToggleClass compares the class name exactly, case included (Globals.cs:1480-1504,
    #     1703-1727 R; the triggers compare lower-cased).
    #
    # Display semantics: a gag is tested on Utility.Trim(text) (CR/LF only) of any window but the
    # thoughts window; a substitute replaces in Utility.Trim(text) with .NET's replacement
    # language ({NetReplace}) after ParseGlobalVars of its replacement AT DISPLAY TIME, and a text
    # it changed gets back a leading/trailing CRLF it had (Game.cs:3173-3206 R). Remix applies
    # both to each piece of text it prints (a row is printed in pieces at its markup); {#apply}
    # tests a gag on the line's whole display text and substitutes in each text run between
    # tags -- the recorded approximation (open-items.md F1). A gag hides TEXT only: Remix still
    # parses the row's markup (stream, component, compass, prompt state) and only skips the
    # printed piece, so the client keeps every tag of a gagged line and loses its text runs;
    # a line whose display text is blank is never gagged or substituted (Remix
    # prints nothing for it, Game.cs:2811 R).
    #
    # Thread-safe: one mutex; matching runs on snapshots outside it. Every pattern has a match
    # timeout ({MATCH_TIMEOUT_SECONDS}; a {NetRegex::Emulated} one through
    # {NetRegex::Emulated#with_timeout}): a timed-out match counts as no match, and
    # {TIMEOUT_LIMIT} of them in a row shut the entry off until it is added again ({#on_disabled}
    # is told once) -- like the #triggers (decided divergence, open-items.md K1: Remix would hang its
    # display thread; Lich's parser thread runs these). The gag result of a text is memoized
    # until the next list change, so the game-state capture's test of a row's text and the
    # client hook's test of the same line match once.
    class StreamFilters
      Gag = Struct.new(:text, :ignore_case, :regex, :klass, :active, :timeouts, :disabled)
      Sub = Struct.new(:text, :replacement, :ignore_case, :regex, :klass, :active, :timeouts, :disabled)

      # Regexp#timeout of a gag/substitute pattern (seconds).
      MATCH_TIMEOUT_SECONDS = 1.0
      # Consecutive timed-out matches after which an entry stops being matched (as
      # {Triggers::TIMEOUT_LIMIT}). A match that completes resets the count.
      TIMEOUT_LIMIT = 3
      # Entries in each memo before it is emptied (bounded memory).
      MEMO_LIMIT = 256
      # A markup tag of a client-bound line.
      TAG = /<[^>]*>/.freeze
      # Game.cs's WindowTarget.Thoughts: gags skip it (Game.cs:3075 R).
      THOUGHTS = :thoughts
      CRLF = "\r\n"
      ENTITIES = { 'lt' => '<', 'gt' => '>', 'amp' => '&', 'quot' => '"', 'apos' => "'" }.freeze

      def initialize
        @gags = []
        @subs = []
        @mutex = Mutex.new
        @save_mutex = Mutex.new # orders whole gag/substitute saves, like Triggers#save
        @globals = ->(text) { text }
        @generation = 0 # bumped by every change that can alter a match result
        @gag_memo = {} # CR/LF-trimmed text => whether an active gag hides it
        @sub_miss = {} # CR/LF-trimmed texts no active substitute matches
        @on_disabled = nil
      end

      # @return [#call] callable(text) => Globals.ParseGlobalVars(text), used on a substitute's
      #   replacement at display time (Game.cs:3185 R); identity until the owner sets it
      attr_accessor :globals
      # @return [#call, nil] callable(kind, text) told ONCE when an entry is shut off after
      #   {TIMEOUT_LIMIT} consecutive timed-out matches (kind "gag" or "substitute"); called
      #   outside the lock, on the matching thread (Lich's parser thread: it must not block)
      attr_accessor :on_disabled

      # The text Add keeps (Globals.cs:1446-1459 R) and whether it ignores case.
      # @param pattern [String]
      # @return [Array(String, Boolean)]
      def self.normalize(pattern)
        text = pattern.to_s
        text = text[1..] if text.start_with?('/')
        return [text[0...-2], true] if text.end_with?('/i')

        [text.end_with?('/') ? text[0...-1] : text, false]
      end

      # @param text [String] a normalized text
      # @param ignore_case [Boolean]
      # @return [Regexp, NetRegex::Emulated, NetRegex::Unsupported, nil] nil when
      #   ValidateRegExp refuses +text+ (Utility.cs:113-126 R: `new Regex(text)`); a Regexp or
      #   an Emulated pattern carries the {MATCH_TIMEOUT_SECONDS} match timeout (a private copy:
      #   NetRegex's cached object is shared)
      def self.compile(text, ignore_case)
        NetRegex.compile(text) # ValidateRegExp: no options
        compiled = NetRegex.compile(text, ignore_case: ignore_case)
        case compiled
        when Regexp then Regexp.new(compiled, timeout: MATCH_TIMEOUT_SECONDS)
        when NetRegex::Emulated then compiled.with_timeout(MATCH_TIMEOUT_SECONDS)
        else compiled
        end
      rescue StandardError
        nil
      end

      # GagRegExp.Add (Globals.cs:1667-1701 R).
      # @param pattern [String]
      # @param ignore_case [Boolean] Add's IgnoreCase parameter (`#gag`'s fourth argument TRUE
      #   lands here, Command.cs:1791-1793 R)
      # @param klass [String]
      # @return [Boolean] false (nothing added) when the text is not a valid regex
      def add_gag(pattern, ignore_case: false, klass: '')
        text, slash_i = self.class.normalize(pattern)
        ignore_case ||= slash_i
        regex = self.class.compile(text, ignore_case)
        return false if regex.nil?

        entry = Gag.new(text, ignore_case, regex, klass.to_s, true, 0, false)
        @mutex.synchronize { upsert(@gags, entry) }
        true
      end

      # SubstituteRegExp.Add (Globals.cs:1444-1478 R).
      # @return [Boolean] false (nothing added) when the text is not a valid regex
      def add_sub(pattern, replacement, ignore_case: false, klass: '')
        text, slash_i = self.class.normalize(pattern)
        ignore_case ||= slash_i
        regex = self.class.compile(text, ignore_case)
        return false if regex.nil?

        entry = Sub.new(text, replacement.to_s, ignore_case, regex, klass.to_s, true, 0, false)
        @mutex.synchronize { upsert(@subs, entry) }
        true
      end

      # GagRegExp.Remove: every entry whose text is +text+ exactly.
      # @return [void]
      def remove_gag(text)
        @mutex.synchronize { changed! if @gags.reject! { |gag| gag.text == text.to_s } }
      end

      # SubstituteRegExp.Remove.
      # @return [void]
      def remove_sub(text)
        @mutex.synchronize { changed! if @subs.reject! { |sub| sub.text == text.to_s } }
      end

      # @return [void]
      def clear_gags
        @mutex.synchronize { @gags.clear.tap { changed! } }
      end

      # @return [void]
      def clear_subs
        @mutex.synchronize { @subs.clear.tap { changed! } }
      end

      # @return [Array<Gag>] snapshots, list order (ListGags, Command.cs:3120-3157 R)
      def gags
        @mutex.synchronize { @gags.map(&:dup) }
      end

      # @return [Array<Sub>] snapshots, list order (ListSubstitutes, Command.cs:3081-3118 R)
      def subs
        @mutex.synchronize { @subs.map(&:dup) }
      end

      # ToggleClass of both lists (Command_EventClassChange, FormMain.cs:7510-7514 R): every entry
      # whose class is exactly +name+ ("" = the class-less ones) takes +state+.
      # @return [void]
      def toggle_class(name, state)
        key = name.to_s
        on = state ? true : false
        @mutex.synchronize do
          @gags.each { |gag| gag.active = on if gag.klass == key }
          @subs.each { |sub| sub.active = on if sub.klass == key }
          changed!
        end
      end

      # GagRegExp.Load (Globals.cs:1755-1806 R): rows with more than one ParseArgs token add
      # [1] with class [2]; merged in, no clear. A malformed row ends the load there.
      # @param path [String, nil]
      # @return [Boolean] Remix's Load result
      def load_gags(path)
        each_row(path) { |args| add_gag(args[1], klass: args.length > 2 ? args[2] : '') if args.length > 1 }
      end

      # SubstituteRegExp.Load (Globals.cs:1532-1582 R): rows with more than two tokens add [1]
      # -> [2] with class [3].
      # @param path [String, nil]
      # @return [Boolean]
      def load_subs(path)
        each_row(path) { |args| add_sub(args[1], args[2], klass: args.length > 3 ? args[3] : '') if args.length > 2 }
      end

      # GagRegExp.Save (Globals.cs:1808-1848 R): `#gag {text}` (`/text/i` when it ignores case)
      # plus ` {class}` when there is one.
      # @param path [String, nil]
      # @return [Boolean] false when there is no path or the write failed
      def save_gags(path)
        write(path) { gags.map { |gag| class_suffix("#gag {#{shown(gag)}}", gag.klass) } }
      end

      # SubstituteRegExp.Save (Globals.cs:1584-1638 R): `#subs {text} {replacement}` [+ class].
      # @param path [String, nil]
      # @return [Boolean]
      def save_subs(path)
        write(path) { subs.map { |sub| class_suffix("#subs {#{shown(sub)}} {#{sub.replacement}}", sub.klass) } }
      end

      # Whether an active gag hides +text+ (Game.cs:3075-3092 R): tested on Utility.Trim(text);
      # never in the thoughts window. Memoized per text until the next list change.
      # @param text [String]
      # @param target [Symbol, String] the window
      # @return [Boolean]
      def gagged?(text, target = :main)
        return false if target == THOUGHTS

        line = Text.trim_crlf(text.to_s)
        list, generation, known = @mutex.synchronize { [@gags.dup, @generation, @gag_memo[line]] }
        return known unless known.nil?
        return false if list.empty?

        hidden = list.any? { |gag| gag.active && !gag.disabled && matches?(gag, line) }
        @mutex.synchronize { remember(@gag_memo, line, hidden) if @generation == generation }
        hidden
      end

      # Game.SendText's echo test (Game.cs:481-511 R): a send made by a script (+origin+ its name)
      # is not echoed when ANY gag -- active or not -- matches the origin (a shut-off one is no
      # longer matched).
      # @param origin [String]
      # @return [Boolean]
      def hides_echo_of?(origin)
        name = origin.to_s
        return false if name.empty?

        @mutex.synchronize { @gags.dup }.any? { |gag| !gag.disabled && matches?(gag, name) }
      end

      # Game.ParseSubstitutions (Game.cs:3173-3206 R). A substitute's replacement is
      # ParseGlobalVars'd only once its pattern matched (side-effect free, so equivalent).
      # @param text [String]
      # @param expand [Boolean] ParseGlobalVars the replacement first (Remix always does)
      # @return [String]
      def substitute(text, expand: true)
        text = text.to_s
        list, generation, missed = @mutex.synchronize { [@subs.dup, @generation, @sub_miss.key?(Text.trim_crlf(text))] }
        return text if missed || list.empty? || Text.net_trim(text).empty?

        original = Text.trim_crlf(text)
        hit = false
        list.each do |sub|
          next unless sub.active && !sub.disabled

          trimmed = Text.trim_crlf(text)
          replaced = safe_replace(sub, trimmed, -> { expand ? @globals.call(sub.replacement).to_s : sub.replacement })
          next if replaced.nil?

          hit = true
          start_crlf = text.start_with?(CRLF)
          end_crlf = text.end_with?(CRLF)
          text = replaced
          text = "#{CRLF}#{text}" if start_crlf
          text = "#{text}#{CRLF}" if end_crlf
        end
        @mutex.synchronize { remember(@sub_miss, original, true) if !hit && @generation == generation }
        text
      end

      # What PrintTextToWindow passes on to the window (Game.cs:3075-3103 R): nil when gagged,
      # else the substituted text.
      # @param text [String]
      # @param target [Symbol, String]
      # @param expand [Boolean] see {#substitute}
      # @return [String, nil]
      def displayed(text, target = :main, expand: true)
        return nil if gagged?(text, target)

        substitute(text, expand: expand)
      end

      # The DownstreamHook rewrite of one client-bound line (see the class comment): the line
      # itself when its display text is blank or nothing applies; when a gag hides its display
      # text, its tags only (every text run dropped, the line end too) -- nil only for a line with
      # no tag at all; else the line with each text run between tags substituted (entities
      # decoded for the match, the changed run re-encoded). Never raises: Lich's DownstreamHook.run
      # removes a hook that raises for the rest of the session (downstreamhook.rb), so a fault
      # passes the line on unchanged.
      # @param line [String]
      # @return [String, nil]
      def apply(line)
        return line unless line.is_a?(String)

        no_gags, no_subs = @mutex.synchronize { [@gags.empty?, @subs.empty?] }
        return line if no_gags && no_subs # the common case: nothing to scan

        filter_line(line, no_subs)
      rescue StandardError
        line
      end

      private

      # Under the lock: the list changed (or an entry was shut off): forget every memoized result.
      def changed!
        @generation += 1
        @gag_memo.clear
        @sub_miss.clear
      end

      # Under the lock.
      def upsert(list, entry)
        index = list.index { |existing| existing.text == entry.text }
        index ? list[index] = entry : list << entry
        changed!
      end

      # Under the lock.
      def remember(memo, key, value)
        memo.clear if memo.size >= MEMO_LIMIT
        memo[key] = value
      end

      def matches?(entry, text)
        hit = entry.regex.match?(text)
        completed(entry)
        hit
      rescue Regexp::TimeoutError
        timed_out(entry)
        false
      end

      def safe_replace(entry, text, replacement)
        replaced = NetReplace.replace(entry.regex, text, replacement)
        completed(entry)
        replaced
      rescue Regexp::TimeoutError
        timed_out(entry)
        nil
      end

      # A match of +entry+ completed: its timed-out run is over.
      def completed(entry)
        @mutex.synchronize { entry.timeouts = 0 } if entry.timeouts.positive?
      end

      # One more consecutive timed-out match of +entry+; the {TIMEOUT_LIMIT}th shuts it off and
      # tells {#on_disabled} (outside the lock).
      def timed_out(entry)
        shut = @mutex.synchronize do
          entry.timeouts += 1
          next false if entry.disabled || entry.timeouts < TIMEOUT_LIMIT

          entry.disabled = true
          changed!
          true
        end
        return unless shut

        begin
          @on_disabled&.call(entry.is_a?(Gag) ? 'gag' : 'substitute', entry.text)
        rescue StandardError
          nil # the report must not break the line being filtered
        end
      end

      # {#apply} past the empty-lists test.
      def filter_line(line, no_subs)
        decoded = GameState.decode(line) # valid UTF-8 (a bad byte becomes U+FFFD) for the regexes
        display = display_text(decoded)
        return line if Text.net_trim(display).empty? # printed as nothing: never gagged (Game.cs:2811 R)

        target = decoded.include?("id='thoughts'") || decoded.include?('id="thoughts"') ? THOUGHTS : :main
        return tags_only(decoded) if gagged?(display, target)
        return line if no_subs

        out = decoded.split(/(<[^>]*>)/).map { |part| part.start_with?('<') ? part : substitute_run(part) }.join
        out == decoded ? line : out
      end

      # A gagged line's markup: its tags, in order, with no text; nil when it has none.
      def tags_only(line)
        tags = line.scan(TAG)
        tags.empty? ? nil : tags.join
      end

      def substitute_run(raw)
        decoded = decode(raw)
        replaced = substitute(decoded)
        replaced == decoded ? raw : replaced.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
      end

      def display_text(line)
        decode(line.gsub(TAG, ''))
      end

      # Character references and the five XML entities. A reference to a code point no String
      # can hold (a surrogate, or past U+10FFFF) is left as written: [n].pack('U') would build an
      # invalid String that every regex then raises on.
      def decode(text)
        text.gsub(/&(?:#(\d+)|#x(\h+)|([A-Za-z]+));/) do
          if Regexp.last_match(1) then character(Regexp.last_match(1).to_i) || Regexp.last_match(0)
          elsif Regexp.last_match(2) then character(Regexp.last_match(2).hex) || Regexp.last_match(0)
          else ENTITIES.fetch(Regexp.last_match(3), Regexp.last_match(0))
          end
        end
      end

      # @return [String, nil] the character for +code+, nil when it is not a Unicode scalar value
      def character(code)
        return nil if code > 0x10FFFF || code.between?(0xD800, 0xDFFF)

        [code].pack('U')
      end

      def shown(entry)
        entry.ignore_case ? "/#{entry.text}/i" : entry.text
      end

      def class_suffix(line, klass)
        klass.to_s.empty? ? line : "#{line} {#{klass}}"
      end

      def each_row(path)
        lines = path && ConfigFile.read_lines(path)
        return false if lines.nil?

        lines.each { |line| yield Text.parse_args(line) }
        true
      rescue StandardError # Load is catch (Exception) -> false
        false
      end

      # The rows are snapshotted (the block) inside @save_mutex, so two concurrent saves write in
      # order and an older snapshot never lands last.
      def write(path)
        return false if path.nil?

        @save_mutex.synchronize do
          ConfigFile.write_lines(path, yield)
          true
        end
      rescue StandardError
        false
      end
    end
  end
end
