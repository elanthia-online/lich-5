# Ruby4Lich5 gem recovery manifest

`Lich::GemCheck` reads `R4L5-gem-manifest.json` on every Windows startup,
before application dependency activation. The default location is the released
`R4L5-gem-bundle-x64-mingw-ucrt` asset; development may override it with
`LICH_GEM_MANIFEST_URL`.

The manifest is an allow-list, not a dependency resolver. Every recoverable
gem must be mapped to a specific package or ordered bundle unit. Lich accepts
only the exact Ruby ABI and platform of the running runtime, HTTPS URLs, and
lowercase SHA-256 digests in `sha256:<hex>` form.

## Shared Windows version contract

`Gemfile` and `Gemfile.lock` at an explicitly selected full lich-5 commit are
the version authority for non-GTK Windows packages, including transitive
dependencies. Ruby4Lich5 owns GTK versions and packaging. The producer vendors
`lib/runtime_gem_contract.rb` from that commit; the reader uses static Gemfile
declarations and lock checksums without evaluating Gemfile plugins or running
Bundler. Default and profanity roots apply to Windows. Development, VS Code
and GTK groups do not enter this version contract. Unsupported dynamic runtime
declarations fail the check and require an explicit reader update.

The Windows target's `contract` object has `schema: 2`, `lich5_commit` (40
lowercase hex characters), `gemfile_sha256`, `lock_sha256`, `promotable: true`,
`overrides: {}`, `windows_contract_sha256`, and `ruby_inventory`. All three
digests are bare lowercase SHA-256 hex strings. The raw file digests identify
the producer input bytes for provenance; they are not consumer eligibility gates. `ruby_inventory` records the pristine target RubyInstaller's
`ruby_version`, `ruby_abi`, `platform`, and `gems` mapping. Each supplied gem
records `version` and `dependencies` (a name-to-requirement-array mapping).
This inventory must be measured before application gems are installed.
Supplied versions are checked against dependency requirements and differences
from the lock are reported; those gems are not shipped to hide a difference.
The reader selects the UCRT variant before a generic Ruby variant, so Windows
sqlite3 uses its upstream binary and excludes source-only mini_portile2.

The contract also carries producer-owned `build_roles.gtk`, an array of package
names in the tested GTK build role. Listed packages are exempt from the consumer
lock version/checksum comparison because Ruby4Lich5 owns that role's versions.
Non-GTK packages reached only through GTK remain lock-governed unless explicitly
assigned to that producer-owned role. The exemption does not bypass unit shape,
RubyInstaller-supplied package exclusion, manifest/contract digest checks or
installer provenance verification. Packages outside the role retain exact lock
version enforcement.

`.github/scripts/check_r4l5_contract.rb` checks all non-GTK Windows closure versions
against the served recovery manifest and requires a matching installer
predecessor. The published `installer-provenance.json` must carry
`runtime_contract_sha256` (the canonical contract digest from
`Lich::RuntimeGemContract.digest`), `recovery_manifest_sha256` (the exact served
manifest bytes), `ruby_installer_version`, and `installer_sha256`. All four
digests use bare lowercase hex. Existing installer provenance fields remain.
`--installer PATH` also verifies the executable before release attachment.
`--manifest PATH --provenance PATH` supports offline validation. This is a
build/release check; it does not install gems or change startup recovery.

The CI contract job always reports and is included in `ci-gate`. Stable and
prerelease workflows recheck before Release Please can write, and verify the
downloaded installer before attaching it. Manual asset rebuilds check the
target tag's Gemfile and lock before uploads, using the workflow checkout's
checker. Skipping installer attachment does not bypass the recovery check.

Release order: prepare the candidate lock, have an administrator select its
full SHA in Ruby4Lich5, promote tested recovery and publish its matching tested
installer, then rerun the lich-5 check before accepting/releasing the consumer.
The effort-3 producer PR requires Ruby4Lich5 PR #47 to merge first. The consumer
PR must wait for that producer's accepted recovery and installer. PR activity
does not dispatch privileged producer work.

The producer validates the selected candidate SHA explicitly. Both producer and
consumer compute `RuntimeGemContract#windows_contract_digest` with the measured
`ruby_inventory`, producer `build_roles`, and the flattened candidate-applicable
recovery-unit member names as `advertised_members` (after strict range selection
when ranges are present). The method hashes a versioned Windows projection:
normalized runtime root requirements, relevant selected Windows lock packages
(including checksums and normalized dependency requirements), supplied-gem
resolution and the pristine target inventory. Relevant packages include runtime
closure packages and advertised GTK-only non-GTK lock members. Producer-owned GTK
role members remain exempt from lock pinning. Unused development entries,
non-Windows variants and source comments do not enter eligibility. Changing an
applicable version, checksum or requirement does change eligibility even when the
old selected version would still satisfy a changed requirement.

Schema 2 requires this semantic digest and retains the full candidate SHA and raw
Gemfile/lock hashes for provenance. A normal merge or dev-only edit may change
consumer bytes without changing eligibility. `--candidate-sha SHA` still requires
the selected producer identity. Schema 1 contracts are rejected rather than
silently reinterpreted: the paired Ruby4Lich5 #48 producer change must vendor this
reader, emit schema 2 and its digest, and preserve provenance/installer binding.
Publish matching accepted recovery and installer before clearing consumer gates.
Do not add equality with the superseded main lock to producer promotion:
supported consumers retain coverage/recovery gates while the selected candidate
supplies new exact versions. This avoids a circular handoff.

Single-package units that require no local build use original rubygems.org
files and lock digests. Complete multi-package closures retain the ZIP
exception. Built/repacked packages have new digests tied to producer smoke
evidence. The installer must acquire both kinds from the accepted artifact
map rather than assume every file remains in the smaller ZIP. Any diagnostic
or override build is unpromotable, even if its versions happen to match.

## Startup version enforcement

The accepted manifest is Windows startup version policy. The static shared
reader reads selected Gemfile declarations without evaluating plugins or needing
a shipped lockfile. Default roots always apply; GTK also applies unless the user
passes `--no-gtk` or `--no-gui`. The build-time non-GTK contract still includes
the profanity group independently of these launch-time groups.

Lich validates every unit in the applicable ABI/platform target before selecting
required roots and their complete recovery closures. Every selected package
version is a minimum. An installed-only RubyGems resolver checks the declared
requirements, closure floors and package platforms, then Lich explicitly
activates and verifies the selected versions. Eligible newer installations remain
eligible; an already active accepted newer version is retained. RubyInstaller-
supplied roots must satisfy both their measured inventory floor and the Gemfile;
an unavailable supplied version requires reinstalling Ruby4Lich5.

A working older gem triggers repair even when no gem is missing. If an older
version is already active, merely installing a fixed copy does not permit
startup to continue. Lich requests one native consent decision for all affected
complete units before downloading artifacts or changing the runtime. Refusal,
missing confirmation UI or the two-minute consent timeout stops startup and
records the reason in `temp/lich5-missing-gems.log`.

Manifest lookup and parsing have a 30-second total deadline and a 5 MiB limit;
artifact staging has a five-minute total deadline, plus per-connection/read
limits. Unavailable service, an unsupported target, invalid declarations or
invalid policy stops Windows startup with an explicit error. There is no cached
policy or offline success fallback. A healthy local gem set still requires the
accepted policy lookup.

A missing transitive dependency in an otherwise accepted installed gem is a
local installation failure: repair or reinstall Ruby4Lich5, then retry. It is
reported separately from unreachable policy, missing server coverage and
incompatible accepted versions. Lich does not download an unlisted dependency
to conceal a damaged installation. Genuine requirement conflicts remain policy
compatibility failures and retain maintainer guidance.

## Supported-client policy retention

Because Windows startup requires reachable accepted policy, promotion must
preserve startup compatibility for every explicitly supported client revision,
including its roots, manifest schema, target ABI/platform and requirements.
A new client declaration or dependency floor must not silently withdraw policy
coverage or invalidate requirements for a still-supported older client. Retain
that client's compatible policy and recovery coverage until maintainers explicitly
retire support; a new producer candidate alone does not retire an older client.
No minimum supported version or retirement date is selected here.

Producer acceptance must exercise each supported revision's own startup-policy
implementation with its declarations and the proposed manifest. Running all
historical declarations through the newest reader is insufficient. Clients that
predate online startup policy require their pinned legacy recovery checks rather
than a claim that they implement the new policy. The paired producer enforcement
belongs in Ruby4Lich5 #50; this consumer documentation does not establish that
those per-version acceptance runs have passed.

## Recovery transaction

After consent, all selected artifacts are staged and hash-verified under Lich's
`temp` directory before a runtime write. Required version repairs are forced and
always restart, including pure-gem repairs and direct native `.gem` downloads.
One hidden `rubyw.exe` helper handles the complete transaction after the original
process exits. It backs up replaced variants in the runtime gem directory,
installs and verifies exact accepted packages, probes sqlite3/GTK entry points
in a fresh bounded process when present, then relaunches the original Lich
command and arguments. Startup then selects and verifies accepted versions in
the new process. Existing newer packages are retained. Failed installation rolls
back moved files and stops without relaunching. An unwritable gem home reports
an error rather than continuing with an older version.

No second permanent GTK tree or user `GEM_HOME` is used. Staging is removed after
direct recovery or after the replacement helper completes. This policy does not
remove old Ruby installations or user-added gems.

Release order: accepted recovery artifacts and a matching installer must already
be available before this runtime change is released. Only clients that receive
this Lich update gain version enforcement; older clients continue to need the
recorded Ruby4Lich5 reinstall guidance. The producer's vendored static reader
must match the selected Lich candidate when building a new contract.

Other platforms retain their existing recovery paths: macOS may consent to
private non-GTK Bundler recovery, while Linux uses its existing missing-gem
notice. Neither fetches Windows policy at startup. GTK/headless selection is
explicit; terminal, `DISPLAY` and cron state do not implicitly select headless
operation.

```json
{
  "schema": 1,
  "targets": [
    {
      "ruby_abi": "4.0",
      "platform": "x64-mingw-ucrt",
      "units": [
        {
          "id": "sqlite3",
          "members": ["sqlite3"],
          "artifact": {
            "url": "https://rubygems.org/downloads/sqlite3-2.10.2-x64-mingw-ucrt.gem",
            "filename": "sqlite3-2.10.2-x64-mingw-ucrt.gem",
            "sha256": "sha256:<64-lowercase-hex-characters>",
            "archive": "gem"
          },
          "packages": [
            {
              "name": "sqlite3",
              "version": "2.10.2",
              "filename": "sqlite3-2.10.2-x64-mingw-ucrt.gem",
              "sha256": "sha256:<64-lowercase-hex-characters>"
            }
          ],
          "install_order": ["sqlite3"]
        },
        {
          "id": "gtk3-runtime",
          "members": ["glib2", "gobject-introspection", "gio2", "cairo", "cairo-gobject", "pango", "gdk_pixbuf2", "atk", "gdk3", "gtk3"],
          "artifact": {
            "url": "https://github.com/elanthia-online/Ruby4Lich5/releases/download/R4L5-gem-bundle-x64-mingw-ucrt/R4L5-gem-bundle-x64-mingw-ucrt.zip",
            "filename": "R4L5-gem-bundle-x64-mingw-ucrt.zip",
            "sha256": "sha256:<64-lowercase-hex-characters>",
            "archive": "zip"
          },
          "packages": [
            {
              "name": "glib2",
              "version": "4.3.6",
              "filename": "glib2-4.3.6-x64-mingw-ucrt.gem",
              "sha256": "sha256:<64-lowercase-hex-characters>"
            },
            {
              "name": "gtk3",
              "version": "4.3.6",
              "filename": "gtk3-4.3.6-x64-mingw-ucrt.gem",
              "sha256": "sha256:<64-lowercase-hex-characters>"
            }
          ],
          "install_order": ["glib2", "gtk3"]
        }
      ]
    }
  ]
}
```

The GTK example is abbreviated only for readability. Production must list its
complete tested closure in dependency order. ZIP package filenames must be at
the archive root, and `install_order` must name every package exactly once.

The generator should derive package names, versions, filenames, and SHA-256
values from the exact staged `.gem` files used by the clean-runtime smoke test.
Publish it only after every referenced release asset is stable. A temporary
asset/manifest mismatch fails closed instead of installing an unchecked gem.

There is no signature verification yet. Hashes protect transfer integrity and
release-assembly mistakes, but a party able to replace both the manifest and
asset can also replace the expected hash. Treat the release promotion review
and GitHub repository protections as the current trust boundary until signing
is funded.

## Range-aware recovery and lifecycle

Units may carry `lich_versions` with an inclusive `min_inclusive` and/or an
exclusive `max_exclusive` version. At least one bound is required. The running
`LICH_VERSION` is used before both repair planning and startup version policy.
Applicable ranged closures replace intersecting legacy closures as whole units;
Lich never mixes a retained older shared package into a newer closure. Conflicting
applicable range package identities fail closed. Release checks apply the same selection
before comparing the candidate lock.

### Explicitly versioned candidates and prerelease bounds

A ranged producer candidate must be a prepared commit containing both the
candidate lock and its intended `LICH_VERSION`. Administrators select that full
commit SHA; the producer does not infer a future release version from an
unversioned lock PR. Contract validation uses that candidate's version (or the
explicit offline checker version) when selecting applicable units.

Bounds use literal RubyGems `Gem::Version` ordering. For example,
`5.24.0-beta.1` precedes `5.24.0`: a minimum of `5.24.0` excludes its betas.
To include the beta series, use an explicit prerelease minimum such as
`5.24.0-beta.0`. These are illustrative bounds, not selected support cutoffs.

### Publication strictness and startup compatibility

Publication checks reject unknown `lich_versions` keys and malformed or unknown
lifecycle metadata. Startup ignores lifecycle annotations and unknown range
keys, but requires at least one recognized bound. It applies known
`min_inclusive` and `max_exclusive` bounds literally. Thus a range with a known
minimum and an unknown `max_inclusive` key has no recognized upper bound;
a range containing only unknown keys is rejected. This is the existing tolerant
startup rule, not permission to publish those shapes: strict checks reject both.

New fields that change mandatory selection semantics require an explicit
manifest-schema or reader-capability transition and supported-client acceptance.
Do not treat an ignored key as an enforced restriction on old readers. This
manifest schema transition is separate from the runtime contract's schema-2
semantic identity; the recovery manifest envelope remains schema 1 here.

Keep a complete legacy unit ahead of every ranged replacement. Older first-match
readers ignore these added fields and continue recovering their legacy closure.
The producer gates both pinned legacy consumers and the explicitly selected new
consumer on clean RubyInstaller. Before promoting ranges, it also verifies an
explicit `range_reader` release tag and full commit against the reviewed reader.
Release/install this Lich capability before publishing policy that relies on it.
No range or support cutoff is enabled by this change.

An obsolete unit carries `lifecycle: {"state":"obsolete"}`, optionally with one
`until_date` (ISO date) or `floor_lich_version`. These fields document support;
they never automatically remove service. Withdrawal is a separate reviewed
producer change, emitting `withdrawn_members` and its explicit decisions. No
unit may advertise or package a withdrawn member, including alternate units and
the promotion rollback manifest. Historical release files are kept.

GTK remains built and served under the current policy. Frozen GTK preparation
copies the complete published, hash-verified Ruby 4.0 closure into an immutable
standalone ZIP. Actual freeze waits for webUI go-live; the shim-retirement change
sets the future support floor. The v5.19.0 compaction boundary is a compatibility
consideration for that decision, not a selected support cutoff.
