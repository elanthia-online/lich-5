// The client harness: the REAL lib/webui/assets/app.js loaded into a jsdom
// window against a fake WebSocket the test controls. A case sends server
// messages in with `socket.receive(...)`, drives the DOM the way a viewer
// would, and reads the messages app.js sent out of `socket.sent`.
//
// Nothing app.js relies on is stubbed around: window.location,
// requestAnimationFrame, timers, EventTarget and the DOM are jsdom's own
// (pretendToBeVisual gives it a real animation-frame clock). The only
// thing replaced is the WebSocket constructor, because there is no server.
//
// Fixtures in fixtures/renders.json are `render` messages the real runtime
// produced for the pages the cases use (fixtures/generate.rb).

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { JSDOM, VirtualConsole } from "jsdom";

const here = path.dirname(fileURLToPath(import.meta.url));
const assets = path.resolve(here, "../../lib/webui/assets");
const appSource = fs.readFileSync(path.join(assets, "app.js"), "utf8");
const indexHtml = fs.readFileSync(path.join(assets, "index.html"), "utf8");
export const renders = JSON.parse(fs.readFileSync(path.join(here, "fixtures/renders.json"), "utf8"));

// A WebSocket with no wire behind it. It is a real EventTarget of the
// window it is installed in, so app.js's addEventListener/dispatch see
// ordinary DOM events; readyState follows the standard constants, and a
// closed socket stays closed -- a second close() is a no-op, as it is for
// a real one, which is what lets the reconnect case observe whether an
// error on a dead socket reaches the live one.
function installFakeWebSocket(window) {
  const instances = [];
  class FakeWebSocket extends window.EventTarget {
    static CONNECTING = 0;
    static OPEN = 1;
    static CLOSING = 2;
    static CLOSED = 3;
    static instances = instances;

    constructor(url) {
      super();
      this.url = url;
      this.readyState = FakeWebSocket.CONNECTING;
      this.sent = [];
      instances.push(this);
    }

    // Server side of the socket: the test's hand.
    open() {
      this.readyState = FakeWebSocket.OPEN;
      this.dispatchEvent(new window.Event("open"));
    }

    receive(message) {
      const data = typeof message === "string" ? message : JSON.stringify(message);
      this.dispatchEvent(new window.MessageEvent("message", { data }));
    }

    fail() {
      this.dispatchEvent(new window.Event("error"));
    }

    // Client side: what app.js calls.
    send(text) {
      if (this.readyState !== FakeWebSocket.OPEN) throw new Error("send on a socket that is not open");
      this.sent.push(JSON.parse(text));
    }

    close() {
      if (this.readyState === FakeWebSocket.CLOSED) return;
      this.readyState = FakeWebSocket.CLOSED;
      this.dispatchEvent(new window.Event("close"));
    }

    // Messages of one type, most recent last.
    ofType(type) {
      return this.sent.filter((message) => message.type === type);
    }

    events() {
      return this.ofType("event");
    }
  }
  window.WebSocket = FakeWebSocket;
  return FakeWebSocket;
}

// Boots one window with the client loaded and its first socket open.
// `query` is the launch URL's search string ("?page=..." scopes the window
// to one page, as the launcher does).
export function boot({ query = "" } = {}) {
  const warnings = [];
  const virtualConsole = new VirtualConsole();
  virtualConsole.on("warn", (...args) => warnings.push(args));
  virtualConsole.on("error", (...args) => warnings.push(args));
  virtualConsole.on("jsdomError", (error) => { throw error; });
  const dom = new JSDOM(indexHtml, {
    url: `http://localhost:0/${query}`,
    pretendToBeVisual: true,
    runScripts: "outside-only",
    virtualConsole,
  });
  const { window } = dom;
  const FakeWebSocket = installFakeWebSocket(window);
  window.eval(appSource);
  const socket = FakeWebSocket.instances.at(-1);
  socket.open();

  const harness = {
    window,
    document: window.document,
    FakeWebSocket,
    warnings,
    get socket() { return FakeWebSocket.instances.at(-1); },
    // The client's view of the server saying hello with these pages; the
    // client answers with an attach per page it will show.
    hello(pages) {
      this.socket.receive({
        type: "hello", contract_version: window.LichWebUI.VERSION, viewer: "viewer-harness",
        pages: pages.map((render) => ({ address: render.page, title: render.tree.props.title, owner: "harness" })),
      });
    },
    // Attaches a fixture page end to end: hello, the client's attach, the
    // render. Returns the render delivered, generation included.
    attach(name) {
      const render = clone(renders[name]);
      this.hello([render]);
      const attach = this.socket.ofType("attach").find((message) => message.page === render.page);
      if (!attach) throw new Error(`client did not attach ${name}`);
      this.socket.receive(render);
      return render;
    },
    // A later render of the same page: the fixture again, one generation
    // on, with `mutate` applied to the tree first if given.
    rerender(render, mutate = null) {
      const next = clone(render);
      next.generation = render.generation + 1;
      if (mutate) mutate(next);
      this.socket.receive(next);
      return next;
    },
    refuse(render, cid, event, reason = "stale_generation") {
      this.socket.receive({ type: "refusal", reason, message: "Message refused", page: render.page, cid, event });
    },
    control(cid) {
      const wrapper = window.document.querySelector(`[data-cid="${cid}"]`);
      if (!wrapper) throw new Error(`no element for ${cid}`);
      return wrapper.matches("input, select, textarea") ? wrapper : wrapper.querySelector("input, select, textarea");
    },
    element(cid) {
      const element = window.document.querySelector(`[data-cid="${cid}"]`);
      if (!element) throw new Error(`no element for ${cid}`);
      return element;
    },
    // What a viewer typing does: the value, then the input event.
    type(control, value) {
      control.focus();
      control.value = value;
      control.dispatchEvent(new window.Event("input", { bubbles: true }));
    },
    // A committed edit: input, then change.
    commit(control, value) {
      this.type(control, value);
      control.dispatchEvent(new window.Event("change", { bubbles: true }));
    },
    click(element, init = {}) {
      element.dispatchEvent(new window.MouseEvent("click", { bubbles: true, cancelable: true, ...init }));
    },
    key(element, key) {
      element.dispatchEvent(new window.KeyboardEvent("keydown", { key, bubbles: true, cancelable: true }));
    },
    // Lets timers app.js set with setTimeout(fn, 0) run.
    tick(ms = 5) {
      return new Promise((resolve) => setTimeout(resolve, ms));
    },
    // Waits for the next animation frame to have fired, plus a tick so
    // anything the frame scheduled has run.
    async frame() {
      await new Promise((resolve) => window.requestAnimationFrame(resolve));
      await this.tick(0);
    },
    close() {
      window.close();
    },
  };
  return harness;
}

// Finds a node in a render tree by cid.
export function find(tree, cid) {
  if (!tree) return null;
  if (tree.cid === cid) return tree;
  for (const child of tree.children || []) {
    const found = find(child, cid);
    if (found) return found;
  }
  return null;
}

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}
