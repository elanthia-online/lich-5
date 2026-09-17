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
