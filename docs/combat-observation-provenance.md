# Combat observation provenance

This additive native contract supports consumers such as Bigshot Quick Combat
without another combat parser, listener, or persisted configuration change.
It describes source-backed offline tests, not live gameplay certification.

## Source and batch

`Combat::Tracker.observation_context` returns a frozen binding-only hash, or nil:

```ruby
{ connection_id: Integer, game: String, character: String, room_epoch: Integer }
```

The connection ID is the public `Game.thread.object_id` of the live parser
thread. Game/character are copied frozen strings; room epoch is
`XMLData.room_count`, not a map room number. Reading this method does not
initialize, enable, configure, or save the tracker. Current context is only for
comparison; it must never be attached to a delayed event by a consumer.

The native downstream hook attaches `event[:source]`:

```ruby
{ connection_id: Integer, game: String, character: String, room_epoch: Integer,
  sequence: Integer, received_at: Float }
```

The hash and strings are frozen. Sequence is a positive increasing ingress
counter; it can have gaps. `received_at` is the monotonic timestamp captured
immediately after the socket read, before socket-read hooks and the parser queue.
It is not wall-clock time, server time, command acknowledgment, or proof that
an attack was caused by a particular command.

`Game.current_ingress_time` exposes that timestamp only on the exact
`Game.thread` during its current queue-item dispatch, and clears it in ensure.
Legacy direct dispatches, other threads, and absent/invalid timestamps return
nil. The tracker never substitutes the later hook or combat-worker clock.

`Game.process_server_string` parses XML before running downstream hooks. The
tracker therefore requires main-stream state and rejects room/stream protocol
transitions and partial tags. Object links, bold wrappers, and prompt tags are
allowed. A prompt-delimited chunk retains its **first** fragment's source;
different bindings, unknown source, or buffer truncation invalidate the whole
chunk. This is deliberately conservative: unrelated preceding text can make
the chunk too old for a consumer's action window.

The async worker copies and forwards source; it never rereads current room.
A held cast preserves its initiating source when a same-binding later chunk
supersedes it with a spell result. Missing or changed later binding invalidates
that source instead of assigning a new room/time.

`Processor.process` adds a frozen `event[:observation_batch]` before callbacks:

```ruby
{ id: Integer, index: Integer, size: Integer }
```

ID is positive and increases per nonempty processing invocation; index is
zero-based, size is the complete parsed event count. Existing `_uid`,
`root_uid`, and `parent_uid` retain their in-batch meaning. Consumers must
collect every index before treating the batch as complete; a root callback
can precede a contradictory child. Missing callbacks, interrupted emission,
or truncated consumer queues mean incomplete evidence, not success/failure.
Batch completion proves only this parser emission set, not absence of later
game output or unsupported effects. Batch IDs are process-local, not durable.

`Tracker.process`, `AsyncProcessor.process_async`, `Processor.process`, and
`Processor.parse_events` accept optional `source: nil`. Existing positional
calls remain valid and produce unavailable source. Direct `parse_events`
does not supply an emission batch. Explicit supplied metadata is a trusted
local replay/integration seam, not authenticated input or new authority.
Direct callers of `Processor.process` must serialize complete invocations;
production already does this through the ordered `AsyncProcessor` worker.

## Transient demand and consumer obligations

Existing attack parsing/emission gates use
`settings[:emit_attacks] || Observers.any_for?(:attack)`. Demand is snapshotted
once per complete `Processor.process` invocation, so a subscriber cannot join or
leave halfway through a batch. Subscribing requests complete native attack
outcomes beginning with the next processing invocation; unsubscribing restores
the previous setting-driven behavior after the current invocation. This does
**not** turn a
disabled tracker on or write settings. Quick consumers must require the
tracker to be enabled explicitly and unsubscribe on completion.

Callbacks must remain bounded and command-free: copy relevant data into a
consumer queue, then classify on its owner thread. Require exact run/context,
target ID, initiation ownership, freshness, complete batch and supported
outcome evidence. Unknown, inbound, foreign, targetless, ambiguous, stale, or
incomplete observations do not establish an own-action failure. Creature HP
changes alone cannot establish which actor caused damage.

## Offline proof

`spec/lib/games_spec.rb` tests original queue time, exact-thread visibility,
legacy nil, and normal/exception cleanup. Combat specs cover production-hook
main-stream capture, protocol/mixed-room/overflow rejection, delayed async
copying, held/superseding provenance, batch completeness metadata, and actual
subscriber removal. Tracker fixtures suppress only automatic initialization;
they do not load saved character settings or send game commands.
