# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require 'open3'
require 'rbconfig'

# The shim closes a dying script's windows through the core pre-terminate hook
# (1836:RC20): destroy handlers run while the owner is still admitted, before
# the core retires its pages, and keep resolving the dying Script. Fresh
# process with the production shim entry and a real Script owner.
RSpec.describe 'script compatibility close on script death' do
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
    Open3.capture3(RbConfig.ruby, '-I', LIB_DIR, '-e', prelude + body + "\nputs 'ready'\n")
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
          seen[:widget] = (GTK::Label.new('late') && true rescue false)
        end
        window.show_all
      end
      events = order.size.times.map { order.pop }
      abort "destroy handler never ran: \#{events.inspect}" unless events.include?(:destroy)
      abort "order: \#{events.inspect}" unless events.first == :destroy
      abort "seen: \#{seen.inspect}" unless seen == { admitted: true, script: true, identity: true, host_thread: true, widget: true }
      abort 'owner pages remain' unless service.registry.pages_for(owner).empty?
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
