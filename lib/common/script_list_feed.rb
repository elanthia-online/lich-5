# frozen_string_literal: true

module Lich
  module Common
    # Pushes the list of running scripts to every front end that asked for it
    # (docs/frontends/script-list-feed.md).
    #
    # A client opts in by declaring the +script_list+ capability with
    # +SET_FRONTEND_CAPS+ (or the session gets it from +--frontend-caps=+ or
    # the frontend catalog; see ClientCapabilities). Lich then sends it one
    # line:
    #
    #   <lichScripts v="1" char="%3B" list="bigshot:0,go2:1"/>
    #
    # +char+ is the Lich command character and +list+ is the scripts ;list
    # shows (hidden ones are left out), each as +name:paused+ with paused 1 or
    # 0. Both are percent-encoded, so no script name can break the tag. A front
    # end replaces its whole list with each tag it gets.
    #
    # The tag goes to a client as soon as it declares the capability, again
    # whenever the list changes, and every HEARTBEAT seconds, so a client that
    # reloads without re-attaching relearns it. Script lifecycle code calls
    # +changed!+, which only flags the change: the send happens on this
    # module's own thread, so no socket write runs under a script registry
    # lock, and a burst of changes (a ;kill all) goes out as one tag.
    #
    # The tag is written to the client sockets directly, never through
    # +_respond+, so scripts that watch script output never see it.
    module ScriptListFeed
      CAPABILITY = :script_list
      ELEMENT = 'lichScripts'
      VERSION = 1

      # Seconds between unconditional resends.
      HEARTBEAT = 30
      # Seconds to wait after a change before sending, to fold a burst into one tag.
      SETTLE = 0.1

      # Characters left as they are; everything else is percent-encoded.
      UNRESERVED = %r{[^A-Za-z0-9_./-]}
      private_constant :UNRESERVED

      @mutex = Mutex.new
      @wakeup = ConditionVariable.new
      @dirty = false
      @thread = nil
      @last_tag = nil
      @last_sent_at = nil

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
        # @return [Boolean] whether a tag was sent
        def client_ready(client)
          return false unless wants?(client)

          tag = current_tag
          start(tag)
          deliver(client, tag)
        rescue StandardError => e
          log("error: script list feed: #{e}\n\t#{e.backtrace&.first}")
          false
        end

        # Whether a client gets the feed.
        #
        # @param client [Object, nil]
        # @return [Boolean]
        def wants?(client)
          return false unless client.respond_to?(:alive?) && client.alive?

          ClientCapabilities.feeds_for(client).include?(CAPABILITY)
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
        # @param sent_tag [String, nil] the list the first subscriber is being
        #   sent, so the thread does not send that subscriber the same list
        #   again on a change ;list does not show (a hidden script starting)
        # @return [Thread]
        def start(sent_tag = nil)
          @mutex.synchronize do
            return @thread if @thread&.alive?

            # Seeded before the thread exists, so nothing reads these yet.
            @last_tag = sent_tag
            @last_sent_at = sent_tag && Time.now
            @thread = Thread.new { run }
            @thread.name = 'lich-script-list-feed' if @thread.respond_to?(:name=)
            @thread
          end
        end

        # Builds the tag, sends it to the subscribers when it changed or the
        # heartbeat is due, and records what was sent.
        #
        # @param now [Time]
        # @return [Boolean] whether anything was sent
        def publish(now = Time.now)
          tag = current_tag
          due = @last_sent_at.nil? || now - @last_sent_at >= HEARTBEAT
          return false if tag == @last_tag && !due

          subscribers.each { |client| deliver(client, tag) }
          @last_tag = tag
          @last_sent_at = now
          true
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
          @last_tag = nil
          @last_sent_at = nil
          nil
        end

        private

        def run
          loop do
            @mutex.synchronize do
              @wakeup.wait(@mutex, HEARTBEAT) unless @dirty
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

        def current_tag
          tag(Script.running, $clean_lich_char)
        end

        def deliver(client, tag)
          return false unless client.alive?

          client.puts_main_stream(tag) ? true : false
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
