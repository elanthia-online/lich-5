# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../support/webui_fresh_process'
require 'webui'

# The shim closes a dying script's windows through the core pre-terminate hook
# (1836:RC20): destroy handlers run while the owner is still admitted, before
# the core retires its pages, and keep resolving the dying Script. Fresh
# process with the production shim entry and a real Script owner.
RSpec.describe 'script compatibility close on script death' do
  include WebUIFreshProcess

  def run_fresh(body)
    prelude = <<~RUBY_CODE
      require 'webui'
      require 'timeout'
      require 'tmpdir'
      LOGS = Queue.new
      module Lich
        def self.log(message) = LOGS << message
        module Common; end
      end
      def respond(*) = nil
      require 'common/class_exts/nilclass'
      require 'common/limitedarray'
      require 'common/script'
      require 'common/script_scope/gtk/boot'
      GTK = Lich::Common::ScriptScope::Gtk
      SCRIPT = Lich::Common::Script
      KEY = SCRIPT::CLEANUP_SCRIPT_THREAD_KEY

      def new_owner(name)
        file = File.join(Dir.mktmpdir('death'), name)
        File.write(file, "# death\\n")
        SCRIPT.new(file: file, quiet: true)
      end

      # Runs the block as the owner's main thread, then stops the owner
      # asynchronously and waits, bounded, for its teardown.
      def stop_owner(owner)
        ready = Queue.new
        Thread.new do
          owner.thread_group.add(Thread.current)
          yield
          ready << true
          sleep
        end
        abort 'script body did not start' unless ready.pop(timeout: 10)
        owner.kill(async: true)
        abort 'owner did not stop' unless owner.join(6) && !owner.running?
      end
    RUBY_CODE
    output, errors, status = run_ruby_with_deadline(prelude + body + "\nputs 'ready'\n")
    expect_child_within_deadline(status, output, errors, RSpec.current_example.full_description)
    [output, errors, status]
  end

  it 'closes the windows before the core retires the owner, as the dying script' do
    output, errors, status = run_fresh(<<~RUBY_CODE)
      service = Lich::WebUI::Service.new(logger: ->(*) {})
      Lich::WebUI.instance_variable_set(:@service, service)
      order = Queue.new
      terminate = service.method(:terminate_owner)
      service.define_singleton_method(:terminate_owner) do |owner|
        order << :terminate_owner
        terminate.call(owner)
      end
      owner = new_owner('death.lic')
      seen = {}
      stop_owner(owner) do
        window = GTK::Window.new('death')
        window.signal_connect('destroy') do
          order << :destroy
          seen[:admitted] = (service.registry.ensure_active!(owner); true rescue false)
          seen[:script] = SCRIPT.current.equal?(owner)
          seen[:identity] = Thread.current.thread_variable_get(KEY).equal?(owner)
          seen[:host_thread] = Thread.current.group.equal?(ThreadGroup::Default)
          seen[:widget] = (GTK::Label.new('late') && :built rescue $!.class.name)
        end
        window.show_all
      end
      events = order.size.times.map { order.pop }
      abort "destroy handler never ran: \#{events.inspect}" unless events.include?(:destroy)
      abort "order: \#{events.inspect}" unless events.first == :destroy
      abort "seen: \#{seen.inspect}" unless seen == { admitted: true, script: true, identity: true, host_thread: true,
                                  widget: 'Lich::Common::ScriptScope::Gtk::UnsupportedOperation' }
      abort 'owner pages remain' unless service.registry.pages_for(owner).empty?
      service.stop
    RUBY_CODE

    expect([errors, status.success?]).to eq(['', true])
    expect(output).to eq("ready\n")
  end

  # 1845:RC12: a widget built once the death close has begun (a destroy handler
  # run by the close, or a later ScriptDeath handler) must not create a session
  # and terminate hook for the dead owner, which nothing would ever close.
  it 'refuses a new session for an owner whose death close has begun' do
    output, errors, status = run_fresh(<<~RUBY_CODE)
      service = Lich::WebUI::Service.new(logger: ->(*) {})
      Lich::WebUI.instance_variable_set(:@service, service)
      owner = new_owner('late.lic')
      built = Queue.new
      Lich::Common::ScriptDeath.on_death do |dying|
        next unless dying.equal?(owner)
        built << [:after_close, (GTK::Label.new('x') && :built rescue $!.class.name)]
        built << [:after_close_session, (GTK.session && :built rescue $!.class.name)]
      end
      stop_owner(owner) do
        window = GTK::Window.new('late')
        window.signal_connect('destroy') do
          built << [:in_destroy, (GTK::Label.new('x') && :built rescue $!.class.name)]
          built << [:in_destroy_session, (GTK.session && :built rescue $!.class.name)]
        end
        window.show_all
      end
      seen = built.size.times.map { built.pop }.to_h
      refused = 'Lich::Common::ScriptScope::Gtk::UnsupportedOperation'
      abort "built: \#{seen.inspect}" unless seen == { in_destroy: refused, in_destroy_session: refused,
                                                       after_close: refused, after_close_session: refused }
      abort 'a session is retained' unless GTK.instance_variable_get(:@sessions).empty?
      hooks = Lich::WebUI.instance_variable_get(:@owner_terminate_hooks)
      abort 'a terminate hook is retained' if hooks&.key?(owner)
      abort 'owner pages remain' unless service.registry.pages_for(owner).empty?
      service.stop
    RUBY_CODE

    expect([errors, status.success?]).to eq(['', true])
    expect(output).to eq("ready\n")
  end

  # 1836:RC22: an owner that never used Gtk has no shim hook, so the refusal
  # above cannot key on it. Its killed worker's ensure builds a first widget
  # after the core has run the owner's pre-terminate hooks; a session created
  # then would be held with a terminate hook that never fires.
  it 'refuses a first session for an owner whose pre-terminate hooks have already run' do
    output, errors, status = run_fresh(<<~RUBY_CODE)
      service = Lich::WebUI::Service.new(logger: ->(*) {})
      Lich::WebUI.instance_variable_set(:@service, service)
      owner = new_owner('first.lic')
      core_done = false
      seen = Queue.new
      # Registered after the core's handler, so it runs once the hooks have run
      # and keeps the owner running (still the worker's Script.current) a while.
      Lich::Common::ScriptDeath.on_death do |dying|
        next unless dying.equal?(owner)

        core_done = true
        sleep 1.0
      end
      stop_owner(owner) do
        parked = Queue.new
        Thread.new do
          owner.thread_group.add(Thread.current)
          begin
            parked << true
            sleep
          ensure
            deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 6
            sleep 0.005 until core_done || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
            seen << [:hooks_done, Lich::WebUI.owner_terminate_hooks_done?(owner)]
            seen << [:current, SCRIPT.current.equal?(owner)]
            seen << [:label, (GTK::Label.new('late') && :built rescue $!.class.name)]
            seen << [:session, (GTK.session && :built rescue $!.class.name)]
          end
        end
        abort 'worker did not park' unless parked.pop(timeout: 5)
      end
      events = 4.times.map { seen.pop(timeout: 6) }
      refused = 'Lich::Common::ScriptScope::Gtk::UnsupportedOperation'
      abort "seen: \#{events.inspect}" unless events == [[:hooks_done, true], [:current, true], [:label, refused], [:session, refused]]
      abort 'a session is retained' unless GTK.instance_variable_get(:@sessions).empty?
      hooks = Lich::WebUI.instance_variable_get(:@owner_terminate_hooks)
      abort 'a terminate hook is retained' if hooks&.key?(owner)
      service.stop
    RUBY_CODE

    expect([errors, status.success?]).to eq(['', true])
    expect(output).to eq("ready\n")
  end

  # 1836:RC22 (Gtk.session share): the refusal rests on the core refusing a
  # registration once the owner's hooks have started (snapshotted, not yet
  # done), not on a check made before registering. A core hook held open keeps
  # the owner in that state while its unwinding worker asks for a first session.
  it 'refuses a first session for an owner whose pre-terminate hooks have started but not finished' do
    output, errors, status = run_fresh(<<~RUBY_CODE)
      service = Lich::WebUI::Service.new(logger: ->(*) {})
      Lich::WebUI.instance_variable_set(:@service, service)
      owner = new_owner('started.lic')
      started = Queue.new
      release = Queue.new
      seen = Queue.new
      Lich::WebUI.before_owner_terminate(owner: owner) do
        started << true
        release.pop(timeout: 6)
      end
      stop_owner(owner) do
        parked = Queue.new
        Thread.new do
          owner.thread_group.add(Thread.current)
          begin
            parked << true
            sleep
          ensure
            seen << [:started, started.pop(timeout: 6)]
            seen << [:hooks_done, Lich::WebUI.owner_terminate_hooks_done?(owner)]
            seen << [:current, SCRIPT.current.equal?(owner)]
            seen << [:label, (GTK::Label.new('late') && :built rescue $!.class.name)]
            seen << [:session, (GTK.session && :built rescue $!.class.name)]
            seen << [:retained, GTK.instance_variable_get(:@sessions).empty?]
            hooks = Lich::WebUI.instance_variable_get(:@owner_terminate_hooks)
            seen << [:hook_retained, hooks&.key?(owner) == true]
            release << true
          end
        end
        abort 'worker did not park' unless parked.pop(timeout: 5)
      end
      events = 7.times.map { seen.pop(timeout: 8) }
      refused = 'Lich::Common::ScriptScope::Gtk::UnsupportedOperation'
      expected = [[:started, true], [:hooks_done, false], [:current, true], [:label, refused], [:session, refused],
                  [:retained, true], [:hook_retained, false]]
      abort "seen: \#{events.inspect}" unless events == expected
      abort 'a session is retained' unless GTK.instance_variable_get(:@sessions).empty?
      service.stop
    RUBY_CODE

    expect([errors, status.success?]).to eq(['', true])
    expect(output).to eq("ready\n")
  end

  it 'still lets a stopping owner build its first widget before the death close' do
    output, errors, status = run_fresh(<<~RUBY_CODE)
      service = Lich::WebUI::Service.new(logger: ->(*) {})
      Lich::WebUI.instance_variable_set(:@service, service)
      owner = new_owner('stopping.lic')
      built = Queue.new
      owner.at_exit do
        built << [:stopping, owner.stopping?]
        window = GTK::Window.new('stopping')
        window.signal_connect('destroy') { built << [:destroyed, true] }
        window.show_all
        built << [:widget, (GTK::Label.new('x') && :built rescue $!.class.name)]
      end
      stop_owner(owner) { nil }
      seen = built.size.times.map { built.pop }.to_h
      abort "built: \#{seen.inspect}" unless seen == { stopping: true, widget: :built, destroyed: true }
      abort 'a session is retained' unless GTK.instance_variable_get(:@sessions).empty?
      hooks = Lich::WebUI.instance_variable_get(:@owner_terminate_hooks)
      abort 'a terminate hook is retained' if hooks&.key?(owner)
      service.stop
    RUBY_CODE

    expect([errors, status.success?]).to eq(['', true])
    expect(output).to eq("ready\n")
  end

  it 'closes the windows first when a queued exit stops the script' do
    output, errors, status = run_fresh(<<~RUBY_CODE)
      service = Lich::WebUI::Service.new(logger: ->(*) {})
      Lich::WebUI.instance_variable_set(:@service, service)
      order = Queue.new
      terminate = service.method(:terminate_owner)
      service.define_singleton_method(:terminate_owner) do |owner|
        order << :terminate_owner
        terminate.call(owner)
      end
      owner = new_owner('exit.lic')
      Thread.new do
        owner.thread_group.add(Thread.current)
        window = GTK::Window.new('exit')
        window.signal_connect('destroy') { order << :destroy }
        window.show_all
        GTK.session.queue { exit 3 }
        sleep
      end
      abort 'owner did not stop' unless (Timeout.timeout(8) { sleep 0.02 while owner.running?; true })
      events = order.size.times.map { order.pop }
      abort "order: \#{events.inspect}" unless events.first == :destroy && events.include?(:terminate_owner)
      service.stop
    RUBY_CODE

    expect([errors, status.success?]).to eq(['', true])
    expect(output).to eq("ready\n")
  end

  it 'dies without starting a host or a session for a script that never used Gtk' do
    output, errors, status = run_fresh(<<~RUBY_CODE)
      owner = new_owner('plain.lic')
      stop_owner(owner) { nil }
      abort 'a host was started' if Lich::WebUI.instance_variable_get(:@service)
      abort 'a session was created' unless GTK.instance_variable_get(:@sessions).empty?
    RUBY_CODE

    expect([errors, status.success?]).to eq(['', true])
    expect(output).to eq("ready\n")
  end

  it 'still runs the destroy handler when the host was already stopped' do
    output, errors, status = run_fresh(<<~RUBY_CODE)
      service = Lich::WebUI::Service.new(logger: ->(*) {})
      Lich::WebUI.instance_variable_set(:@service, service)
      Lich::WebUI.define_singleton_method(:service) { @service || service }
      owner = new_owner('stopped.lic')
      ran = Queue.new
      stop_owner(owner) do
        window = GTK::Window.new('stopped')
        window.signal_connect('destroy') { ran << SCRIPT.current.equal?(owner) }
        window.show_all
        Lich::WebUI.reset!
        Lich::WebUI.define_singleton_method(:service) { raise 'host started for a dying script' }
      end
      abort 'destroy handler did not run as the owner' unless ran.pop(timeout: 3) == true
      abort 'a host was started' if Lich::WebUI.instance_variable_get(:@service)
    RUBY_CODE

    expect([errors, status.success?]).to eq(['', true])
    expect(output).to eq("ready\n")
  end
end
