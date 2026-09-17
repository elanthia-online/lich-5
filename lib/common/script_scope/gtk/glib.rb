# frozen_string_literal: true

require_relative 'session'

module Lich
  module Common
    module ScriptScope
      # GLib as far as scripts use it: timeouts, idles and source removal,
      # each running its block on the owning script's session thread.
      module GLib
        @sources = {}
        @sources_mutex = Mutex.new
        @source_id = 0

        class << self
          def register_source(thread)
            @sources_mutex.synchronize do
              id = (@source_id += 1)
              @sources[id] = thread
              id
            end
          end

          def remove_source(id)
            thread = @sources_mutex.synchronize { @sources.delete(id) }
            thread&.kill
            !thread.nil?
          end

          # One source: a thread that sleeps +interval+ seconds, runs +block+
          # on the session thread, and repeats while it answers true. Returns
          # the source id.
          #
          # The thread's ensure removes the source by id, and it used to read
          # that id from a closure variable the caller assigned only after
          # Thread.new returned. With interval 0 and a block that answers
          # false at once the thread reached its ensure first, saw nil,
          # skipped the removal, and left a dead entry in @sources forever.
          # The thread now waits on a queue for its own id, so it cannot get
          # to the ensure with anything but a registered one.
          def spawn_source(interval, session, &block)
            ready = Queue.new
            thread = Thread.new do
              id = ready.pop
              loop do
                sleep(interval)
                break unless session.sync { block.call }
              end
            rescue StandardError
              nil
            ensure
              GLib.remove_source(id) if id
            end
            id = register_source(thread)
            ready << id
            id
          end
        end

        module Timeout
          # Repeats +block+ every +interval+ ms on the session thread until it
          # returns false, like GLib::Timeout.add.
          def self.add(interval, &block)
            GLib.spawn_source(interval.to_f / 1000.0, Gtk::Session.current, &block)
          end

          def self.add_seconds(interval, &block)
            add(interval.to_f * 1000, &block)
          end
        end

        module Idle
          # Runs on the session thread, repeating while +block+ returns true.
          #
          # It used to re-enqueue itself directly and register a fresh source
          # each pass: a block that kept returning true queued the next run
          # with no delay at all, so the session thread spun on it, and every
          # pass leaked another entry in @sources. The id it handed back
          # mapped to nil, so Source.remove could never stop it either.
          #
          # Built on the same shape as Timeout.add, with the shortest wait
          # that still yields the thread: one source, cancellable, no spin.
          IDLE_INTERVAL = 0.01

          def self.add(&block)
            GLib.spawn_source(IDLE_INTERVAL, Gtk::Session.current, &block)
          end
        end

        module Source
          def self.remove(id)
            GLib.remove_source(id)
          end
        end
      end
    end
  end
end
