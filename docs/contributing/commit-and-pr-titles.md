# Commit and PR titles

lich-5 PRs are squash-merged, so the PR title becomes the commit message on
`main`. Release Please reads those messages to choose the next version and
build `CHANGELOG.md`, so the title has to follow
[Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): short description
```

The **Lint PR** workflow (`.github/workflows/lint_pr.yaml`) checks every PR
title against `main` and `staging` and fails the PR if the title doesn't fit.
This page describes that check and `release-please-config.json`; if it
disagrees with them, the files are right and this page needs updating.

## Scope (required)

| Scope | Use for |
|---|---|
| `all` | Changes that affect both games, or the engine as a whole |
| `gs` | GemStone IV-only changes |
| `dr` | DragonRealms-only changes |
| `main` | Release Please's release PRs (`chore(main): release 5.24.2`); not for ordinary PRs |
| `pre/beta…` | Release Please's prerelease PRs (`chore(pre/beta): release 5.15.0-beta.0`); not for ordinary PRs |

A title without a scope fails the check, and so does an uppercase scope.

## Type

The check accepts the standard Conventional Commits types. How each one shows
up in the changelog comes from `changelog-sections` in
`release-please-config.json`:

| Type | Use for | Changelog section | Example |
|---|---|---|---|
| `feat` | New features or functionality | Features | `feat(all): install scripts shipped as a gem on GitHub releases` |
| `fix` | Bug fixes, including game text an existing matcher missed | Bug Fixes | `fix(gs): tolerate nil table rows in critranks` |
| `perf` | Performance improvements | Performance | `perf(all): skip the map reload when the file is unchanged` |
| `refactor` | Restructuring without changing behavior | Refactoring | `refactor(dr): extract the room-players parser` |
| `docs` | Documentation only | Documentation | `docs(all): move script-author docs to the wiki` |
| `test` | Adding or updating tests | not listed | `test(all): add replay goldens for Saga logins` |
| `style` | Formatting with no code change | not listed | `style(all): apply rubocop autocorrect` |
| `build` | Build system or dependencies | hidden | `build(all): bump sqlite3 to 2.7` |
| `ci` | CI configuration | hidden | `ci(all): cache gems in the spec job` |
| `chore` | Maintenance that fits nothing above | hidden | `chore(all): update .gitignore` |
| `revert` | Reverting an earlier commit | not listed | `revert(all): restore the old login timeout` |

## Versions

- `feat` bumps the minor version (5.24.x → 5.25.0).
- `fix` bumps the patch version (5.24.1 → 5.24.2).
- A breaking change bumps the major version, whatever its type. Mark it with
  `!` after the scope (`feat(all)!: …`) or a `BREAKING CHANGE:` footer.

**Open question:** whether a release that contains only `perf`, `refactor` or
`docs` commits (visible in the changelog, but neither `feat` nor `fix`) gets a
patch release from Release Please. Confirm it against a real release run and
update this section.
