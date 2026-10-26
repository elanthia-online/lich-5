WebUI setup fixture provenance and acceptance boundaries

This record describes frozen fixtures, not the latest upstream script versions.
The original Builder cohort contains ten script fixtures: eight unchanged positive setup candidates and
two unchanged negative candidates (eloot and Bigshot), also exercised with
explicit test-only source repairs. These ten fixtures are not a total-corpus
compatibility count or the full current fixture inventory. Separate fixtures below
cover tpick, manatimer, repository v2.76, sail2, gemstonev/highlight-manager and the
source refresh (abyssx, compass_and_wings, newer eloot and Bigshot provenance).
Setup acceptance remains distinct from whole-script gameplay acceptance.

CSS decoration cohort (separate from the ten setup fixtures)

`css-decoration.json` retains 71 stylesheet payloads from the cached 33-script
provider cohort, covering 66 load sites. It is not another full setup fixture.
All source hashes match `css-provenance.json`, using EO revision
`7fd0b971387492cfd81b4bc7ef94428413965071` and mirror revision
`549e33506e121453e3c01cfe5df46a902f44fc5f`. Paths, line ranges, raw call shapes,
payload hashes and all interpolation/assembly substitutions are recorded inside.

`spec/support/build_css_decoration_corpus.rb` rebuilds it from only those pinned
Git blobs. Prism decodes selected strings; extraction never evaluates source Ruby.
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

Unchanged ecleanse setup fixture

`ecleanse_setup.lic` is the exact `Ecleanse::Setup` module at lines 267–623 of
[`scripts/ecleanse.lic` at 7fd0b971387492cfd81b4bc7ef94428413965071](https://github.com/elanthia-online/scripts/blob/7fd0b971387492cfd81b4bc7ef94428413965071/scripts/ecleanse.lic).
It includes the complete XML and original settings, change, Close and destroy
handlers. Do not simplify the XML or rewrite callbacks to accommodate the shim.

Provenance checks:

- Original whole-script SHA-256: `64e7b1d920bed944b8b33bf9a192c13bb23289d932e6873f38d61579971da4bf`.
- `Setup.ui` SHA-256: `1dec1310d30d6b3f1e34beb7a39aeccdffdd6da70e87c476818759405be13eea` (25,513 bytes).
- The Builder regression asserts the XML digest and 54 constructed objects.

The RSpec harness supplies inert game lookups, a temporary settings directory and
message capture; it does not execute the script's game loop. Unit tests exercise
initialization, changes and close lifecycle. The explicit Chrome run drives the
same controls and original callbacks through the production WebUI transport.
Passing these tests demonstrates setup support, not whole-script gameplay or
native desktop-window parity.

Unchanged ewaggle setup fixture

`ewaggle_setup.lic` is the exact setup section (lines 199–634) of the retained
original GTK script, including Builder XML, original initialization, signals,
list-transfer handlers and save/destroy behavior. No callbacks were rewritten.
Whole-script SHA-256: fe74b93bbc73ce83981ff8e23dba11dcc0e51a905454685afb39988eb87726e4.
Setup.ewaggle_ui SHA-256: c617157ee342adb4bfcb9d3281de5d63c17ef777d4f75fcad60544ec6049eddf
(28,928 bytes; 77 constructed objects).
The harness substitutes game lookups and Ewaggle.save_profile's destination only.
Chrome exercises prefix search, cross-list drag/drop, same-list duplication,
named ComboBox selection, numeric edits and the original Close callback.
Ruby also verifies destruction without saving and unsupported input refusal.
These checks establish setup behavior, not casting-loop or whole-script acceptance.

Unchanged ebounty, eherbs, eloot and BlackArts setup fixtures

These retain the original Setup classes from the same frozen EO script tree
(7fd0b971387492cfd81b4bc7ef94428413965071), with only enclosing module/GTK-guard
wrappers needed for isolated loading. XML, initialization and callbacks are not
rewritten. The retained class line ranges and SHA-256 values are:

- ebounty: lines 1151–2033; class ea8e307083274d54569f48364fd1add9dcf41f1069733b77162136fe67db08c3;
  whole script 9cb9dafe5941f8336a51006846b0c86b712cca2b2340ea1e1c042e7ede781ab7; 435 objects.
- eherbs: lines 525–823; class 154a35392391da1a7869545ec3afbac170c3f3c2660a537570138d1ab2802535;
  whole script 6feecbcec73718d8127432187f3453e06020ba52dc5f312efd4e9dcac5fe5083; 31 objects.
- eloot: lines 720–1926; class 903ec1942b966626de0644d2c2ade7d5e4e5f02e7fd743bd7306aa7492f34077;
  whole script 1e1d5c5bc5e845f47821d1fe0b676b08cdbd139e83f8c594ff221e6cc707a349; 469 objects.
- BlackArts: lines 5282–6045; class 2d76eedd2e65a8bc6546e07fc0f84610cf2d4b8c9171edabbebce4c357e9526c;
  whole script 15932bdd0fa9efcd0a4a13222ebbc3032dda22db8ab28c3effd542349c828703; 216 objects.

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
- EO repository v2.76 Setup, lines 890–1069, revision
  c4a96840ea2a29a445fd797c7baec0b012b0dd12.
- Mirror sail2 config branch, lines 789–875, revision
  2fa28f1e540e97c468af88bbc8c432d3cebf8755.
- Mirror gemstonev difficulty-window method, lines 1754–1796, same mirror revision.
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

Unchanged repository and go2 setup fixtures

These retain the complete Setup classes from the same frozen EO source tree,
including original XML, initialization, filtering/settings callbacks and Close.
Only enclosing module/class/GTK-guard wrappers are supplied for isolated loading.
Class hashes exclude wrappers and the trailing newline and are checked in RSpec.

- repository: lines 880–1042; class ac0107e3149a487f61cfd345a3b962b7673df65ec99921f4b9fdd74d47dd86e5;
  whole script d46a023aaac5f96c1395b89727d0640cee69a91a9103853353de3a1389fe1aa0.
- go2: lines 474–842; class 8bdcf8959473c59d9da2eba4dbc69a2dd13185acd9a3c556288b1bd8198862b2;
  whole script e4763e1fd11ee2645409067dd5ed3463d7e6f8fd48595ae01b19d4aea04237a6.

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

Unchanged bigshot and huntplan setup fixtures

These retain exact Setup class excerpts with enclosing module wrappers. Original
XML, construction and callbacks are digest-checked before execution. The two
fixtures preserve upstream formatting; RuboCop Layout exclusions and Huntplan's
unused local exclusion apply only to these excerpts, not product or harness code.

- bigshot: frozen EO original, lines 1300-2704;
  class da564437b0eb893e8abd3757afdbbe35bd57b4b134d24e562e4f17d1af76ad34;
  whole script f96ac381aa1f09f248f79de486bf236fa4ae558d3231ad90941333dd4e3f2873.
- huntplan: retained original, lines 1992-2112;
  class 14d3be8481c1d1abc76cf7394c9dc7d7fb4aca8966b33fb4d3940f9bcabf92a5;
  whole script 37a6af449da8f8bbf26cc63d8b714d52099c87fe994dabeddeac6f07a5fbd726.

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
Focused controls tests run 50–75 and 80–96 separately. Full setup acceptance also
runs unchanged 49–97, including monitor restoration 76–79. It runs the original
queued countdown 176–182 and before_dying cleanup 101–116 against isolated settings
with a saved position. Missing position and the ignored monitor origin remain
source limitations, not shim repairs.
No source rewriting, game loop, pulse catcher, real GTK or live settings writes.
The browser adds harness buttons to drive original updates and end the fixture;
right-click executes the original callback. This is not whole-script acceptance.

Geometry/cursor fixture

`geometry-cursors.json` retains unchanged gemstonev and highlight-manager excerpts
from mirror revision `2fa28f1e540e97c468af88bbc8c432d3cebf8755`, with whole-source
and block SHA-256 hashes. Gemstonev lines 37–39, 52–56 and 710–715 provide cursor
names, primary geometry and cursor assignment; highlight-manager 4275–4316 provides
the guarded hand-cursor helpers. Tests evaluate only these blocks against the shim,
not full scripts or game state. See `script_scope_geometry_cursor_spec.rb`
for the accepted methods and fallback boundaries.

Pinned source refresh (2026-10-12 source revisions; merged in PR #56)

`source-refresh.json` records whole-script hashes and exact, independently hashed
source blocks. EO revision c4a96840ea2a29a445fd797c7baec0b012b0dd12 and mirror
revision 2fa28f1e540e97c468af88bbc8c432d3cebf8755 are fixed provenance, not a
claim that these are the latest upstream versions.

- Bigshot v5.17.0 Setup, lines 955–2359, is byte-identical to bigshot_setup.lic's
  original class (including CRLF). The manifest links the new whole-source hash
  to the existing fixture; no duplicate Setup is needed. The original missing
  boon_flee_from failure and separately corrected candidate remain unchanged.
- eloot v2.13.0 Setup, lines 742–1948, replaces loot_defensive with loot_stance.
  The refreshed original still fails on exclusions_label. Its separately labeled
  positive candidate applies only the existing exact-match label-ID repair and
  checks seven stance IDs, restored/default values, changes and saved settings.
  The historical eloot fixture remains separate. Setup acceptance does not run
  the outer profile migration or looting logic.
- AbyssX v3.0 uses exact constants (32–36) and SetupGUI (56–195). Tests run the
  original queue, fields, radio group, source coercions, save/cancel and nested
  destroy callbacks. Only settings load/save, Vars and script-host wait/message
  boundaries are isolated. The arena runner, entry fees and combat never run.
- compass_and_wings retains constants (109–152) and settings/helpers/setup
  (1015–1357). The header says 2.2.0 while VERSION says 1.6.11; neither is rewritten.
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
