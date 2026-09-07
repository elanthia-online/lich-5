# Changing a saved character's frontend

Open **Account Management > Accounts** and expand the account. Edit a character's
**Frontend** cell using its dropdown. The choice saves when the cell edit is
committed; pressing Escape before committing leaves the entry unchanged.
Account headers cannot be edited.
Use the **Frontends** tab to configure an executable, extra arguments, or a custom
frontend before assigning it to a character. Missing desktop clients remain
visible and annotated rather than silently replacing a saved association.

**Launch mode** is separate from frontend identity:

- **Launch client** preserves normal installed/custom desktop frontend behavior.
- **Headless / external client** starts Lich without a desktop executable, using
  the existing detachable-client listener on `127.0.0.1`. Start or attach your
  external client separately. The **Local port** cell is editable in this mode;
  its default is 8000. Use distinct ports for simultaneous sessions, such as
  8000 and 8001, and configure the external client to use the same port.

An invalid saved port displays **Needs configuration** and remains editable so
you can correct it. Validation still rejects ports outside 1-65535.

Profanity is selectable as an external XML client. Choosing it sets external
mode; this does not launch a terminal application. Choosing a non-XML frontend
such as Wizard selects client mode. XML-capable frontends may use either mode.
Existing native entries retain client mode; existing Profanity entries use
external mode without needing their saved frontend rewritten. An existing
explicit custom launch command retains client-launch behavior.

The GUI rejects an occupied/unusable port before authenticating. The actual
runtime bind remains authoritative: another process can still acquire a port
between that check and startup. No existing session is killed or replaced.
These saved mode/port preferences apply to GUI launches; existing CLI launch
flags remain explicit and unchanged. An unsaved manual external login continues
in the current process; a persistent launch passes the chosen port to its child.

Changing the association preserves account credentials, favorite status, and any
per-entry custom launch command and directory. It does not log in or change other
characters. Duplicate destination entries and stale selections are rejected;
refresh the account list if another window changed the entry.
Manual Login refreshes its saved-entry cache after account changes and again
before saving a quick entry, preserving frontend settings edited in another tab.

Additional arguments preserve literal spaces and empty values. For example,
`--title "" "  keep me  "` supplies three arguments, including an empty title.
The editor uses shell-style quoting to express argument boundaries; this is not
a guarantee of cross-platform shell execution semantics. Invalid argument lists
are rejected rather than silently dropping or truncating values. A malformed
argument list loaded from `frontends.yml` leaves the last usable catalog active
and logs a warning; the file is not rewritten.

An unavailable Wrayth entry is not evidence of bad credentials. Its saved frontend
may simply not be installed on this computer. The launcher error now points to
the configuration controls, and OK dismisses the dialog.

The GTK message-box repair uses the return value of `Gtk::Dialog#run`. Current
Ruby-GNOME GTK3 does not yield to a supplied block, so putting `destroy` inside
that block left the dialog visible even after OK. Response and cleanup regression
tests cover OK, Cancel, Yes, No, and an exception from `run`.

## Native GTK regression check

With the project's Ruby/GTK dependencies installed, run:

```sh
xvfb-run -a ruby spec/native/frontend_inline_smoke.rb
```

This standalone test uses a virtual display, temporary synthetic accounts, and
a temporary loopback listener. It checks selection/commit/cancellation, invalid
port recovery, account expansion, and credential preservation. It neither
authenticates to the game nor accesses saved player accounts. Ordinary RSpec
coverage also exercises a frontend edit followed by another character's Manual
Login save through the production notification and persistence paths.
