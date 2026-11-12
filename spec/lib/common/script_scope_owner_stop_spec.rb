# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../support/webui_fresh_process'
require 'webui'

# Shim callbacks that call exit stop their Script owner (1843:RC3, settled
# decision B3): a queued or timed block, a signal handler, a close handler and
# a destroy handler run from a close or an explicit destroy each reach the core
# owner stop, which asks the Script to kill itself. Fresh process with a real
# host service and a Script-shaped owner that records kill requests.
RSpec.describe 'script compatibility owner stop' do
  include WebUIFreshProcess

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
    output, errors, status = run_ruby_with_deadline(prelude + body + "\nSERVICE.stop\nputs 'ready'\n")
    expect_child_within_deadline(status, output, errors, RSpec.current_example.full_description)
    [output, errors, status]
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

  it 'removes a window from its session when a destroy handler exits while the owner is live' do
    output, errors, status = run_fresh(<<~RUBY_CODE)
      session = nil
      window = nil
      requested = stop_requested?('forget.lic') do
        session = GTK.session
        window = GTK::Window.new('forget')
        window.signal_connect('destroy') { exit 10 }
        session.queue { window.destroy }
      end
      abort 'owner not stopped' unless requested
      abort 'window not destroyed' unless window.destroyed?
      windows = session.instance_variable_get(:@windows)
      abort "window left in session: \#{windows.size}" unless windows.empty?
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

  # 1843:RC18: while an owner is stopping, queue runs the block inline for that
  # owner's own threads (legacy parity), so a killed thread's ensure that queues
  # and then waits with no timeout cannot hang the script stop. Real Script
  # owner and real host service in a fresh process; only the stop is bounded.
  def run_real_script(body)
    prelude = <<~RUBY_CODE
      require 'webui'
      require 'tmpdir'
      require 'timeout'
      module Lich
        def self.log(_message) = nil
        module Common; end
      end
      def respond(*) = nil
      require 'common/class_exts/nilclass'
      require 'common/limitedarray'
      require 'common/script'
      require 'common/script_scope/gtk/session'
      require 'common/script_scope/gtk/widgets'
      GTK = Lich::Common::ScriptScope::Gtk
      SCRIPT = Lich::Common::Script
      SERVICE = Lich::WebUI::Service.new(logger: ->(*) {}, browser_open: ->(_url, **) { true }, browser_terminate: ->(*) {})
      Lich::WebUI.define_singleton_method(:service) { SERVICE }
      SESSIONS = {}.compare_by_identity
      GTK.define_singleton_method(:session) { SESSIONS[SCRIPT.current] ||= GTK::Session.new(SCRIPT.current) }

      # Runs the body as the owner's main thread, kills the owner and reports
      # whether its teardown finished inside the bound, with the recorded events.
      def stop_case(label)
        file = File.join(Dir.mktmpdir('rc18'), "\#{label}.lic")
        File.write(file, "# rc18\\n")
        owner = SCRIPT.new(file: file, quiet: true)
        rec = Queue.new
        ready = Queue.new
        Thread.new do
          owner.thread_group.add(Thread.current)
          yield GTK.session, rec, ready
        end
        raise "\#{label}: body did not start" unless ready.pop(timeout: 10)

        owner.kill(async: true)
        stopped = !owner.join(8).nil? && !owner.running?
        [label, stopped, Array.new(rec.size) { rec.pop }]
      end
    RUBY_CODE
    output, errors, status = run_ruby_with_deadline(prelude + body + "\nSERVICE.stop\nputs 'ready'\n")
    expect_child_within_deadline(status, output, errors, RSpec.current_example.full_description)
    [output, errors, status]
  end

  it 'completes a killed thread queue-then-wait without a timeout and finishes the owner stop' do
    output, errors, status = run_real_script(<<~RUBY_CODE)
      results = [
        stop_case('main') do |session, rec, ready|
          begin
            ready << true
            sleep
          ensure
            done = Queue.new
            rec << session.queue { done << :value }
            rec << done.pop
          end
        end,
        stop_case('worker') do |session, rec, ready|
          worker = Thread.new do
            begin
              sleep
            ensure
              done = Queue.new
              rec << session.queue { done << :value }
              rec << done.pop
            end
          end
          Thread.pass until worker.status == 'sleep'
          ready << true
          sleep
        end
      ]
      abort results.inspect unless results.all? { |_label, stopped, events| stopped && events == [:queued, :value] }
    RUBY_CODE

    expect([errors, status.success?]).to eq(['', true])
    expect(output).to eq("ready\n")
  end

  it 'keeps other threads, a closed session and exit inside an inline block unchanged' do
    output, errors, status = run_real_script(<<~RUBY_CODE)
      results = [
        stop_case('foreign') do |session, rec, ready|
          SCRIPT.at_exit do
            foreign = Thread.new { session.queue { rec << :foreign_ran } }
            ThreadGroup::Default.add(foreign)
            rec << foreign.value
          end
          ready << true
          sleep
        end,
        stop_case('closed') do |session, rec, ready|
          begin
            ready << true
            sleep
          ensure
            session.close
            rec << session.queue { rec << :closed_ran }
          end
        end,
        stop_case('exit') do |session, rec, ready|
          begin
            ready << true
            sleep
          ensure
            rec << session.queue { exit 3 }
            rec << :survived
          end
        end
      ]
      expected = { 'foreign' => [nil], 'closed' => [nil], 'exit' => [:queued, :survived] }
      abort results.inspect unless results.all? { |label, stopped, events| stopped && events == expected.fetch(label) }
    RUBY_CODE

    expect([errors, status.success?]).to eq(['', true])
    expect(output).to eq("ready\n")
  end

  it 'keeps a live owner thread on the dispatcher instead of running its queue inline' do
    output, errors, status = run_real_script(<<~RUBY_CODE)
      file = File.join(Dir.mktmpdir('rc18'), 'live.lic')
      File.write(file, "# rc18\\n")
      owner = SCRIPT.new(file: file, quiet: true)
      ran_on = Queue.new
      caller_thread = nil
      queued = nil
      Thread.new do
        owner.thread_group.add(Thread.current)
        caller_thread = Thread.current
        queued = GTK.session.queue { ran_on << Thread.current }
      end.join
      worker = ran_on.pop(timeout: 5)
      owner.kill(async: true)
      abort 'owner did not stop' unless owner.join(8)
      abort "live queue ran inline: \#{[queued, worker.equal?(caller_thread)].inspect}" unless queued == :queued && worker && !worker.equal?(caller_thread)
    RUBY_CODE

    expect([errors, status.success?]).to eq(['', true])
    expect(output).to eq("ready\n")
  end
end
