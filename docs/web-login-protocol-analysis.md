# Web Login Protocol Analysis

## Overview

This document captures findings from probing play.net's HTTPS web login flow (`www.play.net`),
as a candidate fallback authentication path for when `eaccess.play.net:7910` (TLS) is
unreachable. Captured via a live browser session (Playwright) against `https://www.play.net/dr/play/`
using a real test account, DragonRealms Prime and DragonRealms Prime Test instances.

Unlike the EAccess protocol (tab-delimited text over a raw TLS socket, see
[eaccess-protocol-analysis.md](eaccess-protocol-analysis.md)), this flow is a sequence of
ordinary HTTPS form POSTs / redirects (ASP.NET, `www.play.net`), authenticated by a session
cookie set after login. It terminates in the same information the EAccess `L` command returns:
a game server host, port, and one-time connection key.

---

## Implementation Status

A `Lich::Common::Authentication::WebLogin` module implementing this flow has been built
(`lib/common/authentication/web_login.rb`) and exercised live end-to-end: DR Test, GemStone Prime
(`GS3`->`GS4` mapping), GemStone Test, and a bad-password failure all confirmed working against
the real play.net servers, matching the browser-captured hosts/ports exactly. Two things were
only discovered by building and running a non-browser HTTP client, not by watching the browser:

1. **A browser-like `User-Agent` header is required on every request, including the very first
   GET.** play.net's front end (CloudFront/WAF) returns a bare `500` for Ruby's default
   `Net::HTTP` User-Agent (`Ruby/x.y.z`) -- not documented anywhere, not visible from the browser
   capture since a real browser always sends one. Every request must set this header.
2. **The login POST requires a pre-existing ASP session cookie from a prior `GET` of the
   sign-in page** (e.g. `GET /dr/signin_needed.asp`) -- posting `login.asp` cold (no session
   cookie) also returns a bare `500`. A real browser always visits the sign-in page before
   submitting the form, so this dependency is invisible in a browser capture alone. The module
   issues this GET itself and carries its cookie into the login POST.

Both were invisible in the pure browser capture and only surfaced once a standalone Ruby client
tried the same requests -- worth remembering if this flow needs re-verifying after a play.net
change: reproduce with a non-browser client, not just by re-watching DevTools.

---

## Request Chain

### 1 -- Login (establishes session cookie)

```
POST https://www.play.net/includes/common/login/login.asp
Content-Type: application/x-www-form-urlencoded

return_okay_page=%2Fdr%2Fplay%2Fhome.asp
&return_error_page=%2Fdr%2Flogin_error.asp
&remember_account=
&remember_password=
&account_name={ACCOUNT}
&account_password={PASSWORD}
&submit=Login
```

- Password is sent **in the clear as an HTTPS form field** -- no client-side hashing/obfuscation
  (unlike EAccess's XOR scheme). Security rests entirely on TLS.
- On success: `302` redirect to whatever `return_okay_page` was set to. A session cookie is
  established (not inspected in detail here -- treat as an opaque authenticated session, sent
  automatically by any HTTP client that preserves cookies across the chain).
- On failure: `302` redirect to `return_error_page` instead. **The redirect target itself is the
  pass/fail signal** -- compare the `Location` header's path against the two page params you
  sent, don't parse body text for control flow.
  - Confirmed failure case: wrong password -> redirects to
    `/dr/login_error.asp?error=&returnto=/dr/`, page body has heading `"Invalid password."`.
    Other failure modes (bad account name, locked account, etc.) not yet probed -- likely land on
    the same `login_error.asp` page with a different heading, analogous to EAccess's
    `REJECT`/`NORECORD`/`INVALID`/`PASSWORD` codes but not yet enumerated here.

`return_okay_page`/`return_error_page` are attacker-controlled-looking (client supplies them) but
game-specific (`/dr/...` vs presumably `/gs4/...`) -- set them to the game's own home/error page.

---

### 1a -- Resolving `charID` (no EAccess-`C`-equivalent enumeration endpoint)

Unlike EAccess's `C` command, there is no separate API call that lists an account's characters
for a game family. The character list is server-rendered directly into the game's `home.asp`
page (the `return_okay_page` from step 1) as radio inputs, confirmed live:

```html
<input type=radio name="charID" id="W_TESTACCOUNT_000" value="W_TESTACCOUNT_000" checked  >
<label for="W_TESTACCOUNT_000"><span class="normS1">Raiyen</span></label><br>
```

So resolving a `char_name` to the `charID` needed for step 2 means: `GET` the family's
`home.asp` (or equivalent per-instance page, e.g. `playdrt.asp` for DR Test, `play_test.asp` for
GS Test -- same character list, different subscription-tier framing) with the session cookie
from step 1, then regex-scrape `id="(W_[^"]+)"` paired with the following
`<label for="\1"><span[^>]*>([^<]+)</span>` for the display name. Confirmed the session cookie
from a single `login.asp` call is valid across both game families (DR and GS4) in the same
browser session -- one login, both games' `home.asp` pages render correctly without re-posting
credentials.

This HTML-scrape step is inherently more fragile than EAccess's tab-delimited `C` response --
any markup change on play.net's end breaks it silently (returns no match) rather than erroring
clearly. Treat it as the most likely maintenance burden of this whole fallback path.

---

### 2 -- Select Character / Game Instance

```
POST https://www.play.net/includes/common/play/goplay2.asp
Content-Type: application/x-www-form-urlencoded

charID={CHAR_CODE}
&NEWCHARSUB=TRUE
&managesub=0
&gameName={dr|gs4}
&instanceID=0
&game={GAME_CODE}
&frontend=web
```

- `charID` -- same character-code format EAccess's `C` command returns (e.g. `W_TESTACCOUNT_000`).
  Characters are shared across instances of the same game family here too (confirmed: same
  `charID` worked unchanged for both `game=DR` and `game=DRT`).
- `gameName` -- the game **family**, lowercase: `dr` for all DragonRealms instances, `gs4` for
  all GemStone IV instances (confirmed live).
- `game` -- the specific **instance code**. **Does NOT always match the EAccess game code --
  confirm each one live, don't assume passthrough.** Confirmed:
  - `game=DR` (DragonRealms Prime) -> host `storm.dr.game.play.net`, port `11024` -- matches EAccess `DR`
  - `game=DRT` (DragonRealms Prime Test) -> host `hydra.simutronics.com`, port `11624` -- matches EAccess `DRT`
  - `game=GS4` (GemStone IV Prime) -> host `storm.gs4.game.play.net`, port `10024` --
    **differs from EAccess, which uses `GS3` for this instance.** The web layer has its own code
    table; `GS3` is not accepted here (untested whether it would error or silently fail --
    `GS4` is the confirmed-working value).
  - `game=GST` (GemStone IV Prime Test) -> host `chimera.simutronics.com`, port `10624` --
    matches EAccess `GST`

  Not yet confirmed live: `DRF` (Fallen), `DRX` (Platinum), `GSF` (Shattered), `GSX` (Platinum).
  Given the confirmed `GS3`->`GS4` mismatch, **do not assume these match their EAccess codes
  either** -- each must be probed individually before being relied on. A `WebLogin` module should
  carry its own explicit `game_code` mapping table (seeded from EAccess codes where confirmed
  identical, overridden where not), not reuse EAccess's codes directly.
- `instanceID=0` in both observed cases -- meaning not yet determined (possibly multi-session
  slot, unrelated to which game instance is selected -- that's `game`).
- Response: `302` to `/{gameName}/play/playing_web.asp`.

---

### 3 -- Redirect Chain to Connection Info

```
GET /{gameName}/play/playing_web.asp
  -> 302 -> /includes/common/play/goplay_web.asp
    -> 302 -> https://www.play.net/play/home.asp?host={GAMEHOST}&port={GAMEPORT}&key={KEY}
```

The final `Location` header carries the same triple as EAccess's `L\tOK\t...` response
(`GAMEHOST`/`GAMEPORT`/`KEY` keys in that protocol). This is the payload our fallback module
actually needs -- everything before this is just how to obtain it over HTTPS instead of TLS:7910.

**This is a one-time key** -- same characteristic as the EAccess session key: presumably expires
quickly and is single-use, so it must be fetched fresh per connection attempt, not cached.

---

## What Happens After (informational -- not needed for the fallback)

The official web client (loaded at `/play/home.asp?host=...&port=...&key=...`) does **not** open
a raw TCP socket to `{GAMEHOST}:{GAMEPORT}` -- browsers can't. Instead
(`style/js/all_web_fe_min.js`, `SimuSocket.tryWebSocket`):

```js
socket = new WebSocket("wss://" + actualHost + "/shim/" + port, "websocket_shim-protocol");
socket.onopen = () => {
  socket.send("<c>" + key + "\r\n");
  socket.send("<c>/FE:WebFE /VERSION:0.2015.9.29.0 /P:WIN_XP  /XML\r\n");
  socket.send("\r\n");
  socket.send("\r\n");
};
```

i.e. the game host runs a WebSocket-to-TCP shim at `wss://{host}/shim/{port}` for browser clients,
which then speaks the same key-then-`/FE:` handshake a native Wrayth/Stormfront client sends over
a raw TCP connection.

**This shim is not needed for our fallback**, provided the game connection ports themselves
(11024, 11624, etc.) remain reachable and only `eaccess.play.net:7910` is blocked -- Lich's
existing raw-socket game connection code should work unchanged once fed `GAMEHOST`/`GAMEPORT`/`KEY`
obtained via this HTTPS path instead of via EAccess. The WS shim would only become relevant if a
future fallback needs to tunnel the *game* connection itself over HTTPS too (out of scope here).

---

## Open Questions / Not Yet Probed

- `DRF` (Fallen), `DRX`/`GSX` (Platinum), `GSF` (Shattered) -- account used for probing only
  holds DR/DRT/GS4(Prime)/GST entitlements, so these instance codes are untested against this
  account's subscription tier. **Given the confirmed `GS3`->`GS4` mismatch on GemStone Prime,
  do not assume these match their EAccess codes -- verify each one live.**
- Full error-code vocabulary on `login_error.asp` (bad account name, locked account, etc.) --
  only "Invalid password" confirmed. Needed to build the fatal-vs-transient error classification
  `Authenticator.with_retry` already does for EAccess (`FATAL_ERROR_CODES`).
  - Body heading (`h4`) appears to carry the specific reason; a client would need to parse it,
    or accept a coarser "auth failed" signal instead of granular error codes.
  - Consider whether error handling should instead treat *any* redirect to `return_error_page` as
    a single "AUTH_FAILED" class initially, refining later if specific messages need distinct
    retry semantics (e.g. a transient site error vs bad credentials).
- Character-generator equivalent (EAccess's `charID=0` -> character generator entry) -- not
  probed. `goplay2.asp`'s `NEWCHARSUB=TRUE` flag looks adjacent but unconfirmed.
- Cookie/session details (name, TTL, whether it's IP-pinned) -- not inspected; treated as opaque,
  handled by any client that persists cookies across the 4-request chain.
- Rate limiting / lockout behavior -- not tested (avoided repeated probing on the live site).

---

## Summary Mapping to EAccess

| EAccess (TLS:7910) | Web (HTTPS) | Notes |
|---|---|---|
| `K` + `A` (hash + authenticate) | `POST login.asp` | Password sent in the clear over HTTPS instead of XOR-obfuscated over TLS |
| `M`/`F`/`G`/`P`/`C` (enumerate) | *(not needed)* | Web flow skips straight to a specific `game`+`charID`; no equivalent enumeration observed/needed for the fallback |
| `L\t{charID}\tSTORM` | `POST goplay2.asp` + 2 redirects | Same `charID` format; `game` param mostly matches EAccess game code but not always (confirmed mismatch: GS Prime is `GS4` here vs `GS3` in EAccess) |
| `L\tOK\t...GAMEHOST=...GAMEPORT=...KEY=...` | Final redirect `?host=...&port=...&key=...` | Same three values, different transport |
| `AuthenticationError` codes (`REJECT`, `NORECORD`, ...) | Redirect target (`return_error_page`) + body heading | Coarser today; only "Invalid password" confirmed |
