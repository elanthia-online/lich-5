# frozen_string_literal: true

require_relative '../../spec_helper'
require 'gemstone/effects'

RSpec.describe Lich::Gemstone::Effects::Registry do
  let(:registry) { described_class.new('Buffs') }

  before { XMLData.save_dialogs('Buffs', { 'Berserk' => Time.now + 60, 211 => Time.now + 60 }) }
  after { XMLData.reset_dialogs }

  # Runs +scan+ on a reader thread and, while it is paused inside its
  # iteration, adds an effect from this thread the way the XML parser does.
  # Returns whatever the add raised, or nil.
  def add_effect_during_scan(&scan)
    inside = Queue.new
    resume = Queue.new
    paused = false
    pause = lambda do
      next if paused

      paused = true
      inside << true
      resume.pop
    end
    reader = Thread.new { scan.call(pause) }
    unless inside.pop(timeout: 5)
      reader.kill
      raise 'the scan never reached its pause point'
    end
    begin
      XMLData.dialogs['Buffs']['Surge of Strength'] = Time.now + 60
      nil
    rescue => e
      e
    ensure
      resume << true
      reader.join
    end
  end

  # A key whose to_s pauses the scan, for methods whose block only calls to_s.
  def pausing_key(pause)
    key = Object.new
    key.define_singleton_method(:to_s) { pause.call; 'pausing key' }
    XMLData.dialogs['Buffs'][key] = Time.now + 60
  end

  describe 'while the parser adds an effect mid-scan' do
    it 'each does not break the add' do
      expect(add_effect_during_scan { |pause| registry.each { pause.call } }).to be_nil
    end

    it 'Enumerable methods do not break the add' do
      expect(add_effect_during_scan { |pause| registry.select { pause.call } }).to be_nil
    end

    it 'to_h iteration does not break the add' do
      expect(add_effect_during_scan { |pause| registry.to_h.any? { pause.call; false } }).to be_nil
    end

    it 'a Regexp expiration lookup does not break the add' do
      expect(add_effect_during_scan { |pause| pausing_key(pause); registry.expiration(/no such effect/) }).to be_nil
    end
  end

  describe '#to_h' do
    it 'reflects the current effects' do
      expect(registry.to_h.keys).to contain_exactly('Berserk', 211)
    end

    it 'is a copy, so changing it leaves the parser state alone' do
      registry.to_h['Scribbled'] = Time.now + 60
      expect(XMLData.dialogs['Buffs']).not_to have_key('Scribbled')
    end
  end

  describe '#active?' do
    it 'sees an effect added after the registry was last read' do
      registry.to_h
      XMLData.dialogs['Buffs']['Surge of Strength'] = Time.now + 60
      expect(registry.active?('Surge of Strength')).to be(true)
    end

    it 'is false for an expired effect' do
      XMLData.dialogs['Buffs']['Old'] = Time.now - 1
      expect(registry.active?('Old')).to be(false)
    end

    # Specs do not load Lich's NilClass patch, so this also checks that a
    # Regexp with no match does not depend on it.
    it 'is false for a Regexp that matches nothing' do
      expect(registry.expiration(/no such effect/)).to eq(0)
      expect(registry.active?(/no such effect/)).to be(false)
    end

    it 'is true for a Regexp that matches an active effect' do
      expect(registry.active?(/^Bers/)).to be(true)
    end
  end
end

RSpec.describe Lich::Gemstone::Effects, '.display' do
  before do
    require 'terminal-table'
    require 'common/class_exts/numeric'
    load_spell_data
    stub_const('Spell', Lich::Common::Spell)
    XMLData.reset_dialogs
    stub_const('Spells', Module.new)
    allow(Spells).to receive(:get_circle_name).and_return('Minor Spirit')
    allow(Lich::Common::Spell).to receive(:active).and_return([])
  end
  after { XMLData.reset_dialogs }

  # Fills a dialog the way parse_psm3_progressbar does: each bar gets its own
  # expiry Time under both its name and its id, and its id => name is kept in
  # the dialog's names. A repeated name overwrites its earlier name key, as it
  # does in the parser.
  def seed_dialog(kind, bars)
    effects = {}
    names = {}
    bars.each do |id, name|
      expiry = Time.now + 60
      effects[name] = effects[id] = expiry
      names[id] = name
    end
    XMLData.save_dialogs(kind, effects)
    XMLData.save_dialog_names(kind, names)
  end

  # The table ;magic printed, as one string.
  def display_output
    out = nil
    allow(Lich::Messaging).to receive(:mono) { |text| out = text }
    described_class.display
    out
  end

  it 'names each effect from the dialog when ids and names pair up' do
    seed_dialog('Buffs', { 101 => 'Spirit Warding I', 107 => 'Spirit Warding II' })

    out = display_output

    expect(out).to match(/101 .*Spirit Warding I /)
    expect(out).to match(/107 .*Spirit Warding II /)
  end

  it 'shows both effects by name when two share one name' do
    # The effects Hash keys by id and by name, so two Sword Hymns leave one
    # name key for two id keys. Regression for elanthia-online/lich-5#2248.
    seed_dialog('Buffs', { 555_001 => 'Sword Hymn', 555_002 => 'Sword Hymn' })

    out = nil
    expect { out = display_output }.not_to raise_error
    expect(out).to match(/555001 .*Sword Hymn /)
    expect(out).to match(/555002 .*Sword Hymn /)
  end

  it 'keeps the dialog name for a bar id that is not a Lich spell number' do
    # The game sends Symbol of Protection as bar 3011; Lich numbers it 9806
    # and marks it active by name. Dropping the name would print the bar as
    # 3011 and then list 9806 again under Other.
    seed_dialog('Buffs', { 3011 => 'Symbol of Protection', 555_001 => 'Sword Hymn', 555_002 => 'Sword Hymn' })
    allow(Lich::Common::Spell).to receive(:active).and_return([Lich::Common::Spell[9806]])

    out = display_output

    expect(out).to match(/3011 .*Buffs .*Symbol of Protection /)
    expect(out).not_to match(/Other/)
  end

  it 'names effects from the spell list when the dialog carries only ids' do
    soon = Time.now + 60
    XMLData.save_dialogs('Buffs', { 101 => soon, 107 => soon })

    out = display_output

    expect(out).to match(/101 .*Spirit Warding I /)
    expect(out).to match(/107 .*Spirit Warding II /)
  end

  it 'falls back to the id for an unnamed effect the spell list does not know' do
    soon = Time.now + 60
    XMLData.save_dialogs('Buffs', { 99_999 => soon, 101 => soon })

    out = nil
    expect { out = display_output }.not_to raise_error
    expect(out).to match(/99999 .*Buffs .*99999 /)
  end
end
