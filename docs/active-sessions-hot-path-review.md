# ActiveSessions Hot Path Review

## Root Cause

The original Active Sessions API implementation (`#1274`) placed the
`active_sessions_api` feature flag on a heartbeat-driven hot path:

- `Lifecycle.start` gated on `ActiveSessions.enabled?`
- heartbeat upserts called `ActiveSessions.register_session`
- `register_session` gated on `enabled?` again
- `register_session` then called `ensure_service!`
- `ensure_service!` gated on `enabled?` again

This caused repeated SQLite-backed feature-flag reads per process, per
heartbeat, for a feature whose enablement rarely changes during runtime.

## Why It Surfaced

In multi-session usage, each process runs its own lifecycle heartbeat loop.
That multiplied redundant reads of `FeatureFlags.enabled?(:active_sessions_api)`
until SQLite lock pressure became visible in logs as `BusyException` warnings.

## This Branch

This branch applies a narrow cleanup:

- gate the feature once at lifecycle start
- latch that admitted state in the lifecycle instance
- stop re-checking the feature flag for heartbeat/listener/shutdown hot paths
- preserve local listener state independent of transient feature-flag failures

## Summary Of What Changed

- Added an `assume_enabled:` internal path in `ActiveSessions` so lifecycle
  callers do not re-read the same feature flag after startup admission.
- Latched feature admission in `Lifecycle.start` and reused that state for
  heartbeat upserts, listener updates, and teardown.
- Kept the normal public gate behavior intact for callers that do not pass
  `assume_enabled:`.
- Expanded specs to cover both the normal gate and adversarial cases where
  `enabled?` would raise after the lifecycle has already started.

## Review Guidance For Adjacent PRs

When reviewing nearby PRs, separate them into:

1. Root-cause cleanup
- removes redundant ActiveSessions hot-path flag polling

2. Symptom mitigation
- caches feature flags
- adds SQLite timeouts/WAL
- hardens listener behavior during transient failures

3. Broader architectural improvements
- local DB path strategy
- single-owner DataStore / owner-subscriber persistence model

The key question is whether a PR solves the original hot-path design problem,
or only reduces the pain it causes.
