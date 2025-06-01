# frozen_string_literal: true

module Lich
  module Common
    module GUI
      # Provides accessibility support for the Lich GUI login system
      # Implements features to make the login GUI accessible to users with disabilities
      module Accessibility
        # Initializes accessibility features for a GTK application
        #
        # @return [void]
        def self.initialize_accessibility
          # In GTK3, accessibility is enabled by default through ATK
          # Ensure ATK is loaded by referencing a GAIL widget type
          begin
            GLib::Object.type_from_name('GailWidget')
          rescue NoMethodError => e
            Lich.log "Warning: Could not initialize accessibility: #{e.message}"
          end
        end

        # Applies accessibility properties to a widget
        #
        # @param widget [Gtk::Widget] The widget to make accessible
        # @param label [String] Accessible name for the widget
        # @param description [String] Accessible description for the widget
        # @param role [Symbol] Accessible role for the widget (e.g., :button, :text)
        # @return [void]
        def self.make_accessible(widget, label, description = nil, role = nil)
          return unless widget.respond_to?(:get_accessible)

          begin
            accessible = widget.get_accessible
            return unless accessible

            # Set accessible name
            accessible.set_name(label) if accessible.respond_to?(:set_name)

            # Set accessible description
            accessible.set_description(description) if description && accessible.respond_to?(:set_description)

            # Set accessible role
            if role && accessible.respond_to?(:set_role)
              role_value = get_atk_role(role)
              accessible.set_role(role_value) if role_value
            end
          rescue => e
            Lich.log "Warning: Could not make widget accessible: #{e.message}"
          end
        end

        # Makes a button accessible
        #
        # @param button [Gtk::Button] The button to make accessible
        # @param label [String] Accessible name for the button
        # @param description [String] Accessible description for the button
        # @return [void]
        def self.make_button_accessible(button, label, description = nil)
          make_accessible(button, label, description, :button)

          # Ensure button has a visible label for screen readers
          begin
            if button.child.is_a?(Gtk::Label)
              button.child.set_text(label) if button.child.text.empty?
            elsif !button.label.nil? && button.label.empty?
              button.label = label
            end
          rescue => e
            Lich.log "Warning: Could not set button label: #{e.message}"
          end
        end

        # Makes an entry field accessible
        #
        # @param entry [Gtk::Entry] The entry field to make accessible
        # @param label [String] Accessible name for the entry
        # @param description [String] Accessible description for the entry
        # @return [void]
        def self.make_entry_accessible(entry, label, description = nil)
          make_accessible(entry, label, description, :text)
        end

        # Makes a combo box accessible
        #
        # @param combo [Gtk::ComboBox] The combo box to make accessible
        # @param label [String] Accessible name for the combo box
        # @param description [String] Accessible description for the combo box
        # @return [void]
        def self.make_combo_accessible(combo, label, description = nil)
          make_accessible(combo, label, description, :combo_box)
        end

        # Makes a notebook tab accessible
        #
        # @param notebook [Gtk::Notebook] The notebook containing the tab
        # @param page [Gtk::Widget] The page widget
        # @param tab_label [String] Accessible name for the tab
        # @param description [String] Accessible description for the tab
        # @return [void]
        def self.make_tab_accessible(notebook, page, tab_label, description = nil)
          begin
            page_num = notebook.page_num(page)
            return if page_num == -1

            tab = notebook.get_tab_label(page)
            make_accessible(tab, tab_label, description, :page_tab)

            # Also make the page itself accessible
            make_accessible(page, tab_label, description, :panel)
          rescue => e
            Lich.log "Warning: Could not make tab accessible: #{e.message}"
          end
        end

        # Makes a window accessible
        #
        # @param window [Gtk::Window] The window to make accessible
        # @param title [String] Accessible name for the window
        # @param description [String] Accessible description for the window
        # @return [void]
        def self.make_window_accessible(window, title, description = nil)
          make_accessible(window, title, description, :window)

          # Ensure window has a title for screen readers
          begin
            window.title = title if window.title.nil? || window.title.empty?
          rescue => e
            Lich.log "Warning: Could not set window title: #{e.message}"
          end
        end

        # Adds keyboard navigation support to a widget
        #
        # @param widget [Gtk::Widget] The widget to make keyboard navigable
        # @param can_focus [Boolean] Whether the widget can receive keyboard focus
        # @param tab_order [Integer] Tab order for the widget (lower numbers first)
        # @return [void]
        def self.add_keyboard_navigation(widget, can_focus = true, tab_order = nil)
          begin
            widget.can_focus = can_focus

            # In GTK3, we need to check if the property exists before setting it
            if tab_order && widget.class.property?('tab-position')
              widget.set_property('tab-position', tab_order)
            end
          rescue => e
            Lich.log "Warning: Could not set keyboard navigation: #{e.message}"
          end
        end

        # Adds a keyboard shortcut to a widget
        #
        # @param widget [Gtk::Widget] The widget to add the shortcut to
        # @param key [String] Key for the shortcut (e.g., "a", "Return")
        # @param modifiers [Array<Symbol>] Modifier keys (e.g., [:control, :shift])
        # @return [void]
        def self.add_keyboard_shortcut(widget, key, modifiers = [])
          return unless widget.respond_to?(:add_accelerator)

          begin
            # Convert modifiers to Gdk::ModifierType
            modifier_mask = 0
            modifiers.each do |mod|
              case mod
              when :control, :ctrl
                modifier_mask |= Gdk::ModifierType::CONTROL_MASK
              when :shift
                modifier_mask |= Gdk::ModifierType::SHIFT_MASK
              when :alt
                modifier_mask |= Gdk::ModifierType::MOD1_MASK
              end
            end

            # Find or create accelerator group
            if widget.parent.is_a?(Gtk::Window)
              # Get the first accel group (replacing the unreachable loop)
              accel_group = widget.parent.accel_groups.first

              # Create new accel group if none found
              if accel_group.nil?
                accel_group = Gtk::AccelGroup.new
                widget.parent.add_accel_group(accel_group)
              end

              # Add accelerator
              widget.add_accelerator(
                "activate",
                accel_group,
                Gdk::Keyval.from_name(key),
                modifier_mask,
                Gtk::AccelFlags::VISIBLE
              )
            end
          rescue => e
            Lich.log "Warning: Could not add keyboard shortcut: #{e.message}"
          end
        end

        # Announces a message to screen readers
        #
        # @param widget [Gtk::Widget] The widget to announce from
        # @param message [String] Message to announce
        # @param _priority [Symbol] Priority of the announcement (:low, :medium, :high)
        # @return [void]
        def self.announce(widget, message, _priority = :medium)
          return unless widget.respond_to?(:get_accessible)

          begin
            accessible = widget.get_accessible
            return unless accessible

            # In GTK3/ATK, we can use state changes to trigger screen reader announcements
            if accessible.respond_to?(:notify_state_change)
              # Toggle state to trigger announcement
              accessible.notify_state_change(Atk::StateType::SHOWING, true)

              # Set name to message temporarily
              original_name = nil
              if accessible.respond_to?(:get_name) && accessible.respond_to?(:set_name)
                original_name = accessible.get_name
                accessible.set_name(message)
              end

              # Restore original name after a short delay
              if original_name
                # Using one-shot timeout (returns false to prevent repetition)
                GLib::Timeout.add(1000) do
                  accessible.set_name(original_name)
                  false # Intentionally return false to run only once
                end
              end
            end
          rescue => e
            Lich.log "Warning: Could not announce message: #{e.message}"
          end
        end

        # Creates a label for an input field to improve accessibility
        #
        # @param container [Gtk::Container] Container to add the label to
        # @param input [Gtk::Widget] Input widget to label
        # @param text [String] Label text
        # @param position [Symbol] Label position (:left, :right, :top, :bottom)
        # @return [Gtk::Label] The created label
        def self.create_accessible_label(container, input, text, position = :left)
          label = Gtk::Label.new(text)
          label.set_alignment(position == :left ? 1 : 0, 0.5)

          # Connect label to input for screen readers
          if input.respond_to?(:get_accessible) && label.respond_to?(:get_accessible)
            input_accessible = input.get_accessible
            label_accessible = label.get_accessible

            if input_accessible && label_accessible &&
               input_accessible.respond_to?(:add_relationship) &&
               defined?(Atk::RelationType::LABEL_FOR)
              label_accessible.add_relationship(Atk::RelationType::LABEL_FOR, input_accessible)
            end
          end

          # Add to container based on position
          case container
          when Gtk::Box
            case position
            when :left
              container.pack_start(label, expand: false, fill: false, padding: 5)
              container.pack_start(input, expand: true, fill: true, padding: 5)
            when :right
              container.pack_start(input, expand: true, fill: true, padding: 5)
              container.pack_start(label, expand: false, fill: false, padding: 5)
            when :top, :bottom
              # For top/bottom, we need to change the box orientation or create a vertical box
              vbox = if container.orientation == :vertical
                       container
                     else
                       vbox = Gtk::Box.new(:vertical, 5)
                       container.add(vbox)
                       vbox
                     end

              if position == :top
                vbox.pack_start(label, expand: false, fill: false, padding: 2)
                vbox.pack_start(input, expand: true, fill: true, padding: 2)
              else
                vbox.pack_start(input, expand: true, fill: true, padding: 2)
                vbox.pack_start(label, expand: false, fill: false, padding: 2)
              end
            end
          when Gtk::Grid
            # For Grid, we need row and column information which isn't provided
            # This is a simplified version
            container.add(label)
            container.add(input)
          else
            # For other containers, just add both
            container.add(label)
            container.add(input)
          end

          label
        end

        # Gets the ATK role value for a symbol
        #
        # @param role_symbol [Symbol] Role symbol
        # @return [Integer, nil] ATK role value or nil if not found
        def self.get_atk_role(role_symbol)
          return nil unless defined?(Atk::Role)

          begin
            case role_symbol
            when :button then Atk::Role::PUSH_BUTTON
            when :text then Atk::Role::TEXT
            when :combo_box then Atk::Role::COMBO_BOX
            when :page_tab then Atk::Role::PAGE_TAB
            when :panel then Atk::Role::PANEL
            when :window then Atk::Role::FRAME
            when :label then Atk::Role::LABEL
            when :list then Atk::Role::LIST
            when :list_item then Atk::Role::LIST_ITEM
            when :menu then Atk::Role::MENU
            when :menu_item then Atk::Role::MENU_ITEM
            when :check_box then Atk::Role::CHECK_BOX
            when :radio_button then Atk::Role::RADIO_BUTTON
            when :dialog then Atk::Role::DIALOG
            when :separator then Atk::Role::SEPARATOR
            when :scroll_bar then Atk::Role::SCROLL_BAR
            when :slider then Atk::Role::SLIDER
            when :spin_button then Atk::Role::SPIN_BUTTON
            when :table then Atk::Role::TABLE
            when :tree then Atk::Role::TREE
            when :tree_item then Atk::Role::TREE_ITEM
            else nil
            end
          rescue => e
            Lich.log "Warning: Could not get ATK role: #{e.message}"
            nil
          end
        end

        class << self
          private :get_atk_role
        end
      end
    end
  end
end
