# WebUI author guide

WebUI supplies the graphical launcher and native script interfaces. Core uses
WebUI directly; it neither loads native GTK nor uses the script compatibility
shim. There is no user-selectable GTK backend. `--no-gui` and its legacy alias
`--no-gtk` suppress the graphical launcher, not dependency checks.

## Native pages

The [author API](../lib/api/webui.rb) exposes page registration, schema lookup,
refresh, hosting, modals and owner cleanup. The [component contract](../lib/webui/contract.rb)
is the authoritative list of supported properties, events and child relationships.
Its version describes the Ruby/browser contract, not a script release number.

A script can create an explicitly owned page:

```ruby
owner = Script.current
count = 0
page = nil
page = Lich::API.webui_page(owner: owner, id: 'counter', title: 'Counter') do |ui|
  ui.text key: 'count', content: "Count: #{count}"
  ui.button key: 'increment', label: 'Increment', on: { activate: proc {
    count += 1
    Lich::API.webui_refresh(page)
  } }
end
Lich::API.webui_refresh(page)
Lich::API.webui_start
Lich::API.webui_open(page: page)
```

Keep the owning script alive while its interface is needed, using its normal
lifecycle. Script termination removes its pages and callbacks. Core consumers
supply their own lifetime object and call `webui_terminate_owner(owner)` when
that owner ends. Registration alone does not render or open a window. Reopening
an owned page reuses its existing window. Do not create a private WebUI server
per script, or stop the shared service to close one owner's UI.

Scripts retain their own calculations, ordering, validation, persistence and
Save/Cancel behavior. Stable component keys preserve identity across refreshes.
Viewer drafts and selection are attachment-local; authoritative model changes
belong to the owner. Use submitted values and the originating event's viewer
context rather than guessing which browser owns an edit.

`webui_schema(:text)` returns the immutable component schema and
`webui_contract_version` returns its version. `webui_adapter(owner:)` supplies
an imperative adapter whose first valid page render opens its owned window.
After publication, viewer-local reads/writes require explicit viewer attribution
or the current callback context. Before publication, unattributed writes set
defaults for future attachments.

## Callbacks and cleanup

Events dispatch on the owner's queue. Keep callbacks bounded: a callback must
not wait for work queued behind itself. Use the existing owner scheduler for
supported deferred work, and asynchronous modal completion rather than blocking
the dispatcher. Native modals require an explicit no-viewer policy; cancellation
and owner shutdown are outcomes callers must handle.

Owner termination refuses new work, cancels modals and scheduled callbacks,
revokes registered files, closes owned windows and unregisters pages. A restarted
script is a new owner. Ordinary connection loss can resume for a bounded period;
an explicit close is different from temporary disconnection. A forced process
kill can leave host windows or temporary directories behind; normal shutdown
uses the owned cleanup path.

## Existing GTK scripts and conversion

The bounded shim is a temporary migration bridge for the established supported
script population and tested source versions. It is available only inside
Script/script scope. New scripts require native WebUI immediately. Updates that
introduce unsupported GTK or Builder interfaces require conversion rather than
new shim support. Defects in already-supported behavior can still be corrected;
a converted native script is maintained as native WebUI and does not drive shim
expansion. Scripts that cannot be supported require conversion.

Within script ownership, `require 'gtk2'` and `require 'gtk3'` resolve to the
already-loaded compatibility layer. They do not load native GTK gems or install
a global `Gtk`. Recognizable GTK dependency subloads are refused, including
explicit Kernel loader calls. This dependency boundary is not a sandbox against
arbitrary Ruby or direct native calls. Core must never consume shim controls.

`Gtk.main` and `Gtk.main_quit` do not control a native loop or stop the shared
WebUI dispatcher. `Gtk.queue` uses the owner's queue; nested submissions join its
tail. Detached threads do not acquire script ownership merely by invoking GTK
methods. See [compatibility lifecycle](engine/gtk-hardening.md) for cleanup and
queued-error behavior.

Unsupported operations raise attributed errors instead of silently fabricating
controls. Presentation omissions and OS limitations must be distinguished from
functional support. Opening a window is not proof that a complete script works;
beta usage validates actual operations and persistence. After usage and issue
tracking, maintainers determine shim retirement. There is no fixed retirement
date or ongoing GTK development commitment. The mirrored DR Repository is
unsupported; use EO's Repository implementation.

## Bounded Builder

The [Builder mapping](../lib/common/script_scope/gtk/builder.rb) translates a
supported subset of GTK 3 XML into the same script-owned objects as direct Ruby
calls. It supports `add_from_string`, local `add_from_file`, `get_object`/`[]`,
`objects`, `builder_name`, subclassing and `connect_signals`. XML does not evaluate
Ruby. Supported families include bounded containers, labels, entries, buttons,
scalar stores, tree/combo controls, text views and the explicitly mapped properties.
Consult the mapping and contract for individual operations; GTK documentation
alone does not establish shim support.

Loads are transactional: declarations, properties, references and component
relationships are checked before publishing visible windows. Failure destroys
candidate widgets and leaves earlier successfully loaded objects intact. IDs
must be unique, and references must resolve within the current document.
Cross-document references into an earlier graph are unsupported.

Undeclared object lookups raise `Gtk::BuilderError`; optional lookup callers must
inspect `objects` explicitly. Unhandled Builder errors escaping `Gtk.queue` close
that owner's UI and request script termination, preventing a partly initialized
setup from continuing. A rescued direct error does not discard prior objects.
Source defects are not repaired by the shim. Regression fixtures distinguish
unchanged source failures from explicitly corrected candidates; see their
[provenance and limits](../spec/fixtures/webui/README.txt).

## Hosting and presentation

macOS uses an AppKit/WKWebView helper. Ruby4Lich5 tooling is the intended delivery
mechanism; signing and Gatekeeper acceptance remain distribution work. Normal
launches do not compile or download the helper, and a missing helper reports a
launch failure. Developers can build it with
`zsh lib/webui/native/macos/build.sh` using Apple's command-line tools. The source
build targets macOS 14 or later; that build target is not a substitute for the
maintainers' supported-platform policy.

Windows and Linux use dedicated Chrome app windows; Windows also supports Edge.
Windows topmost/opacity support uses the existing Fiddle/user32 integration, not
an additional WebView2 runtime. Browser and OS capabilities differ. Native focus,
topmost, opacity, geometry and cleanup require platform beta acceptance.

Each page has an owned host. Chrome/Edge use isolated temporary profiles; the
macOS helper uses nonpersistent WebKit storage. Closing one page does not close
the user's ordinary browser. Native presentation properties must be requested
through the component contract; CSS cannot establish an OS-level topmost window.
Explicit caller geometry takes precedence over saved geometry and defaults.
Pages with configure handlers own their geometry policy, including shim windows.

The shared loopback host authenticates page and WebSocket access. Launch URLs
are short-lived credentials: do not persist or log them. Registered file access
is scoped to the owning page/session and application roots. Do not treat the
loopback UI as a public server or a sandbox for untrusted script code.

## Theme and shared helpers

Pages inherit `Lich.track_dark_mode`, including the startup `--dark-mode`
override, unless they explicitly request `theme: :light` or `:dark`. Standalone
consumers without Lich settings default to light. The shim's theme query reads
the same preference. Explicit component colors, fonts and dimensions retain
their authority; changing theme does not replace script-owned preferences.

`SettingsForm` and `ListSettingsForm` compose existing controls while retaining
caller-owned persistence and validation. `SettingsForm.choice_options` preserves
prepared order, duplicates and blank choices. `ListSettingsForm.text_list_spec`
passes list mutations through the caller's callbacks. `TreeBuilder#setup_footer`
combines caller-supplied notice and action rendering; it does not save or close
anything. Notice wording must match actual behavior.

## Validation

Run the ordinary Ruby suite and relevant individual specs with the project's
configured Ruby environment. RSpec does not run the npm suite automatically:

```sh
parallel_rspec -n 4 --serialize-stdout --verbose-rerun-command -o '--seed 251026' spec
npm test --prefix spec/webui
NATIVE_BROWSER=1 parallel_rspec -n 2 --test-options '--tag browser' spec/lib/common spec/lib/webui
```

The browser tests require the locked test dependencies and installed Chrome.
The default-startup probe validates authenticated protocol traffic and shutdown;
it is not a native-window test. On a suitable logged-in macOS desktop,
`NATIVE_HOST=1 rspec spec/lib/webui/native_host_presentation_spec.rb` exercises the
native host. `ruby bench/native_webui_smoke.rb` is an interactive manual check,
not CI. See [test guidance](../spec/README.md#webui-validation).

Fixtures use pinned excerpts, explicit game boundaries and isolated persistence.
Neither fixture passes nor source-tree historical results certify full script
operations or every platform. Actual script and native-host acceptance belongs
to beta testing. Rollback, if approved, uses an earlier GTK-supported Lich release;
it is not a GTK mode inside this WebUI runtime.
