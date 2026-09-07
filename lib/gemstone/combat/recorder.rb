# frozen_string_literal: true

#
# Combat Recorder - persists the observer event stream to SQLite.
#
# Seven-table relational schema (2026-09-05 design).
#
#   sessions     - one per hunt / replayed log. The recount unit.
#   creatures    - subject registry: (session_id, exist_id) unique.
#   attacks      - one row per :attack observer emission (swing, cast,
#                  inbound, orphan). The ordered list a forensic view
#                  walks and a recount groups over. Attribution flags
#                  (inbound / foreign_caster / unowned / orphan) keep a
#                  nearby player's attacks and actor-less effect ticks off
#                  our own damage rollup. Spawn-tree links (root_attack_id
#                  / parent_attack_id / parent_confidence) chain a blob's
#                  spawned attacks back to their initiating shot - see the
#                  spawn-tree note below.
#   resolutions  - roll lines, one row each, attack- or flare-owned.
#                  AS/DS/CS/TD are PRINTED values stored verbatim
#                  (attacker_stat/defender_stat/modifier per type);
#                  d100 kept separate so (result - roll) is the
#                  deterministic margin -> hit-chance / "use a setup
#                  first" tactics.
#   flares       - one row per flare on an attack; hits/resolutions
#                  reference their flare so flare analytics (crit-rank
#                  distribution, "does the flare hit where the attack
#                  hit?") are plain joins.
#   hits         - the workhorse: one row per damage fact, with its
#                  crit (location, rank, type, fatal, amputated,
#                  secondary wound) denormalized onto the row and
#                  session/creature denormalized for join-free
#                  aggregation.
#   statuses     - status add/remove stream (creature, self, ambient),
#                  spell losses and UCS facts, attack-attributed when
#                  the emission falls inside that attack's window.
#
# Sources of truth (no double counting):
#   - attacks/resolutions/flares/hits unpack the :attack payload only.
#     The per-fact :damage/:wound/:fatal_crit/:amputation emits are
#     derived from that same payload and are deliberately NOT
#     subscribed.
#   - statuses come from the :status/:stun/:roundtime/:spell_loss/:ucs
#     emits only - event[:statuses] and crit statuses re-emit through
#     :status during persist_event, so unpacking them from the payload
#     as well would duplicate rows.
#
# Attack attribution of statuses is a window heuristic: persist_event
# emits :attack first, then that event's facts, synchronously on one
# worker thread - so a status emission naming a creature the open
# attack touched is attributed to it. Parse-time ambient statuses from
# the NEXT chunk can land in a stale window only when they name the
# same creature; accepted and marked via source='window'.
#
# Spawn tree (2026-09-07): the whole attack - the initiating shot, its
# flares, any spawned echo attacks and their own flares - resolves inside
# one prompt-bounded blob before roundtime, so a blob is a closed spawn
# tree with a single root. root_attack_id points every event at that
# initiating shot (self for a root), giving correct per-shot spawn-tree
# damage totals. parent_attack_id/parent_confidence record the immediate
# spawner ONLY when the game declares it (blink's bracketed cast,
# confidence 'bracket'); mirror/afterimage echoes are left unparented
# rather than guessed (positional order does not prove parentage).
#
# Thread safety: record fires on the AsyncProcessor worker thread while
# check_idle!/close run on the consuming script's own loop - both touch
# @db, so every public entry point serialises on one non-reentrant mutex,
# with _locked internal variants for calls made while the lock is held.
#
# Usage (live, auto-sessioned - see scripts/combat_stats.lic):
#   rec = Combat::Recorder.new(path, character: Char.name, idle_timeout: 300)
#   rec.subscribe!            # named handler, idempotent
#   ...                       # sessions open on the first event and close
#   rec.check_idle!           # after idle_timeout seconds without one
#   rec.close                 # (call check_idle! periodically from a loop)
#
# Usage (explicit sessions - a headless replay driver):
#   rec = Combat::Recorder.new(path)
#   rec.start_session(character: 'Nisugi', source: log_path, at: t0)
#   ... feed events ...
#   rec.finish_session(at: t1)
#
# Session semantics (owner ruling 2026-09-05): a hunt is bounded by a
# 5-minute gap without combat events, inbound or outbound. With
# idle_timeout set, the recorder opens a session lazily on the first
# event and closes it AT THE LAST EVENT's time once the gap elapses -
# town time never pads a hunt's duration.

require 'sqlite3'

module Lich
  module Gemstone
    module Combat
      class Recorder
        HANDLER_NAME = 'combat_recorder'

        SCHEMA = <<~SQL
          CREATE TABLE IF NOT EXISTS sessions (
            id          INTEGER PRIMARY KEY,
            character   TEXT,
            source      TEXT,
            started_at  REAL NOT NULL,
            ended_at    REAL
          );

          CREATE TABLE IF NOT EXISTS creatures (
            id          INTEGER PRIMARY KEY,
            session_id  INTEGER NOT NULL REFERENCES sessions(id),
            exist_id    INTEGER,
            noun        TEXT,
            name        TEXT,
            first_seen  REAL,
            last_seen   REAL,
            killed_at   REAL,
            killed_by_attack_id INTEGER,
            UNIQUE (session_id, exist_id)
          );

          CREATE TABLE IF NOT EXISTS attacks (
            id          INTEGER PRIMARY KEY,
            session_id  INTEGER NOT NULL REFERENCES sessions(id),
            seq         INTEGER NOT NULL,             -- monotonic within session
            occurred_at REAL NOT NULL,
            name        TEXT NOT NULL,                -- def name (:unknown = orphan sink)
            parent      TEXT,                         -- spawned-cast lineage (flare name)
            parent_weapon TEXT,                       -- the weapon whose flare spawned it
            root_attack_id   INTEGER REFERENCES attacks(id), -- initiating shot of this blob's spawn tree (self for a root)
            parent_attack_id INTEGER REFERENCES attacks(id), -- immediate spawner, ONLY when asserted (blink bracket); NULL when ambiguous
            parent_confidence TEXT,                   -- 'bracket' (game-declared) | NULL (unproven); reserved: 'count'
            via         TEXT,                         -- gesture wrapper (:cast)
            creature_id INTEGER REFERENCES creatures(id),  -- NULL: inbound/self/foreign/orphan
            target_kind TEXT NOT NULL,                -- creature|self|foreign|none
            attacker    TEXT,                         -- inbound: who attacked us
            attacker_exist_id INTEGER,
            weapon      TEXT,
            outcome     TEXT,                         -- first outcome (miss/evade/warded/...)
            outcomes_all TEXT,                        -- comma-joined when >1
            aimed       INTEGER NOT NULL DEFAULT 0,
            ambush      INTEGER NOT NULL DEFAULT 0,
            inbound     INTEGER NOT NULL DEFAULT 0,
            orphan      INTEGER NOT NULL DEFAULT 0,
            foreign_caster INTEGER NOT NULL DEFAULT 0, -- a nearby player's attack (observed, not ours)
            unowned     INTEGER NOT NULL DEFAULT 0,    -- effect tick, no owning cast: applied to creature, not our deal
            redirected_from TEXT                       -- guardian redirect: noun of the creature we struck AT; the row's creature is the guardian that took it
          );
          CREATE INDEX IF NOT EXISTS idx_attacks_session ON attacks(session_id, seq);
          CREATE INDEX IF NOT EXISTS idx_attacks_creature ON attacks(creature_id);
          CREATE INDEX IF NOT EXISTS idx_attacks_name ON attacks(session_id, name);
          CREATE INDEX IF NOT EXISTS idx_attacks_root ON attacks(root_attack_id);

          -- attacker_stat/defender_stat/modifier by type:
          --   as_ds:  AS  / DS  / AvD      cs_td: CS  / TD  / CvA
          --   uaf_udf:UAF / UDF / MM       fear:  FS  / FD  / FvP
          --   smr/ssr/maneuver_roll/activation: NULLs + roll/bonus/penalty/result
          CREATE TABLE IF NOT EXISTS resolutions (
            id          INTEGER PRIMARY KEY,
            attack_id   INTEGER NOT NULL REFERENCES attacks(id),
            flare_id    INTEGER REFERENCES flares(id),   -- NULL = the attack's own roll
            seq         INTEGER NOT NULL,                -- order within the attack
            type        TEXT NOT NULL,
            attacker_stat INTEGER,
            defender_stat INTEGER,
            modifier    INTEGER,
            roll        INTEGER,                         -- the die, kept separate:
            bonus       INTEGER,                         -- result - roll = margin
            penalty     INTEGER,
            result      INTEGER,
            total       REAL                             -- UCS pre-MM total (fractional)
          );
          CREATE INDEX IF NOT EXISTS idx_resolutions_attack ON resolutions(attack_id);

          CREATE TABLE IF NOT EXISTS flares (
            id          INTEGER PRIMARY KEY,
            attack_id   INTEGER NOT NULL REFERENCES attacks(id),
            seq         INTEGER NOT NULL,
            name        TEXT NOT NULL,
            damaging    INTEGER NOT NULL DEFAULT 0,
            creature_id INTEGER REFERENCES creatures(id), -- AoE: may differ from swing
            weapon      TEXT,
            outcome     TEXT
          );
          CREATE INDEX IF NOT EXISTS idx_flares_attack ON flares(attack_id);
          CREATE INDEX IF NOT EXISTS idx_flares_name ON flares(name);

          CREATE TABLE IF NOT EXISTS hits (
            id          INTEGER PRIMARY KEY,
            attack_id   INTEGER NOT NULL REFERENCES attacks(id),
            flare_id    INTEGER REFERENCES flares(id),    -- NULL = attack's own damage
            session_id  INTEGER NOT NULL REFERENCES sessions(id),
            creature_id INTEGER REFERENCES creatures(id), -- NULL = inbound/self/orphan
            seq         INTEGER NOT NULL,
            damage      INTEGER NOT NULL,
            location    TEXT,                             -- CritRanks location
            body_part   TEXT,                             -- mapped injury-doll part
            crit_type   TEXT,
            crit_rank   INTEGER,                          -- CritRanks :rank (0-9): crit severity
            wound_rank  INTEGER,                          -- CritRanks :wound_rank (0-3): wound left on the creature
            fatal       INTEGER NOT NULL DEFAULT 0,
            amputated   INTEGER NOT NULL DEFAULT 0,
            secondary_location TEXT,
            secondary_rank     INTEGER                    -- secondary wound severity (:wound_rank)
          );
          CREATE INDEX IF NOT EXISTS idx_hits_attack ON hits(attack_id);
          CREATE INDEX IF NOT EXISTS idx_hits_creature ON hits(session_id, creature_id);
          CREATE INDEX IF NOT EXISTS idx_hits_location ON hits(location);
          CREATE INDEX IF NOT EXISTS idx_hits_crit ON hits(crit_rank);

          -- kind: status (action add/remove), stun (value=rounds),
          --       roundtime (value=seconds), spell_loss (spell/spell_name/cause),
          --       ucs (status=position/tierup/..., value=tier)
          CREATE TABLE IF NOT EXISTS statuses (
            id          INTEGER PRIMARY KEY,
            session_id  INTEGER NOT NULL REFERENCES sessions(id),
            creature_id INTEGER REFERENCES creatures(id), -- NULL = self or unresolved
            subject     TEXT,                             -- name as printed ('self' for us)
            attack_id   INTEGER REFERENCES attacks(id),   -- window attribution
            occurred_at REAL NOT NULL,
            kind        TEXT NOT NULL,
            status      TEXT,
            action      TEXT,
            value       INTEGER,
            spell       INTEGER,
            spell_name  TEXT,
            cause       TEXT,
            source      TEXT                              -- 'direct' | 'window'
          );
          CREATE INDEX IF NOT EXISTS idx_statuses_creature ON statuses(session_id, creature_id);
          CREATE INDEX IF NOT EXISTS idx_statuses_attack ON statuses(attack_id);
        SQL

        # parsed-resolution key -> generic column, per roll family
        STAT_KEYS = { as: :attacker_stat, cs: :attacker_stat, uaf: :attacker_stat, fs: :attacker_stat,
                      ds: :defender_stat, td: :defender_stat, udf: :defender_stat, fd: :defender_stat,
                      avd: :modifier, cva: :modifier, mm: :modifier, fvp: :modifier, mods: :modifier,
                      roll: :roll, bonus: :bonus, penalty: :penalty, result: :result, total: :total }.freeze

        attr_reader :db, :session_id

        # idle_timeout (seconds): enables auto-sessioning - a session opens on
        # the first recorded event and closes once this long passes without
        # one (see check_idle!). nil = explicit start_session/finish_session.
        def initialize(db_path, character: nil, source: 'live', idle_timeout: nil)
          @db = SQLite3::Database.new(db_path)
          @db.busy_timeout = 5_000
          @db.execute('PRAGMA journal_mode = WAL')
          @db.execute('PRAGMA synchronous = NORMAL')
          @db.execute_batch(SCHEMA)
          migrate!
          @seq = 0
          @open_attack = nil # { id:, creature_ids: Set, inbound: bool }
          @chunk_rows = {}   # per-chunk _uid -> attack row id, for spawn-tree links
          @pending_cache = nil      # creature-cache entries staged during a txn (see in_txn)
          @pending_chunk_rows = nil # chunk-row entries staged during a txn (see in_txn)
          @character = character
          @source = source
          @idle_timeout = idle_timeout
          @last_event_at = nil
          # record fires on the AsyncProcessor worker thread; check_idle!/close
          # are documented as driven from the consuming script's own periodic
          # loop. Both touch @db, so every public entry point serialises on one
          # non-reentrant mutex. Internal helpers that run while the lock is
          # already held (start_session/finish_session called from inside
          # record) must NOT re-acquire it - hence the unsynchronised _locked
          # variants below.
          @mutex = Mutex.new
        end

        def start_session(character: nil, source: nil, at: Time.now)
          @mutex.synchronize { start_session_locked(character: character, source: source, at: at) }
        end

        # Text from the game stream arrives as ASCII-8BIT (binary) strings, and
        # the sqlite3 gem binds a binary string as a BLOB. Every noun, creature
        # name, attacker and weapon was landing typed blob (real db 2026-09-07:
        # creatures.noun blob=196, text=0), so `WHERE noun = 'berserker'` never
        # matched and text functions saw bytes, not words. Re-tag as UTF-8 at
        # the boundary; game text is ASCII/Latin-1 so scrub only guards junk.
        def txt(value)
          return nil if value.nil?

          s = value.to_s
          s.encoding == Encoding::ASCII_8BIT ? s.dup.force_encoding('UTF-8').scrub('?') : s
        end

        def start_session_locked(character: nil, source: nil, at: Time.now)
          finish_session_locked if @session_id
          @db.execute('INSERT INTO sessions (character, source, started_at) VALUES (?, ?, ?)',
                      [txt(character), txt(source), at.to_f])
          @session_id = @db.last_insert_row_id
          @seq = 0
          @creature_cache = {}
          @session_id
        end

        # @return [Integer, nil] the id of the session just closed
        def finish_session(at: Time.now)
          @mutex.synchronize { finish_session_locked(at: at) }
        end

        def finish_session_locked(at: Time.now)
          return unless @session_id

          @db.execute('UPDATE sessions SET ended_at = ? WHERE id = ?', [at.to_f, @session_id])
          finished = @session_id
          @session_id = nil
          @open_attack = nil
          finished
        end

        # Hook the live observer feed. Idempotent via the named-handler
        # contract; per the Observers contract the callback stays cheap
        # (single WAL transaction) and never sends game commands.
        def subscribe!
          obs = Lich::Gemstone::Combat::Observers
          obs.on(:attack, :status, :stun, :roundtime, :spell_loss, :ucs,
                 name: HANDLER_NAME) { |type, data| record(type, data) }
        end

        def unsubscribe!
          Lich::Gemstone::Combat::Observers.off(HANDLER_NAME)
        end

        # Close the current session if the idle gap has elapsed - ended_at is
        # the LAST EVENT's time, not now, so town time never pads a hunt.
        # Cheap; call it from a periodic loop so a finished hunt closes even
        # when no further event ever arrives.
        def check_idle!(now = Time.now)
          @mutex.synchronize { check_idle_locked!(now) }
        end

        def check_idle_locked!(now = Time.now)
          return unless @idle_timeout && @session_id && @last_event_at
          return unless now - @last_event_at > @idle_timeout

          finish_session_locked(at: @last_event_at)
        end

        # Finish any open session and release the database.
        def close
          unsubscribe!
          @mutex.synchronize do
            finish_session_locked(at: @last_event_at || Time.now) if @session_id
            @db.close
          end
        end

        def record(type, data)
          @mutex.synchronize { record_locked(type, data) }
        end

        def record_locked(type, data)
          if @idle_timeout
            now = Time.now
            check_idle_locked!(now)
            start_session_locked(character: @character, source: @source, at: now) unless @session_id
            @last_event_at = now
          end
          return unless @session_id

          case type
          when :attack then record_attack(data)
          when :status then record_status(kind: 'status', id: data[:id], name: data[:name],
                                          status: data[:status].to_s, action: data[:action].to_s)
          when :stun then record_status(kind: 'stun', id: data[:id], name: data[:name],
                                        status: 'stunned', action: 'add', value: data[:rounds].to_i)
          when :roundtime then record_status(kind: 'roundtime', id: data[:id], name: data[:name],
                                             status: 'roundtime', action: 'add', value: data[:seconds].to_i)
          when :spell_loss then record_status(kind: 'spell_loss', id: data[:id], name: data[:name],
                                              action: 'remove', spell: data[:spell],
                                              spell_name: data[:spell_name], cause: data[:cause]&.to_s)
          when :ucs then record_status(kind: 'ucs', id: data[:id], name: data[:name],
                                       status: data[:kind].to_s,
                                       value: ucs_value(data))
          end
        rescue StandardError => e
          # Never raise into the processor; surfaced via Lich.log when present.
          msg = "CombatRecorder #{type}: #{e.message}"
          defined?(Lich) && Lich.respond_to?(:log) ? Lich.log("error: #{msg}") : warn(msg)
        end

        private

        # Additive schema migrations for databases created before a column
        # existed. CREATE TABLE IF NOT EXISTS never alters an existing table,
        # so each column added after first release is listed here and ALTERed
        # in when absent. Keep entries append-only.
        ADDED_COLUMNS = {
          'attacks' => { 'redirected_from' => 'TEXT' }
        }.freeze

        def migrate!
          ADDED_COLUMNS.each do |table, cols|
            present = @db.execute("PRAGMA table_info(#{table})").map { |r| r[1] }
            cols.each do |col, type|
              next if present.include?(col)

              @db.execute("ALTER TABLE #{table} ADD COLUMN #{col} #{type}")
            end
          end
        end

        # -- creatures -----------------------------------------------------------

        # Run a block inside a DB transaction, publishing creature-cache
        # in-memory mappings created during it ONLY on commit. A row inserted
        # inside a transaction that later rolls back is undone in the DB - but a
        # naive in-memory write would survive, so the next record would hand out
        # a row id that no longer exists (dangling FK). Two maps need this:
        #   @creature_cache - exist_id -> creatures.id (ensure_creature)
        #   @chunk_rows      - per-chunk _uid -> attacks.id (spawn-tree links)
        # During a transaction both stage into @pending_* and reads consult the
        # staged map; on commit we publish, on rollback we drop.
        def in_txn
          prev_cache = @pending_cache
          prev_chunk = @pending_chunk_rows
          @pending_cache = {}
          @pending_chunk_rows = {}
          @db.transaction do
            yield
          end
          # committed: publish staged entries
          @creature_cache.merge!(@pending_cache)
          @chunk_rows.merge!(@pending_chunk_rows)
        ensure
          # on rollback (transaction raised) the staged entries are discarded
          # with @pending_*; restore any outer transaction's.
          @pending_cache = prev_cache
          @pending_chunk_rows = prev_chunk
        end

        # Read a chunk-row mapping, consulting the in-transaction staged map
        # first (a child emitted after its parent in the SAME transaction can
        # still resolve it), then the committed map.
        def chunk_row(uid)
          (@pending_chunk_rows && @pending_chunk_rows[uid]) || @chunk_rows[uid]
        end

        def ensure_creature(info, at)
          return nil unless info && info[:id]

          exist_id = info[:id].to_i
          # cache hit: committed cache first, then this transaction's staged.
          # Backfill BOTH name and noun via COALESCE - a status-first creature
          # is inserted with a nil noun (status events carry only id + name),
          # so the later attack that names the noun must fill it, else it stays
          # NULL forever (1 kill / 0 kinds, since kinds counts DISTINCT noun).
          if (row_id = @creature_cache[exist_id] || (@pending_cache && @pending_cache[exist_id]))
            @db.execute('UPDATE creatures SET last_seen = ?, name = COALESCE(name, ?), noun = COALESCE(noun, ?) WHERE id = ?',
                        [at, txt(info[:name]), txt(info[:noun]), row_id])
            return row_id
          end

          @db.execute(<<~SQL, [@session_id, exist_id, txt(info[:noun]), txt(info[:name]), at, at])
            INSERT INTO creatures (session_id, exist_id, noun, name, first_seen, last_seen)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT (session_id, exist_id) DO UPDATE SET last_seen = excluded.last_seen
          SQL
          row_id = @db.get_first_value('SELECT id FROM creatures WHERE session_id = ? AND exist_id = ?',
                                       [@session_id, exist_id])
          # Inside a transaction, stage the id; it becomes visible in
          # @creature_cache only when in_txn commits. Outside one (the pre-
          # transaction ensure_creature in record_attack auto-commits), publish
          # immediately.
          if @pending_cache
            @pending_cache[exist_id] = row_id
          else
            @creature_cache[exist_id] = row_id
          end
          row_id
        end

        # -- the :attack payload: attack + resolutions + flares + hits -----------

        def record_attack(event)
          at = (event[:at] || Time.now).to_f
          target = event[:target] || {}
          creature_row = ensure_creature(target, at)
          target_kind = if creature_row then 'creature'
                        elsif event[:inbound] then 'self'
                        elsif event[:foreign_target] then 'foreign'
                        else 'none'
                        end
          outcomes = (event[:outcomes] || []).map(&:to_s)
          attacker = event[:attacker] || {}
          # Spawned-cast lineage arrives as { flare:, weapon: {id:, name:} }
          # (Blink: the flare procs a free cast) - split it into columns.
          parent = event[:parent]
          parent_weapon = nil
          if parent.is_a?(Hash)
            pw = parent[:weapon]
            parent_weapon = pw.is_a?(Hash) ? pw[:name] : pw
            parent = parent[:flare]
          end

          # Spawn-tree links: the processor stamps a per-chunk _uid on every
          # event and points :root_uid/:parent_uid at other events in the same
          # chunk (root/parent always emit BEFORE their children). We map uid ->
          # row id in @chunk_rows, resetting when a new chunk's first event
          # (_uid == 0) arrives. A root points at itself; an ambiguous spawn has
          # parent_uid nil.
          uid = event[:_uid]
          @chunk_rows = {} if uid.nil? || uid.zero?
          root_uid = event[:root_uid]
          parent_uid = event[:parent_uid]
          # parent/root were committed by an earlier record in this chunk (they
          # always emit first), so they live in @chunk_rows; chunk_row also
          # checks the staged map for safety. nil root => self, patched post-insert.
          root_row = (root_uid && chunk_row(root_uid))
          parent_row = (parent_uid && chunk_row(parent_uid))
          parent_conf = event[:parent_confidence]&.to_s

          in_txn do
            @seq += 1
            params = [@session_id, @seq, at, event[:name].to_s, parent&.to_s, txt(parent_weapon),
                      root_row, parent_row, parent_conf,
                      event[:via]&.to_s, creature_row, target_kind,
                      txt(attacker[:name]), attacker[:id],
                      txt(event[:weapon]), outcomes.first, (outcomes.size > 1 ? outcomes.join(',') : nil),
                      event[:aimed] ? 1 : 0, event[:ambush] ? 1 : 0,
                      event[:inbound] ? 1 : 0, event[:_orphan] ? 1 : 0,
                      event[:foreign_caster] ? 1 : 0, event[:unowned] ? 1 : 0,
                      # only an HONORED redirect changes who the row is about;
                      # an announced-but-unhonored one (UAC shape) resolved on
                      # the intended creature, which the row already names
                      (event[:redirect] && event[:redirect][:honored] != false) ? event[:redirect][:intended] : nil]
            @db.execute(<<~SQL, params)
              INSERT INTO attacks (session_id, seq, occurred_at, name, parent, parent_weapon,
                                   root_attack_id, parent_attack_id, parent_confidence,
                                   via, creature_id,
                                   target_kind, attacker, attacker_exist_id, weapon, outcome,
                                   outcomes_all, aimed, ambush, inbound, orphan, foreign_caster, unowned,
                                   redirected_from)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            SQL
            attack_id = @db.last_insert_row_id
            # stage the uid -> row mapping; published to @chunk_rows only when
            # in_txn commits, so a rolled-back attack can't leave a child
            # pointing at a nonexistent parent/root row.
            @pending_chunk_rows[uid] = attack_id if uid
            # A root references itself: when root_uid maps to this very event
            # (or is unset), point root_attack_id at our own new row.
            if root_row.nil?
              @db.execute('UPDATE attacks SET root_attack_id = ? WHERE id = ?', [attack_id, attack_id])
            end

            hit_seq = 0
            res_seq = 0
            (event[:resolutions] || []).each do |r|
              insert_resolution(attack_id, nil, res_seq += 1, r)
            end
            (event[:hits] || []).each do |hit|
              insert_hit(attack_id, nil, creature_row, hit_seq += 1, hit, at)
            end

            touched = Set.new([target[:id]].compact.map(&:to_i))
            (event[:flares] || []).each_with_index do |flare, i|
              f_target = flare[:target_info]
              f_creature = f_target ? ensure_creature(f_target, at) : nil
              touched << f_target[:id].to_i if f_target && f_target[:id]
              f_outcomes = (flare[:outcomes] || []).map(&:to_s)
              weapon = flare[:weapon].is_a?(Hash) ? flare[:weapon][:name] : flare[:weapon]
              f_params = [attack_id, i + 1, flare[:name].to_s, flare[:damaging] ? 1 : 0,
                          f_creature, txt(weapon), f_outcomes.first]
              @db.execute(<<~SQL, f_params)
                INSERT INTO flares (attack_id, seq, name, damaging, creature_id, weapon, outcome)
                VALUES (?, ?, ?, ?, ?, ?, ?)
              SQL
              flare_id = @db.last_insert_row_id
              (flare[:resolutions] || []).each { |r| insert_resolution(attack_id, flare_id, res_seq += 1, r) }
              (flare[:hits] || []).each do |hit|
                insert_hit(attack_id, flare_id, f_creature || creature_row, hit_seq += 1, hit, at)
              end
            end

            @open_attack = { id: attack_id, creature_ids: touched, inbound: !!event[:inbound] }
          end
        end

        def insert_resolution(attack_id, flare_id, seq, res)
          cols = { attacker_stat: nil, defender_stat: nil, modifier: nil, roll: nil,
                   bonus: nil, penalty: nil, result: nil, total: nil }
          res.each do |k, v|
            next if k == :type

            col = STAT_KEYS[k]
            cols[col] = v if col
          end
          @db.execute(<<~SQL, [attack_id, flare_id, seq, res[:type].to_s, *cols.values])
            INSERT INTO resolutions (attack_id, flare_id, seq, type, attacker_stat, defender_stat,
                                     modifier, roll, bonus, penalty, result, total)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          SQL
        end

        def insert_hit(attack_id, flare_id, creature_row, seq, hit, at)
          crit = hit[:crit] || {}
          secondary = crit[:secondary_wound].is_a?(Hash) ? crit[:secondary_wound] : {}
          fatal = crit[:fatal] ? 1 : 0
          # crit_rank is the CritRanks :rank (0-9 crit severity - what crit-rank
          # distributions and `crit_rank >= 8` queries mean); wound_rank is the
          # distinct :wound_rank (0-3 wound left on the creature). These were
          # conflated (wound_rank stored as crit_rank), which flattened every
          # crit-rank analytic - now stored in their own columns.
          params = [attack_id, flare_id, @session_id, creature_row, seq,
                    hit[:damage].to_i, crit[:location], map_body_part(crit[:location]),
                    crit[:type]&.to_s, crit[:rank], crit[:wound_rank], fatal,
                    crit[:amputated] ? 1 : 0,
                    secondary[:location], secondary[:wound_rank] || secondary[:rank]]
          @db.execute(<<~SQL, params)
            INSERT INTO hits (attack_id, flare_id, session_id, creature_id, seq, damage, location,
                              body_part, crit_type, crit_rank, wound_rank, fatal, amputated,
                              secondary_location, secondary_rank)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          SQL

          return unless fatal == 1 && creature_row

          # A fatal crit is ground truth for the killing blow: it takes the
          # credit even when a room-feed death already stamped killed_at
          # (that stamp can land under an earlier attack when the worker
          # lags the stream), but never moves an earlier killed_at.
          @db.execute('UPDATE creatures SET killed_at = COALESCE(killed_at, ?), killed_by_attack_id = ? WHERE id = ?',
                      [at, attack_id, creature_row])
        end

        def map_body_part(location)
          p = Lich::Gemstone::Combat::Processor
          p.respond_to?(:map_critranks_to_body_part, true) &&
            p.send(:map_critranks_to_body_part, location)
        rescue StandardError
          nil
        end

        # -- the status stream ---------------------------------------------------

        # The status value column is numeric. UCS position kinds carry their
        # decent/good/excellent tier as tier: 1..3; anything else only
        # persists when the payload value is already a number.
        def ucs_value(data)
          return data[:tier] if data[:tier].is_a?(Numeric)

          data[:value].is_a?(Numeric) ? data[:value] : nil
        end

        def record_status(kind:, id:, name:, status: nil, action: nil, value: nil,
                          spell: nil, spell_name: nil, cause: nil)
          at = Time.now.to_f
          # Atomic like record_attack: the creature upsert, the status insert
          # and the kill-stamp are one unit, so a mid-write failure can't leave
          # an auto-vivified creature row with no matching status row. in_txn
          # also stages the creature-cache entry so a rollback can't leave a
          # cached id pointing at a rolled-back row.
          in_txn do
            creature_row = id ? ensure_creature({ id: id, name: name }, at) : nil
            attack_id = nil
            source = 'direct'
            if @open_attack && id && @open_attack[:creature_ids].include?(id.to_i)
              attack_id = @open_attack[:id]
              source = 'window'
            elsif @open_attack && name == 'self' && @open_attack[:inbound]
              attack_id = @open_attack[:id]
              source = 'window'
            end

            params = [@session_id, creature_row, txt(name), attack_id, at, kind,
                      txt(status), action, value, spell, txt(spell_name), cause, source]
            @db.execute(<<~SQL, params)
              INSERT INTO statuses (session_id, creature_id, subject, attack_id, occurred_at,
                                    kind, status, action, value, spell, spell_name, cause, source)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            SQL

            # A death confirmed by the room feed (processor death watch) rather
            # than a fatal crit: stamp the kill and credit the attack whose
            # window it fell in - the last attack that touched this creature.
            # Ownership (kill vs assist) is judged later from that attack's
            # flags, so crediting a foreign caster's attack here is correct.
            if status == 'dead' && action == 'add' && creature_row
              @db.execute(<<~SQL, [at, attack_id, creature_row])
                UPDATE creatures SET killed_at = ?, killed_by_attack_id = COALESCE(killed_by_attack_id, ?)
                WHERE id = ? AND killed_at IS NULL
              SQL
            end
          end
        end
      end
    end
  end
end
