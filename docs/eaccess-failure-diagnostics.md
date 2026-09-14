# EAccess Failure Diagnostics

## Overview

`EAccess.auth` is a single linear exchange -- TCP connect, TLS handshake, then a
K/A/M/F/G/P/C/L command sequence over one blocking socket (see
[eaccess-protocol-analysis.md](eaccess-protocol-analysis.md) for the protocol itself). Historically,
a failure anywhere in that chain surfaced as one of a handful of generic exception types
(`Errno::*`, `OpenSSL::SSL::SSLError`, `AuthenticationError`, a bare `StandardError`, or just "timed
out after 30s" from the outer watchdog) with no indication of *which* stage failed. Two very
different root causes -- "the load balancer in front of 7910 is dropping packets" and "the account's
password is wrong" -- could both eventually surface as "authentication failed," several layers away
from the log line a responder would actually need.

This document defines the failure-stage taxonomy `EAccess` now logs on, so a log line's stage name
maps to a specific, actionable probable cause instead of requiring someone to re-read the protocol
exchange from scratch during an incident.

## Design

Each stage is wrapped so that on failure, `EAccess` logs (at `warn`, `Lich.log`):

```
warn: EAccess stage '<stage>' failed after <duration>s (<ExceptionClass>: <message>) -- likely cause: <probable cause>
```

**Never logged:** the account password (obfuscated or not), the session `KEY`, or the account's
character list (the `C` response). `M`/`F`/`L`'s raw response text IS included in their exception
messages (and therefore in the stage log line) -- these are short, low-sensitivity protocol status
tokens (`NEW_TO_GAME`, `PROBLEM\t1`, etc.), not secrets, and the exact token is genuinely useful for
diagnosis. The `A` response is different: it can be a real Simutronics rejection token or an
unrecognized/garbled response, and only the *derived classification* (recognized-rejection vs.
divergence, see `.classify_a_response_failure`) is logged, not the raw text -- an unrecognized
response is exactly the case most likely to contain something unexpected (an HTML intercept page
from a WAF, a truncated fragment, etc.) that shouldn't be assumed safe to log verbatim.

## Stage Taxonomy

| # | Stage (exact log name) | Trigger (code) | Confirmed cause(s) | Probable cause hint |
|---|---|---|---|---|
| 1 | `tcp_connect:main` (the auth connection) or `tcp_connect:pem_bootstrap` (the separate connection `download_pem` makes when no cert is pinned yet) | `Socket.tcp(..., connect_timeout:)` raises `SocketError` (DNS resolution failure from `getaddrinfo`, before any TCP attempt), `Errno::ETIMEDOUT` (SYN sent, no response), or `Errno::ECONNREFUSED` (connection actively refused) | Hostname doesn't resolve, packets are being dropped, or the host is reachable but nothing is listening on 7910 | `SocketError`: upstream DNS or local resolver, not Simutronics-side. `ETIMEDOUT`: firewall/routing/load-balancer silently dropping packets (probable). `ECONNREFUSED`: service down, or wrong port, on an otherwise-reachable host -- distinct from `ETIMEDOUT`, different remediation |
| 2 | `tls_handshake:main` or `tls_handshake:pem_bootstrap` | `ssl_socket.connect` (or `ssl.connect` for the bootstrap path) raises `OpenSSL::SSL::SSLError` | TLS negotiation failure (protocol/cipher mismatch, handshake timeout) | TLS termination misconfiguration (not probable on its own -- rare relative to #1) |
| 3 | `cert_pin_mismatch` | `verify_pem`: peer cert != locally pinned `simu.pem` | Certificate changed since last pin | **Ambiguous by design today** -- a legitimate Simutronics cert rotation and a MITM presenting a different cert look identical; currently auto-re-pins with only a log line, no alert. Flagged loudly as its own stage rather than folded into a generic warning. |
| 4 | `k_response` | No response to `K`, or response received but empty/implausibly short | Connection closed immediately post-handshake, or a malformed hash key | A relay or the EAccess target itself behind 7910 (possible) -- previously indistinguishable from a stage-5 (`a_response`) failure, since a malformed K silently produced garbage password bytes that only failed two steps later |
| 5 | `a_response` | `K` succeeded; `A` response doesn't match `/KEY\t.../ ` | Two distinct sub-cases, now classified separately (see below) | (a) recognized rejection token (`REJECT`/`NORECORD`/`INVALID`/`PASSWORD`) -- normal, expected, not a backend issue; (b) unrecognized/empty/malformed response -- application/backend divergence (possible) |
| 6 | `m_response` | `A` succeeded; `M` response doesn't match `/^M\t/` | Session accepted, but the very next command fails | Session-affinity issue on a load-balanced backend (possible) -- credentials are known-good at this point, which rules out #5 entirely |
| 7 | `entitlement_response` | Any of `F`/`G`/`P`/`C` fails or times out (non-legacy path) | Valid session, valid `M`, but the per-game entitlement pipeline breaks for the requested `game_code` | A backend/DB dependency specific to entitlements, not the auth path itself |
| 8 | `l_response` | `L` response isn't `/^L\t/` at all (distinct from a well-formed `L\tPROBLEM\t...`) | Protocol/backend divergence at the final step | Same "unrecognized response" class as #5b, at the last step instead of the first |
| 9 | *(cross-cutting, not its own `stage` call)* | The outer 30s `auth_with_timeout` watchdog fires | A hang with no exception at all | Answers "which stage" using the last-entered-stage marker rather than nothing, the actual gap this taxonomy closes -- see `auth_with_timeout`'s log line |

Stage 1 refines the reviewer's original "TCP timeout/refusal" bucket (three causes -- DNS,
timeout, refusal -- rather than one); 5's (a)/(b) split refines "K succeeds, but authentication
command fails." Stages 3, 4, 6, 7, 8, and 9 are new relative to the original 4-stage list.

**Not implemented (out of scope for this pass):** distinguishing a truncated/partial `sysread` from
a genuine short response -- `EAccess.read` remains a single `sysread(PACKET_SIZE)` call. If a
response is ever found to legitimately span multiple TCP segments in practice, this would need a
read-until-delimiter loop, not just better logging.

## Where this shows up

- `EAccess.socket` / `EAccess.download_pem` -- stages 1-3 (connect through cert verification)
- `EAccess.auth` -- stages 4-8 (the K/A/M/F/G/P/C/L exchange)
- `EAccess.auth_with_timeout` -- stage 9 (reports the last stage that was entered when the
  watchdog fires, if the thread was killed mid-stage)
