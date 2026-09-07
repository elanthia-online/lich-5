# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'tmpdir'
require 'gemstone/combat/recorder'

# End-to-end coverage for the SQLite Combat::Recorder: the wiring the PR
# shipped with zero first-party callers. These drive a real on-disk database
# (WAL, the shipped SCHEMA) through the public surface - session lifecycle,
# the :attack payload unpack, the status stream, attack-window attribution,
# idle auto-sessioning, transactional integrity, and the fixed cross-thread
# and record_status-atomicity concerns - and assert against the rows actually
# written, not mocks.
RSpec.describe Lich::Gemstone::Combat::Recorder do
  # NB: WAL mode keeps -wal/-shm sidecar files open, and on Windows an open
  # handle blocks unlink - so we can't use mktmpdir's strict block cleanup.
  # Make a unique dir, run, then best-effort remove (ignoring locks that the
  # GC hasn't released yet; the OS reclaims the temp dir regardless).
  before do
    # close calls unsubscribe! -> Observers.off; stub a no-op Observers so the
    # recorder's lifecycle runs without the full pub/sub module loaded.
    observers = Module.new do
      def self.on(*, **, &_blk); end
      def self.off(*); end
      def self.emit(*); end
    end
    stub_const('Lich::Gemstone::Combat::Observers', observers)

    @tmpdir = Dir.mktmpdir('combat-recorder')
    @db_path = File.join(@tmpdir, 'test.db')
  end

  after do
    GC.start
    FileUtils.remove_entry(@tmpdir)
  rescue StandardError
    # leftover WAL sidecar still locked on Windows - harmless, temp dir is
    # reclaimed by the OS; don't fail the example over cleanup.
  end

  # a fresh recorder + a plain sqlite handle for assertions
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

  def count(table)
    query("SELECT COUNT(*) AS n FROM #{table}").first['n']
  end

  # minimal but realistic :attack payload
  def attack_event(name: 'fire', target_id: 101, target_name: 'a cave lizard',
                   damage: 42, at: Time.at(1_000_000), **extra)
    {
      name: name, at: at,
      target: { id: target_id, name: target_name },
      hits: [{ damage: damage, crit: nil }],
      resolutions: [{ type: :ranged, as: 300, ds: 120, roll: 55, result: 235 }]
    }.merge(extra)
  end

  describe 'session lifecycle' do
    it 'opens, records into, and closes a session' do
      rec = new_recorder
      sid = rec.start_session(character: 'Tester', source: 'test', at: Time.at(1_000_000))
      expect(sid).to be_a(Integer)
      rec.record(:attack, attack_event)
      fin = rec.finish_session(at: Time.at(1_000_100))
      rec.close

      expect(fin).to eq(sid)
      s = query('SELECT * FROM sessions').first
      expect(s['character']).to eq('Tester')
      expect(s['started_at']).to eq(1_000_000.0)
      expect(s['ended_at']).to eq(1_000_100.0)
    end

    it 'starting a new session finishes the previous one' do
      rec = new_recorder
      s1 = rec.start_session(at: Time.at(10))
      s2 = rec.start_session(at: Time.at(20))
      rec.close
      expect(s2).not_to eq(s1)
      # s1 got an ended_at when s2 opened
      expect(query('SELECT ended_at FROM sessions WHERE id = ?', s1).first['ended_at']).not_to be_nil
    end

    it 'does not record when no session is open' do
      rec = new_recorder
      rec.record(:attack, attack_event) # no start_session, no idle_timeout
      rec.close
      expect(count('attacks')).to eq(0)
    end
  end

  describe 'idle auto-sessioning' do
    it 'opens a session lazily on the first event' do
      rec = new_recorder(idle_timeout: 300)
      rec.record(:attack, attack_event)
      expect(count('sessions')).to eq(1)
      expect(count('attacks')).to eq(1)
      rec.close
    end

    it 'closes the session after the idle gap, stamped at the last event time' do
      rec = new_recorder(idle_timeout: 300)
      # first event opens the session; stub Time so last_event_at is controlled
      allow(Time).to receive(:now).and_return(Time.at(2_000_000))
      rec.record(:attack, attack_event(at: Time.at(2_000_000)))
      # jump past the idle gap and fire check_idle!
      allow(Time).to receive(:now).and_return(Time.at(2_000_000 + 400))
      rec.check_idle!
      rec.close

      ended = query('SELECT ended_at FROM sessions').first['ended_at']
      # ended_at is the LAST EVENT time, not now - town time never pads a hunt
      expect(ended).to eq(2_000_000.0)
    end
  end

  describe 'record_attack (:attack payload unpack)' do
    it 'writes attack + resolution + hit rows and registers the creature' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))
      rec.record(:attack, attack_event(damage: 77))
      rec.close

      a = query('SELECT * FROM attacks').first
      expect(a['name']).to eq('fire')
      expect(a['target_kind']).to eq('creature')
      expect(count('resolutions')).to eq(1)
      h = query('SELECT * FROM hits').first
      expect(h['damage']).to eq(77)
      c = query('SELECT * FROM creatures').first
      expect(c['exist_id']).to eq(101)
    end

    it 'classifies inbound / foreign_target / foreign_caster / unowned' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))
      rec.record(:attack, attack_event(name: 'claw', target: nil, inbound: true))
      rec.record(:attack, attack_event(name: 'spell', target: nil, foreign_target: true))
      rec.record(:attack, attack_event(name: 'jab', foreign_caster: true))
      rec.record(:attack, attack_event(name: 'pestilence', unowned: true))
      rec.close

      rows = query('SELECT name, target_kind, inbound, foreign_caster, unowned FROM attacks ORDER BY seq')
      expect(rows[0].values_at('target_kind', 'inbound')).to eq(['self', 1])
      expect(rows[1]['target_kind']).to eq('foreign')
      expect(rows[2]['foreign_caster']).to eq(1)
      expect(rows[3]['unowned']).to eq(1)
    end

    it 'splits spawned-cast lineage into parent + parent_weapon' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))
      rec.record(:attack, attack_event(name: 'natures_fury',
                                       parent: { flare: :blink, weapon: { id: 5, name: 'glowbark bow' } }))
      rec.close
      a = query('SELECT parent, parent_weapon FROM attacks').first
      expect(a['parent']).to eq('blink')
      expect(a['parent_weapon']).to eq('glowbark bow')
    end

    it 'records flares with their own hits and creature attribution' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))
      ev = attack_event.merge(
        flares: [{ name: :glowbark, damaging: true,
                   target_info: { id: 101, name: 'a cave lizard' },
                   hits: [{ damage: 25, crit: nil }] }]
      )
      rec.record(:attack, ev)
      rec.close
      f = query('SELECT * FROM flares').first
      expect(f['name']).to eq('glowbark')
      expect(f['damaging']).to eq(1)
      # attack hit + flare hit
      expect(count('hits')).to eq(2)
    end
  end

  describe 'status stream + attack-window attribution' do
    it 'attributes a status to the open attack when it names a touched creature' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))
      rec.record(:attack, attack_event(target_id: 202, target_name: 'an orc'))
      rec.record(:status, { id: 202, name: 'an orc', status: :prone, action: :add })
      rec.close

      st = query('SELECT * FROM statuses').first
      expect(st['status']).to eq('prone')
      expect(st['source']).to eq('window') # inside the open attack's window
      expect(st['attack_id']).not_to be_nil
    end

    it 'marks a status with no matching open attack as direct' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))
      rec.record(:status, { id: 999, name: 'a stranger', status: :prone, action: :add })
      rec.close
      expect(query('SELECT source FROM statuses').first['source']).to eq('direct')
    end

    it 'stamps killed_at on a dead status and is transactional (creature+status atomic)' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))
      rec.record(:status, { id: 303, name: 'a doomed goblin', status: :dead, action: :add })
      rec.close
      c = query('SELECT killed_at FROM creatures WHERE exist_id = 303').first
      expect(c['killed_at']).not_to be_nil
      # the creature row and its status row are both present (atomic)
      expect(count('creatures')).to eq(1)
      expect(count('statuses')).to eq(1)
    end
  end

  describe 'crit-status gate decoupling (Major fix)' do
    # apply_crit_statuses lives in the processor, but the recorder is the
    # downstream consumer of the :stun/:roundtime emits those statuses produce.
    # Here we just assert the recorder faithfully persists them regardless of
    # origin - the processor-side gate fix is covered in processor specs.
    it 'persists stun and roundtime status emits with their numeric value' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))
      rec.record(:stun, { id: 404, name: 'a warg', rounds: 3 })
      rec.record(:roundtime, { id: 404, name: 'a warg', seconds: 5 })
      rec.close
      rows = query("SELECT kind, status, value FROM statuses ORDER BY id")
      expect(rows[0].values_at('kind', 'value')).to eq(['stun', 3])
      expect(rows[1].values_at('kind', 'value')).to eq(['roundtime', 5])
    end
  end

  describe 'fault isolation' do
    it 'never raises out of record even on a malformed payload' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))
      expect { rec.record(:attack, nil) }.not_to raise_error
      expect { rec.record(:bogus_type, {}) }.not_to raise_error
      rec.close
    end
  end

  describe 'thread safety (mutex-guarded surface)' do
    it 'serialises concurrent record and check_idle! without corrupting the db' do
      rec = new_recorder(idle_timeout: 300)
      allow(Time).to receive(:now).and_return(Time.at(3_000_000))
      rec.record(:attack, attack_event(at: Time.at(3_000_000)))

      # hammer record from several threads while a checker thread races close-y
      # operations; the mutex must keep every write on a live handle.
      writers = 4.times.map do |t|
        Thread.new do
          10.times { |i| rec.record(:attack, attack_event(target_id: 500 + t, damage: i + 1)) }
        end
      end
      checker = Thread.new { 10.times { rec.check_idle! } }
      (writers + [checker]).each(&:join)
      rec.close

      # 1 opener + 40 writer attacks, all persisted, db intact
      expect(count('attacks')).to eq(41)
      expect(query('PRAGMA integrity_check').first.values.first).to eq('ok')
    end
  end
end
