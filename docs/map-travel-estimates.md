# Map travel time estimates

`Map.estimate_time(path)` adds up the `timeto` of each leg between consecutive
rooms in `path`. The first element is the room the trip starts in, so
`[a, b, c]` counts the legs a to b and b to c. A leg with no `timeto` counts as
0.2 seconds. A StringProc `timeto` is evaluated.

## Paths from `path_to` and `findpath` leave out the start

`room.path_to(destination)` and `Map.findpath(source, destination)` return the
rooms to walk through: the destination is included, but the starting room is
not. Passing one of those paths on its own makes `estimate_time` treat the first
step as the start, so the leg out of the starting room is never counted. A trip
of one step always estimates 0.0.

Name the starting room with `from:` to count that leg:

```ruby
start = Room.current
path = start.path_to(destination)
seconds = Map.estimate_time(path, from: start) if path
```

Read `Room.current` once and reuse it, as above. It changes as soon as the
character moves, so reading it a second time can name a different room from
the one the path was built from.

`from:` takes a room, a room id, or a numeric id String, and works the same
whether you call `Map.estimate_time` or `Room.estimate_time`. Anything else
raises `ArgumentError`, including an explicit `nil` (what `Room.current` gives
in an unmapped room), since quietly treating it as "no start room" would return
the short estimate again. A negative id is refused too: on DragonRealms,
`Map.current_room_id` is -1 until the first room match after the map loads (and
`nil` for an unmapped room after that). A non-numeric String is refused, not
looked up by title. An id with no room in the map also raises `ArgumentError`
rather than counting the first leg as 0.2 seconds; a GemStone uid passed as a
bare Integer where a Lich room id belongs would otherwise give a quietly wrong
estimate. A `"u123"` uid String is refused as well: pass the Lich room id or
the room. Rooms missing from inside the path still count 0.2 seconds per leg,
as before.

If the path already begins with the `from:` room (compared as numbers, so
`"012"` matches room 12), that room is not added a second time, so a full path
is also safe to pass with `from:`. Otherwise the `from:` room must have an exit
to the first room of the path, or `estimate_time` raises `ArgumentError`. This
catches a start room read again after the character moved. An exit with no
`timeto` still counts 0.2 seconds. A stale start room that happens to be the
first room of the path can't be told apart from a full path, so it is taken as
one; reading `Room.current` once avoids both cases.

Leave `from:` out and `estimate_time` behaves as it always has.

## Errors and the argument

- A path that is not an Array raises `ArgumentError`. The most common case is
  the nil `path_to` returns when the destination can't be reached. Check for nil
  first, or rescue it. `ArgumentError` is a `StandardError`, so a bare `rescue`
  catches it, and an uncaught one appears as an ordinary Lich script error.
  Before this change, `estimate_time` raised a plain `Exception`. A bare
  `rescue` did not catch that, and the script error handler did not report it.
- `estimate_time` does not modify the Array you pass, and it accepts a frozen
  one. Before this change it emptied the Array down to its last element.
