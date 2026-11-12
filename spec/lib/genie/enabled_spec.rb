# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# The per-character enable toggle must survive relogins. The key is derived from
# live XMLData (empty until the character stream arrives), so these guard the
# caching/scoping logic that made the toggle "not stick": a premature (pre-login)
# check must not memoize a false that poisons the real, logged-in read.
RSpec.describe Lich::Genie do
  before do
    described_class.reset_enabled_cache!
    # Back the DB with an in-memory store keyed exactly like lich_settings.
    @store = {}
    allow(described_class).to receive(:persistence_available?).and_return(true)
    allow(described_class).to receive(:read_enabled) { |key| @store[key] == 'true' }
    allow(described_class).to receive(:write_enabled) { |key, value| @store[key] = value.to_s }
    # Default: logged in as DR:Alice unless a test overrides.
    stub_character('DR', 'Alice')
  end

  after { described_class.reset_enabled_cache! }

  def stub_character(game, name)
    allow(described_class).to receive(:safe_xml).with(:game).and_return(game)
    allow(described_class).to receive(:safe_xml).with(:name).and_return(name)
  end

  it 'persists an enabled toggle under the per-character key' do
    described_class.enabled = true
    expect(@store).to eq('genie_enabled:DR:Alice' => 'true')
    expect(described_class.enabled?).to be(true)
  end

  it 'reads a value written by a previous process (relog) fresh' do
    @store['genie_enabled:DR:Alice'] = 'true' # as if a prior session saved it
    described_class.reset_enabled_cache! # fresh process
    expect(described_class.enabled?).to be(true)
  end

  it 'keeps characters independent' do
    described_class.enabled = true # Alice on
    stub_character('DR', 'Bob')
    expect(described_class.enabled?).to be(false) # Bob unaffected
  end

  it 'does NOT let a pre-login check poison the post-login read (the relog bug)' do
    @store['genie_enabled:DR:Alice'] = 'true'
    # Pre-login: XMLData not yet populated -> key is genie_enabled:: -> miss/false.
    stub_character('', '')
    expect(described_class.enabled?).to be(false) # premature check
    # Character stream arrives; the real check must now see the stored true.
    stub_character('DR', 'Alice')
    expect(described_class.enabled?).to be(true)
  end

  it 'does not cache a pre-login read (re-reads live until scoped)' do
    stub_character('', '')
    described_class.enabled? # pre-login read
    stub_character('DR', 'Alice')
    @store['genie_enabled:DR:Alice'] = 'true'
    expect(described_class.enabled?).to be(true)
  end

  # PR #1813 open question: the <genieHook> tags are opt-in per character, off by default.
  describe '.hooks_enabled? (the genieHook opt-in)' do
    it 'is off by default and persists per character under its own key, apart from the engine toggle' do
      described_class.enabled = true
      expect(described_class.hooks_enabled?).to be(false)
      described_class.hooks_enabled = 'on'
      expect(@store).to eq('genie_enabled:DR:Alice' => 'true', 'genie_hooks:DR:Alice' => 'true')
      stub_character('DR', 'Bob')
      expect(described_class.hooks_enabled?).to be(false)
      stub_character('DR', 'Alice')
      described_class.hooks_enabled = false
      expect([described_class.hooks_enabled?, described_class.enabled?]).to eq([false, true])
    end

    it 'reads a row a previous session wrote' do
      @store['genie_hooks:DR:Alice'] = 'true'
      expect(described_class.hooks_enabled?).to be(true)
    end
  end

  # engine_active? is the one gate that keeps the engine (its game-state
  # tap, installed at Lich load for EVERY character) off for a Lich user who never enabled it.
  describe '.engine_active? (the Lich-load tap gate)' do
    it 'is false before login and reads no setting there (no database read per row)' do
      stub_character('', '')
      expect(described_class.engine_active?).to be(false)
      stub_character('DR', '')
      expect(described_class.engine_active?).to be(false)
      expect(described_class).not_to have_received(:read_enabled)
    end

    # PR #1813 review item 3: every hot path asks it once per row/line/send -- after login it must
    # stay a cached read (no database per call), and a toggle must show at once.
    it 'reads the setting once after login however often it is asked, and shows a toggle at once' do
      1000.times { described_class.engine_active? }
      expect(described_class).to have_received(:read_enabled).once
      described_class.enabled = true
      expect(described_class.engine_active?).to be(true)
      described_class.enabled = false
      expect(described_class.engine_active?).to be(false)
      expect(described_class).to have_received(:read_enabled).once
    end

    it 'is false for a logged-in character with no setting row, true once the row says on' do
      expect(described_class.engine_active?).to be(false)
      @store['genie_enabled:DR:Alice'] = 'true'
      described_class.reset_enabled_cache! # a later session reads the row
      expect(described_class.engine_active?).to be(true)
      stub_character('DR', 'Bob')
      expect(described_class.engine_active?).to be(false)
    end

    # End to end: the gated feed the glue installs at Lich load, on a stand-in for Lich's Script.
    it 'keeps the gated tap shut for a character with no setting: a row feeds nothing and the engine never starts' do
      fed = []
      started = []
      capture = Object.new.tap { |c| c.define_singleton_method(:feed) { |line| fed << line } }
      capture.define_singleton_method(:seed) { |&block| block.call.each { |line| fed << [:replay, line] } }
      lich = Class.new { def self.new_downstream_xml(_line) = nil }
      feed = Lich::Genie::GameStateFeed.new(game_state: -> { capture }, report: ->(e) { raise e })
      feed.install(lich, buffer: -> { ['old row'] }, gate: -> { described_class.engine_active? }, on_open: -> { started << true })
      # on threads of their own: the tap marks its calling thread as Lich's parser (READER_KEY)
      Thread.new { lich.new_downstream_xml('row 1') }.join
      expect([fed, started]).to eq([[], []])
      described_class.enabled = true
      Thread.new { lich.new_downstream_xml('row 2') }.join
      expect([fed, started]).to eq([[[:replay, 'old row'], 'row 2'], [true]])
    end
  end
end
