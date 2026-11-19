# Genie engine — code & spec standards

The bar every file in this effort holds to. Referenced from PRs.

## Tooling
- Ruby 4.0, RSpec 3.13, rubocop (repo `.rubocop.yml`). The `AsciiOnlySource` cop is active:
  **use escape sequences for any non-ASCII** (e.g. Genie's variable sentinel).

## SOLID
- **SRP:** one class/module per concern (`Numeric`, `Text`, `MathCalc`, `MathEval`, `Eval`, and
  forthcoming `Interpreter`, `Variables`, `Hooks`, `Lexer`). A class is split when it grows a
  second reason to change (e.g. split `Eval`'s function library out if it expands).
- **DIP:** collaborators are injected so units test without the Lich runtime. `Eval.new(globals:)`
  takes its variable lookup; the interpreter takes a game/IO port + variable store + hook sink.
- **OCP:** verbs and hook ops are dispatch tables — adding one does not modify the core loop.
- **LSP/ISP:** `GenieScript < Script` must honor the `Script` contract; injected ports expose only
  the methods the engine needs.

## DRY (production code)
- Shared numeric/string semantics live once in `Numeric`/`Text`. Faithful ports of the *same*
  Genie helper collapse to one Ruby method. No copy-pasted parsing.

## YARD (production code) — what "copious" means here
- **Every class/module:** a summary doc that cites the Genie4 source it ports and lists any
  faithful behavioral quirks it preserves.
- **Every public method:** full `@param` / `@return` / `@raise` tags.
- **Non-obvious private methods:** a one-line purpose plus notes on any faithful Genie quirk
  (so future readers don't "fix" intentional behavior).
- **Trivial one-line helpers** (e.g. `num_bool`, `number`, `string`): left clean — YARD there is
  noise, not documentation.
- **Every intentional Genie quirk** gets an inline comment at the site (left-assoc `^`, dividend-
  sign `%`, `log`=base-10, negative-arg clamp, string relational -> false, etc.).
- **Cross-cutting TODOs** are tagged, e.g. `TODO(regex-parity)`.

## Specs — DAMP, not DRY
- Descriptive `describe`/`it`; prefer small readable helpers (`truthy`, `str`, `evl`) over
  abstraction; a little repetition is fine if it aids readability.
- **Assert Genie quirks explicitly and by name** — each is its own example with a comment on why.
- One behavior per example where practical.

## Testing layers
- **Unit:** pure logic (evaluators, substitution, verb handlers with stubbed ports).
- **Integration:** drive the interpreter against a mock downstream buffer; assert the commands
  sent to the game **and** the `<genieHook>` wire bytes emitted (front-end-agnostic).
- **Acceptance bar:** behavioral transparency — a corpus of real Genie scripts under
  `spec/fixtures/genie/` must produce identical observable behavior (see design doc Decision 4).
