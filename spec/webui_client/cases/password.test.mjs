// D17 (contract 2.18): a password says that it changed and nothing more,
// and only the server empties it.
import { test } from "node:test";
import assert from "node:assert/strict";
import { boot } from "../run.mjs";

const SECRET = "page:edits/password_input:secret";
const LOGIN = "page:edits/button:login";

test("typing into a password emits change with no payload, one per animation frame", async () => {
  const h = boot();
  try {
    const render = h.attach("edits");
    const secret = h.control(SECRET);
    h.type(secret, "h");
    h.type(secret, "hu");
    h.type(secret, "hun");
    assert.deepEqual(h.socket.events(), [], "nothing is sent before the frame");

    await h.frame();
    assert.deepEqual(h.socket.events().map(({ request, ...rest }) => rest), [{
      type: "event", page: render.page, cid: SECRET, event: "change",
      generation: render.generation, payload: {},
    }]);

    // A further keystroke in a later frame is a further change.
    h.type(secret, "hunt");
    await h.frame();
    assert.equal(h.socket.events().length, 2);
    assert.ok(h.socket.events().every((e) => JSON.stringify(e).includes("hunt") === false), "the value never leaves the browser");
  } finally {
    h.close();
  }
});

// Review 2026-09-17 (b), F5: the record of a send, password submission
// included, lived until the next render of its page and a refusal was
// honoured before its age was checked. An hour-old refusal replayed a
// password the field no longer showed.
test("a refusal arriving after the record's TTL replays nothing, and clear_sensitive drops the record at once", async () => {
  const h = boot();
  try {
    const render = h.attach("edits");
    h.type(h.control(SECRET), "hunter2");
    await h.frame();
    h.click(h.element(LOGIN));
    const original = h.socket.events().at(-1);
    assert.deepEqual(original.submission, ["hunter2"]);

    const now = h.window.Date.now();
    h.window.Date.now = () => now + 3_600_000;
    h.socket.receive({ type: "refusal", reason: "stale_generation", message: "Message refused",
      page: render.page, cid: LOGIN, event: "activate", request: original.request });
    h.rerender(render);
    await h.tick();
    assert.equal(h.socket.events().filter((e) => e.event === "activate").length, 1, "an expired record is not replayed");

    h.window.Date.now = () => now;
    h.type(h.control(SECRET), "hunter3");
    await h.frame();
    h.click(h.element(LOGIN));
    const second = h.socket.events().at(-1);
    h.socket.receive({ type: "clear_sensitive", cids: [SECRET] });
    h.socket.receive({ type: "refusal", reason: "stale_generation", message: "Message refused",
      page: render.page, cid: LOGIN, event: "activate", request: second.request });
    h.rerender(render);
    await h.tick();
    assert.equal(h.control(SECRET).value, "");
    assert.equal(h.socket.events().filter((e) => e.event === "activate").length, 2, "a cleared value is never resubmitted");
  } finally {
    h.close();
  }
});

// Review 2026-09-17 (c): a replay recomputed its scope from the current
// render; one that no longer listed the control gave the replayed record an
// empty scope, and clear_sensitive could not find the password it carried.
test("a replayed submission keeps its scope, so clear_sensitive still drops it", async () => {
  const h = boot();
  try {
    const render = h.attach("edits");
    h.type(h.control(SECRET), "hunter2");
    await h.frame();
    h.click(h.element(LOGIN));
    const original = h.socket.events().at(-1);
    assert.deepEqual(original.submission, ["hunter2"]);

    h.socket.receive({ type: "refusal", reason: "stale_generation", message: "Message refused",
      page: render.page, cid: LOGIN, event: "activate", request: original.request });
    h.rerender(render, (r) => { delete r.submissions[LOGIN]; });
    await h.tick();
    const replayed = h.socket.events().at(-1);
    assert.equal(replayed.cid, LOGIN);
    assert.deepEqual(replayed.submission, ["hunter2"], "the replay carries the original submission");

    h.socket.receive({ type: "clear_sensitive", cids: [SECRET] });
    h.socket.receive({ type: "refusal", reason: "stale_generation", message: "Message refused",
      page: render.page, cid: LOGIN, event: "activate", request: replayed.request });
    h.rerender(render);
    await h.tick();
    assert.equal(h.socket.events().filter((e) => e.event === "activate").length, 2, "the cleared value is not sent a third time");
  } finally {
    h.close();
  }
});

test("submit does not blank the field; clear_sensitive does", async () => {
  const h = boot();
  try {
    const render = h.attach("edits");
    const secret = h.control(SECRET);
    h.type(secret, "hunter2");
    await h.frame();

    h.key(secret, "Enter");
    const submit = h.socket.events().find((e) => e.event === "submit");
    assert.ok(submit, "Enter submits");
    assert.equal(submit.cid, SECRET);
    assert.equal(h.control(SECRET).value, "hunter2", "the field keeps its text after submit");

    h.click(h.element(LOGIN));
    const activate = h.socket.events().find((e) => e.event === "activate");
    assert.deepEqual(activate.submission, ["hunter2"]);
    assert.equal(h.control(SECRET).value, "hunter2", "the field keeps its text after the button's submission");

    // A wrong password: the server re-renders, and the text is still there.
    h.rerender(render);
    assert.equal(h.control(SECRET).value, "hunter2");

    // The script decides: clear_sensitive is what empties it.
    h.socket.receive({ type: "clear_sensitive", cids: [SECRET] });
    assert.equal(h.control(SECRET).value, "");
  } finally {
    h.close();
  }
});
