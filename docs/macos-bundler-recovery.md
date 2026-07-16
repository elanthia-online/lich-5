# macOS Bundler recovery

Lich can repair missing default runtime gems on macOS through a user-approved
Bundler install. This is a narrow compatibility path for normal runtime gems
such as `ox`; it is not a macOS GTK installer.

## Scope

- macOS only; Linux keeps the ordinary missing-gem message.
- Only the `:default` Bundler group is eligible.
- `gtk`, `development`, `vscode`, and `profanity` are explicitly excluded.
- GTK remains required for a graphical launch unless `--no-gui` or `--no-gtk`
  is present, but Lich never attempts to install GTK through this path.

## Recovery flow

1. Lich detects a missing default runtime gem.
2. It performs local preflight checks: Gemfile, Bundler availability, and—for
   native defaults such as Ox—Ruby headers, Xcode Command Line Tools, and
   `make`.
3. A native macOS dialog lists the missing gems and asks for approval. No gem
   download or install happens until approval.
4. Lich copies `Gemfile`, plus `Gemfile.lock` when it was shipped, into staging.
   A child process runs `bundle install` with a private `BUNDLE_PATH`. A shipped
   lockfile is used with `BUNDLE_FROZEN=true`; otherwise Bundler resolves and
   creates a lockfile only inside staging. The live Lich files are never changed.
5. Bundler writes only beneath `lich-5/.lich-bundler-gems/.staging-*`. If every
   dependency installs successfully, Lich atomically renames that directory to
   a new private bundle and atomically updates `active.json`.
6. Lich relaunches. At the next boot, GemCheck adds the activated bundle's
   RubyGems home before checking dependencies.

If Bundler cannot reach a source, a build fails, or the process is interrupted
before promotion, the active RubyGems paths and active record are unchanged.
The incomplete staging directory is removed. Bundler output is retained in
`temp/lich5-bundler-recovery.log`; GemCheck records the recovery event or
failure in `temp/lich5-missing-gems.log`.

This path intentionally does not install into the system or user `GEM_HOME`.
It also does not provide cryptographic verification equivalent to the
Ruby4Lich5 Windows manifest: when a release includes a lockfile, it constrains
versions; when it does not, Bundler resolves from its configured sources.
