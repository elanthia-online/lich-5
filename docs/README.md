# Lich 5 project docs

This folder holds docs about how the lich-5 project itself is run:
contributing, the release and dependency-recovery contracts, and maintainer
guides for parts of the codebase.

Everything else lives elsewhere:

- **Script authors, front-end developers and players:** the
  [lich-5 wiki](https://github.com/elanthia-online/lich-5/wiki). This covers the
  scripting API guides, the WebUI guide, front-end protocol references, the
  creature API and the protocol research notes.
- **Individual classes and methods:** the generated YARD reference at
  https://lich-5-docs.elanthia.online/. A note about one or two methods belongs
  in their YARD comment, not in a separate doc.
- **Open-item tracking:** GitHub issues.

Docs are not packaged in releases (`/docs export-ignore`), and changes here
skip the RSpec run in CI.

## Index

| Doc | Covers |
|---|---|
| **Contributing** | |
| [YARD style guide](contributing/yard-style-guide.md) | Which methods get docs, required tags, type notation |
| **Dependency recovery** | |
| [Windows: R4L5 gem manifest](dependency-recovery/windows-r4l5-gem-manifest.md) | Manifest-driven missing-gem repair and the shared lich-5/Ruby4Lich5 version contract |
| [macOS: Bundler recovery](dependency-recovery/macos-bundler-recovery.md) | Transactional Bundler repair of default gems |
| **Engine** | |
| [GTK hardening](engine/gtk-hardening.md) | Shared GTK main loop protection and callback retention (until WebUI replaces GTK) |
| **GemStone** | |
| [Combat defs onboarding](gemstone/combat/defs-onboarding.md) | Extending the combat def grammar from log evidence, and the backlog |

## Adding a doc

- First decide whether it belongs here. A doc about how the project is run
  (contributing, CI, releases, packaging) belongs here. A doc about what Lich
  does for script authors, front-end developers or players belongs on the wiki.
- Put it in the folder for the subsystem it describes. Folders group docs by
  subsystem; game-specific docs mirror `lib/` under `gemstone/` or `dragonrealms/`.
- File names are lowercase kebab-case and don't repeat the folder name.
- Add a row to the index above.
- Link other docs with relative paths. From code comments, reference the
  repo-root path (`docs/...`), or the full URL for a wiki page.
- Moving a doc? Grep for its old path first: code comments in `lib/` and
  `spec/` cite docs by path.
