(() => {
  "use strict";

  const VERSION = "2.51.0";
  const pagesNode = document.getElementById("pages");
  const statusNode = document.getElementById("status");
  const notifications = document.getElementById("notifications");
  const announcer = document.getElementById("announcer");
  const pages = new Map();
  // Script app windows share the service, not its entire page catalog. Dialogs
  // advertise their eligible parent pages using server-owned opaque addresses.
  const requestedPage = new URLSearchParams(window.location.search).get("page");
  let socket;
  let reconnectDelay = 250;
  let nextRequest = 0;
  const pending = new Map();

  // Retain bounded, short-lived intent snapshots. Correlation numbers carry
  // no server routing authority; every retry is validated against a new tree.
  function dropPending(request) {
    window.clearTimeout(pending.get(request)?.timer);
    pending.delete(request);
  }

  /** Drops matching retry records and their timers, including secret-bearing submissions. */
  function discardPending(predicate) {
    for (const [request, record] of pending) if (predicate(record)) dropPending(request);
  }

  /** Finds a stable identity in the accepted tree; absent controls cannot receive a retry. */
  function findComponent(component, cid) {
    if (component.cid === cid) return component;
    for (const child of component.children || []) {
      const found = findComponent(child, cid);
      if (found) return found;
    }
  }

  /** Identifies indexed tab destinations independently of paint-only changes. */
  function tabIdentity(component) {
    return JSON.stringify([component.props.names, component.props.headers?.map(header => header.key),
      (component.children || []).filter(child => !child.placement?.tab_action).map(child => [child.cid, child.slot])]);
  }

  /** Navigation intent expires or retires as soon as its original destination becomes unavailable. */
  function canRetryTab(page, component, record) {
    const index = record.message.payload.index;
    if (!component || component.type !== "tabs" || Date.now() >= record.tabSelection.deadline ||
        tabIdentity(component) !== record.tabSelection.identity || !bound(page, component.cid, "select") ||
        component.props.disabled || component.props.hidden || component.props.show_tabs === false ||
        (component.props.selected ?? 0) === index || component.props.headers?.[index]?.hidden ||
        component.props.headers?.[index]?.disabled) return false;
    const element = [...page.element.querySelectorAll("[data-cid]")].find(child => child.dataset.cid === component.cid);
    return !!element && !element.closest("[hidden],[inert]");
  }

  /**
   * Serializes host measurements using content or outer-frame dimensions explicitly.
   * @param {boolean} content Whether dimensions describe the client area.
   * @returns {string} JSON dimensions and desktop position.
   */
  function windowGeometry(content) {
    return JSON.stringify({
      width: content ? window.innerWidth : window.outerWidth,
      height: content ? window.innerHeight : window.outerHeight,
      position: [window.screenX, window.screenY]
    });
  }

  /** Removes the previous render's timer and resize listener before replacement or closure. */
  function stopWindowGeometry(page) {
    window.clearInterval(page.geometryTimer);
    if (page.reportGeometry) window.removeEventListener("resize", page.reportGeometry);
    page.reportGeometry = null;
  }

  /** Retires native state observation with its owning rendered page. */
  function stopWindowState(page) {
    if (page.reportWindowState) window.removeEventListener("lich-window-state", page.reportWindowState);
    page.reportWindowState = null;
  }

  /** Reports measured native minimize/restore transitions, independently of page visibility. */
  function trackWindowState(page, component) {
    stopWindowState(page);
    if (requestedPage && page.address !== requestedPage) return;
    if (!bound(page, component.cid, "window_state") || !window.lichNativeWindow) return;
    page.reportWindowState = () => {
      const minimized = window.lichNativeWindow.minimized;
      if (typeof minimized !== "boolean" || minimized === page.lastWindowMinimized) return;
      page.lastWindowMinimized = minimized;
      emit(page, component, "window_state", { minimized });
    };
    window.addEventListener("lich-window-state", page.reportWindowState);
    page.reportWindowState();
  }

  // Native windows may preserve either outer size (launcher) or content size
  // (fixed artwork). Meter renders must not reset the last observed geometry.
  function trackWindowGeometry(page, component, content) {
    stopWindowGeometry(page);
    if (!content) page.geometryRestored = true; // Launcher launch flags already describe its outer frame.
    if (content && !page.geometryRestored) {
      page.geometryRestored = true;
      try {
        const saved = JSON.parse(component.props.value);
        if ([saved.width, saved.height].every(n => Number.isInteger(n) && n > 0 && n <= 65536)) {
          window.resizeTo(saved.width + window.outerWidth - window.innerWidth,
            saved.height + window.outerHeight - window.innerHeight);
        }
      } catch (_) { /* Missing or invalid hints leave the browser's size intact. */ }
    }
    page.reportGeometry = () => {
      const current = windowGeometry(content);
      if (current === page.lastGeometry) return;
      page.lastGeometry = current;
      emit(page, component, "change", { value: current });
    };
    window.addEventListener("resize", page.reportGeometry);
    page.geometryTimer = window.setInterval(page.reportGeometry, 500);
  }

  // One geometry reporter per host window. Keep legacy hidden geometry fields
  // working while every page also reports typed measurements to core. Only the
  // requested root owns desktop geometry; an in-window dialog cannot resize it.
  function naturalPageSize(element, requestedWidth) {
    const previous = { width: element.style.width, height: element.style.height, minHeight: element.style.minHeight };
    try {
      // A viewport-sized allocation is not the contents' minimum. Collapse
      // only the root while measuring; child requests and overflow still count.
      element.style.width = "0px";
      element.style.height = "0px";
      element.style.minHeight = "0px";
      const width = element.scrollWidth;
      // Wrapped content's height depends on its allocated width. Measure it
      // at the requested width after deriving the independent width minimum.
      element.style.width = `${Math.max(width, requestedWidth)}px`;
      return { width, height: element.scrollHeight };
    } finally {
      Object.assign(element.style, previous);
    }
  }

  /** Reports typed root geometry and applies each explicit resize request only once. */
  function trackPageGeometry(page, component) {
    if (requestedPage && page.address !== requestedPage) return;
    const reportsGeometry = bound(page, component.cid, "configure");
    // Minima govern the host even when the script does not subscribe to geometry.
    if (!reportsGeometry && !Number.isFinite(component.props.min_width) && !Number.isFinite(component.props.min_height)) return;
    const legacyReport = page.reportGeometry;
    stopWindowGeometry(page);
    page.reportGeometry = (event) => {
      // Launch dimensions are not minima. An explicitly unscrolled table
      // also retains its contents' requisition, as a naked GTK TreeView does.
      if (event?.type === "resize") {
        const natural = page.unscrolledTableMinimum ? naturalPageSize(page.element,
          Math.max(window.innerWidth, component.props.min_width || 0)) : { width: 0, height: 0 };
        const width = Math.max(window.innerWidth, component.props.min_width || 0, natural.width);
        const height = Math.max(window.innerHeight, component.props.min_height || 0, natural.height);
        const attempt = `${window.innerWidth},${window.innerHeight}->${width},${height}`;
        if (width !== window.innerWidth || height !== window.innerHeight) {
          if (page.minimumResizeAttempt !== attempt) {
            page.minimumResizeAttempt = attempt;
            window.resizeTo(width + window.outerWidth - window.innerWidth,
              height + window.outerHeight - window.innerHeight);
          }
        } else page.minimumResizeAttempt = null;
      }
      legacyReport?.();
      if (!reportsGeometry) return;
      const payload = { width: Math.round(window.innerWidth), height: Math.round(window.innerHeight),
        position: [Math.round(window.screenX), Math.round(window.screenY)] };
      const nativeMonitors = window.lichNativeWindow?.monitors;
      const screen = window.screen;
      payload.monitors = nativeMonitors || (screen?.width > 0 && screen?.height > 0 ? {
        source: "browser", screens: [{ x: Math.round(screen.left ?? screen.availLeft ?? 0),
          y: Math.round(screen.top ?? screen.availTop ?? 0), width: Math.round(screen.width), height: Math.round(screen.height),
          primary: false, active: true }]
      } : { source: "unavailable", screens: [] });
      const signature = JSON.stringify(payload);
      if (signature === page.lastPageGeometry) return;
      page.lastPageGeometry = signature;
      emit(page, component, "configure", payload);
    };
    window.addEventListener("resize", page.reportGeometry);
    page.geometryTimer = window.setInterval(page.reportGeometry, 250);
    window.requestAnimationFrame(() => {
      if (!page.element?.isConnected) return;
      let requestedResize = false;
      if (!page.geometryRestored) {
        const size = component.props.size;
        const position = component.props.position;
        // GTK requested dimensions refer to the client area. Chrome's launch
        // flags use the outer frame, so add the measured decoration once.
        if (size?.[0] > 0 && size?.[1] > 0) {
          const natural = naturalPageSize(page.element, Math.max(size[0], component.props.min_width || 0));
          const height = Math.max(size[1], component.props.min_height || 0, natural.height);
          window.resizeTo(Math.max(size[0], component.props.min_width || 0, natural.width) + window.outerWidth - window.innerWidth,
            height + window.outerHeight - window.innerHeight);
          requestedResize = true;
        }
        if (position?.length === 2) window.moveTo?.(...position);
        page.geometryRestored = true;
      }
      // A script may explicitly request another resize. The id distinguishes
      // that action from an ordinary meter render and from replayed renders.
      const request = component.props.resize_request;
      if (request && request.id !== page.lastResizeRequest) {
        page.lastResizeRequest = request.id;
        const natural = naturalPageSize(page.element, Math.max(request.size[0], component.props.min_width || 0));
        const width = Math.max(request.size[0], component.props.min_width || 0, natural.width);
        const height = Math.max(request.size[1], component.props.min_height || 0, natural.height);
        window.resizeTo(width + window.outerWidth - window.innerWidth,
          height + window.outerHeight - window.innerHeight);
        requestedResize = true;
      }
      // Enforce partial or changed minima on first display and every render,
      // retaining the other axis and larger user geometry. An explicit request
      // already clamps both minima; do not compete with that asynchronous resize
      // using the old host measurements. Repeated host refusals are deduplicated.
      page.reportGeometry?.(requestedResize ? undefined : { type: "resize" });
    });
  }

  /** Creates a DOM node with literal textContent; supplied text is never parsed as HTML. */
  function node(tag, className, text) {
    const result = document.createElement(tag);
    if (className) result.className = className;
    if (text !== undefined) result.textContent = String(text);
    return result;
  }

  /** Applies validated common properties; it does not accept arbitrary CSS or HTML source. */
  function common(element, component) {
    const props = component.props || {};
    if (component.type === "button") nativeTextStyle(element, props);
    element.dataset.cid = component.cid;
    element.dataset.componentType = component.type;
    if (props.presentation_role) element.dataset.presentationRole = props.presentation_role;
    if (props.width_groups?.length) element.dataset.widthGroups = props.width_groups.join(" ");
    element.hidden = props.hidden === true;
    if (["stack", "button", "text"].includes(component.type)) element.style.opacity = props.opacity ?? "";
    if ("disabled" in element) element.disabled = props.disabled === true;
    if (props.disabled) element.inert = true;
    if (props.tooltip) element.title = props.tooltip;
    if (props.cursor_hint) {
      element.dataset.cursorHint = props.cursor_hint;
      element.style.setProperty("--webui-cursor-hint", props.cursor_hint);
    } else {
      delete element.dataset.cursorHint;
      element.style.removeProperty("--webui-cursor-hint");
    }
    if (props.a11y_label) element.setAttribute("aria-label", props.a11y_label);
    if (props.a11y_description) element.setAttribute("aria-description", props.a11y_description);
    if (props.a11y_role) element.setAttribute("role", props.a11y_role);
    ["align", "emphasis", "tone"].forEach((name) => {
      if (props[name]) element.classList.add(`${name}-${props[name]}`);
    });
    if (component.type === "button" && ["start", "center", "end"].includes(props.align)) {
      element.style.alignSelf = props.align === "center" ? "center" : `flex-${props.align}`;
      element.style.justifySelf = props.align;
    }
    if (Number.isFinite(props.margin)) element.style.margin = `${props.margin}px`;
    else if (props.margin) for (const side of ["top", "right", "bottom", "left"]) {
      element.style[`margin${side[0].toUpperCase()}${side.slice(1)}`] = `${props.margin[side] || 0}px`;
    }
    if (Number.isFinite(props.width) && props.width >= 0) element.style.width = `${props.width}px`;
    if (Number.isFinite(props.min_width)) element.style.minWidth = `${props.min_width}px`;
    if (component.type === "button" && props.width === undefined && Number.isFinite(props.min_width) &&
        ["start", "center", "end"].includes(props.align)) element.style.width = "max-content";
    if (Number.isFinite(props.height) && props.height >= 0) element.style.height = `${props.height}px`;
    if (Number.isFinite(props.min_height) && props.min_height >= 0) element.style.minHeight = `${props.min_height}px`;
    if (Number.isFinite(props.max_height) && props.max_height >= 0) element.style.maxHeight = `${props.max_height}px`;
    if (props.fill && ["stack", "columns", "table", "split", "group"].includes(component.type)) {
      element.style.flex = "1"; element.style.minHeight = `${props.min_height || 0}px`; element.style.height = "0px";
    }
    return element;
  }

  /** Equalizes page-local width requests, including overlapping horizontal groups. */
  function equalizeWidthGroups(page) {
    const root = page.element;
    const members = [...root.querySelectorAll("[data-width-groups]")];
    if (!members.length) return;
    const authored = new Map(members.map(element => [element, {
      width: element.style.width, minimum: element.style.minWidth
    }]));
    let scheduled = false;
    const measure = () => {
      scheduled = false;
      if (!root.isConnected || page.element !== root) return;
      // Measure all intrinsic requests in one layout pass, without touching live inputs.
      const fragment = document.createDocumentFragment();
      const probes = members.map(element => {
        const clone = element.cloneNode(true), base = authored.get(element);
        clone.hidden = false;
        clone.setAttribute("aria-hidden", "true");
        clone.style.position = "absolute";
        clone.style.visibility = "hidden";
        clone.style.width = "max-content";
        clone.style.maxWidth = "none";
        clone.style.minWidth = base.minimum;
        if (/^\d+(?:\.\d+)?px$/.test(base.width)) {
          clone.style.minWidth = base.minimum ? `max(${base.minimum}, ${base.width})` : base.width;
        }
        // A cloned checked radio must never join and deselect its live group.
        for (const node of [clone, ...clone.querySelectorAll("[id],input[name]")]) {
          node.removeAttribute("id");
          if (node.tagName === "INPUT") node.removeAttribute("name");
        }
        fragment.append(clone);
        return clone;
      });
      root.append(fragment);
      const widths = probes.map(probe => Math.min(65_536, Math.ceil(probe.getBoundingClientRect().width)));
      probes.forEach(probe => probe.remove());
      const parents = new Map();
      const find = key => {
        if (!parents.has(key)) parents.set(key, key);
        let root = key;
        while (parents.get(root) !== root) root = parents.get(root);
        while (key !== root) { const next = parents.get(key); parents.set(key, root); key = next; }
        return root;
      };
      const groups = members.map(element => element.dataset.widthGroups.split(" "));
      groups.forEach(keys => keys.slice(1).forEach(key => parents.set(find(key), find(keys[0]))));
      const maxima = new Map();
      groups.forEach((keys, index) => {
        const key = find(keys[0]);
        maxima.set(key, Math.max(maxima.get(key) || 0, widths[index]));
      });
      members.forEach((element, index) => {
        const width = maxima.get(find(groups[index][0]));
        const base = authored.get(element).minimum;
        element.style.minWidth = width > 0 ? (base ? `max(${base}, ${width}px)` : `${width}px`) : base;
      });
    };
    const schedule = () => {
      if (!scheduled) { scheduled = true; window.requestAnimationFrame(measure); }
    };
    schedule();
    if (window.ResizeObserver) {
      const observer = new window.ResizeObserver(schedule);
      observer.observe(root);
      (page.layoutObservers ||= []).push(observer);
    }
    document.fonts?.ready.then(schedule);
  }

  /** Checks the delivered event allowlist before sending a control interaction. */
  function bound(page, cid, event) {
    return (page.bindings[cid] || []).includes(event);
  }

  /**
   * Extracts the wire value rather than presentation text (notably editable-select labels).
   * @returns {*} Current scalar value, or null when the control is absent.
   */
  function controlValue(control) {
    if (!control) return null;
    if (control.choiceValue) return control.choiceValue();
    if (control.type === "checkbox") return control.checked;
    if (control.type === "number" || control.type === "range") return control.valueAsNumber;
    return control.value;
  }

  /** Retires unsent wheel movement when its attachment closes or disconnects. */
  function clearWheel(page) {
    if (page.wheelFrame != null) window.cancelAnimationFrame(page.wheelFrame);
    page.wheelFrame = null;
    page.wheelBatches = [];
  }

  /** Sends ordered, bounded chunks against the current tree, never an old DOM closure. */
  function flushWheel(page) {
    const batches = page.wheelBatches || [];
    clearWheel(page);
    for (const batch of batches) {
      const component = page.tree && findComponent(page.tree, batch.cid);
      const element = page.element && [page.element, ...page.element.querySelectorAll("[data-cid]")].find(node => node.dataset.cid === batch.cid);
      if (!component || !element || !bound(page, batch.cid, "scroll") || component.props.disabled ||
          element.closest("[hidden],[inert]")) continue;
      let { x, y } = batch;
      while (x || y) {
        const scale = Math.min(1, 65536 / Math.max(Math.abs(x), Math.abs(y)));
        const dx = Math.round(x * scale), dy = Math.round(y * scale);
        emit(page, component, "scroll", { delta_x: dx, delta_y: dy, state: batch.state, ...batch.point });
        x -= dx; y -= dy;
      }
    }
  }

  /** Coalesces only compatible wheel movement; modifier/direction transitions retain order. */
  function queueWheel(page, component, x, y, state, point = {}) {
    if (!Number.isFinite(x) || !Number.isFinite(y) || (!x && !y)) return;
    const direction = `${Math.sign(x)}:${Math.sign(y)}:${Math.abs(x) > Math.abs(y)}`;
    let batches = page.wheelBatches ||= [];
    let last = batches.at(-1);
    const compatible = last && last.cid === component.cid && last.state === state && last.direction === direction &&
      last.point.x === point.x && last.point.y === point.y;
    // Bound unsent segments and sums without dropping accumulated movement.
    // Saturation flushes through the standing server bounds, never bypassing them.
    if (batches.length >= 256 || (compatible && Math.max(Math.abs(last.x + x), Math.abs(last.y + y)) > 16777216)) {
      flushWheel(page);
      batches = page.wheelBatches;
      last = null;
    }
    if (last && compatible) {
      last.x += x; last.y += y;
    } else batches.push({ cid: component.cid, x, y, state, direction, point });
    if (page.wheelFrame == null) page.wheelFrame = window.requestAnimationFrame(() => flushWheel(page));
  }

  /**
   * Counts UTF-8 bytes in serialized JSON without allocating a second byte buffer.
   * @param {string} text JSON text (unpaired surrogates have already been escaped).
   * @returns {number} Encoded byte count.
   */
  function utf8Bytes(text) {
    let size = 0;
    for (const character of text) {
      const code = character.codePointAt(0);
      size += code <= 0x7f ? 1 : code <= 0x7ff ? 2 : code <= 0xffff ? 3 : 4;
    }
    return size;
  }

  // Defaults match Contract::WIRE_LIMITS; the greeting supplies server limits.
  let wireLimits = { message_bytes: 2097152, event_payload_bytes: 524288, submission_bytes: 1048576 };

  // Kept in parity with Contract lifecycle events by contract_foundation_spec.
  const LIFECYCLE_EVENTS = new Set(["attach", "detach", "close", "dismiss", "focus", "blur", "pointer_press", "tab_pointer", "window_state"]);
  // Input-scope terminals exclude runtime close and row/widget drag payloads.
  const TERMINAL_EVENTS = new Set(["activate", "submit", "response", "row_activate", "region_activate", "surface_activate"]);

  /**
   * Sends a bound event with the delivered generation and its server-declared input scope.
   * Keeps at most 256 intent snapshots totaling 8 MiB for 30 seconds and one correlated stale-tree retry.
   * The latest tab navigation may retry through repeated redraws within its original 30-second deadline.
   * Sensitive snapshots are released by clear_sensitive, expiry, closure, or disconnect.
   * Counts serialized message bytes once and updates a local subtotal during eviction.
   * @param {Object} page Viewer state containing bindings, controls, and submission scopes.
   * @param {Object} component Component whose bound event is being emitted.
   * @param {string} event Bound event name.
   * @param {Object} payload Event data checked against the payload byte budget.
   * @param {Object|null} previous Retained intent for replay, otherwise null.
   * @returns {void}
   */
  function emit(page, component, event, payload = {}, previous = null) {
    if (!socket || socket.readyState !== WebSocket.OPEN || !bound(page, component.cid, event)) return;
    if (!previous && !["scroll", "scrolled", "configure", "window_state"].includes(event)) flushWheel(page);
    if (event !== "configure" && !LIFECYCLE_EVENTS.has(event) && (component.props.disabled || page.element?.hidden)) return;
    const message = {
      type: "event", page: page.address, cid: component.cid, event,
      generation: page.generation, payload, request: ++nextRequest
    };
    const scope = page.submissions[component.cid];
    if (scope && TERMINAL_EVENTS.has(event)) {
      message.submission = previous ? previous.message.submission : scope.map(cid => controlValue(page.controls.get(cid)));
    }
    // Measure the actual serialized UTF-8 bytes, including Unicode and escaping,
    // before advancing draft baselines or retaining a retry snapshot.
    const serialized = JSON.stringify(message);
    const messageBytes = utf8Bytes(serialized);
    if (messageBytes > wireLimits.message_bytes ||
        utf8Bytes(JSON.stringify(payload)) > wireLimits.event_payload_bytes ||
        (message.submission && utf8Bytes(JSON.stringify(message.submission)) > wireLimits.submission_bytes)) {
      notify("This change is too large to send. Your edits are retained; reduce the input size and retry.", "error");
      return;
    }
    const liveText = component.type === "text_input" && event === "change" && !component.props.sensitive;
    const tabSelection = component.type === "tabs" && event === "select";
    if (tabSelection) discardPending(record => record.tabSelection && record.message.page === page.address && record.message.cid === component.cid);
    // Only the newest live edit may be retried. Earlier callbacks may still
    // finish, but their render acknowledges an older request and cannot own
    // the current draft or caret. This also bounds typing to one retained edit.
    if (liveText) discardPending(record => record.liveText && record.message.page === page.address && record.message.cid === component.cid);
    // A sent toggle is no longer an unsent draft. A callback may reset it to
    // the previous server value before an intermediate render acknowledges it.
    // A replay must keep the replacement tree's baseline: its DOM may still
    // show the old server value, which must not become a fabricated local edit.
    if (!previous && event === "change" && ["checkbox", "toggle"].includes(component.type)) {
      page.bases?.set(component.cid, payload.value);
    }
    if (scope && TERMINAL_EVENTS.has(event)) {
      // A submitted draft becomes the comparison baseline. Otherwise a server
      // clearing an initially empty field looks like an unrelated redraw and
      // the client restores the just-submitted text (sbounty's Create form).
      // Retrying a retained snapshot is not a new edit of the current controls.
      scope.forEach((cid, index) => {
        if (!previous) discardPending(record => record.liveText && record.message.page === page.address && record.message.cid === cid);
        const control = page.controls.get(cid);
        if (!previous && control && control.type !== "password" && control.dataset?.sensitive !== "true") {
          page.bases?.set(cid, message.submission[index]);
        }
      });
    }
    // Scroll is a fresh measurement, not replayable user intent.
    if (!["scrolled", "pointer_motion"].includes(event)) {
      let retained = [...pending.values()].reduce((sum, record) => sum + record.bytes, 0);
      while (pending.size >= 256 || retained + messageBytes > 8 * 1024 * 1024) {
        const oldest = pending.keys().next().value;
        retained -= pending.get(oldest).bytes;
        dropPending(oldest);
      }
      const record = { message: JSON.parse(JSON.stringify(message)), scope: scope ? [...scope] : [],
        attempt: previous ? previous.attempt + 1 : 0, replay: false, liveText, bytes: messageBytes };
      if (tabSelection) record.tabSelection = previous?.tabSelection || { identity: tabIdentity(component), deadline: Date.now() + 30000 };
      if (event === "widget_drop") record.dragSourceKey = previous?.dragSourceKey || findComponent(page.tree, payload.source)?.props.drag_source;
      record.timer = window.setTimeout(() => dropPending(message.request), record.tabSelection ? record.tabSelection.deadline - Date.now() : 30000);
      pending.set(message.request, record);
    }
    socket.send(serialized);
  }

  function appendChildren(page, component, parent) {
    (component.children || []).forEach((child) => parent.append(render(page, child)));
    return parent;
  }

  // Allocation observers belong to one render and never outlive its page.
  function observeAllocation(page, element, work) {
    window.requestAnimationFrame(work);
    if (window.ResizeObserver) {
      const observer = new window.ResizeObserver(work);
      observer.observe(element);
      (page.layoutObservers ||= []).push(observer);
    }
  }

  const modifiers = event => (event.shiftKey ? 1 : 0) | (event.ctrlKey ? 4 : 0) | (event.altKey ? 8 : 0);

  // Families are inert until this bootstrap supplies their explicit capabilities.
  // They receive the owning page at render time, never the page map or socket.
  const families = Object.freeze(window.LichWebUIRendererFamilies);
  const renderers = {};
  const menusRenderers = families.menus({
    node, common, emit, appendChildren, render, compositeColor, surfacePayload
  });
  const { hideSubmenus, captureMenuNavigation, restoreMenuNavigation, contextMenuFocus, hideContextMenu, showContextMenu } = menusRenderers;
  const layoutRenderers = families.layout({
    node, common, emit, appendChildren, render, observeAllocation, requestedPage, holdPointer, compositeColor, modifiers, acceptRender
  });
  const displayRenderers = families.display({
    node, common, bound, emit, observeAllocation, nativeTextStyle, compositeColor, surfacePayload, showContextMenu
  });
  const inputsRenderers = families.inputs({
    node, common, emit, appendChildren, findComponent, trackWindowGeometry, nativeTextStyle, renderers
  });
  const tableRenderers = families.table({
    node, common, bound, emit, compositeColor, holdPointer, acceptRender, findComponent, controlValue
  });
  Object.assign(renderers, {
    expander: layoutRenderers.expander,
    page: layoutRenderers.page,
    group: menusRenderers.group,
    stack: layoutRenderers.stack,
    columns: layoutRenderers.columns,
    grid: layoutRenderers.grid,
    scroll: layoutRenderers.scroll,
    tabs: layoutRenderers.tabs,
    divider: layoutRenderers.divider,
    overlay: layoutRenderers.overlay,
    split: layoutRenderers.split,
    log: displayRenderers.log,
    text: displayRenderers.text,
    markdown: displayRenderers.markdown,
    progress: displayRenderers.progress,
    button: inputsRenderers.button,
    checkbox: inputsRenderers.checkbox,
    toggle: inputsRenderers.toggle,
    radio_option: inputsRenderers.radio_option,
    radio: inputsRenderers.radio,
    textarea: inputsRenderers.textarea,
    text_input: inputsRenderers.text_input,
    password_input: inputsRenderers.password_input,
    slider: inputsRenderers.slider,
    number_input: inputsRenderers.number_input,
    select: inputsRenderers.select,
    image: displayRenderers.image,
    composite: displayRenderers.composite,
    table: tableRenderers.table,
    dialog: layoutRenderers.dialog
  });

  // Adapted from Nisugi's individual DOM style assignments. Native consumers
  // supply validated properties; no markup or CSS source is interpreted.
  function nativeTextStyle(element, props) {
    if (props.font_size !== undefined) element.style.fontSize = `${props.font_size}${props.font_unit || "pt"}`;
    if (props.font_family) element.style.fontFamily = props.font_family;
    if (props.font_style) element.style.fontStyle = props.font_style;
    if (props.foreground) element.style.color = compositeColor(props.foreground);
    if (props.background) element.style.backgroundColor = compositeColor(props.background);
  }

  /** Converts validated RGBA channels or semantic tones to a renderer-owned CSS color. */
  function compositeColor(value) {
    if (value && typeof value === "object" && "r" in value) return `rgba(${value.r}, ${value.g}, ${value.b}, ${value.a})`;
    const tone = typeof value === "string" ? value : value?.tone;
    return ({ neutral: "CanvasText", positive: "#27833e", caution: "#b57900", danger: "#b12a2a" })[tone] || "CanvasText";
  }

  /** Converts pointer coordinates back to original image pixels and includes an optional region ID. */
  function surfacePayload(event, surface, scale, button) {
    const bounds = surface.getBoundingClientRect();
    const modifiers = ["ctrl", "shift", "alt"].filter(key => event[`${key}Key`]);
    const payload = { x: Math.round((event.clientX - bounds.left) / scale),
      y: Math.round((event.clientY - bounds.top) / scale), button, modifiers };
    const region = event.target.closest?.(".composite-region");
    if (region) payload.region = region.dataset.region;
    return payload;
  }

  const widgetCoordinate = value => Math.max(-65536, Math.min(65536, Math.round(value)));

  /** Measures only the destination's declared children, in contract order. */
  function widgetAllocations(element, component) {
    const origin = element.getBoundingClientRect();
    const children = new Map([...element.querySelectorAll("[data-cid]")].map(child => [child.dataset.cid, child]));
    return (component.children || []).map(child => {
      const rect = children.get(child.cid)?.getBoundingClientRect();
      return { cid: child.cid, y: widgetCoordinate((rect?.top ?? origin.top) - origin.top),
        height: Math.max(0, Math.min(65536, Math.round(rect?.height || 0))) };
    });
  }

  /** Dispatches by contract type, leaving an explicit diagnostic node for unsupported types. */
  function render(page, component) {
    const inherited = page.renderDisabled;
    page.renderDisabled = inherited || component.props.disabled === true;
    if (page.renderDisabled) component = { ...component, props: { ...component.props, disabled: true } };
    try {
      return renderComponent(page, component);
    } finally {
      page.renderDisabled = inherited;
    }
  }

  /** Renders one effective component while recursive children inherit its sensitivity. */
  function renderComponent(page, component) {
    const renderer = renderers[component.type];
    if (!renderer) {
      const error = common(node("div", "renderer-error", `Renderer not implemented: ${component.type}`), component);
      error.dataset.error = "renderer_not_implemented";
      return error;
    }
    const element = renderer(page, component);
    // Keep widget transfers in this viewer and generation. Browser text/files
    // never authorize a drop, and nested targets consume only their own surface.
    if (component.props.drag_source && !component.props.disabled) {
      element.draggable = true;
      element.dataset.widgetDragSource = "true";
      element.addEventListener("pointerdown", () => holdPointer(page));
      element.addEventListener("dragstart", event => {
        if (event.target.closest("[data-widget-drag-source]") !== element || !element.isConnected) return;
        event.stopPropagation();
        page.widgetDrag = { source: component.cid, generation: page.generation };
        page.rowDragging = true; // Reuse render deferral through native dragend/drop.
        holdPointer(page);
        event.dataTransfer.effectAllowed = "move";
        event.dataTransfer.setData("application/x-lich-widget", component.cid);
      });
      element.addEventListener("dragend", () => { page.widgetDrag = null; });
    }
    if (component.props.drag_destination && bound(page, component.cid, "widget_drop")) {
      element.dataset.widgetDragDestination = "true";
      const accepts = event => page.widgetDrag?.generation === page.generation && !component.props.disabled &&
        element.isConnected && !element.closest("[hidden],[inert]") && event.target.closest("[data-widget-drag-destination]") === element;
      element.addEventListener("dragover", event => {
        if (!accepts(event)) return;
        event.preventDefault(); event.stopPropagation();
        event.dataTransfer.dropEffect = "move";
      });
      element.addEventListener("drop", event => {
        if (!accepts(event)) return;
        event.preventDefault(); event.stopPropagation();
        const source = page.widgetDrag.source;
        page.widgetDrag = null;
        const origin = element.getBoundingClientRect();
        emit(page, component, "widget_drop", { source, x: widgetCoordinate(event.clientX - origin.left),
          y: widgetCoordinate(event.clientY - origin.top), allocations: widgetAllocations(element, component) });
      });
    }

    if (bound(page, component.cid, "pointer_enter") || bound(page, component.cid, "pointer_leave")) {
      page.hoveredComponents ||= new Set();
      const rememberPointer = event => { page.hoverPointer = { x: event.clientX, y: event.clientY }; };
      element.addEventListener("pointermove", rememberPointer);
      element.addEventListener("pointerenter", event => {
        rememberPointer(event);
        // Suppressed enters must not poison hover tracking when re-enabled.
        if (component.props.disabled || page.element?.hidden) return;
        if (page.hoveredComponents.has(component.cid)) return;
        page.hoveredComponents.add(component.cid);
        emit(page, component, "pointer_enter");
      });
      const leave = event => {
        if (!element.isConnected || page.restoringFocus) return;
        if (event) rememberPointer(event);
        const point = page.hoverPointer;
        if (point && element.contains(document.elementFromPoint(point.x, point.y))) return;
        if (page.hoveredComponents.delete(component.cid)) emit(page, component, "pointer_leave");
      };
      (page.hoverElements ||= new Map()).set(component.cid, { element, leave });
      element.addEventListener("pointerleave", leave);
    }
    if (component.type === "page") {
      if (bound(page, component.cid, "key_press") || bound(page, component.cid, "key_release")) element.tabIndex = 0;
      for (const [native, name] of [["keydown", "key_press"], ["keyup", "key_release"]]) {
        if (!bound(page, component.cid, name)) continue;
        element.addEventListener(native, event => {
          if (event.isComposing) return;
          const keyval = event.key === "Escape" ? 0xff1b : [...event.key].length === 1 ? event.key.codePointAt(0) : null;
          if (keyval !== null) emit(page, component, name, { keyval, state: modifiers(event) });
        });
      }
    }
    if (bound(page, component.cid, "scroll")) {
      element.dataset.scrollSurface = "true";
      element.addEventListener("wheel", event => {
        if (!element.isConnected || event.target.closest("[data-scroll-surface]") !== element || component.props.disabled || element.closest("[hidden],[inert]")) return;
        event.preventDefault(); event.stopPropagation();
        const scale = event.deltaMode === 1 ? 16 : event.deltaMode === 2 ? window.innerHeight : 1;
        const pixels = value => widgetCoordinate(value * scale);
        const origin = element.getBoundingClientRect();
        queueWheel(page, component, pixels(event.deltaX), pixels(event.deltaY), modifiers(event),
          { x: widgetCoordinate(event.clientX - origin.left), y: widgetCoordinate(event.clientY - origin.top) });
      }, { passive: false });
    }
    if (component.props.pointer_events) {
      const press = (event, clickCount) => {
        if ((component.type === "button" && component.props.disabled) || event.target.closest("[data-pointer-surface]") !== element || event.button > 2) return;
        event.stopPropagation();
        emit(page, component, "pointer_press", { x: Math.round(event.clientX), y: Math.round(event.clientY),
          button: event.button + 1, time: Math.floor(event.timeStamp),
          state: modifiers(event), click_count: clickCount });
      };
      let pressed = null;
      element.addEventListener("pointerdown", event => {
        if (component.props.pointer_tracking && event.button === 0 && event.target.closest("[data-pointer-surface]") === element &&
            !component.props.disabled && !element.closest("[hidden],[inert]")) {
          event.preventDefault();
          startTrackedPointer(page, component, event);
          press(event, 1);
          return;
        }
        if (event.target.closest("[data-pointer-surface]") === element && event.button <= 2 &&
            !component.props.disabled && !element.closest("[hidden],[inert]")) {
          pressed = { id: event.pointerId, button: event.button };
          page.pointerRelease = pressed;
          if (bound(page, component.cid, "pointer_release")) holdPointer(page);
        }
        press(event, 1);
      });
      const cancelRelease = () => { pressed = null; };
      element.addEventListener("pointercancel", cancelRelease);
      element.addEventListener("dragstart", cancelRelease);
      element.addEventListener("pointerup", event => {
        const previous = pressed; pressed = null;
        if (!previous || page.pointerRelease !== previous || previous.id !== event.pointerId || previous.button !== event.button || component.props.disabled ||
            element.closest("[hidden],[inert]") || event.target.closest("[data-pointer-surface]") !== element) return;
        if (!bound(page, component.cid, "pointer_release")) return;
        event.stopPropagation();
        try {
          emit(page, component, "pointer_release", { x: Math.round(event.clientX), y: Math.round(event.clientY),
            button: event.button + 1, time: Math.floor(event.timeStamp), state: modifiers(event), click_count: 1 });
        } finally {
          // This handler stops bubbling, so document pointerup cannot release it.
          releasePointers(event);
        }
      });
      element.addEventListener("dblclick", event => press(event, 2));
      element.dataset.pointerSurface = "true";
      element.addEventListener("contextmenu", event => event.preventDefault());
    }
    return element;
  }

  /** Tracks a positioned canvas across paints without holding scroll updates until release. */
  function startTrackedPointer(page, component, event) {
    page.trackedPointer?.finish({ type: "replace" });
    const start = page.generation;
    let point = event, frame = null, ended = false;
    let deadline;
    const payload = () => ({ x: widgetCoordinate(point.clientX), y: widgetCoordinate(point.clientY), state: modifiers(point) });
    const current = () => page.tree && findComponent(page.tree, component.cid);
    const sample = () => {
      frame = null;
      const target = current();
      if (!ended && target?.props.pointer_tracking) emit(page, target, "pointer_motion", payload());
    };
    const move = next => {
      if (next.pointerId !== event.pointerId) return;
      point = next;
      if (frame == null) frame = window.requestAnimationFrame(sample);
    };
    const finish = next => {
      if (ended || (next.pointerId !== undefined && next.pointerId !== event.pointerId)) return;
      if (next.clientX !== undefined) point = next;
      ended = true;
      window.clearTimeout(deadline);
      if (frame != null) window.cancelAnimationFrame(frame);
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", finish);
      window.removeEventListener("pointercancel", finish);
      window.removeEventListener("blur", finish);
      document.body.removeEventListener("lostpointercapture", finish);
      page.trackedPointer = null;
      const target = current();
      if (target?.props.pointer_tracking) {
        // Release keeps the original server authority even though the DOM can repaint.
        const generation = page.generation;
        page.generation = start;
        emit(page, target, "pointer_release", { ...payload(), button: 1, time: Math.floor(point.timeStamp), click_count: 1 });
        page.generation = generation;
      }
      if (document.body.hasPointerCapture?.(event.pointerId)) document.body.releasePointerCapture(event.pointerId);
    };
    page.trackedPointer = { finish };
    window.addEventListener("pointermove", move);
    window.addEventListener("pointerup", finish);
    window.addEventListener("pointercancel", finish);
    window.addEventListener("blur", finish);
    document.body.addEventListener("lostpointercapture", finish);
    document.body.setPointerCapture?.(event.pointerId);
    // End before the server's 30-second release authority expires.
    deadline = window.setTimeout(() => finish({ type: "timeout" }), 25000);
  }

  /** Applies accepted viewer-local wheel deltas once, after scroll restoration. */
  function applyScrollRequests(page) {
    page.wheelRequests ||= new Map();
    const live = new Set();
    const visit = component => {
      if (component.props.scroll_request) {
        live.add(component.cid);
        const current = component.props.scroll_request;
        const previous = page.wheelRequests.get(component.cid) || { x: 0, y: 0 };
        const dx = current.x - previous.x, dy = current.y - previous.y;
        page.wheelRequests.set(component.cid, current);
        const element = page.element.querySelector(`[data-cid="${CSS.escape(component.cid)}"]`);
        let target = element;
        while (target && target !== page.element) {
          const style = window.getComputedStyle(target);
          if ((dx && /auto|scroll/.test(style.overflowX) && target.scrollWidth > target.clientWidth) ||
              (dy && /auto|scroll/.test(style.overflowY) && target.scrollHeight > target.clientHeight)) break;
          target = target.parentElement;
        }
        if (target === page.element) target = document.scrollingElement;
        if (target && !element?.closest("[hidden],[inert]")) {
          target.scrollLeft += dx; target.scrollTop += dy;
          if (target.dataset.cid && target.classList.contains("webui-scroll")) {
            (page.scrollOffsets ||= new Map()).set(target.dataset.cid, target.scrollTop);
            (page.horizontalScrollOffsets ||= new Map()).set(target.dataset.cid, target.scrollLeft);
          }
        }
      }
      component.children?.forEach(visit);
    };
    visit(page.tree);
    for (const cid of page.wheelRequests.keys()) if (!live.has(cid)) page.wheelRequests.delete(cid);
  }

  /**
   * Applies page facilities, delegating OS presentation only for the owning root.
   * Native alpha replaces CSS opacity; in-window modals retain their parent's window.
   * @param {Object} page Rendered page state with properties and facility overrides.
   */
  function applyFacilities(page) {
    const facilities = page.facilities || {};
    const presentation = { ...page.windowProps?.presentation, ...facilities.presentation };
    const ownsWindow = !requestedPage || page.address === requestedPage;
    const nativeOpacity = ownsWindow && (window.lichNativeWindow || page.windowPresentation?.opacity);
    page.element.style.opacity = nativeOpacity ? "" : (presentation.opacity ?? "");
    page.element.hidden = presentation.hidden === true;
    // Only the requested root owns the native window. In-window modals retain
    // their parent's title, level and geometry. Browsers have no native bridge.
    if (!requestedPage || page.address === requestedPage) {
      window.lichNativeWindow?.present({ ...presentation, title: page.windowProps.title,
        min_width: page.windowProps.min_width, min_height: page.windowProps.min_height });
    }
    if (facilities.geometry) {
      if (facilities.geometry.width > 0) page.element.style.width = `${facilities.geometry.width}px`;
      if (facilities.geometry.height > 0) page.element.style.minHeight = `${facilities.geometry.height}px`;
    }
    if (facilities.focus && (facilities.focus_revision === undefined || page.focusRevision !== facilities.focus_revision)) {
      const focusRoot = page.element.querySelector(`[data-cid="${CSS.escape(facilities.focus)}"]`);
      const focusTarget = focusRoot?.matches("input, select, button, textarea")
        ? focusRoot
        : focusRoot?.querySelector("input, select, button, textarea");
      if (focusTarget) {
        focusTarget.focus();
        if (document.activeElement === focusTarget) page.focusRevision = facilities.focus_revision;
      }
    }
    if (facilities.announce) {
      announcer.setAttribute("aria-live", facilities.announce.politeness);
      announcer.textContent = facilities.announce.text;
    }
    if (facilities.notify) notify(facilities.notify.text, facilities.notify.level);
  }

  document.addEventListener("pointerdown", event => {
    if (!event.target.closest?.(".webui-context-menu")) pages.forEach(hideContextMenu);
    pages.forEach(page => page.popovers?.forEach(entry => {
      if (!entry.group.contains(event.target)) entry.close();
    }));
  });
  document.addEventListener("keydown", event => {
    if (event.key !== "Escape") return;
    pages.forEach(page => {
      page.popovers?.forEach(entry => {
        if (entry.trigger.getAttribute("aria-expanded") === "true") {
          entry.close(); entry.trigger.focus(); event.preventDefault();
        }
      });
      page.contextMenus?.forEach(menu => {
        if (menu.style.display === "none") return;
        // There is one selected branch. Its last expanded trigger is deepest.
        const expanded = [...menu.querySelectorAll('.submenu-trigger[aria-expanded="true"]')].at(-1);
        if (expanded) {
          hideSubmenus(expanded.parentElement, page);
          expanded.focus();
        } else hideContextMenu(page);
        event.preventDefault();
      });
    });
  });
  // A blur can commit an edited cell during a Save button's pointerdown.
  // Preserve that button through pointerup/click before applying the response.
  function holdPointer(page) {
    page.pointerActive = true;
    page.pointerEpoch = (page.pointerEpoch || 0) + 1;
  }
  const releasePointers = event => {
    const endingDrag = ["drop", "dragend", "blur"].includes(event.type);
    const releases = [...pages.values()].map(page => {
      page.pointerRelease = null;
      if (endingDrag) { page.rowDragging = false; page.widgetDrag = null; }
      return [page, page.pointerEpoch || 0];
    });
    window.setTimeout(() => releases.forEach(([page, epoch]) => {
      // Chrome cancels its pointer stream when native HTML dragging takes over.
      // Also ignore a previous gesture's delayed release after a new press.
      if (page.rowDragging || (page.pointerEpoch || 0) !== epoch) return;
      page.pointerActive = false;
      if (!page.editingCell && !page.splitDragging && !page.columnDragging && page.deferredRender) {
        const deferred = page.deferredRender; page.deferredRender = null; acceptRender(deferred);
      }
    }), 0);
  };
  document.addEventListener("pointerup", releasePointers);
  document.addEventListener("pointercancel", releasePointers);
  // Native HTML drags can end without pointerup/cancel. Release the render
  // after drop handlers finish, or after a cancelled drag, without another click.
  document.addEventListener("drop", releasePointers);
  document.addEventListener("dragend", releasePointers);
  window.addEventListener("blur", releasePointers);

  /** Canonicalizes modifier ordering to match registered page accelerator tokens. */
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
      // An explicitly registered shortcut may own a keyboard-only action.
      // Ordinary controls inside inactive tabs still cannot receive shortcuts.
      if (!target || target.disabled || (!target.hidden && target.getClientRects().length === 0)) continue;
      event.preventDefault();
      target.click();
      break;
    }
  });

  /**
   * Admits the current generation or retains only the newest gesture-deferred tree.
   * @param {Object} page Attached page whose gesture flags own render deferral.
   * @param {Object} message Server render envelope.
   * @returns {boolean} Whether replacement may proceed now.
   */
  function admitRender(page, message) {
    if (message.generation < page.generation) return false;
    // Keep the active pointer target alive through periodic meter renders.
    // Only the latest tree is retained and applied when the gesture finishes.
    if (page.splitDragging || page.columnDragging || page.editingCell || page.pointerActive || page.rowDragging) {
      if (!page.deferredRender || message.generation > page.deferredRender.generation) page.deferredRender = message;
      return false;
    }
    return true;
  }

  /**
   * Stops old geometry reporting and captures drafts, acknowledgement state and focus.
   * @param {Object} page Current DOM, controls and comparison bases.
   * @param {Object} message Incoming tree and optional input acknowledgements.
   * @returns {Object} Replacement-local state; sensitive values never enter page.bases.
   */
  function captureRenderState(page, message) {
    stopWindowGeometry(page);
    // Reuse the draft/base comparison from PR1650, restricted to stable cids.
    // A deliberate server value change wins; unrelated renders preserve typing.
    const edits = [];
    const active = document.activeElement;
    const pageFocus = active === page.element && active.tabIndex === 0 ? active.dataset.cid : null;
    const activeRow = active?.closest?.("tr[data-row-key]");
    const tableFocus = activeRow && page.element?.contains(activeRow) ? {
      cid: activeRow.closest("[data-cid]")?.dataset.cid, row: activeRow.dataset.rowKey,
      column: active.closest("td")?.dataset.columnKey
    } : null;
    const menuState = captureMenuNavigation(page);
    // Preserve an open menu's original target, not its currently focused item.
    // A newly server-opened menu needs the origin before replaceWith detaches it.
    const menuReturnFocus = page.contextMenuPosition ? page.contextMenuReturnFocus : contextMenuFocus(page, active);
    let focus = null;
    for (const [cid, control] of page.controls || []) {
      const base = page.bases?.get(cid);
      if (control === active) focus = { cid, start: control.selectionStart, end: control.selectionEnd };
      const sensitive = control.type === "password" || control.dataset.sensitive === "true";
      const outstanding = [...pending.values()].find(record => record.liveText && record.message.page === page.address && record.message.cid === cid);
      const acknowledged = outstanding && message.input_requests !== undefined &&
        (message.input_requests[cid] || 0) >= outstanding.message.request;
      const live = outstanding && message.input_requests !== undefined && !acknowledged;
      if (live || sensitive || (base !== undefined && controlValue(control) !== base)) {
        edits.push({ cid, base, value: controlValue(control), password: sensitive, live, acknowledged });
      }
    }
    // Plain action buttons are not input values. Retain their exact component
    // identity independently so a redraw cannot swallow the following Enter.
    if (!focus && active?.matches?.('button[data-component-type="button"]') && page.element?.contains(active)) {
      focus = { cid: active.dataset.cid, action: true };
    }
    return { edits, focus, pageFocus, tableFocus, menuState, menuReturnFocus };
  }

  /** Disconnects the current observer set; callers decide whether to reset or discard it. */
  function disconnectLayoutObservers(page) {
    page?.layoutObservers?.forEach(observer => observer.disconnect());
  }

  /** Disposes current input listeners/timers without changing close or disconnect policy. */
  function disposeRenderInputs(page) {
    page?.inputDisposers?.forEach(dispose => dispose());
  }

  /**
   * Adopts accepted metadata, resets render registries, then retires old resources.
   * Observer and input arrays reset separately in their original order. Page closure
   * uses the same disposals without adopting metadata or resetting those arrays.
   * @param {Object} page Existing page and resource owner.
   * @param {Object} message Accepted render metadata and tree.
   * @returns {void}
   */
  function retireRender(page, message) {
    page.generation = message.generation;
    page.bindings = message.bindings || {};
    page.submissions = message.submissions || {};
    page.facilities = message.facilities || {};
    page.windowPresentation = message.window_presentation || {};
    page.resume = message.resume;
    page.tree = message.tree;
    if (page.hoveredComponents) {
      for (const cid of page.hoveredComponents) if (!findComponent(page.tree, cid)) page.hoveredComponents.delete(cid);
    }
    page.hoverElements = new Map();
    page.controls = new Map();
    page.unscrolledTableMinimum = false;
    page.contextMenus = new Map();
    page.popovers = new Map();
    page.tableFocusRequests = [];
    disconnectLayoutObservers(page);
    page.layoutObservers = [];
    disposeRenderInputs(page);
    page.inputDisposers = [];
  }

  /**
   * Constructs/replaces the DOM under mechanical-blur suppression and opens menus.
   * @param {Object} page Page with accepted metadata and empty render registries.
   * @param {Object} message Accepted render envelope.
   * @param {Object} state Captured origin for menu focus restoration.
   * @returns {Array|undefined} Server-requested menu entry, retaining focus priority.
   */
  function installRender(page, message, state) {
    const { menuReturnFocus } = state;
    const next = render(page, message.tree);
    next.dataset.pageAddress = page.address;
    // Chrome blurs the old textarea during replacement, before focus is restored.
    // That redraw is not a user focus-out; suppress only this mechanical blur.
    const previousRestoringFocus = page.restoringFocus;
    page.restoringFocus = true;
    try {
      if (page.element) page.element.replaceWith(next); else pagesNode.append(next);
    } finally { page.restoringFocus = previousRestoringFocus; }
    page.element = next;
    const hoverElements = page.hoverElements;
    window.requestAnimationFrame(() => {
      if (page.hoverElements !== hoverElements) return;
      hoverElements?.forEach(({ element, leave }, cid) => {
        if (page.hoveredComponents?.has(cid)) leave();
      });
    });
    page.openPopovers?.forEach(cid => {
      const entry = page.popovers.get(cid);
      if (entry && !entry.trigger.disabled && !entry.group.closest("[hidden],[inert]")) entry.open();
      else page.openPopovers.delete(cid);
    });
    equalizeWidthGroups(page);
    const requestedMenu = [...page.contextMenus.entries()].find(([, menu]) => menu.menuComponent?.props.open === true);
    if (requestedMenu) {
      const [key, menu] = requestedMenu;
      const [x, y] = menu.menuComponent.props.popup_position || [0, 0];
      showContextMenu(page, key, x, y, menuReturnFocus);
    } else if (page.contextMenuPosition) {
      const { key, x, y } = page.contextMenuPosition;
      const menu = page.contextMenus.get(key);
      if (menu && menu.menuComponent?.props.open === undefined) showContextMenu(page, key, x, y, menuReturnFocus);
      else page.contextMenuPosition = null;
    }
    trackPageGeometry(page, message.tree);
    trackWindowState(page, message.tree);
    return requestedMenu;
  }

  /**
   * Restores eligible drafts, menu/table/input/page focus and page facilities in order.
   * @param {Object} page Newly installed DOM and controls.
   * @param {Object} message Accepted acknowledgements for pending live text.
   * @param {Object} state Captured drafts and focus identities.
   * @param {Array|undefined} requestedMenu Server-requested menu with focus priority.
   * @returns {void}
   */
  function restoreRenderState(page, message, state, requestedMenu) {
    const { edits, focus, pageFocus, tableFocus, menuState } = state;
    page.bases = new Map([...page.controls].filter(([, control]) => control.dataset.sensitive !== "true")
      .map(([cid, control]) => [cid, controlValue(control)]));
    for (const edit of edits) {
      const control = page.controls.get(edit.cid);
      if (!control || edit.acknowledged || (!edit.live && !edit.password && page.bases.get(edit.cid) !== edit.base)) continue;
      if (edit.live && (control.disabled || control.closest("[hidden],[inert]"))) continue;
      if (control.type === "checkbox") control.checked = edit.value;
      else if (control.restoreChoice) control.restoreChoice(edit.value);
      else control.value = edit.value;
    }
    discardPending(record => record.liveText && record.message.page === page.address &&
      (!page.controls.has(record.message.cid) || (message.input_requests?.[record.message.cid] || 0) >= record.message.request));
    restoreMenuNavigation(page, menuState);
    // Resolve table focus by identities after replacement, never by a stale row index.
    if (!requestedMenu && !menuState?.focus) {
      const target = page.tableFocusRequests.at(-1) || tableFocus;
      if (target) {
        const wrapper = [...page.element.querySelectorAll(".webui-table-wrap")].find(element => element.dataset.cid === target.cid);
        const row = [...(wrapper?.querySelectorAll("tr[data-row-key]") || [])].find(element => element.dataset.rowKey === target.row);
        const cell = target.column && [...(row?.children || [])].find(element => element.dataset.columnKey === target.column);
        if (row && !wrapper.inert) {
          const focusable = cell?.querySelector("input,select") || row;
          if (!focusable.disabled) { focusable.focus(); if (page.tableFocusRequests.length) row.scrollIntoView?.({ block: "nearest" }); }
        }
      }
    }
    // Menu restoration also covers triggers and plain action buttons, which do
    // not appear in the form-control map. Never refocus a now-closed menu input.
    const focused = !menuState?.focus && focus && (focus.action
      ? [...page.element.querySelectorAll('button[data-component-type="button"]')].find(button => button.dataset.cid === focus.cid)
      : page.controls.get(focus.cid));
    if (focused && !focused.disabled && !focused.closest("[hidden],[inert]") &&
        (!requestedMenu || focused.closest(".webui-context-menu"))) {
      page.restoringFocus = true;
      try {
        focused.focus({ preventScroll: true });
        if (Number.isInteger(focus.start)) focused.setSelectionRange(focus.start, focus.end);
      } finally { page.restoringFocus = false; }
    }
    // A pointer action can focus the keyboard-enabled page itself. Replacing
    // that root must not strand the next key on the document outside its handlers.
    // Menu and explicit server focus retain priority over this local restoration.
    const presentation = { ...page.windowProps?.presentation, ...page.facilities.presentation };
    if (pageFocus === page.element.dataset.cid && page.element.tabIndex === 0 &&
        !page.element.hidden && !page.element.inert && !presentation.hidden &&
        !requestedMenu && !menuState?.focus) {
      page.element.focus({ preventScroll: true });
    }
    applyFacilities(page);
    const scrollRoot = page.element;
    window.requestAnimationFrame(() => {
      if (page.element === scrollRoot) applyScrollRequests(page);
    });
  }

  /**
   * Revalidates retained intents only after the accepted tree and local state are ready.
   * Transport, scope checks and replay limits remain owned by emit and pending.
   * @param {Object} page Fully restored page and current server-declared scopes.
   * @returns {void}
   */
  function replayRenderIntents(page) {
    for (const [request, record] of pending) {
      if (record.message.page !== page.address) continue;
      const component = findComponent(page.tree, record.message.cid);
      if (record.tabSelection && !canRetryTab(page, component, record)) {
        dropPending(request);
        continue;
      }
      if (!record.replay) continue;
      dropPending(request);
      const scope = page.submissions[record.message.cid] || [];
      if (!component || component.props.disabled || component.props.hidden ||
          JSON.stringify(scope) !== JSON.stringify(record.scope)) continue;
      let payload = record.message.payload;
      if (record.message.event === "widget_drop") {
        const source = findComponent(page.tree, payload.source);
        const ids = (component.children || []).map(child => child.cid);
        if (!component.props.drag_destination || !source?.props.drag_source || source.props.drag_source !== record.dragSourceKey ||
            source.props.disabled || source.props.hidden || JSON.stringify(ids) !== JSON.stringify(payload.allocations.map(child => child.cid))) continue;
        const element = [...page.element.querySelectorAll("[data-cid]")].find(child => child.dataset.cid === component.cid);
        if (!element || element.closest("[hidden],[inert]")) continue;
        // Retry the insertion intent, not old pixel measurements. A changed
        // child set/order retires the drop instead of moving a different item.
        let index = payload.allocations.findIndex(child => payload.y < child.y + child.height / 2);
        if (index < 0) index = ids.length;
        const allocations = widgetAllocations(element, component);
        const y = index < allocations.length ? Math.ceil(allocations[index].y + allocations[index].height / 2) - 1 :
          allocations.length ? allocations.at(-1).y + allocations.at(-1).height : 0;
        payload = { ...payload, y: widgetCoordinate(y), allocations };
      }
      emit(page, component, record.message.event, payload, record);
    }
  }

  /**
   * Coordinates admission, capture, retirement, installation, restoration and replay.
   * Native-presentation metadata travels with the accepted tree and its facilities.
   * @param {Object} message Server render envelope for an attached page.
   * @returns {void}
   */
  function acceptRender(message) {
    const page = pages.get(message.page);
    if (!page || !admitRender(page, message)) return;
    const state = captureRenderState(page, message);
    retireRender(page, message);
    const requestedMenu = installRender(page, message, state);
    restoreRenderState(page, message, state, requestedMenu);
    replayRenderIntents(page);
  }

  /** Displays a literal, temporary status notice without interpreting message markup. */
  function notify(text, level = "info") {
    const message = node("div", `notification ${level}`, text);
    notifications.append(message);
    window.setTimeout(() => message.remove(), 5000);
  }

  /**
   * Routes server envelopes, keeping page selection and modal routing within this window.
   * A stale-event retry requires matching request/page/control/event correlation; other
   * refusals do not replay user actions. The server still validates all routing authority.
   */
  function receive(event) {
    const message = JSON.parse(event.data);
    if (message.type === "hello" || message.type === "pages") {
      if (message.type === "hello" && message.limits) wireLimits = message.limits;
      statusNode.textContent = "Connected";
      message.pages.forEach((descriptor) => {
        if (requestedPage && descriptor.address !== requestedPage &&
            !descriptor.modal_for?.includes(requestedPage)) return;
        if (descriptor.title && (!requestedPage || descriptor.address === requestedPage)) document.title = descriptor.title;
        const page = pages.get(descriptor.address) || { address: descriptor.address };
        pages.set(descriptor.address, page);
        // Opening or closing a modal announces the page list again. Resuming a
        // live attachment is refused by the core and must not reset its drafts.
        if (message.type === "pages" && page.attaching) return;
        page.attaching = true;
        socket.send(JSON.stringify({ type: "attach", page: descriptor.address, version: VERSION, resume: page.resume }));
      });
    } else if (message.type === "render") acceptRender(message);
    else if (message.type === "clear_sensitive") {
      discardPending(record => record.scope.some(cid => message.cids.includes(cid)));
      pages.forEach((page) => message.cids.forEach((cid) => {
        const control = page.controls?.get(cid); if (control) control.value = "";
        page.bases?.delete(cid);
      }));
    }
    else if (message.type === "page_closed") {
      pages.get(message.page)?.trackedPointer?.finish({ type: "close" });
      discardPending(record => record.message.page === message.page);
      disconnectLayoutObservers(pages.get(message.page));
      disposeRenderInputs(pages.get(message.page));
      if (pages.has(message.page)) {
        clearWheel(pages.get(message.page));
        stopWindowGeometry(pages.get(message.page));
        stopWindowState(pages.get(message.page));
      }
      pages.get(message.page)?.element?.remove();
      pages.delete(message.page);
    } else if (message.type === "refusal") {
      if (message.reason === "stale_generation" && message.event === "scrolled") {
        pages.get(message.page)?.scrollMeasurements?.delete(message.cid);
      }
      const record = pending.get(message.request);
      const matches = record && ["page", "cid", "event"].every(key => record.message[key] === message[key]);
      // A superseded/acknowledged edit no longer has retry authority or a
      // user-visible failure. Only a still-correlated intent may report staleness.
      if (message.reason === "stale_generation" && !matches) return;
      if (message.reason === "stale_generation" && matches &&
          (record.tabSelection ? Date.now() < record.tabSelection.deadline : record.attempt === 0)) {
        record.replay = true;
      } else {
        if (matches) dropPending(message.request);
        if (!(message.reason === "stale_generation" && message.event === "scrolled")) {
          notify(message.message || "Request refused", "error");
        }
      }
    }
  }

  /** Reconnects the authenticated same-origin socket with bounded backoff and clears old retries. */
  function connect() {
    const scheme = window.location.protocol === "https:" ? "wss:" : "ws:";
    socket = new WebSocket(`${scheme}//${window.location.host}/ws`);
    socket.addEventListener("open", () => { reconnectDelay = 250; });
    socket.addEventListener("message", receive);
    socket.addEventListener("close", () => {
      pages.forEach(page => page.trackedPointer?.finish({ type: "disconnect" }));
      discardPending(() => true);
      pages.forEach(clearWheel);
      statusNode.textContent = "Disconnected; reconnecting";
      window.setTimeout(connect, reconnectDelay);
      reconnectDelay = Math.min(5000, reconnectDelay * 2);
    });
    socket.addEventListener("error", () => socket.close());
  }

  /** Sends intentional detach with final geometry; transport loss alone remains resumable. */
  function detachPages() {
    if (!socket || socket.readyState !== WebSocket.OPEN) return;
    pages.forEach((page) => {
      flushWheel(page);
      page.splitDragging = false;
      page.editingCell = false;
      page.pointerActive = false;
      page.rowDragging = false;
      if (page.deferredRender) { const deferred = page.deferredRender; page.deferredRender = null; acceptRender(deferred); }
      if (!Number.isInteger(page.generation)) return;
      page.reportGeometry?.();
      socket.send(JSON.stringify({
        type: "detach", page: page.address, generation: page.generation,
        ...(!requestedPage || page.address === requestedPage ? { geometry: JSON.parse(windowGeometry(true)) } : {})
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
