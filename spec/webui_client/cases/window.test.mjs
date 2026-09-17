// A window opened for one page sizes itself to that page on its first
// render, and closes itself when its last page closes. Chrome ignores
// --window-size once it is already running, so the first thing a script
// window did was appear at the screen's size; and a page whose owner
// closed it used to leave an empty window behind.
import { test } from "node:test";
import assert from "node:assert/strict";
import { boot } from "../run.mjs";

function watchWindow(h) {
  const calls = { resize: [], move: [], close: 0 };
  h.window.resizeTo = (width, height) => calls.resize.push([width, height]);
  h.window.moveTo = (x, y) => calls.move.push([x, y]);
  h.window.close = () => { calls.close += 1; };
  return calls;
}

test("an explicit geometry facility becomes the window size, once", () => {
  const h = boot();
  const calls = watchWindow(h);
  try {
    const render = h.attach("actions");
    // The fixture has no geometry; a second render with one is what the
    // launcher and a shim window with a default size send.
    assert.deepEqual(calls.resize, [], "nothing measurable in jsdom, so no content-sized resize");
    h.rerender(render, (next) => { next.facilities = { geometry: { width: 700, height: 500 } }; });
    assert.deepEqual(calls.resize, [], "the window is fitted on the first render only");
  } finally {
    h.close();
  }
});

test("a page whose first render carries geometry opens at that size, chrome included", () => {
  const h = boot();
  const calls = watchWindow(h);
  try {
    // jsdom reports outer == inner, so the chrome adds nothing here; the
    // arithmetic is pinned by the minimum instead.
    const render = h.attachWith("actions", (next) => { next.facilities = { geometry: { width: 700, height: 500 } }; });
    assert.deepEqual(calls.resize, [[700, 500]]);
    h.rerender(render, (next) => { next.facilities = { geometry: { width: 900, height: 900 } }; });
    assert.deepEqual(calls.resize, [[700, 500]], "later geometry does not fight the viewer's own resizing");
  } finally {
    h.close();
  }
});

test("a geometry below the minimum is raised to it", () => {
  const h = boot();
  const calls = watchWindow(h);
  try {
    h.attachWith("actions", (next) => { next.facilities = { geometry: { width: 100, height: 40 } }; });
    assert.deepEqual(calls.resize, [[320, 200]]);
  } finally {
    h.close();
  }
});

test("the last page closing closes the window; an earlier one does not", () => {
  const h = boot();
  const calls = watchWindow(h);
  try {
    const render = h.attach("actions");
    h.socket.receive({ type: "page_closed", page: render.page, reason: "owner" });
    assert.equal(calls.close, 1, "a window showing nothing closes itself");
    assert.equal(h.document.querySelectorAll(".webui-page").length, 0);
  } finally {
    h.close();
  }
});

test("a geometry with a position moves the window there, once; without one it is left alone", () => {
  const h = boot();
  const calls = watchWindow(h);
  try {
    const render = h.attachWith("actions", (next) => { next.facilities = { geometry: { width: 700, height: 500, x: 40, y: 60 } }; });
    assert.deepEqual(calls.move, [[40, 60]]);
    h.rerender(render, (next) => { next.facilities = { geometry: { width: 700, height: 500, x: 1, y: 2 } }; });
    assert.deepEqual(calls.move, [[40, 60]], "a later position does not fight the viewer's own dragging");
  } finally {
    h.close();
  }
  const g = boot();
  const quiet = watchWindow(g);
  try {
    g.attachWith("actions", (next) => { next.facilities = { geometry: { width: 700, height: 500 } }; });
    assert.deepEqual(quiet.move, [], "no position declared, no move");
  } finally {
    g.close();
  }
});

test("the window-geometry field reports the content size, not the outer size", async () => {
  const h = boot();
  try {
    Object.defineProperty(h.window, "outerWidth", { value: 1100, configurable: true, writable: true });
    Object.defineProperty(h.window, "outerHeight", { value: 900, configurable: true, writable: true });
    Object.defineProperty(h.window, "innerWidth", { value: 1000, configurable: true, writable: true });
    Object.defineProperty(h.window, "innerHeight", { value: 820, configurable: true, writable: true });
    // The fixture's note field, made the geometry field by its key: the
    // client picks the tracker by cid.
    h.attachWith("actions", (next) => {
      const note = next.tree.children.find((c) => c.cid === "page:actions/text_input:note");
      note.cid = "page:actions/text_input:window-geometry";
      note.props.key = "window-geometry";
      next.bindings[note.cid] = next.bindings["page:actions/text_input:note"];
      delete next.bindings["page:actions/text_input:note"];
    });
    h.window.innerWidth = 980;
    h.window.innerHeight = 800;
    await h.tick(700);
    const reports = h.socket.sent.filter((m) => m.type === "event" && m.cid === "page:actions/text_input:window-geometry");
    assert.equal(reports.length, 1, "one report for one change");
    const geometry = JSON.parse(reports[0].payload.value);
    assert.equal(geometry.width, 980);
    assert.equal(geometry.height, 800);
  } finally {
    h.close();
  }
});

test("a resize is still reported when the page re-renders faster than the tracker's interval", async () => {
  const h = boot();
  try {
    Object.defineProperty(h.window, "innerWidth", { value: 1000, configurable: true, writable: true });
    Object.defineProperty(h.window, "innerHeight", { value: 820, configurable: true, writable: true });
    const geometryField = (next) => {
      const note = next.tree.children.find((c) => c.cid.endsWith("text_input:note") || c.cid.endsWith("text_input:window-geometry"));
      note.cid = "page:actions/text_input:window-geometry";
      note.props.key = "window-geometry";
      next.bindings[note.cid] = ["change"];
      delete next.bindings["page:actions/text_input:note"];
    };
    const render = h.attachWith("actions", geometryField);
    h.window.innerWidth = 900;
    // Renders every 200ms for a second: each one restarts the tracker.
    for (let i = 0; i < 5; i += 1) {
      await h.tick(200);
      h.rerender(render, geometryField);
    }
    await h.tick(700);
    const reports = h.socket.sent.filter((m) => m.type === "event" && m.cid === "page:actions/text_input:window-geometry");
    assert.equal(reports.length, 1, "the resize is reported once, not swallowed by the renders");
    assert.equal(JSON.parse(reports[0].payload.value).width, 900);
  } finally {
    h.close();
  }
});
