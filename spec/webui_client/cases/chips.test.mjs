// 2.20 chips: several values from a list, as removable chips with a filter
// box. The option list is built from the filter's text and lives only while
// there is text; a non-searchable field opens the whole list on focus;
// allow_custom admits what was typed; max caps the count.
import { test } from "node:test";
import assert from "node:assert/strict";
import { boot } from "../run.mjs";

const AREAS = "page:chips/chips:areas";
const ROOMS = "page:chips/chips:rooms";
const ALL = "page:chips/chips:all";

function chips(h, cid) {
  return Array.from(h.element(cid).querySelectorAll(".chip")).map((chip) => chip.dataset.value);
}
function filterOf(h, cid) {
  return h.element(cid).querySelector("input");
}
function optionsOf(h, cid) {
  const list = h.element(cid).querySelector(".chips-options");
  return list.hidden ? null : Array.from(list.querySelectorAll(".chips-option")).map((option) => option.dataset.value);
}
function changes(h, cid) {
  return h.socket.events().filter((e) => e.cid === cid && e.event === "change").map((e) => e.payload.values);
}

test("typing filters the options, choosing one adds a chip and reports every value", () => {
  const h = boot();
  try {
    h.attach("chips");
    assert.deepEqual(chips(h, AREAS), ["thanot"]);
    const filter = filterOf(h, AREAS);
    assert.equal(optionsOf(h, AREAS), null, "nothing listed until something is typed");

    h.type(filter, "zu");
    assert.deepEqual(optionsOf(h, AREAS), ["zul"]);
    h.element(AREAS).querySelector(".chips-option").dispatchEvent(new h.window.MouseEvent("mousedown", { bubbles: true, cancelable: true }));
    assert.deepEqual(chips(h, AREAS), ["thanot", "zul"]);
    assert.deepEqual(changes(h, AREAS), [["thanot", "zul"]]);
    assert.equal(filter.value, "", "the filter is cleared for the next value");
    assert.equal(optionsOf(h, AREAS), null);

    h.type(filter, "e");
    assert.deepEqual(optionsOf(h, AREAS), ["pinefar", "gyre"], "a chosen value is no longer offered");
    const groups = Array.from(h.element(AREAS).querySelectorAll(".chips-group")).map((g) => g.textContent);
    assert.deepEqual(groups, ["Icemule", "Wehnimer"]);
    h.key(filter, "Enter");
    assert.deepEqual(chips(h, AREAS), ["thanot", "zul", "pinefar"], "Enter takes the first match");
  } finally {
    h.close();
  }
});

test("a chip's button and Backspace on an empty filter remove; the control's value is the chips", () => {
  const h = boot();
  try {
    h.attach("chips");
    const remove = h.element(AREAS).querySelector(".chip .chip-remove");
    assert.equal(remove.getAttribute("aria-label"), "Remove Thanot");
    h.click(remove);
    assert.deepEqual(chips(h, AREAS), []);
    assert.deepEqual(changes(h, AREAS), [[]]);

    const rooms = filterOf(h, ROOMS);
    h.key(rooms, "Backspace");
    assert.deepEqual(chips(h, ROOMS), ["12345"]);
    assert.deepEqual(changes(h, ROOMS), [["12345"]]);
    const control = h.element(ROOMS).querySelector(".chips-control");
    assert.deepEqual([...control.chipsValues()], ["12345"], "what a submission would carry");
    assert.equal(control.value, JSON.stringify(["12345"]));
  } finally {
    h.close();
  }
});

test("allow_custom offers what was typed; max closes the field when reached", () => {
  const h = boot();
  try {
    h.attach("chips");
    const rooms = filterOf(h, ROOMS);
    h.type(rooms, "34567");
    assert.deepEqual(optionsOf(h, ROOMS), ["34567"], "no options, so the typed value is the one offer");
    h.key(rooms, "Enter");
    assert.deepEqual(chips(h, ROOMS), ["12345", "23456", "34567"]);
    assert.equal(rooms.disabled, true, "max reached");
    h.type(rooms, "45678");
    h.key(rooms, "Enter");
    assert.deepEqual(chips(h, ROOMS), ["12345", "23456", "34567"], "nothing past max");

    const areas = filterOf(h, AREAS);
    h.type(areas, "nowhere");
    assert.equal(optionsOf(h, AREAS), null, "without allow_custom an unknown value offers nothing");
    h.key(areas, "Enter");
    assert.deepEqual(chips(h, AREAS), ["thanot"]);
  } finally {
    h.close();
  }
});

test("a non-searchable field lists every remaining option on focus", () => {
  const h = boot();
  try {
    h.attach("chips");
    const all = filterOf(h, ALL);
    all.dispatchEvent(new h.window.Event("focus"));
    assert.deepEqual(optionsOf(h, ALL), ["thanot", "pinefar", "zul", "gyre"]);
    all.dispatchEvent(new h.window.Event("blur"));
    assert.equal(optionsOf(h, ALL), null);
  } finally {
    h.close();
  }
});

test("a render carrying the viewer's value shows it; the chips survive an unrelated render", () => {
  const h = boot();
  try {
    const render = h.attach("chips");
    h.rerender(render, (next) => {
      const areas = (function walk(nodeTree) {
        if (nodeTree.cid === AREAS) return nodeTree;
        for (const child of nodeTree.children || []) { const found = walk(child); if (found) return found; }
        return null;
      }(next.tree));
      areas.props.value = ["gyre", "zul"];
    });
    assert.deepEqual(chips(h, AREAS), ["gyre", "zul"]);
    assert.deepEqual(changes(h, AREAS), [], "showing the server's value is not a change");
  } finally {
    h.close();
  }
});

// 2.20 on the older inputs: `size` on a select shows a list box, and grouped
// options sit under headings in select and radio alike.
test("a select with size is a list box, and grouped options sit under headings in select and radio", () => {
  const h = boot();
  try {
    h.attach("chips");
    const town = h.control("page:chips/select:town");
    assert.equal(town.size, 4);
    assert.deepEqual(Array.from(town.querySelectorAll("optgroup")).map((g) => g.label), ["Icemule", "Wehnimer"]);
    assert.equal(town.value, "zul");
    const headings = Array.from(h.element("page:chips/radio:side").querySelectorAll(".radio-group")).map((g) => g.textContent);
    assert.deepEqual(headings, ["Icemule", "Wehnimer"]);
  } finally {
    h.close();
  }
});
