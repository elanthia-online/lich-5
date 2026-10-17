# Events: script-to-script notifications

`Lich::Common::Events` (bare `Events` inside scripts) is the shared notice
board. An emitter says what just happened. Listeners hear it. Lich owns the
board, so cleanup is automatic.

## Two verbs

```ruby
# the speaker (go2) - does not know or care who is listening
Events.emit('go2.status', Go2.status)

# the listener (a supervisor) - "when anyone says go2.status, run this"
Events.on('go2.status', name: 'eohunter') { |topic, status|
  @need_heal = true if status.phase == :blocked && status.reason =~ /agony/
}
```

The block runs on the emitter's thread at the moment it emits. It must only
set a flag or push onto a queue. Never send game commands (`fput`,
`Spell#cast`, `PSMS.use`) from inside a handler; act on the flag from your
own script loop.

## Topics

Dotted strings, family first: `combat.damage`, `go2.status`. Subscribe to
one exactly, to a family with `combat.*`, or to everything with `*`. Symbols
are accepted and stringified. Pick a family name that matches your script or
module so a `;e Events.list` reads sensibly.

## What makes it a primitive rather than a hash

- **Named registration is idempotent.** Subscribing again under the same
  `name:` replaces the old handler instead of stacking, so restarting your
  script or re-running a `;e` line never leaves two listeners. Anonymous
  subscriptions get a generated name, which `on` returns.
- **Owner tracking.** Every subscription records the script that made it.
  When that script dies, its subscriptions are removed (the `ScriptDeath`
  path, same as stream hooks), so a crashed supervisor cannot leave a ghost.
  Pass `persist: true` to keep one past your exit; then also `off` it in a
  `before_dying` block.
- **Error isolation.** A handler that raises is logged and skipped. One bad
  listener cannot break the emitter or the other listeners.
- **`off` is not a barrier.** An emit already in progress snapshots its
  handlers first, so a handler removed mid-emit can run one more time. If a
  handler must not act once your script is shutting down, check a flag of
  your own inside it.

## API

| Call | What it does |
| --- | --- |
| `Events.on(*topics, name: nil, persist: false) { \|topic, payload\| }` | subscribe; returns the name |
| `Events.off(name_or_block)` | unsubscribe; true if something was removed |
| `Events.emit(topic, payload = nil)` | deliver synchronously; returns handler count |
| `Events.any_for?(topic)` | skip building an expensive payload when nobody listens |
| `Events.on_change(prefix: nil) { }` / `off_change(block)` | run after registrations change, optionally only for one family |
| `Events.list` / `Events.names` | inspect what is registered and by whom |
| `Events.clear!(prefix = nil)` | drop everything, or one family |

## State versus events

Keep a read model for "what is true now" and poll it: `Go2.status`, the
Creature registry. Emit events for the edges polling cannot see: transitions,
brief transients, the moment something changed. Payloads are the read model's
own object or a small Hash. A consumer that wants its own thread pushes
payloads onto its own `Queue` inside the handler.

Deliberately not provided: async delivery, event history, persistence,
delivery guarantees. None of the current users need them, and each is a real
design decision with a real cost.

## Existing families

- `combat.<type>`: every parsed combat fact and message event
  (`combat.damage`, `combat.status`, `combat.wound`, `combat.bolted`, ...).
  The catalogue of types and payloads is documented on `Combat::Tracker.on`,
  which is only a spelling convenience: `Tracker.on(:damage)` is
  `Events.on('combat.damage')`, and the block receives the topic string.
  `Events.any_for?('combat.attack')` is what makes the processor emit
  attacks when nobody asked for them in settings.
