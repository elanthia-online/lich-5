(() => {
  "use strict";
  const families = window.LichWebUIRendererFamilies ||= Object.create(null);

  /**
   * Builds structural containers while the application retains page and gesture lifetimes.
   * Loading registers only this factory; it does not create DOM, listeners or sockets.
   * @param {Object} context Explicit capabilities; no page map or transport state.
   * @param {Function} context.node Creates literal DOM nodes.
   * @param {Function} context.common Applies validated common properties.
   * @param {Function} context.emit Sends admitted events through the central transport.
   * @param {Function} context.appendChildren Recursively renders children in contract order.
   * @param {Function} context.render Renders one component through the central dispatcher.
   * @param {Function} context.observeAllocation Registers observers owned by the current render.
   * @param {string|null} context.requestedPage Selects which page may update the document title.
   * @param {Function} context.holdPointer Defers replacement until the active press completes.
   * @param {Function} context.compositeColor Maps validated colors to renderer-owned CSS.
   * @param {Function} context.modifiers Encodes native modifier flags.
   * @param {Function} context.acceptRender Returns deferred updates to the lifecycle coordinator.
   * @returns {Object} Renderer functions.
   */
  families.layout = function createLayoutRenderers({
    node, common, emit, appendChildren, render, observeAllocation, requestedPage, holdPointer, compositeColor, modifiers, acceptRender
  }) {
    // Some source grids spread a spanning child's minimum-height deficit over
    // every covered row, including occupied rows. CSS auto tracks instead favor
    // empty rows. Measure natural children at the current column widths; never
    // substitute fixed heights captured from one window or font size.
    function spreadGridRows(page, component, grid) {
      observeAllocation(page, grid, () => {
        if (!grid.isConnected || !grid.getClientRects().length) return;
        // Property patches may arrive separately from a new child tree; retain
        // ordinary CSS allocation until explicit row placements are available.
        if ((component.children || []).some(child => !Number.isInteger(child.placement?.row))) return;
        grid.style.gridTemplateRows = "none";
        const items = (component.children || []).map((child, index) => {
          const cell = grid.children[index];
          if (!cell || child.props.hidden) return null;
          const alignment = cell.style.alignSelf, height = cell.style.height;
          cell.style.alignSelf = "start"; cell.style.height = "auto";
          const style = window.getComputedStyle(cell);
          const minimum = cell.getBoundingClientRect().height +
            (parseFloat(style.marginTop) || 0) + (parseFloat(style.marginBottom) || 0);
          cell.style.alignSelf = alignment; cell.style.height = height;
          return { row: child.placement.row - 1, span: child.placement.row_span || 1, minimum };
        }).filter(Boolean);
        if (!items.length) return;
        const gap = component.props.row_gap ?? component.props.gap ?? 8;
        const rows = Array(Math.max(...items.map(item => item.row + item.span))).fill(0);
        // Resolve smaller constraints first, then share each remaining deficit.
        // This retains sparse source rows rather than deleting their allocation.
        items.sort((a, b) => a.span - b.span).forEach(item => {
          const occupied = rows.slice(item.row, item.row + item.span).reduce((sum, height) => sum + height, 0);
          const extra = Math.max(0, item.minimum - occupied - gap * (item.span - 1)) / item.span;
          for (let row = item.row; row < item.row + item.span; row++) rows[row] += extra;
        });
        grid.style.gridTemplateRows = rows.map(height => `${height}px`).join(" ");
      });
    }

    const controls = {
      expander(page, component) {
        const details = common(node("details", "webui-expander"), component);
        details.open = component.props.open === true;
        let lastOpen = details.open;
        details.append(node("summary", null, component.props.label));
        // Collapsed content remains mounted so terminal submissions include its
        // inputs. Ignore the browser's initial toggle notification on rendering.
        appendChildren(page, component, details);
        details.addEventListener("toggle", () => {
          if (details.open === lastOpen) return;
          lastOpen = details.open;
          emit(page, component, "toggle", { open: details.open });
        });
        return details;
      },
      /** Builds the page root and retains its properties for native presentation updates. */
      page(page, component) {
        const root = common(node("section", "webui-page"), component);
        page.windowProps = component.props;
        if (!requestedPage || page.address === requestedPage) document.title = component.props.title;
        root.classList.toggle("webui-page-bare", component.props.bare === true);
        if (component.props.theme) root.dataset.theme = component.props.theme;
        if (component.props.density) root.dataset.density = component.props.density;
        if (component.props.viewport) root.dataset.viewport = "true";
        root.addEventListener("pointerdown", () => holdPointer(page));
        if (!component.props.bare) root.append(node("h1", null, component.props.title));
        return appendChildren(page, component, root);
      },
      stack(page, component) {
        const stack = common(node("div", "webui-stack"), component);
        stack.style.gap = `${component.props.gap ?? 8}px`;
        if (component.props.orientation === "horizontal") {
          stack.style.flexDirection = "row";
          stack.style.flexWrap = "nowrap";
          if (component.props.align === "center") stack.style.justifyContent = "center";
        }
        appendChildren(page, component, stack);
        if (component.props.content_align && component.children?.length === 1) {
          stack.style.display = "grid";
          stack.style.gridTemplateRows = "minmax(min-content, 1fr)";
          stack.firstElementChild.style.alignSelf = component.props.content_align;
        }
        return stack;
      },
      columns(page, component) {
        const columns = common(node("div", "webui-columns"), component);
        if (component.props.compact) columns.dataset.compact = "true";
        // Center short content, but never place the beginning of overflowing text
        // above its scroll origin where the user cannot reach it.
        if (component.props.row_align) columns.style.alignItems = component.props.row_align === "center" ? "safe center" : component.props.row_align;
        const weights = component.props.weights || Array(component.props.count).fill(1);
        columns.style.gridTemplateColumns = weights.map((weight) => weight === 0 ? "max-content" : `${weight}fr`).join(" ");
        columns.style.gap = `${component.props.gap ?? 8}px`;
        (component.children || []).forEach((child) => {
          const childNode = render(page, child);
          childNode.style.gridColumn = String(Number(child.slot) + 1);
          columns.append(childNode);
        });
        return columns;
      },
      grid(page, component) {
        const grid = common(node("div", "webui-grid"), component);
        grid.style.gridTemplateColumns = `repeat(${component.props.cols}, ${component.props.homogeneous === false ? "auto" : "minmax(0, 1fr)"})`;
        if (component.props.homogeneous === false) {
          const expanding = component.props.expand_columns || [];
          if (expanding.length) {
            // Auto tracks share surplus space above their natural widths. Fixed
            // peers stay content-sized; equal fr tracks would erase that distinction.
            grid.style.gridTemplateColumns = Array.from({ length: component.props.cols },
              (_, index) => expanding.includes(index + 1) ? "auto" : "max-content").join(" ");
            grid.style.justifyContent = "stretch";
          } else {
            // Natural tracks must still let scroll containers fit their allocation.
            // Inline controls contribute their own minimum below; long list text
            // must not turn an entire column into a max-content track.
            grid.style.justifyContent = component.props.align === "end" ? "end" : "start";
          }
        }
        // Equal natural row tracks differ from spreading surplus height: each
        // occupied row receives the same fraction, including multi-row content.
        if (component.props.equal_rows) grid.style.gridAutoRows = "1fr";
        grid.style.gap = `${component.props.gap ?? 8}px`;
        if (component.props.row_gap !== undefined) grid.style.rowGap = `${component.props.row_gap}px`;
        if (component.props.column_gap !== undefined) grid.style.columnGap = `${component.props.column_gap}px`;
        (component.children || []).forEach((child) => {
          const cell = render(page, child);
          if (child.props.vertical_align) cell.style.alignSelf = child.props.vertical_align;
          const placement = child.placement || {};
          if (!component.props.flow) {
            cell.style.gridColumn = `${placement.column ? placement.column + " / " : ""}span ${placement.span ?? 1}`;
            cell.style.gridRow = `${placement.row ? placement.row + " / " : ""}span ${placement.row_span ?? 1}`;
          }
          if (child.props.align) cell.style.justifySelf = child.props.align;
          if (["scroll", "table"].includes(child.type) && child.props.width === undefined) {
            // A scroller consumes its grid allocation; its longest row must not
            // enlarge max-content tracks spanned by the scrolling viewport.
            // Leave width auto so grid stretching subtracts the source margins.
            cell.style.contain = "inline-size";
            if (child.props.min_width === undefined) cell.style.minWidth = "0px";
          }
          if (child.type === "scroll" && child.props.height === undefined && placement.row &&
              (!child.props.vertical_align || child.props.vertical_align === "stretch") &&
              (component.children || []).some(peer => peer !== child && peer.placement?.row === placement.row &&
                (peer.placement.row_span || 1) === (placement.row_span || 1) && Number.isFinite(peer.props.height))) {
            // An unsized scroller alongside an explicitly allocated peer consumes
            // that row's height. Its document must not become the row's minimum.
            cell.style.contain = "size";
            cell.style.minHeight = `${child.props.min_height || 0}px`;
            cell.style.alignSelf = child.props.vertical_align || "stretch";
          }
          if (component.props.homogeneous === false && !(component.props.expand_columns || []).length &&
              (child.props.inline || ["checkbox", "radio_option"].includes(child.type)) && ["text_input", "number_input", "select", "checkbox", "radio_option"].includes(child.type) &&
              child.props.min_width === undefined && !child.props.max_width_chars) {
            // Keep an inline label and control together without imposing the same
            // minimum on scrollable peers or explicitly capped entry fields.
            cell.style.minWidth = "max-content";
          }
          grid.append(cell);
        });
        if (component.props.flow) {
          const allocate = () => {
            if (!grid.isConnected || grid.clientWidth <= 0) return;
            const gap = component.props.column_gap ?? component.props.gap ?? 8;
            const cells = [...grid.children].filter(cell => !cell.hidden);
            const authoredWidths = cells.map(cell => cell.style.width);
            cells.forEach(cell => { cell.style.width = "max-content"; });
            const widths = cells.map(cell => Math.max(cell.scrollWidth, cell.getBoundingClientRect().width));
            cells.forEach((cell, index) => { cell.style.width = authoredWidths[index]; });
            const natural = Math.max(1, ...widths);
            const columns = Math.max(1, Math.min(component.props.cols, Math.floor((grid.clientWidth + gap) / (natural + gap))));
            const tracks = `repeat(${columns}, ${component.props.homogeneous === false ? "max-content" : "minmax(0, 1fr)"})`;
            if (grid.style.gridTemplateColumns !== tracks) grid.style.gridTemplateColumns = tracks;
          };
          window.requestAnimationFrame(allocate);
          if (window.ResizeObserver) {
            const observer = new window.ResizeObserver(allocate);
            observer.observe(grid);
            (page.layoutObservers ||= []).push(observer);
          }
          window.addEventListener("resize", allocate);
          (page.inputDisposers ||= []).push(() => window.removeEventListener("resize", allocate));
          document.fonts?.ready.then(allocate);
        }
        if (component.props.row_sizing === "spread" && !component.props.equal_rows) spreadGridRows(page, component, grid);
        return grid;
      },
      // alias/vars use vertical adjustments. Retain offsets locally across tree
      // replacement and report actual layout measurements only when they change.
      scroll(page, component) {
        const element = common(node("div", "webui-scroll"), component);
        element.style.overflow = "auto";
        if (component.props.fill) { element.style.flex = "1"; element.style.minHeight = `${Math.max(0, component.props.min_height || 0)}px`; element.style.height = "0px"; }
        if (component.props.scrollbars === false) element.style.scrollbarWidth = "none";
        appendChildren(page, component, element);
        const alignedChild = component.children?.length === 1 && component.children[0].props.vertical_align;
        if (alignedChild) {
          // Give the child a vertical allocation without turning align-self into
          // a flex cross-axis request. The min-content row grows when content
          // overflows, keeping its beginning reachable for center/end alignment.
          element.style.display = "grid";
          element.style.gridTemplateColumns = "minmax(0, 1fr)";
          element.style.gridTemplateRows = "minmax(min-content, 1fr)";
          const child = element.firstElementChild;
          child.style.alignSelf = alignedChild;
          if (component.children[0].props.height === undefined) child.style.height = "auto";
        }
        // A lone table owns the whole viewport, including its empty drop area.
        // Propagate allocation through transparent vertical wrappers; keep mixed
        // content and explicitly sized children under their existing layout rules.
        const path = [];
        let parent = component, parentNode = element;
        while (!alignedChild && parent.children?.length === 1) {
          const child = parent.children[0], childNode = parentNode.firstElementChild;
          if (!childNode || child.props.hidden || child.props.height !== undefined) break;
          path.push(childNode);
          if (child.type === "table") {
            element.style.display = "flex";
            element.style.flexDirection = "column";
            path.forEach(node => { node.style.flex = "1 0 auto"; node.style.height = "auto"; });
            // The outer viewport owns overflow; the table retains its natural row
            // height while its border/drop surface grows to the available minimum.
            childNode.style.contain = "none";
            childNode.style.overflow = "visible";
            break;
          }
          if (child.type !== "stack" || child.props.orientation === "horizontal") break;
          parent = child; parentNode = childNode;
        }
        const offsets = page.scrollOffsets ||= new Map();
        const horizontalOffsets = page.horizontalScrollOffsets ||= new Map();
        const requests = page.scrollRequests ||= new Map();
        const requested = component.props.scroll_position;
        const requestedX = component.props.scroll_position_x;
        const revision = component.props.scroll_revision || 0;
        const revisionX = component.props.scroll_revision_x || 0;
        const report = () => {
          if (!element.isConnected) return;
          const pixels = value => Math.round(value);
          const payload = {
            position: pixels(element.scrollTop), upper: pixels(element.scrollHeight),
            page_size: pixels(element.clientHeight), position_x: pixels(element.scrollLeft),
            upper_x: pixels(element.scrollWidth), page_size_x: pixels(element.clientWidth)
          };
          offsets.set(component.cid, payload.position);
          horizontalOffsets.set(component.cid, pixels(element.scrollLeft));
          const signature = JSON.stringify(payload);
          const measurements = page.scrollMeasurements ||= new Map();
          if (measurements.get(component.cid) === signature) return;
          measurements.set(component.cid, signature);
          emit(page, component, "scrolled", payload);
        };
        element.addEventListener("scroll", report, { passive: true });
        window.requestAnimationFrame(() => {
          if (!element.isConnected) return;
          const previous = requests.get(component.cid);
          if (requested !== undefined && (previous?.y !== requested || previous?.revision !== revision)) {
            element.scrollTop = requested;
          } else element.scrollTop = offsets.get(component.cid) ?? component.props.initial_scroll?.y ?? 0;
          if (requestedX !== undefined && (previous?.x !== requestedX || previous?.revisionX !== revisionX)) element.scrollLeft = requestedX;
          else element.scrollLeft = horizontalOffsets.get(component.cid) ?? component.props.initial_scroll?.x ?? 0;
          requests.set(component.cid, { x: requestedX, y: requested, revision, revisionX });
          report();
        });
        return element;
      },
      tabs(page, component) {
        const tabs = common(node("div", "webui-tabs"), component);
        if (component.props.size_to_all) {
          tabs.dataset.sizeToAll = "true";
          // Theme flex styles must not put hidden sizing pages into normal flow.
          tabs.style.display = "grid";
          tabs.style.gridTemplateRows = component.props.show_tabs === false ? "0 minmax(min-content, 1fr)" : "max-content minmax(min-content, 1fr)";
        }
        if (component.props.vertical) tabs.classList.add("account-tabs-left");
        else if (component.props.presentation_role === "inset") tabs.classList.add("nested");
        const list = node("div", "tab-list");
        list.setAttribute("role", "tablist");
        list.hidden = component.props.show_tabs === false;
        if (list.hidden) list.style.display = "none";
        const selected = component.props.selected ?? 0;
        component.props.names.forEach((name, index) => {
          const button = node("button", null, name);
          button.type = "button";
          button.setAttribute("role", "tab");
          button.setAttribute("aria-selected", String(index === selected));
          const header = component.props.headers?.[index];
          button.hidden = header?.hidden === true;
          button.disabled = component.props.disabled === true || header?.disabled === true;
          if (header?.foreground) button.style.color = compositeColor(header.foreground);
          if (header?.pointer_events) {
            const press = (event, clickCount) => {
              if (button.disabled || event.button > 2) return;
              event.stopPropagation();
              if (event.button !== 0) event.preventDefault();
              emit(page, component, "tab_pointer", { tab: header.key, x: Math.round(event.clientX), y: Math.round(event.clientY),
                button: event.button + 1, time: Math.floor(event.timeStamp),
                state: modifiers(event), click_count: clickCount });
            };
            button.addEventListener("pointerdown", event => press(event, 1));
            button.addEventListener("dblclick", event => press(event, 2));
            button.addEventListener("contextmenu", event => event.preventDefault());
            button.addEventListener("auxclick", event => event.preventDefault());
          }
          button.addEventListener("click", () => emit(page, component, "select", { index, ...(header ? { tab: header.key } : {}) }));
          list.append(button);
        });
        const actions = (component.children || []).filter(child => child.placement?.tab_action);
        if (actions.length) {
          tabs.dataset.tabActions = "true";
          const header = node("div", "tab-header");
          header.hidden = component.props.show_tabs === false;
          if (header.hidden) header.style.display = "none";
          for (const side of ["start", "end"]) {
            const action = actions.find(child => child.placement.tab_action === side);
            if (!action) continue;
            const region = node("div", `tab-action tab-action-${side}`);
            region.append(render(page, action));
            header.append(region);
          }
          const end = header.querySelector(".tab-action-end");
          header.insertBefore(list, end);
          tabs.append(header);
        } else tabs.append(list);
        (component.children || []).filter(child => !child.placement?.tab_action).forEach((child, index) => {
          const panel = render(page, child);
          panel.classList.add("tab-panel");
          panel.setAttribute("role", list.hidden ? "group" : "tabpanel");
          if (list.hidden) panel.setAttribute("aria-label", component.props.names[index]);
          panel.hidden = index !== selected || component.props.headers?.[index]?.hidden === true;
          if (component.props.size_to_all) {
            panel.inert = index !== selected;
            // Grid tracks supply the allocation; the flex-parent zero-height
            // basis would otherwise prevent this page from stretching.
            if (child.props.fill) panel.style.height = "auto";
          }
          tabs.append(panel);
        });
        return tabs;
      },
      divider(_page, component) { return common(node("div", "webui-divider", component.props.label || ""), component); },
      overlay(page, component) {
        const overlay = common(node("div", "webui-overlay"), component);
        if (component.props.clip_children) overlay.style.overflow = "hidden";
        if (component.props.positioned) {
          overlay.style.position = "relative";
          appendChildren(page, component, overlay);
          Array.from(overlay.children).forEach((child, index) => {
            const layer = component.children[index];
            child.style.position = "absolute";
            child.style.left = `${layer.placement?.x || 0}px`;
            child.style.top = `${layer.placement?.y || 0}px`;
            if (layer.props.width === undefined) child.style.width = "max-content";
            if (layer.placement?.pass_through) child.dataset.overlayPassThrough = "true";
          });
          const measure = () => {
            if (!overlay.isConnected) return;
            let width = 0, height = 0;
            Array.from(overlay.children).forEach((child, index) => {
              if (child.hidden) return;
              const placement = component.children[index].placement || {};
              width = Math.max(width, (placement.x || 0) + child.offsetWidth);
              height = Math.max(height, (placement.y || 0) + child.offsetHeight);
            });
            overlay.style.minWidth = `${width}px`;
            overlay.style.minHeight = `${height}px`;
          };
          observeAllocation(page, overlay, measure);
          if (window.ResizeObserver) {
            const observer = new window.ResizeObserver(measure);
            Array.from(overlay.children).forEach(child => observer.observe(child));
            (page.layoutObservers ||= []).push(observer);
          }
          return overlay;
        }
        overlay.style.display = "grid";
        appendChildren(page, component, overlay);
        Array.from(overlay.children).forEach((child, index) => {
          const layer = component.children[index];
          child.style.gridArea = "1 / 1";
          if (layer.props.align) child.style.justifySelf = layer.props.align;
          if (layer.props.vertical_align) child.style.alignSelf = layer.props.vertical_align;
          if (layer.placement?.pass_through) child.dataset.overlayPassThrough = "true";
        });
        return overlay;
      },
      // A split starts at its first child's natural width. Subsequent positions
      // are viewer state, so a meter refresh cannot reset the user's divider.
      split(page, component) {
        const root = common(node("div", "webui-split"), component);
        const horizontal = component.props.orientation === "horizontal";
        root.dataset.orientation = component.props.orientation;
        if (component.props.fill) root.dataset.fill = "true";
        const first = node("div", "split-pane"), second = node("div", "split-pane");
        const handle = node("div", "split-handle");
        handle.tabIndex = 0;
        handle.setAttribute("role", "separator");
        handle.setAttribute("aria-orientation", horizontal ? "vertical" : "horizontal");
        handle.setAttribute("aria-valuemin", "0"); handle.setAttribute("aria-valuemax", "100");
        for (const child of component.children || []) (child.slot === "first" ? first : second).append(render(page, child));
        root.append(first, handle, second);
        let position = component.props.position;
        const pixelMode = component.props.position_pixels !== undefined && component.props.resize_side === "first";
        const pixelState = page.pixelSplits ||= new Map();
        let secondPixels = pixelState.get(component.cid);
        const measure = () => {
          const extent = horizontal ? root.clientWidth : root.clientHeight;
          return extent ? Math.round(100 * (horizontal ? first.clientWidth : first.clientHeight) / extent) : 0;
        };
        const layout = () => {
          if (pixelMode) {
            const extent = horizontal ? root.clientWidth : root.clientHeight;
            if (!root.isConnected || extent <= 0) return;
            // GTK gives a non-resizing second pane its width from the requested
            // initial window allocation. A split can first mount after the page
            // has grown or shrunk, so use that request rather than its current
            // allocation. An explicit drag still replaces this viewer state.
            if (secondPixels === undefined) {
              const pageExtent = horizontal ? page.element?.clientWidth : page.element?.clientHeight;
              const requested = page.tree?.props?.size?.[horizontal ? 0 : 1];
              const requestedExtent = Number.isFinite(requested) && pageExtent > 0
                ? requested - Math.max(0, pageExtent - extent) : 0;
              const initialExtent = requestedExtent > component.props.position_pixels + 1
                ? requestedExtent : extent;
              if (initialExtent > component.props.position_pixels + 1) {
                secondPixels = initialExtent - 1 - component.props.position_pixels;
              }
            }
            if (secondPixels !== undefined) pixelState.set(component.cid, secondPixels);
            const visibleSecondPixels = Math.min(secondPixels ?? 0, extent - 1);
            root.style[horizontal ? "gridTemplateColumns" : "gridTemplateRows"] = `minmax(0, 1fr) 1px ${visibleSecondPixels}px`;
            handle.setAttribute("aria-valuenow", String(Math.max(0, Math.round(100 * (extent - visibleSecondPixels - 1) / extent))));
            return;
          }
          const track = position === undefined ? "max-content" : `minmax(0, ${position}fr)`;
          const rest = position === undefined ? "minmax(0, 1fr)" : `minmax(0, ${100 - position}fr)`;
          root.style[horizontal ? "gridTemplateColumns" : "gridTemplateRows"] = `${track} 1px ${rest}`;
          handle.setAttribute("aria-valuenow", String(position ?? measure()));
        };
        if (pixelMode) observeAllocation(page, root, layout); else layout();
        window.requestAnimationFrame(() => {
          if (handle.isConnected && position === undefined) handle.setAttribute("aria-valuenow", String(measure()));
        });
        let dragging = false;
        const finish = commit => {
          if (!dragging) return;
          dragging = false;
          page.splitDragging = false;
          const deferred = page.deferredRender;
          page.deferredRender = null;
          if (deferred) acceptRender(deferred);
          if (commit && position !== undefined) emit(page, component, "move", { position });
        };
        handle.addEventListener("pointerdown", event => {
          if (event.button !== 0) return;
          dragging = true; page.splitDragging = true;
          handle.setPointerCapture(event.pointerId); event.preventDefault();
        });
        handle.addEventListener("pointermove", event => {
          if (!dragging) return;
          const rect = root.getBoundingClientRect();
          const extent = horizontal ? rect.width : rect.height;
          if (!extent) return;
          position = Math.max(0, Math.min(100, Math.round(100 *
            (horizontal ? event.clientX - rect.left : event.clientY - rect.top) / extent)));
          if (pixelMode) secondPixels = Math.max(0, extent * (1 - position / 100) - 1);
          layout();
        });
        handle.addEventListener("pointerup", () => finish(true));
        handle.addEventListener("pointercancel", () => finish(false));
        handle.addEventListener("lostpointercapture", () => finish(false));
        handle.addEventListener("keydown", event => {
          const decrement = horizontal ? "ArrowLeft" : "ArrowUp";
          const increment = horizontal ? "ArrowRight" : "ArrowDown";
          if (![decrement, increment, "Home", "End"].includes(event.key)) return;
          event.preventDefault();
          position = event.key === "Home" ? 0 : event.key === "End" ? 100 :
            Math.max(0, Math.min(100, (position ?? measure()) + (event.key === increment ? 1 : -1)));
          if (pixelMode) secondPixels = Math.max(0, (horizontal ? root.clientWidth : root.clientHeight) * (1 - position / 100) - 1);
          layout(); emit(page, component, "move", { position });
        });
        return root;
      },
      dialog(page, component) {
        const dialog = common(node("dialog", "webui-dialog"), component);
        dialog.setAttribute("aria-label", component.props.title);
        if (component.props.title && component.props.show_title !== false) dialog.append(node("h2", null, component.props.title));
        if (component.props.body) dialog.append(node("p", null, component.props.body));
        appendChildren(page, component, dialog);
        const actions = node("div", "dialog-actions");
        component.props.buttons.forEach((definition) => {
          const button = node("button", definition.variant || "default", definition.label);
          button.addEventListener("click", () => emit(page, component, "response", { button: definition.id }));
          actions.append(button);
        });
        dialog.append(actions);
        if (component.props.cancel_button) dialog.addEventListener("cancel", event => {
          event.preventDefault();
          emit(page, component, "response", { button: component.props.cancel_button });
        });
        queueMicrotask(() => { if (dialog.isConnected && !dialog.open) dialog.showModal(); });
        return dialog;
      }
    };
    return controls;
  };
})();
