(() => {
  "use strict";

  const VERSION = "2.5.0";
  const pagesNode = document.getElementById("pages");
  const statusNode = document.getElementById("status");
  const notifications = document.getElementById("notifications");
  const announcer = document.getElementById("announcer");
  const pages = new Map();
  let socket;
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
    if (Number.isFinite(props.margin)) element.style.margin = `${props.margin}px`;
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

  function emit(page, component, event, payload = {}) {
    if (!socket || socket.readyState !== WebSocket.OPEN || !bound(page, component.cid, event)) return;
    const message = {
      type: "event", page: page.address, cid: component.cid, event,
      generation: page.generation, payload
    };
    const scope = page.submissions[component.cid];
    if (scope) message.submission = scope.map((cid) => controlValue(page.controls.get(cid)));
    socket.send(JSON.stringify(message));
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
      if (!component.props.bare) root.append(node("h1", null, component.props.title));
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
      return appendChildren(page, component, stack);
    },
    columns(page, component) {
      const columns = common(node("div", "webui-columns"), component);
      const weights = component.props.weights || Array(component.props.count).fill(1);
      columns.style.gridTemplateColumns = weights.map((weight) => `${weight}fr`).join(" ");
      columns.style.gap = `${component.props.gap ?? 8}px`;
      (component.children || []).forEach((child) => {
        const childNode = render(page, child);
        childNode.style.gridColumn = String(Number(child.slot) + 1);
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
    divider(_page, component) { return common(node("div", "webui-divider", component.props.label || ""), component); },
    text(_page, component) { return common(node("div", "webui-text", component.props.content), component); },
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
      const header = node("tr");
      component.props.columns.forEach((column) => header.append(node("th", null, column.label)));
      const head = node("thead");
      head.append(header);
      table.append(head);
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

  function render(page, component) {
    const renderer = renderers[component.type];
    if (!renderer) {
      const error = common(node("div", "renderer-error", `Renderer not implemented: ${component.type}`), component);
      error.dataset.error = "renderer_not_implemented";
      return error;
    }
    return renderer(page, component);
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

  function acceptRender(message) {
    const page = pages.get(message.page);
    if (!page) return;
    if (page.geometryTimer) window.clearInterval(page.geometryTimer);
    page.generation = message.generation;
    page.bindings = message.bindings || {};
    page.submissions = message.submissions || {};
    page.facilities = message.facilities || {};
    page.resume = message.resume;
    page.controls = new Map();
    const next = render(page, message.tree);
    next.dataset.pageAddress = page.address;
    if (page.element) page.element.replaceWith(next); else pagesNode.append(next);
    page.element = next;
    applyFacilities(page);
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
      message.pages.forEach((descriptor) => {
        if (descriptor.title) document.title = descriptor.title;
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
    } else if (message.type === "refusal") notify(message.message || "Request refused", "error");
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
