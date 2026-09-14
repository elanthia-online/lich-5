# Combat Defs: Onboarding

How the combat definition grammar (`lib/gemstone/combat/defs/*`) gets
extended from log evidence — the methods that worked, the traps that are
documented in blood, and the current backlog with its evidence files.

## The two projects (don't mix them)

**Creature messaging** (the other project): per-creature flavor — arrivals,
deaths, flees, lore — merged into the canonical creature files in
`lich-5-creature-spawns` through numbered proposal rounds. Per-creature
bespoke flavor is unbounded; the combat defs project deliberately does not
chase it.

**Combat defs** (this project): the *mechanics grammar* — the shared
messaging the game emits for combat resolution, identical across
creatures. Attack initiations, roll lines, damage, outcomes, flares,
sequences, status transitions. One pattern here serves all 600+ creatures.

The routing rule between them, per the status-bucket ruling (2026-09-01):
a creature-specific ACTIVE recovery ("the Illoke jarl shakes off the
stun") is creature messaging; a shared PASSIVE transition ("the stun wears
off", a moonbeam hold arresting movement) is a combat def. When a line
appears near-identically across many unrelated creatures, it is grammar,
not flavor.

## What the parser recognizes today

Everything flows through `lib/gemstone/combat/parser.rb`, dispatching to
the def families in `defs/`:

| Family | File | What it matches |
|---|---|---|
| Attack initiations | `attacks.rb` | ~115 named defs (`:attack`, `:cast`, `:mstrike` parts, cmans, spells-as-attacks). Third-person defs capture `attacker:`. |
| Damage | `damage.rb` | "...N points of damage!", inline tick damage |
| Crits | `critranks` (separate module) | 2,389 crit descriptor patterns, first-word-indexed. Crit lines NEVER belong in combat defs. |
| Resolutions | `outcomes.rb` (resolution section) | AS/DS, CS/TD, UAF/UDF, SMR/SSR, fear saves, activation rolls |
| Outcomes | `outcomes.rb` | why nothing landed: evade/block/parry/warded/miss/fumble/resisted/hindrance |
| Flares | `flares.rb` | weapon scripts, enchants, GEFs; carry weapon identity for attribution |
| Sequences | `sequences.rb` | multi-part brackets: mstrike, flurry, volley, barrage, spawned casts |
| Statuses | `statuses.rb` | add/remove PAIRS per status (stunned, prone, kneeling, webbed, immobilized...) |
| UCS | `ucs.rb` | position/tierup/smite |

Layered on top for corpus work: the **lore layer**
(`scripts/custom/forge/tools/speed_ledger.rb`) compiles the canonical
creature files' messaging (~5,600 patterns) so creature flavor is
"recognized" during replay without being combat-defs material.

## What is NOT parsed — the standing backlog

The ledger's coverage channel records every line where a catalogued
creature is the subject but neither the parser nor its lore file matched.
After noise filtering, ~780k lines remain, already classified:

1. **Status onset/expiry candidates** — the biggest pile. 5,083 templates
   in `{s}/{p}` form, cross-creature aggregated, volume-sorted, delivered
   in round 11's proposal (combat-defs candidate list section). The task:
   pair onsets with expiries and grow `statuses.rb`. The moonbeam hold
   (75k lines) and `is unharmed by the impact!` (35k) were the first two
   converted; thousands of smaller families remain.
2. **AoE outcome families** — 283 templates (round-12 proposal, tracker
   candidates section): "unable to avoid being injured by the
   firestorm!", "dodges the effects of the raging tempest.",
   "is unaffected." These are outcomes of OUR spells; `outcomes.rb`
   material.
3. **Player-spell noise** — wear-offs/dispels/sigil visuals, filtered at
   ingest by `scripts/custom/forge/tools/spell_noise.rb`. New spells will
   grow this list; patterns are curated and specific, never verb-broad.
4. **708 Limb Disruption family** — one archived cast total (GSIV-Zoleta
   2026-01). Known gaps: the limb-removal result line ("right hind leg
   explodes!" — amputation-class, limb captured), the collapse/favors
   prone follow-through, the "has no limbs left!" saturation outcome, and
   "Nothing happens." Live sorcerer captures are being gathered now; the
   forge sorcerer profile casts 708 per creature specifically to build
   this corpus.
5. **Known-pending from earlier rounds**: dazed-sway status; 3p
   spirit-strike flare wordings; sweep-tool timestamp stripping +
   Sequences awareness (false-family noise).
6. **Homeless line families** (reviewer-ruled skip-for-now):
   player-corpse taunts, enrage-on-ally-death, spell-absorb reactions.
   Counted at ingest so recurrence is visible.

## Methods that work

### 1. Blob audit (the core mining method)
Split logs into prompt-separated blobs (`[script]>cmd` echoes as
boundaries). Classify EVERY line through the compiled defs. Group the
unmatched combat-shaped residue into digit-normalized templates. Present
each candidate WITH its full annotated exchange, because the role must be
provable:
- an **initiation** precedes its own roll line
- a **hit line** sits between roll and damage
- a **prefix** precedes a matched attack line — and is therefore NEVER a
  def (adding one double-opens events; the trap has been hit repeatedly:
  quiver-draw before fire, "You position yourself to attack", "leap from
  hiding" before the maneuver line)

Line-grepping without the exchange context was tried and rejected — roles
are unprovable in isolation.

### 2. Evidence rules
- Patterns target the RAW XML feed. Captures span markup; use the
  `MK_PRE`/`MK_POST` tokens (`pattern_gate.rb`) at every possessive-glue
  and linked-pronoun site. A markup-blind pattern silently loses
  thousands of hits per month (46 def kinds were, before the round-6
  sweep).
- Cite the observed line and its count for every proposed pattern. A
  pattern with no observed line does not ship.
- Refuse over guess: ambiguous attribution, unresolved subjects, and
  lines carrying unaccounted capitalized tokens (player names) are
  dropped, not interpreted.
- The game's own bugs are preserved verbatim (elementals render "its
  still pulsating" — the skin-noun substitution has nothing to
  substitute). Check raw renders before assuming the tooling ate a word.

### 3. Performance shape
Each def family gates itself with a small literal union (`PatternGate`).
One combined mega-union was measured SLOWER (58µs vs 35µs/line) — Ruby
scans big alternations linearly. At hundreds of patterns per family, the
proven scale-up is a first-word bucket index (see CritRanks), not a
bigger union.

### 4. Validation loop (all of it, every change)
- **Fixtures**: `logs/examples/*.txt` — real-feed captures, one per
  attack/spell/mechanic; replayed by the fixture harness. The scoreboard
  target is 0 unknown events / 0 damage-without-roll per fixture, with
  understood residuals documented.
- **Per-attack corpus**: `C:\Gemstone\dev\combat_corpus\by_attack\`
  (stripped) + `by_attack_xml\` (synthesized live-feed XML) — pure
  trimmed exchanges with `# expect:` headers. `tools/` holds the
  pipeline (attack_corpus.rb → xmlify.rb, replay_harness.rb).
- **Replay**: the deduplicated blob corpus (257,568 signatures) replays
  through the real `Processor.parse_events`; the fully-matching rate is
  the regression metric (92.7% at last full run).
- Widen strictly: markup-tolerance changes are validated against the
  real failing lines they were written for (392/392 at the last sweep).

### 5. Processor routing rules (hard-won; don't rediscover)
- Maneuver-class rolls (SMR/SSR/fear) PRECEDE their per-target line;
  AS/DS-class rolls FOLLOW their attack line. A roll arriving on a
  settled event (has damage or an outcome) belongs to the NEXT target.
- The bare-gesture `:cast` event is a WRAPPER when a spell-specific
  initiation follows in-chunk: rolls transfer, wrapper discarded,
  `via: :cast`.
- A damaging flare's cursor closes once it has damage (or it steals the
  next swing's roll).
- Inbound events (creature → us) carry no creature target BY DESIGN and
  must never adopt one from a later link (emotes handed creatures their
  own damage). Same for foreign targets (players).
- No death defs, ever: death STATE is owned by `<crtrStatus dead="1">`;
  death MESSAGES are catalogued (`combat_corpus/deaths_catalog.txt`) but
  never pattern-matched into events.

### 6. Timing tap (if you touch the speed pipeline)
`parse_events` deliberately DROPS inbound events (no damage target), so
timing tools tap `Parser.parse_attack`/`Statuses.parse` per line instead.
Cost model and measurement rules live in
`scripts/custom/forge/tools/speed_report.rb` and are corpus-verified:
casts are half-actions whatever def matched them, movement costs a full
action, BCS tiers shift the timer −2..+2 (+4 grizzled, −4 AG-dangerous).

## Where everything lives

| Thing | Path |
|---|---|
| Def families | `lib/gemstone/combat/defs/*.rb` |
| Parser / processor / observers | `lib/gemstone/combat/{parser,processor,observers}.rb` |
| Ledger (coverage channel source) | `scripts/custom/forge/tools/speed_ledger.rb` → `data/speed_ledger/ledger.jsonl` |
| Noise filter | `scripts/custom/forge/tools/spell_noise.rb` |
| Status/defs candidate lists | `data/forge_reports/PROPOSAL11.md` (status candidates, 5,083 templates) + `data/forge_reports/PROPOSAL12.md` (tracker candidates, 283 templates) |
| Fixtures | `logs/examples/` (user adds captures continuously — rerun the fixture replay when new files appear) |
| Corpus + replay tooling | `C:\Gemstone\dev\combat_corpus\` |
| Deaths catalog | `combat_corpus/deaths_catalog.txt` (miner: `combat_corpus/tools/death_miner.rb`) |
| Prior proposals/catalogs | `docs/COMBAT_DEFS_*.md` |

## Suggested first tasks (increasing difficulty)

1. **AoE outcome families** (283 templates, evidence attached): mostly
   mechanical additions to `outcomes.rb` — good first exposure to the
   evidence-and-validation loop.
2. **Status onset/expiry pairing** from the 5,083-template candidate
   list: start with the highest-volume families; each needs an add
   pattern, a remove pattern where observed, and a decision about which
   status name it maps to.
3. **708 limb family** once the sorcerer captures land: one new
   result-line def with limb capture, one prone pattern, one outcome —
   plus the open design question of per-limb tracker state.
4. **Sweep-tool hardening** (round-7 pending): timestamp stripping and
   Sequences.parse_* awareness in the audit tooling.
