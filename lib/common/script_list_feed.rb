# frozen_string_literal: true

module Lich
  module Common
    # Pushes the list of running scripts to every front end that gets it
    # (docs/frontends/script-list-feed.md), in one of two forms, each a feed
    # in ClientCapabilities (declared with +SET_FRONTEND_CAPS+, from
    # +--frontend-caps=+, or from the frontend catalog):
    #
    # * +script_list+, data for a front end that draws its own panel:
    #
    #     <lichScripts v="1" char="%3B" list="bigshot:0,go2:1"/>
    #
    #   +char+ is the Lich command character and +list+ is the scripts ;list
    #   shows (hidden ones are left out), each as +name:paused+ with paused 1
    #   or 0. Both are percent-encoded, so no script name can break the tag. A
    #   front end replaces its whole list with each tag it gets.
    #
    # * +script_window+, a StormFront-style stream window (WINDOW_ID) that
    #   Lich fills itself: each script on a line with pause/unpause and kill
    #   links. Any front end that renders stream windows shows it with no
    #   change of its own; the catalog turns it on for those that do.
    #
    # A client that declares +script_list+ replaces its feed set with that,
    # so it stops getting the window; one that declares both gets both.
    #
    # The list goes to a client as soon as it gets a feed, and again only
    # when the list changes: nothing is resent on a timer. A client that
    # loses its copy (a view reload without re-attaching) sends its
    # SET_FRONTEND_CAPS line again to be sent the current list. The command
    # character is set once at startup (lib/main/main.rb), so it never
    # changes the list on its own. Script lifecycle code calls
    # +changed!+, which only flags the change: the send happens on this
    # module's own thread, so no socket write runs under a script registry
    # lock, and a burst of changes (a ;kill all) goes out as one update.
    #
    # What each client was last sent is recorded per client, and every send
    # (the attach-time one and the thread's) takes the snapshot and writes it
    # under one lock. So a client that joins mid-change is compared with what
    # it actually got, and an older snapshot can never land after a newer
    # one.
    #
    # The tag is written to the client sockets directly, never through
    # +_respond+, so scripts that watch script output never see it.
    module ScriptListFeed
      # The data feed and its element.
      LIST = :script_list
      ELEMENT = 'lichScripts'
      VERSION = 1

      # The stream-window feed, its stream id and its title.
      WINDOW = :script_window
      WINDOW_ID = 'scripts'
      WINDOW_TITLE = 'Lich Scripts'

      # Every form, in the order they are sent to a client that gets both.
      FORMS = [LIST, WINDOW].freeze

      # Seconds to wait after a change before sending, to fold a burst into one tag.
      SETTLE = 0.1

      # Characters left as they are; everything else is percent-encoded.
      UNRESERVED = %r{[^A-Za-z0-9_./-]}
      private_constant :UNRESERVED

      @mutex = Mutex.new
      @wakeup = ConditionVariable.new
      @dirty = false
      @thread = nil
      # Held while a snapshot is taken and written, by client_ready and by
      # publish. Lock order: this, then the script registry (Script.running);
      # nothing that holds the registry lock ever takes this.
      @send_mutex = Mutex.new
      # Each client's last data tag sent, keyed by the client object itself.
      @sent = {}.compare_by_identity

      class << self
        # Percent-encodes every byte outside A-Z, a-z, 0-9 and _ . / -.
        #
        # @param text [#to_s]
        # @return [String]
        def encode(text)
          text.to_s.gsub(UNRESERVED) { |char| char.bytes.map { |byte| format('%%%02X', byte) }.join }
        end

        # Builds the tag for a list of scripts.
        #
        # @param scripts [Array<#name, #paused?>] the scripts to list, in order
        # @param lich_char [String] the Lich command character
        # @return [String]
        def tag(scripts = Script.running, lich_char = $clean_lich_char)
          entries = scripts.map { |script| "#{encode(script.name)}:#{script.paused? ? 1 : 0}" }
          %(<#{ELEMENT} v="#{VERSION}" char="#{encode(lich_char)}" list="#{entries.join(',')}"/>)
        end

        # Builds the stream window for a list of scripts: the window
        # definition, a clear, and one line per script with links that send
        # the same ;pause, ;unpause and ;kill a user would type. ifClosed=''
        # keeps the lines out of the main window when the window is closed.
        #
        # @param scripts [Array<#name, #paused?>] the scripts to list, in order
        # @param lich_char [String] the Lich command character
        # @return [String] several lines joined with CRLF
        def window(scripts = Script.running, lich_char = $clean_lich_char)
          lines = scripts.map do |script|
            toggle = script.paused? ? 'unpause' : 'pause'
            "#{xml_escape(script.name)}#{' (paused)' if script.paused?}  " \
              "#{link(lich_char, toggle, script.name)} #{link(lich_char, 'kill', script.name)}"
          end
          lines = ['No scripts running.'] if lines.empty?
          [%(<streamWindow id="#{WINDOW_ID}" title="#{WINDOW_TITLE}" ifClosed="" resident="true"/>),
           %(<clearStream id="#{WINDOW_ID}"/>),
           %(<pushStream id="#{WINDOW_ID}"/>#{lines.join("\r\n")}),
           '<popStream/>'].join("\r\n")
        end

        # Escapes the characters that would break XML text or a quoted
        # attribute.
        #
        # @param text [#to_s]
        # @return [String]
        def xml_escape(text)
          text.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;')
        end

        # Notes that the list may have changed. Cheap and safe to call while
        # holding script registry or lifecycle locks: it takes only this
        # module's own lock, does no I/O, and does nothing at all until some
        # client has asked for the feed.
        #
        # @return [nil]
        def changed!
          return nil unless @thread

          @mutex.synchronize do
            @dirty = true
            @wakeup.signal
          end
          nil
        end

        # Called when a client attaches and again after each capability
        # declaration it sends. When the client wants the feed, sends it the
        # current list straight away and makes sure the change thread runs.
        #
        # Never raises: it runs on the client's own read loop, and a feed
        # failure must not take that client's session down with it.
        #
        # @param client [#alive?, #puts_main_stream] the client
        # @return [Boolean] whether anything was sent
        def client_ready(client)
          return false unless wants?(client)

          start
          @send_mutex.synchronize do
            scripts = Script.running
            lich_char = $clean_lich_char
            send_to(client, scripts, lich_char, tag(scripts, lich_char))
          end
        rescue StandardError => e
          log("error: script list feed: #{e}\n\t#{e.backtrace&.first}")
          false
        end

        # The forms a client gets, in FORMS order: none for a dead client.
        #
        # @param client [Object, nil]
        # @return [Array<Symbol>]
        def forms_for(client)
          return [] unless client.respond_to?(:alive?) && client.alive?

          feeds = ClientCapabilities.feeds_for(client)
          FORMS.select { |form| feeds.include?(form) }
        end

        # Whether a client gets the list in any form.
        #
        # @param client [Object, nil]
        # @return [Boolean]
        def wants?(client)
          !forms_for(client).empty?
        end

        # Every connected client that gets the feed: the primary client and
        # each detachable one.
        #
        # @return [Array]
        def subscribers
          clients = []
          clients << $_CLIENT_ if defined?($_CLIENT_)
          clients.concat(detachable_clients_snapshot) if respond_to?(:detachable_clients_snapshot, true)
          clients.compact.uniq.select { |client| wants?(client) }
        end

        # Starts the change thread if it is not running. Called lazily, so a
        # session where no client asks for the feed never starts it.
        #
        # @return [Thread]
        def start
          @mutex.synchronize do
            return @thread if @thread&.alive?

            @thread = Thread.new { run }
            @thread.name = 'lich-script-list-feed' if @thread.respond_to?(:name=)
            @thread
          end
        end

        # Sends the list to each subscriber, in its own forms, whose last
        # list differs from the current one. The data tag stands for the list:
        # both forms are built from the same scripts and command character.
        #
        # @return [Boolean] whether anything was sent
        def publish
          @send_mutex.synchronize do
            clients = subscribers
            # Forget clients that left or stopped getting a feed.
            @sent.keep_if { |client, _tag| clients.any? { |current| current.equal?(client) } }
            scripts = Script.running
            lich_char = $clean_lich_char
            tag = tag(scripts, lich_char)
            sent = clients.select { |client| @sent[client] != tag && send_to(client, scripts, lich_char, tag) }
            !sent.empty?
          end
        end

        # Stops the change thread and forgets what was sent. For specs and
        # shutdown.
        #
        # @return [nil]
        def reset!
          thread = nil
          @mutex.synchronize do
            thread = @thread
            @thread = nil
            @dirty = false
            @wakeup.broadcast
          end
          thread&.kill
          thread&.join(1)
          @send_mutex.synchronize { @sent.clear }
          nil
        end

        private

        def run
          loop do
            @mutex.synchronize do
              @wakeup.wait(@mutex) until @dirty
              @dirty = false
            end
            sleep SETTLE
            begin
              publish
            rescue StandardError => e
              log("error: script list feed: #{e}\n\t#{e.backtrace&.first}")
            end
          end
        end

        def link(lich_char, verb, name)
          %(<d cmd="#{xml_escape("#{lich_char}#{verb} #{name}")}">#{verb}</d>)
        end

        # Writes the list to a client and records it as that client's last
        # list. Called with @send_mutex held. Not recorded when the write
        # failed, so the next publish tries again.
        def send_to(client, scripts, lich_char, tag)
          return false unless deliver(client, scripts, lich_char)

          @sent[client] = tag
          true
        end

        # Writes the list to one client in each form it gets.
        def deliver(client, scripts, lich_char)
          forms = forms_for(client)
          return false if forms.empty?

          forms.map do |form|
            client.puts_main_stream(form == LIST ? tag(scripts, lich_char) : window(scripts, lich_char))
          end.all?
        rescue StandardError => e
          log("warning: script list feed: #{e}")
          false
        end

        def log(message)
          Lich.log(message) if Lich.respond_to?(:log)
        end
      end
    end
  end
end
