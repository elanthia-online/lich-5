// Shared dependency-free DOM/socket fixture for the shipped renderer.
const { browserAssets } = require("./webui_assets_fixture.cjs");
const vm = require("node:vm");

/**
 * Runs the shipped renderer against deterministic DOM/socket doubles.
 * Tests explicitly drain animation frames and deliver server envelopes; dimensions
 * are fixture values, so this helper cannot establish browser layout or OS geometry.
 * @param {string|null} target Requested page address, or null for the page selector.
 * @returns {Object} Recorded messages, synthetic DOM, and frame/delivery controls.
 */
function fixture(target) {
  class Element {
    constructor(tag) {
      if (['button', 'input', 'select', 'textarea'].includes(tag)) this.disabled = false;
      this.tagName = tag; this.children = []; this.dataset = {}; this.style = {
        setProperty(name, value) { this[name] = value; },
        removeProperty(name) { const old = this[name] || ''; delete this[name]; return old; },
        getPropertyValue(name) { return this[name] || ''; }
      };
      this.classList = { add() {}, toggle() {} }; this.listeners = {}; this.isConnected = true; this.attributes = {};
      this.clientWidth = 340; this.clientHeight = 144; this.scrollWidth = 340; this.scrollHeight = 144;
    }
    append(...children) { children.forEach(child => { child.parent = this; this.children.push(child); }); }
    replaceChildren(...children) { this.children.forEach(child => { child.isConnected = false; }); this.children = []; this.append(...children); }
    focus() { document.activeElement = this; }
    closest() { return null; }
    click() { this.listeners.click?.({}); }
    getClientRects() { return this.hidden ? [] : [this.getBoundingClientRect()]; }
    querySelector(selector) {
      const cid = selector.match(/^\[data-cid="(.*)"\]$/)?.[1];
      for (const child of this.children) {
        if (child.dataset.cid === cid) return child;
        const nested = child.querySelector?.(selector);
        if (nested) return nested;
      }
      return null;
    }
    // Width-group layout uses this selector after each render; other DOM layout
    // checks use jsdom rather than this dependency-free fixture's synthetic geometry.
    querySelectorAll(selector) {
      return this.children.flatMap(child => [
        ...(selector === '[data-width-groups]' && child.dataset.widthGroups ? [child] : []),
        ...(child.querySelectorAll?.(selector) || [])
      ]);
    }
    setAttribute(name, value) { this.attributes[name] = value; }
    setPointerCapture() {}
    getBoundingClientRect() { return { left: 0, top: 0, width: this.clientWidth, height: this.clientHeight }; }
    addEventListener(name, callback) { this.listeners[name] = callback; }
    remove() { if (this.parent) this.parent.children = this.parent.children.filter(child => child !== this); }
    replaceWith(next) { const parent = this.parent; if (parent) { this.remove(); parent.append(next); } }
    showModal() { this.open = true; }
  }
  const elements = Object.fromEntries(['pages', 'status', 'notifications', 'announcer'].map(id => [id, new Element('div')]));
  const documentEvents = {};
  const document = { title: '', activeElement: null, createElement: tag => new Element(tag),
    getElementById: id => elements[id], addEventListener(name, callback) { documentEvents[name] = callback; } };
  const sent = [], resized = [], listeners = {}, windowEvents = {};
  let timer = 0;
  const frames = [];
  class WebSocket {
    static OPEN = 1;
    readyState = 1;
    addEventListener(name, callback) { listeners[name] = callback; }
    send(raw) { sent.push(JSON.parse(raw)); }
  }
  const window = { location: { protocol: 'http:', host: '127.0.0.1', search: target === null ? '' : `?page=${target}` },
    innerWidth: 800, innerHeight: 600, outerWidth: 800, outerHeight: 630, screenX: 0, screenY: 0,
    requestAnimationFrame: work => frames.push(work), resizeTo: (...size) => resized.push(size), setTimeout: () => ++timer, clearTimeout() {},
    setInterval: () => ++timer, clearInterval() {},
    addEventListener: (name, callback) => { windowEvents[name] = callback; },
    removeEventListener: name => { delete windowEvents[name]; } };
  const context = vm.createContext({ window, document, WebSocket, URL, URLSearchParams,
    CSS: { escape: value => value }, queueMicrotask: work => work() });
  for (const asset of browserAssets()) vm.runInContext(asset.source, context, { filename: asset.name });
  return { document, documentEvents, elements, sent, resized, windowEvents, window,
    frame: () => { frames.splice(0).forEach(work => work()); },
    receive: message => listeners.message({ data: JSON.stringify(message) }) };
}

module.exports = { fixture };
