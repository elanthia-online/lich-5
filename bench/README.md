# Memory profiling harness

Tools for measuring Lich's memory footprint and how it grows over a synthesized
"normal run". Built to answer: *where is memory actually going, and what grows
unbounded over a long session?* Measure before optimizing.

Nothing here is loaded by the runtime -- it is a standalone benchmark that boots
the real subsystems and drives them directly. No production code is modified.

## Files

| File | Role |
|------|------|
| `memory_sampler.rb` | Reusable, stdlib-only `MemorySampler`: records RSS + GC/heap/objectspace stats at named checkpoints and prints a delta report. |
| `lich_env.rb` | Headless bootstrap. Requires the real subsystems in `lich.rbw` order up to the parse/script/hook pipeline, points data/log/script dirs at a throwaway temp sandbox, and stubs the front-end client. **Does not** require `lib/main/main.rb` (it spawns the live login/socket thread at require time). |
| `memory_profile.rb` | The run harness. Boots, loads the GS trackers, then drives a synthetic GS server stream and real `Script` thread churn, sampling at each phase. |

## Run it

```bash
bundle exec ruby bench/memory_profile.rb

# bigger / with a by-class object census of the run:
ITER=5000 NPCS=20000 CHURN=200 CENSUS=1 bundle exec ruby bench/memory_profile.rb
```

| Env var | Default | Meaning |
|---------|---------|---------|
| `ITER` | 2000 | server-string "ticks" fed through `Game.process_server_string` |
| `SAMPLE_EVERY` | 500 | sample interval within the stream phase |
| `NPCS` | 5000 | unique NPCs pushed at `GameObj`'s identity index |
| `CHURN` | 200 | start/kill `Script` cycles |
| `CENSUS` | 0 | `1` walks ObjectSpace for a top-growers-by-class diff |

## Design

The run is driven **synchronously** -- `process_server_string` is called in a
loop rather than fed through the live game-server thread -- so the exact number
of lines processed before each RSS sample is known and growth is attributable
per phase. The thread-id-keyed paths (hook registry, per-script `@watchfor`,
`Buffer`/`SharedBuffer` indices) still need real threads to leak the way they do
in production, so those are exercised with genuine `Script` start/kill churn.

## Reading the report

- **Phase 0 -> 1 -> 2** is the *static* footprint: process start, after core
  requires, after `GameLoader.gemstone`. The jump at phase 2 is dominated by the
  ~46k-line critrank tables.
- **`dRSS`** is resident-set delta vs the baseline; **`dlive(k)`** is live Ruby
  objects (thousands) delta. Phases tagged `(post-GC)` force a full GC first, so
  they show *retained* memory -- the number that matters for leaks.
- A phase whose post-GC live-object count keeps climbing across runs with larger
  knobs is growing unbounded.
