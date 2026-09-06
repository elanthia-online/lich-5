# Spawns-repo proposal — per-creature messaging from the 2026-09-04 combat-defs rounds

For: `lich-5-creature-spawns/lib/gemstone/creatures`
From: combat-defs rounds 13/14 + the corpus_sweep3 unmatched channel
(10,637 logs / 48 GB, defs @ 16e0df73). Line counts and creature
attributions come from the sweep-3 ledger; every template below was
ruled **creature messaging, not combat defs** — single-creature
wording, or shared wording that lives in per-creature buckets
(arrival/search/death/stand/status) by the established architecture.

Volumes are corpus line counts; creature lists are ledger-attributed
(top contributors shown, counts in parens).

---

## 1. Ready to promote — already sitting in comment blocks

Two lines were captured in raw-log `=end` comment blocks inside their
creature files but never promoted to messaging buckets:

- **grim_gigas_skald.rb** (~line 222) → `stand`:
  `A grim gigas skald flails on the ground, making the ground shudder, before managing to fight her way into a standing position.` *(1,233x)*
- **savage_fork-tongued_wendigo.rb** (~line 255) → `stand`:
  `A savage fork-tongued wendigo jerks up from the ground in a single boneless motion.` *(554x)*

## 2. Stand buckets

- **niveous giant warg** *(2,926x)*:
  `{s} rolls over and leaps to {p} feet in a single fluid motion.`
- **eyeless black valravn** *(550x)*:
  `{s} hops to {p} feet and gives a single flap of {p} wings.`
- **brawny gigas shield-maiden** *(1,382x)*:
  `{s} rises fluidly, dusting a bit of dirt from one knee with a faint smirk.`

## 3. Status / ambient buckets

- **tattooed gigas berserker** *(493x)*:
  `{s} totters around, looking as if {x} is about to topple!`
  (off-balance/stagger flavor; combat defs took the generic tick
  family, this wording is berserker-only)
- **triton brawler** *(16,159x — largest single-creature residue)*:
  `{s}'s expression briefly shifts, nearly but not quite smoothing into blankness.`
  (ambient idle; fires alone in its chunk)
- **triton brawler** *(10,665x of 11,306; also spectral triton
  protector 454x, trace others)*:
  `{s} is surrounded by an ominous, chitinous clicking!`
- **niveous giant warg** *(3,521x)*:
  `{s} sits back on {p} haunches and unleashes a long, high-pitched howl that sends a shiver of primal terror down your spine!`
- **roiling crimson angargeist** *(2,992x + 1,466x)*:
  `{s} lights from within, energy crackling within {p} chaotic core.`
  `{s} swarms low over the ground as if questing for something unseen.`
- **cat family — cougar (306), muscular brindlecat (228), puma (106),
  panther (104), tawny brindlecat (92), dark panther (88), black
  leopard (68), mountain lion (65) + more** *(1,374x total)*:
  `{s} pounces to the ground in front of you!`
  (shared wording across the cat line — one entry per creature file,
  probably arrival-or-ambush bucket by your call)

## 4. Search buckets

- `{s} glances around, sure that {x} has missed something...`
  *(9,996x)*: **imposing elk (3,717), muddy hog (2,510), ebon swine
  (2,303)** + triton casters (psionicist 365, fanatic 333, protector
  290, brawler 234)

## 5. Arrival buckets

- `{s} trots in!` *(7,021x)*: **imposing elk (2,927), muddy hog
  (1,920), ebon swine (1,821)**, black rolton (96), rolton (58),
  great stag (40), mountain goat (38), spotted gnarp (32)
- `{s} ambles in.` *(2,560x)*: forest troll (231), mountain troll
  (214), mountain rolton (199), cave gnome (184), rolton (165),
  kobold (157), large ogre (117), manticore (96) + long tail
- `{s} glides in, leaving a slick trail behind {x}.` *(2,996x)*:
  **quivering sanguine ooze (1,688), colossal boreal undansormr (1,308)**

## 6. Death / decay buckets

- `{s}'s slick skin begins to rapidly desiccate and dissolve away, leaving nothing behind.`
  *(119,323x — the single largest residue template in the corpus)*:
  the whole triton line — **brawler (60,666), fanatic (26,452),
  warden (15,549), warlock (10,052), assassin (6,267)** + minor
  variants (combatant/executioner/radical ~100 each). Decay bucket.
- `{s} collapses, gurgling once with a wrathful look on {p} face before expiring.`
  *(60,663x)*: same triton spread — **brawler (28,950), fanatic
  (13,915), warden (8,983), warlock (5,406), assassin (3,201)** +
  minors. Death bucket.
- `{s} ceases all attempts at movement.` *(278x)*: **spectral dwarven
  miner, shadow mare, spectral miner, ghostly pooka** — noncorporeal
  death echo, proven 40/40 on the killing blow (round-13 windows:
  corpse search / decay / death buff-strips follow every time).
  Death bucket for all four. NOTE (spawns feedback 2026-09-04): the
  spectral dwarven miner has NO template file yet — that one is a
  missing-template item, the other three landed.
- `{s} rapidly coagulates, the air sucking the moisture from {p} shape. What remains of the ooze flakes into a pile of reddish flakes...`
  *(2,075x)*: **quivering sanguine ooze**. Decay bucket.

## 7. Spell-prep buckets

- **brawny gigas shield-maiden** *(1,910x)*:
  `{s} raises her eyes to the heavens as sunny light enshrouds her!`
  (prep/cast flavor preceding her holy casts)

## 8. ~~Also pending (from round 12)~~ — RESOLVED

STALE, per spawns-repo feedback 2026-09-04: the
`docs/COMBAT_DEFS_PROPOSAL12.md` per-creature additions were already
merged there as rounds 12-13. Nothing outstanding from that list.
(Their pronoun renders also confirmed beings-style variance — "her
face" on a triton brawler death — validating the {pronoun} templating
throughout this proposal.)

---

## Appendix — surfaced by the same sweep but NOT for creature files

Listed so they don't get double-converted:

- `{s} is quite dead already.` *(1,988x / 22 creatures)* — system
  echo for attacking a corpse; combat-defs territory (candidate
  outcome/noise claim), not creature messaging.
- `{s} becomes solid again.` *(1,767x / 20)* — already converted:
  Mass Blur (911) wear-off in combat-defs spell_losses (creatures
  self-cast it; the spell_loss def handles creature and player alike).
- `{s} shudders with severe convulsions as pearlescent ripples envelop {p} body.`
  *(6,189x / 50+)* and `{s} appears somehow different.` /
  `{s} seems slightly different.` *(5,191x combined / 26+15)* — spell
  effects landing on creatures (caster-side or self-buff visuals);
  open combat-defs questions, not bucket material.
- `{s} glances around, looking a bit less confident.` *(1,782x / 26)*
  — shared confidence-loss wording across 26 creatures; likely a
  spell/debuff expiry (combat-defs open question).
