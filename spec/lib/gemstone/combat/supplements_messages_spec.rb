# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'tmpdir'
require 'gemstone/combat/defs/messages'
require 'gemstone/combat/defs/supplements'
require 'gemstone/combat/messages'

# The messages: section of the supplement file: declarative captures and
# literal values compiled into MessageDef data blocks, validated against
# the shipped event registry (Messages::CONTRACTS), spliced into families
# before their gates derive, and re-evaluated by the runtime after a reload.
RSpec.describe 'combat message supplements' do
  let(:defs) { Lich::Gemstone::Combat::Definitions }
  let(:supplements) { defs::Supplements }
  let(:messages) { Lich::Gemstone::Combat::Messages }
  let(:events) { Lich::Common::Events }

  def write(yaml)
    File.write(@file, yaml)
    @stamp = (@stamp || Time.now - 60) + 1
    File.utime(@stamp, @stamp, @file)
  end

  def reports
    Lich::Messaging.messages.map { |m| m[:message] }.join("\n")
  end

  # The runtime installs a DownstreamHook when a family goes active; the
  # spec_helper mock has no add/remove, so stand one in (as messages_spec does).
  before(:each) do
    stub_const('DownstreamHook', Class.new do
      define_singleton_method(:add) { |_name, _action, persist: nil| persist }
      define_singleton_method(:remove) { |_name| nil }
    end)
  end

  around(:each) do |example|
    Dir.mktmpdir('combat-msg-supp') do |dir|
      @file = File.join(dir, 'defs.yaml')
      supplements.path = @file
      events.clear!('combat.')
      Lich::Messaging.clear_messages!
      example.run
    end
  end

  # Runs while the DownstreamHook stub is still in place (after hooks run
  # before mock teardown), so the uninstall on the way out has a target.
  after(:each) do
    events.clear!('combat.')
    messages.shutdown
    supplements.path = nil
    supplements.reload_defs!
  end

  describe 'the shipped contract registry' do
    it 'names every shipped event with the family it is defined in' do
      supplements.reload_defs!
      defs::Messages::SHIPPED_FAMILIES.each do |family|
        family.events.each do |event|
          contract = defs::Messages::CONTRACTS[event]
          expect(contract).not_to be_nil, "no CONTRACTS entry for shipped event #{event}"
          expect(contract[:family]).to eq(family.name), "#{event} is defined in #{family.name}, CONTRACTS says #{contract[:family]}"
        end
      end
      expect(defs::Messages::CONTRACTS.keys).to match_array(defs::Messages::SHIPPED_FAMILIES.flat_map(&:events))
    end
  end

  describe 'with no file' do
    it 'assembles the shipped families only and the table is frozen' do
      supplements.reload_defs!
      expect(supplements.message_families).to eq([])
      expect(defs::Messages::USER_FAMILIES).to eq([])
      expect(defs::Messages::FAMILIES.map(&:name)).to eq(%i[disarm hazard ambush hold bless archery marks reaction])
      expect(defs::Messages::TABLE).to be_frozen
      expect(messages.table).to equal(defs::Messages::TABLE)
    end
  end

  describe 'compiling' do
    it 'adds a def to a shipped family and event with a typed capture' do
      write(<<~YAML)
        messages:
          - family: marks
            event: swift_justice
            patterns: ['Your Swift Justice charges are restored to (?<n>\\d+)\\.']
            captures:
              charges: { from: n, type: integer }
      YAML
      rows = supplements.messages(:marks)
      expect(rows.size).to eq(1)
      event, pattern, data = rows.first
      expect(event).to eq(:swift_justice)
      expect(pattern).to be_a(Regexp)
      expect(data.call(pattern.match('Your Swift Justice charges are restored to 3.'))).to eq(charges: 3)
      expect(supplements.summary[:messages]).to eq(1)
    end

    it 'builds a new family and event from captures shorthand and literal values' do
      write(<<~YAML)
        messages:
          - family: user_item_prep
            event: user_feed_result
            patterns: ['You feed the (?<what>.+?) and it hums softly\\.', 'You feed the (?<what>.+?) and it purrs\\.']
            captures: { what: what }
            values: { ok: true, count: 2, note: fed, nothing: null }
      YAML
      rows = supplements.messages(:user_item_prep)
      expect(rows.map(&:first)).to eq(%i[user_feed_result user_feed_result])
      _event, pattern, data = rows.first
      expect(data.call(pattern.match('You feed the crystal and it hums softly.')))
        .to eq(what: 'crystal', ok: true, count: 2, note: 'fed', nothing: nil)
      expect(supplements.message_families).to eq([:user_item_prep])
    end

    # values.dup in the data block is a shallow copy, so an unfrozen String
    # literal would be the same object in every payload the def emits: a
    # consumer doing payload[:note] << 'x' or .replace would rewrite the
    # fact every later match reports. Frozen, that consumer raises on its
    # own line instead of silently corrupting the next event.
    it 'does not let a consumer mutating a literal rewrite later facts' do
      write(<<~YAML)
        messages:
          - family: user_item_prep
            event: user_feed_result
            patterns: ['You feed the (?<what>.+?) and it hums softly\\.']
            captures: { what: what }
            values: { state: ready }
      YAML
      _event, pattern, data = supplements.messages(:user_item_prep).first
      line = 'You feed the crystal and it hums softly.'

      first = data.call(pattern.match(line))
      expect(first[:state]).to eq('ready')
      expect(first[:state]).to be_frozen
      expect { first[:state] << ' corrupted' }.to raise_error(FrozenError)

      # An independent later match still reports the fact as written.
      expect(data.call(pattern.match(line))[:state]).to eq('ready')
    end

    it 'gives each payload its own hash, so adding a key does not leak either' do
      write(<<~YAML)
        messages:
          - family: user_item_prep
            event: user_feed_result
            patterns: ['You feed the (?<what>.+?) and it hums softly\\.']
            values: { state: ready }
      YAML
      _event, pattern, data = supplements.messages(:user_item_prep).first
      line = 'You feed the crystal and it hums softly.'

      first = data.call(pattern.match(line))
      first[:injected] = true
      expect(data.call(pattern.match(line))).to eq(state: 'ready')
    end

    it 'converts a symbol-typed capture and a string literal for a symbol contract key' do
      write(<<~YAML)
        messages:
          - family: hazard
            event: hive_trap
            patterns: ['A (?<how>burrow) trap springs!']
            captures: { kind: { from: how, type: symbol } }
          - family: disarm
            event: disarm_seen
            patterns: ['Your (?<noun>\\w+) is yanked away!']
            captures: { noun: noun }
            values: { kind: recover }
      YAML
      trap = supplements.messages(:hazard).first
      expect(trap[2].call(trap[1].match('A burrow trap springs!'))).to eq(kind: :burrow)
      disarm = supplements.messages(:disarm).first
      expect(disarm[2].call(disarm[1].match('Your sword is yanked away!'))).to eq(noun: 'sword', kind: :recover)
    end
  end

  describe 'rejections' do
    def only_report(yaml)
      write(yaml)
      expect(supplements.summary[:messages]).to eq(0)
      reports
    end

    it 'keeps a shipped event in its shipped family' do
      r = only_report("messages:\n  - family: hazard\n    event: swift_justice\n    patterns: ['x (?<n>\\d+)']\n    captures: { charges: { from: n, type: integer } }\n")
      expect(r).to include('swift_justice is a shipped event of the marks family and cannot be declared under hazard')
    end

    it 'requires the user_ prefix on a new event and on a new family' do
      r = only_report("messages:\n  - family: marks\n    event: my_thing\n    patterns: ['x']\n  - family: mine\n    event: user_thing\n    patterns: ['y']\n")
      expect(r).to include('new event my_thing must be named with the user_ prefix')
      expect(r).to include('new family mine must be named with the user_ prefix')
    end

    it 'allows a new user_ event inside a shipped family' do
      write("messages:\n  - family: marks\n    event: user_mark\n    patterns: ['a mark appears']\n")
      expect(supplements.messages(:marks).map(&:first)).to eq([:user_mark])
    end

    it 'lists its events by family in .loaded' do
      write(<<~YAML)
        messages:
          - family: marks
            event: user_mark
            patterns: ['a mark appears']
          - family: user_item_prep
            event: user_feed_result
            patterns: ['You feed the (?<what>.+?) and it hums softly\\.']
            captures: { what: what }
      YAML

      expect(supplements.loaded).to eq(
        messages: { marks: [:user_mark], user_item_prep: [:user_feed_result] }
      )
    end

    it 'enforces the payload contract of a reused event' do
      r = only_report(<<~YAML)
        messages:
          - family: marks
            event: swift_justice
            patterns: ['charges (?<n>\\d+)']
          - family: marks
            event: swift_justice
            patterns: ['charges (?<n>\\d+)']
            captures: { charges: { from: n, type: string } }
          - family: marks
            event: arcane_reflex
            patterns: ['reflexes!']
            values: { active: yes_please }
      YAML
      expect(r).to include('swift_justice consumers expect a charges (integer) in the payload')
      expect(r).to include('swift_justice consumers expect charges as integer, but captures.charges is typed string')
      expect(r).to include('arcane_reflex consumers expect active as boolean, but values.active is "yes_please"')
    end

    it 'rejects a capture missing from a pattern, an unknown type, a reserved key, and a duplicate key' do
      r = only_report(<<~YAML)
        messages:
          - family: user_f
            event: user_a
            patterns: ['no capture here']
            captures: { what: what }
          - family: user_f
            event: user_b
            patterns: ['(?<n>\\d+)']
            captures: { n: { from: n, type: float } }
          - family: user_f
            event: user_c
            patterns: ['x']
            values: { raw: nope }
          - family: user_f
            event: user_d
            patterns: ['(?<n>\\d+)']
            captures: { n: n }
            values: { n: 1 }
      YAML
      expect(r).to include('captures.what: no (?<what>...) capture in every pattern')
      expect(r).to include('captures.n: type must be one of string, integer, symbol, got "float"')
      expect(r).to include('values.raw is set by Lich itself and cannot be overridden')
      expect(r).to include('n is declared under both captures: and values:')
    end
  end

  describe 'a payload that cannot be built' do
    it 'emits nothing and reports once, instead of a misleading fact' do
      write(<<~YAML)
        messages:
          - family: user_f
            event: user_count
            patterns: ['count (?<n>\\S+)( extra (?<opt>\\d+))?']
            captures: { n: { from: n, type: integer } }
      YAML
      supplements.reload_defs!
      expect(defs::Messages.scan('count 12')).to eq([[:user_count, { n: 12, raw: 'count 12' }]])
      expect(defs::Messages.scan('count twelve')).to eq([])
      expect(reports).to include('messages[0] (user_count) matched but emitted nothing: n="twelve" is not an integer')

      Lich::Messaging.clear_messages!
      defs::Messages.scan('count twelve')
      expect(reports).to eq('') # once per def
    end

    it 'emits nothing when an optional capture did not participate' do
      write(<<~YAML)
        messages:
          - family: user_f
            event: user_opt
            patterns: ['seen( (?<n>\\d+))?']
            captures: { n: { from: n, type: integer } }
      YAML
      supplements.reload_defs!
      expect(defs::Messages.scan('seen')).to eq([])
      expect(reports).to include('capture (?<n>...) did not participate')
    end
  end

  describe 'after reload_defs!' do
    let(:yaml) do
      <<~YAML
        messages:
          - family: marks
            event: swift_justice
            patterns: ['Your Swift Justice charges are restored to (?<n>\\d+)\\.']
            captures: { charges: { from: n, type: integer } }
          - family: user_item_prep
            event: user_feed_result
            patterns: ['You feed the (?<what>.+?) and it hums softly\\.']
            captures: { what: what }
            values: { ok: true }
      YAML
    end

    it 'splices into the shipped family before its gate derives, and registers the new family' do
      write(yaml)
      supplements.reload_defs!
      marks = defs::Messages::BY_NAME[:marks]
      expect(marks.defs.map(&:event)).to include(:swift_justice)
      expect(defs::Messages.scan('Your Swift Justice charges are restored to 4.', [marks]))
        .to eq([[:swift_justice, { charges: 4, raw: 'Your Swift Justice charges are restored to 4.' }]])
      # the shipped def still matches too
      expect(defs::Messages.scan('Your Swift Justice charges are increased to 2.', [marks]).first[1][:charges]).to eq(2)

      expect(defs::Messages::USER_FAMILIES.map(&:name)).to eq([:user_item_prep])
      expect(defs::Messages::FAMILY_OF[:user_feed_result].name).to eq(:user_item_prep)
      expect(messages.event?(:user_feed_result)).to be(true)
    end

    # `;hmr combat/defs/` is a separate script that plainly `load`s each def
    # file; it never calls Supplements.reload_defs!. The def file therefore
    # refreshes subscriptions itself when it rebinds its table -- otherwise
    # the event exists while its family stays inactive, the hook stays down
    # and nothing emits, which is exactly what the documented command did.
    it 'activates the family when the def file is merely re-loaded, as ;hmr does' do
      seen = []
      events.on('combat.user_feed_result', name: 'spec-hmr') { |topic, data| seen << [topic, data] }
      messages.refresh!
      expect(messages.active_families).to eq([])

      write(yaml)
      supplements.reset! # the memo is not ;hmr's to clear either
      verbose = $VERBOSE
      $VERBOSE = nil
      load File.join(LIB_DIR, 'gemstone', 'combat', 'defs', 'messages.rb')
      $VERBOSE = verbose

      expect(messages.event?(:user_feed_result)).to be(true)
      expect(messages.active_families.map(&:name)).to eq([:user_item_prep])
      expect(messages.stats[:installed]).to be_truthy

      messages.process('You feed the crystal and it hums softly.')
      expect(seen.size).to eq(1)
      expect(seen.first[1]).to include(what: 'crystal', ok: true)
    end

    it 'activates a subscription made before the event existed, and emits definitions_reloaded' do
      seen = []
      events.on('combat.user_feed_result', name: 'spec-feed') { |topic, data| seen << [topic, data] }
      reloads = []
      events.on('combat.definitions_reloaded', name: 'spec-reload') { |_t, data| reloads << data }
      messages.refresh!
      expect(messages.active_families).to eq([]) # nothing owns the event yet

      write(yaml)
      supplements.reload_defs!

      expect(messages.active_families.map(&:name)).to eq([:user_item_prep])
      expect(reloads.size).to eq(1)
      expect(reloads.first[:files]).to include('messages.rb')
      expect(reloads.first[:supplements][:messages]).to eq(2)

      messages.process('You feed the crystal and it hums softly.')
      expect(seen.size).to eq(1)
      expect(seen.first[1]).to include(what: 'crystal', ok: true)
    end

    it 'drops the family and deactivates it when the file is removed' do
      events.on('combat.user_feed_result', name: 'spec-feed') { |*| }
      write(yaml)
      supplements.reload_defs!
      expect(messages.active_families.map(&:name)).to eq([:user_item_prep])

      File.delete(@file)
      supplements.reload_defs!
      expect(messages.active_families).to eq([])
      expect(messages.event?(:user_feed_result)).to be(false)
      expect(messages.process('You feed the crystal and it hums softly.')).to eq([])
    end
  end

  # A user pattern that exceeds its evaluation budget must cost that one
  # pattern and nothing else: not the facts the line already yielded, not
  # the defs that follow it, and not the rest of the family behind a gate
  # that raised while deciding whether to scan at all.
  describe 'a supplemental pattern that times out while matching' do
    let(:shipped_line) { 'You shiver slightly as an invisible rash covers your body.' }

    # Stands in for a catastrophically backtracking regex without needing
    # one: matching raises the same error Regexp.timeout raises.
    def timing_out_pattern(source = 'rash')
      Regexp.new(source).tap do |rx|
        allow(rx).to receive(:match).and_raise(Regexp::TimeoutError)
        allow(rx).to receive(:match?).and_raise(Regexp::TimeoutError)
      end
    end

    # Splices a def carrying +pattern+ into the hazard family, before or
    # after the shipped ones, and returns the family list scan takes.
    def hazard_with(pattern, event: :user_boom, position: :after)
      hazard = defs::Messages.table.by_name[:hazard]
      row = defs::Messages::MessageDef.new(event, pattern, ->(_m) { {} })
      order = position == :before ? [row, *hazard.defs] : [*hazard.defs, row]
      gate, always = defs::PatternGate.build(order.map(&:pattern))
      [defs::Messages::Family.new(:hazard, order.freeze, gate, always)]
    end

    it 'keeps a shipped fact found before the timing-out pattern' do
      families = hazard_with(timing_out_pattern, position: :after)
      found = defs::Messages.scan(shipped_line, families)
      expect(found.map(&:first)).to eq([:itchy_curse])
    end

    it 'still delivers a shipped fact that comes after it' do
      families = hazard_with(timing_out_pattern, position: :before)
      found = defs::Messages.scan(shipped_line, families)
      expect(found.map(&:first)).to eq([:itchy_curse])
    end

    it 'scans the family when the gate itself times out deciding' do
      # An ungated pattern raises inside PatternGate.rejects?; treating the
      # family as rejected there would hide every def it holds.
      families = hazard_with(timing_out_pattern('.'), position: :after)
      expect(families.first.always_scan).not_to be_empty
      found = defs::Messages.scan(shipped_line, families)
      expect(found.map(&:first)).to eq([:itchy_curse])
    end

    it 'reports once per pattern however many lines hit it, and again after a reload' do
      families = hazard_with(timing_out_pattern)
      3.times { defs::Messages.scan(shipped_line, families) }
      expect(reports.scan('took too long').size).to eq(1)

      Lich::Messaging.clear_messages!
      supplements.reset!
      defs::Messages.scan(shipped_line, families)
      expect(reports).to include('took too long')
    end
  end

  describe 'the shipped example file' do
    it 'loads its messages section with no rejections' do
      supplements.path = File.join(LIB_DIR, 'gemstone', 'combat', 'defs', 'supplements.example.yaml')
      expect(supplements.summary[:messages]).to eq(5)
      expect(reports).not_to include('skipped')
    end
  end
end
