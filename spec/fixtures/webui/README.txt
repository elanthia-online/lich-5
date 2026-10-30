WebUI setup fixture provenance and acceptance boundaries

This record describes frozen fixtures, not the latest upstream script versions.
The original Builder cohort contains ten script fixtures: eight positive setup candidates and
two negative candidates (eloot and Bigshot), also exercised with
explicit test-only source repairs. These ten fixtures are not a total-corpus
compatibility count or the full current fixture inventory. Separate fixtures below
cover tpick, manatimer, repository v2.76, sail2, gemstonev/highlight-manager and the
source refresh (abyssx, compass_and_wings, newer eloot and Bigshot provenance).
Setup acceptance remains distinct from whole-script gameplay acceptance.
The setup fixtures keep the retained source lines byte for byte but are not
whole upstream files: most add synthetic enclosing wrappers, and a few carry the
boundary edits listed per fixture below. Each entry records the original source
identity (whole-script and retained-class SHA-256) separately from the fixture
file's own SHA-256.

Byte-pinned files and line endings

`.gitattributes` in this directory marks `*_setup.lic` and `css-provenance.json`
`-text`, so Git never converts their line endings on checkout or commit. The
setup fixtures are digest-checked as stored bytes (LF, CRLF or mixed), and
`css-decoration.json` records the whole-file SHA-256 of `css-provenance.json`.
The other JSON fixtures escape CR inside their strings, so their parsed block
hashes do not depend on checkout line endings.

Attribution

Settled direction B5: each script-derived test identifies the script, the tested
version (or the exact source revision when the source states none) and the
credited author. These records support that citation; they do not replace it.
Names are as the pinned source header writes them; email addresses and AI-tool
credits are omitted, nothing is inferred, and the header at the pinned revision
is the full record. "Not stated" means the header has no such field.
CSS corpus scripts: see each record's `attribution` in `css-decoration.json`.

- bigshot (EO 7fd0b971, scripts/bigshot.lic, header lines 7-11): version 5.16.1;
  author elanthia-online; contributors SpiffyJr, Tillmen, Kalros, Hazado, Tysong,
  Athias, Falicor, Deysh, Nisugi. The refresh source (EO c4a96840) is 5.17.0 with
  the same credits.
- BlackArts (EO 7fd0b971, lines 5-9): version 1.3.6; author elanthia-online;
  contributors Deysh, Tysong, Gob.
- ebounty (EO 7fd0b971, lines 8-13): version 1.12.3; author elanthia-online;
  contributors Deysh, Nisugi, Tysong, Rinualdo.
- ecleanse (EO 7fd0b971, lines 4-9): version 2.3.6; author Deysh; contributors
  Tysong.
- eherbs (EO 7fd0b971, lines 12-17): version 2.2.1; author Elanthia-Online;
  contributors Tillmen, Tysong, Doug, Rinualdo, Xanlin, Deysh.
- eloot (EO 7fd0b971, lines 10-18): version 2.11.9; author elanthia-online;
  original author SpiffyJr (sloot); maintainer elanthia-online; contributors
  SpiffyJr, Athias, Demandred, Tysong, Deysh, Ondreian, Lieo, Lobe, Etheirys.
  The refresh source (EO c4a96840) is 2.13.0 with the same credits.
- ewaggle (EO 7fd0b971, lines 6-11): version 2.1.6; author elanthia-online;
  contributors Tillmen, Tysong, Deysh.
- go2 (EO 7fd0b971, lines 8-13): version 2.4.0; author Tillmen; original author
  Shaelun; contributors Deysh, Doug, Gildaren, Sarvatt, Tysong, Xanlin,
  Dissonance, Drafix.
- repository (EO 7fd0b971, lines 8-13): version 2.74; author elanthia-online;
  maintained by Tillmen, EO team, SpiffyJr. The scheduling source (EO c4a96840)
  is 2.76 with the same credits.
- huntplan: author and version not established. The fixture retains no header,
  the local lich_repo_mirror `lib/huntplan.lic` is empty at every revision that
  touches it, no local EO scripts revision has the file, and no local copy matches
  whole-script SHA-256 37a6af449da8f8bbf26cc63d8b714d52099c87fe994dabeddeac6f07a5fbd726,
  which is the tested source identity.
- tpick (mirror 2fa28f1e, lib/tpick.lic, lines 17-18): version 48; author Dreaven.
- manatimer (mirror 2fa28f1e, lines 13-14): version 0.1; author Drafix.
- sail2 (mirror 2fa28f1e, lines 2 and 30): version 1.0.8; no author field; the
  header is signed Peggyanne.
- gemstonev (mirror 2fa28f1e, lines 14-15): version 3; author Dreaven.
- highlight-manager (mirror 2fa28f1e, lines 37-39): version 1.2.0; author
  Mystienne; contributors Peggyanne, Eternil.
- abyssx (mirror 2fa28f1e, lines 2-3): version 3.0; author Hexbane.
- compass_and_wings (mirror 2fa28f1e, lines 97-99): header version 2.2.0
  (VERSION constant 1.6.11, line 109); authors Khaell, Ruseoffools.

EO 7fd0b971 is 7fd0b971387492cfd81b4bc7ef94428413965071, EO c4a96840 is
c4a96840ea2a29a445fd797c7baec0b012b0dd12 and mirror 2fa28f1e is
2fa28f1e540e97c468af88bbc8c432d3cebf8755.

CSS decoration cohort (separate from the ten setup fixtures)

`css-decoration.json` retains 71 stylesheet payloads from the cached 33-script
provider cohort, covering 66 load sites. It is not another full setup fixture.
All source hashes match `css-provenance.json`, using EO revision
`7fd0b971387492cfd81b4bc7ef94428413965071` and mirror revision
`549e33506e121453e3c01cfe5df46a902f44fc5f`. Paths, line ranges, raw call shapes,
payload hashes and all interpolation/assembly substitutions are recorded inside.
Its top-level `fields` object documents every key, unit and status value;
`source` is the stable repository identifier ("eo" or "mirror") and `revision`
the full pinned commit. `audit_sha256` is the SHA-256 of `css-provenance.json`,
which the corpus spec asserts.

`spec/support/build_css_decoration_corpus.rb` rebuilds it from only those pinned
Git blobs, including `fields`, `source` and each record's `attribution` (read from
the pinned source header). Its output must equal the committed file byte for
byte. With local clones of elanthia-online/scripts and lich_repo_mirror, run
`ruby spec/support/build_css_decoration_corpus.rb EO_REPO MIRROR_REPO | cmp - spec/fixtures/webui/css-decoration.json`,
or set CSS_CORPUS_EO_REPO and CSS_CORPUS_MIRROR_REPO for the corpus spec's
rebuild example (skipped otherwise).
Prism decodes selected strings; extraction never evaluates source Ruby.
The corpus spec uses only this retained artifact and runs reviewed CSS-only
excerpts from eleven sources, with explicit test widget/settings bindings. It
does not execute game loops, downloads, persistence, or excluded Builder setup.
The original tpick HeaderBar constructor and manatimer Display chain now succeed.
The CSS evidence remains separate from setup acceptance below.

The Chrome progress harness loads the retained tpick global and label CSS, but
does not render the original tpick setup. The retained corpus records measured
sizes, dispositions, sample-versus-maximum limits and omissions.
No script source was repaired for this acceptance.

tpick setup fixture (separate from the ten Builder setup fixtures)

`tpick-titlebar.json` retains unchanged GUI/persistence methods, constants,
stylesheet and setup-data/default/tooltip blocks from mirror `lib/tpick.lic` v48
at `2fa28f1e540e97c468af88bbc8c432d3cebf8755`. Each block/method carries its
source SHA-256 and original line range. No source repairs are applied.
`script_scope_header_bar_spec.rb` uses its first eight methods for narrow tests;
`script_scope_tpick_setup_spec.rb` exercises the broader original default flows.
The harness substitutes only game-facing character/profession/spell/inventory
answers, message/running boundaries and temporary settings destinations. It does
not execute top-level initialization, downloads, Scan/game commands or gameplay.
Settings coverage includes Rogue/Warrior/Bard/Wizard, all their tabs, original
profile/default/save behavior and required-setting colors. Information coverage
includes deferred stats tabs, message updates, Start flag and close/save cleanup.
Native WKWebView and Chrome acceptance results are recorded in the handoff.
Negative cases retain spell-less Monk/Paladin's absent Spells grid and optional
image mode's first unsupported window call. Image mode is an owner-deferred PR.

ecleanse setup fixture

`ecleanse_setup.lic` is byte-identical to the `Ecleanse::Setup` module at lines 267-623 of
[`scripts/ecleanse.lic` at 7fd0b971387492cfd81b4bc7ef94428413965071](https://github.com/elanthia-online/scripts/blob/7fd0b971387492cfd81b4bc7ef94428413965071/scripts/ecleanse.lic).
It includes the complete XML and original settings, change, Close and destroy
handlers. Do not simplify the XML or rewrite callbacks to accommodate the shim.

Provenance checks:

- Original whole-script SHA-256: `64e7b1d920bed944b8b33bf9a192c13bb23289d932e6873f38d61579971da4bf`.
- Fixture file SHA-256: `6ae8038eef18f3325811c486b5b1068cf32f174bf029a69841bca99c46026061`
  (no wrapper; identical to the retained source lines).
- `Setup.ui` SHA-256: `1dec1310d30d6b3f1e34beb7a39aeccdffdd6da70e87c476818759405be13eea` (25,513 bytes).
- The Builder regression asserts the XML digest and 54 constructed objects.

The RSpec harness supplies inert game lookups, a temporary settings directory and
message capture; it does not execute the script's game loop. Unit tests exercise
initialization, changes and close lifecycle. The explicit Chrome run drives the
same controls and original callbacks through the production WebUI transport.
Passing these tests demonstrates setup support, not whole-script gameplay or
native desktop-window parity.

ewaggle setup fixture

`ewaggle_setup.lic` is byte-identical (CRLF) to the setup section at lines 199-633
of EO `scripts/ewaggle.lic` at 7fd0b971 (line 634 is a blank line, not retained),
including Builder XML, original initialization, signals,
list-transfer handlers and save/destroy behavior. No callbacks were rewritten.
Whole-script SHA-256: fe74b93bbc73ce83981ff8e23dba11dcc0e51a905454685afb39988eb87726e4.
Fixture file SHA-256: 1156f420986c07c7f0a9472dc6215934318693b43eb30376c1dc7b05f24b7097 (no wrapper).
Setup.ewaggle_ui SHA-256: c617157ee342adb4bfcb9d3281de5d63c17ef777d4f75fcad60544ec6049eddf
(28,928 bytes; 77 constructed objects).
The harness substitutes game lookups and Ewaggle.save_profile's destination only.
Chrome exercises prefix search, cross-list drag/drop, same-list duplication,
named ComboBox selection, numeric edits and the original Close callback.
Ruby also verifies destruction without saving and unsupported input refusal.
These checks establish setup behavior, not casting-loop or whole-script acceptance.

ebounty, eherbs, eloot and BlackArts setup fixtures

These retain the original Setup classes byte for byte from the same frozen EO
script tree (7fd0b971387492cfd81b4bc7ef94428413965071), inside synthetic LF
enclosing module/GTK-guard wrapper lines added for isolated loading. XML,
initialization and callbacks are not rewritten. The retained class line ranges,
original class and whole-script SHA-256 values, wrapper lines on each side and
fixture file SHA-256 are:

- ebounty: lines 1151-2033; class ea8e307083274d54569f48364fd1add9dcf41f1069733b77162136fe67db08c3;
  whole script 9cb9dafe5941f8336a51006846b0c86b712cca2b2340ea1e1c042e7ede781ab7; 435 objects;
  1 wrapper line on each side; fixture c4132f9f43c7d4de0057b696855a66159dcd16d3e936d418e908c5af1baf4123.
- eherbs: lines 525-823; class 154a35392391da1a7869545ec3afbac170c3f3c2660a537570138d1ab2802535;
  whole script 6feecbcec73718d8127432187f3453e06020ba52dc5f312efd4e9dcac5fe5083; 31 objects;
  2 wrapper lines on each side; fixture 8f71513ad9a67c426449858de39180818be0f6be959a24bb0f987bde219ea62c.
- eloot: lines 720-1926; class 903ec1942b966626de0644d2c2ade7d5e4e5f02e7fd743bd7306aa7492f34077;
  whole script 1e1d5c5bc5e845f47821d1fe0b676b08cdbd139e83f8c594ff221e6cc707a349; 469 objects;
  2 wrapper lines on each side; fixture 629e8f9f1b845f5348068a5ba75c42bd74006d5c59e45bf218c6cc2d5d4a00e0.
- BlackArts: lines 5282-6045; class 2d76eedd2e65a8bc6546e07fc0f84610cf2d4b8c9171edabbebce4c357e9526c;
  whole script 15932bdd0fa9efcd0a4a13222ebbc3032dda22db8ab28c3effd542349c828703; 216 objects;
  1 wrapper line on each side; fixture 26af20469bba5ede53ba49d3fd62d13a840068d35de31c43eabd0d27a9256744.

The harness substitutes only game catalogs, character availability, profile
discovery, message capture and persistence destinations. ebounty/eherbs/BlackArts
each have independent browser examples and original Close/destroy checks.
ebounty/BlackArts retain source uniq!.sort! chains; subprocess tests load Lich's
actual NilClass extension without changing the parent RSpec process. Removing
that production extension will require source migration; it is not shim support.
eloot is a negative fixture: its XML never declares exclusions_label, so tooltip
initialization must report BuilderError even with nil suppression present.
Unhandled queued Builder failures close the owner's UI and request the existing
asynchronous script stop. No widget is fabricated.

The preserved native WebUI versions of all three positive fixtures were reviewed
for reusable behavior. Their settings and script-specific form code remain out
of the shim. These tests do not execute game loops, certify all settings paths,
or assert native desktop-window/pixel parity.

Scheduling source acceptance (PR 4)

scheduling.json adds exact cached source blocks alongside the older fixtures below:
- EO repository v2.76 Setup, lines 890-1069, revision
  c4a96840ea2a29a445fd797c7baec0b012b0dd12.
- Mirror sail2 config branch, lines 789-875, revision
  2fa28f1e540e97c468af88bbc8c432d3cebf8755.
- Mirror gemstonev difficulty-window method, lines 1754-1796, same mirror revision.
The JSON records whole-file and block SHA256 hashes; mirror blocks retain CRLF bytes.
RSpec checks block hashes before evaluating with original filenames/line numbers.
No original source is modified. Repository receives synthetic listing rows and a
captured Script.start. Its ten-second timer executes unchanged. Sail2's nil/Idle/
wait-until-nil startup race is an explicit negative test. Positive setup/save tests
replace only its initial nil with :pending, visibly in the test harness. Persistence
and game functions are captured; the sailing loop is outside the extracted block.
The owner expanded PR 4 to inherited sensitivity and retained Window#hide/show.
Chrome and native WebKit verify the selector disables/re-enables while retaining
its value, captured Save succeeds, and the original Close callback hides/destroys.
A separate generic fixture hides for two seconds, then reuses the same window
and input draft. Sail2's original startup failure remains an explicit negative case.
Gemstonev runs its complete unchanged difficulty method. Its game command is
captured; the 50ms timer repeats until synthetic game data arrives, then hands off
once and stops. Main-window creation is captured, not accepted as a whole-script
run. Browser/native checks close the fixture at that handoff.

repository and go2 setup fixtures

These retain the complete Setup classes byte for byte from the same frozen EO
source tree, including original XML, initialization, filtering/settings
callbacks and Close. Synthetic LF enclosing module/class/GTK-guard wrapper lines
are added for isolated loading. Class hashes exclude wrappers and the trailing
newline and are checked in RSpec; the fixture file SHA-256 covers the wrappers.

- repository: lines 880-1042; class ac0107e3149a487f61cfd345a3b962b7673df65ec99921f4b9fdd74d47dd86e5;
  whole script d46a023aaac5f96c1395b89727d0640cee69a91a9103853353de3a1389fe1aa0;
  3 wrapper lines on each side; fixture 7c20377fbc3ca5a0355ac978af1fcce8e4a81ddf31754fbebc7cb8ba219f9dff.
- go2: lines 474-842; class 8bdcf8959473c59d9da2eba4dbc69a2dd13185acd9a3c556288b1bd8198862b2;
  whole script e4763e1fd11ee2645409067dd5ed3463d7e6f8fd48595ae01b19d4aea04237a6;
  2 wrapper lines on each side; fixture 8f51c6313e1f0349acc1e6d635da40817519148068c32599a091760fc4768a8a.

Repository's basic Ruby case receives two inert listing records. Additional
cases supply long comments and enough synthetic rows to overflow the viewport.
Its original download handler is captured at Script.run, so no download occurs.
Tests verify numeric model sorting,
filtering, single-click activation, command construction and Close/cleanup.
Go2 receives inert GS/DR character data and an in-memory Go2.load destination.
Go2's GS and DR layouts run original setup, updates and Close/destroy callbacks in
Ruby and independent Chrome cases; repository has its own GS case.
No travel, repository network operation or gameplay
loop executes. Converted WebUI counterparts informed acceptance behavior only;
no converted business logic or script-name rendering cases enter the shim.

bigshot and huntplan setup fixtures

These retain Setup class excerpts inside one synthetic LF module wrapper line on
each side. They are not exact upstream bytes: the class boundary lines were
edited as listed below; the class body between them is retained byte for byte.
Original XML, construction and callbacks are digest-checked before execution.
The two fixtures preserve upstream formatting; RuboCop Layout exclusions and
Huntplan's unused local exclusion apply only to these excerpts, not product or
harness code.

- bigshot: frozen EO original, lines 1300-2704;
  class da564437b0eb893e8abd3757afdbbe35bd57b4b134d24e562e4f17d1af76ad34;
  whole script f96ac381aa1f09f248f79de486bf236fa4ae558d3231ad90941333dd4e3f2873;
  fixture 96f776df5e26ba41feac6d26e95717cf43999b48d7e3b6919537ba6c750d342b.
  Boundary edits: fixture line 2 drops the upstream two-space indent of
  `class Setup`, and the class-closing `end` is LF where upstream is CRLF.
- huntplan: retained original, lines 1992-2112;
  class 14d3be8481c1d1abc76cf7394c9dc7d7fb4aca8966b33fb4d3940f9bcabf92a5;
  whole script 37a6af449da8f8bbf26cc63d8b714d52099c87fe994dabeddeac6f07a5fbd726;
  fixture 9667d7039ea72d4d835673085406fc7f8efa03391efedaf59e58c90cd1c5ab07.
  Boundary edit: the class-closing line 122 is LF inside a CRLF body. The
  upstream source is not available locally, so its bytes were not re-compared.

Huntplan's original setup, input limits, invalid-slot refusal, Save & Exit and
cleanup run in Ruby and Chrome with inert game data and in-memory persistence.
Bigshot's retained original source fails on the undeclared boon_flee_from
tooltip target before connecting its XML signals. This is an expected source
failure, not successful Bigshot acceptance. Its converted version was inspected
as a behavior reference; converted business logic is not copied into the shim.

Explicitly corrected eloot/Bigshot acceptance candidates

webui_builder_source_repairs.rb applies exact-match substitutions only while
loading separately labeled positive tests. Fixture files remain untouched.
eloot names its existing Exclusions label exclusions_label; Bigshot removes
the obsolete tooltip assignment and replaces its legacy boon-flag migration.
Source digests are checked before these substitutions. The unchanged negative
tests remain mandatory, so candidate success does not hide production defects.

Corrected eloot exercises all twelve list add/delete handlers, scalar entry/spin
settings, tipping-preview dispatch with isolated calculation/formatting, dependent
controls, Close/save and destroy without save. Corrected Bigshot exercises scalar
and text-area callbacks, boon selection/migration, profile load/new/overwrite/
cancel/update, Close/save and destroy without save. Both also run in Chrome.
This establishes setup/UI acceptance for those explicit repairs, not live-game
behavior or proof that an upstream author has adopted the same repairs.

Manatimer progress/overlay fixture

`manatimer.json` retains unchanged v0.1 blocks from mirror `lib/manatimer.lic` at
`2fa28f1e540e97c468af88bbc8c432d3cebf8755`, with source and block SHA-256 hashes.
Focused controls tests run 50-75 and 80-96 separately. Full setup acceptance also
runs unchanged 49-97, including monitor restoration 76-79. It runs the original
queued countdown 176-182 and before_dying cleanup 101-116 against isolated settings
with a saved position. Missing position and the ignored monitor origin remain
source limitations, not shim repairs.
No source rewriting, game loop, pulse catcher, real GTK or live settings writes.
The browser adds harness buttons to drive original updates and end the fixture;
right-click executes the original callback. This is not whole-script acceptance.

Geometry/cursor fixture

`geometry-cursors.json` retains unchanged gemstonev and highlight-manager excerpts
from mirror revision `2fa28f1e540e97c468af88bbc8c432d3cebf8755`, with whole-source
and block SHA-256 hashes. Gemstonev lines 37-39, 52-56 and 710-715 provide cursor
names, primary geometry and cursor assignment; highlight-manager 4275-4316 provides
the guarded hand-cursor helpers. Tests evaluate only these blocks against the shim,
not full scripts or game state. See `script_scope_geometry_cursor_spec.rb`
for the accepted methods and fallback boundaries.

Pinned source refresh (2026-10-12 source revisions; merged in PR #56)

`source-refresh.json` records whole-script hashes and exact, independently hashed
source blocks. EO revision c4a96840ea2a29a445fd797c7baec0b012b0dd12 and mirror
revision 2fa28f1e540e97c468af88bbc8c432d3cebf8755 are fixed provenance, not a
claim that these are the latest upstream versions.

- Bigshot v5.17.0 Setup, lines 955-2359, is byte-identical to bigshot_setup.lic's
  original class (including CRLF). The manifest links the new whole-source hash
  to the existing fixture; no duplicate Setup is needed. The original missing
  boon_flee_from failure and separately corrected candidate remain unchanged.
- eloot v2.13.0 Setup, lines 742-1948, replaces loot_defensive with loot_stance.
  The refreshed original still fails on exclusions_label. Its separately labeled
  positive candidate applies only the existing exact-match label-ID repair and
  checks seven stance IDs, restored/default values, changes and saved settings.
  The historical eloot fixture remains separate. Setup acceptance does not run
  the outer profile migration or looting logic.
- AbyssX v3.0 uses exact constants (32-36) and SetupGUI (56-195). Tests run the
  original queue, fields, radio group, source coercions, save/cancel and nested
  destroy callbacks. Only settings load/save, Vars and script-host wait/message
  boundaries are isolated. The arena runner, entry fees and combat never run.
- compass_and_wings retains constants (109-152) and settings/helpers/setup
  (1015-1357). The header says 2.2.0 while VERSION says 1.6.11; neither is rewritten.
  Original settings normalization, validation, scrolling, save, close/cancel and
  before_dying behavior run against in-memory Settings and an isolated script host.
  load_settings itself persists normalized initial settings; cancel avoids saving
  later edits, not that initial source-defined write. No combat or game commands run.

Ruby examples use the actual owner dispatcher. Browser examples use the same
original sources and validate AbyssX saving, compass validation/scrolling/saving,
and the explicitly repaired eloot stance selector. Source and callback diagnostics
remain observable failures. These are setup-flow checks, not whole-gameplay claims.
Those three browser flows also passed actual macOS WebKit checks; native cancel
was not separately exercised in that pass. Ruby covers cancellation and cleanup.
The separate GTK/shim/native Bigshot preview used repaired setup candidates for
GTK and shim; visual similarity does not convert the original failure into a pass.
