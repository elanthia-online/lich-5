# frozen_string_literal: true

require_relative '../../spec_helper'

load_spell_data

require "common/sharedbuffer"
require "common/buffer"
require "games"

Spell = Lich::Common::Spell unless defined?(Spell)

require "gemstone/overwatch"
require "gemstone/infomon"
require "attributes/stats"
require "attributes/resources"
require "attributes/skills"
require "attributes/spells"
require "gemstone/currency"
require "gemstone/infomon/status"
require "gemstone/experience"
require "util/util"
require "gemstone/psms"
require "gemstone/psms/ascension"
require "gemstone/group"

Skills = Lich::Gemstone::Skills unless defined?(Skills)
Spells = Lich::Gemstone::Spells unless defined?(Spells)

# The caster of a group (EVOKE) spell gets no messaging about who it landed
# on, so Group records a cooldown for everyone grouped at the time and lets
# the next casting correct any member it guessed wrong about.
RSpec.describe Lich::Gemstone::Group, 'per-target group spell cooldowns' do
  let(:spell) { Spell[215] } # Heroism: 180s cooldown on the EVOKE version

  def member(name)
    double(noun: name, id: name.hash.to_s)
  end

  before do
    Lich::Gemstone::Group.spell_cooldowns.clear
    allow(Lich::Gemstone::Group).to receive(:members).and_return([member('Grhim'), member('Painz')])
    allow(spell).to receive(:group_cooldown).and_return(180)
  end

  after { Lich::Gemstone::Group.spell_cooldowns.clear }

  it 'reports an unknown member as ready with no time left' do
    expect(described_class.spell_cooldown_ready?(spell, 'Bransen')).to be true
    expect(described_class.spell_cooldown_left(spell, 'Bransen')).to eq 0.0
  end

  it 'puts every grouped member on cooldown when a group casting lands' do
    described_class.record_spell_cooldown(spell)
    expect(described_class.spell_cooldown_ready?(spell, 'Grhim')).to be false
    expect(described_class.spell_cooldown_left(spell, 'Grhim')).to be_within(2).of(180)
  end

  it 'reports a member as ready once the cooldown has elapsed' do
    described_class.record_spell_cooldown(spell)
    described_class.spell_cooldowns[spell.num]['Grhim'] = Time.now - 1
    expect(described_class.spell_cooldown_ready?(spell, 'Grhim')).to be true
    expect(described_class.spell_cooldown_left(spell, 'Grhim')).to eq 0.0
  end

  it 'never reports negative time left' do
    described_class.spell_cooldowns[spell.num] = { 'Grhim' => Time.now - 500 }
    expect(described_class.spell_cooldown_left(spell, 'Grhim')).to eq 0.0
  end

  it 'leaves someone who joined after the casting ready' do
    described_class.record_spell_cooldown(spell)
    expect(described_class.spell_cooldown_ready(spell)).to be_empty

    allow(Lich::Gemstone::Group).to receive(:members)
      .and_return([member('Grhim'), member('Bransen')])
    expect(described_class.spell_cooldown_ready(spell)).to eq ['Bransen']
  end

  it 'records nothing for a spell with no per-target cooldown' do
    allow(spell).to receive(:group_cooldown).and_return(nil)
    described_class.record_spell_cooldown(spell)
    expect(described_class.spell_cooldowns[spell.num]).to be_nil
    expect(described_class.spell_cooldown_ready?(spell, 'Grhim')).to be true
  end

  it 'keeps separate cooldowns per spell' do
    other = Spell[219]
    allow(other).to receive(:group_cooldown).and_return(360)
    described_class.record_spell_cooldown(spell)
    expect(described_class.spell_cooldown_ready?(other, 'Grhim')).to be true
  end

  it 'refreshes the stamp when a later casting lands' do
    described_class.record_spell_cooldown(spell)
    described_class.spell_cooldowns[spell.num]['Grhim'] = Time.now + 5
    described_class.record_spell_cooldown(spell)
    expect(described_class.spell_cooldown_left(spell, 'Grhim')).to be_within(2).of(180)
  end
end

# The trigger side: only the caster's own group (EVOKE) message starts the
# cooldowns. A self-cast, or seeing someone else's casting land on you, uses
# the same spell and must not stamp anyone.
RSpec.describe Lich::Gemstone::Infomon::Parser, 'group casting messages' do
  let(:heroism) { Spell[215] }
  let(:spell_shield) { Spell[219] }

  def member(name)
    double(noun: name, id: name.hash.to_s)
  end

  before do
    allow(Lich::Gemstone::Infomon).to receive(:set)
    allow(Lich::Gemstone::Spells).to receive(:require_cooldown)
    allow(XMLData).to receive(:level).and_return(100)
    allow(XMLData).to receive(:name).and_return('Nisugi')
    allow(Lich::Gemstone::Spells).to receive(:majorspiritual).and_return(50)
    allow(Lich::Gemstone::Group).to receive(:members).and_return([member('Grhim')])
    allow(heroism).to receive(:group_cooldown).and_return(180)
    allow(spell_shield).to receive(:group_cooldown).and_return(360)
    Lich::Gemstone::Group.spell_cooldowns.clear
    heroism.putdown
    spell_shield.putdown
  end

  after do
    Lich::Gemstone::Group.spell_cooldowns.clear
    heroism.putdown
    spell_shield.putdown
  end

  it "starts cooldowns on the caster's own group casting" do
    described_class.parse('A brilliant aura surrounds you and your group.  You feel charged with extra vitality.')
    expect(Lich::Gemstone::Group.spell_cooldown_ready?(heroism, 'Grhim')).to be false
    expect(Lich::Gemstone::Group.spell_cooldown_left(heroism, 'Grhim')).to be_within(2).of(180)
  end

  it 'starts no cooldowns on a self-cast of the same spell' do
    described_class.parse('A brilliant aura surrounds you and sinks into your skin.  You feel charged with extra vitality.')
    expect(Lich::Gemstone::Group.spell_cooldowns[heroism.num]).to be_nil
    expect(Lich::Gemstone::Group.spell_cooldown_ready?(heroism, 'Grhim')).to be true
  end

  it 'starts no cooldowns when another caster lands the spell on you' do
    described_class.parse('An opalescent aura surrounds you.')
    expect(Lich::Gemstone::Group.spell_cooldowns[spell_shield.num]).to be_nil
  end

  it "uses each spell's own cooldown length" do
    described_class.parse('An opalescent aura surrounds you and your group.')
    expect(Lich::Gemstone::Group.spell_cooldown_left(spell_shield, 'Grhim')).to be_within(2).of(360)
  end
end
