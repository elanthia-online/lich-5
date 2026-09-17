// 2.15.1: every socket handler closes over the socket it was made for, so
// an error on a superseded socket cannot close the live one.
import { test } from "node:test";
import assert from "node:assert/strict";
import { boot } from "../run.mjs";

test("an error on a superseded socket does not close the live one, and the live one re-attaches", async () => {
  const h = boot();
  try {
    const first = h.socket;
    const render = h.attach("actions");
    assert.equal(h.FakeWebSocket.instances.length, 1);

    // The connection drops: the client dials again after its backoff.
    first.close();
    assert.match(h.document.getElementById("status").textContent, /reconnecting/i);
    await h.tick(300);
    assert.equal(h.FakeWebSocket.instances.length, 2, "one reconnect");
    const second = h.socket;
    assert.notEqual(second, first);
    second.open();

    // A late error from the dead socket. The old code closed the CURRENT
    // socket here, which then dialled a third one.
    first.fail();
    await h.tick(300);
    assert.equal(second.readyState, h.FakeWebSocket.OPEN, "the live socket stays open");
    assert.equal(h.FakeWebSocket.instances.length, 2, "no reconnect loop");

    // The live socket is the one that resumes: hello on it gets an attach.
    h.hello([render]);
    assert.deepEqual(second.ofType("attach").map((m) => m.page), [render.page]);
    assert.equal(first.ofType("attach").length, 1, "the dead socket saw only the original attach");
  } finally {
    h.close();
  }
});
