# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::Variables do
  subject(:variables) { described_class.new(game_state: game_state, global_store: store) }

  let(:game_state) { { 'health' => '100' } }
  let(:store) { Lich::Genie::GlobalStore.new(file: nil) }

  describe 'local variables' do
    it 'stores, reads, and deletes, coercing values to strings' do
      variables.local_set('count', 3)
      expect(variables.local_get('count')).to eq('3')
      expect(variables.local_key?('count')).to be(true)
      variables.local_delete('count')
      expect(variables.local_key?('count')).to be(false)
    end

    it 'is case-sensitive' do
      variables.local_set('Name', 'a')
      expect(variables.local_key?('name')).to be(false)
    end
  end

  describe 'global variables' do
    it 'reads from the store' do
      variables.global_set('gold', 500)
      expect(variables.global_get('gold')).to eq('500')
      expect(variables.global_key?('gold')).to be(true)
    end

    it 'falls back to reserved game state when not in the store' do
      expect(variables.global_get('health')).to eq('100')
      expect(variables.global_key?('health')).to be(true)
      expect(variables.global_get('missing')).to be_nil
    end

    it 'lets a stored global shadow reserved game state' do
      variables.global_set('health', '42')
      expect(variables.global_get('health')).to eq('42')
    end

    it 'passes the persist flag through to the store' do
      variables.global_set('temp', 'x', persist: false)
      expect(variables.global_get('temp')).to eq('x')
    end

    it 'keeps local and global namespaces separate' do
      variables.local_set('x', 'local')
      variables.global_set('x', 'global')
      expect(variables.get(:local, 'x')).to eq('local')
      expect(variables.get(:global, 'x')).to eq('global')
    end
  end

  describe 'authoritative (live-wins) game state' do
    # A resolver may declare some names live-authoritative (the EXPTracker/TimeTracker
    # plugin namespaces, $scriptlist): names it synthesizes each read with no game update
    # to stamp. For those, live state must win over a stale value in the store.
    let(:game_state) do
      live = { 'Time.isDay' => '1', 'health' => '100' }
      Object.new.tap do |o|
        o.define_singleton_method(:[]) { |n| live[n] }
        o.define_singleton_method(:key?) { |n| live.key?(n) }
        o.define_singleton_method(:authoritative?) { |n| n.start_with?('Time.') }
      end
    end

    it 'lets live state win over a stale stored value for authoritative names' do
      variables.global_set('Time.isDay', '0') # e.g. loaded from a Genie variables.cfg
      expect(variables.global_get('Time.isDay')).to eq('1')
    end

    it 'still falls back to the store for authoritative names the resolver returns nil for' do
      variables.global_set('Time.isXibarUp', '0')
      expect(variables.global_get('Time.isXibarUp')).to eq('0')
    end

    it 'does NOT flip precedence for non-authoritative reserved names (stored #var still wins)' do
      variables.global_set('health', '42')
      expect(variables.global_get('health')).to eq('42')
    end
  end

  # Remix has one variable list, so `#var invisible 0` holds until the next game update
  # of `invisible`, which wins again (Globals.cs:604-617 R; Game.cs:2093-2099 R). Flow
  # golden: t88_reserved_last_writer.
  describe 'last writer wins between a #var and the game' do
    let(:clock) { Lich::Genie::WriteClock.new }
    let(:store) { Lich::Genie::GlobalStore.new(write_clock: clock) }
    let(:capture) { Lich::Genie::GameState.new(write_clock: clock) }
    let(:game_state) { Lich::Genie::ReservedState.new(game_state: capture) }

    def indicator(visible)
      capture.feed("<indicator id='IconINVISIBLE' visible='#{visible}'/>\r\n")
    end

    it 'shows the #var until the game next writes the name, then the game value' do
      indicator('y')
      variables.global_set('invisible', '0')
      expect(variables.global_get('invisible')).to eq('0')
      indicator('y')
      expect(variables.global_get('invisible')).to eq('1')
      variables.global_set('invisible', '0')
      expect(variables.global_get('invisible')).to eq('0')
    end

    it 'keeps a #var of a name the game never writes (client/version are set once in Remix)' do
      variables.global_set('version', '9.9')
      indicator('y')
      expect(variables.global_get('version')).to eq('9.9')
    end

    it 'lets a #var made before any game update win over the Remix default' do
      variables.global_set('hidden', '1')
      expect(variables.global_get('hidden')).to eq('1')
    end

    it 'falls back to the game value after #unvar' do
      indicator('y')
      variables.global_set('invisible', '0')
      variables.global_delete('invisible')
      expect(variables.global_get('invisible')).to eq('1')
    end

    it 'treats a store with no write clock stamp as older than any game write' do
      bare_store = Object.new
      bare_store.define_singleton_method(:get) { |_| 'stale' }
      bare_store.define_singleton_method(:stamp) { |_| nil }
      indicator('n')
      vars = described_class.new(game_state: game_state, global_store: bare_store)
      expect(vars.global_get('invisible')).to eq('0')
    end
  end

  # ListVariables (Command.cs:3002-3079 R; flow t216_var_listing, corpus var.cmd / pvpdummy.cmd).
  describe '#listing' do
    let(:reserved) do
      Lich::Genie::ReservedState.new(game_state: Lich::Genie::GameState.new(write_clock: Lich::Genie::WriteClock.new))
    end
    let(:variables) { described_class.new(game_state: reserved, global_store: store) }

    it 'groups SaveToFile, temporary, reserved, server -- each in SortedList order -- with an ordinal filter' do
      variables.global_set('pvpdummy', 'goblin')
      variables.global_set('Pvp2', 'x')
      variables.global_set('tmpvp', '1', persist: false)
      variables.global_set('svpvp', '2', persist: false, server: true)
      expect(variables.listing('pvp')).to eq(['Active variables: ', 'Filter: pvp', '$pvpdummy=goblin', '(temporary) $tmpvp=1',
                                              '(server) $svpvp=2'])
      expect(variables.listing('Pvp')).to eq(['Active variables: ', 'Filter: Pvp', '$Pvp2=x'])
      expect(variables.listing('zz')).to eq(['Active variables: ', 'Filter: zz', 'None.'])
    end

    it 'lists the reserved globals with their raw stored values, a script\'s re-set one under the script\'s type' do
      variables.global_set('roundtime', '5')
      lines = variables.listing('')
      expect(lines).to include('$roundtime=5', '(reserved) $time=@time@', '(reserved) $client=Genie Remix Client 4',
                               '(reserved) $scriptlist=none')
      expect(lines).not_to include('(reserved) $roundtime=0')
      expect(lines.index('$roundtime=5')).to be < lines.index('(reserved) $account=')
    end
  end
end
