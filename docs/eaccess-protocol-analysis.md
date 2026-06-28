# EAccess Protocol Analysis

## Overview

This document captures findings from systematic probing of the Simutronics EAccess authentication protocol at `eaccess.play.net:7910`. The protocol uses SSL/TLS over TCP with tab-delimited text commands. Each command is a single uppercase letter optionally followed by tab-separated arguments, terminated by a newline.

The server responds with `?` for unrecognized commands or malformed argument counts.

---

## Connection

- Host: `eaccess.play.net`
- Port: `7910`
- Transport: TLS over TCP
- Certificate: Self-signed, stored locally as `simu.pem` in the data directory
- Packet size: Up to 8192 bytes per read

---

## Protocol Command Reference

### Known Commands (used by Lich)

#### K -- Hash Key Exchange

Request: `K`
Response: 32-byte random hash key string

Used to XOR-encrypt the password before transmission. The encryption algorithm:

```
for each byte i in password:
  encrypted[i] = ((password[i] - 32) ^ hashkey[i]) + 32
```

This is obfuscation, not real encryption -- the key is transmitted in the clear on the same connection.

---

#### A -- Authenticate

Request: `A\t{ACCOUNT}\t{HASHED_PASSWORD}`
Response (success): `A\t{ACCOUNT}\tKEY\t{SESSION_KEY}\t{ACCOUNT_HOLDER_NAME}`
Response (failure): Error code (e.g., `REJECT`, `NORECORD`, `INVALID`, `PASSWORD`)

The session key is a 32-character hex string reused later in the `L` command response. The account holder's real name is returned in the success response.

---

#### M -- List Available Games

Request: `M`
Response: `M\t{CODE1}\t{NAME1}\t{CODE2}\t{NAME2}\t...`

Returns all game instances visible to the authenticated account. Observed game codes:

| Code | Name | Notes |
|------|------|-------|
| DR | DragonRealms | Production |
| DRD | DragonRealms Development | Staff-only |
| DRF | DragonRealms The Fallen | Separate subscription |
| DRT | DragonRealms Prime Test | Open to subscribers |
| DRX | DragonRealms Platinum | Separate subscription |
| GS3 | GemStone IV | Production |
| GS4D | GemStone IV Development | Staff-only |
| GSF | GemStone IV Shattered | Separate subscription |
| GST | GemStone IV Prime Test | Open (FREE tier) |
| GSX | GemStone IV Platinum | Separate subscription |

All codes are returned regardless of whether the account has access. The `F` command determines actual access.

---

#### F -- Check Subscription / Access Tier

Request: `F\t{GAME_CODE}`
Response: `F\t{TIER}`

Possible tier values:

| Tier | Meaning |
|------|---------|
| `PREMIUM` | Full paid subscription |
| `NORMAL` | Standard subscription |
| `FREE` | Free-to-play access |
| `TRIAL` | Trial period |
| `INTERNAL` | Staff/GM access (not observed, but handled in code) |
| `NEW_TO_GAME` | No subscription for this game instance |

`NEW_TO_GAME` is returned for game instances the account has never subscribed to. This is distinct from an error -- it indicates the game is recognized but the account lacks entitlement.

**`NEW_TO_GAME` is the normal response for every unsubscribed instance, not a failure.** Probing a test account (subscribed only to DR/DRT) returned `NEW_TO_GAME` uniformly for `GS3`, `DRX`, `GSX`, `DRF`, and `GSF`. This matters for the character generator: a guard that treats only `NORMAL|PREMIUM|TRIAL|INTERNAL|FREE` as valid will abort on `F` before reaching `L`, blocking generator entry on every instance the account does not already hold -- which is precisely the case the generator exists to serve. `NEW_TO_GAME` must be tolerated on the generator path. Whether creation is actually permitted is decided later, by the `G` tier and the `L` response (see below), not by `F`.

---

#### N -- Check Game Frontend Availability

Request: `N\t{GAME_CODE}`
Response: Contains `STORM` if the game supports the Storm/Wrayth frontend

Used in the legacy login path to filter which games support the current frontend protocol.

---

#### G -- Select Game (Detailed Info)

Request: `G\t{GAME_CODE}`
Response: `G\t{GAME_NAME}\t{TIER}\t{FLAG}\t\t{KEY1=VAL1}\t{KEY2=VAL2}\t...`

The second field is the **effective access tier for this account on this instance**, and it is the real entitlement signal -- more informative than `F`, which collapses every unsubscribed state to `NEW_TO_GAME`. Observed values while `F` returned `NEW_TO_GAME`:

| Instance | `G` tier | Generator (`L\t0`) outcome |
|----------|----------|----------------------------|
| GS3 | `TRIAL` (31) | accepted -- server grants a temporary trial entitlement |
| DRX | `TRIAL` (31) | accepted |
| GSX | `TRIAL` (31) | accepted |
| DRF | `UNKNOWN` | refused (`L\tPROBLEM\t1`) -- no trial offered, paid subscription required |
| GSF | `UNKNOWN` | refused (`L\tPROBLEM\t1`) -- paid subscription required |
| DR (subscribed) | `PREMIUM` | accepted |

A `TRIAL` or paid tier (`NORMAL`/`PREMIUM`) permits generator entry; `UNKNOWN` means the account has no path to create on that instance without first purchasing a subscription. Nothing here is inherently non-creatable -- a Fallen/Shattered account with a paid subscription would see `F` return `NORMAL`/`PREMIUM` and behave like DR. The outcome is per-account entitlement state, decided by the server, so the client must not crash on any of it.

Returns game metadata including URL templates for various services. The URLs contain `{KEY}` placeholder for session key substitution. Observed keys:

- `ROOT` -- Base path (e.g., `sgc/dr`)
- `BILLINGINFO` -- Account info URL with session key injection point
- `LTSIGNUP` -- Long-term signup URL
- `SIGNUP`, `SIGNUPA` -- Signup redirect URLs
- `FEEDBACK`, `MAILFAIL`, `MAILSUCC` -- Feedback system paths
- Various content paths: `MAIN`, `MKTG`, `GAMEINFO`, `PLAYINFO`, `MSGBRD`, `CHAT`, `FILES`

---

#### P -- Platform / Pricing Info

Request: `P\t{GAME_CODE}`
Response: `P\t{CODE}\t{PRICE1}\t{CODE.EC}\t{PRICE2}\t{CODE.P}\t{PRICE3}`

Returns pricing tiers for the game instance. Observed values:

| Game | Base Price | EC Price | Platinum Price |
|------|-----------|----------|----------------|
| DR | 1495 | 250 | 2500 |
| DRT | 1495 | 250 | 2500 |
| GST | 1000 | -1 | 2500 |

The `.EC` suffix likely means "Extra Characters" (additional character slot pricing). A value of `-1` indicates the feature is unavailable. Prices are presumably in cents.

---

#### C -- Character List

Request: `C`
Response: `C\t{N1}\t{N2}\t{N3}\t{N4}\t{CODE1}\t{NAME1}\t{CODE2}\t{NAME2}\t...`

Returns the account's characters for the currently selected game. The four header numbers:

| Position | Observed Values | Likely Meaning |
|----------|----------------|----------------|
| N1 | 0, 2 | Active character count |
| N2 | 16, 100 | Maximum character slots |
| N3 | 0, 1 | Unknown (possibly deleted count or status flag) |
| N4 | 1 | Unknown (possibly account status flag) |

Premium DR accounts get 16 slots. GST (free) accounts get 100 slots.

Character codes follow the format `W_{ACCOUNT}_{SLOT}` where SLOT is a zero-padded 3-digit number (e.g., `W002`, `W003`). Slot numbers are not necessarily sequential -- gaps indicate previously deleted characters.

When an account has no characters on an instance, only the header is returned (e.g., `C\t0\t100\t0\t1`).

**Characters are shared across test and production instances.** The same character codes and names appear on both DR and DRT for the same account.

---

#### L -- Launch / Select Character

Request: `L\t{CHAR_CODE}\tSTORM`
Response (success): `L\tOK\t{KEY1=VAL1}\t{KEY2=VAL2}\t...`

Selects a character and returns game server connection details. Observed response keys:

| Key | Example Value | Purpose |
|-----|---------------|---------|
| UPPORT | 5535 | Support port (note: may be `SUPPORT` with leading S consumed) |
| GAME | STORM | Frontend protocol |
| GAMECODE | DR | Game instance |
| FULLGAMENAME | Wrayth | Frontend application name |
| GAMEFILE | WRAYTH.EXE | Frontend executable |
| GAMEHOST | dr.simutronics.net | Game server hostname |
| GAMEPORT | 11024 | Game server port |
| KEY | (session key) | Authentication key for game server |

**Character code `0` enters the character generator.** Sending `L\t0\tSTORM` bypasses character selection entirely and returns valid connection details that lead to the character creation flow on the game server. This works even when the account has no characters on the selected instance, and even when `F` returned `NEW_TO_GAME`, provided the account has a creation entitlement (a paid tier or a `TRIAL` grant; see the `G` command).

**Generator entry can be refused: `L\tPROBLEM\t1`.** When the account has no entitlement to create on the instance (the `G` tier is `UNKNOWN`, e.g. unsubscribed Fallen/Shattered), `L\t0\tSTORM` returns `L\tPROBLEM\t1` instead of `L\tOK\t...`. Note this still begins with `L\t`, so a guard of the form `response =~ /^L\t/` accepts it and then parses a garbage launch payload (`{"l"=>nil, "problem"=>nil, "1"=>nil}`). The success guard must require `^L\tOK\t`, and `L\tPROBLEM` should be surfaced as a clear "account not entitled to create a character on this instance" error rather than crashing or launching with broken data.

---

### Discovered Commands (not used by Lich)

#### B -- Billing Status

Request: `B`
Response: `B\t{TIER}`

Returns the account's current billing/subscription tier without requiring a game code argument. Appears to return the account-level subscription rather than a game-specific one. With arguments, returns `?`.

---

#### D -- Delete Character (or Character Info)

Request: `D\t{CHAR_CODE}`
Response (not found): `D\t{CHAR_CODE}\tERROR: Character not found`

Takes a single argument: the character code (e.g., `W_ACCT_W002`). Two-argument forms return `?`. The command validates the character code against the account's character list and returns a structured error when the code doesn't match.

The response format for a valid character code was not tested to avoid data loss. The error response structure suggests the success response would be `D\t{CHAR_CODE}\t{STATUS}`.

---

#### E -- Email Address

Request: `E`
Response: `S\t{EMAIL_ADDRESS}`

Returns the email address associated with the authenticated account. Note the response prefix is `S` (not `E`), possibly indicating a "Settings" response category.

This is a read-only information disclosure endpoint. It accepts no arguments -- `E\t{value}` returns `?`, so it cannot be used to modify the email.

---

#### S -- Subscription Management

Request: `S`
Response: `S\tPROBLEM\tProblem processing subscription. Please try again later or contact customer service.`

Appears to be a subscription purchase or modification endpoint. The bare command reaches a real server-side handler that returns a structured error message, but every argument variation returns `?`:

Tested and rejected argument patterns:
- `S\t{GAME_CODE}` (e.g., `S\tDR`, `S\tDRD`)
- `S\t{TIER}` (e.g., `S\tINTERNAL`, `S\tPREMIUM`)
- `S\t{GAME_CODE}\t{TIER}`
- `S\t{GAME_CODE}\t{NUMBER}`
- `S\t{GAME_CODE}\t{TIER}\t{NUMBER}`
- `S\tSUBSCRIBE\t{GAME_CODE}`

The handler likely requires a payment token or transaction reference from the web billing portal (`account.play.net`). The protocol alone cannot modify subscriptions. After all probe attempts, `F` responses remained unchanged -- no subscription state was altered.

---

#### V -- Protocol Version

Request: `V`
Response: `V\t1`

Returns the EAccess protocol version number. Currently version 1. Accepts no arguments.

---

#### Z -- Logout / Session Close

Request: `Z`
Response: `OK`

Cleanly terminates the authenticated session. The connection remains open but the session state is cleared.

---

### Unused Command Letters

The following letters return `?` in all tested forms (bare and with arguments) and appear to be unimplemented:

`H`, `I` (returns `I\tPROBLEM` with game code arg), `J`, `O`, `Q`, `R`, `T`, `U`, `W`, `X`, `Y`

The `I` command with a game code argument returns `I\tPROBLEM`, suggesting a partially implemented or disabled endpoint -- possibly an "Info" or "Inquiry" command.

---

## Access Control Observations

### Development Server Access

The development instances (DRD, GS4D) are visible in the game list but return `NEW_TO_GAME` for standard accounts. Access is gated by subscription tier, not by game visibility. The `INTERNAL` tier (handled in code but never observed) is presumably the staff subscription that grants access.

There is no protocol-level mechanism to elevate subscription tier. The `S` command's server-side handler appears to require external input (likely from the web billing system) and cannot be used standalone.

### Test Server Access

Test instances (DRT, GST) are freely accessible:
- DRT inherits the account's DR subscription tier (PREMIUM)
- GST is available as FREE tier to all accounts
- GST provides 100 character slots (vs. 16 for premium DR)
- Characters and character codes are shared between production and test instances

### Character Slot Allocation

| Tier | Observed Max Slots |
|------|--------------------|
| PREMIUM (DR) | 16 |
| FREE (GST) | 100 |

The generous GST slot allocation (100) combined with the character code `0` entry point makes it a useful target for character generator testing.

---

## Security Observations

1. **Password obfuscation is weak.** The XOR scheme with a cleartext key provides no meaningful security beyond the TLS transport layer.

2. **Email disclosure.** The `E` command returns the account holder's email with no additional authentication beyond the initial login.

3. **Account holder name disclosure.** The `A` command success response includes the account holder's full name.

4. **Subscription tier disclosure.** The `B`, `F`, and `G` commands expose subscription information.

5. **No rate limiting observed.** The protocol accepted rapid sequential probing without throttling or lockout.

6. **Self-signed certificate.** The server uses a self-signed certificate with no chain of trust. The client must manually verify the certificate against a stored copy.

---

## Protocol State Machine

The protocol follows a strict state progression:

```
K (hash key)
  -> A (authenticate)
    -> M (list games)
      -> F (check subscription for game)
        -> G (select game)
          -> P (platform info)
            -> C (character list)
              -> L (launch character)
```

Auxiliary commands (B, D, E, S, V, Z) can be issued at various points after authentication. The `D` command requires a game to be selected (via G) so the server knows which character list to validate against.

Commands issued out of order may produce unexpected results or error responses. The `F` command resets the game selection context, requiring G/P/C to be re-issued for a different game.
