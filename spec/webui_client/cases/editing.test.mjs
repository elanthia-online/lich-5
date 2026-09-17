// Edit preservation: a render arriving while the viewer types does not take
// their draft or their caret; a value the server deliberately changed does.
import { test } from "node:test";
import assert from "node:assert/strict";
import { boot, find } from "../run.mjs";

const NAME = "page:edits/text_input:name";
const COUNT = "page:edits/number_input:count";
const SECRET = "page:edits/password_input:secret";

test("a half-typed text input survives an unrelated render, caret included", () => {
  const h = boot();
  try {
    const render = h.attach("edits");
    const name = h.control(NAME);
    h.type(name, "Alice B");
    name.setSelectionRange(3, 5);
    assert.equal(h.document.activeElement, name);

    h.rerender(render);
    const after = h.control(NAME);
    assert.notEqual(after, name, "the render rebuilt the control");
    assert.equal(after.value, "Alice B");
    assert.equal(h.document.activeElement, after);
    assert.equal(after.selectionStart, 3);
    assert.equal(after.selectionEnd, 5);
  } finally {
    h.close();
  }
});

test("a half-typed number input survives an unrelated render", () => {
  const h = boot();
  try {
    const render = h.attach("edits");
    const count = h.control(COUNT);
    assert.equal(count.type, "number");
    h.type(count, "42");
    h.rerender(render);
    assert.equal(h.control(COUNT).value, "42");
    assert.equal(h.control(COUNT).valueAsNumber, 42);
  } finally {
    h.close();
  }
});

test("a half-typed password survives an unrelated render although the tree carries no value", () => {
  const h = boot();
  try {
    const render = h.attach("edits");
    assert.equal(Object.hasOwn(find(render.tree, SECRET).props, "value"), false, "the runtime never sends a password value");
    const secret = h.control(SECRET);
    assert.equal(secret.type, "password");
    h.type(secret, "hunter2");
    secret.setSelectionRange(2, 2);

    h.rerender(render);
    const after = h.control(SECRET);
    assert.equal(after.value, "hunter2");
    assert.equal(h.document.activeElement, after);
    assert.equal(after.selectionStart, 2);
  } finally {
    h.close();
  }
});

test("a genuine server value change wins over the draft", () => {
  const h = boot();
  try {
    const render = h.attach("edits");
    h.type(h.control(NAME), "Alic");
    h.type(h.control(COUNT), "42");
    h.rerender(render, (next) => {
      find(next.tree, NAME).props.value = "Bob";
      find(next.tree, COUNT).props.value = 7;
    });
    assert.equal(h.control(NAME).value, "Bob");
    assert.equal(h.control(COUNT).value, "7");
  } finally {
    h.close();
  }
});

// Review 2026-09-17, R10: a table's editor cells were not controls, so a
// half-typed cell was replaced by the model value on any render.
test("a half-typed table cell survives an unrelated render, and a changed model value wins", () => {
  const h = boot();
  try {
    const render = h.attach("tables");
    const cell = () => h.element("page:tables/table:editable").querySelector("input");
    h.type(cell(), "unfinished");
    h.rerender(render);
    assert.equal(cell().value, "unfinished");
    assert.equal(h.document.activeElement, cell(), "focus stays in the cell");

    h.rerender(render, (next) => {
      const table = next.tree.children.find((child) => child.cid === "page:tables/table:editable");
      table.props.rows[0].cells.name = "server";
    });
    assert.equal(cell().value, "server", "a value the script changed replaces the draft");

    // A committed edit the script refused: the render carries the old value
    // and the cell shows it, not the refused keystrokes.
    h.commit(cell(), "refused");
    assert.equal(h.socket.events().filter((e) => e.event === "cell_edit").length, 1);
    h.rerender(render, (next) => {
      const table = next.tree.children.find((child) => child.cid === "page:tables/table:editable");
      table.props.rows[0].cells.name = "server";
    });
    assert.equal(cell().value, "server", "the script's answer shows after a commit");
  } finally {
    h.close();
  }
});
