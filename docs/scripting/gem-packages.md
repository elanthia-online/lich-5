# Gem packages

`lich5-update` can follow a GitHub repository's releases and install the
`.gem` attached to each one. This is for scripts made of more than one file,
such as `eohunter.lic` plus an `eohunter/` folder, which the script
repository sync and `;repository` cannot place. Code lives in
`lib/common/update/gem_packages.rb`. The proposal is #2322.

```
;lich5-update --add-gem=owner/repo      register it, and install the latest release now
;lich5-update --update-gem=owner/repo   install its latest release now
;lich5-update --remove-gem=owner/repo   stop following it
;lich5-update --gems                    list what is followed
```

New releases install automatically only for trusted owners, today
`elanthia-online`. Other owners' releases are announced and wait for
`--update-gem`. See [Trust model](#trust-model).

## The gem contract

A release publishes one asset named `<name>-<version>.gem`. The version
must be one `Gem::Version` accepts. Assets that do not match are ignored,
and a release with no matching asset is skipped with a message.

The gemspec names the package's installer:

```ruby
spec.metadata['lich_install'] = 'eohunter/install#EOHunter::Install'
```

The gemspec must also name the repository it is published from, in
`source_code_uri` or `homepage`:

```ruby
spec.metadata['source_code_uri'] = 'https://github.com/elanthia-online/eohunter'
```

Lich uses it to recognise its own package when the gem is already installed
but no registration records installing it: after `--remove-gem` and
`--add-gem` again, when a second Lich install on the same Ruby adds the
package, or when the gem was installed by hand. Without it, that add is
refused (see below).

The part before `#` is a file under the gem's `require_paths`, without
`.rb`. The part after is a constant. Lich `load`s that file from the
installed gem and calls `EOHunter::Install.install(LICH_DIR)`. The installer
copies the package's scripts into Lich; Lich never knows what it copies or
where. It is loaded rather than required, so a second update in one session
runs the new version's installer.

Lich refuses a gem, before installing anything, when:

- its own name or version differs from the asset filename;
- it declares native `extensions`;
- an archive path is one Windows would change on extraction: a component
  ending in a dot (`rubygems_plugin.rb..` lands as `rubygems_plugin.rb`),
  a reserved character such as `:` (which also opens an alternate data
  stream), a control character, `.` or `..`, or a device name such as
  `nul`. Trailing spaces never reach this check, because RubyGems' tar
  reader strips them;
- its archive contains a `rubygems_plugin` file with any suffix RubyGems
  loads, in any folder and any case. That would run on every later `gem`
  command, outside Lich. The archive's own entries are checked, not the
  publisher-written `spec.files`;
- it has no `lich_install` metadata;
- its `required_ruby_version` or `required_rubygems_version` is not met.
  RubyGems' installer does not check these, because this install bypasses
  its resolver.

It also refuses an asset GitHub reports as over 10 MB, and a download whose
SHA-256 differs from the `digest` GitHub publishes for the asset. Older
assets without a digest are accepted. The 10 MB cap is also enforced during
the transfer: a response declaring a larger length is dropped before its
body is read, and one without a length is cut off once it passes the cap.

Runtime dependencies are not installed. A gem that declares any is
installed with a note saying so.

A release refused for any of these reasons is recorded on the
registration, with its version, its asset's digest (or size when GitHub
publishes no digest), and the Ruby and RubyGems it was refused under. Later
syncs do not download it again while all of those are unchanged, so the
refusal is printed once rather than at every login. A new release, a
re-uploaded asset, or a Ruby or RubyGems upgrade is checked afresh.
`--gems` shows the refused version. A first `--add-gem` whose release is
refused is not kept.

## The gem name belongs to the repository

The first release a registration installs pins its gem name. The name
is checked before downloading, but only pinned once the downloaded gem has
passed the checks above, so a refused release (a misnamed asset, say) does
not hold the name. After that:

- a release under a different name is refused. The player has to remove the
  package and add it again to accept the new name;
- a name another registration holds is refused;
- a name already installed in Lich's Ruby that no registration installed is
  refused. This stops a release from replacing one of Lich's own gems, such
  as `json`, which Lich loads at every start. An installed gem whose
  `source_code_uri` or `homepage` is this repository is accepted. The
  refusal names both ways out: set that field in the next release, or
  uninstall the gem and add the package again.

A `--add-gem` whose first sync is refused this way is not kept, so the
refusal does not repeat at every login.

The name check and the registry write happen in one locked update, so two
sessions cannot both claim a name.

## When and where it runs

- `--add-gem` registers the repository and installs its latest release at
  once, whoever the owner is.
- `--update-gem` installs a followed repository's latest release at once,
  whoever the owner is.
- `--sync` with no repository runs the script repositories, then every
  registered package.
- At login, the same pass runs on the background sync thread in
  `lib/games.rb`, after the script repositories.

At login and on `--sync`, a new release installs only when its owner is
trusted. Otherwise the pass prints one line naming the release and the
`--update-gem` command, and moves on. `--sync` is not consent: it refreshes
everything the player follows at once, not one package.

The gem pass is skipped when the script repository sync stopped on a
GitHub-wide failure. One package failing does not stop the others.

Everything runs in the Lich process. The installer's code runs with the
player's permissions and can write anywhere they can.

## What lands where

| What | Where |
|---|---|
| The gem | Lich's Ruby gem home (`Gem.dir`), shared by every Lich install on that Ruby |
| Its executables | `DATA_DIR/gem-packages/bin`, not Ruby's `bin`. Lich never runs them |
| Its scripts | Wherever its installer copies them, normally `scripts/` |
| The registry | The `gem_packages` row of `lich_settings` in this Lich install's database |
| Verified `.gem` files | `DATA_DIR/gem-packages/artifacts`, one per installed version, for retries |
| Registry lock | `DATA_DIR/gem_packages.lock` |
| Install lock | `Gem.dir/.lich5-gem-packages.lock`, or `TEMP_DIR/gem-packages-install.lock` when the gem home cannot hold it |
| Downloads | `TEMP_DIR/<pid>-<thread>-<asset>`, removed after the install or on failure |

Each registration records `gem` (the pinned name), `installed_gem`,
`installed` and `artifact_sha256` (the version this registration
downloaded, verified and installed, and the SHA-256 of the kept `.gem`),
and `deployed_gem` and `deployed` (what this Lich install last deployed).

Only the exact version the release advertises is ever deployed, and only
when this registration installed it. A higher version of the same name
elsewhere in Ruby's gem path, from another Lich install or a hand-run
`gem install`, is never adopted: its installer would run as if this
repository had published it. When the release version is installed but
this registration did not install it, Lich downloads, verifies and
installs it again (reported as "reinstalled"). A package is current when
the recorded installed and deployed versions both match the release.

A deploy that failed is never retried by finding the gem by name and
version in Ruby's gem path, where another publisher's gem of the same name
and version could have replaced or shadowed it. Lich reinstalls from the
kept `.gem`, after checking it still matches its recorded SHA-256, and runs
the installer from that fresh install. A kept file that no longer matches
is discarded in favour of a new download.

After a new version is installed and deployed, older versions of that gem
in Lich's gem home are uninstalled, along with their kept `.gem` files.
Copies in other gem directories on `GEM_PATH` are left alone. A gem home
reached through a symlink or junction is handled. They are removed only after success, so a failed update
leaves the working version in place. Other Lich installs on the same Ruby
keep their copied scripts and deploy the new version at their next sync.

`--remove-gem` stops the updates. It leaves the gem and the scripts its
installer copied, and prints the command that removes the gem:

```
gem uninstall <name> --all --executables
```

## Failure and retry

| Failure | What happens |
|---|---|
| GitHub unavailable or rate limited | Reported once. The pass stops and runs again at the next sync |
| Repository or release not found | Reported for that package. The others still run |
| Gem home not writable, or `plugins/` marked read-only | Reported before downloading, naming the directory and the fix |
| Download fails, or is over the limit, or the digest differs | Reported. The partial file is removed, and the next sync tries again |
| The gem is refused for its contents | Reported once and recorded. Not downloaded again until the release, its asset, or the Ruby changes |
| The installer raises, including `LoadError` or `SyntaxError` | The gem stays installed. The next sync reinstalls from the kept `.gem` and runs the installer again, without downloading |
| Another session is installing | This sync waits up to 60 seconds, then leaves it for the next sync |

Downloads happen before taking the install lock, so a slow transfer does not
hold up other sessions. Under the lock, the state is checked again, since
another session may have installed the release in the meantime.

## Trust model

A registered package is code from that repository's release. Its
installer runs in the Lich process with the player's permissions and can
write anywhere they can.

**The rule (decided on #2322 and #2323, option c):**

- **Trusted owners update automatically.** At login and on `--sync`, a new
  release from an owner in `GemPackages::TRUSTED_OWNERS` is downloaded,
  verified, installed and deployed with no player action. The list is
  `elanthia-online` today. An owner is added by adding it to that list.
  The owner part of `owner/repo` is compared whole and without case:
  `Elanthia-Online/x` is trusted, `elanthia-online-fork/x` is not.
- **Everyone else waits for the player.** A new release from any other
  owner is announced at login and on `--sync`, one line with the release
  and the command, and nothing is downloaded. It installs only when the
  player runs `--update-gem=owner/repo`.
- **`--add-gem` installs at once, whoever the owner is.** The player named
  that repository, which is the go-ahead for its current release. For an
  owner that is not trusted, it also says that later releases will be
  announced rather than installed.
- **A failed deploy is retried at login, whoever the owner is.** The
  retry reinstalls the exact `.gem` the player already installed, checked
  against its recorded SHA-256, so it runs no code the player has not
  approved.

What protects the player besides that rule:

- they choose which repositories to register;
- a release cannot take over a gem name it does not own, ship native code
  or RubyGems plugins, or link commands into Ruby's `bin`;
- only a version this registration downloaded and verified is deployed,
  never one some other source put in the shared Ruby;
- the downloaded bytes must match GitHub's published digest when there is
  one.

What it does not protect against: an installed release can run any Ruby
code in Lich, and a trusted owner's new release does so at the next login
without asking. Trusting an owner means trusting everything it publishes.
