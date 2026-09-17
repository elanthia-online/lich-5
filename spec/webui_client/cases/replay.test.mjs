// W12: a stale-generation refusal replays the event it names, once, with
// the payload and submission it was first sent with.
import { test } from "node:test";
import assert from "node:assert/strict";
import { boot } from "../run.mjs";

const A = "page:actions/button:a";
const B = "page:actions/button:b";
const NOTE = "page:actions/text_input:note";
const SAVE = "page:actions/button:save";

test("refusing A replays A once with its original payload; B is sent exactly once; a second refusal is not replayed", async () => {
  const h = boot();
  try {
    const render = h.attach("actions");
    h.click(h.element(A));
    h.click(h.element(B));
    assert.deepEqual(h.socket.events().map((e) => [e.cid, e.event, e.generation]), [
      [A, "activate", render.generation],
      [B, "activate", render.generation],
    ]);

    // The server refuses A as stale and follows with the render that
    // superseded it. Nothing is replayed until that render lands.
    h.refuse(render, A, "activate");
    await h.tick();
    assert.equal(h.socket.events().length, 2, "a refusal alone replays nothing");

    const next = h.rerender(render);
    await h.tick();
    const events = h.socket.events();
    assert.equal(events.length, 3, "exactly one replay");
    assert.deepEqual(events[2], {
      type: "event", page: render.page, cid: A, event: "activate",
      generation: next.generation, payload: {},
    });
    assert.equal(events.filter((e) => e.cid === B).length, 1, "B is never re-sent");

    // Refuse the replay too: the attempt limit stops it here.
    h.refuse(next, A, "activate");
    h.rerender(next);
    await h.tick();
    assert.equal(h.socket.events().length, 3, "a second refusal of the same event is dropped");
  } finally {
    h.close();
  }
});

test("a refusal for an event nobody sent replays nothing", async () => {
  const h = boot();
  try {
    const render = h.attach("actions");
    h.click(h.element(B));
    h.refuse(render, A, "activate");
    h.rerender(render);
    await h.tick();
    assert.deepEqual(h.socket.events().map((e) => e.cid), [B]);
  } finally {
    h.close();
  }
});

test("a control edited between the send and the replay is not what gets replayed", async () => {
  const h = boot();
  try {
    const render = h.attach("actions");
    const note = h.control(NOTE);
    note.value = "typed-1";
    h.click(h.element(SAVE));
    const [sent] = h.socket.events();
    assert.deepEqual(sent.submission, ["typed-1"]);

    // The viewer keeps typing, then the server refuses the click.
    h.control(NOTE).value = "typed-2";
    h.refuse(render, SAVE, "activate");
    h.rerender(render);
    await h.tick();

    const events = h.socket.events();
    assert.equal(events.length, 2);
    assert.deepEqual(events[1].submission, ["typed-1"], "the replay carries the submission of the original send");
    assert.equal(events[1].cid, SAVE);
    // And the viewer's newer draft is still on screen, not lost to the render.
    assert.equal(h.control(NOTE).value, "typed-2");
  } finally {
    h.close();
  }
});
