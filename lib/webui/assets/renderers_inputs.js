(() => {
  "use strict";
  const families = window.LichWebUIRendererFamilies ||= Object.create(null);

  /**
   * Builds input controls and page-local choice values; submission and replay stay in the application.
   * Loading registers only this factory; it does not create DOM, listeners or sockets.
   * @param {Object} context Explicit capabilities; no page map or transport state.
   * @param {Function} context.node Creates literal DOM nodes.
   * @param {Function} context.common Applies validated common properties.
   * @param {Function} context.emit Sends admitted events through the central transport.
   * @param {Function} context.appendChildren Recursively renders children in contract order.
   * @param {Function} context.findComponent Resolves the latest tree identity.
   * @param {Function} context.trackWindowGeometry Retains the existing launcher geometry boundary.
   * @param {Function} context.nativeTextStyle Applies validated native text properties.
   * @param {Object} context.renderers Shared public dictionary used by control aliases.
   * @returns {Object} Renderer functions.
   */
  families.inputs = function createInputsRenderers({
    node, common, emit, appendChildren, findComponent, trackWindowGeometry, nativeTextStyle, renderers
  }) {
    /** Registers an input and composes its label without losing the control's natural sizing. */
    function field(page, component, control, inline = false) {
      control.dataset.sensitive = String(component.props.sensitive === true || component.type === "password_input");
      const wrapper = common(node("label", `field${inline || component.props.inline ? " inline" : ""}`), component);
      if (inline) wrapper.append(control);
      if (component.props.label) wrapper.append(node("span", "field-label", component.props.label));
      if (!inline) wrapper.append(control);
      if (component.props.max_width_chars) {
        // Preserve character-based natural sizing. GTK rounds the digit advance
        // to whole layout pixels; compact entries add 8px padding and 1px border
        // on each side. The field may grow within this cap as its grid expands.
        wrapper.style.width = "100%";
        wrapper.style.maxWidth = `calc(${component.props.max_width_chars} * round(up, 1ch, 1px) + 18px)`;
        // Give grid layout both a preferred width and a shrinkable allocation;
        // a cap alone leaves the entry's smaller default intrinsic size in force.
        control.style.width = wrapper.style.maxWidth;
        control.style.maxWidth = "100%";
      }
      if (component.props.control_width) {
        control.style.width = `${component.props.control_width}px`;
        // flex-basis follows the wrapper axis: only an inline row may use its
        // width as the basis. A vertical field would otherwise become square.
        control.style.flex = inline || component.props.inline ? `0 0 ${component.props.control_width}px` : "0 0 auto";
      }
      if (component.props.control_margin !== undefined) {
        // The combo entry shares this input; its spacing must not move the outer field.
        const margin = component.props.control_margin;
        if (Number.isFinite(margin)) control.style.margin = `${margin}px`;
        else for (const side of ["top", "right", "bottom", "left"]) {
          control.style[`margin${side[0].toUpperCase()}${side.slice(1)}`] = `${margin[side] || 0}px`;
        }
      }
      if (component.props.control_width_chars) {
        control.style.width = `calc(${component.props.control_width_chars} * round(up, 1ch, 1px) + 2 * var(--entry-padding, 8px) + 2px)`;
        control.style.flex = "0 0 auto";
      }
      if (component.props.min_width_chars) {
        // A GTK width-chars request is a minimum, independent of whether its
        // parent gives the field extra space. Keep any larger pixel request.
        const minimum = `calc(${component.props.min_width_chars} * round(up, 1ch, 1px) + 2 * var(--entry-padding, 8px) + 2px)`;
        wrapper.style.minWidth = wrapper.style.minWidth ? `max(${wrapper.style.minWidth}, ${minimum})` : minimum;
      }
      page.controls.set(component.cid, control);
      return wrapper;
    }

    /** Creates a typed input while keeping sensitive defaults out of the rendered value. */
    function input(page, component, type) {
      const control = node("input");
      control.type = type;
      control.disabled = component.props.disabled === true;
      if (component.props.placeholder) control.placeholder = component.props.placeholder;
      if (component.props.max_length) control.maxLength = component.props.max_length;
      page.controls.set(component.cid, control);
      return control;
    }

    function markNaturalEntry(control, props) {
      if (!props.search && ["width", "min_width", "control_width", "control_width_chars",
        "min_width_chars", "max_width_chars"].every(key => props[key] === undefined)) {
        // Both a bare Gtk::Entry and an editable Gtk::ComboBoxText contain
        // the same natural-width entry until the script requests another size.
        control.dataset.naturalEntry = "true";
      }
    }

    /** Names one independent radio-option group within its owning page. */
    function radioGroupName(page, group) {
      return `${page.address}:option:${group}`;
    }

    /** Keeps native and menu radio peers exclusive without touching other groups. */
    function clearRadioPeers(page, selected) {
      const name = radioGroupName(page, selected.menuGroup);
      for (const peer of page.controls.values()) {
        if (peer !== selected && (peer.menuGroup === selected.menuGroup || peer.name === name)) peer.restoreChoice(false);
      }
    }

    /** Menu choices share boolean/radio values and submit the form on activation. */
    function menuChoice(page, component, radio) {
      const button = common(node("button", "webui-menu-choice", component.props.label), component);
      button.type = "button";
      button.setAttribute("role", radio ? "menuitemradio" : "menuitemcheckbox");
      button.setAttribute("aria-label", component.props.label || "");
      button.dataset.indicator = radio ? "radio" : "check";
      button.menuGroup = radio ? component.props.group : null;
      let checked = component.props.checked === true;
      button.choiceValue = () => checked;
      button.restoreChoice = value => {
        checked = value;
        button.setAttribute("aria-checked", String(value));
        button.dataset.checked = String(value);
      };
      button.restoreChoice(checked);
      page.controls.set(component.cid, button);
      button.addEventListener("click", () => {
        const changed = !radio || !checked;
        if (radio) clearRadioPeers(page, button);
        button.restoreChoice(radio || !checked);
        if (changed) emit(page, component, "change", { value: checked });
        emit(page, component, "activate");
      });
      return button;
    }

    const controls = {
      button(page, component) {
        const button = common(node("button", component.props.variant || "default"), component);
        button.textContent = component.props.label;
        if (component.props.presentation_role === "record_favorite") {
          button.dataset.favoriteState = component.props.checked ? "filled_star" : "empty_star";
        }
        button.type = "button";
        if (component.children?.length) {
          button.replaceChildren();
          appendChildren(page, component, button);
        }
        if (component.props.indicator) {
          button.dataset.indicator = component.props.indicator;
          button.setAttribute("role", component.props.indicator === "check" ? "menuitemcheckbox" : "menuitemradio");
          button.setAttribute("aria-checked", String(component.props.checked));
        }
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
      toggle(page, component) {
        if (component.props.appearance === "menu") return menuChoice(page, component, false);
        if (component.props.appearance === "switch") {
          const control = input(page, component, "checkbox");
          control.checked = component.props.checked;
          control.setAttribute("role", "switch");
          control.setAttribute("aria-label", component.props.label || component.props.accessible_label || "Switch");
          control.classList.add("webui-switch-control");
          control.addEventListener("change", () => emit(page, component, "change", { value: control.checked }));
          const wrapper = field(page, component, control, true);
          wrapper.classList.add("webui-switch");
          const track = node("span", "webui-switch-track");
          track.setAttribute("aria-hidden", "true");
          control.after(track);
          return wrapper;
        }
        if (component.props.appearance !== "button") return renderers.checkbox(page, component);
        const button = common(node("button", "webui-toggle", component.props.label || ""), component);
        button.type = "button";
        button.disabled = component.props.disabled === true;
        let checked = component.props.checked;
        button.setAttribute("aria-pressed", String(checked));
        button.choiceValue = () => checked;
        button.restoreChoice = value => {
          checked = value;
          button.setAttribute("aria-pressed", String(checked));
        };
        page.controls.set(component.cid, button);
        button.addEventListener("click", () => {
          checked = !checked;
          button.setAttribute("aria-pressed", String(checked));
          emit(page, component, "change", { value: checked });
        });
        return button;
      },
      radio_option(page, component) {
        if (component.props.appearance === "menu") return menuChoice(page, component, true);
        const control = input(page, component, "radio");
        let checked = component.props.checked;
        control.choiceValue = () => control.checked;
        control.restoreChoice = value => { checked = value; control.checked = value; };
        control.name = radioGroupName(page, component.props.group);
        control.menuGroup = component.props.group;
        control.checked = checked;
        // Native click precedes change. Publish the transition synchronously and
        // suppress its later duplicate; already-selected clicks still activate.
        const change = () => {
          if (!control.isConnected || control.disabled || control.closest("[hidden],[inert]")) return;
          if (control.checked && !checked) {
            checked = true;
            clearRadioPeers(page, control);
            emit(page, component, "change", { value: true });
          }
        };
        control.addEventListener("change", change);
        control.addEventListener("click", () => {
          if (!control.isConnected || control.disabled || control.closest("[hidden],[inert]")) return;
          change();
          // A synchronous bridge/redraw may replace this DOM control during change.
          // Resolve the same live identity rather than losing or reviving activation.
          const current = page.controls.get(component.cid);
          const latest = page.tree && findComponent(page.tree, component.cid);
          if (latest && current?.isConnected && !current.disabled && !current.closest("[hidden],[inert]")) emit(page, latest, "activate");
        });
        return field(page, component, control, true);
      },
      radio(page, component) {
        const wrapper = common(node("fieldset", "field"), component);
        wrapper.append(node("legend", null, component.props.label));
        const options = node("div", "radio-options");
        if (component.props.orientation === "vertical") options.style.flexDirection = "column";
        options.style.gap = `${component.props.gap ?? 12}px`;
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
      textarea(page, component) {
        const control = node("textarea");
        control.value = component.props.value || "";
        control.rows = component.props.rows || 5;
        control.readOnly = component.props.read_only === true;
        for (const side of ["left", "right"]) if (component.props[`padding_${side}`] !== undefined) control.style[`padding${side[0].toUpperCase()}${side.slice(1)}`] = `${component.props[`padding_${side}`]}px`;
        control.wrap = component.props.wrap === "none" ? "off" : "soft";
        control.style.overflowWrap = component.props.wrap === "word_char" ? "anywhere" : "normal";
        if (component.props.cursor_visible === false) control.style.caretColor = "transparent";
        if (component.props.follow) window.requestAnimationFrame(() => { control.scrollTop = control.scrollHeight; });
        control.disabled = component.props.disabled === true;
        if (component.props.max_length) control.maxLength = component.props.max_length;
        control.addEventListener("input", () => { if (!control.readOnly) emit(page, component, "change", { value: control.value }); });
        control.addEventListener("blur", () => {
          if (!control.readOnly && !page.restoringFocus) emit(page, component, "blur", { value: control.value });
        });
        return field(page, component, control);
      },
      text_input(page, component) {
        const control = input(page, component, component.props.search ? "search" : "text");
        nativeTextStyle(control, component.props);
        if (component.props.has_frame === false) {
          control.style.border = "none";
          control.style.boxShadow = "none";
        }
        markNaturalEntry(control, component.props);
        control.value = component.props.value;
        control.readOnly = component.props.read_only === true;
        let lastValue = control.value;
        const changed = () => {
          if (control.readOnly) return;
          if (control.value === lastValue) return;
          lastValue = control.value;
          emit(page, component, "change", { value: lastValue });
        };
        if (component.props.change_mode === "input") control.addEventListener("input", changed);
        control.addEventListener("change", changed);
        control.addEventListener("focus", () => {
          if (!page.restoringFocus) emit(page, component, "focus");
        });
        control.addEventListener("blur", () => {
          if (!control.readOnly && !page.restoringFocus) emit(page, component, "blur", { value: control.value });
        });
        control.addEventListener("keydown", (event) => {
          if (event.key === "Enter") emit(page, component, "submit");
        });
        const wrapper = field(page, component, control);
        // Retire these legacy outer/content hooks only after their producers and
        // retained consumers migrate together to a compatibility-tested observation path.
        if (component.props.hidden && component.cid.endsWith("text_input:window-geometry")) trackWindowGeometry(page, component, false);
        if (component.props.hidden && component.cid.endsWith("text_input:window-content-geometry")) trackWindowGeometry(page, component, true);
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
      /** Renders a numeric range through the existing numeric event and form path. */
      slider(page, component) {
        return renderers.number_input(page, component);
      },
      /** Renders numeric inputs and sliders with validated changes and numeric submissions. */
      number_input(page, component) {
        const control = input(page, component, component.type === "slider" ? "range" : "number");
        for (const name of ["min", "max", "step", "value"]) control[name] = component.props[name] ?? 1;
        if (component.props.snap_to_step === false) control.step = "any";
        let preciseValue = component.props.value, formattedText = null;
        const numericValue = () => component.props.digits !== undefined && control.value === formattedText ? preciseValue : control.valueAsNumber;
        const formatValue = () => {
          if (component.props.digits !== undefined && Number.isFinite(numericValue())) {
            preciseValue = numericValue();
            formattedText = preciseValue.toFixed(component.props.digits);
            control.value = formattedText;
          }
        };
        formatValue();
        if (component.props.digits !== undefined) {
          // Display precision must not silently change the numeric submission value.
          control.choiceValue = numericValue;
          control.restoreChoice = value => { formattedText = null; control.value = value; formatValue(); };
        }
        let lastValue = numericValue();
        const changed = () => {
          const value = numericValue();
          const valid = component.props.snap_to_step === false ? value >= component.props.min && value <= component.props.max : control.checkValidity();
          if (Number.isFinite(value) && valid && value !== lastValue) {
            lastValue = value;
            emit(page, component, "change", { value: lastValue });
          }
        };
        control.addEventListener("input", changed);
        control.addEventListener("change", changed);
        control.addEventListener("blur", () => { formatValue(); changed(); });
        const wrapper = field(page, component, control);
        if (component.props.stepper_buttons) {
          const row = node("span", "webui-number-stepper");
          row.style.width = `${component.props.control_width || 118}px`;
          // A standalone spin widget owns its original minimum request. Leaving
          // that request only on the label wrapper creates empty space beside a
          // smaller control. An inline labelled field keeps its separate sizing.
          if (!component.props.label && !component.props.inline && component.props.min_width !== undefined) {
            row.style.minWidth = `${component.props.min_width}px`;
          }
          control.style.width = "100%";
          control.replaceWith(row);
          row.append(control);
          let timer, repeatStep = component.props.step, repeats = 0, suppressClick = false;
          const pageStep = component.props.page_step ?? component.props.step * 10;
          const stop = () => {
            window.clearTimeout(timer);
            timer = null;
            repeatStep = component.props.step;
            repeats = 0;
          };
          const step = (direction, amount = component.props.step) => {
            if (control.disabled) return;
            if (component.props.snap_to_step === false) {
              const current = Number.isFinite(numericValue()) ? numericValue() : component.props.min;
              const next = Math.min(component.props.max, Math.max(component.props.min, current + direction * amount));
              formattedText = null;
              control.value = Number(next.toPrecision(15));
            } else if (direction < 0) control.stepDown(); else control.stepUp();
            formatValue();
            changed();
          };
          const accelerate = () => {
            if (++repeats > 5) {
              repeats = 0;
              if (repeatStep < pageStep) {
                repeatStep = Math.min(pageStep, repeatStep + (component.props.acceleration || 0));
              }
            }
          };
          (page.inputDisposers ||= []).push(() => { stop(); window.removeEventListener("blur", stop); });
          window.addEventListener("blur", stop);
          control.addEventListener("blur", stop);
          if (component.props.snap_to_step === false) {
            control.addEventListener("keydown", event => {
              if (!["ArrowUp", "ArrowDown", "PageUp", "PageDown"].includes(event.key)) return;
              event.preventDefault();
              const direction = event.key.endsWith("Up") ? 1 : -1;
              step(direction, event.key.startsWith("Page") ? pageStep : repeatStep);
              accelerate();
            });
            control.addEventListener("keyup", stop);
          }
          [-1, 1].forEach(direction => {
            const button = node("button", null, direction < 0 ? "\u2212" : "+");
            button.type = "button";
            button.disabled = control.disabled;
            button.setAttribute("aria-label", direction < 0 ? "Decrease" : "Increase");
            button.addEventListener("click", () => {
              if (suppressClick) { suppressClick = false; return; }
              step(direction);
            });
            if (component.props.acceleration !== undefined) {
              button.addEventListener("pointerdown", event => {
                if (event.button !== 0 || control.disabled) return;
                stop();
                suppressClick = true;
                button.setPointerCapture?.(event.pointerId);
                step(direction);
                const repeat = () => {
                  if (!control.isConnected || control.disabled) { stop(); return; }
                  step(direction, repeatStep);
                  accelerate();
                  timer = window.setTimeout(repeat, 50);
                };
                timer = window.setTimeout(repeat, 500);
              });
              const released = () => { stop(); window.setTimeout(() => { suppressClick = false; }, 0); };
              button.addEventListener("pointerup", released);
              button.addEventListener("pointercancel", released);
              button.addEventListener("lostpointercapture", stop);
            }
            row.append(button);
          });
        }
        return wrapper;
      },
      select(page, component) {
        // Editable legacy combos offer suggestions without restricting the text
        // value. The server enables this explicitly; ordinary selects stay closed.
        if (component.props.editable) {
          const control = input(page, component, "text");
          markNaturalEntry(control, component.props);
          // Keep the option ID separate from its visible label. Free text still
          // travels literally; form submissions and draft restoration use IDs
          // for selected options, just like an ordinary select.
          let selectedValue, selectedLabel, chooser;
          const textPrefix = component.props.free_text_prefix || "";
          const textValue = text => textPrefix + text;
          control.restoreChoice = value => {
            // An absent value is unselected; an explicit empty ID can name an option.
            selectedValue = value;
            selectedLabel = value == null ? "" : (component.props.options.find(option => option.value === value)?.label ??
              (textPrefix && value.startsWith(textPrefix) ? value.slice(textPrefix.length) : value));
            control.value = selectedLabel;
            if (chooser) {
              if (value == null) chooser.selectedIndex = -1;
              else chooser.value = value;
            }
          };
          control.choiceValue = () => control.value === selectedLabel ? (selectedValue ?? "") : textValue(control.value);
          control.restoreChoice(component.props.value);
          control.maxLength = 8192 - textPrefix.length;
          const suggestions = node("datalist");
          suggestions.id = `choices-${component.cid}`;
          control.setAttribute("list", suggestions.id);
          component.props.options.forEach(option => {
            const choice = node("option", null, option.label);
            choice.value = textPrefix ? option.label : option.value;
            suggestions.append(choice);
          });
          let lastValue = selectedValue;
          const changed = () => {
            // A custom entry clears the native picker's selection. Otherwise
            // choosing the previous option again would not fire change.
            const value = control.value === selectedLabel ? selectedValue : textValue(control.value);
            if (value === lastValue) return;
            control.restoreChoice(value);
            lastValue = value;
            emit(page, component, "change", { value: lastValue });
          };
          control.addEventListener("input", changed);
          control.addEventListener("change", changed);
          const wrapper = field(page, component, control);
          // Keep an always-visible native option picker beside the editable
          // text. Unlike datalist filtering, this picker offers every choice
          // even when the current entry contains a custom value.
          const row = node("span", "webui-editable-select");
          if (component.props.min_height) row.style.minHeight = `${component.props.min_height}px`;
          if (component.props.control_width) row.style.width = `${component.props.control_width}px`;
          // The character request belongs to the editable entry. Its adjacent
          // picker retains the existing 34px body plus its one-pixel border.
          if (component.props.control_width_chars) {
            row.style.width = `calc(${component.props.control_width_chars} * round(up, 1ch, 1px) + 2 * var(--entry-padding, 8px) + 2px + 35px)`;
          }
          const picker = node("span", "webui-choice-picker");
          const arrow = node("span", null, "\u2304");
          arrow.setAttribute("aria-hidden", "true");
          chooser = node("select");
          chooser.disabled = control.disabled;
          chooser.setAttribute("aria-label", `Choose ${component.props.label || "option"}`);
          component.props.options.forEach(option => {
            const item = node("option", null, option.label); item.value = option.value; chooser.append(item);
          });
          control.restoreChoice(component.props.value);
          chooser.addEventListener("change", () => { control.restoreChoice(chooser.value); changed(); });
          control.style.width = "100%"; control.style.flex = "1";
          control.replaceWith(row);
          picker.append(arrow, chooser); row.append(control, picker);
          wrapper.append(suggestions);
          return wrapper;
        }
        const control = node("select");
        if (component.props.min_height) control.style.minHeight = `${component.props.min_height}px`;
        control.disabled = component.props.disabled === true;
        component.props.options.forEach((option) => {
          const choice = node("option", null, option.label);
          choice.value = option.value;
          choice.selected = option.value === component.props.value;
          control.append(choice);
        });
        if (!Object.prototype.hasOwnProperty.call(component.props, "value")) control.selectedIndex = -1;
        control.addEventListener("change", () => emit(page, component, "change", { value: control.value }));
        return field(page, component, control);
      }
    };
    return controls;
  };
})();
