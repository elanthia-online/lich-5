const { JSDOM } = require('jsdom');
const { browserAssets } = require('./webui_assets_fixture.cjs');

// Each call owns its DOM, measurements, observers, frames and socket capture.
// The caller closes dom.window after the test.
function measuredDomFixture() {
  const dom = new JSDOM('<div id="status"></div><div id="pages"></div><div id="notifications"></div><div id="announcer"></div>',
    { url: 'http://127.0.0.1/', runScripts: 'outside-only' });
  const frames = [], sent = [], widths = new Map(), observers = [];
  const listeners = {};
  dom.window.requestAnimationFrame = callback => frames.push(callback);
  dom.window.ResizeObserver = class {
    constructor(callback) { this.callback = callback; observers.push(this); }
    observe() {}
    disconnect() { this.disconnected = true; }
  };
  dom.window.HTMLElement.prototype.getBoundingClientRect = function () {
    return { width: widths.get(this.dataset.cid) || 0, height: 20, top: 0, left: 0 };
  };
  dom.window.WebSocket = class {
    static OPEN = 1;
    readyState = 1;
    addEventListener(name, callback) { listeners[name] = callback; }
    send(value) { sent.push(JSON.parse(value)); }
  };
  for (const asset of browserAssets()) dom.window.eval(asset.source);
  return { dom, widths, sent, observers,
    receive: value => listeners.message({ data: JSON.stringify(value) }),
    disconnect: () => listeners.close(),
    frame: () => frames.splice(0).forEach(callback => callback()),
    element: cid => dom.window.document.querySelector(`[data-cid="${cid}"]`) };
}

module.exports = { measuredDomFixture };
