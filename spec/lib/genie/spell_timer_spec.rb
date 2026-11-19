# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# The genie-spell-timer plugin port (SpellTimerPlugin/PluginProgram.cs v1.10). Expected
# values are read off the plugin source (cited per example); genieflow loads no plugins,
# so there is no Remix-run golden for these.
RSpec.describe Lich::Genie::SpellTimer do
  let(:store) { Lich::Genie::GlobalStore.new }
  let(:timer) { described_class.new(store: store) }

  def pop(*lines)
    lines.each { |line| timer.parse_text("#{line}\r\n", 'percwindow') }
  end

  def vars(name)
    %w[active duration charge].to_h { |field| [field, store.get("SpellTimer.#{name}.#{field}")] }.compact
  end

  it 'reads "(N roisaen)" as active with that duration (PluginProgram.cs:143-149)' do
    pop('Ignite  (11 roisaen)')
    expect(vars('Ignite')).to eq('active' => '1', 'duration' => '11')
  end

  it 'reads OM and Indefinite as 999, not Lich dr_active_spells 1000 (PluginProgram.cs:150-154)' do
    pop('Persistence of Mana  (OM)', 'Hydra Hex  (Indefinite)')
    expect([vars('PersistenceofMana'), vars('HydraHex')]).to all(eq('active' => '1', 'duration' => '999'))
  end

  it 'reads any other parenthesised detail as active with duration 0 (Fading, inexact verbiage, singular roisan)' do
    pop('Cure Disease  (Fading)', 'Khri Prowess  (a few roisaen)', 'Khri Sagacity  (1 roisan)')
    expect([vars('CureDisease'), vars('KhriProwess'), vars('KhriSagacity')]).to all(eq('active' => '1', 'duration' => '0'))
  end

  it 'reads Osrel Meraud as its percentage (PluginProgram.cs:130-139)' do
    pop('Osrel Meraud  (94%)')
    expect(vars('OsrelMeraud')).to eq('active' => '1', 'duration' => '94')
  end

  it 'gives Stellar Collector a .charge and no anlaen conversion (PluginProgram.cs:121-129, 291-300)' do
    pop('Stellar Collector  (25%, 4 anlaen)')
    expect(vars('StellarCollector')).to eq('active' => '1', 'duration' => '0', 'charge' => '25')
    pop('Stellar Collector  (30%, 10 roisaen)')
    expect(vars('StellarCollector')).to eq('active' => '1', 'duration' => '10', 'charge' => '30')
  end

  it 'turns the orbiting slivers line into Moonblade Slivers (PluginProgram.cs:157-174)' do
    pop('Many small orbiting slivers of lunar magic')
    expect(vars('MoonbladeSlivers')).to eq('active' => '1', 'duration' => '2')
    pop('A few small orbiting slivers of lunar magic')
    expect(vars('MoonbladeSlivers')).to eq('active' => '1', 'duration' => '1')
    pop('No small orbiting slivers of lunar magic')
    expect(vars('MoonbladeSlivers')).to eq('active' => '0', 'duration' => '0')
  end

  it 'names variables with spaces, apostrophes and hyphens removed (spellNameToVariableName)' do
    pop("Redeemer's Pride  (30 roisaen)", 'Heroic Strength-Of-Arms  (2 roisaen)')
    expect(store.keys).to include('SpellTimer.RedeemersPride.active', 'SpellTimer.HeroicStrengthOfArms.duration')
  end

  it 'ignores other windows and lines that are not spell lines' do
    timer.parse_text("Ignite  (11 roisaen)\r\n", 'main')
    pop('You feel a tingle.', '')
    expect(store.keys).to eq([])
  end

  it 'ends an update at the next percWindow clear: spells not listed go inactive (finishPop)' do
    pop('Ignite  (11 roisaen)', 'Tailwind  (30 roisaen)')
    timer.parse_xml('<clearStream id="percWindow"/>')
    pop('Tailwind  (29 roisaen)')
    timer.parse_xml('<clearStream id="percWindow"/>')
    expect([vars('Ignite'), vars('Tailwind')]).to eq([{ 'active' => '0', 'duration' => '0' }, { 'active' => '1', 'duration' => '29' }])
  end

  it 'reacts only to the exact percWindow clear buffer' do
    pop('Ignite  (11 roisaen)')
    timer.parse_xml("<clearStream id='percWindow'/>")
    timer.parse_xml('<clearStream id="percWindow"/>')
    expect(vars('Ignite')).to eq('active' => '1', 'duration' => '11') # popped in the round the 2nd clear closed
    timer.parse_xml('<clearStream id="percWindow"/>')
    expect(vars('Ignite')).to eq('active' => '0', 'duration' => '0')
  end

  it 'knows the spells variables.cfg had at the first update, so a stale active 1 is reset (stands in for the saved spell list)' do
    store.set('SpellTimer.Ignite.active', '1')
    store.set('SpellTimer.Ignite.duration', '5')
    timer.parse_xml('<clearStream id="percWindow"/>')
    expect(vars('Ignite')).to eq('active' => '0', 'duration' => '0')
  end

  it 'writes a variable only when its value changes (`#var` only on a difference)' do
    pop('Ignite  (11 roisaen)')
    stamp = store.stamp('SpellTimer.Ignite.active')
    pop('Ignite  (10 roisaen)')
    expect(store.stamp('SpellTimer.Ignite.active')).to eq(stamp)
    expect(store.get('SpellTimer.Ignite.duration')).to eq('10')
  end

  it "writes saved (#var) globals, so #var save keeps them like the plugin's #var" do
    pop('Ignite  (11 roisaen)')
    expect(store.persistent?('SpellTimer.Ignite.active')).to be(true)
  end

  it 'is driven by GameState from the percWindow rows of a session (the session capture)' do
    state = Lich::Genie::GameState.new(spell_timer: timer)
    File.foreach(File.expand_path('../../fixtures/genie/game_state/session_capture_rows.txt', __dir__)) { |row| state.feed("#{row.chomp}\r\n") }
    expect(vars('Ignite')).to eq('active' => '1', 'duration' => '9')
    expect(vars('RedeemersPride')).to include('active' => '1')
  end

  # Each `#var` the plugin sends raises a variable change in Remix (Command.cs:931-933 R).
  describe '#take_changes' do
    it 'lists the variables written since the last call, in write order, then empties' do
      pop('Ignite  (11 roisaen)')
      expect(timer.take_changes).to eq(%w[SpellTimer.Ignite.active SpellTimer.Ignite.duration])
      expect(timer.take_changes).to eq([])
    end

    it 'lists nothing for an update that changes no value (setGenieVariables writes only changes)' do
      pop('Ignite  (11 roisaen)')
      timer.take_changes
      pop('Ignite  (11 roisaen)')
      expect(timer.take_changes).to eq([])
      pop('Ignite  (10 roisaen)')
      expect(timer.take_changes).to eq(%w[SpellTimer.Ignite.duration])
    end
  end
end
