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
    let(:now) { Time.at(1_000) }

    it 'sends to the subscribers only' do
      expect(described_class.publish(now)).to be true
      expect(subscriber.written.size).to eq(1)
      expect(bystander.written).to be_empty
    end

    it 'skips an unchanged list until the heartbeat is due' do
      described_class.publish(now)
      expect(described_class.publish(now + 1)).to be false
      expect(described_class.publish(now + described_class::HEARTBEAT)).to be true
      expect(subscriber.written.size).to eq(2)
    end

    it 'sends a changed list at once' do
      described_class.publish(now)
      scripts.first.paused = true
      expect(described_class.publish(now + 1)).to be true
      expect(subscriber.written.last).to eq('<lichScripts v="1" char="%3B" list="bigshot:1,go2:1"/>')
    end

    it 'resends when only the command character changed' do
      described_class.publish(now)
      $clean_lich_char = ','
      expect(described_class.publish(now + 1)).to be true
      expect(subscriber.written.last).to include('char="%2C"')
    end

    it 'keeps serving the other subscribers when one write raises' do
      broken = client_class.new(%i[script_list])
      def broken.puts_main_stream(_line) = raise(IOError, 'gone')
      allow(described_class).to receive(:subscribers).and_return([broken, subscriber])
      expect { described_class.publish(now) }.not_to raise_error
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
end
