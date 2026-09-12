# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/defs/messages'

# The message families, each pinned against the game line the scripts
# were matching (ecleanse set_hooks, bigshot hunt_monitor, eohunter's
# watch rules). scan over ALL families here; the subscription gate is
# Combat::Messages' and tested there.
RSpec.describe Lich::Gemstone::Combat::Definitions::Messages do
  def link(id, noun, name = noun) = %(<a exist="#{id}" noun="#{noun}">#{name}</a>)
  def bold(id, noun, name) = "<pushBold/>#{link(id, noun, name)}<popBold/>"
  # the article outside the link, the game's form for "a kobold"
  def bold_a(id, noun) = "<pushBold/>a #{link(id, noun)}<popBold/>"

  def scan(line) = described_class.scan(line)

  def only(line)
    found = scan(line)
    expect(found.size).to eq(1), "expected one event for #{line.inspect}, got #{found.inspect}"
    found.first
  end

  it 'names every family once and maps every event to one family' do
    expect(described_class::FAMILIES.map(&:name)).to eq(%i[disarm hazard ambush hold bless archery marks reaction])
    described_class::FAMILIES.each do |family|
      family.events.each { |e| expect(described_class::FAMILY_OF[e]).to equal(family) }
    end
  end

  it 'gates every family on a literal (no def is a bare alternation)' do
    described_class::FAMILIES.each do |family|
      expect(family.gate).not_to be_nil, "#{family.name} has no gate"
    end
  end

  describe 'disarm' do
    it 'sees a weapon knocked away, wrenched, or floated off, with the noun and the recovery kind' do
      event, data = only("Your #{link('1', 'falchion', 'vultite falchion')} is knocked from your grasp!")
      expect(event).to eq(:disarm_seen)
      expect(data).to include(kind: :recover, noun: 'falchion')
      _, data = only("Your #{link('1', 'falchion', 'vultite falchion')} tears free from your hands and floats up into the air.")
      expect(data).to include(kind: :telekinetic_recover, noun: 'falchion')
      _, data = only("The webbing entangles your #{link('1', 'falchion', 'vultite falchion')}, rendering it useless.")
      expect(data).to include(kind: :recover_weapon_webbing, noun: 'falchion')
      line = "Your #{link('1', 'falchion', 'vultite falchion')} strikes one of the bony protrusions on #{bold_a('2', 'crawler')} back and it is wrenched out of your grasp!"
      _, data = only(line)
      expect(data).to include(kind: :recover, noun: 'falchion', raw: line)
    end

    it 'sees the sanctum transform with the new noun' do
      line = "Striking with a serpent's unsettling quickness, the creature bites.  Vile venom courses, kindling it into an unholy semblance of life.  The dead form twists and mutates, sprouting scales and cold eyes as it transforms into a #{link('3', 'wyrm', 'scaled wyrm')}!"
      expect(only(line)).to match([:sanctum_transform, { noun: 'wyrm', raw: line }])
    end
  end

  describe 'hazard' do
    it 'sees the itchy curse, the infected wound, the entangling force, and both hive traps' do
      expect(only('You shiver slightly as an invisible rash covers your body.').first).to eq(:itchy_curse)
      expect(only('The flesh around the wound feels hot and cold at the same time, heavy with infection.').first).to eq(:infected_wound)
      expect(only('An unseen force entangles you, restricting your movement!').first).to eq(:entangled)
      expect(only('You notice a flickering glint in the shadows.')).to include(:hive_trap, hash_including(kind: :apparatus))
      expect(only('The ground churns violently as flashes of chitin jut from its depths!')).to include(:hive_trap, hash_including(kind: :ground))
    end
  end

  describe 'ambush' do
    it 'names the ambusher, or not, and sees the bolt' do
      expect(only("#{link('-10', 'Bob')} leaps from hiding to attack!")).to match([:ambusher, { noun: 'Bob', raw: "#{link('-10', 'Bob')} leaps from hiding to attack!" }])
      expect(only('A shadowy figure leaps from hiding to attack!').last).to include(noun: nil)
      expect(only('You bolt out of the room!').first).to eq(:bolted)
    end
  end

  describe 'hold' do
    it 'sees the snake, the release, and the item limit' do
      expect(only("You are unable to get out of the way as <pushBold/>the #{link('7', 'snake')}<popBold/> coils tightly around you, holding you in place!")).to match([:rooted, hash_including(id: '7')])
      expect(only("You don't seem to be able to move to do that.").first).to eq(:rooted)
      expect(only("You're finally able to break free of <pushBold/>the #{link('7', 'snake', "snake's")}<popBold/> coils!")).to match([:unrooted, hash_including(id: '7')])
      expect(only('You are unable to hold the number of items you are trying to carry.').first).to eq(:item_limit)
    end
  end

  describe 'bless' do
    it 'sees a blessed strike shrugged off and a blessing gone' do
      line = "The #{link('5', 'arrow', 'silver-tipped arrow')} strikes true, but the ghost shrugs off some of the damage!"
      expect(only(line)).to match([:bless_shrugged, { id: '5', noun: 'arrow', raw: line }])
      expect(only("Your #{link('5', 'arrow', 'silver-tipped arrow')} returns to normal.")).to match([:bless_expired, hash_including(id: '5', noun: 'arrow')])
    end
  end

  describe 'archery' do
    it 'sees where the arrow stuck, the aim, and the bonded return' do
      expect(only("The arrow sticks in #{bold_a('9', 'kobold')}'s left leg!")).to match([:arrow_stuck, hash_including(id: '9', where: 'leg')])
      expect(only("You're now aiming at the head of your target.")).to match([:aiming, hash_including(where: 'head')])
      expect(only("You're now no longer aiming at anything in particular.")).to match([:aiming, hash_including(where: nil)])
      expect(only('A vultite dagger rises out of the shadows and flies back to your waiting hand!')).to match([:bond_return, hash_including(what: 'vultite dagger')])
    end
  end

  describe 'marks' do
    it 'sees the haze, the rebuke, the charges and the reflexes' do
      expect(only("#{bold('4', 'orc', 'an orc')} is suddenly surrounded by a blood red haze.")).to match([:haze_703, hash_including(id: '4', on: true)])
      expect(only("The blood red haze dissipates from around #{bold('4', 'orc', 'an orc')}.")).to match([:haze_703, hash_including(id: '4', on: false)])
      expect(only("#{bold('4', 'orc', 'an orc')} is visibly struggling against your radiant aura!")).to match([:rebuke_1614, hash_including(id: '4', on: true)])
      expect(only("#{bold('4', 'orc', 'an orc')} recovers from being rebuked.")).to match([:rebuke_1614, hash_including(id: '4', on: false)])
      expect(only('Your Swift Justice charges are increased to 3.')).to match([:swift_justice, hash_including(charges: 3)])
      expect(only('Vital energy infuses you, hastening your arcane reflexes!')).to match([:arcane_reflex, hash_including(active: true)])
    end
  end

  describe 'reaction' do
    it 'sees the weapon reaction prompt with its command' do
      expect(only("You could use this opportunity to <d cmd='WEAPON PARRY #123'>parry</d>!")).to match([:weapon_reaction, hash_including(reaction: 'PARRY #123')])
    end
  end

  it 'yields nothing for ordinary lines' do
    expect(scan('You swing a vultite falchion at a kobold!')).to eq([])
    expect(scan('<prompt time="1">&gt;</prompt>')).to eq([])
  end
end
