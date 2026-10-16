# Stream replay fixtures

Captured DragonRealms server streams, replayed by
`spec/stream_replay/stream_replay_spec.rb` through a real `lich.rbw --pipe`
process (see `spec/support/stream_replay/`). Each fixture's per-prompt parsed
state must match `goldens/<name>.jsonl`.

All fixtures come from `;logxml streams` captures and were produced with
`spec/support/stream_replay/extract.rb`:
- timestamps, client echoes and reget content stripped;
- windows snapped to prompt boundaries;
- a synthetic login header added;
- every player name pseudonymized and account names replaced.

Character names below are the pseudonyms used inside the fixture.

DragonRealms has two dialects:
- **legacy** is the stream sent to a front end that identifies as Wrayth 1.0.1.28. This is the default before #1700, and still what Genie, Warlock and Wrayth get.
- **saga** is the stream sent for the `/VERSION:saga-… /P:SAGA` identity. This is the default after #1700 for Wizard/Avalon, Frostbite, Mudlet and `--without-frontend`, which includes Profanity (it runs Lich with `--without-frontend`).

| Fixture | Dialect | Captured | Prompts | Covers |
|---|---|---|---|---|
| `dr_legacy_hunt.xml` | legacy | 2026-10-15 15:35 | 341 | hunting: bold room objs, dead NPCs, assess, combat stream, percWindow, PC postures, spell prep/castTime, movement |
| `dr_legacy_stow_movement.xml` | legacy | 2026-10-15 15:20 | 70 | inventoryManager, `clearContainer`/`<inv id='stow'>` (plain text, no links), movement with roomName |
| `dr_legacy_hide_whisper.xml` | legacy | 2026-10-07 | 57 | IconHIDDEN, whispers |
| `dr_legacy_group.xml` | legacy | 2026-10-07 | 32 | group stream incl. `You (Leader)` |
| `dr_legacy_bank.xml` | legacy | 2026-10-03 | 15 | bank clerk lines |
| `dr_saga_hunt.xml` | saga | 2026-10-15 16:15 | 276 | hunting: `<a exist>` links with doubled bold, dead NPCs, assess with nested `<d><a>`, combat, percWindow, `<room>` block, movement |
| `dr_saga_inventory.xml` | saga | 2026-10-15 16:15 | 56 | INV SEARCH, passive inventoryManager, linked hands |
| `dr_saga_stow.xml` | saga | 2026-10-15 16:15 | 10 | linked stow container feed (`<inv id='stow'>` with links, no `<container>`) |
| `dr_saga_group_bank.xml` | saga | 2026-10-15 16:37 | 79 | group join/list/leave with another leader, bank balance with linked name |
| `dr_saga_containers_speech.xml` | saga | 2026-10-15 17:49 | 100 | open/close/look in/rummage, bank deposit/withdraw, hide/unhide, linked speech preset |

`benchmark/fixtures/gs_sample.xml` and `dr_sample.xml` are also replayed (goldens `gs_sample.jsonl`, `dr_sample.jsonl`). `gs_sample` is the only committed GemStone stream and serves as the GS replay oracle for shared-path changes. GemStone has one dialect, the rich stream with `<a exist>` links and no `<room>` block, whichever identity Lich sends (see E11 in `docs/saga-stream-deferred.md`).

## Regenerating

- **A fixture:** run `extract.rb` against the source log with the same `--from`/`--to`, and pass `--scrub-names` a local, uncommitted list of names that must never appear in the repo.
- **Goldens:** `UPDATE_STREAM_GOLDENS=1 bundle exec rspec spec/stream_replay`. Review every golden diff in the PR; a changed golden is a behavior change.
