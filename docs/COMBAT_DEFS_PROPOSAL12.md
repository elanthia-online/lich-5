# Creature Messaging Proposal - Round 12 (Vigil)

Diffed against the canonical files at `88633e76` (round-10 merge +
ledger speed write-back included).

**First incremental round.** The ledger topped up with 59 new XML logs
(105 records) - everything else came from the standing coverage channel
minus what round 10 merged. The shrink the architecture promised is
real: round 10 proposed 5,311 lines; after the merge, the non-status
residue is **33 lines across 33 files**.

Generator changes this round: findings 44-48 all fixed at the source
(observed-case leading adjectives, death-bucket anchored on the subject
dying with dialogue stripped, skip-family counters, {Pronoun} sentence-
start placeholders, ProperName gate on every row including the generic
table), plus one self-caught: pronouns inside quoted speech stay
literal.

## Per-creature additions

### tawny armor-clad pegasus — `tawny_armor_clad_pegasus.rb`

**arrival**

- `A tawny armor-clad pegasus trots in with elegant ease, hooves leaving behind fading pools of colored light.`  *(18x)*

**flee**

- `A tawny armor-clad pegasus canters south with elegant ease, hooves leaving behind fading pools of colored light.`  *(2x)*

**death**

- `A tawny armor-clad pegasus's eyes roll up into {pronoun} head as {pronoun} body goes limp on the ground.`  *(7x)*

**spell_prep**

- `A tawny armor-clad pegasus's wings begin to glow, throwing off scintillating sparks, and the forces entangling {pronoun} snap away into flickering threads of spent mana.`  *(18x)*

### branded goliath diviner — `branded_goliath_diviner.rb`

**death**

- `A branded goliath diviner's dreamy gaze goes lifeless.`  *(439x)*
- `A branded goliath diviner's eyes roll up into {pronoun} head as {pronoun} body goes limp on the ground.`  *(32x)*

**search**

- `A branded goliath diviner looks around as if waking up from a dream.`  *(45x)*

**attack**

- `A branded goliath diviner extends {pronoun} hands, palms outward, and a shimmering wave of force thunders toward you!`  *(6x)*

### burly goliath engineer — `burly_goliath_engineer.rb`

**death**

- `A burly goliath engineer reaches out with a quavering hand before collapsing, lifeless, to the ground.`  *(453x)*
- `A burly goliath engineer's eyes roll up into {pronoun} head as {pronoun} body goes limp on the ground.`  *(32x)*

**search**

- `A burly goliath engineer scans the area methodically, eyes sharp and questioning.`  *(35x)*

### disfigured hive thrall — `disfigured_hive_thrall.rb`

**search**

- `A disfigured hive thrall fidgets, one eye twitching as {pronoun} searches the shadows.`  *(12x)*

**attack**

- `A disfigured hive thrall's eyes widen as {pronoun} topples forward, belching caustic bile at you!`  *(2x)*

### Shining winged disir — `shining_winged_disir.rb`

**spell_prep**

- `A shining winged disir silently mouths an incantation that does not seem to be in any language you know.`  *(177x)*

### radiant-eyed goliath auramancer — `radiant_eyed_goliath_auramancer.rb`

**death**

- `A radiant-eyed goliath auramancer's eyes roll up into {pronoun} head as {pronoun} body goes limp on the ground.`  *(33x)*

### earth elemental — `earth_elemental.rb`

**death**

- `The earth elemental falls to the floor dead, {pronoun} still pulsating with a blinding white hue.`  *(5x)*

### water elemental — `water_elemental.rb`

**death**

- `The water elemental falls to the floor dead, {pronoun} still pulsating with a blinding white hue.`  *(2x)*

### corpulent kresh ravager — `corpulent_kresh_ravager.rb`

**decay**

- `A corpulent kresh ravager's vast abdomen deflates, oozing fluids as the ravager succumbs to rapid decay.`  *(86x)*

### treekin warrior — `treekin_warrior.rb`

**attack**

- `A treekin warrior attempts to grab you!`  *(5x)*

### chitinous kiramon myrmidon — `chitinous_kiramon_myrmidon.rb`

**search**

- `A chitinous kiramon myrmidon's faceted eyes reflect nothing but empty shadows as {pronoun} twitches {pronoun} head to look around, hesitantly, as if {pronoun} has missed something.`  *(10x)*

### savage fork-tongued wendigo — `savage_fork-tongued_wendigo.rb`

**attack**

- `A savage fork-tongued wendigo crooks an oddly elongated finger at you!`  *(197x)*

---

## Triggers (frenzy/enrage - native messaging attrs, per your ruling)

- **tattooed gigas berserker**: `{s} flies into a wild rage, animalistic fury washing over {p} features!`  *(4705x)*
- **wraith**: `{s} spins in a frenzy and a strong wind whips around you.`  *(106x)*
- **bloody halfling cannibal**: `{s} bares {p} teeth in a mad parody of a grin as {p} bloodlust rises!`  *(68x)*
- **tattooed gigas berserker**: `{s} falls deeper into bloodlust, gnashing {p} teeth and clenching {p} immense muscles!`  *(17x)*
- **massive grahnk**: `{s} whales away, consumed with bloodlust!`  *(15x)*
- **wind wraith**: `{s} whales away, consumed with bloodlust!`  *(11x)*
- **moulis**: `{s} slides side to side in an agitated frenzy.`  *(6x)*
- **warrior shade**: `{s} whales away, consumed with bloodlust!`  *(4x)*
- **bloody halfling cannibal**: `{s} succumbs further to {p} bloodlust as spittle drips from {p} open mouth!`  *(3x)*

---

## Combat-defs candidate list (status expiry/onset - NOT for creature files)

Per the status-bucket ruling: passive status lines in template form,
aggregated cross-creature, sorted by volume. Onset/expiry pairing is
left to the defs review. Top 150 of 5190 templates:

| Lines | Creatures | Template |
|---|---|---|
| 7172 | 3 | `{s} is struck by a sharp piece of mist-covered debris!` |
| 5983 | 4 | `{s} is unharmed by the plasma!` |
| 5571 | 5 | `{s} is unharmed by the electricity!` |
| 4479 | 7 | `{s} is unharmed by the cold!` |
| 3517 | 1 | `{s} sits back on {p} haunches and unleashes a long, high-pitched howl that sends a shiver of primal ` |
| 3032 | 4 | `{s} loses an intense expression.` |
| 2980 | 2 | `{s} glides in, leaving a slick trail behind {x}.` |
| 2947 | 1 | `{s} lights from within, energy crackling within {p} chaotic core.` |
| 2922 | 1 | `{s} rolls over and leaps to {p} feet in a single fluid motion.` |
| 2811 | 1 | `{s} grits {p} teeth, but is unable to recover {p} wits.` |
| 2671 | 5 | `{s} loses an aura of resolve.` |
| 2533 | 2 | `{s} is revealed from hiding.` |
| 1907 | 1 | `{s} raises {p} eyes to the heavens as sunny light enshrouds {p}!` |
| 1866 | 5 | `{s} is struck by a sharp piece of hot debris!` |
| 1661 | 1 | `{s} glances to {p} left and right, a sinister smile twisting {p} fleshless face.` |
| 1541 | 1 | `{s} raises {p} a gleaming golden aegis and braces for an assault as a luminous barrier momentarily e` |
| 1466 | 1 | `{s} swarms low over the ground as if questing for something unseen.` |
| 1402 | 2 | `{s} gets a running start and then acrobatically leaps up onto the back of a heavily armored battle m` |
| 1381 | 7 | `{s} takes a deep breath, blinking a couple of times before resuming a calm expression.` |
| 1378 | 1 | `{s} rises fluidly, dusting a bit of dirt from one knee with a faint smirk.` |
| 1363 | 6 | `{s} is large in size and about seven feet high in {p} current state.` |
| 1233 | 1 | `{s} flails on the ground, making the ground shudder, before managing to fight {p} way into a standin` |
| 1222 | 1 | `{s} looks sluggishly about with dazed eyes.` |
| 1111 | 2 | `{s} makes a subtle gesture, drawing traces of faint blue-green light into {p} webbed hands.` |
| 1099 | 1 | `{s} cocks {p} eyeless head.` |
| 1094 | 4 | `{s} is unharmed by the heat!` |
| 1056 | 1 | `{s} stares sightlessly into the shadows, revealing you in your hiding place!` |
| 1033 | 2 | `{s} approaches you.` |
| 1029 | 1 | `{s} roils and ripples, sending questing tendrils toward the shadows.` |
| 1029 | 1 | `{s} sprouts a pseudopod that tests the air eagerly before retreating into the ooze's central mass.` |
| 1016 | 1 | `{s} surrenders to bloodthirst, darkness swathing {p} in a thick shroud!` |
| 988 | 1 | `{s} surrenders to bloodthirst, darkness swathing him in a thick shroud!` |
| 985 | 1 | `{s} turns, searching the shadows with one twitching eye.` |
| 960 | 1 | `{s} struggles as {x} tries to move.` |
| 940 | 1 | `{s} raises a hand skyward, suffusing {r} with scintillating power.` |
| 823 | 6 | `{s} staggers slightly, swaying about in a daze.` |
| 707 | 1 | `{s} slings a gleaming golden aegis over {p} shoulder.` |
| 684 | 1 | `{s} rapidly begins dwindling away, flickering like a dying candleflame.` |
| 683 | 5 | `{s} is huge in size and about twelve feet high in {p} current state.` |
| 635 | 1 | `{s} hits {r} trying to recover {p} balance.` |
| 595 | 5 | `{s} ambles in!` |
| 592 | 5 | `{s} slinks in, peering about with cold, unblinking eyes.` |
| 591 | 1 | `{s} steps back into the shadows, {p} ebon carapace blending with the darkness.` |
| 589 | 1 | `{s} gives a flourish of {p} spectral arms as {x} raises {p} voice in a theatrical chant.` |
| 566 | 2 | `{s} careens to the ground and crumples in a heap.` |
| 554 | 1 | `{s} jerks up from the ground in a single boneless motion.` |
| 548 | 5 | `{s} vanishes into thin air, leaving no trace behind.` |
| 546 | 1 | `{s} hops to {p} feet and gives a single flap of {p} wings.` |
| 540 | 7 | `{s} snatches up a riveted golden targe!` |
| 537 | 1 | `{s} cackles with glee as {x} reaches down and claws into your helpless body!` |
| 531 | 4 | `{s} vanishes in a brisk wind that rips through the trees!` |
| 530 | 1 | `{s} shifts uncertainly as {x} glares about with fiery blue eyes.` |
| 522 | 5 | `{s} just arrived.` |
| 522 | 3 | `{s} lunges towards you, most likely intending to finish you off!` |
| 511 | 3 | `{s} moves agressively towards you to finish you off, but you still have enough wits about you to thw` |
| 510 | 5 | `{s} fades into transparency, {p} remnants rapidly dissolving into the air.` |
| 505 | 3 | `{s} totally ignores {p} missing leg, attacking with complete concentration.` |
| 501 | 4 | `{s} draws an ancient sigil in the air.` |
| 499 | 1 | `{s} stops, surveying the surroundings with a look of disdain on {p} face.` |
| 499 | 7 | `{s} slumps silently to the ground and begins to rapidly dissipate.` |
| 499 | 5 | `{s} is sliced neatly in two.` |
| 496 | 2 | `{s} removes a brackish green arrow from in {p} rough leather quiver.` |
| 493 | 1 | `{s} totters around, looking as if {x} is about to topple!` |
| 491 | 1 | `{s} rapidly decomposes into a puddle of greenish-brown goo.` |
| 491 | 2 | `{s} removes a silver-streaked arrow from in {p} rough leather quiver.` |
| 488 | 7 | `{s} is inspired by the chant!` |
| 469 | 2 | `{s} raises an outstretched hand to the air!` |
| 463 | 1 | `{s} twists and coils {p} tentacles, sending tendrils of electricity crawling along the surface of {p` |
| 459 | 1 | `{s} twitches, {p} distended cranium pulsing as a look of intense focus stills {p} face.` |
| 449 | 1 | `{s} soars past you on stygian wings.` |
| 447 | 6 | `{s} raises {p} hands high, laces them together and brings them crashing down towards you!` |
| 445 | 2 | `{s} tries to maneuver in close with you, but you manage to avoid {p} attempt.` |
| 427 | 2 | `{s} hangs back for a moment and concentrates intently on you, before unleashing an attack on the mag` |
| 426 | 2 | `{s} draws into a tense, defensive stance, bobbing {p} head as {p} tail swishes angrily.` |
| 423 | 4 | `{s} runs in!` |
| 423 | 1 | `{s} clumsily twists {p} palsied hands into a spell form, {p} fingers trailing waves of psionic energ` |
| 420 | 2 | `{s} removes a sapphire-tipped arrow from in {p} rough leather quiver.` |
| 419 | 1 | `{s} raises {p} sonorous voice into a resounding cry that crashes like mad thunder through the area!` |
| 416 | 5 | `{s} is forced out of hiding!` |
| 414 | 1 | `{s} stumbles forward, off balance.` |
| 409 | 1 | `{s} rears back, emitting an awful keening cry that resounds shrilly through the area!` |
| 407 | 2 | `{s} tries to maneuver in close with you, but you avoid {p} maneuver easily.` |
| 401 | 3 | `{s} is huge in size and about twenty-two feet high in {p} current state.` |
| 400 | 3 | `{s} is huge in size and about twenty-one feet high in {p} current state.` |
| 391 | 1 | `{s} skitters in, raising {p} scythe-like forelegs and straightening to an impressive height.` |
| 389 | 3 | `{s} is tiny in size and about three feet high in {p} current state.` |
| 385 | 1 | `{s} twists a skeletal hand, uttering a blasphemous chant.` |
| 384 | 1 | `{s} weaves complex threads of raw mana with {p} pale legs.` |
| 375 | 2 | `{s} suddenly bursts from the ground!` |
| 373 | 2 | `{s} comes galloping in, {p} nostrils flaring!` |
| 369 | 2 | `{s} shakes {p} mane.` |
| 368 | 1 | `{s} slices a shadowy sigil in the air as {x} utters an old chant.` |
| 365 | 1 | `{s} suddenly grows very still, {p} eye sockets blazing with a brilliant green.` |
| 360 | 4 | `{s} melts away, leaving nothing behind.` |
| 359 | 4 | `{s} skitters in.` |
| 357 | 1 | `{s} traces a twisted symbol as {x} calls upon {p} inner power.` |
| 354 | 1 | `{s} is cut short in mid-wail, sent back to the ethereal plane where {x} belongs!` |
| 348 | 2 | `{s} glares at you and lets out a nerve-shattering bellow!` |
| 342 | 1 | `{s} blends with the shadows, moving too swiftly for the eye to follow.` |
| 342 | 3 | `{s} fails to connect solidly with any magical ward.` |
| 333 | 2 | `{s} looses an unnerving caterwaul!` |
| 331 | 1 | `{s} shrivels up leaving nothing but a few scales and some dust.` |
| 327 | 1 | `{s} stumbles about, {p} great footsteps sending tremors through the area.` |
| 319 | 2 | `{s} crawls out of the wasp nest!` |
| 311 | 4 | `{s} begins to wail loudly!` |
| 311 | 1 | `{s} glances about, eyes watching the shadows.` |
| 304 | 2 | `{s} crumbles into a pile of dry splinters.` |
| 304 | 4 | `{s} is medium in size and about eight feet high in {p} current state.` |
| 302 | 7 | `{s} is huge in size and about fifteen feet high in {p} current state.` |
| 302 | 4 | `{s} gets a glint in {p} eye!` |
| 302 | 1 | `{s} howls as {x} runs in!` |
| 299 | 2 | `{s} is large in size and about eleven feet high in {p} current state.` |
| 297 | 1 | `{s} glowers disdainfully as {x} sweeps the surroundings with {p} gaze.` |
| 295 | 3 | `{s} pins you to the ground and quickly jumps to {p} feet!` |
| 294 | 1 | `{s} begins to mouth a desperate prayer, but death stifles {p}.` |
| 290 | 1 | `{s} flickers for a moment, assessing {p} surroundings for signs of life.` |
| 289 | 1 | `{s} looks over {p} shoulder for a moment, but shrugs as if dismissing a stray thought.` |
| 286 | 1 | `{s} begins to mouth a desperate prayer, but death stifles him.` |
| 284 | 1 | `{s} breaks apart into misty tendrils.` |
| 283 | 1 | `{s} growls an arcane phrase.` |
| 282 | 2 | `{s} manages to cleave away a magical ward!` |
| 280 | 2 | `{s} buzzes about angrily.` |
| 279 | 3 | `{s} vanishes in a cold mist of evaporating ice.` |
| 278 | 3 | `{s} ceases all attempts at movement.` |
| 272 | 1 | `{s}'s face turns upward in a tortured rictus then {p} body goes slack.` |
| 269 | 2 | `{s} collapses to the ground, a thick grey mist pouring from {p} nostrils.` |
| 267 | 2 | `{s} oozes molten glaes from all over {p} body.` |
| 262 | 2 | `{s} simply withers away, bits of grayish dust scattered about in {p} wake.` |
| 260 | 1 | `{s} unfurls {p} resplendent wings and throws {p} head back!` |
| 259 | 2 | `{s} sinks into the ground, leaving nothing behind.` |
| 258 | 1 | `{s} begins buzzing loudly, {p} corrupt aura turning a deeper shade of bile green.` |
| 255 | 3 | `{s} is small in size and about four feet high in {p} current state.` |
| 250 | 4 | `{s} becomes enshrouded in a swirling vortex of energy that quickly expands outward from {p}, forming` |
| 248 | 2 | `{s} melts down and seeps into the earth.` |
| 246 | 3 | `{s} quickly decomposes before your eyes.` |
| 244 | 7 | `{s} falls to the ground in a crumpled heap.` |
| 240 | 3 | `{s} gushes noisily as {x} forms from a whirling watery vortex!` |
| 238 | 2 | `{s}'s arm snaps trying to prevent fall.` |
| 234 | 1 | `{s} briefly combs the shadows.` |
| 233 | 1 | `{s} shakes free from {p} stunned state, {p} monstrous features twitching painfully!` |
| 232 | 5 | `{s} stomps angrily, tossing {p} head from side to side.` |
| 231 | 1 | `{s} hurries in, torment making {p} mismatched eyes bulge.` |
| 224 | 1 | `{s} darts into the shadows.` |
| 224 | 1 | `{s} tramps in, scanning the area suspiciously.` |
| 221 | 4 | `{s} falls to the ground, {p} living fire extinguished.` |
| 219 | 1 | `{s} swirls into a tortured column of melting faces and snatching claws!` |
| 218 | 1 | `{s} looks at a cinder wasp and drools.` |
| 217 | 6 | `{s} snorts anxiously!` |
| 216 | 2 | `{s} crumbles into a pile of ash.` |
| 216 | 1 | `{s} twists {p} hand into a fist, {p} aura searing away shadows to reveal you in your hiding place!` |

---

## Generic messaging table (unchanged reference)

| Lines | Creatures | Template |
|---|---|---|
| 60646 | 9 | `{s} collapses, gurgling once with a wrathful look on {p} face before expiring.` |
| 13713 | 12 | `{s} avoids the incense smoke!` |
| 13387 | 124 | `{s} blinks and looks around in confusion for a moment.` |
| 11305 | 9 | `{s} is surrounded by an ominous, chitinous clicking!` |
| 11078 | 82 | `{s} is medium in size and about five feet high in {p} current state.` |
| 10192 | 73 | `{s} decays into compost.` |
| 9996 | 12 | `{s} glances around, sure that {x} has missed something...` |
| 9032 | 14 | `{s} is struck by a sharp piece of snowy debris!` |
| 8692 | 64 | `{s} is medium in size and about six feet high in {p} current state.` |
| 7715 | 45 | `{s} stands up with a grunt.` |
| 7672 | 531 | `{s} appears dazed and unsure.` |
| 7232 | 272 | `{s} is already blinded.` |
| 6999 | 12 | `{s} trots in!` |
| 6247 | 214 | `{s} is medium in size and about one foot high in {p} current prone state.` |
| 6186 | 320 | `{s} shudders with severe convulsions as pearlescent ripples envelop {p} body.` |
| 5701 | 52 | `{s} is medium in size and about three feet high in {p} current state.` |
| 4836 | 124 | `{s} is awakened by your attack!` |
| 4802 | 458 | `{s} shakes off the effects of the flames.` |
| 4704 | 28 | `{s} decays into a compost of fangs, fur and claws.` |
| 3862 | 23 | `{s} decays into a pile of fur and bone.` |
| 3709 | 24 | `{s} turns to dust.` |
| 3497 | 14 | `{s} is buffeted by the icy blue ethereal sphere.` |
| 3442 | 94 | `{s} is large in size and about one foot high in {p} current prone state.` |
| 3315 | 15 | `{s} is buffeted by the snapping and crackling ethereal sphere.` |
| 3312 | 12 | `{s} is buffeted by the crimson ethereal sphere.` |
---

## Tracker candidates (outcomes.rb - our AoE spells, not creature messaging)

| Lines | Creatures | Template |
|---|---|---|
| 1324 | 1 | `{s} gigas berserker is unaffected.` |
| 903 | 1 | `{s} gigas shield-maiden is unaffected.` |
| 438 | 1 | `{s} giant warg is buffeted by the formless black waves, but is unaffected.` |
| 286 | 1 | `{s} giant warg is buffeted by the crimson ethereal waves, but is unaffected.` |
| 185 | 1 | `{s} gigas berserker is buffeted by the formless black waves, but is unaffected.` |
| 173 | 1 | `{s} armored battle mastodon is buffeted by the crimson ethereal waves, but is unaffected.` |
| 167 | 1 | `{s} armored battle mastodon is buffeted by the formless black waves, but is unaffected.` |
| 167 | 1 | `{s} gigas berserker is buffeted by the crimson ethereal waves, but is unaffected.` |
| 159 | 1 | `{s} giant warg is buffeted by the formless black sphere, but is unaffected.` |
| 139 | 1 | `{s} giant warg is buffeted by the crimson ethereal sphere, but is unaffected.` |
| 136 | 1 | `{s} gigas berserker is buffeted by the crimson ethereal sphere, but is unaffected.` |
| 118 | 1 | `{s} giant warg is buffeted by the icy blue ethereal sphere, but is unaffected.` |
