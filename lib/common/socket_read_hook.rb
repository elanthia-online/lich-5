# frozen_string_literal: true

module Lich
  module Common
    # Read-only hooks that run immediately after a complete line is read from
    # the game socket, before XML parsing, RawHook, DownstreamHook, or frontend
    # writes. Hooks intentionally run inline, like the existing hook chains, to
    # preserve exact reader-before-parser ordering.
    class SocketReadHook
      Event = Struct.new(:server_string, :received_at, :monotonic_received_at, keyword_init: true)

      @@hooks ||= {}
      @@hook_sources ||= {}
      @@mutex ||= Mutex.new

      def self.add(name, action = nil, &block)
        action ||= block
        unless action.is_a?(Proc)
          raise ArgumentError, "SocketReadHook: not a Proc (#{action.inspect})"
        end

        @@mutex.synchronize do
          @@hook_sources[name.to_s] = current_source
          @@hooks[name.to_s] = action
        end
        name
      end

      def self.add_daemon_hook(name, &block)
        add(name, &block)
      end

      def self.add_script_hook(name, &block)
        add(name, &block)
        before_dying { remove(name) } if defined?(before_dying)
        name
      end

      def self.remove(name)
        @@mutex.synchronize do
          @@hook_sources.delete(name.to_s)
          @@hooks.delete(name.to_s)
        end
      end

      def self.list
        @@mutex.synchronize { @@hooks.keys.dup }
      end

      def self.hook_sources
        @@mutex.synchronize { @@hook_sources.dup }
      end

      def self.sources
        info_table = Terminal::Table.new :headings => ['Hook', 'Source'],
                                         :rows     => hook_sources.to_a,
                                         :style    => { :all_separators => true }
        Lich::Messaging.mono(info_table.to_s)
      end

      def self.run(server_string, received_at: Time.now, monotonic_received_at: monotonic_now)
        raw = server_string.dup.freeze
        event = Event.new(
          server_string: raw,
          received_at: received_at,
          monotonic_received_at: monotonic_received_at
        ).freeze

        entries.each do |name, action|
          invoke(action, raw, event)
        rescue StandardError => e
          remove(name)
          Lich.log "SocketReadHook #{name}: #{e.class}: #{e.message}\n\t#{e.backtrace&.first}"
        end
        nil
      end

      def self.entries
        @@mutex.synchronize { @@hooks.to_a }
      end

      def self.current_source
        if defined?(Script) && Script.respond_to?(:current) && Script.current
          Script.current.name || 'Unknown'
        else
          'core'
        end
      rescue StandardError
        'Unknown'
      end

      def self.invoke(action, raw, event)
        if action.lambda?
          case action.arity
          when 0
            action.call
          when 1
            action.call(raw)
          else
            action.call(raw, event)
          end
        else
          action.call(raw, event)
        end
      end

      def self.monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      private_class_method :entries, :current_source, :invoke, :monotonic_now
    end
  end
end
