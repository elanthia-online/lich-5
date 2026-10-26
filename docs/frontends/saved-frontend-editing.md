# Changing a saved character's frontend

In the WebUI launcher, open **Account Management > Accounts**, select a
character row, and choose **Edit Character**. Change the **Frontend** dropdown
and choose **Save Character**. **Back to Accounts** leaves the saved entry
unchanged. The Accounts table displays saved values; it is not an inline editor.
Use the **Frontends** tab to configure an executable, extra arguments, or a custom
frontend before assigning it to a character. Missing desktop clients remain
visible and annotated rather than silently replacing a saved association.

**Manual Entry** uses a **Front end** dropdown backed by the same catalog,
including configured, detected, and unavailable choices. The **Custom launch
command** checkbox reveals command and working-directory fields for the selected
frontend; it is not a separate radio choice. Enabling it requires a nonblank
command. Native-only adapters such as Saga disable that checkbox. Manual Entry
checks frontend availability before Play, including when that checkbox is used;
an unavailable choice produces a notice rather than silently selecting another
frontend. A configured custom frontend has its own catalog availability rules.

Headless operation remains an explicit CLI choice (`--headless PORT` or
`--detachable-client=PORT`). There is no GUI headless mode or saved listener-port
preference. Selecting Profanity as a saved protocol identity does not silently
create a listener or launch a terminal: configure a custom command for GUI use,
or launch it through the CLI.

Changing the association preserves account credentials, favorite status, and any
per-entry custom launch command and directory. It does not log in or change other
characters. A missing selected entry is rejected; refresh the account list if
another window removed or changed it. Adding a character checks for an existing
matching destination. Editing an existing character does not run that duplicate
check, so it can create equivalent saved entries; do not rely on automatic
deduplication in the editor.
The launcher refreshes its catalog after account changes and preserves existing
entry data when saving Manual Entry choices.

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
may simply not be installed on this computer. The launcher notice points to
the Frontends configuration controls.

## Regression checks

The former GTK inline editor, message boxes and native smoke test have been
removed. Current behavior is exercised through the WebUI launcher and catalog:

```sh
rspec spec/lib/common/webui_launcher_redux_spec.rb spec/lib/common/webui_launcher_workflows_spec.rb spec/lib/common/webui_launcher spec/lib/common/frontend_choices_spec.rb
```

These tests isolate authentication, accounts and process launches. They cover
character editing, supported-but-unavailable choices, cancellation, catalog
updates and launch gating without authenticating to a live game or reading
player accounts. Browser and OS-window acceptance remain separate; see the
[WebUI validation guidance](../webui-integration.md#validation).
