# Creature health API

GemStone began supplying exact `health` and `maxhealth` attributes in
`<crtrStatus>` snapshots in September 2026. Lich feeds usable values into the
existing creature HP API so scripts do not need a second, parallel set of
methods:

- `creature.health` is the exact current value from the latest snapshot. It is
  an `Integer`, including zero and negative overkill values, or `nil` when the
  latest snapshot did not provide a valid value.
- `creature.max_health` is the exact maximum from the latest snapshot. It is an
  `Integer`, including zero, or `nil` when unavailable.
- `creature.current_hp`, `creature.max_hp`, and `creature.hp_percent` prefer the
  snapshot values when both are valid integers and `max_health` is positive.
  `current_hp` and `hp_percent` preserve negative overkill values rather than
  clamping them to zero.

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

For the burgee, both `health` and `current_hp` return `-16`, and `hp_percent`
returns approximately `-4.7`. `dead?` treats zero or negative HP as dead. For
the toucan, `health` and `max_health` both retain the exact zero values, but the
positive-maximum gate keeps the existing inferred HP pathway active. A `0/0`
entity is therefore not considered dead or removed from target selection solely
because of those values.

## Snapshot and parsing behavior

`crtrStatus` is treated as a complete snapshot. Each received tag replaces both
exact health values. An absent or malformed attribute clears its corresponding
value to `nil` rather than retaining data that is no longer the latest exact
server value. Parsing accepts only complete signed or unsigned decimal integers;
values such as `75hp`, `120.0`, `1_20`, or a whitespace-padded number become
`nil` without raising an exception.

If no new `crtrStatus` tag arrives at all, Lich has no event from which to infer
that a prior value should be cleared. The fields therefore represent the latest
received snapshot, not a time-based guarantee of freshness.

## Fallback behavior

When either exact value is unavailable or `max_health` is zero, `max_hp`,
`current_hp`, and `hp_percent` fall back to the established template/default and
observed-damage model. The damage tracker continues accumulating combat-message
damage while server health is authoritative; it is not stopped, reset, or
rewritten by snapshots. Inferred overkill is also preserved: if observed damage
exceeds the inferred maximum, `current_hp` and `hp_percent` become negative and
`dead?` remains true because it checks for zero or less.

This means a transition to fallback can produce a different number from the
last exact server reading. That is intentional: retaining the last reading
would present stale data as current, while recalibrating `damage_taken` from a
snapshot could double-count a hit because status and combat messages arrive as
separate feed events. If valid attributes return later, the existing HP methods
immediately prefer them again.

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
back or disables the attributes: scripts use the continuously maintained
inferred pathway instead of a stale value.
