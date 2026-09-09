# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/parser'
require 'gemstone/combat/processor'

# Loads the production Tracker with only its automatic initialization thread
# suppressed. The captured production hook runs against synthetic XML state;
# no saved settings are loaded and no game/socket commands are sent.
RSpec.describe 'Tracker ingestion observations' do
  let(:tracker) { Lich::Gemstone::Combat::Tracker }
  let(:attack) { 'You swing a broadsword at <pushBold/><a exist="123" noun="rat">a giant rat</a><popBold/>!' }
  let(:prompt) { '<prompt time="123">&gt;</prompt>' }

  around do |example|
    original_store = Lich::Common::DB_Store
    original_read = original_store.method(:read)
    store_feature = File.expand_path('common/db_store.rb', LIB_DIR)
    store_preloaded = $LOADED_FEATURES.include?(store_feature)
    example.run
    expect(Lich::Common::DB_Store).to equal(original_store)
    expect(original_store.method(:read)).to eq(original_read)
  ensure
    $LOADED_FEATURES.delete(store_feature) unless store_preloaded
  end

  before do
    stub_const('Lich::Gemstone::Combat::Tracker', Module.new)
    # Tracker requires DB_Store even though automatic initialization is disabled.
    # Load into a temporary constant, not the shared in-memory store used by
    # QStrike/SlackBot and other specs; restore require-cache state on teardown.
    stub_const('Lich::Common::DB_Store', Module.new)
    allow(Thread).to receive(:new).and_return(nil)
    load File.join(LIB_DIR, 'gemstone/combat/tracker.rb')
    allow(Thread).to receive(:new).and_call_original
    stub_const('Lich::Gemstone::Combat::Game', Class.new { class << self; attr_accessor :thread; end })
    Lich::Gemstone::Combat::Game.thread = Thread.current
    allow(Lich::Gemstone::Combat::Game).to receive(:current_ingress_time).and_return(10.0)
    allow(XMLData).to receive_messages(game: 'GSIV', name: 'Testmage', room_count: 4, in_stream: false)
    stub_const('Lich::Gemstone::Combat::DownstreamHook', Module.new)
    allow(Lich::Gemstone::Combat::DownstreamHook).to receive(:add) { |_id, callback, **_options| @hook = callback }
    tracker.instance_variable_set(:@settings, tracker::DEFAULT_SETTINGS.merge(max_threads: 0, enabled: true))
    tracker.instance_variable_set(:@initialized, true)
    tracker.instance_variable_set(:@enabled, true)
    allow(Lich::Gemstone::Combat::Processor).to receive(:process)
    @seen = []
    allow(tracker).to receive(:process) { |chunk, **metadata| @seen << [chunk, metadata[:source]] }
    tracker.send(:add_downstream_hook)
  end

  it 'captures immutable main-stream identity and monotonic time before processing' do
    expect(@hook.call(attack)).to eq(attack)
    @hook.call(prompt)
    source = @seen.first.last
    expect(source).to include(connection_id: Thread.current.object_id, game: 'GSIV', character: 'Testmage', room_epoch: 4, sequence: 1)
    expect(source[:received_at]).to eq(10.0)
    expect(source).to be_frozen
    expect(source[:character]).to be_frozen
    expect(tracker.observation_context.keys).to contain_exactly(:connection_id, :game, :character, :room_epoch)
    @hook.call(attack + prompt)
    expect(@seen.last.last[:sequence]).to be > source[:sequence]
  end

  it 'does not enable or save settings when reading the binding or subscribing' do
    tracker.instance_variable_set(:@enabled, false)
    expect(tracker).not_to receive(:initialize!)
    expect(tracker).not_to receive(:enable!)
    expect(tracker).not_to receive(:save_settings)
    expect(tracker.observation_context).to be_frozen
    handler = tracker.on(:attack) { |_type, _event| }
    expect(tracker.instance_variable_get(:@enabled)).to be(false)
    tracker.off(handler)
  end

  it 'invalidates a mixed-room chunk rather than assigning its last room' do
    @hook.call(attack)
    allow(XMLData).to receive(:room_count).and_return(5)
    @hook.call(prompt)
    expect(@seen.first.last).to be_nil
    @hook.call(attack + prompt)
    expect(@seen.last.last[:room_epoch]).to eq(5)
  end

  it 'does not replace missing queue ingress time with the later hook clock' do
    allow(Lich::Gemstone::Combat::Game).to receive(:current_ingress_time).and_return(nil)
    @hook.call(attack + prompt)
    expect(@seen.last.last).to be_nil
  end

  it 'invalidates partial protocol tags instead of overlooking a split room transition' do
    @hook.call(attack + '<nav ')
    @hook.call('rm="10"/>' + prompt)
    expect(@seen.last.last).to be_nil
  end

  it 'rejects transition markup while allowing ordinary object links and prompt tags' do
    ['<popStream id="room"/>', '<nav rm="10"/>', '<component id="room objs">', '<style id="roomName"/>', '</compass>'].each do |transition|
      @hook.call(attack + transition + prompt)
      expect(@seen.last.last).to be_nil
    end
    @hook.call(attack + prompt)
    expect(@seen.last.last).not_to be_nil
  end

  it 'rejects subsequent non-main-stream chunks even when their opening tag was in a prior chunk' do
    allow(XMLData).to receive(:in_stream).and_return(true)
    @hook.call(attack + prompt)
    expect(@seen.last.last).to be_nil
  end

  it 'rejects absent connection identity and hooks executing outside the actual Game.thread' do
    release = Queue.new
    other = Thread.new { release.pop }
    Lich::Gemstone::Combat::Game.thread = other
    @hook.call(attack + prompt)
    expect(@seen.last.last).to be_nil
    Lich::Gemstone::Combat::Game.thread = nil
    expect(tracker.observation_context).to be_nil
  ensure
    release << true
    other.join
  end

  it 'invalidates a truncated chunk after buffer overflow' do
    tracker.instance_variable_get(:@settings)[:buffer_size] = 1
    @hook.call(attack)
    @hook.call(attack)
    @hook.call(prompt)
    expect(@seen.last.last).to be_nil
  end

  it 'forwards source through normal synchronous processing but leaves disabled tracking disabled' do
    allow(tracker).to receive(:process).and_call_original
    @hook.call(attack + prompt)
    expect(Lich::Gemstone::Combat::Processor).to have_received(:process).with([attack + prompt], source: hash_including(room_epoch: 4))
    tracker.instance_variable_set(:@enabled, false)
    expect(Lich::Gemstone::Combat::Processor).not_to receive(:process)
    tracker.process([attack])
  end
end
