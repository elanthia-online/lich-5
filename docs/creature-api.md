# Creature server-health API

GemStone began supplying exact `health` and `maxhealth` attributes in
`<crtrStatus>` snapshots in September 2026. Runtime creature instances expose
the latest exact values through a server-specific API that remains independent
of Lich's established inferred-HP behavior:

- `creature.server_health` — exact current server value as an `Integer`,
  including zero and negative overkill values; `nil` when unavailable.
- `creature.server_max_health` — exact maximum server value as an `Integer`,
  including zero; `nil` when unavailable.
- `creature.server_health_percent` — `server_health / server_max_health * 100`,
  rounded to one decimal place. It is `nil` when either value is unavailable or
  `server_max_health` is zero. The result is not clamped, so negative health
  produces a negative percentage.

## Captured feed examples

These tags are reproduced from raw GemStone server captures. A living
silver-eyed sleek onyx panther reported:

```xml
<crtrStatus exist="357970513" health="260" maxhealth="260" challenging="1"/>
```

A dead scaly burgee preserved damage beyond zero:

```xml
<crtrStatus exist="360586159" health="-16" maxhealth="340" hostile="1" dead="1" prone="1"/>
```

A noncombat black-necked hooded toucan legitimately reported zero for both
values:

```xml
<crtrStatus exist="356889321" health="0" maxhealth="0" inferior="1"/>
```

For these examples, `server_health` returns `260`, `-16`, and `0`, respectively.
The toucan's `server_health_percent` is `nil` because its maximum is zero.

## Snapshot and parsing behavior

`crtrStatus` is treated as a complete snapshot. Each received tag replaces both
server-health values. An absent or malformed attribute clears its corresponding
value to `nil` rather than retaining data that is no longer the latest exact
server value. Parsing accepts only complete signed or unsigned decimal integers;
values such as `75hp`, `120.0`, `1_20`, or a whitespace-padded number become
`nil` without raising an exception.

If no new `crtrStatus` tag arrives at all, Lich has no event from which to infer
that a prior value should be cleared. The values therefore represent the latest
received snapshot, not a time-based guarantee of freshness.

## Observed feed behavior

The snapshot policy was checked against 186 raw server captures totaling about
11 GB and containing 2,352,662 `crtrStatus` tags. Of those, 52,154 supplied
health data. The observations were:

- `health` and `maxhealth` were always supplied together; there were no partial
  health pairs.
- Every supplied value was a valid signed or unsigned decimal integer.
- There were 49,040 consecutive health-bearing updates for the same creature.
- There were 83 absent-to-present transitions during the feature rollout.
- There were no present-to-absent transitions for the same creature.

This supports treating the pair as part of the complete snapshot once enabled.
Clearing on a future omission also gives a safe failure mode if GemStone rolls
back or disables the attributes: callers receive `nil`, not stale data presented
as an exact current value.

## Backward compatibility

The server-health API does not replace or feed Lich's existing fields and
inferred HP methods:

- `health` and `health=` retain their pre-existing behavior and storage.
- `max_hp` comes from creature templates or the combat-tracker fallback.
- `current_hp` subtracts observed combat damage from `max_hp` and clamps at zero.
- `hp_percent`, `low_hp?`, `dead?`, Coup de Grace checks, and target selection
  continue to use the inferred values and structured status flags.

Consequently, an entity reporting `health="0" maxhealth="0"` is not considered
dead or removed from target selection solely because of the server-health data.
Scripts may opt into the exact values without changing existing combat behavior.
