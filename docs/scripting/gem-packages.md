# Gem packages

`lich5-update` can follow a GitHub repository's releases and install the
`.gem` attached to each one. This is for scripts made of more than one file,
such as `eohunter.lic` plus an `eohunter/` folder, which the script
repository sync and `;repository` cannot place. Code lives in
`lib/common/update/gem_packages.rb`. The proposal is #2322.

```
;lich5-update --add-gem=owner/repo      register it, and install the latest release now
;lich5-update --remove-gem=owner/repo   stop following it
;lich5-update --gems                    list what is followed
```

## The gem contract

A release publishes one asset named `<name>-<version>.gem`. The version
must be one `Gem::Version` accepts. Assets that do not match are ignored,
and a release with no matching asset is skipped with a message.

The gemspec names the package's installer:

```ruby
spec.metadata['lich_install'] = 'eohunter/install#EOHunter::Install'
```

The part before `#` is a file under the gem's `require_paths`, without
`.rb`. The part after is a constant. Lich `load`s that file from the
installed gem and calls `EOHunter::Install.install(LICH_DIR)`. The installer
copies the package's scripts into Lich; Lich never knows what it copies or
where. It is loaded rather than required, so a second update in one session
runs the new version's installer.

Lich refuses a gem, before installing anything, when:

- its own name or version differs from the asset filename;
- it declares native `extensions`;
- it ships a `rubygems_plugin.rb`, which would run on every later `gem`
  command, outside Lich;
- it has no `lich_install` metadata;
- its `required_ruby_version` or `required_rubygems_version` is not met.
  RubyGems' installer does not check these, because this install bypasses
  its resolver.

It also refuses an asset GitHub reports as over 10 MB, a download that
grows past 10 MB, and a download whose SHA-256 differs from the `digest`
GitHub publishes for the asset. Older assets without a digest are accepted.

Runtime dependencies are not installed. A gem that declares any is
installed with a note saying so.

## The gem name belongs to the repository

The first release a registration installs pins its gem name. After that:

- a release under a different name is refused. The player has to remove the
  package and add it again to accept the new name;
- a name another registration holds is refused;
- a name already installed in Lich's Ruby that no registration installed is
  refused. This stops a release from replacing one of Lich's own gems, such
  as `json`, which Lich loads at every start. A gem the player installed by
  hand is accepted when its `source_code_uri` or `homepage` is this
  repository.

The name check and the registry write happen in one locked update, so two
sessions cannot both claim a name.

## When and where it runs

- `--add-gem` registers the repository and runs a sync for it at once.
- `--sync` with no repository runs the script repositories, then every
  registered package.
- At login, the same pass runs on the background sync thread in
  `lib/games.rb`, after the script repositories.

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
| Registry lock | `DATA_DIR/gem_packages.lock` |
| Install lock | `Gem.dir/.lich5-gem-packages.lock`, or `TEMP_DIR/gem-packages-install.lock` when the gem home cannot hold it |
| Downloads | `TEMP_DIR/<pid>-<thread>-<asset>`, removed after the install or on failure |

Each registration records `gem` (the pinned name), and `deployed_gem` and
`deployed` (what this Lich install last deployed). A package is current only
when the installed version is at least the release's and both deployed
fields match it.

After a new version is installed and deployed, older versions of that gem
are uninstalled. They are removed only after success, so a failed update
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
| Download fails, or is over the limit, or the digest differs | Reported. The partial file is removed |
| The installer raises, including `LoadError` or `SyntaxError` | The gem stays installed. The next sync runs the installer again without downloading |
| Another session is installing | This sync waits up to 60 seconds, then leaves it for the next sync |

Downloads happen before taking the install lock, so a slow transfer does not
hold up other sessions. Under the lock, the state is checked again, since
another session may have installed the release in the meantime.

## Trust model

A registered package is code from that repository's release, installed and
run without asking at `--add-gem` and at every later login, in every Lich
session on the install.

What protects the player today:

- they choose which repositories to register;
- a release cannot take over a gem name it does not own, ship native code
  or RubyGems plugins, or link commands into Ruby's `bin`;
- the downloaded bytes must match GitHub's published digest when there is
  one.

What it does not protect against: a release from a registered repository
can run any Ruby code in Lich at the next login, and its installer can
write anywhere the player can. This is more than a custom repository
script, which syncs at login but runs only when the player starts it.

**Open decision.** Whether an update should run without the player's
confirmation is for the maintainers to decide on #2322. The options raised
in review are:

- (a) `--add-gem` asks for `--confirm` after showing the gem name, version,
  SHA-256 and entry point;
- (b) the digest check above, which is in place;
- (c) automatic updates only for allowlisted owners; for anyone else, the
  release is announced and waits for the player to run a command.
