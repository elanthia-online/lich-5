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
the short estimate again. A negative id is refused too: DragonRealms reports
`Map.current_room_id` as -1 when it doesn't know the room. A non-numeric String
is refused, not looked up by title. If the path already begins with the `from:` room, that room is not added
a second time, so a full path is also safe to pass with `from:`.

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
