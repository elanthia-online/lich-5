# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require 'open3'
require 'rbconfig'

# Shim callbacks that call exit stop their Script owner (1843:RC3, settled
# decision B3): a queued or timed block, a signal handler, a close handler and
# a destroy handler run from a close or an explicit destroy each reach the core
# owner stop, which asks the Script to kill itself. Fresh process with a real
# host service and a Script-shaped owner that records kill requests.
RSpec.describe 'script compatibility owner stop' do
  def run_fresh(body)
    prelude = <<~RUBY_CODE
      require 'webui'
      require 'timeout'
      LOGS = Queue.new
      module Lich
        def self.log(message) = LOGS << message
        module Common
          class Script
            class << self
              attr_accessor :current
            end
          end
        end
      end
      def respond(*) = nil
      require 'common/script_scope/gtk/session'
      require 'common/script_scope/gtk/widgets'
      GTK = Lich::Common::ScriptScope::Gtk
      SERVICE = Lich::WebUI::Service.new(logger: ->(*) {})
      Lich::WebUI.define_singleton_method(:service) { SERVICE }
      SESSIONS = {}.compare_by_identity
      GTK.define_singleton_method(:session) do
        SESSIONS[Lich::Common::Script.current] ||= GTK::Session.new(Lich::Common::Script.current)
      end

      # Script-shaped owner: kill is requested asynchronously and flips stopping?;
      # join reports the owner's own teardown as finished.
      class KillableOwner
        attr_reader :name, :thread_group, :kills

        def initialize(name)
          @name = name
          @thread_group = ThreadGroup.new
          @kills = Queue.new
          @stopping = false
        end

        def kill(**options)
          @stopping = true
          @kills << options
          @name
        end

        def stopping? = @stopping
        def join(_timeout = nil) = self
      end

      # Runs the action as the owner and waits, bounded, for its kill request
      # and for the host to retire its pages.
      def stop_requested?(name)
        owner = KillableOwner.new(name)
        Lich::Common::Script.current = owner
        yield owner
        requested = owner.kills.pop(timeout: 3) == { async: true }
        Timeout.timeout(3) { sleep 0.02 until (SERVICE.registry.ensure_active!(owner) rescue :stopped) == :stopped }
        requested
      rescue Timeout::Error
        false
      end
    RUBY_CODE
    Open3.capture3(RbConfig.ruby, '-I', LIB_DIR, '-e', prelude + body + "\nSERVICE.stop\nputs 'ready'\n")
  end

  it 'stops the Script owner from a queued block, a timer, a signal handler and a close handler' do
    output, errors, status = run_fresh(<<~RUBY_CODE)
      event = Struct.new(:viewer_id).new(nil)
      results = {
        queue: stop_requested?('queue.lic') { GTK.session.queue { exit 3 } },
        timer: stop_requested?('timer.lic') { GTK.session.schedule(GTK, :add, 0) { exit 4 } },
        signal: stop_requested?('signal.lic') do |owner|
          SERVICE.runtime.dispatch(owner: owner) { GTK.session.callback(event) { exit 5 } }
        end,
        close: stop_requested?('close.lic') do
          GTK::Window.new('close').tap { |window| window.signal_connect('delete_event') { exit 6 } }.show_all
        end
      }
      abort "owner not stopped: \#{results.inspect}" unless results.values.all?
    RUBY_CODE

    expect([errors, status.success?]).to eq(['', true])
    expect(output).to eq("ready\n")
  end

  it 'stops the Script owner when a destroy handler exits during a close or an explicit destroy' do
    output, errors, status = run_fresh(<<~RUBY_CODE)
      closed = Queue.new
      results = {
        default_close: stop_requested?('default_close.lic') do
          window = GTK::Window.new('default')
          window.signal_connect('destroy') { closed << :default; exit 7 }
          window.show_all
        end,
        explicit: stop_requested?('explicit.lic') do
          window = GTK::Window.new('explicit')
          window.signal_connect('destroy') { closed << :explicit; exit 8 }
          GTK.session.queue { window.destroy }
        end
      }
      abort "owner not stopped: \#{results.inspect}" unless results.values.all?
      abort 'destroy handlers did not run' unless closed.size == 2
    RUBY_CODE

    expect([errors, status.success?]).to eq(['', true])
    expect(output).to eq("ready\n")
  end

  it 'leaves a live owner running after an ordinary destroy and contains an exit during teardown' do
    output, errors, status = run_fresh(<<~RUBY_CODE)
      owner = KillableOwner.new('ordinary.lic')
      Lich::Common::Script.current = owner
      ran = Queue.new
      window = GTK::Window.new('ordinary')
      window.signal_connect('destroy') { ran << true }
      GTK.session.queue { window.destroy }
      abort 'ordinary destroy handler did not run' unless ran.pop(timeout: 3)
      sleep 0.2 # settle only: the owner must not have been asked to stop
      abort 'ordinary destroy stopped its owner' unless owner.kills.empty?

      closing = KillableOwner.new('closing.lic')
      Lich::Common::Script.current = closing
      first, second = GTK::Window.new('one'), GTK::Window.new('two')
      survived = []
      first.signal_connect('destroy') { exit 9 }
      second.signal_connect('destroy') { survived << :second }
      GTK.session.close
      abort 'teardown exit escaped or skipped a window' unless first.destroyed? && second.destroyed? && survived == [:second]
      abort 'teardown exit requested a second stop' unless closing.kills.empty?
    RUBY_CODE

    expect([errors, status.success?]).to eq(['', true])
    expect(output).to eq("ready\n")
  end
end
