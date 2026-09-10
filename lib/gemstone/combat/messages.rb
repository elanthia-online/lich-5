# frozen_string_literal: true

#
# Combat Messages - the non-combat message families (defs/messages.rb)
# delivered through Combat::Observers, scanned only while subscribed.
#
# The Tracker's hook chunks on the prompt and only hands a chunk to the
# Processor when it names a creature; most of these lines arrive in
# chunks that name none (an itchy curse, an item limit, a bolt). So the
# messages have their own hook, one line at a time, installed the moment
# the first subscription to a message event appears and removed with the
# last. Scanning is gated twice: a family is only tried when one of its
# events has a subscriber, and each family's PatternGate literal union
# rejects most lines before any def pattern runs. With no subscribers the
# hook is not even installed.
#
# Matching runs on a single worker thread fed by a queue, never on the
# game stream. Subscribers therefore run on that worker: the
# Combat::Observers contract applies - cheap, non-blocking, no game
# commands from the callback.
#
# @example
#   Combat::Tracker.on(:disarm_seen) { |_type, data| queue << data }
#   Combat::Tracker.on(:ambusher, :bolted, name: 'myscript') { |type, data| ... }
#
# Combat::Messages.scan(line) matches one line synchronously and returns
# what it would emit - for tools and specs.
#
require_relative 'observers'
require_relative 'defs/messages'

module Lich
  module Gemstone
    module Combat
      module Messages
        HOOK_ID = 'Combat::Messages::downstream'

        @mutex = Mutex.new
        @active = [].freeze
        @queue = nil
        @worker = nil
        @hook = false
        @scanned = 0
        @matched = 0

        class << self
          def families = Definitions::Messages::FAMILIES
          def events = Definitions::Messages::EVENTS

          # A message event, as opposed to a combat fact.
          def event?(type) = Definitions::Messages::FAMILY_OF.key?(type.to_sym)

          # The families with a subscriber for at least one of their events.
          def active_families = @active

          # Recompute the active families from the subscriptions and put the
          # hook up or take it down to match. Observers calls this on every
          # change; harmless to call again.
          def refresh!
            active = families.select { |f| f.events.any? { |e| Observers.any_for?(e) } }
            @mutex.synchronize { @active = active.freeze }
            active.empty? ? uninstall! : install!
            @active
          end

          # What one line yields, synchronously, over the given families
          # (the active ones by default; pass +families+ to scan them all).
          #
          # @return [Array<Array(Symbol, Hash)>]
          def scan(line, families: @active)
            Definitions::Messages.scan(line, families)
          end

          # Scan and emit, synchronously. Used by the worker; tools may call
          # it directly to replay a log.
          def process(line)
            found = scan(line)
            @scanned += 1
            @matched += found.size
            found.each { |event, data| Observers.emit(event, data) }
            found
          end

          # The hook's entry: enqueue for the worker, never block the stream.
          def enqueue(line)
            return if @active.empty?

            @queue ||= Queue.new
            @queue.push(line)
            ensure_worker
          end

          def installed? = @hook

          def stats
            { installed: @hook, families: @active.map(&:name), scanned: @scanned, matched: @matched,
              queued: @queue ? @queue.size : 0, worker_alive: !@worker.nil? && @worker.alive? }
          end

          # Drain and stop the worker (tests, shutdown).
          def shutdown
            return unless @worker&.alive?

            @queue&.push(:shutdown)
            @worker.join(2)
            @worker = nil
          end

          private

          def install!
            return if @hook
            return unless defined?(::DownstreamHook)

            hook = proc do |server_string|
              enqueue(server_string) if server_string.is_a?(String)
              server_string
            end
            ::DownstreamHook.add(HOOK_ID, hook, persist: true)
            @hook = true
          end

          def uninstall!
            return unless @hook

            ::DownstreamHook.remove(HOOK_ID) if defined?(::DownstreamHook)
            @hook = false
          end

          # One ordered worker, respawned if a script's death took it (the
          # same shape as AsyncProcessor).
          def ensure_worker
            return if @worker&.alive?

            @mutex.synchronize do
              next if @worker&.alive?

              @worker = Thread.new { run_loop }
            end
          end

          def run_loop
            loop do
              line = @queue.pop
              break if line == :shutdown

              begin
                process(line)
              rescue StandardError => e
                Lich.log "error: Combat::Messages worker: #{e.message}\n\t#{e.backtrace&.first}"
              end
            end
          end
        end

        Observers.on_change { refresh! }
      end
    end
  end
end
