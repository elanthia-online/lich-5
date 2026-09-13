# Optional static map routing

`Map.dijkstra(source, destination, static_only: true)` and
`room.dijkstra(destination, static_only: true)` reuse the existing pathfinder but
skip edges unless `wayto` is a plain String and `timeto` is a finite, nonnegative
real Numeric. StringProc weights are skipped before evaluation. The existing
`dijkstra_hashes` aliases accept the same keyword.

Omitting the keyword, or passing `false`, preserves normal route selection and
dynamic weight evaluation. In both cases, class dispatch passes only the
positional destination, so existing positional-only `Room#dijkstra` overrides
remain compatible. Explicitly passing `static_only: true` forwards that keyword
to the instance method. Custom overrides must accept and honor the keyword to
support static routing; an override accepting only the positional destination
raises `ArgumentError` when called with this opt-in. No preference weights or
map entries are changed. Return values remain the existing predecessor/distance
hashes.

Static routing can find a longer ordinary route or leave the destination
unreachable when dynamic edges are necessary. It does not execute movement,
validate the meaning of a String command, prove a destination safe, or guarantee
that mutable map data remains unchanged after planning. Callers must validate
commands and current room transitions and enforce their own execution budget.
This restriction is not a sandbox for arbitrary Ruby objects or map extensions.
