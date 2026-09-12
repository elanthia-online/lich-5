# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/parser'
require 'gemstone/combat/processor'
require 'gemstone/combat/recorder'
require 'tmpdir'
require 'fileutils'

# Parser -> recorder: the delayed-death fallback must credit the attack that
# dealt the LAST damage in COMBAT order. Insertion order is not that: a
# Holy Weapon release re-emits the released cast AFTER the swing it belongs
# to (so the recorder's parent-first lineage resolves), and a pummel opens
# before its released spell but lands its own damage after it. Only the
# damage line's feed position (hits.line_seq) says which hit was last.
RSpec.describe 'Recorder kill credit follows combat order' do
  processor = Lich::Gemstone::Combat::Processor
  troll = '<pushBold/>a <a exist="212657781" noun="troll">bog troll</a><popBold/>'
  mace  = '<a exist="212333157" noun="mace">mithril mace</a>'

  before do
    stub_const('Lich::Gemstone::Combat::Tracker', Module.new)
    allow(Lich::Gemstone::Combat::Tracker).to receive(:settings).and_return(
      emit_attacks: true, track_statuses: true, track_ucs: true, track_wounds: true
    )
    allow(Lich::Gemstone::Combat::Tracker).to receive(:debug?).and_return(false)
    observers = Module.new do
      def self.on(*, **, &_blk); end
      def self.off(*); end
      def self.emit(*); end
    end
    stub_const('Lich::Gemstone::Combat::Observers', observers)
    allow(processor).to receive(:apply_status_to_target)
    allow(processor).to receive(:apply_ucs_to_target)
    processor.instance_variable_set(:@active_assault, nil)
    @tmpdir = Dir.mktmpdir('combat-order')
    @db_path = File.join(@tmpdir, 'test.db')
  end

  after do
    GC.start
    FileUtils.remove_entry(@tmpdir)
  rescue StandardError
    # leftover WAL sidecar still locked on Windows - harmless
  end

  def query(sql, *params)
    db = SQLite3::Database.new(@db_path)
    db.results_as_hash = true
    db.execute(sql, params)
  ensure
    db&.close
  end

  # What Processor.process does after parse_events: resolve the object refs
  # into per-chunk uids the recorder maps to rows, and stamp the chunk time.
  def stamp(events, at:)
    uids = {}.compare_by_identity
    events.each_with_index { |ev, i| uids[ev] = i }
    events.each_with_index do |ev, i|
      ev[:_uid] = i
      ev[:root_uid] = ev[:root_ref] ? (uids[ev[:root_ref]] || i) : i
      ev[:parent_uid] = ev[:parent_ref] ? uids[ev[:parent_ref]] : nil
      ev[:at] = at
    end
    events
  end

  def record_chunk(rec, lines, at:)
    events = stamp(Lich::Gemstone::Combat::Processor.parse_events(lines), at: at)
    events.each { |ev| rec.record(:attack, ev) }
    events
  end

  let(:verdict) do
    [
      "Violet flames erupt from beneath #{troll}.",
      '  CS: +149 - TD: +120 + CvA: +17 + d100: +85 == +131',
      '  Warding failed!',
      "A column of seething violet flame envelops #{troll} in its searing embrace!",
      '   ... 20 points of damage!'
    ]
  end
  let(:release) { "As you attempt to strike with your #{mace}, it sends a surge of power through you that quickly leaps out at #{troll}!" }
  let(:swing_roll) { ['  AS: +273 vs DS: +80 with AvD: +35 + d100 roll: +2 = +230', '   ... and hit for 79 points of damage!'] }
  let(:prompt) { ['<prompt time="1">&gt;</prompt>'] }

  it 'credits the swing when the released spell landed first (release -> Verdict -> swing)' do
    rec = Lich::Gemstone::Combat::Recorder.new(@db_path, character: 'Tester', source: 'test', idle_timeout: 60)
    chunk = [release] + verdict + ["You swing a perfect #{mace} at #{troll}!"] + swing_roll + prompt
    events = record_chunk(rec, chunk, at: Time.at(1_000_000))
    expect(events.map { |e| e[:name] }).to eq(%i[attack templars_verdict]) # cast re-emitted AFTER its swing
    rec.finish_session(at: Time.at(1_000_100))
    rec.record(:status, id: 212_657_781, name: 'bog troll', status: 'dead', action: 'add')
    rec.close

    swing = query("SELECT id FROM attacks WHERE name = 'attack'").first['id']
    row = query('SELECT killed_by_attack_id, kill_credit FROM creatures').first
    expect(row['killed_by_attack_id']).to eq(swing)
    expect(row['kill_credit']).to eq('last_own_hit')
  end

  it 'credits the pummel when its own damage lands after the spell it released (pummel -> release -> Verdict -> AS/DS)' do
    rec = Lich::Gemstone::Combat::Recorder.new(@db_path, character: 'Tester', source: 'test', idle_timeout: 60)
    chunk = [
      "You take a menacing step toward #{troll}, sweeping your #{mace} out low to your side in your advance.",
      '[SMR result: 165 (Open d100: 43, Bonus: 65)]',
      "With deliberate brutality, you bring your #{mace} around to pummel #{troll}!",
      release
    ] + verdict + swing_roll + prompt
    events = record_chunk(rec, chunk, at: Time.at(1_000_000))
    expect(events.map { |e| e[:name] }).to eq(%i[pummel templars_verdict])
    rec.finish_session(at: Time.at(1_000_100))
    rec.record(:status, id: 212_657_781, name: 'bog troll', status: 'dead', action: 'add')
    rec.close

    pummel = query("SELECT id FROM attacks WHERE name = 'pummel'").first['id']
    row = query('SELECT killed_by_attack_id, kill_credit FROM creatures').first
    expect(row['killed_by_attack_id']).to eq(pummel)
    expect(row['kill_credit']).to eq('last_own_hit')
  end

  it 'orders two chunks that share a whole-second timestamp by chunk, not by line position' do
    rec = Lich::Gemstone::Combat::Recorder.new(@db_path, character: 'Tester', source: 'test', idle_timeout: 60)
    same_second = Time.at(1_000_000)
    lizard = { id: 101, name: 'a cave lizard', noun: nil }
    # earlier chunk: our damage late in the chunk (line 30)
    rec.record(:attack, { name: 'mine', at: same_second, target: lizard, _uid: 0,
                          hits: [{ damage: 40, crit: nil, line: 30 }], resolutions: [] })
    # later chunk, same prompt second: a nearby player's damage early in it (line 2)
    rec.record(:attack, { name: 'theirs', at: same_second, target: lizard, _uid: 0, foreign_caster: true,
                          hits: [{ damage: 5, crit: nil, line: 2 }], resolutions: [] })
    rec.finish_session(at: same_second + 100)
    rec.record(:status, id: 101, name: 'a cave lizard', status: 'dead', action: 'add')
    rec.close

    theirs = query("SELECT id, chunk_seq FROM attacks WHERE name = 'theirs'").first
    mine   = query("SELECT chunk_seq FROM attacks WHERE name = 'mine'").first
    expect(theirs['chunk_seq']).to be > mine['chunk_seq']
    row = query('SELECT killed_by_attack_id, kill_credit FROM creatures').first
    expect(row['killed_by_attack_id']).to eq(theirs['id'])
    expect(row['kill_credit']).to eq('last_hit')
  end

  it 'records the feed position of every hit' do
    rec = Lich::Gemstone::Combat::Recorder.new(@db_path, character: 'Tester', source: 'test', idle_timeout: 60)
    chunk = [release] + verdict + ["You swing a perfect #{mace} at #{troll}!"] + swing_roll + prompt
    record_chunk(rec, chunk, at: Time.at(1_000_000))
    rec.close
    rows = query('SELECT a.name, h.damage, h.line_seq FROM hits h JOIN attacks a ON a.id = h.attack_id ORDER BY h.line_seq')
    expect(rows.map { |r| [r['name'], r['damage']] }).to eq([['templars_verdict', 20], ['attack', 79]])
    expect(rows.map { |r| r['line_seq'] }).to all(be_a(Integer))
  end
end
