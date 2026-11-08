# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/class_exts/synchronizedsocket'
require 'common/client_capabilities'
require 'common/script_list_feed'
require_relative '../../../lib/common/front-end'

RSpec.describe Lich::Common::ScriptListFeed do
  # A stand-in for a running script: the feed reads only name and paused?.
  let(:fake_script) do
    Struct.new(:name, :paused) do
      def paused?
        paused
      end
    end
  end

  # A client that records what the feed writes to it.
  let(:client_class) do
    Class.new do
      attr_accessor :declared_feeds, :alive
      attr_reader :written

      def initialize(feeds)
        @declared_feeds = feeds
        @alive = true
        @written = []
      end

      def alive?
        @alive
      end

      def puts_main_stream(line)
        @written << line
        true
      end
    end
  end

  let(:subscriber) { client_class.new(%i[script_list]) }
  let(:bystander) { client_class.new([]) }
  let(:scripts) { [fake_script.new('bigshot', false), fake_script.new('go2', true)] }

  before do
    allow(Lich).to receive(:log)
    @saved = [Lich::Common::ClientCapabilities.launch_feeds, $frontend, $clean_lich_char]
    $clean_lich_char = ';'
    $frontend = 'genie' # no streams: a client without script_list gets nothing
    # Script is stubbed rather than loaded: lib/common/script.rb drags in the
    # whole runtime, and the feed reads only Script.running.
    running = -> { scripts }
    stub_const('Lich::Common::Script', Module.new.tap { |m| m.define_singleton_method(:running) { running.call } })
    allow(described_class).to receive(:subscribers) { [subscriber, bystander].select { |c| described_class.wants?(c) } }
  end

  after do
    described_class.reset!
    Lich::Common::ClientCapabilities.launch_feeds, $frontend, $clean_lich_char = @saved
  end

  describe '.encode' do
    it 'leaves names made of safe characters alone' do
      expect(described_class.encode('custom/my_script-2.1')).to eq('custom/my_script-2.1')
    end

    it 'percent-encodes anything that could break the tag, byte by byte' do
      expect(described_class.encode(%(a b,c:d"e<f>&))).to eq('a%20b%2Cc%3Ad%22e%3Cf%3E%26')
      expect(described_class.encode([0xC3, 0xA9].pack('C*').force_encoding(Encoding::UTF_8))).to eq('%C3%A9')
      expect(described_class.encode(';')).to eq('%3B')
    end
  end

  describe '.tag' do
    it 'lists each script as name:paused with the encoded command character' do
      expect(described_class.tag(scripts, ';')).to eq('<lichScripts v="1" char="%3B" list="bigshot:0,go2:1"/>')
    end

    it 'sends an empty list when nothing runs' do
      expect(described_class.tag([], ';')).to eq('<lichScripts v="1" char="%3B" list=""/>')
    end
  end

  describe '.wants?' do
    it 'is true only for a live client whose set has script_list' do
      expect(described_class.wants?(subscriber)).to be true
      expect(described_class.wants?(bystander)).to be false
      subscriber.alive = false
      expect(described_class.wants?(subscriber)).to be false
      expect(described_class.wants?(nil)).to be false
    end

    it 'honours the session set for a client that has not declared' do
      undeclared = client_class.new(nil)
      $frontend = 'genie'
      expect(described_class.wants?(undeclared)).to be false
      Lich::Common::ClientCapabilities.launch_feeds = %i[script_list]
      expect(described_class.wants?(undeclared)).to be true
    end
  end

  describe '.client_ready' do
    before { allow(described_class).to receive(:start) }

    it 'sends the current list to a client that wants it, and starts the feed' do
      expect(described_class.client_ready(subscriber)).to be true
      expect(subscriber.written).to eq(['<lichScripts v="1" char="%3B" list="bigshot:0,go2:1"/>'])
      expect(described_class).to have_received(:start)
    end

    # It runs on the client's read loop: a raise there would drop the client.
    it 'logs and returns false instead of raising' do
      allow(Lich::Common::ClientCapabilities).to receive(:feeds_for).and_raise(NoMethodError, 'boom')
      expect(described_class.client_ready(subscriber)).to be false
      expect(Lich).to have_received(:log).with(/script list feed: boom/)
    end

    it 'sends nothing, and starts nothing, for a client that does not' do
      expect(described_class.client_ready(bystander)).to be false
      expect(bystander.written).to be_empty
      expect(described_class).not_to have_received(:start)
    end
  end

  describe '.publish' do
    it 'sends to the subscribers only' do
      expect(described_class.publish).to be true
      expect(subscriber.written.size).to eq(1)
      expect(bystander.written).to be_empty
    end

    # Nothing is resent on a timer: an unchanged list is never sent again.
    it 'never resends an unchanged list' do
      described_class.publish
      3.times { expect(described_class.publish).to be false }
      expect(subscriber.written.size).to eq(1)
    end

    it 'sends only to the subscribers whose last list differs' do
      late = client_class.new(%i[script_list])
      allow(described_class).to receive(:subscribers).and_return([subscriber])
      described_class.publish
      allow(described_class).to receive(:subscribers).and_return([subscriber, late])
      described_class.publish
      expect(subscriber.written.size).to eq(1)
      expect(late.written.size).to eq(1)
    end

    it 'retries a client whose write failed' do
      flaky = client_class.new(%i[script_list])
      calls = 0
      flaky.define_singleton_method(:puts_main_stream) { |line| (calls += 1) == 1 ? raise(IOError, 'busy') : (written << line; true) }
      allow(described_class).to receive(:subscribers).and_return([flaky])
      described_class.publish
      expect(flaky.written).to be_empty
      expect(described_class.publish).to be true
      expect(flaky.written.size).to eq(1)
    end

    it 'sends a changed list at once' do
      described_class.publish
      scripts.first.paused = true
      expect(described_class.publish).to be true
      expect(subscriber.written.last).to eq('<lichScripts v="1" char="%3B" list="bigshot:1,go2:1"/>')
    end

    it 'resends when only the command character changed' do
      described_class.publish
      $clean_lich_char = ','
      expect(described_class.publish).to be true
      expect(subscriber.written.last).to include('char="%2C"')
    end

    it 'keeps serving the other subscribers when one write raises' do
      broken = client_class.new(%i[script_list])
      def broken.puts_main_stream(_line) = raise(IOError, 'gone')
      allow(described_class).to receive(:subscribers).and_return([broken, subscriber])
      expect { described_class.publish }.not_to raise_error
      expect(subscriber.written.size).to eq(1)
    end
  end

  describe '.changed!' do
    it 'does nothing before any client asked for the feed' do
      expect(described_class.instance_variable_get(:@thread)).to be_nil
      expect(described_class.changed!).to be_nil
      expect(described_class.instance_variable_get(:@dirty)).to be false
    end

    # The client that starts the feed already got the list from
    # client_ready, so starting the thread must not send it a second copy.
    it 'sends nothing on start, only once something changes' do
      stub_const("#{described_class}::SETTLE", 0)
      described_class.start
      sleep 0.2
      expect(subscriber.written).to be_empty

      scripts << fake_script.new('afk', false)
      described_class.changed!
      deadline = Time.now + 2
      sleep 0.01 until subscriber.written.size >= 1 || Time.now > deadline
      expect(subscriber.written).to eq(['<lichScripts v="1" char="%3B" list="bigshot:0,go2:1,afk:0"/>'])
    end

    it 'does not resend the list the first subscriber was just sent' do
      stub_const("#{described_class}::SETTLE", 0)
      described_class.client_ready(subscriber)
      described_class.changed! # e.g. a hidden script starting: ;list is unchanged
      sleep 0.2
      expect(subscriber.written.size).to eq(1)
    end

    # The review's stale-joiner case: a client joins while a short script
    # runs and is sent that list directly; the script stops before the
    # thread publishes. The joiner must still converge on the empty list,
    # although the thread's last module-wide publish was also empty.
    it 'brings a client that joined mid-change up to date' do
      stub_const("#{described_class}::SETTLE", 0.05)
      scripts.clear
      described_class.client_ready(subscriber)
      deadline = Time.now + 2
      sleep 0.01 until subscriber.written.size >= 1 || Time.now > deadline

      scripts << fake_script.new('s5', false)
      described_class.changed!
      late = client_class.new(%i[script_list])
      allow(described_class).to receive(:subscribers).and_return([subscriber, late])
      described_class.client_ready(late)
      scripts.clear
      described_class.changed!

      empty = '<lichScripts v="1" char="%3B" list=""/>'
      deadline = Time.now + 2
      sleep 0.01 until late.written.last == empty || Time.now > deadline
      expect(late.written).to eq(['<lichScripts v="1" char="%3B" list="s5:0"/>', empty])
    end

    it 'folds a burst of changes into one send' do
      stub_const("#{described_class}::SETTLE", 0.2)
      described_class.start

      3.times do |n|
        scripts << fake_script.new("s#{n}", false)
        described_class.changed!
      end
      sleep 0.6
      expect(subscriber.written.size).to eq(1)
      expect(subscriber.written.last).to end_with('s0:0,s1:0,s2:0"/>')
    end
  end

  describe '.subscribers' do
    before { allow(described_class).to receive(:subscribers).and_call_original }

    it 'includes the primary client and each detachable client that wants the feed' do
      primary = client_class.new(%i[script_list])
      detached = [subscriber, bystander]
      saved_client = $_CLIENT_
      $_CLIENT_ = primary
      allow(described_class).to receive(:detachable_clients_snapshot).and_return(detached)
      expect(described_class.subscribers).to eq([primary, subscriber])
    ensure
      $_CLIENT_ = saved_client
    end
  end

  describe '.window' do
    let(:window_lines) do
      ['<streamWindow id="scripts" title="Lich Scripts" location="right" ifClosed="" resident="true"/>',
       '<clearStream id="scripts"/>']
    end

    it 'defines the window, clears it, and lists each script with links that send the usual commands' do
      expect(described_class.window(scripts, ';').split("\r\n")).to eq(
        window_lines + [
          '<pushStream id="scripts"/>bigshot  <d cmd=";pause bigshot">pause</d> <d cmd=";kill bigshot">kill</d>',
          'go2 (paused)  <d cmd=";unpause go2">unpause</d> <d cmd=";kill go2">kill</d>',
          '<popStream/>'
        ]
      )
    end

    it 'says so when nothing runs' do
      expect(described_class.window([], ';').split("\r\n")).to eq(
        window_lines + ['<pushStream id="scripts"/>No scripts running.', '<popStream/>']
      )
    end

    it 'uses the session command character and escapes what would break the markup' do
      odd = [fake_script.new(%(a&b<c>"d), false)]
      line = described_class.window(odd, ',').split("\r\n")[2]
      expect(line).to eq('<pushStream id="scripts"/>a&amp;b&lt;c&gt;&quot;d  ' \
                         '<d cmd=",pause a&amp;b&lt;c&gt;&quot;d">pause</d> <d cmd=",kill a&amp;b&lt;c&gt;&quot;d">kill</d>')
    end
  end

  # script_list gets the data element; otherwise, with ;display
  # scriptwindow on, a front end with the streams capability gets the
  # window; otherwise nothing.
  describe 'which form a client gets' do
    let(:window_client) { client_class.new(nil) }

    before do
      $frontend = 'stormfront'
      allow(Lich).to receive(:display_script_window).and_return(true)
    end

    it 'gives nothing to a streams client while ;display scriptwindow is off, the default' do
      [false, nil].each do |setting|
        allow(Lich).to receive(:display_script_window).and_return(setting)
        expect(described_class.forms_for(window_client)).to eq([])
      end
    end

    it 'treats an unreadable setting as off' do
      allow(Lich).to receive(:display_script_window).and_raise(StandardError, 'db gone')
      expect(described_class.forms_for(window_client)).to eq([])
    end

    it 'gives the data element to a script_list client even with the setting off' do
      allow(Lich).to receive(:display_script_window).and_return(false)
      expect(described_class.forms_for(subscriber)).to eq([:script_list])
    end

    it 'gives the data element to a client with script_list, whatever the front end' do
      %w[stormfront saga profanity genie wizard].each do |frontend|
        $frontend = frontend
        expect(described_class.forms_for(subscriber)).to eq([:script_list])
      end
    end

    it 'gives the window to any other client when the front end has streams' do
      %w[stormfront wrayth saga profanity].each do |frontend|
        $frontend = frontend
        expect(described_class.forms_for(window_client)).to eq([:window])
      end
    end

    it 'gives nothing to any other client when the front end has no streams' do
      %w[genie frostbite wizard avalon].each do |frontend|
        $frontend = frontend
        expect(described_class.forms_for(window_client)).to eq([])
      end
    end

    it 'sends the window to a window client on ready' do
      allow(described_class).to receive(:start)
      described_class.client_ready(window_client)
      expect(window_client.written.size).to eq(1)
      expect(window_client.written.first).to start_with('<streamWindow id="scripts"')
    end

    it 'publishes each client its own form' do
      allow(described_class).to receive(:subscribers).and_return([subscriber, window_client])
      described_class.publish
      expect(subscriber.written).to eq([described_class.tag(scripts, ';')])
      expect(window_client.written).to eq([described_class.window(scripts, ';')])
    end

    # MahtraDR's review of 1863500f0: on a busy settings database the
    # attach-time read returns the default (off) for 30 s while the stored
    # value is on. The window must still appear at the next script change
    # once the setting reads on, without the user toggling it.
    it 'draws the window at the next change when the setting read off at attach and on later' do
      stub_const("#{described_class}::SETTLE", 0)
      reads = [false]
      allow(Lich).to receive(:display_script_window) { reads.empty? ? true : reads.shift }
      allow(described_class).to receive(:subscribers) { [window_client].select { |c| described_class.wants?(c) } }
      expect(described_class.client_ready(window_client)).to be false

      scripts << fake_script.new('afk', false)
      described_class.changed!
      deadline = Time.now + 2
      sleep 0.01 until window_client.written.any? || Time.now > deadline
      expect(window_client.written).to eq([described_class.window(scripts, ';')])
    end

    it 'leaves the thread unstarted when the front end has no streams' do
      $frontend = 'genie'
      expect(described_class.client_ready(window_client)).to be false
      expect(described_class.instance_variable_get(:@thread)).to be_nil
    end

    describe '.window_setting_changed' do
      it 'draws the window for streams clients when turned on' do
        stub_const("#{described_class}::SETTLE", 0)
        allow(described_class).to receive(:subscribers) { [window_client].select { |c| described_class.wants?(c) } }
        described_class.window_setting_changed(true)
        deadline = Time.now + 2
        sleep 0.01 until window_client.written.any? || Time.now > deadline
        expect(window_client.written).to eq([described_class.window(scripts, ';')])
      end

      it 'replaces the window with an off notice when turned off, once' do
        allow(described_class).to receive(:subscribers).and_return([window_client, subscriber])
        described_class.publish
        allow(Lich).to receive(:display_script_window).and_return(false)
        described_class.window_setting_changed(false)
        described_class.window_setting_changed(false)
        expect(window_client.written.size).to eq(2)
        expect(window_client.written.last).to eq(
          %(<clearStream id="scripts"/>\r\n<pushStream id="scripts"/>The Lich Scripts window is off. ) +
          %(Turn it on with ;display scriptwindow.\r\n<popStream/>)
        )
        expect(subscriber.written.size).to eq(1) # the data client is untouched
      end

      it 'never raises' do
        allow(described_class).to receive(:start).and_raise(ThreadError, 'no threads')
        expect(described_class.window_setting_changed(true)).to be_nil
      end
    end

    it 'redraws the window when a script is paused' do
      allow(described_class).to receive(:subscribers).and_return([window_client])
      described_class.publish
      scripts.first.paused = true
      described_class.publish
      expect(window_client.written.last).to include('bigshot (paused)  <d cmd=";unpause bigshot">unpause</d>')
    end
  end
end
