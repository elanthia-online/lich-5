# Changing a saved character's frontend

Open **Account Management > Accounts** and expand the account. Edit a character's
**Frontend** cell using its dropdown. The choice saves when the cell edit is
committed; pressing Escape before committing leaves the entry unchanged.
Account headers cannot be edited.
Use the **Frontends** tab to configure an executable, extra arguments, or a custom
frontend before assigning it to a character. Missing desktop clients remain
visible and annotated rather than silently replacing a saved association.

**Manual Login** shows detected frontends as radio buttons, plus an always-present
**Custom** option. Unavailable clients stay in the configuration surfaces, not
in the Manual Login choices. Selecting Custom automatically checks **Custom
launch command** and reveals its command and working-directory fields. Custom
requires a nonblank command before Play can authenticate or save an entry.
It uses the historical Wrayth (`stormfront`) protocol identity; this does not
require or execute Wrayth. Detected clients can still use the command checkbox
unless their native adapter disallows it (for example, Saga).

Headless operation remains an explicit CLI choice (`--headless PORT` or
`--detachable-client=PORT`). There is no GUI headless mode or saved listener-port
preference. Selecting Profanity as a saved protocol identity does not silently
create a listener or launch a terminal: configure a custom command for GUI use,
or launch it through the CLI.

Changing the association preserves account credentials, favorite status, and any
per-entry custom launch command and directory. It does not log in or change other
characters. Duplicate destination entries and stale selections are rejected;
refresh the account list if another window changed the entry.
Manual Login refreshes its saved-entry cache after account changes and again
before saving a quick entry, preserving frontend settings edited in another tab.

Additional arguments preserve literal spaces and empty values. For example,
`--title "" "  keep me  "` supplies three arguments, including an empty title.
The argument editor uses shell-style quoting to express argument boundaries,
including on Windows. Windows launch templates with additional arguments are
split using Windows CRT quoting and passed as an argv list, not POSIX-escaped
text; quote executable paths containing spaces. Additional arguments remain
literal, including quotes, backslashes, `%PATH%`, and shell metacharacters.
Implicit shell operators in that Windows template path are rejected: use a
wrapper executable if shell behavior is intentional. A legacy custom command
without a separate argument list retains its existing execution semantics.
Invalid argument lists
are rejected rather than silently dropping or truncating values. A malformed
argument list loaded from `frontends.yml` leaves the last usable catalog active
and logs a warning; the file is not rewritten.

## Frontend definitions and local settings

Built-in definitions live in `lib/common/frontend/*.rb`; the registry exposes
their identities, capabilities, discovery rules, and launch adapters without
GTK. To add a supported capability, update the registry vocabulary and relevant
definitions. The Frontends tab generates its capability checkboxes from that
vocabulary; adding a checkbox does not itself implement protocol support.

Machine-local overrides live in `DATA_DIR/frontends.yml`, separate from account
credentials in `entry.yaml`. A version-1 example (paths are examples, not defaults):

```yaml
version: 1
builtins:
  stormfront:
    executable: 'C:\Program Files\Wrayth\Wrayth.exe'
    arguments: ['--profile', 'Test profile']
custom:
  local-client:
    label: Local Client
    command: 'client --host=%host% --port=%port% --key=%key%'
    directory: '/path/to/client'
    arguments: ['--title', '']
    capabilities: [xml, streams]
```

`executable`, `directory`, and `arguments` are optional. Custom definitions
require a unique stable ID, label, and command; IDs must not replace a built-in
name or alias. Built-ins retain their protocol capabilities. Command placeholders
are `%host%`, `%port%`, and `%key%`; never put account passwords in commands.
These settings are trusted executable configuration, not a sandbox. Import only
commands you trust; explicitly launching a shell or batch wrapper carries that
shell's interpretation rules. Saves are atomic and owner-only where supported.
Newer schema versions are not overwritten. Deleting a custom definition does
not rewrite saved character associations; reassign those entries explicitly.

Windows parsing follows [Microsoft's CRT rules](https://learn.microsoft.com/en-us/cpp/c-language/parsing-c-command-line-arguments).
The argument-list handoff uses [Ruby's process API](https://docs.ruby-lang.org/en/master/Process.html).

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

This standalone test uses a virtual display and temporary synthetic accounts.
It checks selection/commit/cancellation, account expansion, credential preservation,
detected-client radio buttons, and Custom's fallback and field visibility. It neither
authenticates to the game nor accesses saved player accounts. Ordinary RSpec
coverage also exercises a frontend edit followed by another character's Manual
Login save through the production notification and persistence paths.
