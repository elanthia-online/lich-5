# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/recorder'
require 'tmpdir'
require 'fileutils'

# The recorder as the single place that decides what a reader used to
# re-derive: session end (a hook), ownership (attacks.ours / flares.ours),
# kill credit when the death lands outside an attack window, the stun pair
# merged to one row, and 'unbound' for a flare-spawned child whose spawner
# row could not be asserted. Plus the two hit indexes.
RSpec.describe Lich::Gemstone::Combat::Recorder do
  before do
    observers = Module.new do
      def self.on(*, **, &_blk); end
      def self.off(*); end
      def self.emit(*); end
    end
    stub_const('Lich::Gemstone::Combat::Observers', observers)
    @tmpdir = Dir.mktmpdir('combat-recorder-schema')
    @db_path = File.join(@tmpdir, 'test.db')
  end

  after do
    GC.start
    FileUtils.remove_entry(@tmpdir)
  rescue StandardError
    # leftover WAL sidecar still locked on Windows - harmless
  end

  def new_recorder(**opts)
    described_class.new(@db_path, character: 'Tester', source: 'test', **opts)
  end

  def query(sql, *params)
    db = SQLite3::Database.new(@db_path)
    db.results_as_hash = true
    db.execute(sql, params)
  ensure
    db&.close
  end

  def attack_event(name: 'fire', target_id: 101, target_name: 'a cave lizard', damage: 42,
                   at: Time.at(1_000_000), **extra)
    {
      name: name, at: at,
      target: { id: target_id, name: target_name, noun: nil },
      hits: [{ damage: damage, crit: nil }],
      resolutions: [{ type: :ranged, as: 300, ds: 120, roll: 55, result: 235 }]
    }.merge(extra)
  end

  describe 'session-finished hook' do
    it 'fires from finish_session, from the idle poll, and from close, and is drainable' do
      rec = new_recorder(idle_timeout: 60)
      seen = []
      rec.on_session_finished { |id| seen << id }

      rec.record(:attack, attack_event)                        # opens session 1 lazily
      first = rec.finish_session(at: Time.at(1_000_100))
      expect(seen).to eq([first])

      rec.record(:attack, attack_event)                        # session 2
      expect(rec.check_idle!(Time.now + 3600)).to eq(first + 1) # idle poll closes it
      expect(seen).to eq([first, first + 1])

      rec.record(:attack, attack_event)                        # session 3
      rec.close                                                # close path
      expect(seen).to eq([first, first + 1, first + 2])
      expect(rec.drain_finished_sessions).to eq([first, first + 1, first + 2])
      expect(rec.drain_finished_sessions).to eq([])
    end

    it "fires when the NEXT event's own idle check closes the previous session" do
      rec = new_recorder(idle_timeout: 0.05)
      seen = []
      rec.on_session_finished { |id| seen << id }
      rec.record(:attack, attack_event)
      sleep 0.1
      rec.record(:attack, attack_event) # record's own check_idle_locked! closes session 1 first
      expect(seen.size).to eq(1)
      expect(query('SELECT COUNT(*) AS n FROM sessions').first['n']).to eq(2)
      rec.close
    end
  end

  describe 'ownership decided at write time' do
    it 'stamps attacks.ours from the event flags, orphans and foreign targets included' do
      rec = new_recorder
      rec.start_session(character: 'Tester', source: 'test', at: Time.at(1_000_000))
      rec.record(:attack, attack_event(name: 'own'))
      rec.record(:attack, attack_event(name: 'claw', target: nil, inbound: true))
      rec.record(:attack, attack_event(name: 'cast', foreign_caster: true))
      rec.record(:attack, attack_event(name: 'spell', target: nil, foreign_target: true))
      rec.record(:attack, attack_event(name: 'bleed', unowned: true))
      rec.record(:attack, attack_event(name: 'unknown', target: {}, _orphan: true))
      rec.close
      rows = query('SELECT name, ours FROM attacks ORDER BY id').to_h { |r| [r['name'], r['ours']] }
      expect(rows).to eq('own' => 1, 'claw' => 0, 'cast' => 0, 'spell' => 0, 'bleed' => 0, 'unknown' => 0)
    end

    it 'stamps flares.ours: 2p flares are ours even on an inbound row, 3p flares are not' do
      rec = new_recorder
      rec.start_session(character: 'Tester', source: 'test', at: Time.at(1_000_000))
      mine   = { name: :fire, damaging: true, hits: [{ damage: 5, crit: nil }] }
      theirs = { name: :acid, damaging: true, attacker: 'a cave lizard', hits: [{ damage: 5, crit: nil }] }
      rec.record(:attack, attack_event(name: 'own', flares: [mine, theirs]))
      rec.record(:attack, attack_event(name: 'claw', target: nil, inbound: true,
                                       attacker: { id: 101, name: 'a cave lizard' },
                                       flares: [mine.merge(name: :shield_spike), theirs]))
      rec.close
      rows = query('SELECT a.name AS atk, f.name AS flare, f.ours FROM flares f JOIN attacks a ON a.id = f.attack_id ORDER BY f.id')
      expect(rows.map { |r| [r['atk'], r['flare'], r['ours']] }).to eq([
        ['own', 'fire', 1], ['own', 'acid', 0],
        ['claw', 'shield_spike', 1], ['claw', 'acid', 0]
      ])
    end
  end

  describe 'indexes' do
    it 'indexes hits by creature alone and by flare' do
      rec = new_recorder
      rec.close
      names = query("SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'hits'").map { |r| r['name'] }
      expect(names).to include('idx_hits_creature_only', 'idx_hits_flare')
    end
  end

  describe 'kill credit' do
    it "is 'window' when the room-feed death lands inside the attack window" do
      rec = new_recorder
      rec.start_session(character: 'Tester', source: 'test', at: Time.at(1_000_000))
      rec.record(:attack, attack_event)
      rec.record(:status, id: 101, name: 'a cave lizard', status: 'dead', action: 'add')
      rec.close
      row = query('SELECT killed_by_attack_id, kill_credit FROM creatures').first
      expect(row['killed_by_attack_id']).to eq(1)
      expect(row['kill_credit']).to eq('window')
    end

    it "falls back to our last damaging attack and says 'last_own_hit' when there is no window" do
      rec = new_recorder(idle_timeout: 60)
      rec.record(:attack, attack_event(name: 'theirs', foreign_caster: true, damage: 500))
      rec.record(:attack, attack_event(name: 'mine', damage: 40))
      rec.finish_session(at: Time.at(1_000_100)) # clears the attack window
      rec.record(:status, id: 101, name: 'a cave lizard', status: 'dead', action: 'add') # trailing death
      rec.close
      row = query('SELECT killed_by_attack_id, kill_credit FROM creatures').first
      mine = query("SELECT id FROM attacks WHERE name = 'mine'").first['id']
      expect(row['killed_by_attack_id']).to eq(mine)
      expect(row['kill_credit']).to eq('last_own_hit')
    end
  end

  describe 'stun pair' do
    it 'merges the crit-table stun and the messaging status into one row, either order' do
      rec = new_recorder
      rec.start_session(character: 'Tester', source: 'test', at: Time.at(1_000_000))
      rec.record(:attack, attack_event)
      rec.record(:status, id: 101, name: 'a cave lizard', status: 'stunned', action: 'add')
      rec.record(:stun, id: 101, name: 'a cave lizard', rounds: 3)
      rec.record(:attack, attack_event(target_id: 102, target_name: 'a rolton'))
      rec.record(:stun, id: 102, name: 'a rolton', rounds: 2)
      rec.record(:status, id: 102, name: 'a rolton', status: 'stunned', action: 'add')
      rec.close
      rows = query("SELECT c.exist_id AS who, s.kind, s.value FROM statuses s JOIN creatures c ON c.id = s.creature_id WHERE s.status = 'stunned' ORDER BY s.id")
      expect(rows.map { |r| [r['who'], r['kind'], r['value']] }).to eq([[101, 'stun', 3], [102, 'stun', 2]])
    end
  end

  describe 'unbound children' do
    it "marks a flare-spawned child with no asserted parent row as parent_confidence 'unbound'" do
      rec = new_recorder
      rec.start_session(character: 'Tester', source: 'test', at: Time.at(1_000_000))
      rec.record(:attack, attack_event(name: 'fire'))
      rec.record(:attack, attack_event(name: 'fire', parent: { flare: :mirror_image, weapon: nil }))
      rec.close
      rows = query('SELECT parent, parent_attack_id, parent_confidence FROM attacks ORDER BY id')
      expect(rows[0].values_at('parent', 'parent_confidence')).to eq([nil, nil])
      expect(rows[1].values_at('parent', 'parent_attack_id', 'parent_confidence')).to eq(['mirror_image', nil, 'unbound'])
    end
  end
end
