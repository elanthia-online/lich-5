# frozen_string_literal: true

module Lich
  module Genie
    # Opt-in "surface assess exist-ids" shim for Genie scripts. An addition: Genie itself has
    # no such feature, so it is off by default and does nothing until a player turns it on.
    #
    # DragonRealms sends each creature in the ASSESS combat stream as an id-bearing
    # link tag -- `<d cmd='look #78195083'>an elder Adan'f sorcerer</d>` -- but Lich
    # strips that tag before scripts see it, so the exist-id disappears from the
    # visible text. Some front ends re-surface it as `[#78195083]`, and Genie scripts
    # written against them match `\[#(\d+)\]`, which ties those scripts to one front end.
    #
    # When on, the shim re-emits each completed assess creature line with the exist-id
    # spliced into the visible text (`Name [#id]`), where such a front end puts it. The id
    # is taken straight from the tag -- no re-parsing of ASSESS. The original assess output
    # is passed through untouched (XMLData/Creature parsing is unaffected).
    #
    # Who gets the enriched lines ({deliver}):
    #   * the in-Lich Genie engine's scripts and #triggers, through Lich::Genie.text_listener,
    #     and only while the engine is on (Lich::Genie.engine_active?);
    #   * a native Genie front end in front of Lich ($frontend == 'genie'): the client stream.
    # Never a .lic script: nothing is pushed through Script.new_downstream, so Lich scripts see
    # the game text exactly as they do with the shim off.
    #
    # Off by default; enable per character with `Lich::Genie::AssessIds.enabled = true`.
    module AssessIds
      # The ASSESS creature link: `<d cmd='look #NNN'>display name</d>` (single or
      # double quotes; `-?\d+` matches DR's id form). The captured group 1 is the id.
      LOOK_TAG = %r{<d\s+cmd=['"]look #(-?\d+)['"][^>]*>.*?</d>}i
      # A pushStream/popStream marker, capturing the kind and its attributes so we
      # can track whether we are inside the 'assess' combat stream across lines.
      STREAM_MARKER = %r{<(push|pop)Stream\b([^>]*)/?>}i
      # Cap the partial-line buffer so a (pathological) newline-less chunk can't grow
      # it without bound; we only ever need to hold one incomplete trailing line.
      MAX_PARTIAL = 8192

      module_function

      # --- per-character toggle (persisted in lich_settings) ----------------

      # @return [Boolean]
      def enabled?
        read_flag(settings_key)
      end

      # Turn the shim on/off for the current character. Enabling installs the hook
      # immediately (best-effort); it also self-installs when the Genie engine's
      # downstream hook is set up, so it survives relogin under the in-Lich engine.
      # Disabling disarms it at once (the hook stays registered and passes through).
      # @param value [Object] truthy (true/on/yes/1) enables
      def enabled=(value)
        on = truthy?(value)
        write_flag(settings_key, on)
        on ? install! : disarm!
      end

      # @return [Boolean] whether the hook is currently doing work
      def active?
        @active ? true : false
      end

      # Install the pass-through DownstreamHook (idempotent) and arm the shim -- only while
      # the per-character flag is on, so a stray call (an autostart line without its
      # `if enabled?`) cannot turn it on. The hook only OBSERVES the stream and delivers
      # extra enriched lines; it returns the server string unchanged, so the client display
      # and XML parsing are untouched.
      # @return [void]
      def install!
        return disarm! unless enabled?

        @active = true
        return if @installed
        return unless defined?(Lich::Common::DownstreamHook)

        @installed = true
        Lich::Common::DownstreamHook.add('genie-assess-ids', lambda { |server_string|
          observe(server_string)
          server_string
        }, persist: true)
      end

      # Stop observing (the flag was turned off): drop any partial line and stream state.
      # @return [void]
      def disarm!
        @active = false
        @buffer = nil
        @in_assess = nil
      end

      # --- pure enrichment (unit-testable, no Lich deps) --------------------

      # Splice the exist-id into one raw assess line's visible text, returning the
      # stripped, enriched line -- or nil if the line carries no creature link.
      #
      #   "...facing <d cmd='look #78195083'>an elder Adan'f sorcerer</d> (2)..."
      #   -> "...facing an elder Adan'f sorcerer [#78195083] (2)..."
      #
      # @param raw_line [String]
      # @return [String, nil]
      def enrich(raw_line)
        text = raw_line.to_s
        return nil unless text =~ LOOK_TAG

        surfaced = text.gsub(LOOK_TAG) { |tag| "#{tag} [##{Regexp.last_match(1)}]" }
        line = strip_line(surfaced).to_s.strip
        line.empty? ? nil : line
      end

      # Enrich every creature line in a raw assess block (text spanning the
      # pushStream..popStream), dropping the header/blank/non-creature lines.
      # @param block [String]
      # @return [Array<String>]
      def enrich_block(block)
        block.to_s.split(/\r?\n/).filter_map { |line| enrich(line) }
      end

      # --- stream observation ----------------------------------------------

      # Observe the game stream and, for each COMPLETE line that belongs to the
      # 'assess' combat stream and carries a creature link, deliver an enriched copy
      # with the exist-id spliced into the visible text.
      #
      # Processes the stream LINE BY LINE (splitting on newlines, buffering only a
      # trailing partial line) so it is robust to however the server chunks the data:
      # whether DR sends each assess line in its own push
      # (`<popStream/><pushStream id="assess"/>...\r\n` per line, its current form) OR
      # batches the whole block into one chunk. The earlier block-buffered version
      # truncated at the FIRST popStream and silently dropped every assess line but
      # the first in the batched case -- the "assess ids sometimes don't show up" bug.
      # Never raises into the hook chain.
      #
      # @param server_string [String]
      # @return [void]
      def observe(server_string)
        return unless @active

        @buffer = "#{@buffer}#{server_string}"
        while (nl = @buffer.index("\n"))
          line = @buffer.slice!(0..nl)
          handle_stream_line(line)
        end
        # Only ever need to hold one incomplete trailing line; guard against growth.
        @buffer = @buffer[-MAX_PARTIAL..] if @buffer.length > MAX_PARTIAL
      rescue StandardError => e
        @buffer = nil
        safe_respond("--- Lich: genie assess-ids error: #{e}")
      end

      # Update the inside-assess-stream state from any push/pop markers in this line
      # (a stream can open on one line and its content continue), then enrich + deliver
      # the line's creature link when the line is within the assess stream. `enrich`
      # returns nil unless the line actually carries a `look #id` link, so a lingering
      # assess state can never enrich unrelated traffic.
      #
      # @param line [String]
      # @return [void]
      def handle_stream_line(line)
        in_assess = @in_assess
        line.scan(STREAM_MARKER).each do |kind, attrs|
          @in_assess = kind.casecmp('push').zero? && attrs =~ /id=['"]assess['"]/ ? true : false
          in_assess ||= @in_assess
        end
        return unless in_assess

        enriched = enrich(line)
        deliver([enriched]) if enriched
      end

      # Deliver enriched lines to the Genie scripts that asked for them, and nowhere else:
      #   * a native Genie front end in front of Lich ($frontend == 'genie'): the client
      #     game stream (what Genie matches is what it displays), via _respond;
      #   * otherwise, only while the in-Lich Genie engine is on: its game-text intake
      #     (Lich::Genie.text_listener), which hands them to its #triggers and scripts as game
      #     lines on the trigger worker, after the row they came in. (A genie script's input
      #     drops what Lich pushes on its parser thread -- this hook's thread -- so the engine
      #     takes the lines itself.)
      # Nothing goes to Script.new_downstream: a .lic script never sees a synthetic line, and
      # with the engine off (and no Genie front end) nothing is delivered at all.
      # @param lines [Array<String>]
      # @return [void]
      def deliver(lines)
        return if lines.nil? || lines.empty?

        if defined?($frontend) && $frontend == 'genie'
          lines.each { |line| safe_client(line) }
        elsif engine_on?
          Lich::Genie.text_listener&.call(lines)
        end
      end

      # --- helpers ----------------------------------------------------------

      # strip_xml is a top-level (private on Object) def in a running Lich, so
      # respond_to?(:strip_xml) is FALSE even though it is callable; call it directly
      # and fall back to a naive tag-strip only when it is genuinely absent (headless
      # specs). See GenieScript.strip_xml_line for the same rationale.
      def strip_line(text)
        strip_xml(text).to_s
      rescue NameError
        text.to_s.gsub(/<[^>]+>/, '')
      end

      # The engine gate (a cached read after login); a failing read counts as off.
      def engine_on?
        Lich::Genie.engine_active? ? true : false
      rescue StandardError
        false
      end

      def safe_respond(message)
        respond(message)
      rescue StandardError
        nil
      end

      def safe_client(line)
        _respond(line)
      rescue StandardError
        nil
      end

      def truthy?(value)
        value.to_s =~ /\A(1|on|true|yes)\z/i ? true : false
      end

      def settings_key
        "genie_assess_ids:#{safe_xml(:game)}:#{safe_xml(:name)}"
      end

      def safe_xml(attribute)
        return '' unless defined?(XMLData) && XMLData.respond_to?(attribute)

        XMLData.public_send(attribute).to_s
      rescue StandardError
        ''
      end

      def persistence_available?
        defined?(Lich) && Lich.respond_to?(:db) && Lich.db
      rescue StandardError
        false
      end

      def read_flag(key)
        return false unless persistence_available?

        truthy?(Lich.db.get_first_value('SELECT value FROM lich_settings WHERE name=?;', [key]))
      rescue StandardError
        false
      end

      def write_flag(key, value)
        return unless persistence_available?

        Lich.db.execute('CREATE TABLE IF NOT EXISTS lich_settings (name TEXT NOT NULL, value TEXT, PRIMARY KEY(name));')
        Lich.db.execute('INSERT OR REPLACE INTO lich_settings(name,value) values(?,?);', [key, value.to_s])
      rescue StandardError
        nil
      end
    end
  end
end
