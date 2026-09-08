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
(`lib/common/authentication/web_login.rb`) and exercised live end-to-end: DR, DR Test, GemStone
Prime (`GS3`->`GS4` mapping), GemStone Test, GemStone Shattered, and a bad-password failure all
confirmed working against the real play.net servers, matching the browser-captured hosts/ports
exactly. `DRX` (Platinum) and `DRF` (Fallen) are wired in end-to-end too, but as *unverified*
entries pending an account with real entitlement to confirm the actual host/port -- see
`CONFIRMED_INSTANCES`. Several things were only discovered by building and running a non-browser
HTTP client, or by testing more than one account, not by watching a single browser session:

1. **A browser-like `User-Agent` header is required on every request, including the very first
   GET.** play.net's front end (CloudFront/WAF) returns a bare `500` for Ruby's default
   `Net::HTTP` User-Agent (`Ruby/x.y.z`) -- not documented anywhere, not visible from the browser
   capture since a real browser always sends one. Every request must set this header.
2. **The login POST requires a pre-existing ASP session cookie from a prior `GET` of the
   sign-in page** (e.g. `GET /dr/signin_needed.asp`) -- posting `login.asp` cold (no session
   cookie) also returns a bare `500`. A real browser always visits the sign-in page before
   submitting the form, so this dependency is invisible in a browser capture alone. The module
   issues this GET itself and carries its cookie into the login POST.
3. **An account that has never set a security question is redirected to
   `/playdotnet/account/security_qa.asp` instead of `return_okay_page` on an otherwise-successful
   login.** Confirmed live with a second test account. The session is already fully authenticated
   at that point (the account name renders in the page banner; the real session cookie is already
   set) -- manually navigating straight to the game's play page instead of following that redirect
   works fine, confirming it's not a login failure. `WebLogin.login` treats this path as a second
   acceptable redirect target alongside `okay_page`, rather than raising.
4. **A character can exist on one instance of a family without appearing on that family's generic
   `home.asp` at all.** Confirmed live: a GemStone Shattered-only character does not show up on
   the GemStone Prime page. `DR`/`DRT`/`GS3`/`GST` all happened to share characters visible via
   the same generic per-family page in initial testing, which masked this -- resolving a charID
   must scrape the specific instance page a user would actually pick that game code from (e.g.
   `/gs4/play/playf.asp` for Shattered), not assume the family's `home.asp` has the full
   account-wide picture. See `CONFIRMED_INSTANCES`' `character_list_path` per entry.
5. **An account with no active subscription on the requested instance triggers a SECOND
   redirect, from `okay_page` itself, that a naive client never sees.** Confirmed live with a
   third test account: `login.asp`'s own redirect still lands on `okay_page` (e.g.
   `/dr/play/home.asp`) successfully -- login itself does not fail. But `GET`ting that page (the
   same request `.resolve_char_code` makes to scrape the character list) returns another `302`,
   to `/{family}/play/subscription_needed.asp`, which a plain (non-redirect-following) HTTP
   client -- ours included, deliberately, see class doc -- does not follow. Without an explicit
   check, this silently falls through to an empty body scrape and a misleading
   `CHARACTER_NOT_FOUND` instead of the real cause. `WebLogin` now inspects the character-list
   response's status: a redirect to `subscription_needed.asp` raises a distinct `NO_SUBSCRIPTION`
   (classified fatal in `Authenticator::FATAL_ERROR_CODES` -- retrying won't help), and any other
   non-200 response raises `UNEXPECTED_CHARACTER_LIST_RESPONSE`.
6. **The "no subscription" redirect target isn't one fixed path -- it's instance-specific.**
   Confirmed live with the same unentitled account against `DRX`/`DRF`: DR's is plain
   `subscription_needed.asp`, but DRX's (Platinum) is `subscription_to_plat_needed.asp` and DRF's
   (Fallen) is `subscription_to_fall_needed.asp`. `WebLogin` matches this by pattern
   (`subscription(?:_to_\w+)?_needed\.asp`) rather than an exact string, so an instance-specific
   variant not seen yet is still recognized as `NO_SUBSCRIPTION` instead of falling through to the
   generic `UNEXPECTED_CHARACTER_LIST_RESPONSE`.

All six were invisible in a single browser capture and only surfaced by building a standalone
client and/or testing more than one account -- worth remembering if this flow needs
re-verifying after a play.net change: reproduce with a non-browser client against more than one
account (ideally one with an expired/inactive subscription too), not just by re-watching
DevTools on one login.

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
  - **Alternate success redirect, confirmed live:** an account that has never set a security
    question is redirected to `/playdotnet/account/security_qa.asp` instead. The session is
    already fully authenticated at this point -- treat this the same as a redirect to
    `return_okay_page`, not a failure. See "Implementation Status" above.
- On failure: `302` redirect to `return_error_page` instead. **The redirect target itself is the
  pass/fail signal** -- compare the `Location` header's path against the two page params you
  sent, don't parse body text for control flow.
  - Confirmed failure cases, both landing on the same `login_error.asp` redirect target with only
    the body heading differing:
    - Wrong password on a real account -> `/dr/login_error.asp?error=&returnto=/dr/`, heading
      `"Invalid password."`.
    - Nonexistent account name (confirmed with a random fictitious name, e.g. `SDLG3kDSKk38`) ->
      `/dr/login_error.asp?error=&returnto=/dr/play/home.asp`, heading `"Invalid account."`.
    `WebLogin.login` classifies both identically as `LOGIN_FAILED` (matching the redirect path
    only, not the heading -- see "AUTH_FAILED" note below) -- this matters in practice for a
    stale/mistyped saved account name, which resolves the same way a bad password does: a single
    fast, fatal failure with no wasted retries or fallback loop, not an indefinite hang or a
    generic/unclear error. Locked account and other failure modes are still not yet probed --
    likely land on the same page with yet another heading, and would already be handled the same
    way (any redirect to `login_error.asp`, regardless of heading, is `LOGIN_FAILED`).

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

So resolving a `char_name` to the `charID` needed for step 2 means: `GET` the specific instance's
character-selection page -- **not necessarily the family's generic `home.asp`** -- with the
session cookie from step 1, then regex-scrape `id="(W_[^"]+)"` paired with the following
`<label for="\1"><span[^>]*>([^<]+)</span>` for the display name. Confirmed the session cookie
from a single `login.asp` call is valid across both game families (DR and GS4) in the same
browser session -- one login, both games' pages render correctly without re-posting credentials.

**The right page to scrape is instance-specific, confirmed live:**

| Instance | Page |
|---|---|
| `DR` (Prime) | `/dr/play/home.asp` |
| `DRT` (Test) | `/dr/play/playdrt.asp` |
| `GS3` (Prime) | `/gs4/play/home.asp` |
| `GST` (Test) | `/gs4/play/play_test.asp` |
| `GSF` (Shattered) | `/gs4/play/playf.asp` |

For `DR`/`DRT`/`GS3`/`GST`, the same character happened to be visible via any of these pages in
initial testing (the account's DR/DRT characters and GS3/GST characters were each shared across
that pair) -- but that is **not a safe general assumption**. Confirmed live with a Shattered-only
character: it appears on `/gs4/play/playf.asp` but does **not** appear on `/gs4/play/home.asp`
(GemStone Prime) at all -- that page shows "Create a new character" as the only option, with no
indication a Shattered character exists. Always scrape the same page a user would actually pick
that specific game code from.

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
  - `game=GSF` (GemStone IV Shattered) -> host `storm.gs4.game.play.net`, port `10324` --
    matches EAccess `GSF` (like `DR`/`DRT`/`GST`, unlike the `GS3`->`GS4` Prime mismatch)

  `DRX` (Platinum) and `DRF` (Fallen) are wired in end-to-end (`game=DRX`/`game=DRF`, assumed
  identical to their EAccess codes as DR/DRT/GSF's do -- only `GS3`->`GS4` has ever diverged) but
  **not live-confirmed**: no account with these entitlements has been available to test with, so
  their `expected_host`/`expected_port` are deliberately left unpinned in `CONFIRMED_INSTANCES`
  (see that constant's comment for what "unverified" relaxes vs. still enforces). Confirmed live
  with an unentitled account that both reach the real server correctly and fail cleanly (`NO_SUBSCRIPTION`,
  via each instance's own named subscription page -- `subscription_to_plat_needed.asp` /
  `subscription_to_fall_needed.asp`, not the generic `subscription_needed.asp` -- see "Implementation
  Status"), which at least validates `character_list_path` and the request shape; the actual
  `GAMEHOST`/`GAMEPORT` a real entitled account gets back is still unconfirmed. `GSX` (GemStone
  Platinum) is not applicable at all -- the instance itself has been retired (confirmed by the
  account holder; `LoginHelpers.VALID_GAME_CODES` already excludes it independent of this module).
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

- `DRF` (Fallen), `DRX` (Platinum) -- enabled in `CONFIRMED_INSTANCES` as *unverified* entries
  (`expected_host`/`expected_port` left `nil`, see that constant's comment) so a tester with real
  entitlement can exercise them without a code change. No such account has been available yet, so
  the actual `GAMEHOST`/`GAMEPORT` -- and whether `game=DRX`/`game=DRF` truly match their EAccess
  codes, given the confirmed `GS3`->`GS4` mismatch elsewhere -- remain unconfirmed. Once a real
  result comes back, hardcode the observed host/port here and remove the `nil`s. `GSF` (Shattered)
  is fully confirmed (see above); `GSX` (GemStone Platinum) is not applicable at all -- the
  instance has been retired.
- Full error-code vocabulary on `login_error.asp` -- "Invalid password" and "Invalid account"
  (nonexistent account name) both confirmed; locked account and other failure modes not yet
  probed. Not currently a gap in practice: `WebLogin.login` already takes the coarser approach
  described below (any redirect to `return_error_page` is `LOGIN_FAILED`, regardless of heading),
  so an unprobed failure mode still fails correctly today -- just without a distinguishing code.
  - Body heading (`h4`) carries the specific reason if a more granular code is ever wanted; not
    currently parsed.
  - **Resolved: `WebLogin.login` treats any redirect to `return_error_page` as a single
    `LOGIN_FAILED` class**, matching the redirect path only, not the heading. Confirmed this
    correctly covers both known failure modes (bad password, bad account name) without needing to
    parse body text.
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
| `AuthenticationError` codes (`REJECT`, `NORECORD`, ...) | Redirect target (`return_error_page`) only, as a single `LOGIN_FAILED` | Coarser by design; confirmed to correctly cover both bad-password and bad-account-name |
