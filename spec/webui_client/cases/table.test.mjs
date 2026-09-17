// Table multi-select (W05) and `disabled` on select and table (2.15.1).
import { test } from "node:test";
import assert from "node:assert/strict";
import { boot } from "../run.mjs";

const LIVE = "page:tables/table:live";
const LOCKED = "page:tables/table:locked";
const PICK = "page:tables/select:pick";
const FROZEN = "page:tables/select:frozen";

function row(h, cid, key) {
  return h.element(cid).querySelector(`tr[data-row-key="${key}"]`);
}

function selectedRows(h, cid) {
  return Array.from(h.element(cid).querySelectorAll('tr[aria-selected="true"]')).map((tr) => tr.dataset.rowKey);
}

test("ctrl-click accumulates, shift-click ranges, plain click replaces", () => {
  const h = boot();
  try {
    h.attach("tables");
    h.click(row(h, LIVE, "b"));
    h.click(row(h, LIVE, "d"), { ctrlKey: true });
    h.click(row(h, LIVE, "a"), { ctrlKey: true });
    assert.deepEqual(h.socket.events().map((e) => e.payload.rows), [["b"], ["b", "d"], ["b", "d", "a"]]);
    assert.deepEqual(selectedRows(h, LIVE), ["a", "b", "d"]);

    // ctrl-click on a selected row removes it; the selection is read back
    // from the rows on screen, so it reports in table order.
    h.click(row(h, LIVE, "d"), { ctrlKey: true });
    assert.deepEqual(h.socket.events().at(-1).payload.rows, ["a", "b"]);

    // shift extends from the last row clicked without shift -- d, the
    // ctrl-click just above, as GTK moves the cursor on ctrl-click too --
    // and the range replaces what was accumulated.
    h.click(row(h, LIVE, "b"), { shiftKey: true });
    assert.deepEqual(h.socket.events().at(-1).payload.rows, ["b", "c", "d"]);
    assert.deepEqual(selectedRows(h, LIVE), ["b", "c", "d"]);

    // A plain click replaces everything.
    h.click(row(h, LIVE, "e"));
    assert.deepEqual(h.socket.events().at(-1).payload.rows, ["e"]);
    assert.deepEqual(selectedRows(h, LIVE), ["e"]);
    assert.ok(h.socket.events().every((e) => e.cid === LIVE && e.event === "selection_change"));
  } finally {
    h.close();
  }
});

test("a disabled table answers neither clicks nor activation, and a disabled select is disabled", () => {
  const h = boot();
  try {
    h.attach("tables");
    h.click(row(h, LOCKED, "a"));
    h.click(row(h, LOCKED, "b"), { ctrlKey: true });
    row(h, LOCKED, "a").dispatchEvent(new h.window.MouseEvent("dblclick", { bubbles: true }));
    h.key(row(h, LOCKED, "a"), "Enter");
    assert.deepEqual(h.socket.events(), [], "a disabled table emits nothing");
    assert.deepEqual(selectedRows(h, LOCKED), []);
    assert.equal(h.element(LOCKED).dataset.disabled, "true");

    // The live table still activates on double-click, so the silence above
    // is the `disabled`, not a dead gesture.
    row(h, LIVE, "a").dispatchEvent(new h.window.MouseEvent("dblclick", { bubbles: true }));
    assert.deepEqual(h.socket.events().map((e) => [e.cid, e.event]), [[LIVE, "row_activate"]]);

    assert.equal(h.control(FROZEN).disabled, true);
    assert.equal(h.control(PICK).disabled, false);
  } finally {
    h.close();
  }
});
