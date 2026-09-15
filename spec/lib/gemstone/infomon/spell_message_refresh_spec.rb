# frozen_string_literal: true

require_relative '../../../spec_helper'

# Load spell data for realistic testing
load_spell_data

require "common/sharedbuffer"
require "common/buffer"
require "games"
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

# Top-level aliases the parser uses at runtime
Skills = Lich::Gemstone::Skills unless defined?(Skills)
Spell = Lich::Common::Spell unless defined?(Spell)
Spells = Lich::Gemstone::Spells unless defined?(Spells)

# A spell's start message while the spell is already up. The game sends
# it when a refreshable effect is refreshed (a recast of Celerity, another
# RAISE under Briar Betrayer), and the timer has to follow: before this
# the parser skipped the message for an active spell, so Lich let its own
# timer run out while the game's had two minutes to go.
RSpec.describe Lich::Gemstone::Infomon::Parser, 'a start message for an active spell' do
  let(:celerity) { Lich::Common::Spell[506] }   # refreshable in the effect list
  let(:briar)    { Lich::Common::Spell[9105] }  # no span: keeps its timer

  before do
    allow(Lich::Gemstone::Infomon).to receive(:set)
    allow(Lich::Gemstone::Spells).to receive(:require_cooldown)
    celerity.putdown
    briar.putdown
  end

  after do
    celerity.putdown
    briar.putdown
  end

  it 'puts an inactive spell up' do
    described_class.parse('You suddenly start moving light-footedly.')
    expect(celerity.active?).to be true
    expect(celerity.timeleft).to be > 0.5
  end

  it 'resets a refreshable spell to its full duration' do
    celerity.putup
    celerity.timeleft = 0.05 # three seconds left on Lich's clock
    described_class.parse('You suddenly start moving light-footedly.')
    expect(celerity.timeleft).to be > 0.5
  end

  it 'leaves a non-refreshable spell on the timer it has' do
    briar.putup
    briar.timeleft = 0.05
    described_class.parse('As you begin to raise your ruic longbow, the briars imbedded in your flesh release their stored blood in a massive pulse of power that you can feel in the core of your very being.  The vines lose all crimson hues, and strength courses through your blood.')
    expect(briar.active?).to be true
    expect(briar.timeleft).to be <= 0.05
  end
end
