(() => {
  "use strict";
  const families = window.LichWebUIRendererFamilies ||= Object.create(null);

  /**
   * Builds literal text, image and composite surfaces without interpreting HTML or CSS source.
   * Loading registers only this factory; it does not create DOM, listeners or sockets.
   * @param {Object} context Explicit capabilities; no page map or transport state.
   * @param {Function} context.node Creates literal DOM nodes.
   * @param {Function} context.common Applies validated common properties.
   * @param {Function} context.bound Checks delivered event authority.
   * @param {Function} context.emit Sends admitted events through the central transport.
   * @param {Function} context.observeAllocation Registers observers owned by the current render.
   * @param {Function} context.nativeTextStyle Applies validated native text properties.
   * @param {Function} context.compositeColor Maps validated colors to renderer-owned CSS.
   * @param {Function} context.surfacePayload Maps pointer coordinates to surface pixels.
   * @param {Function} context.showContextMenu Opens a page-local menu and retains return focus.
   * @returns {Object} Renderer functions.
   */
  families.display = function createDisplayRenderers({
    node, common, bound, emit, observeAllocation, nativeTextStyle, compositeColor, surfacePayload, showContextMenu
  }) {
    // Pango's middle ellipsis is allocation-dependent. Measure literal text in
    // the rendered font, preserving the full value for accessibility and resize.
    function middleEllipsis(page, element, content, props) {
      const parts = window.Intl?.Segmenter
        ? Array.from(new window.Intl.Segmenter(undefined, { granularity: "grapheme" }).segment(content), part => part.segment)
        : Array.from(content);
      element.style.overflow = "hidden";
      element.style.whiteSpace = "pre";
      element.style.minWidth = "0";
      element.setAttribute("aria-label", content);
      let preferredWidth = null;
      const fit = () => {
        if (!element.isConnected || element.clientWidth <= 0) return;
        element.textContent = content;
        if (preferredWidth === null && element.scrollWidth > element.clientWidth) {
          const cssCap = Number.parseFloat(window.getComputedStyle?.(element)?.maxWidth);
          // The original Pango markup declares points. CreatureBar draws those
          // labels at equivalent CSS pixels, but Gtk::Label's character request
          // is still measured in points. Preserve that natural request before
          // replacing the DOM text with a shorter middle-ellipsized string.
          const cap = Number.isFinite(cssCap) ? Math.round(cssCap * (props.font_unit === "px" ? 4 / 3 : 1)) : Infinity;
          preferredWidth = Math.min(element.scrollWidth, cap);
          element.style.width = `${preferredWidth}px`;
          const horizontalMargin = props.margin && typeof props.margin === "object"
            ? (props.margin.left || 0) + (props.margin.right || 0) : 0;
          element.style.maxWidth = horizontalMargin ? `calc(100% - ${horizontalMargin}px)` : "100%";
        }
        if (element.scrollWidth <= element.clientWidth) return;
        const shorten = count => parts.slice(0, Math.ceil(count / 2)).join("") + "\u2026" +
          (count > 1 ? parts.slice(-Math.floor(count / 2)).join("") : "");
        let low = 0, high = parts.length - 1;
        while (low < high) {
          const count = Math.ceil((low + high) / 2);
          element.textContent = shorten(count);
          if (element.scrollWidth <= element.clientWidth) low = count; else high = count - 1;
        }
        element.textContent = shorten(low);
      };
      observeAllocation(page, element, fit);
    }

    // Reuses the bounded image/label/bar/region model reviewed in lich-5. Unlike
    // its drop-shadow tint, a mask actually colors the requested image pixels.
    function compositeLayer(page, component, layer) {
      if (layer.kind === "rectangle") {
        const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
        const rect = document.createElementNS("http://www.w3.org/2000/svg", "rect");
        svg.setAttribute("width", String(layer.w)); svg.setAttribute("height", String(layer.h));
        Object.assign(svg.style, { overflow: "visible", pointerEvents: "none" });
        rect.setAttribute("width", String(layer.w)); rect.setAttribute("height", String(layer.h));
        rect.setAttribute("fill", layer.mode === "fill" ? compositeColor(layer.color) : "none");
        if (layer.mode === "stroke") {
          rect.setAttribute("stroke", compositeColor(layer.color));
          rect.setAttribute("stroke-width", String(layer.line_width || 2));
        }
        svg.append(rect);
        return svg;
      }
      if (layer.kind === "marker") {
        const marker = node("div", "composite-marker");
        Object.assign(marker.style, { width: `${layer.w}px`, height: `${layer.h}px`, pointerEvents: "none" });
        const color = compositeColor(layer.color), line = layer.line_width || 2;
        if (layer.shape === "ring") {
          Object.assign(marker.style, { border: `${line}px solid ${color}`, borderRadius: "50%" });
        } else {
          const length = Math.hypot(layer.w, layer.h), angle = Math.atan2(layer.h, layer.w) * 180 / Math.PI;
          [angle, -angle].forEach(rotation => {
            const stroke = node("div");
            Object.assign(stroke.style, { position: "absolute", left: "50%", top: "50%", width: `${length}px`,
              height: `${line}px`, backgroundColor: color, transform: `translate(-50%, -50%) rotate(${rotation}deg)` });
            marker.append(stroke);
          });
        }
        return marker;
      }
      if (layer.kind === "image") {
        const image = node(layer.tint ? "div" : "img", "composite-image");
        if (layer.tint) {
          // Keep intrinsic image dimensions when a consumer omits w/h.
          const sizing = node("img");
          sizing.src = layer.src;
          sizing.alt = "";
          Object.assign(sizing.style, { opacity: "0", display: "block", width: layer.w === undefined ? "auto" : "100%",
            height: layer.h === undefined ? "auto" : "100%" });
          image.append(sizing);
          image.style.backgroundColor = compositeColor(layer.tint);
          // Multiply the source raster so tint preserves its shading; the mask
          // restores alpha instead of turning the silhouette into a solid color.
          image.style.backgroundImage = `url(${JSON.stringify(layer.src)})`;
          image.style.backgroundSize = "100% 100%";
          image.style.backgroundBlendMode = "multiply";
          image.style.maskImage = `url(${JSON.stringify(layer.mask || layer.src)})`;
          image.style.maskSize = "100% 100%";
        } else {
          image.src = layer.src;
          image.alt = "";
          if (layer.mask) { image.style.maskImage = `url(${JSON.stringify(layer.mask)})`; image.style.maskSize = "100% 100%"; }
        }
        if (layer.w !== undefined) image.style.width = `${layer.w}px`;
        if (layer.h !== undefined) image.style.height = `${layer.h}px`;
        image.style.opacity = String(layer.opacity ?? 1);
        image.style.pointerEvents = "none";
        return image;
      }
      if (layer.kind === "label") {
        const label = node("div", "composite-label", layer.text);
        label.style.color = compositeColor(layer.tone);
        label.style.textAlign = layer.align || "start";
        if (layer.emphasis === "strong") label.style.fontWeight = "bold";
        if (layer.emphasis === "subtle") label.style.opacity = "0.65";
        nativeTextStyle(label, layer);
        if (layer.w !== undefined) label.style.width = `${layer.w}px`;
        if (layer.h !== undefined) {
          label.style.height = `${layer.h}px`;
          label.style.display = "flex";
          label.style.alignItems = "center";
          label.style.justifyContent = { start: "flex-start", center: "center", end: "flex-end" }[layer.align || "start"];
        }
        return label;
      }
      if (layer.kind === "bar") {
        const track = node("div", "composite-bar");
        Object.assign(track.style, { width: `${layer.w}px`, height: `${layer.h}px` });
        const fill = node("div", "composite-bar-fill");
        const vertical = layer.orientation === "vertical";
        Object.assign(fill.style, { position: "absolute", bottom: "0px", left: "0px",
          width: vertical ? "100%" : `${layer.value * 100}%`, height: vertical ? `${layer.value * 100}%` : "100%",
          backgroundColor: compositeColor(layer.tone) });
        track.append(fill);
        return track;
      }
      if (layer.kind === "region") {
        const region = node(layer.activates ? "button" : "div", "composite-region");
        Object.assign(region.style, { width: `${Math.abs(layer.x2 - layer.x1)}px`, height: `${Math.abs(layer.y2 - layer.y1)}px` });
        region.dataset.region = layer.key;
        region.title = layer.label || layer.key;
        if (layer.activates) {
          region.type = "button";
          region.setAttribute("aria-label", layer.label || layer.key);
          region.addEventListener("click", event => {
            if (!event.ctrlKey && !event.shiftKey && !event.altKey && bound(page, component.cid, "region_activate")) {
              event.stopPropagation();
              emit(page, component, "region_activate", { region: layer.key });
            }
          });
        } else region.style.pointerEvents = layer.label ? "auto" : "none";
        return region;
      }
    }

    const controls = {
      log(_page, component) {
        const log = common(node("div", "webui-log", component.props.lines.slice(-component.props.max_lines)
          .map(line => Array.isArray(line) ? line.join("") : line).join("\n")), component);
        log.setAttribute("role", "log");
        for (const side of ["left", "right"]) if (component.props[`padding_${side}`] !== undefined) log.style[`padding${side[0].toUpperCase()}${side.slice(1)}`] = `${component.props[`padding_${side}`]}px`;
        log.style.whiteSpace = component.props.wrap === "none" ? "pre" : "pre-wrap";
        log.style.overflowWrap = component.props.wrap === "word_char" ? "anywhere" : "normal";
        // The enclosing scroll component owns geometry and measurements. Follow
        // after its restoration frame, so the requested end is not overwritten.
        if (component.props.follow) window.requestAnimationFrame(() => window.requestAnimationFrame(() => {
          if (!log.isConnected) return;
          const scroll = log.closest(".webui-scroll");
          if (scroll) scroll.scrollTop = scroll.scrollHeight;
        }));
        return log;
      },
      text(page, component) {
        const fragments = component.props.fragments;
        const content = fragments ? fragments.map(part => typeof part === "string" ? part : part.content).join("") : component.props.content;
        const fill = element => {
          element.textContent = "";
          if (!fragments || fragments.every(part => typeof part === "string")) { element.textContent = content; return element; }
          fragments.forEach(part => {
            if (typeof part === "string") { element.append(document.createTextNode(part)); return; }
            const span = node("span", "webui-text-fragment", part.content);
            nativeTextStyle(span, part);
            if (part.emphasis) span.style.fontWeight = part.emphasis === "strong" ? "bold" : "normal";
            if (part.font_weight !== undefined) span.style.fontWeight = String(part.font_weight);
            if (part.letter_spacing !== undefined) span.style.letterSpacing = `${part.letter_spacing}px`;
            if (part.emphasis === "subtle") span.style.opacity = "0.72";
            if (part.underline) span.style.textDecorationLine = "underline";
            if (part.scale !== undefined) span.style.fontSize = part.font_size !== undefined
              ? `${part.font_size * part.scale}${part.font_unit || "pt"}` : `${part.scale}em`;
            element.append(span);
          });
          return element;
        };
        const text = common(fill(node("div", "webui-text")), component);
        text.style.whiteSpace = component.props.wrap === false ? "pre" : "pre-wrap";
        nativeTextStyle(text, component.props);
        if (component.props.line_limit > 0) {
          text.style.display = "-webkit-box";
          text.style.webkitBoxOrient = "vertical";
          text.style.webkitLineClamp = String(component.props.line_limit);
          text.style.overflow = "hidden";
        }
        const props = component.props;
        if (props.padding_x !== undefined) text.style.paddingInline = `${props.padding_x}px`;
        if (props.padding_y !== undefined) text.style.paddingBlock = `${props.padding_y}px`;
        if (props.content_vertical_align) {
          text.style.display = "grid";
          text.style.alignContent = props.content_vertical_align;
        }
        // An inner writing-mode box contributes swapped natural dimensions for
        // quarter-turns; rotating the outer element alone would overlap neighbors.
        // GTK angles are counterclockwise. Preserve ordinary literal text at zero.
        const rotation = Number(props.rotation || 0);
        if (rotation) {
          const label = fill(node("span", "webui-rotated-text"));
          text.textContent = "";
          text.style.display = "grid";
          text.style.justifyItems = props.align || "center";
          text.style.alignContent = props.content_vertical_align || "center";
          if (rotation === 90 || rotation === 270) {
            label.style.writingMode = "vertical-rl";
            label.style.textOrientation = "sideways";
          }
          if (rotation === 90 || rotation === 180) label.style.transform = "rotate(180deg)";
          text.append(label);
        }
        if (props.line_justify) {
          // Placement belongs to the outer label. Only lines within its natural
          // text block are justified; one line must not move to the opposite edge.
          // Nest inside a rotated label so its writing mode still determines size.
          const target = rotation ? text.firstElementChild : text;
          const lines = fill(node("span", "webui-justified-lines"));
          lines.style.display = "inline-block";
          lines.style.maxWidth = "100%";
          lines.style.verticalAlign = "top";
          lines.style.textAlign = props.line_justify;
          if (props.content_vertical_align) lines.style.justifySelf = props.align || "start";
          target.textContent = "";
          target.append(lines);
        }
        if (component.props.min_width_chars) {
          const minimum = `calc(${component.props.min_width_chars} * round(up, 1ch, 1px))`;
          text.style.minWidth = text.style.minWidth ? `max(${text.style.minWidth}, ${minimum})` : minimum;
        }
        if (component.props.max_width_chars) text.style.maxWidth = `${component.props.max_width_chars}ch`;
        if (component.props.ellipsize === "middle") middleEllipsis(page, text, content, component.props);
        if (component.props.ellipsize === "end") {
          text.style.overflow = "hidden";
          text.style.whiteSpace = "pre";
          text.style.textOverflow = "ellipsis";
          text.style.minWidth = "0";
          text.setAttribute("aria-label", content);
        }
        return text;
      },
      /**
       * Render text and HTTP(S) links without sending host cookies to other ports.
       * @param {object} _page Owning page (unused by this stateless control).
       * @param {object} component Validated Markdown component and content.
       * @returns {HTMLElement} Text with permitted links; refused links remain labels.
       */
      markdown(_page, component) {
        // Setup labels use Markdown links in place of GTK's label anchors.
        // Build text nodes and HTTP(S) anchors; never interpret supplied HTML.
        const wrapper = common(node("div", "webui-markdown"), component);
        wrapper.style.whiteSpace = "pre-wrap";
        const content = component.props.content;
        const links = /\[([^\]]+)\]\((https?:\/\/(?:[^\s()]|\([^\s()]*\))+)(?: "((?:\\["\\]|[^"\\])*)")?\)/g;
        let offset = 0;
        for (const match of content.matchAll(links)) {
          wrapper.append(node("span", null, content.slice(offset, match.index)));
          let destination = null;
          try {
            const candidate = new URL(match[2]);
            const current = new URL(`${window.location.protocol}//${window.location.host}`);
            // Cookies have no port boundary. Normalize numeric IP aliases too.
            if (candidate.hostname !== current.hostname || candidate.origin === current.origin) destination = candidate.href;
          } catch (_) { /* Malformed destinations remain ordinary text. */ }
          const link = node(destination ? "a" : "span", null, match[1]);
          if (match[3] !== undefined) link.title = match[3].replace(/\\(["\\])/g, "$1");
          if (destination && component.props.disabled) {
            link.setAttribute("aria-disabled", "true");
            link.tabIndex = -1;
          } else if (destination) {
            link.href = destination;
            link.target = "_blank";
            link.rel = "noopener noreferrer";
          }
          wrapper.append(link);
          offset = match.index + match[0].length;
        }
        wrapper.append(node("span", null, content.slice(offset)));
        return wrapper;
      },
      progress(_page, component) {
        const wrapper = common(node("label", "webui-progress"), component);
        if (component.props.label) wrapper.append(node("span", null, component.props.label));
        const progress = node("progress");
        if (component.props.fill_color) {
          progress.style.setProperty("--progress-fill", compositeColor(component.props.fill_color));
        }
        progress.max = 1;
        if (!component.props.indeterminate) progress.value = component.props.value;
        wrapper.append(progress);
        return wrapper;
      },
      image(_page, component) {
        const image = common(node("img", "webui-image"), component);
        if (component.props.src) image.src = component.props.src;
        else image.style.visibility = "hidden";
        image.alt = component.props.alt || "";
        const scale = component.props.scale || 1;
        if (scale !== 1) {
          const resize = () => {
            image.style.width = `${(component.props.width ?? image.naturalWidth) * scale}px`;
            image.style.height = `${(component.props.height ?? image.naturalHeight) * scale}px`;
          };
          image.addEventListener("load", resize);
          if (image.complete) resize();
        }
        return image;
      },
      // The existing composite vocabulary serves native maps and creature panels.
      // The outer box reserves scaled space; events use absolute image pixels.
      composite(page, component) {
        const props = component.props;
        const scale = props.scale || 1;
        const wrapper = common(node("div", "webui-composite"), component);
        wrapper.style.width = `${props.width * scale}px`;
        wrapper.style.height = `${props.height * scale}px`;
        const surface = node("div", "composite-surface");
        Object.assign(surface.style, { position: "relative", width: `${props.width}px`, height: `${props.height}px`,
          transformOrigin: "top left", transform: `scale(${scale})` });
        if (props.clip_layers) surface.style.overflow = "hidden";
        const regions = new Map();
        props.layers.forEach(layer => {
          const element = compositeLayer(page, component, layer);
          if (!element) return;
          element.classList.add("composite-layer");
          Object.assign(element.style, { position: "absolute", left: `${layer.x ?? Math.min(layer.x1, layer.x2)}px`,
            top: `${layer.y ?? Math.min(layer.y1, layer.y2)}px` });
          if (layer.kind === "region") regions.set(layer.key, element);
          surface.append(element);
        });
        let dragged = false;
        if (props.surface_events) {
          let drag;
          surface.addEventListener("pointerdown", event => {
            const scroller = surface.closest(".webui-scroll");
            if (event.button !== 0 || event.target.closest("button") || !scroller) return;
            dragged = false;
            drag = { id: event.pointerId, x: event.clientX, y: event.clientY,
              left: scroller.scrollLeft, top: scroller.scrollTop, scroller };
            surface.setPointerCapture?.(event.pointerId);
          });
          surface.addEventListener("pointermove", event => {
            if (!drag || event.pointerId !== drag.id) return;
            const dx = event.clientX - drag.x, dy = event.clientY - drag.y;
            if (!dragged && Math.abs(dx) <= 4 && Math.abs(dy) <= 4) return;
            dragged = true;
            drag.scroller.scrollLeft = drag.left - dx;
            drag.scroller.scrollTop = drag.top - dy;
          });
          const endDrag = event => {
            if (!drag || drag.id !== event.pointerId) return;
            if (surface.hasPointerCapture?.(drag.id)) surface.releasePointerCapture(drag.id);
            drag = null;
            if (event.type === "pointercancel") dragged = false;
          };
          surface.addEventListener("pointerup", endDrag);
          surface.addEventListener("pointercancel", endDrag);
          surface.addEventListener("click", event => {
            if (dragged) { dragged = false; return; }
            emit(page, component, "surface_activate", surfacePayload(event, surface, scale, "primary"));
          });
        }
        if (props.surface_events || props.popup) surface.addEventListener("contextmenu", event => {
          event.preventDefault();
          if (props.context_menu) showContextMenu(page, props.context_menu, event.clientX, event.clientY);
          if (props.popup) {
            const size = props.popup.size || [500, 600];
            window.open(`/?page=${encodeURIComponent(props.popup.page)}`, "_blank", `noopener,width=${size[0]},height=${size[1]}`);
          } else emit(page, component, "surface_activate", surfacePayload(event, surface, scale, "secondary"));
        });
        if (bound(page, component.cid, "zoom")) surface.addEventListener("wheel", event => {
          if (!event.ctrlKey) return;
          event.preventDefault();
          emit(page, component, "zoom", { direction: event.deltaY < 0 ? "in" : "out" });
        }, { passive: false });
        wrapper.append(surface);
        if (props.scroll_origin) {
          const signature = JSON.stringify(props.scroll_origin);
          const origins = page.compositeOrigins ||= new Map();
          if (origins.get(component.cid) !== signature) {
            origins.set(component.cid, signature);
            window.requestAnimationFrame(() => window.requestAnimationFrame(() => {
              const scroller = wrapper.closest?.(".webui-scroll");
              if (scroller) [scroller.scrollLeft, scroller.scrollTop] = props.scroll_origin;
            }));
          }
        }
        if (props.scroll_to) {
          const target = props.layers.find(layer => layer.kind === "region" && layer.key === props.scroll_to);
          const signature = JSON.stringify([props.scroll_to, target?.x1, target?.y1, scale, props.layers.find(layer => layer.kind === "image")?.src]);
          const centers = page.compositeCenters ||= new Map();
          if (centers.get(component.cid) !== signature) {
            centers.set(component.cid, signature);
            // Restore the containing scroll view first, then apply a changed
            // marker target. Ordinary redraws must not undo the user's panning.
            window.requestAnimationFrame(() => window.requestAnimationFrame(() => {
              if (wrapper.isConnected) regions.get(props.scroll_to)?.scrollIntoView?.({ block: "center", inline: "center" });
            }));
          }
        } else page.compositeCenters?.delete(component.cid);
        return wrapper;
      }
    };
    return controls;
  };
})();
