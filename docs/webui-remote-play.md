# Playing through the WebUI from another machine

The WebUI never uses X11 or GTK. Each Lich process (the launcher, then
every game session it starts) runs a small HTTP/WebSocket server on
`127.0.0.1` and opens Chrome or Edge on the same machine, pointed at a
one-shot launch URL. That URL is the only credential: whoever opens it
first gets the session cookie.

Because it is just a loopback web server, the way to reach it from
elsewhere is to forward the port, not the display.

## Flags

| Flag | Effect |
| --- | --- |
| `--webui-port=PORT` | The launcher binds this port instead of an ephemeral one, so a tunnel can be set up ahead of time. Per process; sessions started from the launcher pick their own. |
| `--webui-no-browser` | Lich opens no browser. The launcher prints its URL to the console; a game session sends each script window's URL to the game window (and the log). Sessions started from the launcher inherit this flag. |

Both are listed under `lich --help advanced`.

## SSH

On the machine running Lich:

```
lich --webui-port=4321 --webui-no-browser
```

From the machine with the browser:

```
ssh -L 4321:127.0.0.1:4321 user@lich-host
```

Then open the URL Lich printed, exactly as printed. It names
`127.0.0.1:4321`, which through the tunnel is the right address.

With `--webui-no-browser` a launch URL is good for ten minutes (a minute
when Lich opens the browser itself). After that the link answers
"expired or already used"; reopen the window from Lich for a fresh one,
or ask for it directly with `Lich::API.webui_launch_url` (with
`page:` for a script window).

A game session runs one WebUI server for the whole process, on its own
ephemeral port: every script window in that session is a page on it, so
one more `-L` covers all of them. The port is in the first script
window URL the session sends to the game window; add it to the SSH
command, or run a second tunnel then. A fixed port for sessions is not
offered because several sessions on one box would collide.

## X11 forwarding

It works, in that Chrome spawned on the remote box gets forwarded like
any other X client, but Chrome over X11 forwarding is slow. Prefer the
tunnel above.

## What is deliberately not offered

The server refuses to bind anything but loopback. A `--bind-address` for
the WebUI (say, a Tailscale address) would be a small change, but it
puts a session's only credential on the wire in plain HTTP and widens
the Host and Origin checks that keep browsers from being pointed at it.
If a real need for it turns up, that is a decision to take on purpose,
not a default.
