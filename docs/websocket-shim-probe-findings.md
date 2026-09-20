# WebSocket Shim Probe Findings (Genie5#356 Phase 2)

Live-verified writeup of what the [GenieClient/Genie5#356](https://github.com/GenieClient/Genie5/issues/356)
phase-2 WebSocket game transport actually needs to connect, gathered while validating
`Lich::Common::GameTransport`'s `WEBSOCKET` mode. Two sources, in order of how they were used:

1. **Static analysis of play.net's own web client bundle** (`style/js/all_web_fe_min.js`, fetched
   unauthenticated over plain HTTPS -- no login required). This is authoritative: it's the literal
   source of the code a real browser session runs, not an inference from observed behavior.
2. **A live probe** against a real DragonRealms Prime Test (`DRT`) account's GAMEHOST/GAMEPORT,
   obtained via ordinary EAccess auth, confirming the values derived from (1) actually complete a
   WebSocket upgrade against the production endpoint.

No live game connection (i.e. sending the session KEY) was completed as part of gathering these
findings -- see "Not yet confirmed" below.

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

Authenticated a real `DRT` (DragonRealms Prime Test) character via ordinary EAccess, then ran the
resulting GAMEHOST/GAMEPORT through the corrected transport:

```
GAMEHOST=dr.simutronics.net GAMEPORT=11624   (as of 2026-09-20; do not treat as a stable value)
  -> websocket_host_for -> hydra.play.net
  -> wss://hydra.play.net:443/shim/11624, Sec-WebSocket-Protocol: websocket_shim-protocol
  -> 101 Switching Protocols
```

No session KEY was sent in this probe, so no character entered the game -- this confirms the
transport-level handshake only (TCP connect, TLS, RFC 6455 upgrade), not the full game-login
sequence.

Also worth recording: the current live GAMEHOST for DRT (`dr.simutronics.net`) differs from the
value `docs/web-login-protocol-analysis.md` recorded during #1570's testing (`hydra.simutronics.com`,
itself a DNS alias of `storm.dr.game.play.net`). Infrastructure has evidently moved since; treat
either as a point-in-time observation, not a pinned constant -- which is exactly why
`GameTransport` derives `ws_host` from whatever GAMEHOST auth actually returns rather than
hardcoding it.

## Not yet confirmed

- **A full live game login over the WebSocket transport** -- actually sending the session KEY and
  the `/FE:` identification line and confirming real game XML comes back. The transport-level
  handshake (this document) is necessary but not sufficient; this is the next step before phase 2
  could be considered validated end-to-end.
- **GS-family (`chimera.play.net`) path** -- only the DR-family (`hydra.play.net`) branch has been
  exercised live. The GemStone branch is implemented identically per the same source but untested.
- **DRX (Platinum) / DRF (Fallen) / GSX (Platinum, retired)** -- inherits the same gap
  `docs/web-login-protocol-analysis.md` already notes for these instances at the auth layer; no
  entitled account has been available to confirm their GAMEHOST values, so whether they follow the
  same two-pattern remap is assumed, not confirmed.
