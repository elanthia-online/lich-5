# Script execution guards

This API lets a supervising script place cooperative command, time, and
cancellation boundaries around existing helpers without changing their normal
unguarded behavior. Spell-specific integration is intentionally documented and
reviewed separately.

`Script#with_execution_guard(policy)` installs an optional cooperative policy
for that script until its block exits. `policy` must be a `Proc` accepting one
argument and returning **literal `true`** to permit continuation:

- `nil` means a checkpoint, such as a downstream read or guarded wait.
- A frozen `String` means an impending game socket write. It is a detached copy
  of the exact wire command. `Game.puts` has already added `$cmd_prefix`;
  `Game._puts` passes the raw command supplied by its caller without adding or
  stripping a prefix.

For example, this policy bounds elapsed time and attempted writes for one thread:

```ruby
deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10.0
writes = 0
policy = lambda do |command|
  within_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
  within_budget = command.nil? || (writes += 1) <= 3
  within_time && within_budget
end

begin
  Script.current.with_execution_guard(policy) do |_guard|
    fput 'look'
  end
rescue Lich::Common::ScriptExecutionGuard::Interrupted => error
  echo "Stopped: #{error.reason}"
end
```

There is no built-in command budget or deadline: the policy supplies those
decisions. Retries reach the socket check separately; `Game.puts` delegating to
`Game._puts` is checked once. A permitted write attempt does not prove that the
server received or executed it. Policies should inspect local observations,
return promptly, and never send commands. Recursive sends cancel the scope with
`:reentrant_command`. Reading `Script.current` from the callback is supported.

The block receives a cancellation handle. `guard.cancel!(:manual_hold)` latches
cancellation; the next checkpoint raises `Interrupted`. Cancellation is shared
across threads, and the first reason wins. Reasons must be short lowercase
identifiers; invalid labels become `:cancelled`. Returning anything except `true`
latches `:checkpoint_rejected` or `:command_rejected`. Callback exceptions become
`:callback_error`; their original text and cause are not exposed by the
interruption.

The scope checks both entry and successful block completion. Rescuing an
interruption inside the block does not clear cancellation. Cleanup closes the
handle and removes the policy even when the block raises. An overlapping or
nested guard on the same script raises `ArgumentError`.

The policy belongs to the Script instance. Workers attributed to that script
share it; separately started child scripts do not inherit it. The owner must
join its workers before leaving the scope. If workers share policy counters or
other mutable observations, synchronize that state inside the policy.

## Guarding a named child from startup through cleanup

For an existing script that cannot install its own block scope, pass the policy
in the normal launch options:

```ruby
child = Script.start_child('go2', '223 --disable-confirm',
                           { quiet: true, execution_guard: policy })
raise 'go2 did not start' unless child
# Retain this exact object for supervision; a same-name script is not its owner.
child.join
raise 'go2 failed' unless child.completed_successfully?
```

`Script::EXECUTION_GUARD_PROTOCOL == 1` identifies the instance guard API
(`with_execution_guard`, `execution_guard_active?`, `check_execution_guard!`,
and `execution_sleep`). `Script::START_EXECUTION_GUARD_PROTOCOL == 1`
separately identifies guarded named-script startup support. `Script.start`,
`Script.run`, and `Script.run_child` accept the same options hash; `run_child`
also accepts `execution_guard: policy` alongside its `timeout:` keyword.
Omitting the option (or passing `nil`) keeps ordinary launch behavior.

The policy is installed before the worker starts, after which the normal child
adoption and startup gate ensure that its first checkpoint belongs to the exact
child. The callback is evaluated by that child's worker, not by the launching
parent. A refused initial checkpoint prevents its script body from running and
is recorded in `exit_error`. Policies must therefore support startup observations
before the caller has received the returned handle. A caller using a short
startup handshake must bound that wait and permit cancellation.

Unlike a block scope, this guard stays active during the script body's `ensure`
blocks and before-dying callbacks, including external-kill cleanup. A cancelled
policy does not permit cleanup commands; owners must provide a separately
authorized recovery operation when needed. The guard closes only after cleanup
and owned workers have terminated, or after an abandoned startup is discarded.
Rescuing an interruption or calling `exit` cannot turn a cancelled run into a
successful result. Guarded children still do **not** implicitly guard further
child scripts; callers must explicitly supervise any such descendants. This
option supplies no routing rules, automatic return trip, or preemptive timeout.

### Prohibiting descendant launches explicitly

`Script::SCRIPT_START_RESTRICTION_PROTOCOL == 1` identifies support for
`allow_script_starts: false`. Supply it with the launch policy when an existing
helper must not create unguarded scripts:

```ruby
child = Script.start_child('go2', '223 --disable-confirm',
                           { quiet: true, execution_guard: policy,
                             allow_script_starts: false })
```

The same opt-in applies to block scopes, for example read-only map admission:

```ruby
Script.current.with_execution_guard(->(wire) { wire.nil? }, allow_script_starts: false) do
  Map.dijkstra(origin_id, destination_id)
end
```

Native named, anonymous, and exec-script startup admission checks the actual
calling worker's guard before reserving a script name, adopting a child, or
creating a worker. `force: true` and explicitly detached parent options do not
bypass the check. A prohibited launch latches `:script_start_rejected`, including
attempts from policy callbacks or teardown callbacks; subsequent commands remain
cancelled. `run_child` also accepts `allow_script_starts:` as a keyword. A launch
restriction requires a policy, and the value must be boolean. The default is
`true`, preserving existing script-start behavior for ordinary guards and scripts.

This is deliberately not a restriction on all Ruby effects or script lifecycle
operations: it does not intercept direct socket access, arbitrary constructors,
or separately requested kills. It prevents native script launches from escaping
a reviewed helper's execution scope, rather than automatically extending that
scope to unknown descendants.

Checks currently cover the game write seam, downstream `gets`/`gets?`, upstream
and unique-script reads (`upstream_gets`, `unique_gets`, and their `?` polling
forms), script pause checkpoints, and helpers routed through
`Script.execution_sleep`.
`script.check_execution_guard!` provides an explicit checkpoint, and
`script.execution_sleep(seconds)` provides a cooperative finite wait. Guarded
downstream reads, paused-script waits and execution sleeps poll at intervals of
at most 0.05 seconds, subject to scheduling and callback duration. Code without
an active guard retains its ordinary behavior.

This is not a sandbox or preemptive timeout. Arbitrary Ruby loops, direct socket
access, unrelated scripts, and blocking calls without checkpoints are outside
its coverage. Cancellation cannot undo commands already sent or interrupt an
operating-system socket write already in progress. A caller must review the
paths it invokes rather than infer complete coverage from installing a guard.
