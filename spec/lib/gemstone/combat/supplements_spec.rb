# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'tmpdir'
require 'gemstone/combat/defs/attacks'
require 'gemstone/combat/defs/flares'
require 'gemstone/combat/defs/statuses'
require 'gemstone/combat/defs/outcomes'
require 'gemstone/combat/defs/supplements'

# The player-supplied YAML -> Struct compiler. Nothing here is wired into the
# shipped tables yet; these examples pin the contract the splice step will
# rely on: identical Structs to hand-written defs, every rejection path,
# shipped-name reuse, the token expansion, and the mtime-driven re-read.
RSpec.describe Lich::Gemstone::Combat::Definitions::Supplements do
  let(:defs_ns) { Lich::Gemstone::Combat::Definitions }

  around(:each) do |example|
    Dir.mktmpdir('combat-defs') do |dir|
      @file = File.join(dir, 'defs.yaml')
      described_class.path = @file
      Lich::Messaging.clear_messages!
      example.run
    ensure
      described_class.path = nil
    end
  end

  def write(yaml)
    File.write(@file, yaml)
    # File.mtime resolution can be coarse; force a distinct stamp per write.
    @stamp = (@stamp || Time.now - 60) + 1
    File.utime(@stamp, @stamp, @file)
  end

  def messages
    Lich::Messaging.messages.map { |m| m[:message] }.join("\n")
  end

  describe 'with no file' do
    it 'returns empty frozen arrays for every kind and reports nothing' do
      expect(described_class.present?).to be(false)
      expect(described_class.attacks(:priority)).to eq([])
      expect(described_class.attacks).to be_frozen
      expect(described_class.flares).to eq([])
      expect(described_class.statuses).to eq([])
      expect(described_class.outcomes).to eq([])
      expect(described_class.summary).to eq(attacks: 0, flares: 0, statuses: 0, outcomes: 0)
      expect(messages).to eq('')
    end
  end

  describe 'with an empty or malformed file' do
    it 'treats an empty file as no supplements' do
      write('')
      expect(described_class.flares).to eq([])
      expect(messages).to eq('')
    end

    it 'ignores a non-mapping document and says so' do
      write("- just\n- a list\n")
      expect(described_class.attacks).to eq([])
      expect(messages).to include('expected a mapping of kinds')
    end

    it 'reports a YAML syntax error and loads nothing' do
      write("attacks: [unclosed\n")
      expect(described_class.attacks).to eq([])
      expect(messages).to include('could not be read')
    end

    it 'ignores a kind whose value is not a list' do
      write("flares: nope\n")
      expect(described_class.flares).to eq([])
      expect(messages).to include('[combat.defs] flares ignored -- expected a list, got String')
    end
  end

  describe 'attacks' do
    it 'compiles to AttackDefs equal to hand-written ones, in the requested slot' do
      write(<<~YAML)
        attacks:
          - name: ice_lance
            slot: priority
            patterns: ['You hurl a lance of ice at (?<target>[^!]+)!']
          - name: frost_bolt
            patterns: ['You fling a bolt of frost at (?<target>[^!]+)!']
      YAML
      priority = described_class.attacks(:priority)
      expect(priority).to eq([defs_ns::Attacks::AttackDef.new(:ice_lance, [/You hurl a lance of ice at (?<target>[^!]+)!/])])
      expect(priority.first.patterns).to be_frozen
      expect(described_class.attacks(:generic).map(&:name)).to eq([:frost_bolt])
      expect(described_class.attacks(:third_person)).to eq([])
    end

    it 'rejects an unknown slot and an invalid name individually' do
      write(<<~YAML)
        attacks:
          - name: ok_one
            patterns: ['You poke (?<target>.+?)!']
          - name: Bad-Name
            patterns: ['x']
          - name: wrong_slot
            slot: first
            patterns: ['y']
      YAML
      expect(described_class.attacks.map(&:name)).to eq([:ok_one])
      expect(messages).to include('attacks[1] skipped -- name: must be a lowercase identifier')
      expect(messages).to include('attacks[2] skipped -- slot: must be one of priority, generic, third_person')
    end

    it 'warns, but keeps, a pattern with no target or attacker capture' do
      write("attacks:\n  - name: vague\n    patterns: ['Something happens!']\n")
      expect(described_class.attacks.map(&:name)).to eq([:vague])
      expect(messages).to include('attacks[0] warning -- no pattern names a (?<target>...)')
    end

    it 'raises for an unknown slot argument' do
      expect { described_class.attacks(:bogus) }.to raise_error(ArgumentError, /unknown attack slot/)
    end
  end

  describe 'patterns' do
    it 'drops only the pattern that fails to compile, and the entry when none compile' do
      write(<<~YAML)
        attacks:
          - name: partly
            patterns: ['(unclosed', 'You jab (?<target>.+?)!']
          - name: wholly
            patterns: ['(unclosed']
      YAML
      expect(described_class.attacks.map(&:name)).to eq([:partly])
      expect(described_class.attacks.first.patterns.size).to eq(1)
      expect(messages).to include('attacks[0].patterns[0] skipped -- invalid regular expression "(unclosed"')
      expect(messages).to include('attacks[1] skipped -- none of its patterns compiled')
    end

    it 'compiles with the shared regex timeout' do
      write("attacks:\n  - name: t\n    patterns: ['You jab (?<target>.+?)!']\n")
      expect(described_class.attacks.first.patterns.first.timeout).to eq(Lich::Common::UserDefs::REGEX_TIMEOUT_SECONDS)
    end

    it 'expands {{MK_PRE}} and {{MK_POST}} to the markup-tolerance fragments' do
      write("attacks:\n  - name: t\n    patterns: ['(?<attacker>.+?)''s{{MK_POST}} blade bites {{MK_PRE}}you']\n")
      rx = described_class.attacks.first.patterns.first
      expect(rx.source).to eq("(?<attacker>.+?)'s#{defs_ns::MK_POST} blade bites #{defs_ns::MK_PRE}you")
      expect(rx).to match(%(<a exist="1" noun="orc">an orc's</a> blade bites <pushBold/><a exist="2" noun="x">you</a>))
    end

    it 'rejects a pattern with an unknown token' do
      write("attacks:\n  - name: t\n    patterns: ['{{NOPE}} hits (?<target>.+?)']\n")
      expect(described_class.attacks).to eq([])
      expect(messages).to include('unknown token {{NOPE}}; known tokens are {{MK_PRE}}, {{MK_POST}}')
    end

    it 'rejects a missing or empty patterns list' do
      write("attacks:\n  - name: none\n  - name: empty\n    patterns: []\n")
      expect(described_class.attacks).to eq([])
      expect(messages).to include('attacks[0] skipped -- patterns: must be a non-empty list')
      expect(messages).to include('attacks[1] skipped -- patterns: must be a non-empty list')
    end
  end

  describe 'flares' do
    it 'builds a new flare with omitted flags defaulting to false' do
      write("flares:\n  - name: frost_flare\n    damaging: true\n    patterns: ['\\*\\* frost strikes (?<target>.+?)! \\*\\*']\n")
      flare = described_class.flares.first
      expect(flare).to eq(defs_ns::Flares::FlareDef.new(:frost_flare, [/\*\* frost strikes (?<target>.+?)! \*\*/], true, false, false))
    end

    it 'inherits every omitted flag from a shipped flare of the same name' do
      shipped = defs_ns::Flares::FLARE_DEFS.find { |d| d.name == :acid }
      write("flares:\n  - name: acid\n    patterns: ['\\*\\* acid spits at (?<target>.+?)! \\*\\*']\n")
      flare = described_class.flares.first
      expect([flare.damaging, flare.aoe, flare.spawns]).to eq([shipped.damaging, shipped.aoe, shipped.spawns])
    end

    it 'gives a repeated new name the flags of its first entry, inheriting what later entries omit' do
      write(<<~YAML)
        flares:
          - name: custom_frost
            damaging: true
            aoe: true
            patterns: ['Your staff bursts with frost!']
          - name: custom_frost
            patterns: ['Your staff spits frost!']
          - name: custom_frost
            aoe: true
            patterns: ['Your staff hums with frost!']
      YAML
      tuples = described_class.flares.map { |f| [f.name, f.damaging, f.aoe, f.spawns] }
      expect(tuples).to eq([[:custom_frost, true, true, false]] * 3)
      expect(messages).not_to include('skipped')
    end

    it 'rejects a later entry whose explicit flag contradicts the first entry for that new name' do
      write(<<~YAML)
        flares:
          - name: custom_frost
            damaging: true
            patterns: ['Your staff bursts with frost!']
          - name: custom_frost
            damaging: false
            patterns: ['Your staff spits frost!']
      YAML
      expect(described_class.flares.size).to eq(1)
      expect(messages).to include('flares[1] skipped -- damaging: false contradicts flares[0] (custom_frost) (damaging: true)')
    end

    it 'rejects an explicit flag that contradicts the shipped flare' do
      shipped = defs_ns::Flares::FLARE_DEFS.find { |d| d.name == :acid }
      write("flares:\n  - name: acid\n    damaging: #{!shipped.damaging}\n    patterns: ['\\*\\* acid \\*\\*']\n")
      expect(described_class.flares).to eq([])
      expect(messages).to include('contradicts the shipped acid flare')
    end

    it 'rejects a non-boolean flag' do
      write("flares:\n  - name: newf\n    aoe: yes please\n    patterns: ['\\*\\* x \\*\\*']\n")
      expect(described_class.flares).to eq([])
      expect(messages).to include('aoe: must be true or false')
    end
  end

  describe 'statuses' do
    it 'builds add and remove lists, either of which may be absent' do
      write(<<~YAML)
        statuses:
          - name: chilled
            add: ['(?<target>.+?) shivers\\.']
            remove: ['(?<target>.+?) stops shivering\\.']
          - name: add_only
            add: ['(?<target>.+?) is marked\\.']
      YAML
      chilled, add_only = described_class.statuses
      expect(chilled).to eq(defs_ns::Statuses::StatusDef.new(:chilled, [/(?<target>.+?) shivers\./], [/(?<target>.+?) stops shivering\./]))
      expect(add_only.remove_patterns).to eq([])
      expect(add_only.remove_patterns).to be_frozen
    end

    it 'rejects a status with neither list' do
      write("statuses:\n  - name: hollow\n")
      expect(described_class.statuses).to eq([])
      expect(messages).to include('needs at least one pattern under add: or remove:')
    end
  end

  describe 'outcomes' do
    it 'builds an OutcomeDef for a shipped type' do
      write("outcomes:\n  - type: miss\n    patterns: ['The lance misses (?<target>.+?)\\.']\n")
      expect(described_class.outcomes).to eq([defs_ns::Outcomes::OutcomeDef.new(:miss, [/The lance misses (?<target>.+?)\./])])
    end

    it 'rejects an unknown outcome type and lists the known ones' do
      write("outcomes:\n  - type: whiff\n    patterns: ['x']\n")
      expect(described_class.outcomes).to eq([])
      expect(messages).to include('unknown outcome type :whiff; use one of')
      expect(messages).to include('miss')
    end
  end

  describe 'entries that are not mappings' do
    it 'skips a bare string entry with a message' do
      write("attacks:\n  - just_a_name\n")
      expect(described_class.attacks).to eq([])
      expect(messages).to include('attacks[0] skipped -- expected a mapping with name: and patterns:')
    end
  end

  describe 're-reading' do
    it 'memoizes until the file changes, then re-reads; and empties when the file is removed' do
      write("attacks:\n  - name: first\n    patterns: ['You jab (?<target>.+?)!']\n")
      expect(described_class.attacks.map(&:name)).to eq([:first])

      write("attacks:\n  - name: second\n    patterns: ['You jab (?<target>.+?)!']\n")
      expect(described_class.attacks.map(&:name)).to eq([:second])

      File.delete(@file)
      expect(described_class.attacks).to eq([])
    end

    # Review finding on the first draft: a reader that captured the old
    # document and was then overtaken by a reset (an edit plus a read of
    # another kind) published old definitions into the new cache, where
    # they persisted for every later caller. Barriers, not sleeps: thread A
    # is held just after it captures the document, B does the edit/reset/
    # read, then A resumes.
    it 'does not publish a build from a stale document after a concurrent reset' do
      write("attacks:\n  - name: before_edit\n    patterns: ['x (?<target>.+?)!']\n")
      a_captured = Queue.new
      resume_a = Queue.new
      reader = nil
      paused = false

      # Pause the reader once, right after it captures the (old) document.
      # Its retry after the reset comes back through here and must not
      # pause again.
      allow(described_class).to receive(:document).and_wrap_original do |original|
        doc = original.call
        if Thread.current == reader && !paused
          paused = true
          a_captured << true
          resume_a.pop
        end
        doc
      end

      reader = Thread.new { described_class.attacks.map(&:name) }
      a_captured.pop

      write("attacks:\n  - name: after_edit\n    patterns: ['x (?<target>.+?)!']\n")
      described_class.reset!
      described_class.flares # caches the new document without touching :attacks

      resume_a << true
      expect(reader.value).to eq([:after_edit]) # the overlapping reader retried against the current file
      expect(described_class.attacks.map(&:name)).to eq([:after_edit])
    end

    it 'reset! forces a re-read even when the mtime is unchanged' do
      write("attacks:\n  - name: first\n    patterns: ['You jab (?<target>.+?)!']\n")
      described_class.attacks
      stamp = File.mtime(@file)
      File.write(@file, "attacks:\n  - name: rewritten\n    patterns: ['You jab (?<target>.+?)!']\n")
      File.utime(stamp, stamp, @file)
      expect(described_class.attacks.map(&:name)).to eq([:first])

      described_class.reset!
      expect(described_class.attacks.map(&:name)).to eq([:rewritten])
    end
  end

  describe 'the shipped example file' do
    it 'loads with no rejections and exercises every kind' do
      described_class.path = File.join(LIB_DIR, 'gemstone', 'combat', 'defs', 'supplements.example.yaml')
      summary = described_class.summary
      expect(summary.values).to all(be > 0)
      expect(messages).not_to include('skipped')
      expect(messages).not_to include('ignored')
    end
  end
end
