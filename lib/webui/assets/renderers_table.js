(() => {
  "use strict";
  const families = window.LichWebUIRendererFamilies ||= Object.create(null);

  /**
   * Builds tables and cell editors while retaining drafts, widths and gestures on the owning page.
   * Loading registers only this factory; it does not create DOM, listeners or sockets.
   * @param {Object} context Explicit capabilities; no page map or transport state.
   * @param {Function} context.node Creates literal DOM nodes.
   * @param {Function} context.common Applies validated common properties.
   * @param {Function} context.bound Checks delivered event authority.
   * @param {Function} context.emit Sends admitted events through the central transport.
   * @param {Function} context.compositeColor Maps validated colors to renderer-owned CSS.
   * @param {Function} context.holdPointer Defers replacement until the active press completes.
   * @param {Function} context.acceptRender Returns deferred updates to the lifecycle coordinator.
   * @param {Function} context.findComponent Resolves the latest tree identity.
   * @param {Function} context.controlValue Reads wire values rather than displayed labels.
   * @returns {Object} Renderer functions.
   */
  families.table = function createTableRenderers({
    node, common, bound, emit, compositeColor, holdPointer, acceptRender, findComponent, controlValue
  }) {
    /**
     * Creates one cell editor's idempotent finish boundary before any input can fire.
     * @param {Object} context Captured page, cell, column policy and editor references.
     * @returns {Function} Commit/cancel handler; releases the latest deferred tree first.
     */
    function tableCellEditFinisher({ page, component, row, column, cell, paintCell,
      control, definition, initialValue, missingSelectValue }) {
      let finished = false;
      return function finishTableCellEdit(save) {
        if (finished) return;
        finished = true;
        const value = controlValue(control);
        const commit = save && !(missingSelectValue && value === initialValue);
        const displayValue = definition.option_labels ? definition.options.find(option => option.value === value)?.label ?? row.cells[column.key] : value;
        // Selection or another server update may arrive while the
        // cell editor owns an unfinished draft. Commit against the
        // latest generation after releasing that render, once.
        page.editingCell = false;
        const deferred = page.deferredRender;
        page.deferredRender = null;
        if (commit && deferred) {
          const pendingRow = findComponent(deferred.tree, component.cid)?.props.rows?.find(item => item.key === row.key);
          if (pendingRow) pendingRow.cells[column.key] = displayValue;
        }
        if (deferred) acceptRender(deferred);
        if (commit) { row.cells[column.key] = displayValue; emit(page, component, "cell_edit", { row: row.key, column: column.key, value }); }
        delete cell.dataset.editing;
        paintCell();
        cell.setAttribute("aria-label", `${column.label}: ${row.cells[column.key] ?? ""}`);
      };
    }

    /**
     * Begins a text/number/select cell edit while keeping its draft and finish guard local.
     * @param {Object} page Page whose editing flag defers replacement.
     * @param {Object} component Table component and event authority.
     * @param {Object} row Stable row identity and current cells.
     * @param {Object} column Editor definition and column identity.
     * @param {HTMLElement} cell Current cell receiving the editor.
     * @param {Function} paintCell Restores the same literal-cell presentation on finish.
     * @returns {void}
     */
    function beginTableCellEdit(page, component, row, column, cell, paintCell) {
      if (cell.dataset.editing) return;
      cell.dataset.editing = "true";
      page.editingCell = true;
      const definition = column.editor;
      const control = node(definition.type === "select" ? "select" : "input");
      if (definition.type === "select") definition.options.forEach(option => {
        const item = node("option", null, option.label); item.value = option.value; control.append(item);
      });
      // A saved value can outlive the current choices. GTK keeps its
      // displayed cell until the user picks another value; a native
      // select would otherwise fall back to its first option.
      const initialValue = definition.type === "select" && definition.option_labels
        ? definition.options.find(option => option.label === row.cells[column.key])?.value ?? row.cells[column.key]
        : row.cells[column.key];
      const missingSelectValue = definition.type === "select" &&
        !definition.options.some(option => option.value === initialValue);
      if (missingSelectValue) {
        const item = node("option", null, row.cells[column.key] ?? "");
        item.value = row.cells[column.key] ?? "";
        control.append(item);
      }
      if (definition.type !== "select") control.type = definition.type === "number" ? "number" : definition.type === "checkbox" ? "checkbox" : "text";
      for (const name of ["min", "max", "step"]) if (definition[name] !== undefined) control[name] = definition[name];
      if (definition.max_length) control.maxLength = definition.max_length;
      if (definition.type === "checkbox") control.checked = row.cells[column.key] === true;
      else control.value = initialValue ?? "";
      const finish = tableCellEditFinisher({
        page, component, row, column, cell, paintCell, control, definition, initialValue, missingSelectValue
      });
      control.addEventListener("change", () => finish(true));
      control.addEventListener("blur", () => finish(true));
      control.addEventListener("keydown", event => {
        event.stopPropagation();
        if (event.key === "Enter" || event.key === "Escape") { event.preventDefault(); finish(event.key === "Enter"); }
      });
      cell.replaceChildren(control); control.focus();
      if (definition.type === "text") control.select?.();
    }

    const controls = {
      table(page, component) {
        const wrapper = common(node("div", "webui-table-wrap"), component);
        // Filled lists scroll inside their allocation. Their rows must not turn
        // a requested viewport minimum into a content-sized notebook minimum.
        if (component.props.scrollable === false) {
          page.unscrolledTableMinimum = true;
          wrapper.style.overflow = "visible";
          if (component.props.fill) {
            wrapper.style.flex = "1 0 auto";
            wrapper.style.height = "auto";
            wrapper.style.minHeight = "min-content";
          }
        } else if (component.props.fill) wrapper.style.contain = "size";
        if (component.props.border_width !== undefined) wrapper.style.borderWidth = `${component.props.border_width}px`;
        if (component.props.transfer_group && bound(page, component.cid, "row_drop")) {
          wrapper.addEventListener("dragover", event => { event.preventDefault(); event.dataTransfer.dropEffect = "move"; });
          wrapper.addEventListener("drop", event => {
            event.preventDefault();
            try {
              const transfer = JSON.parse(event.dataTransfer.getData("application/x-lich-row"));
              if (transfer.group === component.props.transfer_group && transfer.page === page.address) {
                emit(page, component, "row_drop", { source: transfer.source, row: transfer.row });
              }
            } catch (_) { /* A non-Lich drag has no table operation. */ }
          });
        }
        const table = node("table", "webui-table");
        if (component.props.selection_background) {
          table.style.setProperty("--selection-background", compositeColor(component.props.selection_background));
        }
        if (component.props.wrap === false) table.dataset.wrap = "false";
        if (component.props.grid_lines) table.dataset.gridLines = component.props.grid_lines;
        table.setAttribute("role", "table"); // Headerless lists remain accessible data tables.
        // Column widths are viewer presentation state. Retain them across data
        // refreshes without changing row values or introducing script callbacks.
        const widths = (page.tableWidths ||= new Map());
        const columnWidths = widths.get(component.cid) || new Map();
        widths.set(component.cid, columnWidths);
        const automaticWidths = new Map();
        const boundedWidth = (column, width) => width === undefined ? undefined : Math.max(column.min_width || 0, width);
        const resizable = component.props.columns.some(column => column.resizable);
        const expanding = component.props.columns.some(column => column.expand);
        const allocated = resizable || expanding;
        const cols = new Map();
        if (allocated || component.props.columns.some(column => column.width !== undefined || column.min_width !== undefined)) {
          const colgroup = node("colgroup");
          component.props.columns.forEach(column => {
            const col = node("col");
            cols.set(column.key, col); colgroup.append(col);
            const authored = columnWidths.get(column.key) ?? column.width;
            const width = boundedWidth(column, authored ?? column.min_width);
            if (width > 0 || (!resizable && width === 0)) col.style.width = `${width}px`;
          });
          table.append(colgroup);
        }
        const applyWidths = () => {
          if (!allocated) return;
          const resolved = new Map(component.props.columns.map(column => [column.key,
            boundedWidth(column, columnWidths.get(column.key) ?? (column.width > 0 ? column.width : automaticWidths.get(column.key)))]));
          if ([...resolved.values()].some(width => width === undefined)) return;
          table.style.tableLayout = "fixed";
          table.style.width = `${[...resolved.values()].reduce((sum, width) => sum + width, 0)}px`;
          cols.forEach((col, key) => { col.style.width = `${resolved.get(key)}px`; });
        };
        applyWidths();
        const head = node("thead");
        const header = node("tr");
        const body = node("tbody");
        let sort = component.props.sort;
        const headings = new Map();
        let selected = new Set(component.props.selected || []);
        const expanded = new Set(component.props.expanded || component.props.rows.filter(row => row.expanded).map(row => row.key));
        const children = new Map();
        component.props.rows.forEach(row => {
          const parent = row.parent || null;
          if (!children.has(parent)) children.set(parent, []);
          children.get(parent).push(row);
        });
        const hierarchical = component.props.rows.some(row => row.parent);
        if (hierarchical) table.setAttribute("role", "treegrid");
        if (component.props.selection === "multi") table.setAttribute("aria-multiselectable", "true");
        let visibleRows = [];
        // Search state belongs to this page/viewer, never to the shared model.
        const searches = page.tableSearches ||= new Map();
        const searchStatus = node("span", "webui-table-search");
        searchStatus.setAttribute("role", "status");
        searchStatus.setAttribute("aria-live", "polite");
        const retainedSearch = searches.get(component.cid);
        if (retainedSearch?.text && Date.now() - retainedSearch.time <= 1500) searchStatus.textContent = `Search: ${retainedSearch.text}`;
        if (component.props.search_column) wrapper.append(searchStatus);
        const search = event => {
          if (!component.props.search_column || component.props.disabled || event.ctrlKey || event.metaKey || event.altKey || event.isComposing) return false;
          const previous = searches.get(component.cid) || { text: '', time: 0 };
          let text = Date.now() - previous.time > 1500 ? '' : previous.text;
          if (event.key === 'Escape') text = '';
          else if (event.key === 'Backspace') text = text.slice(0, -1);
          else if (event.key.length === 1 && (event.key !== ' ' || text)) text += event.key;
          else return false;
          event.preventDefault();
          text = text.slice(0, 256);
          searches.set(component.cid, { text, time: Date.now() });
          searchStatus.textContent = text ? `Search: ${text}` : '';
          if (text) {
            const target = visibleRows.find(({ row }) => String(row.cells[component.props.search_column] ?? '').toLocaleLowerCase().startsWith(text.toLocaleLowerCase()));
            if (target) { select(target.row); setCursor(target.row, component.props.search_column); focusRow(target.row.key); }
          }
          return true;
        };
        let anchor = (page.tableAnchors ||= new Map()).get(component.cid);
        const setCursor = (row, column) => {
          const payload = { row: row.key };
          if (column) payload.column = column;
          if (JSON.stringify(component.props.cursor) === JSON.stringify(payload)) return;
          component.props.cursor = payload;
          (page.tableCursors ||= new Map()).set(component.cid, JSON.stringify(payload));
          emit(page, component, "cursor_change", payload);
        };
        const select = (row, event = {}) => {
          if (component.props.selection === "none") return;
          const previous = new Set(selected);
          if (component.props.selection === "multi" && event.shiftKey && visibleRows.some(item => item.row.key === anchor)) {
            const a = visibleRows.findIndex(item => item.row.key === anchor);
            const b = visibleRows.findIndex(item => item.row.key === row.key);
            const range = visibleRows.slice(Math.min(a, b), Math.max(a, b) + 1).map(item => item.row.key);
            selected = new Set(event.ctrlKey || event.metaKey ? [...selected, ...range] : range);
          } else if (component.props.selection === "multi" && (event.ctrlKey || event.metaKey)) {
            if (selected.has(row.key)) selected.delete(row.key); else selected.add(row.key);
            anchor = row.key;
          } else {
            selected = new Set([row.key]); anchor = row.key;
          }
          page.tableAnchors.set(component.cid, anchor);
          // Repeated clicks/search hits must not schedule redundant structural
          // renders that invalidate the following double-click activation.
          if (selected.size === previous.size && [...selected].every(key => previous.has(key))) return;
          component.props.selected = [...selected];
          for (const tr of body.children) tr.setAttribute("aria-selected", String(selected.has(tr.dataset.rowKey)));
          emit(page, component, "selection_change", { rows: [...selected] });
        };
        const focusRow = key => [...body.children].find(tr => tr.dataset.rowKey === key)?.focus();
        const toggle = row => {
          if (expanded.has(row.key)) expanded.delete(row.key); else expanded.add(row.key);
          component.props.expanded = [...expanded];
          drawRows(); focusRow(row.key);
          emit(page, component, "row_toggle", { row: row.key, expanded: expanded.has(row.key) });
        };
        const drawRows = () => {
          body.replaceChildren();
          const compare = (left, right) => {
            const a = left.sort_cells?.[sort.column] ?? left.cells[sort.column];
            const b = right.sort_cells?.[sort.column] ?? right.cells[sort.column];
            const compared = typeof a === "number" && typeof b === "number"
              ? a - b : String(a ?? "").localeCompare(String(b ?? ""), undefined, { numeric: component.props.sort_mode !== "lexical" });
            return sort.direction === "desc" ? -compared : compared;
          };
          // Sorting is sibling-local; a flat global sort would detach children from parents.
          // Model-owned order comes from Ruby and determines GTK paths as well as display order.
          visibleRows = [];
          const visit = (parent, depth) => {
            const peers = [...(children.get(parent) || [])];
            if (sort && component.props.sort_mode !== "model") peers.sort(compare);
            peers.forEach(row => {
              visibleRows.push({ row, depth });
              if (expanded.has(row.key)) visit(row.key, depth + 1);
            });
          };
          visit(null, 0);
          for (const [key, th] of headings) th.setAttribute("aria-sort", sort?.column === key
            ? (sort.direction === "desc" ? "descending" : "ascending") : "none");
          visibleRows.forEach(({ row, depth }, index) => {
            const tr = node("tr");
            tr.dataset.rowKey = row.key;
            if (component.props.row_height) tr.style.height = `${component.props.row_height}px`;
            if (component.props.transfer_group) {
              tr.draggable = true;
              // The table's legacy pointer callback stops bubbling. Keep its row alive
              // across that callback's render until the drag or click is released.
              tr.addEventListener("pointerdown", () => holdPointer(page));
              tr.addEventListener("dragstart", event => {
                page.rowDragging = true;
                holdPointer(page);
                event.dataTransfer.effectAllowed = "move";
                event.dataTransfer.setData("application/x-lich-row", JSON.stringify({
                  page: page.address, group: component.props.transfer_group, source: component.cid, row: row.key
                }));
              });
            }
            tr.tabIndex = 0;
            tr.setAttribute("aria-selected", String(selected.has(row.key)));
            if (hierarchical) {
              tr.setAttribute("aria-level", String(depth + 1));
              if (children.has(row.key)) tr.setAttribute("aria-expanded", String(expanded.has(row.key)));
            }
            const activate = event => {
              const payload = { row: row.key };
              const column = event.target.closest("td")?.dataset.columnKey;
              if (column) payload.column = column;
              emit(page, component, "row_activate", payload);
            };
            tr.addEventListener("click", event => {
              select(row, event); setCursor(row, event.target.closest("td")?.dataset.columnKey); tr.focus();
              // Ignore the second click of a double click in single-activation mode.
              if (component.props.activation === "single" && event.detail < 2) activate(event);
            });
            tr.addEventListener("dblclick", event => {
              if (component.props.activation !== "single") activate(event);
            });
            tr.addEventListener("keydown", event => {
              if (event.target !== tr) return;
              if (search(event)) return;
              if (event.key === "Enter") { event.preventDefault(); emit(page, component, "row_activate", { row: row.key, ...(component.props.cursor?.row === row.key && component.props.cursor.column ? { column: component.props.cursor.column } : {}) }); }
              else if (event.key === " ") { event.preventDefault(); select(row, event); setCursor(row); }
              else if (["ArrowDown", "ArrowUp", "Home", "End"].includes(event.key)) {
                event.preventDefault();
                const targetIndex = event.key === "Home" ? 0 : event.key === "End" ? visibleRows.length - 1 : Math.max(0, Math.min(visibleRows.length - 1, index + (event.key === "ArrowDown" ? 1 : -1)));
                const target = visibleRows[targetIndex].row;
                focusRow(target.key); setCursor(target);
                if (!event.ctrlKey && !event.metaKey) select(target, event);
              } else if (event.key === "ArrowRight" && children.has(row.key)) {
                event.preventDefault();
                if (!expanded.has(row.key)) toggle(row);
                else { const child = children.get(row.key)[0]; focusRow(child.key); setCursor(child); }
              } else if (event.key === "ArrowLeft") {
                event.preventDefault();
                if (expanded.has(row.key)) toggle(row);
                else if (row.parent) { focusRow(row.parent); setCursor(component.props.rows.find(candidate => candidate.key === row.parent)); }
              }
            });
            component.props.columns.forEach((column, columnIndex) => {
              const cell = node("td", null, row.cells[column.key]);
              const cellDisabled = component.props.disabled === true || column.editor?.disabled === true || row.cell_disabled?.includes(column.key) === true;
              if (cellDisabled) cell.setAttribute("aria-disabled", "true");
              cell.dataset.columnKey = column.key;
              cell.style.textAlign = column.align || "start";
              if (column.min_width) cell.style.minWidth = `${column.min_width}px`;
              const foreground = row.cell_foregrounds?.find(entry => entry.column === column.key)?.color;
              if (foreground) cell.style.color = compositeColor(foreground);
              if (column.background && !row.background_disabled?.includes(column.key)) {
                cell.style.backgroundColor = compositeColor(column.background);
                cell.dataset.backgroundFill = "true";
              }
              // Reuse the same literal-cell presentation after edits and Escape.
              const paintCell = () => {
                cell.replaceChildren(); cell.textContent = row.cells[column.key] ?? "";
                if (resizable) cell.title = cell.textContent;
                if (column.editor?.type === "checkbox") {
                  const control = node("input"); control.type = "checkbox";
                  control.checked = row.cells[column.key] === true;
                  control.disabled = cellDisabled || !bound(page, component.cid, "cell_edit");
                  control.setAttribute("aria-label", column.label || "Toggle row");
                  control.addEventListener("click", event => event.stopPropagation());
                  control.addEventListener("change", () => {
                    select(row); setCursor(row, column.key);
                    emit(page, component, "cell_edit", { row: row.key, column: column.key, value: control.checked });
                  });
                  cell.replaceChildren(control);
                }
                if (hierarchical && columnIndex === 0) {
                  cell.style.paddingLeft = `${4 + depth * 18}px`;
                  const disclosure = node(children.has(row.key) ? "button" : "span", "webui-tree-disclosure", children.has(row.key) ? (expanded.has(row.key) ? "\u25be" : "\u25b8") : "");
                  if (children.has(row.key)) {
                    disclosure.type = "button";
                    disclosure.disabled = component.props.disabled === true;
                    disclosure.setAttribute("aria-label", `${expanded.has(row.key) ? "Collapse" : "Expand"} ${row.cells[column.key] ?? "row"}`);
                    disclosure.addEventListener("click", event => { event.stopPropagation(); toggle(row); });
                  }
                  cell.prepend(disclosure);
                }
                if (column.color_preview) {
                const swatch = node("span", "webui-cell-swatch");
                swatch.setAttribute("aria-hidden", "true");
                Object.assign(swatch.style, { display: "inline-block", verticalAlign: "middle", marginRight: "10px",
                  width: `${column.color_preview.width}px`, height: `${column.color_preview.height}px`,
                  backgroundColor: /^#[0-9a-f]{6}$/i.test(String(row.cells[column.key])) ? row.cells[column.key] : "#FFFFFF" });
                // Keep the original literal text beside the bounded color preview.
                cell.replaceChildren(swatch, node("span", null, row.cells[column.key]));
              }
              };
              paintCell();
              if (column.editor && !cellDisabled && column.editor.type !== "checkbox" && bound(page, component.cid, "cell_edit")) {
                cell.tabIndex = 0;
                cell.setAttribute("aria-label", `${column.label}: ${row.cells[column.key] ?? ""}`);
                const edit = () => beginTableCellEdit(page, component, row, column, cell, paintCell);
                cell.addEventListener("click", event => {
                  event.stopPropagation();
                  // Modifier clicks select a range/set; they must not consume the gesture as editing.
                  if (event.ctrlKey || event.metaKey || event.shiftKey) tr.focus(); else edit();
                  select(row, event); setCursor(row, column.key);
                });
                cell.addEventListener("dblclick", event => { event.stopPropagation(); edit(); });
                cell.addEventListener("keydown", event => { if (event.key === "Enter" || event.key === "F2") { event.stopPropagation(); event.preventDefault(); edit(); } });
              }
              tr.append(cell);
            });
            body.append(tr);
          });
        };
        component.props.columns.forEach(column => {
          const th = node("th");
          headings.set(column.key, th);
          if (column.min_width) th.style.minWidth = `${column.min_width}px`;
          if (column.tooltip !== undefined) th.title = column.tooltip;
          if (column.activatable) {
            const button = node("button", null, column.label);
            button.type = "button";
            button.disabled = component.props.disabled === true;
            button.addEventListener("click", () => emit(page, component, "column_activate", { column: column.key }));
            th.append(button);
          } else if (component.props.sortable && column.sortable) {
            const button = node("button", null, column.label);
            button.type = "button";
            button.addEventListener("click", () => {
              sort = { column: column.key, direction: sort?.column === column.key && sort.direction === "asc" ? "desc" : "asc" };
              drawRows();
              emit(page, component, "sort_change", sort);
            });
            th.append(button);
          } else if (allocated) th.append(node("span", "webui-column-label", column.label));
          else th.textContent = column.label;
          if (column.resizable) {
            const handle = node("span", "webui-column-resize");
            handle.setAttribute("aria-label", `Resize ${column.label}`);
            handle.setAttribute("role", "separator");
            handle.setAttribute("aria-orientation", "vertical");
            handle.setAttribute("aria-valuemin", String(Math.max(24, column.min_width || 0)));
            handle.setAttribute("aria-valuemax", "65536");
            const updateWidth = () => handle.setAttribute("aria-valuenow", String(Math.round(
              boundedWidth(column, columnWidths.get(column.key) || th.getBoundingClientRect().width || 24))));
            updateWidth();
            window.requestAnimationFrame(() => { if (handle.isConnected) updateWidth(); });
            handle.tabIndex = 0;
            handle.addEventListener("keydown", event => {
              if (!["ArrowLeft", "ArrowRight"].includes(event.key)) return;
              event.preventDefault(); event.stopPropagation();
              headings.forEach((heading, key) => columnWidths.set(key, heading.getBoundingClientRect().width));
              columnWidths.set(column.key, Math.max(24, column.min_width || 0, Math.min(65536,
                columnWidths.get(column.key) + (event.key === "ArrowRight" ? 10 : -10))));
              applyWidths();
              updateWidth();
            });
            let drag = null;
            handle.addEventListener("pointerdown", event => {
              if (event.button !== 0) return;
              event.preventDefault(); event.stopPropagation();
              headings.forEach((heading, key) => columnWidths.set(key, heading.getBoundingClientRect().width));
              drag = { x: event.clientX, width: columnWidths.get(column.key) };
              page.columnDragging = true;
              handle.setPointerCapture?.(event.pointerId);
            });
            handle.addEventListener("pointermove", event => {
              if (!drag) return;
              columnWidths.set(column.key, Math.max(24, column.min_width || 0, Math.min(65536, drag.width + event.clientX - drag.x)));
              applyWidths();
              updateWidth();
            });
            const finish = () => {
              drag = null; page.columnDragging = false;
              if (page.deferredRender) { const pending = page.deferredRender; page.deferredRender = null; acceptRender(pending); }
            };
            handle.addEventListener("pointerup", finish);
            handle.addEventListener("pointercancel", finish);
            handle.addEventListener("lostpointercapture", finish);
            th.append(handle);
          }
          header.append(th);
        });
        head.append(header);
        // Empty captions represent the original headerless spell lists.
        const hasHeaders = component.props.headers !== false && (component.props.headers === true || component.props.columns.some(column => column.label));
        if (hasHeaders) table.append(head);
        table.append(body);
        drawRows();
        wrapper.append(table);
        if (allocated) {
          table.dataset.boundedColumns = "true";
          /**
           * Allocate automatic columns from the visible viewport and header labels,
           * never from the longest cell. Zero is an automatic width. Positive
           * authored widths and viewer-resized widths remain authoritative, even
           * when they require horizontal scrolling. Hidden tabs wait for allocation.
           */
          const allocateColumns = () => {
            if (!wrapper.isConnected || wrapper.clientWidth <= 0) return;
            const available = wrapper.clientWidth;
            const automatic = [];
            let occupied = 0;
            component.props.columns.forEach(column => {
              const fixed = columnWidths.get(column.key) ?? (column.width > 0 ? column.width : undefined);
              if (fixed !== undefined) { occupied += Math.max(column.min_width || 0, fixed); return; }
              const heading = headings.get(column.key);
              const style = heading && window.getComputedStyle(heading);
              const minimum = Math.max(24, column.min_width || 0, heading ? Math.ceil(heading.firstElementChild.getBoundingClientRect().width +
                parseFloat(style.paddingLeft || 0) + parseFloat(style.paddingRight || 0) +
                parseFloat(style.borderLeftWidth || 0) + parseFloat(style.borderRightWidth || 0)) : 24);
              automatic.push([column.key, minimum]);
              occupied += minimum;
            });
            const recipients = expanding ? automatic.filter(([key]) => component.props.columns.find(column => column.key === key).expand) : automatic;
            const extra = recipients.length ? Math.max(0, available - occupied) / recipients.length : 0;
            const recipientKeys = new Set(recipients.map(([key]) => key));
            automatic.forEach(([key, minimum]) => automaticWidths.set(key, minimum + (recipientKeys.has(key) ? extra : 0)));
            applyWidths();
          };
          window.requestAnimationFrame(allocateColumns);
          if (window.ResizeObserver) {
            const observer = new ResizeObserver(allocateColumns);
            observer.observe(wrapper);
            (page.layoutObservers ||= []).push(observer);
          }
        }
        const cursor = component.props.cursor || {};
        const signature = JSON.stringify(cursor);
        const cursors = page.tableCursors ||= new Map();
        if (cursors.get(component.cid) !== signature && cursor.row) {
          (page.tableFocusRequests ||= []).push({ cid: component.cid, ...cursor });
        }
        cursors.set(component.cid, signature);
        return wrapper;
      }
    };
    return controls;
  };
})();
