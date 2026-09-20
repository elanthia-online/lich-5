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
   production DragonRealms (`DR`) and GemStone IV (`GS3`/`GS4`).

Status: the transport is confirmed working end-to-end for both game families in production. See
"Not yet confirmed" for what's left (mostly instances no available account has entitlement for).

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

**Caveat on logout:** in both runs, a `quit` command was sent after an idle-timeout heuristic
decided the initial setup burst had ended, but the trailing lines that came back look like they
were still part of that same initial burst (room/inventory setup), not a logout confirmation. The
socket was closed immediately after regardless. This most likely just means each character went
link-dead rather than logged out cleanly -- functionally identical to what happens if any real
client (Wrayth, Stormfront, a phone losing signal) crashes or loses its connection mid-session; the
game's own link-dead timeout handles this the same way it always does. Not a transport defect, just
an artifact of the probe script's simplistic "wait for a gap, then quit" logic.

## Automatic fallback

Once the transport itself was confirmed working end-to-end for both game families (above),
`GameTransport`'s `DIRECT` mode was updated to automatically retry over `WEBSOCKET` on a
connectivity-class failure (`Errno::ETIMEDOUT`/`ECONNREFUSED`/`EHOSTUNREACH`/`ENETUNREACH`/
`SocketError`) -- the actual "firewall silently drops the game port, 443 is still open" scenario
this whole feature exists for. This mirrors `Authenticator.authenticate`'s EAccess -> WebLogin
fallback from #1570 exactly: try the normal path first, fall back only on transport-level
unreachability (not on errors the other transport would hit identically), log which one actually
connected. Also required bounding `open_direct`'s TCP connect with an explicit timeout
(`Socket.tcp(..., connect_timeout: 10)` in place of a bare `TCPSocket.open`) -- a silently-blocked
port otherwise hits the OS's default SYN-retry timeout (60s+ on Linux) before the fallback ever
gets a chance to run, for the same reason `EAccess::CONNECT_TIMEOUT` exists.

This fallback logic is covered by full mocked-error unit coverage (one example per error class in
the list above, plus a negative case confirming an unrelated error does *not* trigger it) but has
not been exercised against an actual firewalled port live -- doing that would mean deliberately
blocking outbound traffic to a real game port from a test network, which hasn't been done. The
WebSocket path it falls back *to* has, independently, already been confirmed live end-to-end
(above), so the only untested piece is the trigger condition itself, not the destination.

## Not yet confirmed

- **DRX (Platinum) / DRF (Fallen) / GSX (Platinum, retired)** -- inherits the same gap
  `docs/web-login-protocol-analysis.md` already notes for these instances at the auth layer; no
  entitled account has been available to confirm their GAMEHOST values, so whether they follow the
  same two-pattern remap is assumed, not confirmed.
- **Sustained/interactive play over the transport** -- both live runs above were short (login burst,
  a handful of lines, then disconnect) rather than an extended session exercising two-way traffic,
  keepalive/ping-pong under real network conditions, or a clean `Game.close`-driven shutdown through
  the full `games.rb` reader/parser thread stack rather than a standalone script talking to `Stream`
  directly.
