// 2.17: a composite's line, rect and ellipse layers are drawn as SVG.
import { test } from "node:test";
import assert from "node:assert/strict";
import { boot, find } from "../run.mjs";

const SURFACE = "page:shapes/composite:surface";

test("ellipse, rect and line layers render SVG children with the right geometry and paint", () => {
  const h = boot();
  try {
    const render = h.attach("shapes");
    const layers = find(render.tree, SURFACE).props.layers;
    assert.deepEqual(layers.map((layer) => layer.kind), ["ellipse", "rect", "line"]);

    const svgs = Array.from(h.element(SURFACE).querySelectorAll("svg.composite-shape"));
    assert.equal(svgs.length, 3);
    svgs.forEach((svg) => assert.equal(svg.namespaceURI, "http://www.w3.org/2000/svg"));

    // ellipse: 20x20 box at (10,10), stroke width 3 -> pad 3, so the svg is
    // 26x26 placed at (7,7) and the ellipse centred in it.
    const ellipse = svgs[0].querySelector("ellipse");
    assert.ok(ellipse);
    assert.equal(svgs[0].getAttribute("width"), "26");
    assert.equal(svgs[0].getAttribute("height"), "26");
    assert.equal(svgs[0].dataset.originX, "7");
    assert.equal(svgs[0].dataset.originY, "7");
    assert.equal(ellipse.getAttribute("cx"), "13");
    assert.equal(ellipse.getAttribute("cy"), "13");
    assert.equal(ellipse.getAttribute("rx"), "10");
    assert.equal(ellipse.getAttribute("ry"), "10");
    assert.equal(ellipse.getAttribute("stroke"), "rgb(255 0 0 / 0.8)");
    assert.equal(ellipse.getAttribute("stroke-width"), "3");
    assert.equal(ellipse.getAttribute("fill"), "none");

    // rect: tone stroke, RGBA fill, default stroke width 1 -> pad 2.
    const rect = svgs[1].querySelector("rect");
    assert.ok(rect);
    assert.equal(rect.getAttribute("width"), "30");
    assert.equal(rect.getAttribute("height"), "20");
    assert.equal(rect.getAttribute("x"), "2");
    assert.equal(rect.getAttribute("y"), "2");
    assert.equal(rect.getAttribute("fill"), "rgb(0 0 255 / 0.5)");
    assert.equal(rect.getAttribute("stroke-width"), "1");
    // A tone tint is paint named by the tone, not an RGBA (it used to fall
    // through the RGBA branch and come out black).
    assert.equal(rect.getAttribute("stroke"), "var(--tone-danger)");
    assert.equal(svgs[1].dataset.originX, "38");

    // line: from (0,0) to (99,99), stroke width 2 -> pad 2.
    const line = svgs[2].querySelector("line");
    assert.ok(line);
    assert.deepEqual(["x1", "y1", "x2", "y2"].map((name) => line.getAttribute(name)), ["2", "2", "101", "101"]);
    assert.equal(line.getAttribute("stroke"), "rgb(0 200 0 / 1)");
    assert.equal(line.getAttribute("stroke-width"), "2");
    assert.equal(svgs[2].getAttribute("width"), "103");
  } finally {
    h.close();
  }
});

// 2.19: ctrl+wheel over a surface that asked for surface events is a zoom
// request carrying the pointer, not a scroll.
test("ctrl+wheel emits surface_zoom with a direction and the pointer; a plain wheel does not", () => {
  const h = boot();
  try {
    h.attach("shapes");
    const surface = h.element(SURFACE);
    const wheel = (init) => surface.dispatchEvent(new h.window.WheelEvent("wheel", { bubbles: true, cancelable: true, ...init }));

    wheel({ deltaY: -120, clientX: 30, clientY: 40 });
    assert.equal(h.socket.ofType("event").filter((m) => m.event === "surface_zoom").length, 0);

    const cancelled = !wheel({ deltaY: -120, clientX: 30, clientY: 40, ctrlKey: true });
    assert.equal(cancelled, true, "the browser's own ctrl+wheel zoom must be suppressed");
    wheel({ deltaY: 120, clientX: 30, clientY: 40, ctrlKey: true, shiftKey: true });

    const zooms = h.socket.ofType("event").filter((m) => m.event === "surface_zoom");
    assert.equal(zooms.length, 2);
    assert.equal(zooms[0].payload.direction, "in");
    assert.equal(zooms[1].payload.direction, "out");
    assert.deepEqual(zooms[1].payload.modifiers, ["ctrl", "shift"]);
    assert.equal("button" in zooms[0].payload, false);
    assert.equal(typeof zooms[0].payload.x, "number");
  } finally {
    h.close();
  }
});
