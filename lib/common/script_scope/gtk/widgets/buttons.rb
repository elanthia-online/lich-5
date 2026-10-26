# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        # A button-shaped boolean input shares the ordinary checkbox state contract.
        class ToggleButton < Widget
          # Creates an unpressed button with literal text; keyword labels are supported.
          # @param text [String] positional label
          # @param label [String] keyword label, overriding text
          def initialize(text = '', label: text)
            super()
            session.refuse(self, :new) unless label.is_a?(String)
            @props.merge!(label: label, checked: false)
          end

          # Reads current callback selection or retained checkbox state.
          # @return [Boolean]
          def active? = read(:checked)
          alias active active?

          # Reads or replaces the literal control label.
          # @return [String] label text
          def label = read(:label)

          # Replaces literal caption text through the existing control contract.
          # @param value [String] literal label text
          # @return [ToggleButton] self
          def label=(value)
            write(:label, String(value))
          end

          alias set_label label=

          # Coerces legacy truthiness to the shared boolean checked property.
          # @param value [Object] legacy truthiness used for the boolean selection
          # @return [ToggleButton] self
          def set_active(value)
            changed = active? != !!value
            write(:checked, !!value)
            emit_handlers(:change, signal: 'toggled') if changed
            self
          end
          alias active= set_active

          protected

          # Selects the shared component type for this compatibility object.
          # @return [Symbol] shared component type
          # @api private
          def component_type = :toggle
          # Combines shadow properties with the current shared presentation.
          # @return [Hash] shared presentation properties
          # @api private
          def component_props = super.merge(appearance: :button)
          # Identifies the viewer input retained by this widget.
          # @return [Symbol, nil] input property, or nil for non-input widgets
          # @api private
          def input_property = :checked
          # Maps supported GTK signal spellings to shared component events.
          # @return [Hash{String => Symbol}] accepted GTK signals and shared events
          # @api private
          def signal_map = { 'toggled' => :change, 'clicked' => :change }
        end

        # Immediate boolean switch; active notifications observe the new value.
        class Switch < ToggleButton
          ActiveProperty = Data.define(:name)
          ACTIVE_PROPERTY = ActiveProperty.new('active').freeze

          # Creates an inactive switch without a visible text label.
          def initialize
            super('')
          end

          # Publishes a boolean switch value before immediate active notification.
          # @param value [Boolean] explicit boolean preference for this operation
          # @return [Switch] self
          def set_active(value)
            session.style_operation(self, :active=) do
              session.refuse(self, :active=) if destroyed? || ![true, false].include?(value)
              changed = active? != value
              write(:checked, value)
              emit_handlers(:change) if changed
            end
            self
          end
          alias active= set_active

          protected

          # Combines shadow properties with the current shared presentation.
          # @return [Hash] shared presentation properties
          # @api private
          def component_props = super.merge(appearance: :switch)
          # Maps supported GTK signal spellings to shared component events.
          # @return [Hash{String => Symbol}] accepted GTK signals and shared events
          # @api private
          def signal_map = { 'notify::active' => :change }

          # Commits the new active value before notifying property listeners.
          # @param event [Symbol] shared component event family
          # @param signal [String, nil] optional GTK signal spelling used to filter handlers
          # @return [void] result is not part of the supported script contract
          # @api private
          def emit_handlers(event, signal: nil)
            return super unless event == :change

            # Active is an immediate property notification, rather than a deferred form draft.
            @committed[:checked] = read(:checked)
            @signals.fetch(event, []).dup.each { |_name, handler| handler.call(self, ACTIVE_PROPERTY) }
            nil
          end
        end

        # Checkbox presentation shares the toggle value and programmatic signal semantics.
        class CheckButton < ToggleButton
          # With no supplied image GTK has nothing to reveal. Retain this hint
          # explicitly; image-bearing check buttons remain unsupported.
          # @param value [Boolean] whether an available image should be shown
          # @return [CheckButton] self
          def set_always_show_image(value)
            session.refuse(self, :always_show_image=) unless [true, false].include?(value) && children.empty?
            session.degrade(:checkbox_image_hint, 'always-show-image has no effect on an image-free checkbox') if value
            self
          end
          alias always_show_image= set_always_show_image

          # Ordinary checkboxes already show a separate indicator. Button-style mode
          # must be implemented deliberately rather than silently losing this request.
          # @param value [Boolean] only true is supported
          # @return [void]
          def draw_indicator=(value)
            session.refuse(self, :draw_indicator=) unless value == true
          end
          alias set_mode draw_indicator=

          # Space toggles a checkbox; it does not receive the focused default action.
          # GTK default-activation routing has no checkbox equivalent in the
          # browser. Accept the hint explicitly, retaining normal Space/click
          # activation and reporting the ignored true request once per session.
          # @param value [Boolean] either value is accepted; true is ignored and reported
          # @return [void]
          def receives_default=(value)
            session.refuse(self, :receives_default=) unless [true, false].include?(value)
            session.degrade(:checkbox_default, 'checkbox receives-default is ignored; activation uses Space or click') if value
          end
          alias set_receives_default receives_default=

          protected

          # Selects the shared component type for this compatibility object.
          # @return [Symbol] shared component type
          # @api private
          def component_type = :checkbox
          # Combines shadow properties with the current shared presentation.
          # @return [Hash] shared presentation properties
          # @api private
          def component_props = @props.dup
        end

        class Button < Widget
          # Only the measured borderless request is accepted; the browser keeps its theme.
          # @param value [Symbol] :none
          # @return [Button] self
          def set_relief(value)
            session.refuse(self, :relief=) unless value == :none
            session.degrade(:button_relief, 'native button relief is omitted; the browser button retains its theme')
            self
          end
          alias relief= set_relief

          # Copies a bounded direction caption into this button, not another browser control.
          # File images and generic image children remain unsupported by this facade.
          # @param value [Image] same-owner Up/Down symbolic descriptor
          # @return [Button] self
          def set_image(value)
            session.synchronize do
              valid = value.instance_of?(Image) && value.session.equal?(session) && !value.destroyed? && !value.parent &&
                      value.directional_caption && children.empty? && (label.empty? || @button_image)
              session.refuse(self, :image=) unless valid
              self.label = value.directional_caption
              @button_image = value
            end
            self
          end
          alias image= set_image

          # Returns the symbolic image descriptor retained by this button.
          # @return [Image, nil] retained symbolic descriptor
          def image = @button_image

          # Retains a single plain Label as real typed content, including live updates.
          # @param child [Widget] same-session child governed by this container
          # @return [Button] self
          # @raise [UnsupportedOperation] for other child types or occupied/retired buttons
          def add(child)
            session.synchronize do
              valid = !destroyed? && @children.empty? && child.is_a?(Label) &&
                      !child.destroyed? && child.send(:component_type) == :text
              session.refuse(self, :add) unless valid
              super
            end
          end

          # Serializes child removal with single-child admission.
          # @param child [Widget] same-session child governed by this container
          # @return [Button] self
          def remove(child)
            session.synchronize { super }
          end

          # GTK requests are minima. Keep action text free to grow with the
          # browser font and padding instead of clipping it to a fixed box.
          # @param value [Integer] bounded layout or model integer request
          # @return [Button] self
          def set_width_request(value)
            write(:min_width, Integer(value))
          end
          alias width_request= set_width_request

          # Applies a content height floor while allowing natural growth.
          # @param value [Integer] bounded layout or model integer request
          # @return [Button] self
          def set_height_request(value)
            write(:min_height, Integer(value))
          end
          alias height_request= set_height_request

          # The native button receives Enter when focused, without becoming a page-wide
          # default action. Other default-routing requests remain unsupported.
          # @param value [Boolean] only true is supported
          # @return [void]
          def receives_default=(value)
            session.refuse(self, :receives_default=) unless value == true
          end
          alias set_receives_default receives_default=
          # Creates a literal action label, removing mnemonic underscores when requested.
          # Stock-button IDs are unsupported; no native GTK stock catalog is loaded.
          # @param text [String, nil] optional positional caption
          # @param label [String, nil] keyword caption overriding the positional text
          # @param use_underline [Boolean] whether constructor captions drop mnemonic underscores
          # @param stock_id [nil] native stock-button identifiers are unsupported
          def initialize(text = nil, label: text, use_underline: true, stock_id: nil)
            super()
            label = '' if label.nil?
            session.refuse(self, :new) unless label.is_a?(String) && stock_id.nil?
            @props[:label] = use_underline ? label.delete('_') : label
          end

          # Reads the retained action label.
          # @return [String]
          def label = read(:label)

          # Writes literal action text through the shared button contract.
          # @param value [Object] literal text converted with String before publication
          # @return [Button] self
          def label=(value)
            write(:label, String(value))
          end
          alias set_label label=

          protected

          # Selects the shared component type for this compatibility object.
          # @return [Symbol] shared component type
          # @api private
          def component_type = :button
          # Maps supported GTK signal spellings to shared component events.
          # @return [Hash{String => Symbol}] accepted GTK signals and shared events
          # @api private
          def signal_map = { 'clicked' => :activate }
        end

        # Individually placed radio members share a same-owner group and real radio inputs.
        class RadioButton < CheckButton
          # Accepts a label, a member/group plus label, or keyword member/label.
          # The first member starts active; joining members start inactive.
          # @param group_or_label [RadioButton, Array<RadioButton>, String, nil] group leader, group snapshot or positional caption
          # @param text [String] initial literal caption
          # @param member [RadioButton, Array<RadioButton>, nil] explicit same-session member or group snapshot
          # @param label [String, nil] optional keyword caption overriding positional forms
          # @raise [UnsupportedOperation] for foreign or invalid groups
          def initialize(group_or_label = nil, text = '', member: nil, label: nil)
            leader = member.nil? ? (group_or_label unless group_or_label.is_a?(String)) : member
            if leader.is_a?(Array)
              Gtk.session.refuse(self, :new) unless leader.all? { |peer| peer.is_a?(RadioButton) && peer.group.include?(leader.first) }
              leader = leader.first
            end
            super(label.nil? ? (group_or_label.is_a?(String) ? group_or_label : text) : label)
            valid_group = leader.nil? || (leader.is_a?(RadioButton) && leader.session.equal?(session) && !leader.destroyed?)
            session.refuse(self, :new) unless valid_group
            @group = leader ? leader.instance_variable_get(:@group) : []
            @props[:checked] = @group.empty?
            @props[:group] = leader ? leader.send(:read, :group) : "radio-#{object_id}"
            @group << self
          end

          # Returns a snapshot suitable for the legacy group constructor.
          # @return [Array<RadioButton>]
          def group = @group.dup

          # Retires group membership before destroyed controls can be selected again.
          # @return [void]
          def mark_destroyed
            @group.delete(self)
            super
          end

          # A shared radio group must occupy one page; linked windows are unsupported.
          # @return [Lich::WebUI::Adapter::Handle] opaque control handle
          def materialize
            session.refuse(self, :group) if @group.any? { |peer| !peer.equal?(self) && peer.parent && !peer.toplevel.equal?(toplevel) }
            super
          end

          # Changes all affected member values before emitting ordered toggled signals.
          # @param value [Object] legacy truthiness; true selects this member exclusively
          # @return [RadioButton] self
          def set_active(value)
            # GTK radio deactivation preserves the selection and emits no toggled signal.
            # Select another member with true to switch the group instead.
            return self unless value

            session.synchronize do
              changes = @group.filter_map do |peer|
                desired = peer.equal?(self) ? !!value : (value ? false : peer.active?)
                [peer, desired] if peer.active? != desired
              end
              changes.sort_by! { |_peer, desired| desired ? 1 : 0 }
              changes.each { |peer, desired| peer.send(:write, :checked, desired) }
              changes.each { |peer, _desired| peer.send(:emit_handlers, :change, signal: 'toggled') }
            end
            self
          end
          alias active= set_active

          protected

          # Selects the shared component type for this compatibility object.
          # @return [Symbol] shared component type
          # @api private
          def component_type = :radio_option
          # Maps supported GTK signal spellings to shared component events.
          # @return [Hash{String => Symbol}] accepted GTK signals and shared events
          # @api private
          def signal_map = { 'toggled' => :change, 'clicked' => :activate }
        end
      end
    end
  end
end
