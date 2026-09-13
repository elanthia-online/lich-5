# Coordinated operations: bounded request lifecycle prototype

Date: 2026-09-14. Status: experimental stacked implementation; not a published
interface, automatic runtime integration, or grant to send game commands.

## Scope

This is the request-lifecycle slice that follows the read-only coordinated
sessions prototype in PR #1613. It is intentionally stacked on that branch so
review of PRs #1612 and #1613 does not block further design validation.

The module reuses the bounded loopback `ActiveSessions::Server` and
`ActiveSessions::Client`. It adds one explicit control grant between two exact
session identities, a bounded request/receipt store, and an owner-thread
mailbox. It does not add a broker, shared Ruby interpreter, Redis dependency,
remote eval, raw game-command route, script-start route, or hunting policy.

The first exercised operation is synthetic. A test owner takes a `probe` or
`hold` request and explicitly records the result; no game state or script is
touched. EOHunter and LAB adapters are separate follow-up changes.

## Module interface

The owner constructs an inert grant with:

```ruby
grant = Lich::InternalAPI::Coordination::Operations::Grant.new(
  session: coordination_session,
  peer: exact_peer_identity,
  control_token: separately_exchanged_token,
  operations: {
    'probe' => { required: [:value], optional: [:note] }
  },
  enabled: true
)
```

The grant starts only when its owner calls `start`. Its descriptor names the
protocol, loopback endpoint, owner identity and peer identity; it never contains
the control token. The peer uses the separately exchanged token:

```ruby
client.submit(
  request_id: 'one-immutable-operation-id',
  operation: 'probe',
  arguments: { value: 7 }
)
client.result(request_id: 'one-immutable-operation-id')
```

Only the thread that constructed the grant may cross the execution seam:

```ruby
request = grant.next_request(owner_tick: completed_tick)
grant.settle(
  request_id: request[:request_id],
  owner_tick: completed_tick,
  outcome: :succeeded,
  result: { observed: true },
  cleanup: :pending
)
grant.finish_cleanup(request_id: request[:request_id], owner_tick: later_tick)
```

Transport workers only validate, reserve, submit and copy receipts. There is no
callback in the operation definition and no path from the worker to a game
reader, command sender, Script method, or consumer object.

## Contract

Identity is the complete read-prototype identity: game, character, random
incarnation, connection generation and owning run. The grant additionally pins
one exact peer identity. A changed native session identity rejects the old grant
before admission; the owner closes its mailbox on its next progression check.

Operation definitions are declarative exact-key schemas. Names and argument
keys are bounded lowercase identifiers. Values must be bounded,
JSON-compatible data. User Ruby, classes, Procs and arbitrary validators cannot
cross the transport seam.

The first request for an ID stores its operation, arguments and canonical
SHA-256 argument digest. Reusing the ID with identical arguments returns the
same ticket/receipt. Reusing it with different arguments fails as
`request_conflict`. The table has fixed capacity and performs no live-entry
eviction; when full, new work is rejected so replay protection remains intact.

A receiver-generated ticket has a receiver-local issuance-to-use deadline.
Repeating `ticket` or `submit` does not renew it. This bounds time after the
receiver issued the ticket; it does not prove the age of a human's original
intent before ticket issuance.

Receipt state and execution meaning stay separate:

| Field | Values | Meaning |
| --- | --- | --- |
| `state` | `reserved`, `pending`, `running`, `settled`, `expired`, `revoked` | Request lifecycle at the local owner |
| `outcome` | `succeeded`, `failed`, `cancelled`, `unknown`, or `nil` | What the owner can truthfully claim about execution |
| `cleanup` | `not_required`, `pending`, `complete`, `unknown` | Whether owned resources and children have been released |
| `owner_tick` | positive integer or `nil` | Local owner progression that took or settled the request |

Every receipt also carries the exact owner and peer identities. A result that is
validly shaped but belongs to another request, incarnation, connection
generation, run, or peer is rejected rather than accepted as successful work.

Admission is not execution, execution outcome is not cleanup, and endpoint
closure is not proof that running work stopped. A crash after an effect but
before settlement remains unknown to the peer.

Revocation closes admission immediately. Reserved and pending requests become
revoked. Running requests remain running until their exact owner settles them;
the core module does not pretend to stop work it does not own. A consumer
adapter must observe revocation, stop its own work, and report cleanup.

## Trust and security scope

This is a cooperative same-host, same-OS-user safety and idempotency protocol.
Tokens, exact identities, deadlines, request digests and receipts prevent
accidental cross-session action, stale work and duplicate delivery among
cooperating processes. They do not isolate malicious code running as the same
OS user, which can inspect process memory or private files. Remote-machine and
untrusted-plugin operation require a different threat model.

## Deliberate omissions

- No operation is advertised through public discovery.
- No control token appears in descriptors, snapshots or diagnostics.
- No subscription/event stream is added.
- No automatic retry is performed by the client.
- No persistent receipt store survives process replacement.
- No consumer-specific readiness, movement, combat, safe-room or recovery
  meaning is defined in Lich.
- No Script lifecycle registry is duplicated. Later adapters retain exact
  native `Script` handles and use existing supervision.

## Next adapter gates

The EOHunter adapter may register only narrow operations such as diagnostic
`hold`, `release` and local `return`. Its owner tick takes the request, rechecks
current World/policy state, applies it through the existing controller, and
records a receipt. It must not operate both this transport and DRb for the same
order.

The LAB adapter keeps LAB's own admission and full-access switches. Stable LAB
work should call registered operations and reconcile by request ID; discovery
must not grant new authority.

`go2` remains a local child owned by the local controller. A later EO scripts
adapter can expose structured travel status and results, while Lich provides
only exact child supervision and the generic operation lifecycle.

## Verification

The focused suite covers disabled mode, token-free descriptors, real bounded
loopback transport, exact peer/session identity, request validation, canonical
argument digests, identical retries, conflicting retries, expiry without
renewal, capacity rejection without eviction, concurrent duplicate delivery,
owner-thread enforcement, owner-tick progression, revocation during running
work, separate cleanup completion and hostile/misrouted response validation.

Required before a consumer adapter is proposed: full Lich suite, scoped lint,
an independent adversarial review, and synthetic process-replacement tests.
Required before live commands: a separately reviewed EOHunter adapter using an
explicit player grant and the existing safe-start/safe-return rules.
