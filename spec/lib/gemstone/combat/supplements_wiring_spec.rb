# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'tmpdir'
require 'gemstone/combat/defs/attacks'
require 'gemstone/combat/defs/flares'
require 'gemstone/combat/defs/statuses'
require 'gemstone/combat/defs/outcomes'
require 'gemstone/combat/defs/supplements'
require 'gemstone/combat/parser'

# The splice: supplements feed the shipped assembly points, each def module
# binds one frozen TABLE last and in a single assignment, and reload_defs!
# re-executes the def files so the tables rebind from shipped defs plus the
# current file. With no file, the assembled tables are the shipped ones.
RSpec.describe 'combat definition supplements wiring' do
  let(:defs) { Lich::Gemstone::Combat::Definitions }
  let(:supplements) { defs::Supplements }
  let(:parser) { Lich::Gemstone::Combat::Parser }

  def bolded(id, noun, name)
    %(<pushBold/><a exist="#{id}" noun="#{noun}">#{name}</a><popBold/>)
  end

  def write(yaml)
    File.write(@file, yaml)
    @stamp = (@stamp || Time.now - 60) + 1
    File.utime(@stamp, @stamp, @file)
  end

  def messages
    Lich::Messaging.messages.map { |m| m[:message] }.join("\n")
  end

  around(:each) do |example|
    Dir.mktmpdir('combat-defs-wiring') do |dir|
      @file = File.join(dir, 'defs.yaml')
      supplements.path = @file
      Lich::Messaging.clear_messages!
      example.run
    ensure
      # Leave the process with the shipped tables, whatever the example did.
      supplements.path = nil
      supplements.reload_defs!
    end
  end

  # Shipped-only sizes, computed from the shipped lists themselves.
  def shipped_attack_count
    %i[PRIORITY_ATTACKS BASIC_ATTACKS SPELL_ATTACKS WIKI_SPELL_ATTACKS MANEUVER_ATTACKS WEAPON_ATTACKS
       SHIELD_ATTACKS COMPANION_ATTACKS ENVIRONMENTAL_ATTACKS THIRD_PERSON_SPELL_ATTACKS THIRD_PERSON_ATTACKS]
      .sum { |c| defs::Attacks.const_get(c).size }
  end

  describe 'with no supplement file' do
    it 'assembles exactly the shipped defs' do
      supplements.reload_defs!
      expect(supplements.summary.values).to all(eq(0))
      expect(defs::Attacks::ALL_ATTACKS.size).to eq(shipped_attack_count)
      expect(defs::Flares::FLARE_LOOKUP.size).to eq(defs::Flares::FLARE_DEFS.sum { |d| d.patterns.size })
      expect(defs::Statuses::ALL_STATUSES).to eq(defs::Statuses::STATUS_EFFECTS)
      expect(defs::Outcomes::OUTCOME_LOOKUP.size).to eq(defs::Outcomes::OUTCOME_DEFS.sum { |d| d.patterns.size })
    end

    it 'is identical with an empty file' do
      supplements.reload_defs!
      before = [defs::Attacks::TABLE, defs::Flares::TABLE, defs::Statuses::TABLE, defs::Outcomes::TABLE]
               .map { |t| t.lookup.map { |row| row.map { |v| v.is_a?(Regexp) ? v.source : v } } }
      write('')
      supplements.reload_defs!
      after = [defs::Attacks::TABLE, defs::Flares::TABLE, defs::Statuses::TABLE, defs::Outcomes::TABLE]
              .map { |t| t.lookup.map { |row| row.map { |v| v.is_a?(Regexp) ? v.source : v } } }
      expect(after).to eq(before)
    end
  end

  describe 'the tables' do
    it 'are frozen, carry the lookup and gate together, and are what the readers use' do
      [defs::Attacks, defs::Flares, defs::Statuses, defs::Outcomes].each do |mod|
        table = mod::TABLE
        expect(table).to be_frozen
        expect(table).to be_a(defs::Table)
        expect(table.lookup).to be_frozen
        expect(table.lookup.first.first).to be_a(Regexp)
      end
      expect(defs::Attacks.table).to equal(defs::Attacks::TABLE)
    end
  end

  describe 'reload_defs! with a supplement file' do
    let(:yaml) do
      <<~YAML
        attacks:
          - name: ice_lance
            slot: priority
            patterns: ['You hurl a lance of ice at (?<target>[^!]+)!']
          - name: tackle
            patterns: ['You launch yourself bodily at (?<target>.+?) and connect!']
        flares:
          - name: frost_flare
            damaging: true
            patterns: ['\\*\\* Your .+? flares with frost, striking (?<target>.+?)! \\*\\*']
        statuses:
          - name: chilled
            add: ['(?<target>.+?) shivers uncontrollably\\.']
            remove: ['(?<target>.+?) stops shivering\\.']
        outcomes:
          - type: miss
            patterns: ['The ice lance shatters harmlessly near (?<target>[^.]+)\\.']
      YAML
    end

    it 'makes every kind recognisable through the shipped parse entry points' do
      write(yaml)
      reloaded = supplements.reload_defs!
      expect(reloaded.map { |f| File.basename(f) }).to include('attacks.rb', 'flares.rb', 'statuses.rb', 'outcomes.rb')
      expect(reloaded).not_to include(a_string_ending_with('supplements.rb'))

      target = bolded(123, 'kobold', 'a kobold')
      attack = parser.parse_attack("You hurl a lance of ice at #{target}!")
      expect(attack[:name]).to eq(:ice_lance)
      expect(attack[:target][:id]).to eq(123)

      reused = parser.parse_attack("You launch yourself bodily at #{target} and connect!")
      expect(reused[:name]).to eq(:tackle)

      flare = defs::Flares.parse("** Your icy blade flares with frost, striking #{target}! **")
      expect(flare).to include(name: :frost_flare, damaging: true, aoe: false, spawns: false)

      expect(defs::Statuses.parse("#{target} shivers uncontrollably.")).to include(status: :chilled, action: :add)
      expect(defs::Statuses.parse("#{target} stops shivering.")).to include(status: :chilled, action: :remove)
      expect(defs::Outcomes.parse("The ice lance shatters harmlessly near #{target}.")).to eq(:miss)
    end

    it 'keeps the shipped defs matching alongside the supplements' do
      write(yaml)
      supplements.reload_defs!
      target = bolded(452443346, 'warg', 'a niveous giant warg')
      shipped = parser.parse_attack("The lashing emerald briar lashes out violently at #{target}, dragging it to the ground!")
      expect(shipped[:name]).to eq(:tangleweed)
    end

    it 'places a priority supplement ahead of the generic swing defs' do
      write(yaml)
      supplements.reload_defs!
      names = defs::Attacks::ALL_ATTACKS.map(&:name)
      expect(names.index(:ice_lance)).to be < names.index(:attack)
      expect(names.index(:attack)).to be < names.rindex(:tackle)
    end

    it 'drops the supplements again when the file is removed' do
      write(yaml)
      supplements.reload_defs!
      expect(parser.parse_attack("You hurl a lance of ice at #{bolded(1, 'x', 'x')}!")[:name]).to eq(:ice_lance)

      File.delete(@file)
      supplements.reload_defs!
      # The line now falls through to the shipped generic bolt def, which is
      # exactly the point: the supplement no longer pre-empts it.
      expect(parser.parse_attack("You hurl a lance of ice at #{bolded(1, 'x', 'x')}!")[:name]).to eq(:bolt)
      expect(supplements.summary.values).to all(eq(0))
    end

    # The literal gate is a union of plain strings matched case-sensitively,
    # so a case-folded supplemental pattern was filtered out before the scan
    # ever saw it: the pattern matched the line directly while
    # Statuses.parse returned nil. Its literal now joins a case-insensitive
    # union instead, so the pattern stays gated rather than falling back to
    # a full scan of every line.
    it 'recognises a case-insensitive supplemental pattern' do
      write(<<~YAML)
        statuses:
          - name: zephyr_chilled
            add: ['(?i)ZEPHYR chills (?<target>.+)']
      YAML
      supplements.reload_defs!

      pattern = supplements.statuses.find { |s| s.name == :zephyr_chilled }.add_patterns.first
      expect(pattern.match('zephyr chills a kobold')).not_to be_nil
      expect(defs::Statuses::TABLE.always_scan).not_to include(pattern)
      expect(defs::Statuses::TABLE.rejects?('zephyr chills a kobold')).to be(false)

      parsed = defs::Statuses.parse('zephyr chills a kobold')
      expect(parsed).not_to be_nil
      expect(parsed[:status]).to eq(:zephyr_chilled)
      expect(parsed[:action]).to eq(:add)
      expect(parsed[:target]).to eq('a kobold')
    end

    it 'reports stale? only when the file changed since the tables were assembled' do
      supplements.reload_defs!
      expect(supplements.stale?).to be(false)
      write(yaml)
      expect(supplements.stale?).to be(true)
      supplements.reload_defs!
      expect(supplements.stale?).to be(false)
    end

    # stale? must answer for the assembled tables, not for the document
    # cache. Sharing one stamp meant that inspecting the file after an edit
    # -- exactly what loaded and summary are for -- cleared the flag while
    # the new definition was still unrecognised, so the login-time
    # `reload_defs! if stale?` skipped it.
    it 'stays stale while inspecting, until the tables are actually rebuilt' do
      supplements.reload_defs!
      write(yaml)
      expect(supplements.stale?).to be(true)

      expect(supplements.loaded).to include(:attacks)
      expect(supplements.summary[:attacks]).to be > 0
      supplements.flares
      supplements.statuses
      supplements.outcomes

      expect(supplements.stale?).to be(true)
      expect(parser.parse_attack("You hurl a lance of ice at #{bolded(1, 'x', 'x')}!")[:name]).not_to eq(:ice_lance)

      supplements.reload_defs!
      expect(supplements.stale?).to be(false)
      expect(parser.parse_attack("You hurl a lance of ice at #{bolded(1, 'x', 'x')}!")[:name]).to eq(:ice_lance)
    end
  end

  # The compatibility detectors are built lazily, and the memo is a module
  # ivar that survives the def file re-executing. Without invalidation a
  # reload left the detector answering for the previous table -- including
  # a cached nil, which would have looked like "these patterns can never
  # be combined" forever.
  describe 'the compatibility detectors across a reload' do
    it 'rebuilds the attack detector so it sees a newly added pattern' do
      supplements.reload_defs!
      line = 'You zorch a kobold!'
      before = defs::Attacks::ATTACK_DETECTOR
      expect(before&.match?(line)).to be_falsey

      write("attacks:\n  - name: zorch\n    patterns: ['You zorch (?<target>.+?)!']\n")
      supplements.reload_defs!

      after = defs::Attacks::ATTACK_DETECTOR
      expect(after).not_to equal(before)
      expect(after.match?(line)).to be(true)
      # and it agrees with the table the parser actually reads
      expect(defs::Attacks::TABLE.lookup.any? { |(rx, _n)| rx.match?(line) }).to be(true)
    end

    it 'rebuilds the status detector too' do
      supplements.reload_defs!
      line = 'a kobold shivers uncontrollably.'
      before = defs::Statuses::STATUS_DETECTOR
      expect(before&.match?(line)).to be_falsey

      write("statuses:\n  - name: chilled\n    add: ['(?<target>.+?) shivers uncontrollably\\.']\n")
      supplements.reload_defs!

      after = defs::Statuses::STATUS_DETECTOR
      expect(after).not_to equal(before)
      expect(after.match?(line)).to be(true)
    end

    it 'does not keep serving a cached nil once the offending pattern is gone' do
      # A numbered backreference cannot be unioned with a named capture, so
      # the detector is nil while that def is present -- but only while.
      write("statuses:\n  - name: echoing\n    add: ['^(\\w+) echoes \\1$']\n")
      supplements.reload_defs!
      expect(defs::Statuses::STATUS_DETECTOR).to be_nil

      File.delete(@file)
      supplements.reload_defs!
      expect(defs::Statuses::STATUS_DETECTOR).to be_a(Regexp)
    end
  end

  describe 'reload_defs! when a def file fails to load' do
    it 'reports the file, keeps its previous table, and still reloads the rest' do
      before = defs::Flares::TABLE
      flares_file = $LOADED_FEATURES.grep(/flares\.rb\z/).first
      allow(supplements).to receive(:load).and_call_original
      allow(supplements).to receive(:load).with(flares_file).and_raise(SyntaxError, 'boom')

      reloaded = supplements.reload_defs!
      expect(reloaded).not_to include(flares_file)
      expect(reloaded.map { |f| File.basename(f) }).to include('attacks.rb', 'statuses.rb', 'outcomes.rb')
      expect(defs::Flares::TABLE).to equal(before)
      expect(messages).to include('flares.rb failed to reload: SyntaxError: boom. Its previous definitions remain in effect.')

      # "Its previous definitions remain in effect" has to hold at the class
      # level too. pattern_gate.rb defines Table with Struct.new, which
      # yields a fresh class each run; re-executing it on reload left the
      # kept table an instance of a class the constant no longer named.
      expect(reloaded.map { |f| File.basename(f) }).not_to include('pattern_gate.rb')
      expect(defs::Flares::TABLE).to be_a(defs::Table)
      expect(defs::Attacks::TABLE).to be_a(defs::Table)
    end

    # The files that did reload must not answer for the one that did not.
    # With a single shared stamp they did, so stale? went false while the
    # failed module's previous table was still live and the login-time
    # `reload_defs! if stale?` never retried it.
    it 'stays stale while one table is still the old one, and clears once it reloads' do
      supplements.reload_defs!
      write(<<~YAML)
        attacks:
          - name: ice_lance
            patterns: ['You hurl a lance of ice at (?<target>[^!]+)!']
        statuses:
          - name: chilled
            add: ['(?<target>.+?) shivers uncontrollably\\.']
      YAML
      statuses_file = $LOADED_FEATURES.grep(/statuses\.rb\z/).first

      allow(supplements).to receive(:load).and_call_original
      allow(supplements).to receive(:load).with(statuses_file).and_raise(SyntaxError, 'boom')
      reloaded = supplements.reload_defs!

      expect(reloaded).not_to include(statuses_file)
      # The kinds that did reload are current, and the one that did not is
      # still on its old table -- so the file as a whole is not assembled.
      expect(parser.parse_attack("You hurl a lance of ice at #{bolded(1, 'x', 'x')}!")[:name]).to eq(:ice_lance)
      expect(defs::Statuses.parse('a kobold shivers uncontrollably.')).to be_nil
      expect(supplements.stale?).to be(true)

      # The retry that staleness earns now succeeds.
      RSpec::Mocks.space.proxy_for(supplements).reset
      supplements.reload_defs!
      expect(supplements.stale?).to be(false)
      expect(defs::Statuses.parse('a kobold shivers uncontrollably.')).to include(status: :chilled)
    end
  end
end
