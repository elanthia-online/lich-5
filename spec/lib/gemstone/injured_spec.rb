# frozen_string_literal: true

require_relative '../../spec_helper'

require "ox"
require "common/class_exts/synchronizedsocket"
require "common/detachable_client_registry"
require "common/sharedbuffer"
require "common/shutdown_coordinator"
require "common/xmlparser"
require "common/downstreamhook"
require "common/front-end"
require "util/util"
require "games"
require "gemstone/wounds"
require "gemstone/scars"
require "gemstone/effects"
require "gemstone/injured"

RSpec.describe Lich::Gemstone::Injured do
  include_context 'Gemstone injury data'

  before do
    XMLData.reset
    set_injuries

    # Never talk to the game from a spec: these would send _injury commands.
    allow(described_class).to receive(:fix_injury_mode)
    allow(Lich::Gemstone::Wounds).to receive(:fix_injury_mode)
    allow(Lich::Gemstone::Scars).to receive(:fix_injury_mode)
    allow(Lich::Gemstone::Effects::Buffs).to receive(:active?).and_return(false)

    # Clear the cache between examples so tests are independent.
    described_class.instance_variable_set(:@injury_cache_key, nil)
    described_class.instance_variable_set(:@wounds_cache, nil)
    described_class.instance_variable_set(:@scars_cache, nil)
  end

  it 'keeps its cache state and mutex on the class itself, not the singleton class' do
    expect(described_class.instance_variable_get(:@cache_mutex)).to be_a(Mutex)
    expect { described_class.able_to_cast? }.not_to raise_error
  end

  it 'returns true for a healthy character' do
    expect(described_class.able_to_cast?).to be true
    expect(described_class.able_to_sneak?).to be true
    expect(described_class.able_to_search?).to be true
    expect(described_class.able_to_use_ranged?).to be true
  end

  it 'notices an in-place injury update after a cached result' do
    expect(described_class.able_to_cast?).to be true

    # Mutate the live hash the way XMLParser does, without reassigning it.
    XMLData.injuries['head']['wound'] = 3

    expect(described_class.able_to_cast?).to be false
    expect(described_class.able_to_search?).to be false
  end

  it 'notices healing after a cached rejection' do
    XMLData.injuries['leftLeg']['wound'] = 2
    expect(described_class.able_to_sneak?).to be false

    XMLData.injuries['leftLeg']['wound'] = 0
    expect(described_class.able_to_sneak?).to be true
  end

  it 'serves repeated calls from the cache when nothing changed' do
    expect(Lich::Gemstone::Scars).to receive(:all_scars).once.and_call_original

    3.times { described_class.able_to_cast? }
  end

  it 'refetches when the injury state changes' do
    expect(Lich::Gemstone::Scars).to receive(:all_scars).twice.and_call_original

    described_class.able_to_cast?
    XMLData.injuries['rightArm']['wound'] = 1
    described_class.able_to_cast?
  end

  it 'ignores rank 1 scars but not rank 2 scars' do
    XMLData.injuries['head']['scar'] = 1
    expect(described_class.able_to_cast?).to be true

    XMLData.injuries['head']['scar'] = 2
    expect(described_class.able_to_cast?).to be false
  end

  it 'lets Sigil of Determination bypass rank 2 but not rank 3' do
    allow(Lich::Gemstone::Effects::Buffs).to receive(:active?).with("Sigil of Determination").and_return(true)

    XMLData.injuries['head']['wound'] = 2
    expect(described_class.able_to_cast?).to be true

    XMLData.injuries['head']['wound'] = 3
    expect(described_class.able_to_cast?).to be false
  end
end
