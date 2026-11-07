(() => {
  "use strict";
  const families = window.LichWebUIRendererFamilies ||= Object.create(null);

  /**
   * Builds frames, submenus and context menus with page-local focus and dismissal state.
   * Loading registers only this factory; it does not create DOM, listeners or sockets.
   * @param {Object} context Explicit capabilities; no page map or transport state.
   * @param {Function} context.node Creates literal DOM nodes.
   * @param {Function} context.common Applies validated common properties.
   * @param {Function} context.emit Sends admitted events through the central transport.
   * @param {Function} context.appendChildren Recursively renders children in contract order.
   * @param {Function} context.render Renders one component through the central dispatcher.
   * @param {Function} context.compositeColor Maps validated colors to renderer-owned CSS.
   * @param {Function} context.surfacePayload Maps pointer coordinates to surface pixels.
   * @returns {Object} Renderer functions and menu lifecycle helpers.
   */
  families.menus = function createMenusRenderers({
    node, common, emit, appendChildren, render, compositeColor, surfacePayload
  }) {
    /**
     * Dismisses descendant popovers and clears expanded state when a menu branch closes.
     * @param {Element} menu Ancestor of the branch being dismissed.
     * @param {Object} page Viewer state whose closed panels must not reopen on render.
     */
    function hideSubmenus(menu, page) {
      page.popovers?.forEach((entry, cid) => {
        if (entry.group === menu || menu.contains(entry.group)) page.openPopovers?.delete(cid);
      });
      menu.querySelectorAll?.(".submenu-items").forEach(panel => {
        panel.hidePopover?.();
        panel.style.display = "none";
      });
      menu.querySelectorAll?.(".submenu-trigger").forEach(trigger => trigger.setAttribute("aria-expanded", "false"));
    }

    /** Returns enabled entries in this branch only, excluding hidden nested panels. */
    function menuItems(menu) {
      return [...menu.querySelectorAll("button,input")].filter(item => {
        if (item.disabled || item.closest(".submenu-items,.webui-context-menu") !== menu) return false;
        for (let ancestor = item; ancestor; ancestor = ancestor.parentElement) {
          if (ancestor.hidden || ancestor.inert || ancestor.style.display === "none") return false;
          if (ancestor === menu) break;
        }
        return true;
      });
    }

    /** Moves the branch's single tab stop and focus without activating an entry. */
    function focusMenuItem(menu, index = 0) {
      const items = menuItems(menu);
      if (!items.length) return;
      const selected = items[(index + items.length) % items.length];
      items.forEach(item => { item.tabIndex = item === selected ? 0 : -1; });
      selected.focus();
    }

    /**
     * Installs branch-local roving focus. Native buttons retain Enter/Space clicks;
     * Escape remains owned by the existing page-level dismissal handler.
     * @param {Element} menu Context menu or submenu panel, never its trigger.
     * @param {Function} closeBranch Optional ArrowLeft action returning to the parent.
     */
    function menuNavigation(menu, closeBranch) {
      const entries = [...menu.querySelectorAll("button,input")].filter(item => item.closest(".submenu-items,.webui-context-menu") === menu);
      entries.forEach(item => {
        item.tabIndex = -1;
        if (!item.hasAttribute("role")) item.setAttribute("role", "menuitem");
      });
      menu.addEventListener("keydown", event => {
        if (event.target.closest(".submenu-items,.webui-context-menu") !== menu) return;
        if (event.key === "ArrowLeft" && closeBranch) {
          event.preventDefault();
          event.stopPropagation();
          closeBranch();
          return;
        }
        if (!["ArrowUp", "ArrowDown", "Home", "End"].includes(event.key)) return;
        const items = menuItems(menu);
        if (!items.length) return;
        event.preventDefault();
        event.stopPropagation();
        const current = items.indexOf(document.activeElement);
        const index = event.key === "Home" ? 0 : event.key === "End" ? items.length - 1 :
          current < 0 ? (event.key === "ArrowUp" ? items.length - 1 : 0) : current + (event.key === "ArrowUp" ? -1 : 1);
        focusMenuItem(menu, index);
      });
      menu.addEventListener("focusin", event => {
        if (event.target.closest(".submenu-items,.webui-context-menu") !== menu) return;
        entries.forEach(item => { item.tabIndex = item === event.target ? 0 : -1; });
      });
    }

    /**
     * Captures only the currently visible menu's navigation state for one replacement.
     * Trigger CIDs belong to their submenu containers; ordinary entries use their
     * own CIDs. No draft values or script-owned open state are copied here.
     */
    function captureMenuNavigation(page) {
      for (const [key, menu] of page.contextMenus || []) {
        if (menu.style.display === "none") continue;
        return {
          key, cid: menu.dataset.cid,
          branches: [...menu.querySelectorAll('.submenu-trigger[aria-expanded="true"]')]
            .map(trigger => trigger.parentElement.dataset.cid),
          focus: menu.contains(document.activeElement) ? document.activeElement.closest("[data-cid]")?.dataset.cid : null
        };
      }
      return null;
    }

    /**
     * Restores surviving ancestors before their focused entry. Explicit closure,
     * replacement or disabled/removed branches override the previous navigation.
     * A removed entry falls back to the first enabled item in the deepest surviving
     * branch. Opening uses the normal popover layout without emitting events.
     */
    function restoreMenuNavigation(page, state) {
      if (!state) return;
      const menu = page.contextMenus.get(state.key);
      if (!menu || menu.dataset.cid !== state.cid || menu.style.display === "none") return;
      let branch = menu;
      for (const cid of state.branches) {
        const group = menu.querySelector(`[data-cid="${CSS.escape(cid)}"]`);
        const trigger = group?.querySelector(".submenu-trigger");
        if (!group?.openSubmenu || !menuItems(branch).includes(trigger)) break;
        group.openSubmenu();
        branch = trigger.nextElementSibling;
      }
      if (!state.focus) return;
      const component = menu.querySelector(`[data-cid="${CSS.escape(state.focus)}"]`);
      const target = page.controls.get(state.focus) ||
        (component?.matches("button,input") ? component : component?.querySelector("button,input"));
      const targetBranch = target?.closest(".submenu-items,.webui-context-menu");
      const index = targetBranch && menu.contains(target) ? menuItems(targetBranch).indexOf(target) : -1;
      if (index >= 0) focusMenuItem(targetBranch, index);
      else focusMenuItem(branch);
    }

    /**
     * Captures the origin before page replacement can move focus to document.body.
     * The element supports unchanged DOM; its page-local CID survives later renders.
     */
    function contextMenuFocus(page, element = document.activeElement) {
      const component = page.element?.contains?.(element) ? element.closest("[data-cid]") : null;
      return { element, cid: component?.dataset.cid };
    }

    /** Closes every menu branch and restores the origin in the current page tree. */
    function hideContextMenu(page, notify = true) {
      let dismissed = false;
      page.contextMenus?.forEach(menu => {
        const wasOpen = menu.style.display !== "none";
        dismissed ||= wasOpen;
        hideSubmenus(menu, page);
        menu.style.display = "none";
        if (wasOpen && notify && menu.menuComponent) emit(page, menu.menuComponent, "dismiss");
      });
      page.contextMenuPosition = null;
      if (dismissed && notify) {
        const origin = page.contextMenuReturnFocus;
        const target = origin?.element?.isConnected ? origin.element : origin?.cid &&
          (page.controls.get(origin.cid) || page.element?.querySelector(`[data-cid="${CSS.escape(origin.cid)}"]`));
        if (target && !target.disabled && !target.closest("[hidden],[inert]")) target.focus();
        page.contextMenuReturnFocus = null;
      }
    }

    /** Opens a bounded popup, retaining the origin for focus restoration on dismissal. */
    function showContextMenu(page, key, x, y, returnFocus = contextMenuFocus(page)) {
      if (!page.contextMenuPosition) page.contextMenuReturnFocus = returnFocus;
      hideContextMenu(page, false);
      page.contextMenuPosition = { key, x, y };
      const menu = page.contextMenus?.get(key);
      if (!menu) return;
      menu.style.display = "block";
      menu.style.left = `${Math.max(0, Math.min(x, window.innerWidth - menu.getBoundingClientRect().width))}px`;
      menu.style.top = `${Math.max(0, Math.min(y, window.innerHeight - menu.getBoundingClientRect().height))}px`;
      focusMenuItem(menu);
    }

    const controls = {
      /** Builds a frame or menu; submenu selection persists until toggled or dismissed. */
      group(page, component) {
        if (component.props.menu) {
          const popover = component.props.menu === "popover";
          const submenu = component.props.menu === "submenu" || popover;
          const group = common(node("div", submenu ? "webui-submenu" : "webui-context-menu"), component);
          group.setAttribute("role", "menu");
          if (submenu) {
            group.removeAttribute("role");
            const trigger = node("button", "submenu-trigger", component.props.label);
            trigger.setAttribute("role", "menuitem");
            trigger.disabled = component.props.disabled === true;
            trigger.setAttribute("aria-haspopup", "menu");
            trigger.setAttribute("aria-label", component.props.label || "");
            trigger.setAttribute("aria-expanded", "false");
            if (popover) {
              group.classList.add("webui-popover");
              trigger.setAttribute("aria-haspopup", "dialog");
              if (component.props.menu_icon && component.children?.length) {
                trigger.textContent = "";
                trigger.append(render(page, component.children[0]));
              }
            }
            const panel = node("div", "submenu-items");
            panel.setAttribute("role", popover ? "dialog" : "menu");
            if (popover) panel.setAttribute("aria-label", component.props.label || "Options");
            // A scrolling menu clips fixed descendants in WebKit. The top layer
            // lets the existing submenu escape that clip without reparenting it
            // (which would lose inherited theme and menu ancestry).
            if (typeof panel.showPopover === "function") panel.setAttribute("popover", "manual");
            panel.style.display = "none";
            /** Dismisses this branch, including any descendant top-layer panels. */
            const close = () => {
              hideSubmenus(group, page);
            };
            /** Opens this branch within the viewport while preserving its open ancestors. */
            const open = () => {
              if (popover) page.popovers?.forEach((entry, cid) => { if (cid !== component.cid) entry.close(); });
              // Click selection persists while the pointer crosses other rows.
              // Only selecting a sibling replaces this branch; ancestors stay open.
              for (const sibling of group.parentElement.children) {
                if (sibling !== group) hideSubmenus(sibling, page);
              }
              panel.style.display = "block";
              panel.showPopover?.();
              const anchor = trigger.getBoundingClientRect(), bounds = panel.getBoundingClientRect();
              let left = anchor.right + bounds.width > window.innerWidth ? anchor.left - bounds.width : anchor.right;
              let top = anchor.top;
              if (popover) {
                const position = component.props.menu_position || "bottom";
                left = ["top", "bottom"].includes(position) ? anchor.left : position === "left" ? anchor.left - bounds.width : anchor.right;
                top = position === "top" ? anchor.top - bounds.height : position === "bottom" ? anchor.bottom : anchor.top;
                (page.openPopovers ||= new Set()).add(component.cid);
              }
              panel.style.left = `${Math.max(0, Math.min(left, window.innerWidth - bounds.width))}px`;
              panel.style.top = `${Math.max(0, Math.min(top, window.innerHeight - bounds.height))}px`;
              trigger.setAttribute("aria-expanded", "true");
            };
            // Render restoration reuses positioning/popover logic without clicking
            // the trigger or delivering a synthetic script activation.
            group.openSubmenu = open;
            trigger.addEventListener("click", event => {
              event.stopPropagation();
              if (trigger.getAttribute("aria-expanded") === "true") close();
              else open();
            });
            trigger.addEventListener("keydown", event => {
              if (event.key !== "ArrowRight") return;
              event.preventDefault();
              open();
              focusMenuItem(panel);
            });
            const content = popover && component.props.menu_icon ? { ...component, children: component.children?.slice(1) } : component;
            group.append(trigger, appendChildren(page, content, panel));
            if (popover) {
              (page.popovers ||= new Map()).set(component.cid, { group, trigger, open, close });
            } else menuNavigation(panel, () => { close(); trigger.focus(); });
            return group;
          } else {
            (page.contextMenus ||= new Map()).set(component.props.key, group);
            group.style.display = "none";
            group.menuComponent = component;
            group.addEventListener("click", event => {
              if (event.target.closest?.("button,input") && !event.target.closest?.(".submenu-trigger")) hideContextMenu(page);
            });
          }
          appendChildren(page, component, group);
          menuNavigation(group);
          return group;
        }
        const group = common(node("fieldset", "webui-group"), component);
        if (["start", "center", "end"].includes(component.props.align)) group.style.justifySelf = component.props.align;
        if (component.props.constrain_width) group.style.maxWidth = "100%";
        if (component.props.width === undefined && !component.props.constrain_width &&
            component.children?.some(child => child.type === "grid" && child.props.homogeneous === false)) {
          // Keep a natural grid inside its frame, including when the frame lives
          // in a scrollable stack. Explicit constraints still win; grid scrollers
          // remain bounded by inline-size containment rather than long row text.
          group.style.minWidth = "min-content";
          // A requested minimum is a floor, not a cap on the grid's requisition.
          // The intrinsic minimum can exceed this preferred width.
          if (component.props.min_width !== undefined) group.style.width = `${component.props.min_width}px`;
        }
        if (component.props.label) group.append(node("legend", null, component.props.label));
        // An explicitly blank label has a requisition; an absent label has none.
        if (component.props.label === "") group.dataset.emptyLabel = "true";
        // Filling frames participate in their parent's vertical allocation.
        if (component.props.fill || component.props.content_align) {
          group.style.display = "flex"; group.style.flexDirection = "column";
        }
        // Align the natural content inside an allocated frame. The legend and
        // frame allocation remain independent of the child alignment request.
        if (component.props.content_align) {
          group.style.justifyContent = component.props.content_align === "center" ? "center" :
            component.props.content_align === "end" ? "flex-end" : "flex-start";
        }
        if (component.props.padding !== undefined) group.style.padding = `${component.props.padding}px`;
        if (component.props.border_color) group.style.borderColor = compositeColor(component.props.border_color);
        if (component.props.border_width !== undefined) group.style.borderWidth = `${component.props.border_width}px`;
        // A borderless layout surface has no empty frame-label requisition.
        if (component.props.border_width === 0) group.dataset.borderless = "true";
        if (component.props.radius !== undefined) group.style.borderRadius = `${component.props.radius}px`;
        if (component.props.background) group.style.backgroundColor = compositeColor(component.props.background);
        if (component.props.surface_events) group.addEventListener("click", event => {
          if (event.target.closest?.("button,input,select,textarea")) return;
          emit(page, component, "surface_activate", surfacePayload(event, group, 1, "primary"));
        });
        if (component.props.context_menu) group.addEventListener("contextmenu", event => {
          event.preventDefault();
          showContextMenu(page, component.props.context_menu, event.clientX, event.clientY);
        });
        return appendChildren(page, component, group);
      }
    };
    return { ...controls, hideSubmenus, captureMenuNavigation, restoreMenuNavigation, contextMenuFocus, hideContextMenu, showContextMenu };
  };
})();
