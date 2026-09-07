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
                   target_noun: nil, damage: 42, at: Time.at(1_000_000), **extra)
    {
      name: name, at: at,
      target: { id: target_id, name: target_name, noun: target_noun },
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

    it 'stores crit rank and wound rank in their own columns (not conflated)' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))
      # a real CritRanks-shaped crit: :rank (crit severity) != :wound_rank
      ev = attack_event(damage: 88).merge(
        hits: [{ damage: 88, crit: { location: 'left eye', type: 'slash',
                                     rank: 9, wound_rank: 3, fatal: false } }]
      )
      rec.record(:attack, ev)
      rec.close
      h = query('SELECT crit_rank, wound_rank, location, crit_type FROM hits').first
      expect(h['crit_rank']).to eq(9)    # crit severity - was wrongly storing wound_rank (3)
      expect(h['wound_rank']).to eq(3)   # wound left on the creature
      expect(h['location']).to eq('left eye')
      expect(h['crit_type']).to eq('slash')
    end
  end

  describe 'spawn-tree links (root_attack_id / parent_attack_id)' do
    # The processor stamps per-chunk _uid + root_uid/parent_uid; the recorder
    # resolves them to row ids. A chunk resets on _uid == 0.
    it 'points a lone root attack at itself with no parent' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))
      rec.record(:attack, attack_event(_uid: 0, root_uid: 0, parent_uid: nil))
      rec.close
      a = query('SELECT id, root_attack_id, parent_attack_id, parent_confidence FROM attacks').first
      expect(a['root_attack_id']).to eq(a['id']) # self-root
      expect(a['parent_attack_id']).to be_nil
      expect(a['parent_confidence']).to be_nil
    end

    it 'resolves a blink child to the root row id it shares a chunk with' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))
      # root (uid 0) then blink child (uid 1, parent/root -> uid 0), same chunk
      rec.record(:attack, attack_event(name: 'fire', _uid: 0, root_uid: 0, parent_uid: nil))
      rec.record(:attack, attack_event(name: 'natures_fury', _uid: 1, root_uid: 0,
                                       parent_uid: 0, parent_confidence: :bracket))
      rec.close
      rows = query('SELECT id, name, root_attack_id, parent_attack_id, parent_confidence FROM attacks ORDER BY id')
      root, child = rows
      expect(root['root_attack_id']).to eq(root['id'])
      expect(child['root_attack_id']).to eq(root['id'])       # shares the root
      expect(child['parent_attack_id']).to eq(root['id'])     # declared parent
      expect(child['parent_confidence']).to eq('bracket')
    end

    it 'resets the uid map on a new chunk so uids never cross-link' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))
      # chunk A: root(0) + child(1)
      rec.record(:attack, attack_event(name: 'fire', _uid: 0, root_uid: 0))
      rec.record(:attack, attack_event(name: 'natures_fury', _uid: 1, root_uid: 0,
                                       parent_uid: 0, parent_confidence: :bracket))
      # chunk B: a fresh root reusing uid 0 must NOT link to chunk A's row
      rec.record(:attack, attack_event(name: 'jab', _uid: 0, root_uid: 0))
      rec.close
      rows = query('SELECT id, name, root_attack_id, parent_attack_id FROM attacks ORDER BY id')
      chunk_b = rows.last
      expect(chunk_b['name']).to eq('jab')
      expect(chunk_b['root_attack_id']).to eq(chunk_b['id']) # its own root, not chunk A's
      expect(chunk_b['parent_attack_id']).to be_nil
    end

    it 'leaves an ambiguous echo (no parent_uid) rooted but parentless' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))
      rec.record(:attack, attack_event(name: 'fire', _uid: 0, root_uid: 0))
      # a mirror/afterimage echo: shares nothing asserted - own root, no parent
      rec.record(:attack, attack_event(name: 'fire', _uid: 1, root_uid: 1, parent_uid: nil))
      rec.close
      echo = query('SELECT id, root_attack_id, parent_attack_id, parent_confidence FROM attacks ORDER BY id').last
      expect(echo['root_attack_id']).to eq(echo['id']) # own root (not guessed onto the first)
      expect(echo['parent_attack_id']).to be_nil
      expect(echo['parent_confidence']).to be_nil
    end
  end

  describe 'guardian redirect (redirected_from)' do
    it 'stores the intended victim noun; the row itself belongs to the guardian' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))
      rec.record(:attack, attack_event(name: 'fire', target_id: 1002, target_name: 'a brawny gigas shield-maiden',
                                       redirect: { interceptor: { id: 1002, name: 'a brawny gigas shield-maiden' },
                                                   intended: 'mastodon' }))
      rec.record(:attack, attack_event(name: 'fire'))
      # announced but not honored (UAC shape): the row already names the
      # creature that took the hit, so nothing is redirected
      rec.record(:attack, attack_event(name: 'uac', target_id: 1003, target_name: 'a grim gigas skald',
                                       redirect: { interceptor: { id: 1002 }, intended: 'skald', honored: false }))
      rec.close

      rows = query('SELECT redirected_from, creature_id FROM attacks ORDER BY seq')
      expect(rows[0]['redirected_from']).to eq('mastodon')
      expect(rows[0]['creature_id']).not_to be_nil
      expect(rows[1]['redirected_from']).to be_nil
      expect(rows[2]['redirected_from']).to be_nil
    end

    it 'adds the column to a database created before it existed' do
      legacy = SQLite3::Database.new(@db_path)
      # drop the column (and the comma that now precedes it) from the DDL
      pre = described_class::SCHEMA.gsub(/,([^\n]*\n)\s*redirected_from TEXT[^\n]*/, '\1')
      expect(pre).not_to include('redirected_from')
      legacy.execute_batch(pre)
      cols = legacy.execute('PRAGMA table_info(attacks)').map { |r| r[1] }
      legacy.close
      expect(cols).not_to include('redirected_from')

      rec = new_recorder
      rec.close
      expect(query('PRAGMA table_info(attacks)').map { |r| r['name'] }).to include('redirected_from')
    end
  end

  describe 'creature-cache rollback safety' do
    # Re-review finding (PR #1559): ensure_creature cached a creature id inside
    # a transaction; if that transaction rolled back, the DB row was undone but
    # the cache entry survived, so a later record referenced a nonexistent
    # creature row. in_txn now stages cache entries and publishes only on
    # commit.
    it 'does not cache a creature whose insert transaction rolled back' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))

      # Force the FIRST status insert for a brand-new creature to fail AFTER
      # ensure_creature has staged the id. The transaction rolls back.
      db = rec.instance_variable_get(:@db)
      call = 0
      allow(db).to receive(:execute).and_wrap_original do |orig, sql, *args|
        # let the creature upsert run, then blow up on the status insert
        if sql =~ /INSERT INTO statuses/ && (call += 1) == 1
          raise SQLite3::Exception, 'injected failure'
        end

        orig.call(sql, *args)
      end
      rec.record(:status, { id: 909, name: 'a doomed goblin', status: :prone, action: :add })
      # record swallows the error; nothing persisted
      expect(count('creatures')).to eq(0)
      expect(count('statuses')).to eq(0)

      # stop injecting, record a real attack against the SAME creature id
      allow(db).to receive(:execute).and_call_original
      rec.record(:attack, attack_event(target_id: 909, target_name: 'a doomed goblin', damage: 30))
      rec.close

      # the hit must reference a creature row that actually exists (no dangling FK)
      cid = query('SELECT creature_id FROM hits').first['creature_id']
      expect(cid).not_to be_nil
      expect(query('SELECT COUNT(*) AS n FROM creatures WHERE id = ?', cid).first['n']).to eq(1)
      # and it's the goblin, freshly (re)created
      expect(query('SELECT exist_id FROM creatures WHERE id = ?', cid).first['exist_id']).to eq(909)
    end

    it 'stages spawn-tree chunk-row links until commit (rolled-back parent not reused)' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))

      # chunk uid 0 (the root/parent) is recorded, but force ITS hit insert to
      # fail so the whole attack rolls back - its @chunk_rows[0] must not survive.
      db = rec.instance_variable_get(:@db)
      allow(db).to receive(:execute).and_wrap_original do |orig, sql, *args|
        raise SQLite3::Exception, 'injected' if sql =~ /INSERT INTO hits/

        orig.call(sql, *args)
      end
      rec.record(:attack, attack_event(name: 'fire', _uid: 0, root_uid: 0))
      expect(count('attacks')).to eq(0) # rolled back

      # now a child (uid 1) claims uid 0 as its bracket parent. Since uid 0's
      # row was rolled back and never published, the child must NOT resolve a
      # (stale) parent - it falls back to being its own root, parent null.
      allow(db).to receive(:execute).and_call_original
      rec.record(:attack, attack_event(name: 'natures_fury', _uid: 1, root_uid: 0,
                                       parent_uid: 0, parent_confidence: :bracket))
      rec.close

      child = query('SELECT id, root_attack_id, parent_attack_id FROM attacks').first
      expect(child).not_to be_nil
      expect(child['parent_attack_id']).to be_nil          # no stale rolled-back parent
      expect(child['root_attack_id']).to eq(child['id'])   # own root
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

    it 'backfills a status-first creature\'s noun when a later attack supplies it' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))
      # status event carries only id + name (no noun) -> creature inserted with
      # noun NULL
      rec.record(:status, { id: 404, name: 'a cave troll', status: :prone, action: :add })
      expect(query('SELECT noun FROM creatures WHERE exist_id = 404').first['noun']).to be_nil
      # the later attack names the noun -> it must be filled, not left NULL
      rec.record(:attack, attack_event(target_id: 404, target_name: 'a cave troll',
                                       target_noun: 'troll'))
      rec.close
      expect(query('SELECT noun FROM creatures WHERE exist_id = 404').first['noun']).to eq('troll')
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

  describe 'ucs status emits' do
    it 'persists positioning tiers as their ordinal, not nil' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))
      rec.record(:ucs, { id: 404, name: 'a warg', kind: :position, value: 'good', tier: 2 })
      rec.record(:ucs, { id: 404, name: 'a warg', kind: :position_inbound, value: 'excellent', tier: 3 })
      rec.record(:ucs, { id: 404, name: 'a warg', kind: :tierup, value: 'jab', tier: nil })
      rec.close
      rows = query("SELECT status, value FROM statuses ORDER BY id")
      expect(rows.map { |r| r.values_at('status', 'value') })
        .to eq([['position', 2], ['position_inbound', 3], ['tierup', nil]])
    end
  end

  describe 'text columns from binary game-stream strings' do
    it 'stores nouns and names as TEXT, not BLOB, so text predicates match' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))
      # the game stream hands the parser ASCII-8BIT strings
      rec.record(:attack, attack_event(target_name: 'a cave lizard'.b, target_noun: 'lizard'.b))
      rec.close

      types = query('SELECT typeof(noun) AS tn, typeof(name) AS tm FROM creatures').first
      expect(types.values_at('tn', 'tm')).to eq(%w[text text])
      expect(query("SELECT COUNT(*) AS n FROM creatures WHERE noun = 'lizard'").first['n']).to eq(1)
    end
  end

  describe 'room-feed death (dead status without a fatal crit)' do
    it 'stamps killed_at and credits the attack whose window the death fell in' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))
      rec.record(:attack, attack_event(target_id: 101, damage: 120)) # non-fatal hit
      rec.record(:status, { id: 101, name: 'a cave lizard', status: 'dead', action: :add })
      rec.close

      c = query('SELECT killed_at, killed_by_attack_id FROM creatures WHERE exist_id = 101').first
      a = query('SELECT id FROM attacks').first
      expect(c['killed_at']).not_to be_nil
      expect(c['killed_by_attack_id']).to eq(a['id'])
    end

    it 'lets a fatal crit take the credit from an earlier room-feed stamp' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))
      rec.record(:attack, attack_event(target_id: 101, damage: 120)) # the shot before
      rec.record(:status, { id: 101, name: 'a cave lizard', status: 'dead', action: :add }) # lagged feed
      rec.record(:attack, attack_event(target_id: 101).merge(hits: [{ damage: 50, crit: { fatal: true, location: 'neck', rank: 9 } }]))
      rec.close

      fatal_id = query('SELECT MAX(id) AS id FROM attacks').first['id']
      expect(query('SELECT killed_by_attack_id FROM creatures WHERE exist_id = 101').first['killed_by_attack_id']).to eq(fatal_id)
    end

    it 'does not overwrite a fatal-crit kill credit' do
      rec = new_recorder
      rec.start_session(at: Time.at(1))
      rec.record(:attack, attack_event(target_id: 101).merge(hits: [{ damage: 50, crit: { fatal: true, location: 'neck', rank: 9 } }]))
      fatal_id = query('SELECT id FROM attacks').first['id']
      rec.record(:attack, attack_event(target_id: 101, damage: 5)) # a stray later hit
      rec.record(:status, { id: 101, name: 'a cave lizard', status: 'dead', action: :add })
      rec.close

      c = query('SELECT killed_by_attack_id FROM creatures WHERE exist_id = 101').first
      expect(c['killed_by_attack_id']).to eq(fatal_id)
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
