# frozen_string_literal: true

require_relative 'common/shutdown_log'

# Modernized version of games.rb with separated DR and GS functionality
# Original module carve out from lich.rbw
# Refactored on 2025-04-01

module Lich
  # Base module for game-specific functionality
  # Unknown game type module
  module Unknown
    module Game
      # Placeholder for unknown game types
    end
  end

  # Common module for shared functionality
  module Common
    # Placeholder for common game functionality
  end

  module GameBase
    # Game-agnostic formatting for the Lich-injected room annotations
    # (room number, obvious exits, and StringProc exits). Both the GemStone
    # and DragonRealms game instances mix this in so the font and clickable-link
    # toggles behave identically regardless of game: the module decides *how* an
    # annotation looks, while each game instance decides *which* lines/streams to
    # emit. Extracting it removes the near-duplicate exit/StringProc rendering
    # that previously lived in both #process_room_display implementations.
    #
    # Two independent settings drive it:
    # - Lich.display_room_links - clickable <d> command links vs plain text
    # - Lich.display_room_mono  - fixed-width mono style vs the proportional game font
    #
    # The mono wrapper only escapes nothing and merely brackets the line, so a
    # mono line can still contain live <d> links (the two toggles are orthogonal).
    #
    # Escaping: unlike respond (which HTML-escapes &, <, > for the classic
    # roomnumbers.lic path), neither the mono wrapper nor the plain-text entries
    # escape anything. This is deliberate - the links path emits live <d> markup
    # that must survive verbatim, and both paths are kept consistent so a toggle
    # never silently changes escaping. Exit commands and room titles come from the
    # mapdb and contain no markup in practice; if untrusted text is ever fed here
    # the caller must escape it first.
    module RoomFormatter
      # Obvious compass / up / down / out exits (usually rendered by the game
      # itself), excluded from the "Room Exits:" line. Hoisted here so the GS and
      # DR paths share a single, identical definition.
      OBVIOUS_EXIT_PATTERN = /^(?:o|d|u|n|ne|e|se|s|sw|w|nw|out|down|up|north|northeast|east|southeast|south|southwest|west|northwest)$/.freeze

      # Everything below is internal formatting detail, marked +private+ so the
      # mixin adds no new public surface to the game instances that include it.
      # The game #process_room_display methods reach these via implicit self
      # (which is legal for private methods); the unit specs exercise them
      # through a throwaway host class that re-publicizes them.
      private

      # Whether the injected room lines should render in the fixed-width mono
      # style. Gated on the frontend actually supporting mono so non-mono clients
      # never receive stray <output> tags (mirrors respond's own guard).
      # @return [Boolean]
      # @api private
      def room_mono?
        Lich.display_room_mono && Frontend.supports_mono?
      end

      # Whether room exits should render as clickable <d> command links.
      # @return [Boolean]
      # @api private
      def room_links?
        Lich.display_room_links
      end

      # Wraps a completed line body in the classic mono style when enabled, else
      # returns it unchanged. Never escapes, so any <d> links in body survive.
      # @param body [String] the fully built line (label plus entries)
      # @return [String] the styled (or unchanged) line
      # @api private
      def room_styled(body)
        room_mono? ? "<output class=\"mono\"/>#{body}<output class=\"\"/>" : body
      end

      # Builds the StringProc-exit entries for the current room, honoring the
      # links toggle. Returns [] when the feature is off so callers add no line
      # and Map is not touched.
      # NOTE: StringProc overrides #class and #kind_of? (both report Proc), so
      # detection MUST use #is_a?, which reflects the real class - see
      # lib/common/class_exts/stringproc.rb.
      # @return [Array<String>] formatted entries (links or plain labels)
      # @api private
      def room_stringproc_entries
        return [] unless Lich.display_stringprocs

        entries = []
        Map.current.wayto.each do |key, value|
          next unless value.is_a?(StringProc)
          # Only routable StringProcs (a numeric travel time) are useful to show.
          timeto = Map.current.timeto[key]
          next unless timeto.is_a?(Numeric) || (timeto.is_a?(StringProc) && timeto.call.is_a?(Numeric))
          # Guard against a dangling wayto reference (destination room missing
          # from the mapdb) rather than crashing the whole downstream hook.
          dest = Map[key]
          next if dest.nil?

          label = "#{dest.title.first.gsub(/\[|\]/, '')}#{Lich.display_lichid ? "(#{dest.id})" : ''}"
          entries << (room_links? ? "<d cmd=';go2 #{key}'>#{label}</d>" : label)
        end
        entries
      end

      # Builds the obvious-exit entries (non-compass go/climb style exits) for the
      # current room, honoring the links toggle. Returns [] when the feature is
      # off so callers add no line and Map is not touched.
      # @return [Array<String>] formatted entries (links or plain commands)
      # @api private
      def room_exit_entries
        return [] unless Lich.display_exits

        entries = []
        Map.current.wayto.each_value do |value|
          next if value.to_s =~ OBVIOUS_EXIT_PATTERN
          next if value.is_a?(StringProc)

          # Derive the command via to_s (as the OBVIOUS_EXIT_PATTERN check above
          # already does) before #dump, so a non-String wayto value is coerced
          # rather than raising NoMethodError inside the downstream hook. For the
          # String values the mapdb actually stores, value.to_s is the same object
          # so this is byte-identical to the previous value.dump.
          cmd = value.to_s.dump[1..-2]
          entries << (room_links? ? "<d cmd='#{cmd}'>#{cmd}</d>" : cmd)
        end
        entries
      end

      # Prepends the shared "StringProcs:" and "Room Exits:" lines (in that
      # order, so exits end up above StringProcs and any later room-number line
      # ends up above both) to alt_string, each only when it has entries. This is
      # the composition both games share. Entries are passed in (built once by the
      # caller) so a game that also reuses them - e.g. the GemStone room-window
      # mirror - does not iterate Map.current.wayto twice.
      # @param alt_string [String] the server string being rewritten
      # @param stringproc_entries [Array<String>] pre-built StringProc entries
      # @param exit_entries [Array<String>] pre-built obvious-exit entries
      # @return [String] alt_string with the room lines prepended
      # @api private
      def prepend_room_lines(alt_string, stringproc_entries, exit_entries)
        alt_string = "#{room_styled("StringProcs: #{stringproc_entries.join(', ')}")}\r\n#{alt_string}" unless stringproc_entries.empty?
        alt_string = "#{room_styled("Room Exits: #{exit_entries.join(', ')}")}\r\n#{alt_string}" unless exit_entries.empty?
        alt_string
      end
    end

    # Factory for creating game-specific objects
    module GameInstanceFactory
      def self.create(game_type)
        case game_type
        when /^GS/
          Gemstone::GameInstance.new
        when /^DR/
          DragonRealms::GameInstance.new
        else
          # Default to a basic implementation if game type is unknown
          GameInstance::Base.new
        end
      end
    end

    # Game instance interface for game-specific behaviors
    module GameInstance
      # Base instance class that defines the interface
      class Base
        include RoomFormatter

        def initialize
          @atmospherics = false
          @combat_count = 0
          @end_combat_tags = ["<prompt", "<clearStream", "<component", "<pushStream id=\"percWindow"]
          @pending_room_objs = nil
        end

        def clean_serverstring(server_string)
          raise NotImplementedError, "#{self.class} must implement #clean_serverstring"
        end

        def handle_combat_tags(server_string)
          raise NotImplementedError, "#{self.class} must implement #handle_combat_tags"
        end

        def handle_atmospherics(server_string)
          raise NotImplementedError, "#{self.class} must implement #handle_atmospherics"
        end

        def get_documentation_url
          raise NotImplementedError, "#{self.class} must implement #get_documentation_url"
        end

        def process_game_specific_data(server_string, stripped_server = nil)
          raise NotImplementedError, "#{self.class} must implement #process_game_specific_data"
        end

        def modify_room_display(alt_string, uid_from_string, lichid_from_uid_string)
          raise NotImplementedError, "#{self.class} must implement #modify_room_display"
        end

        def process_room_display(alt_string)
          raise NotImplementedError, "#{self.class} must implement #process_room_display"
        end

        def combat_count
          @combat_count
        end

        def atmospherics
          @atmospherics
        end

        def atmospherics=(value)
          @atmospherics = value
        end

        # Buffer split <component id='room objs'> or <component id='room players'> when server sends "...wait N seconds." on separate line
        # Returns [should_skip, server_string]
        def buffer_room_objs(server_string)
          if @pending_room_objs
            if server_string.include?("</component>")
              combined = @pending_room_objs + server_string.sub(/\r\n$/, '')
              Lich.log "Combined split room component: #{combined.inspect}"
              @pending_room_objs = nil
              return [false, combined]
            else
              @pending_room_objs = @pending_room_objs + server_string.sub(/\r\n$/, '')
              return [true, nil]
            end
          end

          if server_string =~ /^(?:<\/?(?:pushStream|popStream)[^>]*>\s*)*<component id='room (?:objs|players)'>.*\.\.\.wait \d+ seconds?\.\r\n$/ && !server_string.include?("</component>")
            Lich.log "Open-ended room component tag, buffering: #{server_string.inspect}"
            # Strip the "...wait N seconds.\r\n" part, keep the opening tag and any content before it
            @pending_room_objs = server_string.sub(/\.\.\.wait \d+ seconds?\.\r\n$/, '')
            return [true, nil]
          end

          [false, server_string]
        end

        protected

        def increment_combat_count(server_string)
          @combat_count += server_string.scan("<pushStream id=\"combat\" />").length
          @combat_count -= server_string.scan("<popStream id=\"combat\" />").length
          @combat_count = 0 if @combat_count < 0
        end
      end
    end

    # XML string cleaner module
    module XMLCleaner
      class << self
        def clean_nested_quotes(server_string)
          # Fix nested single quotes
          unless (matches = server_string.scan(/'([^=>]*'[^=>]*)'/)).empty?
            Lich.log "Invalid nested single quotes XML tags detected: #{server_string.inspect}"
            matches.flatten.each do |match|
              server_string.gsub!(match, match.gsub(/'/, '&apos;'))
            end
            Lich.log "Invalid nested single quotes XML tags fixed to: #{server_string.inspect}"
          end

          # Fix nested double quotes
          unless (matches = server_string.scan(/"([^=>]*"[^=>]*)"/)).empty?
            Lich.log "Invalid nested double quotes XML tags detected: #{server_string.inspect}"
            matches.flatten.each do |match|
              server_string.gsub!(match, match.gsub(/"/, '&quot;'))
            end
            Lich.log "Invalid nested double quotes XML tags fixed to: #{server_string.inspect}"
          end

          server_string
        end

        def fix_invalid_characters(server_string)
          # Note: a bare '&' is intentionally not escaped here. REXML raised on it
          # (hence the old escaping); Ox tolerates it (convert_special: false emits
          # it verbatim with no error), so escaping is no longer needed for parsing.

          # Fix bell character
          if server_string.include?("\a")
            Lich.log "Invalid \\a detected: #{server_string.inspect}"
            server_string.gsub!("\a", '')
            Lich.log "Invalid \\a stripped out: #{server_string.inspect}"
          end

          server_string
        end

        def fix_xml_tags(server_string)
          # Fix open-ended XML tags
          if /^<(?<xmltag>dynaStream|component) id='.*'>[^<]*(?!<\/\k<xmltag>>)\r\n$/ =~ server_string
            Lich.log "Open-ended #{xmltag} tag: #{server_string.inspect}"
            server_string.gsub!("\r\n", "</#{xmltag}>")
            Lich.log "Open-ended #{xmltag} tag fixed to: #{server_string.inspect}"
          end

          # Remove dangling closing tags
          if server_string =~ /^(?:(\"|<compass><\/compass>))?<\/(dynaStream|component)>\r\n/
            Lich.log "Extraneous closing tag detected and deleted: #{server_string.inspect}"
            server_string = ""
          end

          # Remove unclosed tag in long strings from empath appraisals
          if server_string =~ / and <d cmd=\"transfer .+? nerves\">a/
            Lich.log "Unclosed wound (nerves) tag detected and deleted: #{server_string.inspect}"
            server_string.sub!(/ and <d cmd=\"transfer .+? nerves\">a.+?$/, " and more.")
          end

          server_string
        end
      end
    end

    # Raised when a server fragment is structurally truncated (cut off
    # mid-element) -- the stream has desynced from XML framing. Pre-Ox, strict
    # REXML raised on these fragments and Game.process_xml_data's rescue logged
    # the fragment and reset XMLData, so parser strictness doubled as desync
    # detection. Ox is permissive: it parses truncated fragments without
    # raising (auto-closing elements, fabricating empty attribute values) and
    # only reports the damage through its optional error callback. That
    # callback is now the only desync signal, so process_xml_data promotes
    # truncation-class parse errors to this exception to keep the old
    # recovery path (log + XMLData.reset).
    class GameStreamDesyncError < StandardError; end

    # Ox error-callback messages that mean the fragment ended mid-token -- the
    # only unambiguous truncation signal, since a complete line cannot end inside
    # an open tag, attribute list, or quoted value. (In practice genuine
    # truncation is an edge case: reads are newline-delimited via @socket.gets,
    # Simu keeps each tag on one line, multi-line content is reassembled upstream
    # by buffer_room_objs, and #4's tag_end guard keeps @active_tags balanced
    # regardless. This is a backstop for a partial read at disconnect.)
    #
    # Ox also fires the callback for Simu's routine almost-XML -- bare text and
    # multiple top-level elements ('text not terminated', 'multiple top level
    # elements'), nested quotes ('no attribute value'), unescaped ampersands
    # ('Invalid special character sequence'), missing </d> end tags ('Start End
    # Mismatch: ... not closed') -- none of which match these patterns, so they
    # stay tolerated. The message prefix matters: 'Unexpected Character: element
    # not closed' (a start tag that never got its '>') is truncation, while the
    # similarly worded 'Start End Mismatch: element ... not closed' (an element
    # missing its end tag) is routine.
    #
    # 'attribute value not in quotes' is intentionally NOT here: it fires on a
    # *complete* unquoted-attribute line (<a x=y>), so matching it false-resets a
    # fully-parsed fragment. A truncated unquoted attr (<a x=y) still resets via
    # 'attributes not terminated' / 'element not closed' below.
    STREAM_DESYNC_ERRORS = [
      /\ANot Terminated: attributes not terminated/,
      /\ANot Terminated: quoted value not terminated/,
      /\ANot Terminated: document not terminated/,
      /\AUnexpected Character: element not closed/
    ].freeze

    # Ox's signature when a tag scatters into valueless attributes: the
    # settingsInfo space-not-found bug, or a same-quote inside a quoted value
    # (e.g. title='Tsetem's Items'), where the inner quote ends the value early.
    # (A genuinely valueless attribute, <a foo>, reports the same thing, but the
    # repairs leave it unchanged so no reparse happens.)
    NO_ATTRIBUTE_VALUE_ERROR = /\AUnexpected Character: no attribute value/

    # Base Game class with common functionality
    class Game
      class ServerQueueOverflow < StandardError; end

      # Seconds to wait for readable game socket data before one read timeout.
      READ_TIMEOUT_SECONDS = 100

      # Consecutive read timeouts allowed before treating the game link as dead.
      MAX_CONSECUTIVE_READ_TIMEOUTS = 3

      # Sentinel returned when the game socket has no readable data before timeout.
      READ_TIMEOUT = Object.new.freeze

      # A full queue means the parser cannot preserve the game stream. Dropping
      # records or blocking the socket reader would both make recovery unsafe.
      SERVER_QUEUE_CAPACITY = 4_096

      class << self
        attr_reader :thread, :reader_thread, :server_queue, :buffer, :_buffer, :game_instance

        def autostarted?
          @@autostarted
        end

        def prefix_origin_sentinel(string)
          string.gsub(/^.+$/) { |line| "#{Frontend::ORIGIN_SENTINEL}#{line}" }
        end

        def settings_init_needed?
          @@settings_init_needed
        end

        def initialize_buffers
          @socket = nil
          @mutex = Mutex.new
          @last_recv = nil
          @thread = nil
          @reader_thread = nil
          @server_queue = SizedQueue.new(SERVER_QUEUE_CAPACITY)
          reset_server_queue_stats!
          @buffer = Lich::Common::SharedBuffer.new
          @_buffer = Lich::Common::SharedBuffer.new
          @_buffer.max_size = 1000
          @@autostarted = false
          @@settings_init_needed = false
          @cli_scripts = false
          @room_number_after_ready = false
          @last_id_shown_room_window = 0
          @game_instance = nil
          # strip_xml's multiline carry is a process-global; clear it here so a
          # fragment left open before a reconnect/session reset does not bleed
          # into the next session.
          $strip_xml_multiline = {}
        end

        def set_game_instance(game_type)
          @game_instance = GameInstanceFactory.create(game_type)
        end

        # Opens the TCP connection to the game server and starts the socket's
        # wrap and main reader threads.
        #
        # @param host [String] game server hostname
        # @param port [Integer] game server port
        # @return [TCPSocket] the connected, configured game socket
        # @note Connection errors propagate to the caller. Use
        #   {.open_with_timeout} to bound how long the connect may block.
        # @see .open_with_timeout
        def open(host, port)
          @socket = TCPSocket.open(host, port)

          # Configure socket with error handling
          # More forgiving settings for Windows reliability under network stress
          begin
            SocketConfigurator.configure(@socket,
                                         keepalive: {
                                           enable: true,
                                           idle: 30,       # 30s idle before first keepalive; defensive against L3/L4 idle reapers (best-effort, see SocketConfigurator)
                                           interval: 30    # 30 seconds between keepalive probes
                                         },
                                         linger: {
                                           enable: true,
                                           timeout: 5      # Wait 5 seconds for data to send on close
                                         },
                                         timeout: {
                                           recv: 30,       # 30 second receive timeout (increased from 10)
                                           send: 30        # 30 second send timeout (increased from 10)
                                         },
                                         buffer_size: {
                                           recv: 32768,    # 32KB receive buffer (reduced from 65536)
                                           send: 32768     # 32KB send buffer (reduced from 65536)
                                         },
                                         tcp_nodelay: true, # Disable Nagle's algorithm for low latency
                                         tcp_maxrt: 10)     # Windows: max 10 retransmissions before giving up

            Lich.log("Socket configured successfully for #{host}:#{port}") if ARGV.include?("--debug")
          rescue StandardError => e
            # Log the error but continue - socket may still work with default settings
            log_error("Socket configuration error (continuing with defaults)", e)
            Lich.log("WARNING: Socket running with default OS settings - may be less reliable under network stress")
          end

          @socket.sync = true

          start_wrap_thread
          start_main_thread

          @socket
        end

        # Connects to the game server on a background thread, enforcing a connect
        # timeout that a bare {.open} cannot. Surfaces a stuck or failed connect
        # instead of letting startup proceed with a dead socket.
        #
        # @param host [String] game server hostname
        # @param port [Integer] game server port
        # @param timeout [Integer, Float] seconds to wait for the connect to complete
        # @return [void]
        # @raise [RuntimeError] if the connect does not complete within +timeout+
        # @raise [StandardError] re-raises whatever {.open} raises
        #   (e.g. Errno::ECONNREFUSED) so the caller's rescue runs
        # @see .open
        def open_with_timeout(host, port, timeout = 30)
          connect_thread = Thread.new {
            # report_on_exception off: a failed open is surfaced by the join below
            # (which re-raises it), not by an auto-printed thread warning.
            Thread.current.report_on_exception = false
            self.open(host, port)
          }
          # join returns nil on timeout, the thread on success, and re-raises the
          # thread's exception on failure -- so a Game.open that errors (e.g.
          # connection refused) propagates to the caller's rescue instead of being
          # silently swallowed (the old `if connect_thread.status` could not tell a
          # thread that died with an exception, status nil, from a normal finish,
          # status false).
          if connect_thread.join(timeout).nil?
            connect_thread.kill rescue nil
            raise "error: timed out connecting to #{host}:#{port}"
          end
        end

        def start_wrap_thread
          begin
            Lich.db_vacuum_if_due!(months: 6)
          rescue => e
            Lich.log "db_maint(startup): #{e.class}: #{e.message}"
          end

          @wrap_thread = Thread.new do
            @last_recv = Time.now
            until @@autostarted || (Time.now - @last_recv >= 6)
              break if @@autostarted
              sleep 0.2
            end

            puts 'look' unless @@autostarted
          end
        end

        def closed?
          @socket.nil? || @socket.closed?
        end

        def reset_server_queue_stats!
          @server_queue_enqueued = 0
          @server_queue_dequeued = 0
          @server_queue_last_depth = @server_queue&.length.to_i
          @server_queue_max_depth = @server_queue_last_depth
          @server_queue_last_enqueue_at = nil
          @server_queue_last_dequeue_at = nil
          @server_queue_last_wait = nil
          @server_queue_max_wait = 0.0
          @server_queue_total_wait = 0.0
          @server_reader_hook_last = nil
          @server_reader_hook_max = 0.0
          @server_reader_hook_total = 0.0
          @server_reader_enqueue_last = nil
          @server_reader_enqueue_max = 0.0
          @server_reader_enqueue_total = 0.0
          @server_reader_process_last = nil
          @server_reader_process_max = 0.0
          @server_reader_process_total = 0.0
          @server_parser_last = nil
          @server_parser_max = 0.0
          @server_parser_total = 0.0
          nil
        end

        def server_queue_stats(reset: false)
          depth = @server_queue&.length.to_i
          dequeued = @server_queue_dequeued.to_i
          last_wait = @server_queue_last_wait
          max_wait = @server_queue_max_wait.to_f
          avg_wait = dequeued.positive? ? @server_queue_total_wait.to_f / dequeued : 0.0
          enqueued = @server_queue_enqueued.to_i
          hook_last = @server_reader_hook_last
          hook_max = @server_reader_hook_max.to_f
          hook_avg = enqueued.positive? ? @server_reader_hook_total.to_f / enqueued : 0.0
          enqueue_last = @server_reader_enqueue_last
          enqueue_max = @server_reader_enqueue_max.to_f
          enqueue_avg = enqueued.positive? ? @server_reader_enqueue_total.to_f / enqueued : 0.0
          process_last = @server_reader_process_last
          process_max = @server_reader_process_max.to_f
          process_avg = enqueued.positive? ? @server_reader_process_total.to_f / enqueued : 0.0
          parser_last = @server_parser_last
          parser_max = @server_parser_max.to_f
          parser_avg = dequeued.positive? ? @server_parser_total.to_f / dequeued : 0.0
          stats = {
            depth: depth,
            last_depth: @server_queue_last_depth.to_i,
            max_depth: [@server_queue_max_depth.to_i, depth].max,
            enqueued: enqueued,
            dequeued: dequeued,
            last_wait: last_wait,
            max_wait: max_wait,
            avg_wait: avg_wait,
            last_wait_ms: last_wait ? (last_wait * 1000.0).round(3) : nil,
            max_wait_ms: (max_wait * 1000.0).round(3),
            avg_wait_ms: (avg_wait * 1000.0).round(3),
            reader_hook_last_ms: hook_last ? (hook_last * 1000.0).round(3) : nil,
            reader_hook_max_ms: (hook_max * 1000.0).round(3),
            reader_hook_avg_ms: (hook_avg * 1000.0).round(3),
            reader_enqueue_last_ms: enqueue_last ? (enqueue_last * 1000.0).round(3) : nil,
            reader_enqueue_max_ms: (enqueue_max * 1000.0).round(3),
            reader_enqueue_avg_ms: (enqueue_avg * 1000.0).round(3),
            reader_process_last_ms: process_last ? (process_last * 1000.0).round(3) : nil,
            reader_process_max_ms: (process_max * 1000.0).round(3),
            reader_process_avg_ms: (process_avg * 1000.0).round(3),
            parser_process_last_ms: parser_last ? (parser_last * 1000.0).round(3) : nil,
            parser_process_max_ms: (parser_max * 1000.0).round(3),
            parser_process_avg_ms: (parser_avg * 1000.0).round(3),
            last_enqueue_at: @server_queue_last_enqueue_at,
            last_dequeue_at: @server_queue_last_dequeue_at,
            reader_status: @reader_thread&.status,
            parser_status: @thread&.status
          }
          reset_server_queue_stats! if reset
          stats
        end

        def close
          if @socket
            @socket.close rescue nil
            @reader_thread.kill rescue nil
            @thread.kill rescue nil
          end
        end

        # Writes a string to the game server socket.
        #
        # Thread-safe via mutex. Silently absorbs fatal connection errors
        # so callers (scripts) are not killed by a broken server link.
        #
        # @param str [String] the raw command to send upstream
        # @return [nil] on connection error
        def _puts(str)
          @mutex.synchronize do
            @socket.puts(str)
          end
        rescue Errno::EPIPE, Errno::ECONNRESET, Errno::ECONNABORTED, IOError => e
          Lich.log "error: _puts: #{e}\n\t#{e.backtrace.first}"
          nil
        end

        def puts(str)
          if Script.current&.file_name
            script_name = "#{Script.current.custom? ? 'custom/' : ''}#{Script.current&.name}"
          else
            script_name = Script.current&.name || '(unknown script)'
          end

          $_CLIENTBUFFER_.push "[#{script_name}]#{$SEND_CHARACTER}#{$cmd_prefix}#{str}\r\n"

          unless Script.current&.silent
            respond "[#{script_name}]#{$SEND_CHARACTER}#{str}\r\n"
          end

          _puts "#{$cmd_prefix}#{str}"
          $_LASTUPSTREAM_ = "[#{script_name}]#{$SEND_CHARACTER}#{str}"
        end

        def gets
          @buffer.gets
        end

        def _gets
          @_buffer.gets
        end

        def start_main_thread
          @server_queue = SizedQueue.new(SERVER_QUEUE_CAPACITY)
          reset_server_queue_stats!
          start_socket_reader_thread
          start_server_processor_thread
        end

        def record_server_queue_enqueue
          @server_queue_enqueued = @server_queue_enqueued.to_i + 1
          depth = @server_queue&.length.to_i
          @server_queue_last_depth = depth
          @server_queue_max_depth = depth if depth > @server_queue_max_depth.to_i
          @server_queue_last_enqueue_at = Time.now
          nil
        end

        def enqueue_server_string(server_string, enqueued_monotonic_at)
          @server_queue.push([server_string, enqueued_monotonic_at], true)
          record_server_queue_enqueue
        rescue ThreadError
          raise ServerQueueOverflow, "game parser queue exceeded #{SERVER_QUEUE_CAPACITY} records"
        end

        def record_server_reader_timing(hook_time:, enqueue_time:, process_time:)
          @server_reader_hook_last = hook_time
          @server_reader_hook_total = @server_reader_hook_total.to_f + hook_time.to_f
          @server_reader_hook_max = hook_time if hook_time.to_f > @server_reader_hook_max.to_f

          @server_reader_enqueue_last = enqueue_time
          @server_reader_enqueue_total = @server_reader_enqueue_total.to_f + enqueue_time.to_f
          @server_reader_enqueue_max = enqueue_time if enqueue_time.to_f > @server_reader_enqueue_max.to_f

          @server_reader_process_last = process_time
          @server_reader_process_total = @server_reader_process_total.to_f + process_time.to_f
          @server_reader_process_max = process_time if process_time.to_f > @server_reader_process_max.to_f
          nil
        end

        def record_server_queue_dequeue(enqueued_monotonic_at = nil)
          @server_queue_dequeued = @server_queue_dequeued.to_i + 1
          depth = @server_queue&.length.to_i
          @server_queue_last_depth = depth
          @server_queue_last_dequeue_at = Time.now
          if enqueued_monotonic_at
            wait = Process.clock_gettime(Process::CLOCK_MONOTONIC) - enqueued_monotonic_at.to_f
            if wait >= 0.0
              @server_queue_last_wait = wait
              @server_queue_total_wait = @server_queue_total_wait.to_f + wait
              @server_queue_max_wait = wait if wait > @server_queue_max_wait.to_f
            end
          end
          nil
        end

        def record_server_parser_timing(parse_time)
          @server_parser_last = parse_time
          @server_parser_total = @server_parser_total.to_f + parse_time.to_f
          @server_parser_max = parse_time if parse_time.to_f > @server_parser_max.to_f
          nil
        end

        def unwrap_server_queue_item(item)
          if item.is_a?(Array) && item.length == 2 && item[1].is_a?(Numeric)
            item
          else
            [item, nil]
          end
        end

        def start_socket_reader_thread
          @reader_thread = Thread.new do
            consecutive_timeouts = 0
            max_consecutive_timeouts = MAX_CONSECUTIVE_READ_TIMEOUTS

            begin
              while true
                begin
                  server_string = read_server_string

                  if server_string.equal?(READ_TIMEOUT)
                    raise IO::TimeoutError, "no game data for #{READ_TIMEOUT_SECONDS} seconds"
                  end

                  consecutive_timeouts = 0

                  # Break if socket closed (gets returns nil)
                  if server_string.nil?
                    record_shutdown_reason(:game_eof, source: :game_reader)
                    break
                  end

                  reader_process_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
                  received_at = Time.now
                  monotonic_received_at = reader_process_started
                  @last_recv = received_at
                  @_buffer.update(server_string) if defined?(TESTING) && TESTING
                  hook_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
                  Lich::Common::SocketReadHook.run(
                    server_string,
                    received_at: received_at,
                    monotonic_received_at: monotonic_received_at
                  ) if defined?(Lich::Common::SocketReadHook)
                  hook_finished = Process.clock_gettime(Process::CLOCK_MONOTONIC)
                  enqueue_started = hook_finished
                  enqueue_server_string(server_string, enqueue_started)
                  enqueue_finished = Process.clock_gettime(Process::CLOCK_MONOTONIC)
                  record_server_reader_timing(
                    hook_time: hook_finished - hook_started,
                    enqueue_time: enqueue_finished - enqueue_started,
                    process_time: enqueue_finished - reader_process_started
                  )
                rescue Errno::ETIMEDOUT, Errno::EWOULDBLOCK, IO::TimeoutError
                  consecutive_timeouts += 1

                  shutdown_log.info("socket read timeout #{consecutive_timeouts}/#{max_consecutive_timeouts} (no game data for #{READ_TIMEOUT_SECONDS}s)")

                  if consecutive_timeouts >= max_consecutive_timeouts
                    total_timeout = total_read_timeout_seconds(max_consecutive_timeouts)
                    shutdown_log.warning("game connection timed out after #{max_consecutive_timeouts} consecutive read timeouts (#{total_timeout}s)")
                    raise IO::TimeoutError, "no game data for #{total_timeout} seconds"
                  end

                  # Check if socket is still alive
                  if @socket.closed?
                    shutdown_log.info("game socket is closed; exiting server thread")
                    break
                  end

                  # Small sleep before retry
                  sleep 0.1
                  retry
                rescue Errno::ECONNRESET, Errno::EPIPE, Errno::ECONNABORTED => conn_error
                  # Connection was reset/broken - these are fatal
                  shutdown_log.info("connection error: #{conn_error.class} - #{conn_error.message}")
                  raise conn_error
                end
              end
            rescue StandardError => e
              if intentional_shutdown_close_error?(e)
                shutdown_log.info("server thread exiting after orderly user shutdown")
                next
              end

              # Handle any other errors
              should_continue = handle_thread_error(e)
              # Only retry if handle_thread_error says it's safe and socket is still open
              if should_continue && !@socket.closed? && $_CLIENT_.alive?
                shutdown_log.debug("retrying server thread after error")
                consecutive_timeouts = 0 # Reset counter on retry
                sleep 1 # Brief pause before retry
                retry
              else
                reason = shutdown_reason_for_thread_exit(e)
                record_shutdown_reason(reason, source: :game_reader, detail: e.class)
                shutdown_log.info("server thread exiting due to #{reason}")
              end
            ensure
              @server_queue << nil if @server_queue && @thread&.alive?
            end
          end
          @reader_thread.name = 'game socket reader' if @reader_thread.respond_to?(:name=)
          @reader_thread.priority = 5
        end

        def start_server_processor_thread
          @thread = Thread.new do
            begin
              loop do
                item = @server_queue.pop
                break if item.nil?

                server_string, enqueued_monotonic_at = unwrap_server_queue_item(item)
                record_server_queue_dequeue(enqueued_monotonic_at)
                parse_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
                process_server_string(server_string)
                record_server_parser_timing(Process.clock_gettime(Process::CLOCK_MONOTONIC) - parse_started)
              end
            rescue StandardError => e
              log_error("Error processing server string", e)
              record_shutdown_reason(:unrecoverable_game_thread_error, source: :game_parser, detail: e.class)
              @socket.close rescue nil
            end
          end
          @thread.name = 'game parser' if @thread.respond_to?(:name=)
          @thread.priority = 4
        end

        # Reads one game-server line after an explicit readiness wait.
        #
        # Ruby does not reliably surface SO_RCVTIMEO through TCPSocket#gets on
        # every supported platform. Waiting with IO.select makes the reader's
        # no-data timeout deterministic while preserving gets-based EOF handling.
        #
        # @param read_timeout [Numeric] seconds to wait for game socket data
        # @return [String, nil, Object] a server line, nil for EOF, or READ_TIMEOUT
        def read_server_string(read_timeout: READ_TIMEOUT_SECONDS)
          return READ_TIMEOUT unless IO.select([@socket], nil, nil, read_timeout)

          @socket.gets
        end

        # @param timeout_count [Integer] number of consecutive read waits
        # @return [Integer] total elapsed no-data seconds represented by count
        def total_read_timeout_seconds(timeout_count = MAX_CONSECUTIVE_READ_TIMEOUTS)
          READ_TIMEOUT_SECONDS * timeout_count
        end

        def process_server_string(server_string)
          $cmd_prefix = String.new if server_string =~ /^\034GSw/

          # Load game-specific modules if needed
          unless (XMLData.game.nil? || XMLData.game.empty?)
            unless Module.const_defined?(:GameLoader)
              require_relative 'common/gameloader'
              GameLoader.load!
            end
          end

          # Set instance if not already set
          if @game_instance.nil? && !XMLData.game.nil? && !XMLData.game.empty?
            set_game_instance(XMLData.game)
          end

          # Clean server string based on game type
          if @game_instance
            server_string = @game_instance.clean_serverstring(server_string)
            return if server_string.nil? # Buffering split component, wait for next line
          end

          # Debug output if needed
          pp server_string if defined?($deep_debug) && $deep_debug

          # Push to server buffer
          $_SERVERBUFFER_.push(server_string)

          # Handle autostart
          handle_autostart if !@@autostarted && server_string =~ /<app char/

          # Handle CLI scripts
          if !@cli_scripts && @@autostarted && !XMLData.name.nil? && !XMLData.name.empty?
            start_cli_scripts
          end

          # Process XML data
          process_xml_data(server_string) unless server_string =~ /^<settings /

          # Run downstream hooks
          process_downstream_hooks(server_string)
        end

        def handle_autostart
          if defined?(LICH_VERSION) && defined?(Lich.core_updated_with_lich_version) &&
             Gem::Version.new(LICH_VERSION) > Gem::Version.new(Lich.core_updated_with_lich_version)
            Lich::Messaging.mono(Lich::Messaging.monsterbold("New installation or updated version of Lich5 detected!"))
            Lich::Messaging.mono(Lich::Messaging.monsterbold("Installing newest core scripts available to ensure you're up-to-date!"))
            Lich::Messaging.mono("")
            Lich::Util::Update.update_core_data_and_scripts
          end

          # Sync script repositories on login for both DR and GS.
          # MUST run in a background thread -- sync_all_repos makes HTTP calls
          # that block the game thread, preventing process_xml_data from setting
          # XMLData.name. If Vars is accessed before XMLData.name is set, it
          # loads/saves under scope "DR:" instead of "DR:CharName", overwriting
          # real data with an empty session.
          Thread.new do
            # Wait for XMLData.name to be populated by process_xml_data
            # before touching Vars. 200 x 50ms = 10s max wait.
            200.times do
              break if !XMLData.name.nil? && !XMLData.name.empty?

              sleep 0.05
            end
            Lich::Util::Update.sync_all_repos if !XMLData.name.nil? && !XMLData.name.empty?
          rescue StandardError => e
            Lich.log "repo_sync(login): #{e.class}: #{e.message}"
          end

          Script.start('autostart') if defined?(Script) && Script.respond_to?(:exists?) && Script.exists?('autostart')
          @@autostarted = true

          display_ruby_warning if defined?(RECOMMENDED_RUBY) && Gem::Version.new(RUBY_VERSION) < Gem::Version.new(RECOMMENDED_RUBY)
        end

        def display_ruby_warning
          ruby_warning = Terminal::Table.new
          ruby_warning.title = "Ruby Recommended Version Warning"
          ruby_warning.add_row(["Please update your Ruby installation."])
          ruby_warning.add_row(["You're currently running Ruby v#{Gem::Version.new(RUBY_VERSION)}!"])
          ruby_warning.add_row(["It's recommended to run Ruby v#{Gem::Version.new(RECOMMENDED_RUBY)} or higher!"])
          ruby_warning.add_row(["Future Lich5 releases will soon require this newer version."])
          ruby_warning.add_row([" "])
          ruby_warning.add_row(["Visit the following link for info on updating:"])

          # Use instance to get the appropriate documentation URL
          if @game_instance
            ruby_warning.add_row([@game_instance.get_documentation_url])
          else
            ruby_warning.add_row(["Unknown game type detected."])
            ruby_warning.add_row(["Unsure of proper documentation, please seek assistance via discord!"])
          end

          ruby_warning.to_s.split("\n").each do |row|
            Lich::Messaging.mono(Lich::Messaging.monsterbold(row))
          end
        end

        def start_cli_scripts
          if (arg = ARGV.find { |a| a =~ /^\-\-start\-scripts=/ })
            arg.sub('--start-scripts=', '').split(',').each do |script_name|
              Script.start(script_name)
            end
          end
          @cli_scripts = true
          Lich.log("info: logged in as #{XMLData.game}:#{XMLData.name}")
        end

        def process_xml_data(server_string)
          begin
            # Ox is a permissive parser: it handles Simu's not-quite-XML stream
            # without the clean/retry dance REXML required (nested quotes, missing
            # 'd' end tags, etc. are tolerated rather than raised). XMLData itself
            # implements the Ox::Sax interface, so Ox parses straight into it. No
            # <root> wrapper needed: that was a REXML requirement (single root); Ox
            # handles multiple top-level elements and bare text directly.
            XMLData.sax_parse_errors.clear
            # convert_special: false keeps Ox in bytes-land: it never decodes a
            # numeric entity (e.g. &#8217;) into UTF-8. The five standard XML
            # entities are decoded by XMLData#attr/#text instead. Values are left
            # in Ox's native (ASCII-8BIT) encoding -- REXML effectively produced
            # ASCII for this (high-byte-scrubbed) stream, so retagging to
            # Windows-1252 was a divergence and caused entity corruption.
            Ox.sax_parse(XMLData, server_string, convert_special: false, symbolize: false, skip: :skip_none)
            check_stream_desync!(XMLData.sax_parse_errors)
            repair_malformed_attributes_and_reparse(server_string)
          rescue GameStreamDesyncError => e
            # A truncated/desynced fragment. Ox never raises on malformed stream
            # content -- it reports via the error callback, and check_stream_desync!
            # promotes truncation-class errors to this exception. Log and reset
            # rather than killing the server thread.
            Lich.log "warning: stream desync (#{e.message}); resetting XMLData: #{server_string.inspect}"
            XMLData.reset
            return
          end

          stripped_server = strip_xml(server_string, type: "main")

          # Process game-specific data using instance
          if @game_instance && Module.const_defined?(:GameLoader)
            @game_instance.process_game_specific_data(server_string, stripped_server)
          end

          # Process downstream XML
          Script.new_downstream_xml(server_string) if defined?(Script)

          # Process stripped server string
          stripped_server.split("\r\n").each do |line|
            @buffer.update(line) if defined?(TESTING) && TESTING
            Script.new_downstream(line) if defined?(Script) && !line.empty?
          end
        end

        # Promote truncation-class Ox parse errors to GameStreamDesyncError so
        # a desynced stream still hits the log + reset recovery path instead of
        # being silently absorbed (see the GameStreamDesyncError comment).
        # parse_errors is XMLData's collected Ox error-callback messages for
        # the fragment just parsed.
        def check_stream_desync!(parse_errors)
          desync = parse_errors.find do |message|
            STREAM_DESYNC_ERRORS.any? { |pattern| pattern.match?(message) }
          end
          raise GameStreamDesyncError, desync if desync
        end

        # Ox reports "no attribute value" for two repairable malformations that
        # scatter a tag into junk attributes: the settingsInfo space-not-found
        # server bug, and a same-quote inside a quoted value (Simu's dynamic
        # dialogs, e.g. title='Tsetem's Items'). Both raised in REXML and were
        # repaired in the rescue; Ox tolerates them, so drive the repair off its
        # error report -- only the rare flagged line pays the cost. Apply the
        # repairs; if any changed the line, drop the junk the first parse committed
        # and parse once more, ignoring any errors on that pass so we never loop.
        # Escaped &apos;/&quot; round-trip back to the literal char via
        # XmlEntities.decode and the front-end's own entity decoding.
        def repair_malformed_attributes_and_reparse(server_string)
          return unless XMLData.sax_parse_errors.any? { |message| NO_ATTRIBUTE_VALUE_ERROR.match?(message) }

          before = server_string.dup
          fix_invalid_settings_info(server_string)
          XMLCleaner.clean_nested_quotes(server_string)
          return if server_string == before # nothing to repair (e.g. a genuine valueless attribute)

          XMLData.reset
          XMLData.sax_parse_errors.clear
          Ox.sax_parse(XMLData, server_string, convert_special: false, symbolize: false, skip: :skip_none)
        end

        # The server sends a malformed <settingsInfo ... space not found .../> (an
        # attribute with no '=') to characters that have never connected with the
        # Wrayth/StormFront client. REXML raised on it (the rescue repaired it); Ox
        # tolerates it and emits "no attribute value", so it is repaired from
        # repair_malformed_attributes_and_reparse. @@settings_init_needed makes
        # gameloader's PostLoad seed a valid client record (see settings_init_needed?
        # and lib/common/gameloader.rb).
        def fix_invalid_settings_info(server_string)
          return unless server_string =~ /<settingsInfo .*?space not found /

          Lich.log "Invalid settingsInfo XML tags detected: #{server_string.inspect}"
          server_string.sub!(/\s\bspace not found\b\s/, " client='1.0.1.28' ")
          Lich.log "Invalid settingsInfo XML tags fixed to: #{server_string.inspect}"
          @@settings_init_needed = true
        end

        def process_downstream_hooks(server_string)
          if (alt_string = DownstreamHook.run(server_string))
            process_room_information(alt_string)

            # Handle frontend-specific modifications
            if Frontend.client.eql?('genie') && alt_string =~ /^<streamWindow id='room' title='Room' subtitle=" - \[.*\] \((?:\d+|\*\*)\)"/
              alt_string.sub!(/] \((?:\d+|\*\*)\)/) { "]" }
            end

            if Frontend.client.eql?('frostbite') && alt_string =~ /^<streamWindow id='main' title='Story' subtitle=" - \[.*\] \((?:\d+|\*\*)\)"/
              alt_string.sub!(/] \((?:\d+|\*\*)\)/) { "]" }
            end

            # Handle room number display
            if @room_number_after_ready && alt_string =~ /<prompt /
              alt_string = @game_instance ? @game_instance.process_room_display(alt_string) : alt_string
              @room_number_after_ready = false
            end

            # Handle frontend-specific conversions
            if Frontend.supports_gsl?
              alt_string = sf_to_wiz(alt_string)
            end
            # Handle prefix origin sentinel if FE supports it
            alt_string = prefix_origin_sentinel(alt_string) if Frontend.supports_sentinel?

            # Send to client
            send_to_client(alt_string)
          end
        end

        def process_room_information(alt_string)
          if alt_string =~ /^(<pushStream id="familiar" ifClosedStyle="watching"\/>)?(?:<resource picture="\d+"\/>|<popBold\/>)?<style id="roomName"\s+\/>/
            if (Lich.display_lichid == true || Lich.display_uid == true || Lich.hide_uid_flag == true)
              @game_instance ? @game_instance.modify_room_display(alt_string) : alt_string
            end
            @room_number_after_ready = true
            alt_string
          end
        end

        def send_to_client(alt_string)
          detachable_clients = $_DETACHABLE_CLIENT_REGISTRY_&.snapshot || []
          detachable_clients = [$_DETACHABLE_CLIENT_] if detachable_clients.empty? && $_DETACHABLE_CLIENT_
          if !detachable_clients.empty?
            detachable_clients.each { |client| client.write(alt_string) if client.alive? }
          elsif $_CLIENT_
            $_CLIENT_.write(alt_string)
          end
        end

        def handle_thread_error(error)
          if recognized_connection_disruption?(error)
            shutdown_log.info("server_thread: #{connection_disruption_log_message(error)}")
            shutdown_log.debug("server_thread backtrace: #{error.backtrace.join("\n\t")}") if error.backtrace
          else
            shutdown_log.error("server_thread: #{error}\n\t#{Array(error.backtrace).join("\n\t")}")
          end
          sleep 0.2

          case error
          when Errno::ETIMEDOUT, Errno::EWOULDBLOCK, IO::TimeoutError
            # Timeout errors reach this outer handler only after the inner
            # reader loop has exhausted its consecutive-timeout threshold.
            shutdown_log.info("game timeout - will not retry")
            return false
          when Errno::ECONNRESET, Errno::EPIPE, Errno::ECONNABORTED
            # Connection errors are fatal
            shutdown_log.info("connection error - will not retry")
            return false
          when GameStreamDesyncError
            shutdown_log.info("game stream desync detected - will not retry")
            return false
          when ServerQueueOverflow
            shutdown_log.info("game parser queue overflow - will not retry")
            return false
          else
            # Check if socket/client are closed or if it's a known fatal error
            if !$_CLIENT_.alive? || @socket.closed?
              shutdown_log.info("client or socket closed - will not retry")
              return false
            elsif error.to_s =~ /invalid argument|A connection attempt failed|An existing connection was forcibly closed|An established connection was aborted by the software in your host machine./i
              shutdown_log.info("fatal error pattern detected - will not retry")
              return false
            else
              shutdown_log.debug("unknown server thread error - will attempt retry")
              return true
            end
          end
        end

        def shutdown_reason_for_thread_exit(error)
          case error
          when Errno::ETIMEDOUT, Errno::EWOULDBLOCK, IO::TimeoutError
            :game_timeout
          when Errno::ECONNRESET
            :connection_reset
          when Errno::EPIPE
            :connection_pipe
          when Errno::ECONNABORTED
            :connection_aborted
          when GameStreamDesyncError
            :game_stream_desync
          when ServerQueueOverflow
            :unrecoverable_game_thread_error
          else
            :unrecoverable_game_thread_error
          end
        end

        def record_shutdown_reason(reason, source:, detail: nil)
          return unless defined?(Lich::Common::ShutdownCoordinator)

          Lich::Common::ShutdownCoordinator.request(reason: reason, source: source, detail: detail)
        rescue StandardError => e
          shutdown_log.warning("failed to record shutdown reason #{reason.inspect}: #{e.class}: #{e.message}")
        end

        def shutdown_log
          Lich::Common::ShutdownLog
        end

        def intentional_shutdown_close_error?(error)
          return false unless defined?(Lich::Common::ShutdownCoordinator)
          return false unless Lich::Common::ShutdownCoordinator.orderly_user_exit?
          return false unless @socket&.closed?

          error.is_a?(Errno::EBADF) ||
            error.to_s =~ /stream closed in another thread|closed stream|bad file descriptor/i
        end

        def recognized_connection_disruption?(error)
          error.is_a?(Errno::ETIMEDOUT) ||
            error.is_a?(Errno::EWOULDBLOCK) ||
            error.is_a?(IO::TimeoutError) ||
            error.is_a?(Errno::ECONNRESET) ||
            error.is_a?(Errno::EPIPE) ||
            error.is_a?(Errno::ECONNABORTED) ||
            error.is_a?(GameStreamDesyncError)
        end

        def connection_disruption_log_message(error)
          return "GameStreamDesyncError: #{error.message.lines.first&.strip}" if error.is_a?(GameStreamDesyncError)

          "#{error.class}: #{error.message}"
        end

        protected

        def log_error(message, error)
          Lich.log "#{message}: #{error}\n\t#{error.backtrace.join("\n\t")}"
        end
      end
    end
  end

  # Gemstone game module
  module Gemstone
    include Lich

    # Base class for character status tracking
    class CharacterStatus
      class << self
        def fix_injury_mode(mode = 'both') # Default mode 'both' handles wounds (precedence) then scars
          case mode
          when 'scar', 'scars'
            unless XMLData.injury_mode == 1
              Game._puts '_injury 1'
              150.times { sleep 0.05; break if XMLData.injury_mode == 1 }
            end
          when 'wound', 'wounds' # future proof leaving in place, but this will likely not be used
            unless XMLData.injury_mode == 0
              Game._puts '_injury 0'
              150.times { sleep 0.05; break if XMLData.injury_mode == 0 }
            end
          when 'both'
            unless XMLData.injury_mode == 2
              Game._puts '_injury 2'
              150.times { sleep 0.05; break if XMLData.injury_mode == 2 }
            end
          else
            raise ArgumentError, "Invalid mode: #{mode}. Use 'scar', 'wound', or 'both'."
          end
        end

        def method_missing(_method_name = nil)
          result = Lich::Messaging.mono(Lich::Messaging.msg_format("bold", "#{self.name.split('::').last}: Invalid area, try one of these: arms, limbs, torso, #{XMLData.injuries.keys.join(', ')}"))
          # the _respond method used in Lich::Messaging returns nil upon success
          return result
        end
      end
    end

    # Gemstone-specific game instance
    class GameInstance < GameBase::GameInstance::Base
      def clean_serverstring(server_string)
        # The Rift, Scatter is broken...
        if server_string =~ /<compDef id='room text'><\/compDef>/
          server_string.sub!(/(.*)\s\s<compDef id='room text'><\/compDef>/) { "<compDef id='room desc'>#{$1}</compDef>" }
        end

        # Handle combat and atmospherics
        server_string = handle_combat_tags(server_string)
        server_string = handle_atmospherics(server_string)

        server_string
      end

      def handle_combat_tags(server_string)
        if @combat_count > 0
          @end_combat_tags.each do |tag|
            if server_string.include?(tag)
              server_string = server_string.gsub(tag, "<popStream id=\"combat\" />" + tag) unless server_string.include?("<popStream id=\"combat\" />")
              @combat_count -= 1
            end
            if server_string.include?("<pushStream id=\"combat\" />")
              server_string = server_string.gsub("<pushStream id=\"combat\" />", "")
            end
          end
        end

        increment_combat_count(server_string)
        server_string
      end

      def handle_atmospherics(server_string)
        if @atmospherics
          @atmospherics = false
          server_string.prepend('<popStream id="atmospherics" />') unless server_string =~ /<popStream id="atmospherics" \/>/
        end

        if server_string =~ /<pushStream id="familiar" \/><prompt time="[0-9]+">&gt;<\/prompt>/ # Cry For Help spell is broken...
          server_string.sub!('<pushStream id="familiar" />', '')
        elsif server_string =~ /<pushStream id="atmospherics" \/><prompt time="[0-9]+">&gt;<\/prompt>/ # pet pigs in DragonRealms are broken...
          server_string.sub!('<pushStream id="atmospherics" />', '')
        elsif (server_string =~ /<pushStream id="atmospherics" \/>/)
          @atmospherics = true
        end

        server_string
      end

      def get_documentation_url
        "https://gswiki.play.net/Lich:Software/Installation"
      end

      def process_game_specific_data(server_string, stripped_server = nil)
        # Infomon's XML-level parse needs the raw string; its line parser reuses
        # the text already stripped by process_xml_data (XMLParser.parse does not
        # mutate, so no dup or second strip_xml is needed).
        Infomon::XMLParser.parse(server_string)
        stripped_server.split("\r\n").each do |line|
          Infomon::Parser.parse(line) unless line.empty?
        end
      end

      def modify_room_display(alt_string)
        uid_from_string = alt_string.match(/] \((?<uid>\d+)\)/)
        if uid_from_string.nil?
          lichid_from_uid_string = Room.current.id
        else
          lichid_from_uid_string = Room["u#{uid_from_string[:uid]}"].id.to_i
        end
        if Lich.display_lichid == true
          alt_string.sub!(']') { " - #{lichid_from_uid_string}]" }
        end

        if Lich.display_uid == true
          alt_string.sub!(/] \(\d+\)/) { "]" }
          alt_string.sub!(']') { "] (#{(uid_from_string.nil? || XMLData.room_id == uid_from_string[:uid].to_i) ? ((XMLData.room_id == 0 || XMLData.room_id > 4294967296) ? "unknown" : "u#{XMLData.room_id}") : uid_from_string[:uid].to_i})" }
        end

        alt_string
      end

      # Prepends the shared exit / StringProc lines, and mirrors the exits into
      # the GemStone room window on frontends that host one (once per new room).
      # @param alt_string [String] the server string being rewritten
      # @return [String] the rewritten server string
      def process_room_display(alt_string)
        exits = room_exit_entries
        alt_string = prepend_room_lines(alt_string, room_stringproc_entries, exits)

        if !exits.empty? && Frontend.supports_room_window? && Map.current.id != Game.instance_variable_get(:@last_id_shown_room_window)
          alt_string = "#{alt_string}<pushStream id='room' ifClosedStyle='watching'/>Room Exits: #{exits.join(', ')}\r\n<popStream/>\r\n"
          Game.instance_variable_set(:@last_id_shown_room_window, Map.current.id)
        end

        alt_string
      end
    end

    # Game class for Gemstone
    class Game < GameBase::Game
      class << self
        def initialize
          initialize_buffers
          set_game_instance('GS')
        end
      end

      # Initialize the class only if not already connected
      initialize if @socket.nil?
    end
  end

  # DragonRealms game module
  module DragonRealms
    include Lich

    # DragonRealms-specific game instance
    class GameInstance < GameBase::GameInstance::Base
      def clean_serverstring(server_string)
        # Buffer split room objs components (server sends "...wait N seconds." separately)
        should_skip, server_string = buffer_room_objs(server_string)
        return nil if should_skip

        # Clear out superfluous tags
        server_string = server_string.gsub("<pushStream id=\"combat\" /><popStream id=\"combat\" />", "")
        server_string = server_string.gsub("<popStream id=\"combat\" /><pushStream id=\"combat\" />", "")

        # Fix encoding issues
        server_string = GameBase::XMLCleaner.fix_invalid_characters(server_string)

        # Fix combat wrapping components
        server_string = server_string.gsub("<pushStream id=\"combat\" /><component id=", "<component id=")

        # Fix XML tags
        server_string = GameBase::XMLCleaner.fix_xml_tags(server_string)

        # Fix duplicate pushStrings
        while server_string.include?("<pushStream id=\"combat\" /><pushStream id=\"combat\" />")
          server_string = server_string.gsub("<pushStream id=\"combat\" /><pushStream id=\"combat\" />", "<pushStream id=\"combat\" />")
        end

        # Handle combat and atmospherics
        server_string = handle_combat_tags(server_string)
        server_string = handle_atmospherics(server_string)

        server_string
      end

      def handle_combat_tags(server_string)
        if @combat_count > 0
          @end_combat_tags.each do |tag|
            if server_string.include?(tag)
              server_string = server_string.gsub(tag, "<popStream id=\"combat\" />" + tag) unless server_string.include?("<popStream id=\"combat\" />")
              @combat_count -= 1
            end
            if server_string.include?("<pushStream id=\"combat\" />")
              server_string = server_string.gsub("<pushStream id=\"combat\" />", "")
            end
          end
        end

        increment_combat_count(server_string)
        server_string
      end

      def handle_atmospherics(server_string)
        if @atmospherics
          @atmospherics = false
          server_string.prepend('<popStream id="atmospherics" />') unless server_string =~ /<popStream id="atmospherics" \/>/
        end

        if server_string =~ /<pushStream id="familiar" \/><prompt time="[0-9]+">&gt;<\/prompt>/ # Cry For Help spell is broken...
          server_string.sub!('<pushStream id="familiar" />', '')
        elsif server_string =~ /<pushStream id="atmospherics" \/><prompt time="[0-9]+">&gt;<\/prompt>/ # pet pigs in DragonRealms are broken...
          server_string.sub!('<pushStream id="atmospherics" />', '')
        elsif (server_string =~ /<pushStream id="atmospherics" \/>/)
          @atmospherics = true
        end

        server_string
      end

      def get_documentation_url
        "https://github.com/elanthia-online/lich-5/wiki/Documentation-for-Installing-and-Upgrading-Lich"
      end

      def process_game_specific_data(server_string, _stripped_server = nil)
        # Parse directly to allow inline modifications (e.g., inline exp display)
        # The parser modifies server_string in place via line.replace()
        DRParser.parse(server_string)
      end

      def modify_room_display(alt_string)
        if Lich.display_uid == true
          alt_string.sub!(/] \((?:\d+|\*\*)\)/) { "]" }
        elsif Lich.hide_uid_flag == true
          alt_string.sub!(/] \((?:\d+|\*\*)\)/) { "]" }
        end

        alt_string
      end

      # Prepends the shared exit / StringProc lines plus the DragonRealms
      # "Room Number:" line, and updates the room-window subtitle on frontends
      # that host one. The visible room-number line honors the mono toggle; the
      # streamWindow subtitle tags are title-bar metadata and are left as-is.
      # @param alt_string [String] the server string being rewritten
      # @return [String] the rewritten server string
      def process_room_display(alt_string)
        alt_string = prepend_room_lines(alt_string, room_stringproc_entries, room_exit_entries)

        # DR-specific room number display
        room_number = ""
        room_number += "#{Map.current.id}" if Lich.display_lichid
        room_number += " - " if Lich.display_lichid && Lich.display_uid
        room_number += "(#{XMLData.room_id == 0 ? "**" : "u#{XMLData.room_id}"})" if Lich.display_uid

        unless room_number.empty?
          alt_string = "#{room_styled("Room Number: #{room_number}")}\r\n#{alt_string}"
          if Frontend.supports_room_window?
            alt_string = "<streamWindow id='main' title='Story' subtitle=\" - [#{XMLData.room_title[2..-3]} - #{room_number}]\" location='center' target='drop'/>\r\n#{alt_string}"
            alt_string = "<streamWindow id='room' title='Room' subtitle=\" - [#{XMLData.room_title[2..-3]} - #{room_number}]\" location='center' target='drop' ifClosed='' resident='true'/>#{alt_string}"
          end
        end

        alt_string
      end
    end

    # Game class for DragonRealms
    class Game < GameBase::Game
      class << self
        def initialize
          initialize_buffers
          set_game_instance('DR')
        end
      end

      # Initialize the class only if not already connected
      initialize if @socket.nil?
    end
  end
end
