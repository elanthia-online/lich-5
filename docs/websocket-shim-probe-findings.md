# WebSocket Shim Probe Findings (Genie5#356 Phase 2)

Live-verified writeup of what the [GenieClient/Genie5#356](https://github.com/GenieClient/Genie5/issues/356)
phase-2 WebSocket game transport actually needs to connect, gathered while validating
`Lich::Common::GameTransport`'s `WEBSOCKET` mode. Two sources, in order of how they were used:

1. **Static analysis of play.net's own web client bundle** (`style/js/all_web_fe_min.js`, fetched
   unauthenticated over plain HTTPS -- no login required). This is authoritative: it's the literal
   source of the code a real browser session runs, not an inference from observed behavior.
2. **Live probes** against a real account's GAMEHOST/GAMEPORT, obtained via ordinary EAccess auth:
   first a transport-only handshake against DragonRealms Prime Test (`DRT`), then a full end-to-end
   game login -- session key, `/FE:` identification, real game data read back -- against both
   production DragonRealms (`DR`) and GemStone IV (`GS3`/`GS4`), and finally a real Lich session
   (extended, interactive play plus a clean shutdown) over `--game-transport=websocket`.

Status: the transport is confirmed working end-to-end for both game families in production,
including through a real Lich session. See "Not yet confirmed" for what's left (mostly instances no
available account has entitlement for).

## The client-side connection code

From `SimuSocket.tryWebSocket` from a var fetch of `https://www.play.net/style/js/all_web_fe_min.js`:

```js
socket = new WebSocket("wss://" + DynamicData.actualHost + "/shim/" + port, "websocket_shim-protocol");
socket.onopen = function() {
  socket.send("<c>" + key + "\r\n");
  socket.send("<c>/FE:WebFE /VERSION:0.2015.9.29.0 /P:WIN_XP  /XML\r\n");
  socket.send("\r\n");
  socket.send("\r\n");
};
```

This matches, character for character, the `commonSend` path used for regular in-game command
traffic too (`socket.send(e + "\r\n")`) -- confirming the shim just carries the same
newline-delimited byte stream Lich already parses, with no additional per-message framing beyond
RFC 6455 itself. No surprises there; this is what phase 2 assumed going in.

## The actual surprise: `DynamicData.actualHost` is not GAMEHOST

The WebSocket URL's host is **not** the literal GAMEHOST a real (or Lich) client gets back from
auth. From the same bundle, the assignment feeding `actualHost`:

```js
UrlParams.host.match(/(gs|chimera)/)
  ? (DynamicData.in_gs = true,  DynamicData.actualHost = "chimera.play.net")
  : UrlParams.host.match(/(dr|hydra)/)
    ? (DynamicData.in_gs = false, DynamicData.actualHost = "hydra.play.net")
    : (DynamicData.in_gs = false, DynamicData.actualHost = UrlParams.host)
```

i.e. the browser client dials one of exactly two fixed hostnames, chosen by a substring match
against the literal GAMEHOST it was handed:

| GAMEHOST matches | WebSocket actually dials |
|---|---|
| `/gs\|chimera/i` (e.g. `storm.gs4.game.play.net`, `chimera.simutronics.com`) | `chimera.play.net` |
| `/dr\|hydra/i` (e.g. `dr.simutronics.net`, `storm.dr.game.play.net`, `hydra.simutronics.com`) | `hydra.play.net` |
| anything else | the literal GAMEHOST (dead in practice -- every known instance matches one of the above two patterns) |

This is implemented as `Lich::Common::GameTransport::WEBSOCKET_HOST_OVERRIDES` /
`.websocket_host_for`, checked in the same order as the source (GemStone pattern first).

### Why this isn't just a TLS workaround

The first (wrong) hypothesis while investigating this was "the shim's TLS cert doesn't cover the
literal GAMEHOST, so just relax hostname verification." That was true as far as it went --
confirmed live:

```
$ openssl s_client -connect dr.simutronics.net:443 -servername dr.simutronics.net
Verify return code: 62 (hostname mismatch)

$ openssl s_client -connect dr.simutronics.net:443 -servername simutronics.com
Verify return code: 0 (ok)
subject=CN=simutronics.com
X509v3 Subject Alternative Name:
    DNS:simutronics.com, DNS:*.play.net, DNS:*.simutronics.com, DNS:play.net
```

-- but relaxing verification to a hardcoded identity while still *dialing* the literal GAMEHOST
was the wrong fix, just one that happened to also produce a working connection in this particular
case (the shared edge cert happens to answer for `dr.simutronics.net`'s IP too). The real client
doesn't verify a different identity than what it connects to; it simply never connects to the raw
GAMEHOST for the WebSocket leg at all. Both `hydra.play.net` and `chimera.play.net` are ordinary
`*.play.net` names, so standard, unmodified TLS hostname verification passes against them with no
special-casing -- `Lich::Common::WebSocket::Stream` needed no changes at all once
`GameTransport` was passing the right host in the first place.

## Live confirmation

### Transport handshake only (DRT, no login)

First pass: authenticated a real `DRT` (DragonRealms Prime Test) character via ordinary EAccess,
then ran the resulting GAMEHOST/GAMEPORT through the corrected transport without sending the
session key:

```
GAMEHOST=dr.simutronics.net GAMEPORT=11624   (as of 2026-09-20; do not treat as a stable value)
  -> websocket_host_for -> hydra.play.net
  -> wss://hydra.play.net:443/shim/11624, Sec-WebSocket-Protocol: websocket_shim-protocol
  -> 101 Switching Protocols
```

Also worth recording: the current live GAMEHOST for DRT (`dr.simutronics.net`) differs from the
value `docs/web-login-protocol-analysis.md` recorded during #1570's testing (`hydra.simutronics.com`,
itself a DNS alias of `storm.dr.game.play.net`). Infrastructure has evidently moved since; treat
either as a point-in-time observation, not a pinned constant -- which is exactly why
`GameTransport` derives `ws_host` from whatever GAMEHOST auth actually returns rather than
hardcoding it.

### Full end-to-end game login (production DR and GS4)

Second pass: completed the full handshake -- session key + `/FE:WebFE` identification line, exact
byte sequence as recorded above -- against both production instances, using real characters on the
account used throughout this testing. Both came back with unambiguous, real game data:

**DragonRealms (`DR`, host `dr.simutronics.net` -> `hydra.play.net`):**
```
<playerID id='REDACTED'/>
<settingsInfo  client="1.0.1.28" major="258" crc='2639179868' instance='DR'/>
Welcome to DragonRealms (R) v2.00
<app char="TestChar" game="DR" title="[DR: TestChar] Wrayth"/>
... inventory, stream windows, etc.
```

**GemStone IV (`GS3` in EAccess / `GS4` at the web layer, host `storm.gs4.game.play.net` ->
`chimera.play.net`):**
```
<playerID id='REDACTED'/>
<settingsInfo  client="1.0.1.28" major="934" crc='634887039' instance='GS4'/>
Welcome to GemStone IV (R) v5.10
<compDef id='room desc'>Lanterns illuminate the cobbled streets of the market ... (Solhaven, North Market)
... inventory, room contents, exits, etc.
```

(Player IDs and the character name above are redacted -- the original live probes returned real,
account-identifying values here; the structure and every other field are exactly as received.)

This confirms both remap branches (`hydra.play.net` and `chimera.play.net`) end-to-end, not just
the DR-family branch, and confirms the transport carries real, correctly-framed game XML both
directions with no corruption or desync -- phase 2's core premise holds for both game families.

**Caveat on logout (passes 1-2 only, see pass 3 below):** in both runs, a `quit` command was sent
after an idle-timeout heuristic decided the initial setup burst had ended, but the trailing lines
that came back look like they were still part of that same initial burst (room/inventory setup),
not a logout confirmation. The socket was closed immediately after regardless. This most likely
just meant each character went link-dead rather than logged out cleanly -- functionally identical
to what happens if any real client (Wrayth, Stormfront, a phone losing signal) crashes or loses its
connection mid-session; the game's own link-dead timeout handles this the same way it always does.
Not a transport defect, just an artifact of the probe script's simplistic "wait for a gap, then
quit" logic.

### Pass 3 -- a real Lich session over `--game-transport=websocket`

Passes 1-2 above used a standalone script driving the *web client's* exact handshake bytes
(`<c>{key}\r\n<c>/FE:WebFE ...`), not Lich itself -- leaving Lich's own, differently-shaped
handshake (a plain, unprefixed `{key}\n/FE:WRAYTH ...` relayed by a real frontend through
`games.rb`) as the single biggest open question, explicitly flagged by both
[Nisugi's review](https://github.com/elanthia-online/lich-5/pull/1664#pullrequestreview-5331566128)
and [MahtraDR's round-2 review](https://github.com/elanthia-online/lich-5/pull/1664#pullrequestreview-5331758741)
("Settles it: one `--game-transport=websocket` login through a real Lich session").

That test has now been run: a real Lich session launched with `--game-transport=websocket`
connected cleanly (`Lich.log` confirmed the WebSocket transport was used), played for an extended,
interactive session with real back-and-forth gameplay, and shut down cleanly afterward with no
issues. This confirms:

- The shim relays bytes as expected regardless of which client's exact handshake format is used --
  the `<c>`-prefixed shape used in passes 1-2 was a web-client-specific detail, not something the
  shim requires.
- The transport holds up under sustained, real interactive play, not just a short login burst.
- `Game.close`/the reader-thread stack shuts down over this transport with no issues -- the "went
  link-dead instead of a clean logout" caveat above was specific to the passes-1-2 probe script's
  simplistic shutdown, not a transport limitation.

This closes out the three biggest previously-open items (Lich's own handshake bytes, sustained
play, and clean shutdown) from "Not yet confirmed" below.

## Automatic fallback

Once the transport itself was confirmed working end-to-end for both game families (above),
`GameTransport`'s `DIRECT` mode was updated to automatically retry over `WEBSOCKET` on a
connectivity-class failure -- the actual "firewall silently drops the game port, 443 is still open"
scenario this whole feature exists for. This mirrors `Authenticator.authenticate`'s EAccess ->
WebLogin fallback from #1570 exactly: try the normal path first, fall back only on transport-level
unreachability (not on errors the other transport would hit identically), log which one actually
connected. Also required bounding `open_direct`'s TCP connect with an explicit timeout
(`Socket.tcp(..., connect_timeout: 10)` in place of a bare `TCPSocket.open`) -- a silently-blocked
port otherwise hits the OS's default SYN-retry timeout (60s+ on Linux) before the fallback ever
gets a chance to run, for the same reason `EAccess::CONNECT_TIMEOUT` exists.

**The first cut of the error list was wrong**, caught by
[Nisugi's review](https://github.com/elanthia-online/lich-5/pull/1664#pullrequestreview-5331566128)
with a real Windows repro: on Ruby 3.4+, `Socket.tcp`'s fast-fallback connector raises
`IO::TimeoutError` (an `IOError`, not `Errno::ETIMEDOUT`) for a connect timeout against a
*hostname* -- which GAMEHOST always is -- and on Windows can raise a bare `SystemCallError`
carrying only the raw WSA errno instead of the matching `Errno` subclass. Un-fixed, the fallback
simply didn't fire for the exact firewall-drops-the-port scenario this feature exists for.

The current list, `GameTransport::DIRECT_CONNECTIVITY_ERRORS`:

| Condition | Errno class | Windows WSA code (bare `SystemCallError`) |
|---|---|---|
| Connection timed out | `Errno::ETIMEDOUT` | 10060 |
| Connection refused | `Errno::ECONNREFUSED` | 10061 |
| Host unreachable | `Errno::EHOSTUNREACH` | 10065 |
| Network unreachable | `Errno::ENETUNREACH` | 10051 |
| Local firewall/policy block | `Errno::EACCES` / `Errno::EPERM` | 10013 (`WSAEACCES`) |

...plus `IO::TimeoutError` (the fast-fallback connector's actual timeout exception, see above) and
`SocketError` (DNS resolution failure). `GameTransport.direct_connectivity_error?` matches either a
class in this list directly, or a bare `SystemCallError` whose `#errno` is one of the WSA codes
above -- covering the case where Ruby doesn't map the platform errno to the matching subclass.

**`EACCES`/`EPERM` (a local firewall/policy block) were added deliberately, not just carried over
as a leftover reachability code.** POSIX documents both as `connect(2)`'s errors for "a local
firewall rule forbids this connection" -- Windows Defender Firewall and Linux `iptables OUTPUT`
rules both surface this way. Whether a local block should be routed around by an automatic fallback
was raised as an open product question in
[MahtraDR's round-2 review](https://github.com/elanthia-online/lich-5/pull/1664#pullrequestreview-5331758741)
("a local block may be deliberate"). Decided: yes -- Lich is normally run by the same person the
local block (if any) belongs to, so it's far more often their own Windows Firewall, VPN client, or a
work laptop's MDM policy getting in the way of their own tool than a third party's restriction this
transport should respect blindly. A local block that genuinely is someone else's deliberate policy
still fails, just after a slightly slower detour through the WebSocket attempt first.

This fallback logic is covered by full mocked-error unit coverage (one example per error class and
per Windows WSA code, plus a negative case confirming an unrelated error -- `EMFILE`, out of file
descriptors, deliberately *not* treated as a connectivity error since a WebSocket attempt would
likely hit the same resource exhaustion immediately -- does *not* trigger it) but has not been
exercised against an actual firewalled port live -- doing that would mean deliberately blocking
outbound traffic to a real game port from a test network, which hasn't been done. The WebSocket path
it falls back *to* has, independently, already been confirmed live end-to-end (above), so the only
untested piece is the trigger condition itself, not the destination.

## Reviewed trade-offs (accepted, not defects)

Two behavioral points [MahtraDR's review](https://github.com/elanthia-online/lich-5/pull/1664#pullrequestreview-5263085048)
raised as Minor, with a deliberate disposition on each rather than a code change:

- **The `DIRECT` -> `WEBSOCKET` fallback is not gated behind `--game-transport`, so it changes
  default-path behavior for every user, not just those who opt in.** Specifically: `open_direct`'s
  TCP connect is now bounded at 10s (`DIRECT_CONNECT_TIMEOUT`), so a previously-working-but-slow
  (>10s) direct connect now fails over to WebSocket instead of eventually succeeding; and
  `DIRECT_CONNECTIVITY_ERRORS` includes `SocketError`/`ECONNREFUSED`, so a non-play.net game host
  (a private/local proxy, say) that fails DNS or refuses the port now also dials
  `wss://<host>:443/shim/<port>` before the real error surfaces -- extra latency and a confusing
  endpoint on that failure path, though it still fails cleanly. **Accepted as intentional** --
  mirrors the `Authenticator` EAccess -> WebLogin precedent's own "silent fallback, default
  behavior" shape on purpose, not by sliding it in unnoticed. Flagged here explicitly so it's a
  recorded decision rather than an implicit one.
- **`Stream#wait_readable` has line-oriented timeout semantics that a raw socket's `wait_readable`/
  `IO.select` doesn't.** A direct socket reports readable as soon as *any* bytes arrive; `Stream`
  reports readable only once a full `"\n"`-terminated line is buffered (or EOF). Consequence: a
  newline-less fragment that stalls counts toward `consecutive_timeouts` on the WebSocket path,
  where the direct path would instead sit blocked inside `gets` with no application-level timeout
  at all (bounded only by the OS's unreliable `SO_RCVTIMEO`, per the existing comment on
  `read_server_string`) -- arguably the *worse* failure mode of the two, since it's an unbounded
  hang rather than a detected, counted timeout. **Not changed**: making `Stream#wait_readable`
  match the direct path's "ready on any bytes" semantics exactly would trade a clean, bounded
  timeout for a potential indefinite hang, which is a downgrade, not a fix. Real game XML is
  newline-terminated and arrives promptly in practice, so this is unlikely to bite -- and an
  extended, interactive real Lich session over this transport (pass 3, above) turned up no
  timeout-related issues, though that's one session's worth of favorable network conditions, not a
  guarantee against the theoretical worst case described above.

## Self-review findings (pre-upstream)

A self-review pass, run against `6b324d5` after three prior review rounds, found nothing above
Minor -- two Minor fixes, three Nits, and three open questions probed for concrete data rather than
left as pure speculation:

- **Double-failure error message named only the WebSocket endpoint.** When both `DIRECT` and the
  `WEBSOCKET` fallback failed, the exception reaching the caller (and printed to the console/log by
  every `Game.open`/`open_with_timeout` call site) was the WebSocket one -- `Errno::ECONNREFUSED ...
  127.0.0.1:443`, naming a host and port the user never typed, with the actual game-port failure
  visible only in an earlier `warn:` log line. Fixed: `open_direct` now catches the fallback's
  `ConnectionError` and re-raises one message naming both failures (`direct host:port unreachable
  (...); WebSocket fallback also failed (...)`), with the original exception preserved as `.cause`.
- **Module doc still claimed Lich's own handshake had never run over the transport,** left over
  from before pass 3 (above) confirmed exactly that. Corrected.
- **`Frame::Reader#feed` discarded already-decoded messages when a later frame in the same call was
  invalid** -- `messages` was a local, thrown away along with the raised `ProtocolError`. Since the
  error is fatal regardless, the practical cost was losing the last lines before a forced shutdown --
  usually the ones most likely to explain why. Fixed with a deferred-error pattern mirroring how EOF
  already works: `ProtocolError` now carries whatever it had already decoded
  (`#decoded_messages`), `Stream#pump!` ingests those into the line buffer and stashes the error
  instead of raising immediately, and `#gets` returns the salvaged lines first (one per call, same
  as any other queued lines) before finally raising the stashed error once the buffer drains.
- **A dead `rescue IO::WaitReadable` clause in `Stream#pump!`.** Verified two ways: `#readpartial` on
  this always-blocking `SSLSocket` never raises a WaitReadable-shaped error in the first place
  (non-blocking APIs would, blocking ones absorb the retry internally), and even if it somehow did,
  `OpenSSL::SSL::SSLErrorWaitReadable` is an `SSLError` subclass, so the `rescue OpenSSL::SSL::SSLError`
  clause listed first would catch it before this one ever could. Removed; the SSLError rescue's
  comment now notes why this case is moot rather than leaving a misleading dead branch.
- **`@return [TCPSocket, ...]` was inaccurate for direct mode.** `Socket.tcp` (used since the
  automatic-fallback work) returns a `Socket`, not a `TCPSocket` -- `Socket.tcp(...).is_a?(TCPSocket)`
  is `false`. Nothing in lich-5 calls a `TCPSocket`/`IPSocket`-only method on the game socket, so this
  was doc-only; corrected the YARD tags (and the matching test doubles) to `Socket`.

**Open questions probed for data, not left purely speculative:**

- **Does the shim send its own keepalive ping while idle?** No -- `all_web_fe_min.js` contains
  exactly two `setInterval` calls (`GameBuffer.process`, mouse-move tracking), neither touching the
  socket, and neither "ping" nor "keepalive" appears anywhere in the bundle. The web client relies
  entirely on the server's own ping/pong (which `Stream` already answers) or simply isn't exposed to
  an idle-timeout problem in practice (a browser tab has other background traffic keeping the
  connection non-idle even without an app-level ping). This doesn't settle whether an edge/load
  balancer actually *drops* a quiet WebSocket connection after some idle window -- pass 3's session
  was "extended, interactive," which kept the connection busy throughout, not idle. **Still open:**
  leaving a `--game-transport=websocket` session genuinely idle (no commands, no scripts) for
  10+ minutes and seeing whether it survives.
- **What happens when the shim's backend (the actual game process) is unreachable, simulating an
  outage?** Tested directly: `GameTransport.open_websocket("dr.simutronics.net", 1)` -- port 1,
  nothing listening -- **the WS upgrade still succeeds** (`101 Switching Protocols`). The connection
  then goes silent: no close frame, no EOF, not even after sending a bogus key/`/FE:` handshake and
  waiting 15+ seconds total. The shim evidently doesn't verify the backend is reachable before
  completing the upgrade. Consequence: during a real game-server outage, a user with the automatic
  fallback enabled would see `DIRECT` fail fast (`ECONNREFUSED`/timeout), then the `WEBSOCKET`
  fallback silently "succeed" and hang -- recovered only by the existing
  `MAX_CONSECUTIVE_READ_TIMEOUTS` mechanism in `games.rb` (3 x `READ_TIMEOUT_SECONDS`, ~5 minutes),
  reported as `:game_timeout`, not the `:game_eof` one might expect. Not a new bug -- that recovery
  path already exists for any "connected but dead" scenario -- but a real, now-confirmed, several-
  -minutes-long user-visible delay specific to an outage-during-fallback that's worth knowing about
  rather than guessing at.
- **Does the shim reject a text frame containing an invalid UTF-8 byte** (RFC 6455 §8.1: an endpoint
  receiving invalid UTF-8 in a TEXT frame must close with code 1007), given `Stream#puts` always
  sends opcode TEXT and a command could contain a raw Latin-1/CP1252 byte from a script or frontend?
  **Not yet tested** -- this needs a live authenticated session to send an actual in-game command
  through, unlike the two questions above.

## MahtraDR round-3/round-4 delta reviews (pre-upstream)

Two further real-socket-verified nits, each carrying a repro and an already-verified fix, found in
[round 3](https://github.com/elanthia-online/lich-5/pull/1664#pullrequestreview-5332654144) (against
the EACCES/EPERM commit) and [round 4](https://github.com/elanthia-online/lich-5/pull/1664#pullrequestreview-5332860264)
(against the self-review commit):

- **`Stream.connect` set `connected = true` before `new(ssl_socket, prefill: remainder)`.**
  `#initialize` feeds `prefill` through the frame reader, which can itself raise -- a malformed
  frame arriving in the same TLS read as the `101` response raises `ProtocolError` from inside
  `new`. With `connected` already `true` by that point, the `ensure` block believed the connect had
  succeeded and skipped closing `raw_socket`, reopening (in a narrower form -- it needs a
  misbehaving server, not just a slow one) the exact leak the `Thread#kill` fix was written to
  close. Fixed: `stream = new(...); connected = true; stream`, so `connected` only flips once
  construction has actually finished.
- **The deferred-error path in `#gets` dropped a trailing newline-less tail.** It checked
  `@pending_error` before checking for a leftover, non-newline-terminated fragment in
  `@line_buffer` -- unlike the `@eof` branch immediately below it, which already flushes that
  leftover via `#flush_remaining!` first. Since the whole point of deferring the error is to
  preserve the last data before a forced disconnect, silently losing the very last (possibly
  incomplete) line undercut that. Fixed: flush a leftover tail first if one exists, and only raise
  once the buffer is actually empty.

Both fixes match the reviewer's own verified proposals exactly, confirmed against their given repro
shapes.

## Not yet confirmed

- **DRX (Platinum) / DRF (Fallen) / GSX (Platinum, retired)** -- inherits the same gap
  `docs/web-login-protocol-analysis.md` already notes for these instances at the auth layer; no
  entitled account has been available to confirm their GAMEHOST values, so whether they follow the
  same two-pattern remap is assumed, not confirmed.
- **Whether the shim tolerates an invalid-UTF-8 byte in a TEXT frame** -- see above.

~~Sustained/interactive play, a clean `Game.close`-driven shutdown, and Lich's own (un-prefixed)
handshake bytes~~ -- all confirmed by pass 3 above (a real Lich session over
`--game-transport=websocket`).
