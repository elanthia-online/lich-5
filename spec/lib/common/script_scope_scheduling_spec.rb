# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/script_scope'
require 'timeout'

RSpec.describe 'owner-bound GLib scheduling' do
  let(:scope) { Lich::Common::ScriptScope }
  let(:gtk) { scope::Gtk }
  let(:glib) { scope::GLib }
  let(:owner) { Struct.new(:name).new('scheduling.lic') }
  let(:service) { Lich::WebUI::Service.new }

  before do
    scope.activate!
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    allow(Lich::WebUI).to receive(:adapter) { |owner:, viewer: nil| Lich::WebUI::Adapter.new(owner: owner, service: service, viewer: viewer) }
    allow(Lich::WebUI).to receive(:callback_queue) { |owner:| proc { |&work| service.runtime.dispatch(owner: owner, &work) } }
    allow(Lich::WebUI).to receive(:callback_scheduler) { |owner:| service.runtime.scheduler.for_owner(owner) }
    @logs = []
    allow(Lich).to receive(:log) { |message| @logs << message }
  end

  after do
    Lich::Common::ScriptDeath.run(owner)
    Lich::Common::ScriptDeath.run(@other) if @other
    service.stop
  end

  def drain
    done = Queue.new
    service.runtime.dispatch(owner: owner) { done << true }
    expect(done.pop(timeout: 2)).to be(true)
  end

  it 'defers idle callbacks and repeats timeouts through the same owner dispatcher' do
    result, release, started = Queue.new, Queue.new, Queue.new
    service.runtime.dispatch(owner: owner) { started << true; release.pop }
    expect(started.pop(timeout: 2)).to be(true)
    id = glib::Idle.add { result << :idle; false }
    expect(id).to be_a(Integer)
    expect(result).to be_empty
    release << true
    expect(result.pop(timeout: 2)).to eq(:idle)
    drain
    expect(glib::Source.remove(id)).to be(false)
    count = 0
    glib::Timeout.add(1) { result << (count += 1); count < 2 }
    expect(2.times.map { result.pop(timeout: 2) }).to eq([1, 2])
  ensure
    release << true
  end

  it 'converts seconds, accepts block Procs, cancels IDs and refuses unsupported GLib APIs' do
    handle = service.runtime.scheduler.for_owner(owner)
    allow(Lich::WebUI).to receive(:callback_scheduler).and_return(handle)
    expect(handle).to receive(:schedule).with(10_000).and_call_original
    id = glib::Timeout.add_seconds(10, &proc { false })
    expect(glib::Source.remove(id)).to be(true)
    [proc { glib::Timeout.add(-1) {} }, proc { glib::Timeout.add(2) },
     proc { glib::Timeout.add_seconds(0.5) {} }, proc { glib::Source.remove(nil) },
     proc { glib::Timeout.add_full(0) {} }].each do |call|
      expect(&call).to raise_error(gtk::UnsupportedOperation)
    end
    expect(::Timeout).not_to equal(glib::Timeout)
  end

  it 'permits owner-bound loop construction but refuses nested execution and termination' do
    loop = glib::MainLoop.new
    expect { loop.run }.to raise_error(gtk::UnsupportedOperation, /operation=run/)
    expect { loop.quit }.to raise_error(gtk::UnsupportedOperation, /operation=quit/)
    expect { glib::MainLoop.new(:custom_context) }.to raise_error(ArgumentError)
    @other = Struct.new(:name).new('other.lic')
    allow(Lich::Common::Script).to receive(:current).and_return(@other)
    expect { loop.run }.to raise_error(gtk::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    gtk.session.close
    expect { glib::MainLoop.new }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'stops on callback failure, rejects foreign removal and cleans up on session close' do
    fired = Queue.new
    glib::Idle.add { fired << true; raise 'fixture failure' }
    expect(fired.pop(timeout: 2)).to be(true)
    drain
    expect(@logs.join).to include('callback failed')
    id = glib::Timeout.add_seconds(60) { true }
    session = gtk.session
    @other = Struct.new(:name).new('other.lic')
    allow(Lich::Common::Script).to receive(:current).and_return(@other)
    expect { glib::Source.remove(id) }.to raise_error(gtk::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    session.close
    expect(service.runtime.scheduler.for_owner(owner).cancel(id)).to be(false)
    expect { glib::Idle.add {} }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'adopts the script owner on its dispatcher and retains only the registering viewer context' do
    group = ThreadGroup.new
    allow(owner).to receive(:thread_group).and_return(group)
    main = Thread.current
    allow(Lich::Common::Script).to receive(:current) do
      owner if Thread.current.equal?(main) || group.list.include?(Thread.current)
    end
    session = gtk.session
    results = Queue.new
    session.send(:with_callback_context, 'origin-viewer', nil) do
      glib::Idle.add do
        results << [Lich::Common::Script.current, session.viewer_id, Thread.current.group]
        false
      end
    end
    expect(results.pop(timeout: 2)).to eq([owner, 'origin-viewer', group])
    glib::Idle.add { results << session.viewer_id; false }
    expect(results.pop(timeout: 2)).to be_nil
    expect(service.runtime.scheduler.instance_variable_get(:@thread).group).to equal(ThreadGroup::Default)
  end
end
