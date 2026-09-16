(() => {
  "use strict";

  const VERSION = "2.15.0";
  const pagesNode = document.getElementById("pages");
  const statusNode = document.getElementById("status");
  const notifications = document.getElementById("notifications");
  const announcer = document.getElementById("announcer");
  const pages = new Map();
  // A launch URL may name one page (?page=address); that window shows only
  // that page. Without it the window shows every page the server has.
  const onlyPage = new URLSearchParams(window.location.search).get("page");
  let socket;
  // The last event sent, so a stale-generation refusal can replay it, and
  // the set of events already replayed once so a retry cannot loop.
  let pendingEvent = null;
  const retriedEvents = new Set();
  // 2.7: where the pointer last went down, for menus opened by the owner.
  const lastPointer = { x: 40, y: 40 };
  document.addEventListener("mousedown", (event) => {
    lastPointer.x = event.clientX;
    lastPointer.y = event.clientY;
  }, true);
  let reconnectDelay = 250;

  function windowGeometry() {
    return JSON.stringify({
      width: window.outerWidth,
      height: window.outerHeight,
      position: [window.screenX, window.screenY]
    });
  }

  function trackWindowGeometry(page, component) {
    if (page.geometryTimer) window.clearInterval(page.geometryTimer);
    let previous = windowGeometry();
    page.geometryTimer = window.setInterval(() => {
      const current = windowGeometry();
      if (current === previous) return;

      previous = current;
      emit(page, component, "change", { value: current });
    }, 500);
  }

  function node(tag, className, text) {
    const result = document.createElement(tag);
    if (className) result.className = className;
    if (text !== undefined) result.textContent = String(text);
    return result;
  }

  function common(element, component) {
    const props = component.props || {};
    element.dataset.cid = component.cid;
    element.dataset.componentType = component.type;
    element.hidden = props.hidden === true;
    if ("disabled" in element) element.disabled = props.disabled === true;
    if (props.tooltip) element.title = props.tooltip;
    if (props.a11y_label) element.setAttribute("aria-label", props.a11y_label);
    if (props.a11y_description) element.setAttribute("aria-description", props.a11y_description);
    if (props.a11y_role) element.setAttribute("role", props.a11y_role);
    ["align", "emphasis", "tone"].forEach((name) => {
      if (props[name]) element.classList.add(`${name}-${props[name]}`);
    });
    // 2.11: one number for all four sides, or only the sides that differ.
    if (Number.isFinite(props.margin)) element.style.margin = `${props.margin}px`;
    else if (props.margin && typeof props.margin === "object") {
      const side = (name) => (Number.isFinite(props.margin[name]) ? `${props.margin[name]}px` : "0");
      element.style.margin = `${side("top")} ${side("right")} ${side("bottom")} ${side("left")}`;
    }
    if (Number.isFinite(props.width) && props.width >= 0) element.style.width = `${props.width}px`;
    if (Number.isFinite(props.height) && props.height >= 0) element.style.height = `${props.height}px`;
    return element;
  }

  function bound(page, cid, event) {
    return (page.bindings[cid] || []).includes(event);
  }

  function controlValue(control) {
    if (!control) return null;
    if (control.type === "checkbox") return control.checked;
    if (control.type === "number" || control.type === "range") return control.valueAsNumber;
    return control.value;
  }

  function findComponent(node, cid) {
    if (!node) return null;
    if (node.cid === cid) return node;
    for (const child of node.children || []) {
      const found = findComponent(child, cid);
      if (found) return found;
    }
    return null;
  }

  // Events the viewer did not ask for. They report the state of the layout
  // rather than an intent, so a stale one is worth dropping rather than
  // replaying, and it must not take the retry slot from a real gesture.
  const UNSOLICITED = new Set(["scrolled"]);

  function emit(page, component, event, payload = {}) {
    if (!socket || socket.readyState !== WebSocket.OPEN || !bound(page, component.cid, event)) return;
    const message = {
      type: "event", page: page.address, cid: component.cid, event,
      generation: page.generation, payload
    };
    const scope = page.submissions[component.cid];
    if (scope) message.submission = scope.map((cid) => controlValue(page.controls.get(cid)));
    // A render landing between the click and this send makes the generation
    // stale, and the server refuses the event. It replies with the current
    // render, so the click is recoverable: remember it and replay once.
    //
    // Only one event is remembered, so an unsolicited report must not
    // overwrite a click that is still in flight -- doing so lost the click's
    // retry and showed the viewer a refusal for a message they never sent.
    if (!UNSOLICITED.has(event)) {
      pendingEvent = { address: page.address, cid: component.cid, event, payload };
    }
    socket.send(JSON.stringify(message));
  }

  // 2.14: a page-level lifecycle event (key) the browser originates. It is
  // not in page.bindings -- lifecycle bindings are not serialized per cid --
  // so it bypasses emit()'s bound() gate. It carries no submission scope and
  // does not take the retry slot: a key is transient, and replaying a stale
  // one after a re-render would double-fire, so a key lost to a rare stale
  // race is dropped rather than replayed.
  function emitLifecycle(page, component, event, payload = {}) {
    if (!socket || socket.readyState !== WebSocket.OPEN) return;
    socket.send(JSON.stringify({
      type: "event", page: page.address, cid: component.cid, event,
      generation: page.generation, payload
    }));
  }

  // A browser KeyboardEvent to the GTK keyval name a script compares against
  // (the KEY_ constant suffix). Arrow keys and a handful of named keys have
  // GTK spellings that differ from KeyboardEvent.key; a single printable
  // character passes through as itself (so "s" and "S" are distinct here but
  // collapse on the shim side, as they do through Gdk.const_missing). Anything
  // else is dropped.
  const KEYVAL_NAMES = {
    ArrowLeft: "Left", ArrowRight: "Right", ArrowUp: "Up", ArrowDown: "Down",
    Enter: "Return", Escape: "Escape", " ": "space", Tab: "Tab",
    Backspace: "BackSpace", Delete: "Delete", Home: "Home", End: "End",
    PageUp: "Page_Up", PageDown: "Page_Down",
  };
  function keyvalName(event) {
    if (KEYVAL_NAMES[event.key]) return KEYVAL_NAMES[event.key];
    if (event.key.length === 1) return event.key;
    if (/^F([1-9]|1[0-2])$/.test(event.key)) return event.key;
    return null;
  }

  function appendChildren(page, component, parent) {
    (component.children || []).forEach((child) => parent.append(render(page, child)));
    return parent;
  }

  function field(page, component, control, inline = false) {
    const wrapper = common(node("label", `field${inline ? " inline" : ""}`), component);
    if (component.props.label) wrapper.append(node("span", "field-label", component.props.label));
    wrapper.append(control);
    page.controls.set(component.cid, control);
    return wrapper;
  }

  function input(page, component, type) {
    const control = node("input");
    control.type = type;
    control.disabled = component.props.disabled === true;
    if (component.props.placeholder) control.placeholder = component.props.placeholder;
    if (component.props.max_length) control.maxLength = component.props.max_length;
    page.controls.set(component.cid, control);
    return control;
  }

  const renderers = {
    page(page, component) {
      const root = common(node("section", "webui-page"), component);
      document.title = component.props.title;
      if (component.props.bare) root.classList.add("bare");
      else root.append(node("h1", null, component.props.title));
      // 2.14: a window that connected key-press-event receives keys here. The
      // listener is on the page root, not the document, so it only fires when
      // this window has focus -- tabIndex makes the section focusable so keys
      // land even before the viewer clicks a control. A key aimed at a focused
      // control (an entry) is left to that control. A page key is a lifecycle
      // event and is not in page.bindings, so it is sent directly rather than
      // through emit()'s bound() gate.
      if (component.props.key_events) {
        root.tabIndex = -1;
        root.addEventListener("keydown", (event) => {
          if (event.isComposing || event.repeat) return;
          const activeCid = event.target.closest?.("[data-cid]")?.dataset.cid;
          if (activeCid && activeCid !== component.cid) return;
          const keyval = keyvalName(event);
          if (!keyval) return;
          const modifiers = [];
          if (event.ctrlKey) modifiers.push("ctrl");
          if (event.shiftKey) modifiers.push("shift");
          if (event.altKey) modifiers.push("alt");
          event.preventDefault();
          event.stopPropagation();
          emitLifecycle(page, component, "key", { keyval, modifiers });
        });
      }
      return appendChildren(page, component, root);
    },
    group(page, component) {
      const group = common(node("fieldset", "webui-group"), component);
      group.append(node("legend", null, component.props.label));
      return appendChildren(page, component, group);
    },
    stack(page, component) {
      const stack = common(node("div", "webui-stack"), component);
      stack.style.gap = `${component.props.gap ?? 8}px`;
      (component.children || []).forEach((child) => {
        const element = render(page, child);
        const placement = child.placement || {};
        if (placement.grow > 0) {
          element.style.flexGrow = String(placement.grow);
          // A flex item will not shrink below its content without this.
          element.style.minHeight = "0";
        }
        if (placement.pad > 0) element.style.padding = `${placement.pad}px 0`;
        stack.append(element);
      });
      return stack;
    },
    grid(page, component) {
      const grid = common(node("div", "webui-grid"), component);
      // Weights name each column's share of the leftover width, as on
      // `columns`; weight 0 is natural width, and `0fr` would collapse the
      // track. Without weights every column shares equally, which is the
      // GTK default for a table nothing asked to expand.
      const weights = component.props.weights;
      if (Array.isArray(weights) && weights.length) {
        grid.style.gridTemplateColumns = weights.map((weight) => (weight > 0 ? `${weight}fr` : "auto")).join(" ");
        // A weight above zero claims the leftover width, so the grid should
        // fill its container; without one it hugs its content, as GTK does.
        if (weights.some((weight) => weight > 0)) grid.dataset.weighted = "";
      } else {
        grid.style.gridTemplateColumns = `repeat(${component.props.cols}, auto)`;
      }
      grid.style.gap = `${component.props.gap ?? 8}px`;
      (component.children || []).forEach((child) => {
        const element = render(page, child);
        const placement = child.placement || {};
        if (Number.isInteger(placement.span)) element.style.gridColumn = `span ${placement.span}`;
        if (Number.isInteger(placement.row_span)) element.style.gridRow = `span ${placement.row_span}`;
        grid.append(element);
      });
      return grid;
    },
    scroll(page, component) {
      const scroll = common(node("div", "webui-scroll"), component);
      if (Number.isFinite(component.props.max_height)) scroll.style.maxHeight = `${component.props.max_height}px`;
      // The script reads back upper/page_size to work out where the bottom
      // is, so report the extent as well as the offset.
      scroll.addEventListener("scroll", () => {
        // Remembered so the next rebuild can put the viewer back; see the
        // restore below.
        (page.scrollOffsets ||= new Map()).set(component.cid, {
          x: Math.round(scroll.scrollLeft), y: Math.round(scroll.scrollTop),
        });
        emit(page, component, "scrolled", {
          position: Math.round(scroll.scrollTop),
          upper: Math.round(scroll.scrollHeight),
          page_size: Math.round(scroll.clientHeight),
          // 2.13: the horizontal axis. A script panning or centring a wide
          // canvas reads both, and without these the horizontal half was a
          // constructor default.
          position_x: Math.round(scroll.scrollLeft),
          upper_x: Math.round(scroll.scrollWidth),
          page_size_x: Math.round(scroll.clientWidth),
        });
      }, { passive: true });
      // Report the extent once after layout, without waiting for the viewer
      // to scroll. A script that centres the viewport computes against
      // page_size, and until something reported one it was computing against
      // a constructor default -- map centred on a point 800px from where the
      // room actually was.
      //
      // Only when it actually changed. The tree is rebuilt on every commit,
      // so reporting unconditionally sent one of these after every render --
      // and a render landing in that gap made it stale, which surfaced as a
      // refusal the viewer could see. The extent is a property of the
      // layout, not of the render, so re-sending an unchanged one says
      // nothing.
      requestAnimationFrame(() => {
        if (!scroll.isConnected) return;
        const extent = `${scroll.scrollHeight}x${scroll.clientHeight}x${scroll.scrollWidth}x${scroll.clientWidth}`;
        if (page.scrollExtents?.get(component.cid) === extent) return;
        (page.scrollExtents ||= new Map()).set(component.cid, extent);
        emit(page, component, "scrolled", {
          position: Math.round(scroll.scrollTop),
          upper: Math.round(scroll.scrollHeight),
          page_size: Math.round(scroll.clientHeight),
          // 2.13: the horizontal axis. A script panning or centring a wide
          // canvas reads both, and without these the horizontal half was a
          // constructor default.
          position_x: Math.round(scroll.scrollLeft),
          upper_x: Math.round(scroll.scrollWidth),
          page_size_x: Math.round(scroll.clientWidth),
        });
      });
      // The tree is rebuilt on every commit, so a fresh element starts at the
      // top; the position can only be set once it is in the document and has
      // been laid out.
      // The tree is rebuilt on every commit, so a fresh element starts at the
      // top. An explicit position from the script wins; otherwise put the
      // viewer back where they were, because a commit they did not cause --
      // a right-click opening a menu, a marker moving -- would otherwise
      // throw their scroll position away and snap the map to the corner.
      const position = component.props.scroll_position;
      const remembered = page.scrollOffsets?.get(component.cid);
      if (position) page.pendingScrolls.push([scroll, position]);
      else if (remembered) page.pendingScrolls.push([scroll, remembered]);
      return appendChildren(page, component, scroll);
    },
    expander(page, component) {
      const details = common(node("details", "webui-expander"), component);
      details.open = component.props.open === true;
      details.append(node("summary", null, component.props.label));
      details.addEventListener("toggle", () => emit(page, component, "toggle", { open: details.open }));
      return appendChildren(page, component, details);
    },
    textarea(page, component) {
      const control = node("textarea");
      control.rows = component.props.rows ?? 5;
      control.disabled = component.props.disabled === true;
      if (component.props.max_length) control.maxLength = component.props.max_length;
      control.value = component.props.value;
      control.addEventListener("change", () => emit(page, component, "change", { value: control.value }));
      control.addEventListener("focus", () => emit(page, component, "focus"));
      control.addEventListener("blur", () => emit(page, component, "blur"));
      return field(page, component, control);
    },
    number_input(page, component) {
      const control = input(page, component, "number");
      control.min = component.props.min;
      control.max = component.props.max;
      control.step = component.props.step ?? 1;
      control.value = component.props.value;
      control.addEventListener("change", () => {
        if (Number.isFinite(control.valueAsNumber)) emit(page, component, "change", { value: control.valueAsNumber });
      });
      return field(page, component, control);
    },
    columns(page, component) {
      const columns = common(node("div", "webui-columns"), component);
      const weights = component.props.weights || Array(component.props.count).fill(1);
      if (weights.some((weight) => weight > 0)) columns.dataset.weighted = "";
      // Weight 0 is "natural width", which is `auto`; `0fr` would collapse
      // the track to nothing.
      columns.style.gridTemplateColumns = weights.map((weight) => (weight > 0 ? `${weight}fr` : "auto")).join(" ");
      columns.style.gap = `${component.props.gap ?? 8}px`;
      (component.children || []).forEach((child) => {
        const childNode = render(page, child);
        childNode.style.gridColumn = String(Number(child.slot) + 1);
        const pad = (child.placement || {}).pad;
        if (pad > 0) childNode.style.padding = `0 ${pad}px`;
        columns.append(childNode);
      });
      return columns;
    },
    tabs(page, component) {
      const tabs = common(node("div", "webui-tabs"), component);
      if (component.cid.includes("saved-account-tabs")) tabs.classList.add("account-tabs-left");
      else if (component.cid.includes("account")) tabs.classList.add("nested");
      const list = node("div", "tab-list");
      list.setAttribute("role", "tablist");
      const selected = component.props.selected ?? 0;
      component.props.names.forEach((name, index) => {
        const button = node("button", null, name);
        button.type = "button";
        button.setAttribute("role", "tab");
        button.setAttribute("aria-selected", String(index === selected));
        button.addEventListener("click", () => emit(page, component, "select", { index }));
        list.append(button);
      });
      tabs.append(list);
      (component.children || []).forEach((child, index) => {
        const panel = render(page, child);
        panel.classList.add("tab-panel");
        panel.setAttribute("role", "tabpanel");
        panel.hidden = index !== selected;
        tabs.append(panel);
      });
      return tabs;
    },
    // Two panes along an axis with a divider the viewer drags. The shim
    // sends the panes in slot order; the slot is honored when present so a
    // lone second pane still lands on the right.
    split(page, component) {
      const split = common(node("div", "webui-split"), component);
      const vertical = component.props.orientation === "vertical";
      split.classList.add(vertical ? "vertical" : "horizontal");
      const first = node("div", "split-pane first");
      const second = node("div", "split-pane second");
      let position = Number.isFinite(component.props.position) ? component.props.position : 50;
      first.style.flex = `0 0 ${position}%`;
      (component.children || []).forEach((child, index) => {
        const pane = child.slot === "second" || (child.slot !== "first" && index > 0) ? second : first;
        pane.append(render(page, child));
      });
      const handle = node("div", "split-handle");
      handle.setAttribute("role", "separator");
      handle.setAttribute("aria-orientation", vertical ? "horizontal" : "vertical");
      // Pointer capture keeps the gesture on the handle, so nothing is left
      // listening on the document after the tree is rebuilt.
      handle.addEventListener("pointerdown", (event) => {
        handle.setPointerCapture(event.pointerId);
        event.preventDefault();
      });
      handle.addEventListener("pointermove", (event) => {
        if (!handle.hasPointerCapture(event.pointerId)) return;
        const rect = split.getBoundingClientRect();
        const along = vertical ? (event.clientY - rect.top) / rect.height : (event.clientX - rect.left) / rect.width;
        position = Math.max(0, Math.min(100, Math.round(along * 100)));
        first.style.flex = `0 0 ${position}%`;
      });
      handle.addEventListener("pointerup", (event) => {
        if (!handle.hasPointerCapture(event.pointerId)) return;
        handle.releasePointerCapture(event.pointerId);
        emit(page, component, "move", { position });
      });
      split.append(first, handle, second);
      return split;
    },
    // The first child is the base, in flow; every later child is stacked
    // over it in document order, which is GTK's own stacking when no z is
    // set.
    overlay(page, component) {
      const overlay = common(node("div", "webui-overlay"), component);
      (component.children || []).forEach((child, index) => {
        const element = render(page, child);
        if (index > 0) element.classList.add("overlay-layer");
        overlay.append(element);
      });
      return overlay;
    },
    divider(_page, component) { return common(node("div", "webui-divider", component.props.label || ""), component); },
    image(_page, component) {
      const image = common(node("img", "webui-image"), component);
      // src is a server-issued path; never a scheme the page could be
      // tricked into following.
      image.src = component.props.src || "";
      image.alt = component.props.alt || "";
      const scale = component.props.scale;
      if (Number.isFinite(scale) && scale !== 1) {
        image.style.transformOrigin = "top left";
        image.style.transform = `scale(${scale})`;
      }
      return image;
    },
    // A composite is a stack of absolutely-placed layers over a fixed box:
    // a map image, markers on top of it, and clickable regions.
    composite(page, component) {
      const surface = common(node("div", "webui-composite"), component);
      surface.style.width = `${component.props.width}px`;
      surface.style.height = `${component.props.height}px`;
      const scale = component.props.scale;
      if (Number.isFinite(scale) && scale !== 1) {
        surface.style.transformOrigin = "top left";
        surface.style.transform = `scale(${scale})`;
      }
      (component.props.layers || []).forEach((layer) => {
        const element = compositeLayer(page, component, layer);
        if (!element) return;
        element.classList.add("composite-layer");
        element.style.left = `${layer.x ?? layer.x1 ?? 0}px`;
        element.style.top = `${layer.y ?? layer.y1 ?? 0}px`;
        surface.append(element);
      });
      // A click anywhere on the surface, in the surface's own pixels, which
      // is the coordinate space a script placed its layers in. Only sent
      // when the owner asked for it.
      if (component.props.surface_events) {
        // Left-press and drag pans, the way the GTK map does. A GTK script
        // drives that from motion-notify-event, which the contract has no
        // equivalent for -- and does not need one, because the scroller the
        // surface sits in can pan itself. The script is told nothing about
        // the drag; it only ever hears the click that did not become one.
        let drag = null;
        surface.addEventListener("pointerdown", (event) => {
          if (event.button !== 0 || event.target.closest(".composite-region")) return;
          const scroller = surface.closest(".webui-scroll");
          if (!scroller) return;
          drag = {
            id: event.pointerId, moved: false,
            x: event.clientX, y: event.clientY,
            left: scroller.scrollLeft, top: scroller.scrollTop, scroller,
          };
          surface.setPointerCapture(event.pointerId);
        });
        surface.addEventListener("pointermove", (event) => {
          if (!drag || event.pointerId !== drag.id) return;
          const dx = event.clientX - drag.x;
          const dy = event.clientY - drag.y;
          // A few pixels of travel during a click is not a drag; past that it
          // is, and the click that ends it must not also walk the character.
          if (!drag.moved && Math.abs(dx) <= DRAG_THRESHOLD_PX && Math.abs(dy) <= DRAG_THRESHOLD_PX) return;
          drag.moved = true;
          drag.scroller.scrollLeft = drag.left - dx;
          drag.scroller.scrollTop = drag.top - dy;
        });
        const endDrag = (event) => {
          if (!drag || event.pointerId !== drag.id) return;
          const moved = drag.moved;
          drag = null;
          if (surface.hasPointerCapture(event.pointerId)) surface.releasePointerCapture(event.pointerId);
          // Suppress the click this release is about to produce.
          if (moved) surface.dataset.dragged = "true";
        };
        surface.addEventListener("pointerup", endDrag);
        surface.addEventListener("pointercancel", endDrag);
        surface.addEventListener("click", (event) => {
          if (surface.dataset.dragged === "true") {
            delete surface.dataset.dragged;
            return;
          }
          if (event.target.closest(".composite-region")) return;
          emit(page, component, "surface_activate", surfacePayload(event, surface, "primary"));
        });
        surface.addEventListener("contextmenu", (event) => {
          event.preventDefault();
          emit(page, component, "surface_activate", surfacePayload(event, surface, "secondary"));
        });
      }
      return surface;
    },
    text(_page, component) {
      const text = common(node("div", "webui-text"), component);
      if (component.props.wrap === false) text.classList.add("nowrap");
      if (component.props.markup) renderMarkup(component.props.markup, component.props.content, text);
      else text.textContent = component.props.content;
      return text;
    },
    menu(page, component) {
      if (component.props.bar) {
        const bar = common(node("div", "webui-menubar"), component);
        bar.setAttribute("role", "menubar");
        (component.children || []).forEach((item) => {
          if (item.props.kind === "separator") return;
          const button = node("button", "webui-menubar-item", item.props.label);
          button.type = "button";
          button.disabled = item.props.disabled === true;
          button.hidden = item.props.hidden === true;
          const submenu = (item.children || []).find((child) => child.type === "menu");
          button.addEventListener("click", () => {
            if (submenu) {
              const rect = button.getBoundingClientRect();
              openMenu(page, submenu, rect.left, rect.bottom, component);
            } else {
              emit(page, item, "activate");
            }
          });
          bar.append(button);
        });
        return bar;
      }
      const holder = common(node("div", "webui-menu-holder"), component);
      holder.hidden = true;
      if (component.props.open) {
        queueMicrotask(() => {
          if (!holder.isConnected) return;
          const same = menuState.root && menuState.root.component.cid === component.cid;
          const at = same ? menuState.at : { x: lastPointer.x, y: lastPointer.y };
          openMenu(page, component, at.x, at.y, component);
        });
      }
      return holder;
    },
    menu_item(_page, component) {
      // Items only ever render inside their menu's popup or bar.
      const placeholder = common(node("span", "webui-menu-item-holder"), component);
      placeholder.hidden = true;
      return placeholder;
    },
    progress(_page, component) {
      const wrapper = common(node("label", "webui-progress"), component);
      if (component.props.label) wrapper.append(node("span", null, component.props.label));
      const progress = node("progress");
      progress.max = 1;
      if (!component.props.indeterminate) progress.value = component.props.value;
      wrapper.append(progress);
      return wrapper;
    },
    button(page, component) {
      const button = common(node("button", component.props.variant || "default"), component);
      if (component.cid.includes("button:play-entry-") && component.props.label.includes("  |  ")) {
        button.classList.add("entry-launch");
        component.props.label.split("  |  ").forEach((part) => {
          button.append(node("span", "entry-launch-part", part));
        });
      } else if (component.cid.includes("button:favorite-entry-")) {
        button.textContent = component.props.label === "filled_star" ? "\u2605" : "\u2606";
        button.dataset.favoriteState = component.props.label;
      } else {
        button.textContent = component.props.label;
      }
      button.type = "button";
      button.addEventListener("click", () => {
        if (!component.props.confirm || window.confirm(component.props.confirm)) emit(page, component, "activate");
      });
      return button;
    },
    checkbox(page, component) {
      const control = input(page, component, "checkbox");
      control.checked = component.props.checked;
      control.addEventListener("change", () => emit(page, component, "change", { value: control.checked }));
      return field(page, component, control, true);
    },
    toggle(page, component) { return renderers.checkbox(page, component); },
    radio(page, component) {
      const wrapper = common(node("fieldset", "field"), component);
      wrapper.append(node("legend", null, component.props.label));
      const options = node("div", "radio-options");
      let selectedControl;
      component.props.options.forEach((option) => {
        const label = node("label", "field inline");
        const control = node("input");
        control.type = "radio";
        control.disabled = component.props.disabled === true;
        control.name = `${page.address}:${component.props.group}`;
        control.value = option.value;
        control.checked = option.value === component.props.selected;
        control.addEventListener("change", () => {
          if (control.checked) {
            page.controls.set(component.cid, control);
            emit(page, component, "change", { value: control.value });
          }
        });
        if (control.checked) selectedControl = control;
        label.append(control, node("span", null, option.label));
        options.append(label);
      });
      if (selectedControl) page.controls.set(component.cid, selectedControl);
      wrapper.append(options);
      return wrapper;
    },
    text_input(page, component) {
      const control = input(page, component, component.props.search ? "search" : "text");
      control.value = component.props.value;
      control.addEventListener("change", () => emit(page, component, "change", { value: control.value }));
      control.addEventListener("focus", () => emit(page, component, "focus"));
      control.addEventListener("blur", () => emit(page, component, "blur"));
      control.addEventListener("keydown", (event) => {
        if (event.key === "Enter") emit(page, component, "submit");
      });
      const wrapper = field(page, component, control);
      if (component.cid.includes("text_input:window-geometry")) trackWindowGeometry(page, component);
      return wrapper;
    },
    password_input(page, component) {
      const control = input(page, component, "password");
      const wrapper = field(page, component, control);
      control.addEventListener("keydown", (event) => {
        if (event.key === "Enter") emit(page, component, "submit");
      });
      if (component.props.revealable) {
        const reveal = node("button", null, "Show");
        reveal.type = "button";
        reveal.addEventListener("click", () => {
          control.type = control.type === "password" ? "text" : "password";
          reveal.textContent = control.type === "password" ? "Show" : "Hide";
        });
        wrapper.append(reveal);
      }
      return wrapper;
    },
    select(page, component) {
      const control = node("select");
      component.props.options.forEach((option) => {
        const choice = node("option", null, option.label);
        choice.value = option.value;
        choice.selected = option.value === component.props.value;
        control.append(choice);
      });
      control.addEventListener("change", () => emit(page, component, "change", { value: control.value }));
      return field(page, component, control);
    },
    table(page, component) {
      const wrapper = common(node("div", "webui-table-wrap"), component);
      const table = node("table", "webui-table");
      // A tree view used as a plain list names its columns for the model
      // and never shows them; the label is internal, not a heading.
      if (component.props.headers !== false) {
        const header = node("tr");
        component.props.columns.forEach((column) => header.append(node("th", null, column.label)));
        const head = node("thead");
        head.append(header);
        table.append(head);
      }
      const body = node("tbody");
      component.props.rows.forEach((row) => {
        const tr = node("tr");
        tr.dataset.rowKey = row.key;
        tr.setAttribute("aria-selected", String((component.props.selected || []).includes(row.key)));
        tr.addEventListener("click", () => {
          if (component.props.selection !== "none") emit(page, component, "selection_change", { rows: [row.key] });
        });
        component.props.columns.forEach((column) => tr.append(node("td", null, row.cells[column.key])));
        body.append(tr);
      });
      table.append(body);
      wrapper.append(table);
      return wrapper;
    },
    dialog(page, component) {
      const dialog = common(node("dialog", "webui-dialog"), component);
      dialog.append(node("h2", null, component.props.title));
      if (component.props.body) dialog.append(node("p", null, component.props.body));
      appendChildren(page, component, dialog);
      const actions = node("div", "dialog-actions");
      component.props.buttons.forEach((definition) => {
        const button = node("button", definition.variant || "default", definition.label);
        button.addEventListener("click", () => emit(page, component, "response", { button: definition.id }));
        actions.append(button);
      });
      dialog.append(actions);
      queueMicrotask(() => { if (dialog.isConnected && !dialog.open) dialog.showModal(); });
      return dialog;
    }
  };

  // One layer of a composite. Built with createElement like everything else
  // here -- a layer is validated data, not markup.
  function compositeLayer(page, component, layer) {
    if (layer.kind === "image") {
      const image = node("img");
      image.src = layer.src || "";
      image.alt = "";
      if (Number.isFinite(layer.w)) image.style.width = `${layer.w}px`;
      if (Number.isFinite(layer.h)) image.style.height = `${layer.h}px`;
      if (Number.isFinite(layer.opacity) && layer.opacity !== 1) image.style.opacity = String(layer.opacity);
      if (layer.tint) image.style.filter = `drop-shadow(0 0 0 ${cssColor(layer.tint)})`;
      return image;
    }
    if (layer.kind === "label") {
      const label = node("div", `composite-label align-${layer.align || "start"}`, layer.text);
      if (layer.emphasis) label.classList.add(`emphasis-${layer.emphasis}`);
      if (layer.tone) label.classList.add(`tone-${layer.tone}`);
      return label;
    }
    if (layer.kind === "bar") {
      const track = node("div", "composite-bar");
      track.style.width = `${layer.w}px`;
      track.style.height = `${layer.h}px`;
      const fill = node("div", "composite-bar-fill");
      const vertical = layer.orientation === "vertical";
      const portion = `${Math.max(0, Math.min(1, layer.value)) * 100}%`;
      fill.style.width = vertical ? "100%" : portion;
      fill.style.height = vertical ? portion : "100%";
      if (typeof layer.tone === "string") fill.classList.add(`tone-${layer.tone}`);
      else if (layer.tone) fill.style.background = cssColor(layer.tone);
      track.append(fill);
      return track;
    }
    if (layer.kind === "region") {
      // A region is a hit area, not something drawn.
      const region = node(layer.activates ? "button" : "div", "composite-region");
      region.style.width = `${Math.abs(layer.x2 - layer.x1)}px`;
      region.style.height = `${Math.abs(layer.y2 - layer.y1)}px`;
      if (layer.label) region.title = layer.label;
      if (layer.activates) {
        region.type = "button";
        region.setAttribute("aria-label", layer.label || layer.key);
        region.addEventListener("click", () => emit(page, component, "region_activate", { region: layer.key }));
      }
      return region;
    }
    return null;
  }

  // Position in the composite's own pixels, undoing any scale it carries,
  // so a script gets back the coordinates it drew in.
  function surfacePayload(event, surface, button) {
    const rect = surface.getBoundingClientRect();
    const scale = rect.width && surface.offsetWidth ? rect.width / surface.offsetWidth : 1;
    const s = scale || 1;
    const modifiers = [];
    if (event.ctrlKey) modifiers.push("ctrl");
    if (event.shiftKey) modifiers.push("shift");
    if (event.altKey) modifiers.push("alt");
    // The pixel under the cursor in the surface's own coordinates.
    const absX = Math.round((event.clientX - rect.left) / s);
    const absY = Math.round((event.clientY - rect.top) / s);
    // 2.15: split that into the two pieces a GTK script recombines. A real
    // Gtk::Layout's bin-window pointer is relative to the VISIBLE viewport,
    // and the script adds the scroll offset back to reach layout coordinates:
    //   click = (adjustment.value + pointer - offset) / scale
    // Sending the absolute pixel as `pointer` while the adjustment still read
    // its stale default counted the scroll twice -- which is why a click
    // found the right room only while the map sat at the origin.
    const scroller = surface.closest(".webui-scroll");
    const sx = scroller ? clampGeometry(Math.round(scroller.scrollLeft / s)) : 0;
    const sy = scroller ? clampGeometry(Math.round(scroller.scrollTop / s)) : 0;
    const payload = { x: absX - sx, y: absY - sy, button, modifiers };
    if (scroller) {
      payload.scroll_x = sx;
      payload.scroll_y = sy;
    }
    return payload;
  }

  // Travel past which a press-and-move is a pan rather than a click.
  const DRAG_THRESHOLD_PX = 4;

  // The contract bounds geometry at +/-65536; a 2x canvas can scroll past it.
  function clampGeometry(value) {
    return Math.min(Math.max(value, 0), 65535);
  }

  function cssColor(tint) {
    if (typeof tint === "string") return tint;
    if (!tint) return "transparent";
    const alpha = Number.isFinite(tint.a) ? tint.a : 1;
    return `rgb(${tint.r ?? 0} ${tint.g ?? 0} ${tint.b ?? 0} / ${alpha})`;
  }

  function render(page, component) {
    const renderer = renderers[component.type];
    if (!renderer) {
      const error = common(node("div", "renderer-error", `Renderer not implemented: ${component.type}`), component);
      error.dataset.error = "renderer_not_implemented";
      return error;
    }
    const element = renderer(page, component);
    wireSurface(page, component, element);
    return element;
  }

  // ---- 2.7: pointer gestures and context menus ----------------------------

  function pointerPayload(event, element) {
    const rect = element.getBoundingClientRect();
    const button = event.button === 2 ? "secondary" : event.button === 1 ? "middle" : "primary";
    const modifiers = [];
    if (event.ctrlKey) modifiers.push("ctrl");
    if (event.shiftKey) modifiers.push("shift");
    if (event.altKey) modifiers.push("alt");
    return {
      button, modifiers,
      x: Math.round(event.clientX - rect.left), y: Math.round(event.clientY - rect.top)
    };
  }

  function wireSurface(page, component, element) {
    const press = bound(page, component.cid, "press");
    const release = bound(page, component.cid, "release");
    const menuKey = component.props?.context_menu;
    if (!press && !release && !menuKey) return;
    // The innermost wired surface takes the gesture, as a GTK handler that
    // returns true stops propagation.
    element.addEventListener("contextmenu", (event) => {
      event.preventDefault();
      event.stopPropagation();
      if (menuKey) {
        const menu = findByKey(page, menuKey);
        if (menu) openMenu(page, menu, event.clientX, event.clientY, menu);
      }
    });
    if (press) element.addEventListener("mousedown", (event) => {
      event.stopPropagation();
      emit(page, component, "press", pointerPayload(event, element));
    });
    if (release) element.addEventListener("mouseup", (event) => {
      event.stopPropagation();
      emit(page, component, "release", pointerPayload(event, element));
    });
  }

  function findByKey(page, key) {
    const visit = (component) => {
      if (component.props?.key === key) return component;
      for (const child of component.children || []) {
        const found = visit(child);
        if (found) return found;
      }
      return null;
    };
    return page.tree ? visit(page.tree) : null;
  }

  // ---- 2.7: popup menus ----------------------------------------------------

  const menuState = { layers: [], root: null, at: null };
  // How long the pointer must rest on a parent item before its submenu opens.
  const SUBMENU_DWELL_MS = 300;
  // Longer than opening: the pointer crosses the parent on its way into the
  // child, and closing the instant it leaves would shut what it is reaching for.
  const SUBMENU_CLOSE_MS = 450;

  function closeMenuLayers(fromLevel) {
    while (menuState.layers.length > fromLevel) menuState.layers.pop().remove();
  }

  // Whether the pointer is resting in any menu layer deeper than +level+.
  // Tracked rather than hit-tested because a timer fires long after the
  // mousemove that carried the pointer there.
  function pointerInMenuBelow(level) {
    return menuState.layers.some((layer, index) => index > level && layer.dataset.pointerInside === "true");
  }

  // Dismisses every open menu. Tells the owner when the viewer did it.
  function closeMenus(notify = true) {
    closeMenuLayers(0);
    const root = menuState.root;
    menuState.root = null;
    menuState.at = null;
    if (notify && root && root.owner.type === "menu" && !root.owner.props.bar) emit(root.page, root.owner, "close");
  }

  function openMenu(page, menu, x, y, owner) {
    closeMenus(false);
    menuState.root = { page, component: menu, owner: owner || menu };
    menuState.at = { x, y };
    placeMenuLayer(page, menu, 0, x, y);
  }

  function placeMenuLayer(page, menu, level, x, y, owner = null) {
    closeMenuLayers(level);
    const layer = node("div", "webui-menu-popup");
    layer.dataset.level = String(level);
    // The pointer travelling from the parent item into the submenu leaves the
    // parent, which has just scheduled this layer's own closing. Arriving here
    // calls that off; leaving again starts it over.
    layer.addEventListener("mouseenter", () => { layer.dataset.pointerInside = "true"; });
    layer.addEventListener("mouseleave", () => { layer.dataset.pointerInside = "false"; });
    if (owner && owner.__cancelSubmenuClose) {
      layer.addEventListener("mouseenter", () => owner.__cancelSubmenuClose());
      layer.addEventListener("mouseleave", () => owner.__scheduleSubmenuClose?.());
    }
    layer.append(menuList(page, menu, level));
    document.body.append(layer);
    const rect = layer.getBoundingClientRect();
    const left = Math.max(0, Math.min(x, window.innerWidth - rect.width - 4));
    const top = Math.max(0, Math.min(y, window.innerHeight - rect.height - 4));
    layer.style.left = `${left}px`;
    layer.style.top = `${top}px`;
    menuState.layers.push(layer);
    layer.querySelector("button:not([disabled])")?.focus();
    return layer;
  }

  function menuList(page, menu, level) {
    const list = node("div", "webui-menu-list");
    list.setAttribute("role", "menu");
    (menu.children || []).forEach((item) => list.append(menuItem(page, item, level)));
    list.addEventListener("keydown", (event) => {
      const items = [...list.querySelectorAll("button:not([disabled]):not([hidden])")];
      const index = items.indexOf(document.activeElement);
      if (event.key === "ArrowDown") { event.preventDefault(); items[(index + 1) % items.length]?.focus(); }
      else if (event.key === "ArrowUp") { event.preventDefault(); items[(index - 1 + items.length) % items.length]?.focus(); }
      else if (event.key === "ArrowLeft" && level > 0) { event.preventDefault(); closeMenuLayers(level); menuState.layers[level - 1]?.querySelector("button")?.focus(); }
    });
    return list;
  }

  function menuItem(page, item, level) {
    const props = item.props;
    if (props.kind === "separator") return node("hr", "webui-menu-separator");
    const button = node("button", "webui-menu-item");
    button.type = "button";
    const role = props.kind === "check" ? "menuitemcheckbox" : props.kind === "radio" ? "menuitemradio" : "menuitem";
    button.setAttribute("role", role);
    if (props.kind === "check" || props.kind === "radio") button.setAttribute("aria-checked", String(props.active === true));
    button.disabled = props.disabled === true;
    button.hidden = props.hidden === true;
    if (props.tooltip) button.title = props.tooltip;
    const mark = props.kind === "check" && props.active ? "\u2713" : props.kind === "radio" && props.active ? "\u25CF" : "";
    button.append(node("span", "menu-mark", mark), node("span", "menu-label", props.label));
    const submenu = (item.children || []).find((child) => child.type === "menu");
    if (submenu) {
      button.append(node("span", "menu-arrow", "\u25B8"));
      const open = () => {
        const rect = button.getBoundingClientRect();
        placeMenuLayer(page, submenu, level + 1, rect.right, rect.top, button);
      };
      // A submenu that opens the instant the pointer crosses it fires while
      // the viewer is only travelling down the parent menu to something else,
      // so every pass flashes a child open. Wait for the pointer to settle;
      // a click still opens it at once.
      let dwell = null;
      const cancelDwell = () => { if (dwell !== null) { window.clearTimeout(dwell); dwell = null; } };
      // Leaving the parent item closes the submenu again, after a slightly
      // longer wait than opening it: the pointer has to cross the parent on
      // its way into the child, and closing the instant it leaves would shut
      // the menu the viewer is reaching for. Entering the submenu itself
      // cancels the close, and so does coming back to the parent.
      const scheduleClose = () => {
        cancelDwell();
        dwell = window.setTimeout(() => {
          dwell = null;
          // The pointer may have travelled deeper rather than away: leaving
          // this item is also how you reach its submenu, and its submenu's
          // submenu. Closing on that would take the layer the viewer just
          // walked into, and every layer under it, with it.
          if (pointerInMenuBelow(level)) return;

          closeMenuLayers(level + 1);
        }, SUBMENU_CLOSE_MS);
      };
      button.addEventListener("mouseenter", () => {
        cancelDwell();
        dwell = window.setTimeout(() => { dwell = null; open(); }, SUBMENU_DWELL_MS);
      });
      button.addEventListener("mouseleave", scheduleClose);
      // A click is the viewer saying so outright: no wait at all.
      button.addEventListener("click", () => { cancelDwell(); open(); });
      button.addEventListener("keydown", (event) => { if (event.key === "ArrowRight") { event.preventDefault(); cancelDwell(); open(); } });
      // Registered so the submenu this item owns can call off its own closing,
      // and start it again when the pointer leaves the submenu too.
      button.__cancelSubmenuClose = cancelDwell;
      button.__scheduleSubmenuClose = scheduleClose;
    } else {
      button.addEventListener("mouseenter", () => closeMenuLayers(level + 1));
      button.addEventListener("click", () => {
        if (props.kind === "check") {
          // Read the mark that is actually on screen rather than the props of
          // the render this button was built from. A menu is rebuilt in place
          // on every commit, so a second click before the next render arrived
          // was computed from a stale `active` and sent the same value twice
          // -- the toggle appeared not to toggle. Flip the view at once too,
          // so the tick tracks the click even if the render lags.
          const checked = button.getAttribute("aria-checked") === "true";
          const next = !checked;
          button.setAttribute("aria-checked", String(next));
          const mark = button.querySelector(".menu-mark");
          if (mark) mark.textContent = next ? "✓" : "";
          emit(page, item, "change", { value: next });
        } else if (props.kind === "radio") {
          emit(page, item, "change", { value: true });
        }
        emit(page, item, "activate");
        closeMenus();
      });
    }
    return button;
  }

  document.addEventListener("mousedown", (event) => {
    if (menuState.layers.length && !event.target.closest(".webui-menu-popup")) closeMenus();
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && menuState.layers.length) closeMenus();
  });

  // A re-render while a menu is open rebuilds it in place (a check mark
  // toggled by the owner) or takes it down (the owner closed it).
  function refreshMenus(page) {
    const root = menuState.root;
    if (!root || root.page !== page) return;
    const owner = findByKey(page, root.owner.props?.key);
    const menu = root.owner === root.component ? owner : findByKey(page, root.component.props?.key);
    if (!menu || (owner?.type === "menu" && !owner.props.bar && !owner.props.open)) { closeMenus(false); return; }
    const at = menuState.at;
    menuState.root = { page, component: menu, owner: owner || menu };
    placeMenuLayer(page, menu, 0, at.x, at.y);
  }

  // ---- 2.7: Pango markup -----------------------------------------------------

  const MARKUP_ELEMENTS = { b: "b", i: "i", u: "u", s: "s", tt: "code", big: "big", small: "small", span: "span" };
  const MARKUP_WEIGHTS = { ultralight: "200", light: "300", normal: "400", bold: "700", ultrabold: "800", heavy: "900" };

  // Builds nodes from the validated parse; the parsed document itself is
  // never inserted, and every node here comes from createElement.
  function renderMarkup(markup, fallback, target) {
    const parsed = new DOMParser().parseFromString(`<m>${markup}</m>`, "text/xml");
    if (parsed.querySelector("parsererror")) { target.textContent = fallback; return; }
    markupChildren(parsed.documentElement, target);
  }

  function markupChildren(source, target) {
    source.childNodes.forEach((child) => {
      if (child.nodeType === Node.TEXT_NODE) { target.append(document.createTextNode(child.data)); return; }
      if (child.nodeType !== Node.ELEMENT_NODE) return;
      const tag = MARKUP_ELEMENTS[child.nodeName];
      if (!tag) { markupChildren(child, target); return; }
      const element = document.createElement(tag);
      if (child.nodeName === "span") spanStyle(element, child);
      markupChildren(child, element);
      target.append(element);
    });
  }

  function spanStyle(element, source) {
    const attribute = (...names) => names.map((name) => source.getAttribute(name)).find((value) => value !== null);
    const color = attribute("foreground", "color", "fgcolor");
    if (color) element.style.color = color;
    const background = attribute("background", "bgcolor");
    if (background) element.style.backgroundColor = background;
    const size = attribute("size");
    if (size) element.style.fontSize = /^\d+$/.test(size) ? `${Number(size) >= 1024 ? Number(size) / 1024 : Number(size)}pt` : size;
    const weight = attribute("weight");
    if (weight) element.style.fontWeight = MARKUP_WEIGHTS[weight] || weight;
    const style = attribute("style");
    if (style) element.style.fontStyle = style;
    const underline = attribute("underline");
    if (underline && underline !== "none") {
      element.style.textDecoration = underline === "error" ? "underline wavy" : underline === "double" ? "underline double" : "underline";
    }
    const font = attribute("font_desc", "font");
    if (font) fontDescription(element, font);
  }

  // "Courier Bold 15": family words, then style words, then a point size.
  function fontDescription(element, description) {
    const words = description.trim().split(/\s+/);
    if (/^\d+(\.\d+)?$/.test(words[words.length - 1])) element.style.fontSize = `${words.pop()}pt`;
    const family = [];
    words.forEach((word) => {
      const lower = word.toLowerCase();
      if (MARKUP_WEIGHTS[lower]) element.style.fontWeight = MARKUP_WEIGHTS[lower];
      else if (lower === "italic" || lower === "oblique") element.style.fontStyle = lower;
      else family.push(word);
    });
    if (family.length) element.style.fontFamily = `"${family.join(" ")}", monospace, sans-serif`;
  }

  function applyFacilities(page) {
    const facilities = page.facilities || {};
    if (facilities.geometry) {
      if (facilities.geometry.width > 0) page.element.style.width = `${facilities.geometry.width}px`;
      if (facilities.geometry.height > 0) page.element.style.minHeight = `${facilities.geometry.height}px`;
    }
    if (facilities.focus) {
      const focusRoot = page.element.querySelector(`[data-cid="${CSS.escape(facilities.focus)}"]`);
      const focusTarget = focusRoot?.matches("input, select, button, textarea")
        ? focusRoot
        : focusRoot?.querySelector("input, select, button, textarea");
      focusTarget?.focus();
    }
    if (facilities.announce) {
      announcer.setAttribute("aria-live", facilities.announce.politeness);
      announcer.textContent = facilities.announce.text;
    }
    if (facilities.notify) notify(facilities.notify.text, facilities.notify.level);
    // Of the presentation properties only opacity is ours to honor:
    // always_on_top and borderless belong to the window, which a page
    // cannot reach, and the runtime already records those as degraded.
    //
    // It goes on the document, not the page element: fading only the page
    // left the body's own background opaque behind it, so the map dimmed
    // towards grey instead of the window becoming see-through. This makes
    // the whole surface translucent, which is as close as a page can get --
    // what is behind it is still the browser's background, not the game, and
    // real window translucency needs the compositor.
    // A script asking for no scrollbars (map's "Hide Scrollbars", which it
    // spells set_policy(:never, :never)) means the page's own furniture, and
    // the page is the only thing that can take it away. The content still
    // scrolls -- by dragging, by the wheel, by the script centring it.
    const bare = facilities.presentation && facilities.presentation.scrollbars === false;
    document.documentElement.classList.toggle("hide-scrollbars", !!bare);

    const opacity = facilities.presentation && Number.isFinite(facilities.presentation.opacity)
      ? String(facilities.presentation.opacity) : "";
    document.documentElement.style.opacity = opacity;
    document.documentElement.style.background = opacity ? "transparent" : "";
    document.body.style.background = opacity ? "transparent" : "";
    if (page.element.style.opacity) page.element.style.opacity = "";
  }

  function acceleratorKey(event) {
    const parts = [];
    if (event.ctrlKey) parts.push("ctrl");
    if (event.altKey) parts.push("alt");
    if (event.shiftKey) parts.push("shift");
    if (event.metaKey) parts.push("meta");
    parts.push(event.key.toLowerCase());
    return parts.join("+");
  }

  document.addEventListener("keydown", (event) => {
    if (event.isComposing || event.repeat) return;
    const key = acceleratorKey(event);
    for (const page of pages.values()) {
      const activeCid = event.target.closest?.("[data-cid]")?.dataset.cid;
      if (activeCid && bound(page, activeCid, "submit")) continue;
      const accelerator = (page.facilities?.accelerators || []).find((item) => item.keys.toLowerCase() === key);
      if (!accelerator) continue;
      const target = page.element?.querySelector(`[data-cid="${CSS.escape(accelerator.target)}"]`);
      if (!target || target.disabled || target.hidden || target.getClientRects().length === 0) continue;
      event.preventDefault();
      target.click();
      break;
    }
  });

  // What a viewer is in the middle of doing, which the tree swap would
  // otherwise throw away. Keyed by cid, which is stable across renders.
  //
  // Only text-like controls are captured. A checkbox or a select has no
  // half-finished state: its value changes in one gesture that has already
  // been sent, so re-applying a stale one would fight the server.
  function captureEditing(page) {
    if (!page.element) return null;
    const active = document.activeElement;
    const state = { focusCid: null, selection: null, edits: new Map() };
    for (const [cid, control] of page.controls || []) {
      if (!control || !control.isConnected) continue;
      const editable = control.tagName === "TEXTAREA"
        || (control.tagName === "INPUT" && !["checkbox", "radio", "range", "number"].includes(control.type));
      if (control === active) {
        state.focusCid = cid;
        if (editable) {
          state.selection = { start: control.selectionStart, end: control.selectionEnd };
        }
      }
      // The value the server last sent us; anything else is the viewer's own
      // typing. Keeping the base is what lets a genuine server update win
      // below.
      const rendered = findComponent(page.tree, cid)?.props?.value;
      if (editable && rendered !== undefined && control.value !== String(rendered)) {
        state.edits.set(cid, { typed: control.value, base: String(rendered) });
      }
    }
    return state;
  }

  function restoreEditing(page, state) {
    if (!state) return;
    for (const [cid, edit] of state.edits) {
      const control = page.controls?.get(cid);
      if (!control) continue;
      // If the server changed the value in this very render, it wins: the
      // script deliberately set it, and the viewer's stale keystrokes are no
      // longer what they were editing. Compared against the value the
      // previous render carried, not against the fresh control -- the control
      // already holds the new value, so it always matches itself.
      const rendered = findComponent(page.tree, cid)?.props?.value;
      if (rendered !== undefined && String(rendered) !== edit.base) continue;
      control.value = edit.typed;
    }
    if (!state.focusCid) return;
    const control = page.controls?.get(state.focusCid);
    if (!control || control.disabled) return;
    control.focus();
    if (state.selection && typeof control.setSelectionRange === "function") {
      try {
        control.setSelectionRange(state.selection.start, state.selection.end);
      } catch {
        // Some input types refuse a selection range; focus alone is enough.
      }
    }
  }

  function acceptRender(message) {
    const page = pages.get(message.page);
    if (!page) return;
    if (page.geometryTimer) window.clearInterval(page.geometryTimer);
    const editing = captureEditing(page);
    page.generation = message.generation;
    page.bindings = message.bindings || {};
    page.submissions = message.submissions || {};
    page.facilities = message.facilities || {};
    page.resume = message.resume;
    page.controls = new Map();
    page.tree = message.tree;
    page.pendingScrolls = [];
    const next = render(page, message.tree);
    next.dataset.pageAddress = page.address;
    if (page.element) page.element.replaceWith(next); else pagesNode.append(next);
    page.element = next;
    // Before applyFacilities, so an explicit `focus` facility still wins:
    // the script asking for focus outranks restoring where the viewer was.
    restoreEditing(page, editing);
    applyFacilities(page);
    refreshMenus(page);
    applyScrollPositions(page);
  }

  // `bottom` means the end of the content, whatever it turned out to be --
  // the script asked for the bottom, not for the pixel it guessed. Runs after
  // layout so scrollHeight is real.
  function applyScrollPositions(page) {
    const pending = page.pendingScrolls || [];
    page.pendingScrolls = [];
    if (!pending.length) return;
    requestAnimationFrame(() => {
      pending.forEach(([element, position]) => {
        if (!element.isConnected) return;
        if (position.bottom === true) element.scrollTop = element.scrollHeight;
        else if (Number.isFinite(position.y)) element.scrollTop = position.y;
        if (Number.isFinite(position.x)) element.scrollLeft = position.x;
        // Seed the memory from where we just landed, so a rebuild arriving
        // before the element's own scroll event restores this and not the
        // offset from before the script moved it.
        const cid = element.dataset.cid;
        if (cid) {
          (page.scrollOffsets ||= new Map()).set(cid, {
            x: Math.round(element.scrollLeft), y: Math.round(element.scrollTop),
          });
        }
      });
    });
  }

  function notify(text, level = "info") {
    const message = node("div", `notification ${level}`, text);
    notifications.append(message);
    window.setTimeout(() => message.remove(), 5000);
  }

  function receive(event) {
    const message = JSON.parse(event.data);
    if (message.type === "hello" || message.type === "pages") {
      statusNode.textContent = "Connected";
      // A window opened for one page ignores every other page -- except a
      // modal raised by the same owner. A script that asks a question blocks
      // until it is answered, and the dialog is a page of its own, so
      // skipping it left the question invisible and the script stuck.
      const ownerOf = (address) => message.pages.find((p) => p.address === address)?.owner;
      const scopedOwner = onlyPage ? ownerOf(onlyPage) : null;
      message.pages.forEach((descriptor) => {
        const sameOwnerModal = descriptor.modal && scopedOwner && descriptor.owner === scopedOwner;
        if (onlyPage && descriptor.address !== onlyPage && !sameOwnerModal) return;
        // A modal borrows the window; it must not rename it.
        if (descriptor.title && !descriptor.modal) document.title = descriptor.title;
        const page = pages.get(descriptor.address) || { address: descriptor.address };
        pages.set(descriptor.address, page);
        socket.send(JSON.stringify({ type: "attach", page: descriptor.address, version: VERSION, resume: page.resume }));
      });
    } else if (message.type === "render") acceptRender(message);
    else if (message.type === "clear_sensitive") pages.forEach((page) => message.cids.forEach((cid) => {
      const control = page.controls?.get(cid); if (control) control.value = "";
    }));
    else if (message.type === "page_closed") {
      window.clearInterval(pages.get(message.page)?.geometryTimer);
      pages.get(message.page)?.element?.remove();
      pages.delete(message.page);
    } else if (message.type === "refusal") {
      // A stale generation is not a failure the person needs to see: the
      // server already sent the render that supersedes it, so replay the
      // click against that one. Replayed once, so a genuinely rejected
      // event cannot loop.
      if (message.reason === "stale_generation" && pendingEvent) {
        const retry = pendingEvent;
        pendingEvent = null;
        const page = pages.get(retry.address);
        const component = page && findComponent(page.tree, retry.cid);
        if (page && component && !retriedEvents.has(retry.cid + retry.event)) {
          retriedEvents.add(retry.cid + retry.event);
          window.setTimeout(() => {
            retriedEvents.delete(retry.cid + retry.event);
            emit(page, component, retry.event, retry.payload);
          }, 0);
          return;
        }
      }
      pendingEvent = null;
      // A stale report of the layout's own extent tells the viewer nothing:
      // the render that superseded it already carries the truth.
      if (message.reason === "stale_generation") {
        console.warn("webui refusal", message);
        return;
      }
      // The server sends a generic message and a specific reason; showing
      // only the message makes every refusal look alike and undiagnosable.
      const detail = [message.reason, message.cid].filter(Boolean).join(" @ ");
      const text = message.message || "Request refused";
      notify(detail ? `${text}: ${detail}` : text, "error");
      if (message.reason) console.warn("webui refusal", message);
    }
  }

  function connect() {
    const scheme = window.location.protocol === "https:" ? "wss:" : "ws:";
    socket = new WebSocket(`${scheme}//${window.location.host}/ws`);
    socket.addEventListener("open", () => { reconnectDelay = 250; });
    socket.addEventListener("message", receive);
    socket.addEventListener("close", () => {
      statusNode.textContent = "Disconnected; reconnecting";
      window.setTimeout(connect, reconnectDelay);
      reconnectDelay = Math.min(5000, reconnectDelay * 2);
    });
    socket.addEventListener("error", () => socket.close());
  }

  function detachPages() {
    if (!socket || socket.readyState !== WebSocket.OPEN) return;
    pages.forEach((page) => {
      if (!Number.isInteger(page.generation)) return;
      socket.send(JSON.stringify({
        type: "detach", page: page.address, generation: page.generation
      }));
    });
  }

  // A dedicated launcher window owns its Ruby startup session. Tell the
  // server that this is an intentional page close before Chrome tears down
  // the WebSocket; transport-only disconnects retain their resume semantics.
  window.addEventListener("pagehide", detachPages);

  window.LichWebUI = Object.freeze({ VERSION, renderers, render });
  connect();
})();
