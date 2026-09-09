# Optional static map routing

`Map.dijkstra(source, destination, static_only: true)` and
`room.dijkstra(destination, static_only: true)` reuse the existing pathfinder but
skip edges unless `wayto` is a plain String and `timeto` is a finite, nonnegative
real Numeric. StringProc weights are skipped before evaluation. The existing
`dijkstra_hashes` aliases accept the same keyword.

Omitting the keyword, or passing `false`, preserves normal route selection and
dynamic weight evaluation. Existing positional instance overrides remain
compatible with default class dispatch. No preference weights or map entries
are changed. Return values remain the existing predecessor/distance hashes.

Static routing can find a longer ordinary route or leave the destination
unreachable when dynamic edges are necessary. It does not execute movement,
validate the meaning of a String command, prove a destination safe, or guarantee
that mutable map data remains unchanged after planning. Callers must validate
commands and current room transitions and enforce their own execution budget.
This restriction is not a sandbox for arbitrary Ruby objects or map extensions.
