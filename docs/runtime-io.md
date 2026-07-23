# Runtime I/O

## Detachable frontends

`--headless PORT` and `--detachable-client=PORT` expose a persistent frontend
listener. Multiple frontends can attach to the same listener. Every attached
frontend receives game output, while commands from all primary and detachable
frontends are serialized before upstream hooks and command handling run.

The listener has no authentication. Bind it only to an interface trusted clients
can reach; `tailscale` is preferable to `lan` or `any` for remote access.

A disconnected or slow detachable frontend is isolated from the session. A
primary frontend failure still ends the session. Each frontend has a bounded
asynchronous write queue, so writing to a frontend normally returns before the
operating-system socket write completes.

Script and initialization output uses `SynchronizedSocket#puts_main_stream`.
The socket observes frontend stream tags and queues that output until the next
main-stream boundary. Newly attached clients wait for an observed `popStream` or
prompt because they may have connected after the current stream opened.

## Script input

`Script#gets` blocks until the next downstream line by default. Pass a timeout in
seconds to bound the wait:

```ruby
line = Script.current.gets(2.0)
```

It returns `nil` when the timeout expires. `Script#gets?` performs the same read
without blocking, and `Script#clear` atomically returns and removes all currently
buffered downstream lines. Script buffers retain their most recent 200 entries by
default; changing `max_size` requires a positive integer.

## Game reader and hooks

Socket-read hooks execute inline, in registration order, before a game line is
enqueued for parsing. This synchronous behavior intentionally matches the other
hook chains; no execution budget or slow-hook removal is imposed. Hooks must not
block or mutate the supplied frozen input. A hook is removed if it raises an
exception.

The game reader and parser communicate through a bounded queue. Queue overflow or
an unexpected parser exception ends the session because dropping or continuing
after partially processed game data would leave runtime state unreliable.
