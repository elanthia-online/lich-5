# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        class Notebook < Widget
          include Container

          # Creates an empty tab set with the first tab selected by default.
          def initialize
            super
            @props[:names] = []
            @props[:selected] = 0
            @tabs = []
            @actions = {}
            @props[:headers] = []
          end

          # The shared tabs component already places selectors above page content.
          # @param position [Symbol] only :top is supported
          # @return [Notebook] self
          def set_tab_pos(position)
            session.refuse(self, :set_tab_pos) unless position == :top
            self
          end
          alias tab_pos= set_tab_pos

          # Validates the border request and reports theme-controlled tab borders.
          # @param value [Boolean] explicit boolean preference for this operation
          # @return [Notebook] self
          def set_show_border(value)
            session.refuse(self, :set_show_border) unless value == true || value == false
            session.degrade(:notebook_border, 'tab border styling follows the browser theme')
            self
          end
          alias show_border= set_show_border

          # Browser tabs remain reachable through their host's overflow behavior.
          # @param value [Boolean] explicit boolean preference for this operation
          # @return [Notebook] self
          def set_scrollable(value)
            session.refuse(self, :set_scrollable) unless [true, false].include?(value)
            session.degrade(:notebook_scrollable, 'tab overflow follows the browser layout')
            self
          end
          alias scrollable= set_scrollable

          # Legacy tab padding is theme-owned and does not alter page content margins.
          # @param value [Integer] bounded layout or model integer request
          # @return [Notebook] self
          def set_tab_border(value)
            session.refuse(self, :set_tab_border) unless value.is_a?(Integer) && value.between?(0, 65_535)
            session.degrade(:notebook_tab_border, 'tab padding follows the browser theme')
            self
          end
          alias tab_border= set_tab_border

          # Hides only page selectors; the selected page and notebook sizing remain.
          # @param value [Boolean] whether the browser exposes tab buttons
          # @return [void] result is not part of the supported script contract
          def show_tabs=(value)
            session.refuse(self, :show_tabs=) unless [true, false].include?(value)
            write(:show_tabs, value)
          end
          alias set_show_tabs show_tabs=

          # Owns an auxiliary tab-strip widget independently of indexed pages.
          # Replacement and nil clearing detach the old widget for reuse; publication refusal is atomic.
          # @param widget [Widget, nil] live unparented widget from this session
          # @param position [Symbol] :start or :end
          # @return [Notebook] self
          def set_action_widget(widget, position)
            session.style_operation(self, :set_action_widget) do
              session.refuse(self, :set_action_widget) if destroyed? || !%i[start end].include?(position)
              previous = @actions[position]
              return self if widget.equal?(previous)
              if widget
                valid = widget.is_a?(Widget) && !widget.is_a?(Window) && widget.session.equal?(session) && !widget.destroyed? && !widget.parent
                ancestor = self
                while ancestor
                  valid &&= !ancestor.equal?(widget)
                  ancestor = ancestor.parent
                end
                session.refuse(self, :set_action_widget) unless valid
              end
              candidate = widget ? @actions.merge(position => widget) : @actions.except(position)
              session.port.layout_tab_actions(@handle, actions: candidate.transform_values(&:materialize)) if @handle
              previous.send(:parent=, nil) if previous
              widget.send(:parent=, self) if widget
              @actions = candidate
              session.refresh_label_styles
              refresh_layout!
            end
            self
          end

          # Returns an auxiliary tab-strip action without treating it as a page.
          # @param position [Symbol] :start or :end tab-strip side
          # @return [Widget, nil] current action; never an indexed page
          def get_action_widget(position)
            session.style_operation(self, :get_action_widget) do
              session.refuse(self, :get_action_widget) unless %i[start end].include?(position)
              @actions[position]
            end
          end

          # Pages require an explicit paired header; generic container mutation
          # cannot bypass the atomic notebook collection path.
          # @param _child [Widget] child ignored by this unsupported or default operation
          # @return [void] always refuses this unsupported mutation
          def add(_child) = session.refuse(self, :add)
          # Refuses generic child reordering that bypasses the paired tab collection.
          # @param _child [Widget] child ignored by this unsupported or default operation
          # @param _index [Integer] position ignored by this unsupported operation
          # @return [void] always refuses this unsupported mutation
          def reorder_child(_child, _index) = session.refuse(self, :reorder_child)

          # Counts indexed pages independently of headers and auxiliary actions.
          # @return [Integer] number of actual pages, excluding tab-label widgets
          def n_pages = @children.length

          # Returns the actual page, including hidden pages; every negative index
          # names the last page, matching GTK. Out-of-range and empty lookups are nil.
          # @param index [Integer] GTK child or page position; negative values use the operation default
          # @return [Widget, nil] page at the GTK index, or nil when absent
          def get_nth_page(index)
            session.style_operation(self, :get_nth_page) do
              session.refuse(self, :get_nth_page) if destroyed? || !index.is_a?(Integer)
              index = n_pages - 1 if index.negative?
              @children[index] if index.between?(0, n_pages - 1)
            end
          end

          # Selects the last page for GTK's negative spelling, otherwise a bounded index.
          # Live writes use core viewer state, including pages appended in this callback.
          # @param index [Integer] page index; negative values select the last page
          # @return [Notebook] self, including unchanged or ignored selections
          def set_current_page(index)
            session.style_operation(self, :set_current_page) do
              session.refuse(self, :set_current_page) if destroyed? || !index.is_a?(Integer)
              index = n_pages - 1 if index.negative?
              return self unless index.between?(0, n_pages - 1)

              return self if @tabs[index][:page].hidden?
              previous = selected_tab_key
              write(:selected, index)
              notify_switch(previous)
            end
            self
          end

          # Accepts a Label, or one EventBox containing a Label. Headers remain
          # owned widgets but never appear as extra Notebook#children pages.
          # @param child [Widget] same-session child governed by this container
          # @param label [Label, EventBox] same-session paired tab header
          # @return [Integer] new zero-based page index
          def append_page(child, label)
            session.style_operation(self, :append_page) do
              valid = !destroyed? && child.is_a?(Widget) && child.session.equal?(session) && !child.destroyed? && child.parent.nil?
              ancestor = self
              while ancestor
                valid &&= !ancestor.equal?(child)
                ancestor = ancestor.parent
              end
              text = label.is_a?(EventBox) ? label.children.first : label
              valid &&= label.is_a?(Widget) && label.session.equal?(session) && !label.destroyed? && label.parent.nil? &&
                        text.instance_of?(Label) && !text.destroyed? && text.session.equal?(session) && !label.equal?(child) &&
                        !label.tab_owner && !text.tab_owner
              session.refuse(self, :append_page) unless valid
              previous = selected_tab_key
              entry = { key: "tab-#{SecureRandom.hex(12)}", widget: label, label: text, page: child }
              publish_tabs(@tabs + [entry])
              label.send(:parent=, self)
              [label, text].uniq.each { |widget| widget.tab_owner = self }
              child.send(:parent=, self)
              @children << child
              @tabs << entry
              notify_switch(previous)
              n_pages - 1
            end
          end

          # Detaches a page and its header without destroying reusable widgets.
          # @param index [Integer] GTK child or page position; negative values use the operation default
          # @return [Notebook] self, including ignored out-of-range indices
          def remove_page(index)
            session.style_operation(self, :remove_page) do
              session.refuse(self, :remove_page) if destroyed? || !index.is_a?(Integer)
              index = n_pages - 1 if index.negative?
              return self unless index.between?(0, n_pages - 1)

              previous = selected_tab_key
              entry = @tabs.fetch(index)
              remaining = @tabs.reject { |item| item.equal?(entry) }
              publish_tabs(remaining)
              @tabs = remaining
              @children.delete(entry[:page])
              entry[:page].send(:parent=, nil)
              release_header(entry)
              notify_switch(previous)
            end
            self
          end

          # Detaches an auxiliary action or indexed page through its ownership path.
          # @param child [Widget] same-session child governed by this container
          # @return [Notebook] self
          def remove(child)
            side = @actions.key(child)
            return set_action_widget(nil, side) if side
            index = @children.index(child)
            session.refuse(self, :remove) unless index
            remove_page(index)
          end

          # Window teardown includes header widgets even though children lists pages only.
          # @return [void] result is not part of the supported script contract
          def mark_destroyed
            return if destroyed?

            entries = @tabs.dup
            super
            entries.each do |entry|
              release_header(entry)
              entry[:widget].mark_destroyed
            end
            @actions.clear
          end

          protected

          # Includes auxiliary actions in traversal without adding them to indexed pages.
          # @return [Array<Widget>] descendants included in traversal
          # @api private
          def owned_children = @children + @actions.values

          # Tags an auxiliary action with its tab-strip side.
          # @param child [Widget] same-session child governed by this container
          # @return [Hash, nil] auxiliary placement, or nil for ordinary children
          # @api private
          def child_placement(child)
            side = @actions.key(child)
            { tab_action: side.to_s } if side
          end

          # Selects the shared component type for this compatibility object.
          # @return [Symbol] shared component type
          # @api private
          def component_type = :tabs
          # Identifies the viewer input retained by this widget.
          # @return [Symbol, nil] input property, or nil for non-input widgets
          # @api private
          def input_property = :selected
          # Maps supported GTK signal spellings to shared component events.
          # @return [Hash{String => Symbol}] accepted GTK signals and shared events
          # @api private
          def signal_map = { 'switch_page' => :select }
          # Lists component events needed independently of script connections.
          # @return [Array<Symbol>] required shared event names
          # @api private
          def builtin_events = %i[select tab_pointer]

          # Core validates stable header identity before dispatch; recheck under
          # the owner monitor because a queued callback may outlive its tab.
          # @param event [Symbol] shared component event family
          # @return [String] shared event binding identity
          # @api private
          def bind_event(event)
            if event == :select
              return session.port.bind(@handle, :select, proc do |context|
                session.callback(context, widget: self) do
                  index = @tabs.index { |entry| entry[:key] == context.payload[:tab] }
                  next unless index && !@tabs[index][:page].destroyed? && !@tabs[index][:page].hidden?

                  emit_switch(index)
                end
              end)
            end
            return super unless event == :tab_pointer

            session.port.bind(@handle, event, proc do |context|
              session.callback(context, widget: self) do
                entry = @tabs.find { |item| item[:key] == context.payload[:tab] }
                next unless entry && !entry[:widget].destroyed? && entry[:widget].is_sensitive? && is_sensitive?

                widget = entry[:widget]
                pointer = PointerEvent.new(**context.payload.except(:tab))
                session.with_pointer(widget, pointer) do
                  widget.send(:dispatch_pointer_handlers, :pointer_press, pointer)
                end
              end
            end)
          end

          # Routes retired pages, headers and actions through their collection cleanup.
          # @param child [Widget] same-session child governed by this container
          # @return [void] result is not part of the supported script contract
          # @api private
          def forget_child(child)
            side = @actions.key(child)
            return set_action_widget(nil, side) if side
            entry = @tabs.find { |item| item[:page].equal?(child) || item[:widget].equal?(child) }
            entry ? remove_page(@tabs.index(entry)) : super
          end

          private

          # Resolves the retained selection to a stable tab identity.
          # @return [String, nil] selected stable tab identity
          # @api private
          def selected_tab_key
            @tabs[read(:selected) || 0]&.fetch(:key)
          end

          # Emits a switch notification only when the selected identity changes.
          # @param previous [String, nil] previous stable selected tab identity
          # @return [void] result is not part of the supported script contract
          # @api private
          def notify_switch(previous)
            current = selected_tab_key
            emit_switch(@tabs.index { |entry| entry[:key] == current }) if current && current != previous
          end

          # Invokes switch-page handlers while both Notebook and page remain live.
          # @param index [Integer] GTK child or page position; negative values use the operation default
          # @return [void] result is not part of the supported script contract
          # @api private
          def emit_switch(index)
            page = @tabs[index][:page]
            ordered_handlers(:select).each do |name, handler|
              break if destroyed? || page.destroyed? || !@children.include?(page)
              handler.call(self, page, index) if name == 'switch_page'
            end
          end

          # Refreshes only headers; label writes never materialize a second surface.
          # @return [void] result is not part of the supported script contract
          # @api private
          def refresh_headers
            return if destroyed?

            previous = selected_tab_key
            publish_tabs(@tabs)
            notify_switch(previous)
          end

          # Detaches the page associated with a retired header or header label.
          # @param widget [Widget] same-session widget whose ownership is changing
          # @return [void] result is not part of the supported script contract
          # @api private
          def retire_header(widget)
            entry = @tabs.find { |item| item[:widget].equal?(widget) || item[:label].equal?(widget) }
            remove_page(@tabs.index(entry)) if entry
          end

          # Validates replacement header text before shadow or port state changes.
          # @param widget [Widget] same-session widget whose ownership is changing
          # @param property [Symbol] header property about to change
          # @param value [String] bounded literal text for this presentation property
          # @return [void] result is not part of the supported script contract
          # @api private
          def header_will_change(widget, property, value)
            return unless property == :content

            names = @tabs.map { |entry| entry[:label].equal?(widget) ? value : entry[:label].text }
            valid = value.is_a?(String) && value.valid_encoding? && value.length <= Lich::WebUI::Contract::BOUNDS[:short_text] && names.uniq.length == names.length
            session.refuse(self, :tab_label) unless valid
          end

          # Builds bounded, uniquely named header presentations from tab entries.
          # @param entries [Array<Hash>] candidate tab records with stable identity and owned widgets
          # @return [Array(Array<String>, Array<Hash>)] paired names and typed header records
          # @api private
          def header_snapshot(entries)
            names = entries.map { |entry| entry[:label].text }
            session.refuse(self, :tab_label) unless names.uniq.length == names.length
            headers = entries.map do |entry|
              props = entry[:label].send(:header_presentation)
              { key: entry[:key], pointer_events: entry[:widget].pointer_events?,
                foreground: props[:foreground], hidden: entry[:page].hidden?, disabled: !entry[:widget].is_sensitive? }.compact
            end
            [names, headers]
          end

          # Publishes a candidate tab collection and remaps selection by identity.
          # @param entries [Array<Hash>] candidate tab records with stable identity and owned widgets
          # @return [void] updates the accepted tab collection presentation
          # @api private
          def publish_tabs(entries)
            names, headers = header_snapshot(entries)
            # Authored defaults and terminal viewer snapshots may select different
            # pages. Remap each by identity without creating a new committed value.
            remap = lambda do |index|
              index ||= 0
              Lich::WebUI::Contract.remap_tab_index(@props[:headers], headers, index, names.length)
            end
            selected = remap.call(@props[:selected])
            committed = remap.call(@committed[:selected]) if @committed.key?(:selected)
            candidate = @props.merge(names: names, headers: headers, selected: selected)
            Lich::WebUI::Validator.new.validate_component!(:tabs, candidate, owner: self.class.name, page_id: 'notebook', cid: 'tabs')
            if @handle
              session.port.layout_tabs(@handle, children: entries.map { |entry| entry[:page].materialize }, names: names, headers: headers)
            end
            @props.merge!(names: names, headers: headers, selected: selected)
            @committed[:selected] = committed if @committed.key?(:selected)
          end

          # Releases header notification ownership and detaches its widget.
          # @param entry [Hash] one paired page/header ownership record
          # @return [void] result is not part of the supported script contract
          # @api private
          def release_header(entry)
            [entry[:widget], entry[:label]].uniq.each { |widget| widget.tab_owner = nil }
            entry[:widget].send(:parent=, nil)
          end
        end
      end
    end
  end
end
