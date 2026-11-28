# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/processor'

# The tracker's two chunk filters (the downstream hook's creature-link gate
# and Tracker.process's relevance check) run before the processor. A move
# into an empty room must still reach the processor so it forgets running
# spells, and so must a Sandstorm surge whose rounds link no creature.
RSpec.describe 'Combat::Tracker chunk gates' do
  let(:tracker) { Lich::Gemstone::Combat::Tracker }
  let(:processed) { [] }
  let(:hook) { @hook }

  around do |example|
    store_feature = File.expand_path('common/db_store.rb', LIB_DIR)
    store_preloaded = $LOADED_FEATURES.include?(store_feature)
    example.run
  ensure
    $LOADED_FEATURES.delete(store_feature) unless store_preloaded
  end

  before do
    stub_const('Lich::Gemstone::Combat::Tracker', Module.new)
    stub_const('Lich::Common::DB_Store', Module.new)
    allow(Thread).to receive(:new).and_return(nil)
    load File.join(LIB_DIR, 'gemstone/combat/tracker.rb')
    allow(Thread).to receive(:new).and_call_original
    allow(Lich::Gemstone::Combat::Processor).to receive(:process) { |chunk, **_| processed << chunk }
    tracker.instance_variable_set(:@settings, tracker::DEFAULT_SETTINGS.merge(max_threads: 0, enabled: true))
    tracker.instance_variable_set(:@initialized, true)
    tracker.instance_variable_set(:@enabled, true)
    tracker.instance_variable_set(:@buffer, [])
    captured = nil
    stub_const('DownstreamHook', Module.new)
    allow(DownstreamHook).to receive(:add) { |_name, action, **_| captured = action }
    tracker.send(:add_downstream_hook)
    @hook = captured
  end

  def feed(*lines) = lines.each { |line| hook.call(line) }
  def prompt = '<prompt time="1795887200">&gt;</prompt>'

  it 'passes a move into a room with no creatures' do
    feed("<nav rm='13041132'/>", '[Kresh Warrens, Chute - 34194] (13041132)', 'Obvious exits: northeast, south', prompt)
    expect(processed.size).to eq(1)
  end

  it 'passes a Sandstorm surge whose rounds link no creature (real lines)' do
    feed('The sandstorm surges, flinging another wall of stinging sand across the area!',
         '[SMR result: 215 (Open d100: 64, Bonus: 69)]',
         'The sandstorm scours a disfigured hive thrall with a blast of sand!', prompt)
    expect(processed.size).to eq(1)
  end

  it 'still drops a chunk with no combat in it' do
    feed('You feel more refreshed.', prompt)
    expect(processed).to be_empty
  end
end
