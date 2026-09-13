# Coordinated readiness: bounded A/B prototype

Date: 2026-09-13. Status: experimental implementation and synthetic verification;
not a published API, live installation, or approval of write-capable coordination.

## Scope and pinned foundations

Implements the first read-only experiment from the reviewed independent-session
proposal; the bounded implementation contract is recorded here. Each character retains its
own Ruby process. No game commands, scripts, permissions/grants for execution,
receipts, broker replacement, Redis requirement, or native frontend input path
are introduced. No automatic runtime registration or profile enablement.

Source baselines:

- [Lich 3342837fe78cd8965d20525464913c66218ea853](https://github.com/elanthia-online/lich-5/tree/3342837fe78cd8965d20525464913c66218ea853).
- [EOHunter 6f15eb02c6376c4e9330d940e7f1c6f8da18eb3a](https://github.com/elanthia-online/eohunter/tree/6f15eb02c6376c4e9330d940e7f1c6f8da18eb3a).

| Existing facility | Missing behavior | Owner in this experiment | Verification |
| --- | --- | --- | --- |
| ActiveSessions file lock, atomic rename, registry | Publish an optional character endpoint descriptor | Explicit discovery adapter; no extra daemon | Actual owner death, competing successors, reader, cleanup-race tests |
| ActiveSessions Server/Client JSON transport | Bounded optional read-only route, exchange and frame limits | Native transport with opt-in arguments, unchanged legacy defaults | Old transport specs plus bounded I/O/capacity/auth tests |
| Native Script lifecycle | None for read-only observations | No Script launch or supervisor added | No write routes accepted |
| Group.report and Leader movement predicate | Copy diagnostics after owner progression | EOHunter adapter on completed engine tick | Existing policy consumed, no second policy engine |
| Native state readers | Atomic room, vitals, ownership projection | Unresolved native source contract | Unknown readiness cannot pass the barrier |
| LAB identity and admission | Demonstrated reusable deletion, not a wrapper | Deferred second-consumer evidence gate | Not claimed or implemented |

MahtraDR's [plugin guide](https://github.com/elanthia-online/dr-scripts/wiki/Script-Plugin-System)
already describes optional Ruby objects receiving host notifications, with no
backend dependency in the host. We reuse that separation of responsibility:
an explicitly attached adapter consumes a host callback. EOHunter already has
callbacks and World readers; this does not copy DR's script-specific loader or
invent a second plugin registry. One completed-tick notification is added because
the existing `on_tick` fires before the action, not after it.

## Contract

`Lich::InternalAPI::Coordination` is explicitly required by the pilot, never by
normal startup. `Session.new(..., enabled: false)` is inert. An enabled owner
calls `start`, publishes a plain immutable projection from its own thread, and
calls `close` at teardown. No network worker reads World or invokes an owner.

Identity is `(game, character, incarnation, connection_generation, run_id)`.
Incarnation is random per Session; reconnect increments the generation and
invalidates the old snapshot. Peers must use the complete expected identity.
The read credential is separate from discovery credentials and is never included
in the advertised descriptor or diagnostics. Under same-host/same-user trust,
this is a cooperative safety boundary, not protection from malicious same-user
code able to inspect process memory/files.

Only `ping` and `snapshot` exist. Snapshot fields are the fixed `room` and
`readiness` projection. Unknown keys, versions, identities and operations fail.
No raw commands, eval, method invocation, subscriptions or remote mutation.

Owner publications carry a strictly advancing publication sequence and completed
tick, connected state, room ID/epoch, readiness/coherence and source metadata for
each field. A source has its own version, age, room epoch and connection
generation; polling is not a new observation. Equal source versions cannot
change value or gain a younger age. Missing source metadata stays unknown.
The store and reader retain source watermarks even across unavailable samples.

The server measures snapshot and source age on its own monotonic clock. The
client adds its entire measured round trip conservatively; clocks are never
compared between processes. An endpoint replying promptly does not refresh the
owner tick or source age. The derived `ready` is permission-to-proceed for this
read barrier, not the underlying tri-state fact: it is false for unknown, stale,
mixed, disconnected or missing-source observations. The raw readiness remains
nil when not established. Default accepted age is 1 second.

The reader also retains receiver-local aging anchors. Replaying an unchanged
response ten seconds later cannot reset its age, even if the reported wire ages
are unchanged. These anchors survive unavailable-source gaps and faster later
round trips. Concurrent calls on the same Client fail promptly with `snapshot
busy` rather than queue behind an exchange outside the deadline.

Limits: 16 KiB frames including newline, JSON nesting depth 16, four admitted
clients per endpoint, 250 ms monotonic connect/write/read exchange deadline.
There is no application request queue. Callback code must remain nonblocking;
the transport deadline does not promise to preempt arbitrary Ruby computation.
Over-capacity peers are closed, not queued without bound. Native discovery uses
its existing transport defaults; this does not claim its entire failover path
has acquired the endpoint's 250 ms deadline.

## What the Hunter adapter can honestly prove

It calls existing `Group.report` and, when supplied, `Leader#movement_ready?`.
It rejects captures crossing a known room/connection/owner change. Nevertheless,
these readers independently sample native state: a matching generation fence
does not prove atomic vitals and controller ownership. Therefore the actual
adapter deliberately publishes unknown coherence and cannot enable a new
movement barrier. This is a discovery from slice A, not a reason to fabricate
positive readiness. Synthetic fixtures exercise coherent true/false cases in
the core without claiming those fixtures are an available game-state API.

No existing hunting movement, DRb group behavior, LAB admission or recovery
policy is replaced. Reading diagnostic state is the usable result of this
prototype; production coordinated readiness needs the native writer contract
resolved before promotion.

## Discovery ownership finding

The native shutdown released its advisory flock before checking and unlinking
discovery. A successor could publish after that check and have its live file
deleted by the retiring owner. A real-process barrier test reproduced this
exact order. Shutdown now retains the existing flock through cleanup and only
unlinks when it holds that lock. The existing unit fixture now acquires real
ownership instead of treating matching PID metadata as ownership. This small
prerequisite fix should be reviewed separately from the experimental endpoint.

Discovery publication remains opt-in and explicit. No clearing-by-PID is added:
the registry lacks conditional metadata removal, so an old session must not
erase a new session's descriptor. A retired endpoint refuses access; readers
validate identity, and a successor discovery service needs explicit republishing.
Read tokens are supplied separately, not placed in shared discovery metadata.

## Verification and next gates

Run native ActiveSessions, coordination, multiprocess and transport specs. Run
the full Hunter suite and gated cross-repository adapter test using the real
Lich module. `spec/support/coordination_benchmark.rb` starts only independent
synthetic owners on loopback; it must never be loaded as a game script.

Initial local throughput baseline (Ruby 4.0.5, 200 reads per owner, unpaced
concurrent clients; not a production load or idle-CPU estimate):

| Owners | Reads | p50 ms | p95 ms | p99 ms | Reads/sec |
| --- | --- | --- | --- | --- | --- |
| 2 | 400 | 0.310 | 0.554 | 1.638 | 5,711 |
| 5 | 1,000 | 0.812 | 1.162 | 1.657 | 5,845 |
| 10 | 2,000 | 1.689 | 2.158 | 2.452 | 5,716 |

These short runs establish a reproducible baseline, not a latency guarantee.
Follow-up local regression targets: ten-owner p99 below 25 ms and endpoint
incremental RSS below 16 MiB per owner in this harness. Initial RSS deltas were
about 2.9-3.5 MiB. The harness reports parent/owner CPU and owner ticks; its
unpaced flood is intentionally not representative of a one-Hz client. Game-loop
overhead and long-run CPU/memory stability still need measurement before any
live pilot. Four admitted clients are the enforced concurrency bound, not a
measured claim about the kernel's listen backlog.

Before slice C: maintainer agreement on coherent native projections, longer
stalled-publisher/availability measurements, separately reviewed operation
contracts and authorization. Before generic core promotion: a real LAB contract
test plus code deletion demonstrating the second-consumer benefit. No writes or
live trial are silently enabled by completing this prototype.

Rollback: do not require/attach the optional module. The live installation has
not been changed; both worktrees remain separate from running game sessions.

## Acceptance record

- Root reproduced the discovery-cleanup race before modifying production code;
  the exact same multiprocess regression passed afterward.
- Independent review reproduced stale-replay and concurrent-client admission
  defects. Four new regressions pass after fixes; the independent reviewer
  reran all four and found neither issue remaining.
- Final targeted Lich internal API suite: 118 examples, zero failures, seed 719.
- Final full Lich suite: 7,596 examples, zero failures, seed 719.
- Hunter full suite with actual Lich transport integration: 864 examples, zero
  failures, seed 719. Single-file build and documentation generation passed.
- Lich scoped lint: all 13 changed/new Ruby files passed. Hunter changed-file
  lint and both worktree whitespace checks passed.
- Post-fix benchmark p99: 1.892 ms (two owners), 1.894 ms (five), 2.786 ms (ten).
  This run overlapped regression work; it is a local sanity check, not an SLA.

Reproduction commands, from the appropriate repository with Ruby 4.0.5 and the
project test gems on PATH/GEM_PATH:

```sh
# Lich worktree: offline tests and Linux fork-based microbenchmark
rspec spec/lib/internal_api --seed 719
rspec --format progress --seed 719
ruby spec/support/coordination_benchmark.rb

# Hunter worktree: explicit cross-repository test opt-in
LICH_COORDINATION_ROOT='/path/to/lich-coordination-checkout' rspec --format progress --seed 719
```

Known unverified boundaries: live source coherence, production game-loop cost,
long-run resource stability, Windows/macOS process-handoff execution, forced
numeric PID/port reuse, and a production discovery-availability deadline. The
five-second subprocess-test deadline is test orchestration, not a claimed native
failover SLA. No coordination command can be executed in this implementation.

Review split: native discovery cleanup regression/fix; this optional bounded
transport plus experimental read-only core; separate Hunter callback and
diagnostic adapter. The cleanup regression/fix is not bundled here. The full
suite counts above describe the combined prototype; per-PR checks are reported
in the corresponding PR descriptions. The subsequently installed local build
also includes pre-existing integration changes, not just these PRs.
