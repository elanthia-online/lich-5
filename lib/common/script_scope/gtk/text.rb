# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        module WrapMode
          WORD = :word
          WORD_CHAR = :word_char
          NONE = :none
        end

        # Plain text owned by one Script and at most one view. Draft text stays
        # in the core viewer store; buffer reads use the active callback's viewer.
        class TextBuffer
          # Only insertion advances its supplied iterator, as in GTK. Callers cannot
          # assign offsets without going through buffer validation.
          class Iter
            attr_reader :buffer, :offset

            def initialize(buffer, offset)
              @buffer, @offset = buffer, offset
            end

            private

            attr_writer :offset
          end

          # A bounded anonymous right-gravity anchor, always at this buffer's end.
          class EndMark
            attr_reader :buffer

            def initialize(buffer)
              @buffer = buffer
              @deleted = false
            end

            def deleted? = @deleted

            private

            def delete! = @deleted = true
          end
          MAX_LINES = 1000
          attr_reader :session

          # Creates an independent buffer. Rich tag tables are outside this adapter.
          # @param table [nil] no rich-text table is supported
          def initialize(table = nil)
            @session = Gtk.session
            session.refuse(self, :new) unless table.nil?
            @text = ''
            @handlers = []
          end

          # Returns a copy of the current viewer or retained text.
          # @return [String]
          def text = (@view ? @view.send(:buffer_text) : @text).dup

          # @return [Iter] start of this buffer, independent of browser selection
          def start_iter = Iter.new(self, 0)

          # @return [Iter] exclusive end at the current character count
          def end_iter = Iter.new(self, text.length)

          # @return [Integer] Unicode character count, not UTF-8 byte count
          def char_count = text.length

          # @return [Integer] logical lines, including a final empty line
          def line_count = text.count("\n") + 1

          # Supplies only the historical localchat tag entry point, not rich text.
          # @return [TextBuffer] self
          def tag_table = self

          # Replaces text without confusing an append with a replacement.
          # Validation precedes both the renderer write and retained-state update.
          # @param value [String] literal text; log mode keeps the latest 1,000 lines
          # @return [TextBuffer] self
          # @raise [UnsupportedOperation] for nontext or oversized content
          def set_text(value)
            session.synchronize do
              session.refuse(self, :text=) unless value.is_a?(String)
              commit_text(bounded_text(value))
            end
            self
          end
          alias text= set_text

          # Creates a buffer-local character offset, never a byte/browser offset.
          # @param offset [Integer] zero through the current character count
          # @return [Iter]
          def get_iter_at_offset(offset)
            session.refuse(self, :get_iter_at_offset) unless offset.is_a?(Integer) && offset.between?(0, text.length)
            Iter.new(self, offset)
          end

          # Returns the start of an existing zero-based line.
          # @param line [Integer] zero through line_count minus one
          # @return [Iter]
          def get_iter_at_line(line)
            session.refuse(self, :get_iter_at_line) unless line.is_a?(Integer) && line.between?(0, line_count - 1)
            get_iter_at_offset(text.lines.first(line).sum(&:length))
          end

          # Inserts literal text at a valid buffer-local offset.
          # @param iterator [Iter] position from this buffer, still within its bounds
          # @param value [String] text inserted before the position
          # @return [TextBuffer] self
          def insert(iterator, value)
            session.synchronize do
              valid_iter!(iterator, :insert)
              session.refuse(self, :insert) unless value.is_a?(String)
              inserted = text.insert(iterator.offset, value)
              target = bounded_text(inserted)
              offset = [iterator.offset + value.length - (inserted.length - target.length), 0].max
              commit_text(target, iterator, offset)
            end
          end

          # Supports the measured anonymous right-gravity end anchor only.
          # Named marks, other gravity and arbitrary positions remain explicit refusals.
          def create_mark(name, iterator, left_gravity)
            session.style_operation(self, :create_mark) do
              valid_iter!(iterator, :create_mark)
              session.refuse(self, :create_mark) unless name.nil? && left_gravity == false && iterator.offset == char_count
              EndMark.new(self)
            end
          end

          # Retires a same-buffer live mark; it cannot be scrolled or deleted again.
          def delete_mark(mark)
            session.style_operation(self, :delete_mark) do
              validate_mark!(mark, :delete_mark)
              mark.send(:delete!)
            end
            self
          end

          # @api private
          def validate_mark!(mark, operation)
            valid = mark.is_a?(EndMark) && mark.buffer.equal?(self) && !mark.deleted?
            session.refuse(self, operation) unless valid
          end

          # Deletes a validated half-open range.
          # @param first [Iter] inclusive start in this buffer
          # @param last [Iter] exclusive end at or after first
          # @return [TextBuffer] self
          def delete(first, last)
            session.synchronize do
              valid_range!(first, last, :delete)
              value = text
              value.slice!(first.offset...last.offset)
              set_text(value)
            end
          end

          # Reads a validated plain-text range. No hidden rich-text ranges exist.
          # @param first [Iter] inclusive start in this buffer
          # @param last [Iter] exclusive end at or after first
          # @param include_hidden [Boolean] accepted legacy flag; plain text has no hidden spans
          # @return [String]
          def get_text(first = start_iter, last = end_iter, include_hidden = false)
            session.refuse(self, :get_text) unless [true, false].include?(include_hidden)
            valid_range!(first, last, :get_text)
            text[first.offset...last.offset]
          end

          # Connects ordered notifications for programmatic or viewer changes.
          # @param name [String, Symbol] only changed is supported
          # @yield [TextBuffer] buffer read within the originating viewer's callback
          # @return [Integer] connection count
          def signal_connect(name, &block)
            session.refuse(self, "signal:#{name}") unless name.to_s == 'changed' && block
            @handlers << block
            @handlers.length
          end

          # Retains the previously accepted localchat color degradation only.
          # @return [TextBuffer] self
          def add(tag)
            session.refuse(self, :tag) unless tag.is_a?(TextTag)
            session.degrade(:text_colour, 'chat text colours follow the browser theme')
            self
          end

          # Checks localchat's color range without widening rich-text support.
          # @return [TextBuffer] self
          def apply_tag(tag, first, last)
            session.refuse(self, :apply_tag) unless tag.is_a?(TextTag)
            valid_range!(first, last, :apply_tag)
            self
          end

          # Binds one same-session view; ambiguous shared editable buffers refuse.
          # @api private
          # @param view [TextView] sole view allowed to consume this buffer
          # @raise [UnsupportedOperation] for a foreign session or a second view
          def bind(view)
            session.refuse(self, :bind) unless view.session.equal?(session) && (!@view || @view.equal?(view))
            previous = @view
            begin
              @view = view
              view.send(:apply_buffer_text, bounded_text(@text))
            rescue StandardError
              @view = previous
              raise
            end
          end

          # Releases a replaced buffer while preserving its latest retained value.
          # @api private
          # @param view [TextView] current owner view; other callers have no effect
          # @param retained [String] text captured before replacing the view's buffer
          def unbind(view, retained: text)
            return unless @view.equal?(view)
            @text = retained
            @view = nil
          end

          # Delivers a validated viewer change without storing another draft copy.
          # Reentrant matching writes reuse the notification already in progress.
          # @api private
          def notify_changed
            session.synchronize do
              previous = @notifying_text
              @notifying_text = text
              @handlers.dup.each { |handler| handler.call(self) }
            ensure
              @notifying_text = previous
            end
          end

          # Refuses other mark operations, rich ranges and cursor editing explicitly.
          def method_missing(name, *, **, &)
            session.refuse(self, name)
          end

          # Unsupported operations are deliberately absent from introspection.
          def respond_to_missing?(*args) = super

          private

          # Commit iterator movement before changed callbacks can inspect/reuse it.
          # A refused renderer write leaves both text and the iterator untouched.
          def commit_text(target, iterator = nil, offset = nil)
            changed = text != target || (@text != target && @notifying_text != target)
            @view&.send(:apply_buffer_text, target)
            @text = target.dup
            iterator&.send(:offset=, offset)
            notify_changed if changed
            self
          end

          # Applies the selected presentation's limits before any mutation.
          # Logs explicitly degrade history length; editors reject excess text.
          # @return [String] original text or the retained log tail
          # @raise [UnsupportedOperation] for oversized lines or editor content
          def bounded_text(value)
            if @view&.send(:log?)
              lines = value.split("\n", -1)
              session.refuse(self, :text) if lines.any? { |line| line.length > Lich::WebUI::Contract::BOUNDS[:log_line] }
              if lines.length > MAX_LINES
                session.degrade(:text_history, 'compatibility text history retains the latest 1000 lines')
                lines = lines.last(MAX_LINES)
              end
              lines.join("\n")
            else
              session.refuse(self, :text) if value.length > Lich::WebUI::Contract::BOUNDS[:multiline_text]
              value
            end
          end

          # Rejects foreign/stale offsets with the source operation's attribution.
          # @return [nil]
          def valid_iter!(iterator, operation)
            valid = iterator.is_a?(Iter) && iterator.buffer.equal?(self) && iterator.offset.between?(0, text.length)
            session.refuse(self, operation) unless valid
          end

          # Requires two current offsets in this buffer, ordered as a half-open range.
          # @return [nil]
          def valid_range!(first, last, operation)
            [first, last].each { |iterator| valid_iter!(iterator, operation) }
            session.refuse(self, operation) unless first.offset <= last.offset
          end
        end

        class TextTag
          # Accepts the existing bounded localchat color token; never raw CSS.
          def foreground=(colour)
            Gtk.session.refuse(self, :foreground=) unless colour.is_a?(String) && colour.match?(/\A(?:#[0-9a-fA-F]{6}|[a-zA-Z]+)\z/)
          end
        end

        # Editable plain text uses textarea; explicitly read-only views created
        # before publication retain the bounded log contract and history capacity.
        class TextView < Widget
          attr_reader :buffer

          # Creates a view for an independent buffer, or a fresh buffer by default.
          # @param buffer [TextBuffer, nil]
          def initialize(buffer = nil)
            super()
            @editable = true
            @log = false
            @props.merge!(value: '', read_only: false, wrap: :word, follow: false)
            set_buffer(buffer || TextBuffer.new)
          end

          # Rebinds a same-owner buffer without retaining its former view listener.
          # Assigning the current buffer is a no-op that preserves live viewer drafts.
          # @param buffer [TextBuffer] independent buffer from this Script session
          # @return [TextView] self
          def set_buffer(buffer)
            return self if @buffer.equal?(buffer)

            session.synchronize do
              session.refuse(self, :buffer=) unless buffer.is_a?(TextBuffer) && buffer.session.equal?(session)
              retained = @buffer&.text
              buffer.bind(self)
              @buffer&.unbind(self, retained: retained) unless @buffer.equal?(buffer)
              @buffer = buffer
            end
            self
          end
          alias buffer= set_buffer

          # Selects log presentation before publication, or textarea read-only mode.
          # A published log cannot become an editor without replacing the view.
          # @param value [Boolean] whether user edits are allowed
          # @return [TextView] self
          def set_editable(value)
            session.refuse(self, :editable=) unless [true, false].include?(value)
            session.refuse(self, :editable=) if @handle && @log && value
            unless @handle
              retained = @buffer.text
              @log = !value
              apply_buffer_text(retained)
            end
            @editable = value
            write(:read_only, !value) unless @log
            self
          end
          alias editable= set_editable
          # @return [Boolean] whether this view accepts user edits
          def editable? = @editable

          # Cursor visibility applies only to editable text; log views have no cursor.
          # @param value [Boolean] whether the browser caret is visible
          # @return [TextView] self
          def set_cursor_visible(value)
            session.refuse(self, :cursor_visible=) unless [true, false].include?(value)
            session.refuse(self, :cursor_visible=) if @log && value
            write(:cursor_visible, value) unless @log
            self
          end
          alias cursor_visible= set_cursor_visible

          # Word/character fallback wraps long tokens without splitting ordinary words.
          # @param value [Symbol] :word, :word_char or :none
          # @return [TextView] self
          def set_wrap_mode(value)
            session.refuse(self, :wrap_mode=) unless %i[word word_char none].include?(value)
            write(:wrap, value)
          end
          alias wrap_mode= set_wrap_mode

          # Text insets belong inside the view, independently of outer widget margins.
          # Read-only documents retain their scroll position until explicitly asked to follow.
          %i[left right].each do |side|
            define_method("set_#{side}_margin") do |value|
              session.style_operation(self, :text_margin) do
                valid = !destroyed? && value.is_a?(Integer) && value.between?(0, 64)
                session.refuse(self, :text_margin) unless valid
                write(:"padding_#{side}", value)
              end
              self
            end
            alias_method :"#{side}_margin=", :"set_#{side}_margin"
            define_method(:"#{side}_margin") { read(:"padding_#{side}") || 0 }
            alias_method :"get_#{side}_margin", :"#{side}_margin"
          end

          # False uses the browser's normal Tab/Shift-Tab focus navigation.
          # Inserting literal tabs would require a distinct editor interaction.
          # @param value [Boolean] only false is supported
          def accepts_tab=(value)
            session.refuse(self, :accepts_tab=) unless value == false
          end
          alias set_accepts_tab accepts_tab=

          # Preserves the existing explicit chat-font degradation.
          def override_font(font)
            session.refuse(self, :override_font) unless font.is_a?(Pango::FontDescription)
            session.degrade(:font_face, 'chat font face and size follow browser theme')
          end

          # Enables follow-to-end for the accepted legacy scrolling form.
          # @param iterator [TextBuffer::Iter] current buffer end
          # @param margin [Numeric] must be zero
          # @param align [Boolean] must be true
          # @param x [Numeric] must be zero
          # @param y [Numeric] must be zero
          # @return [TextView] self
          # @raise [UnsupportedOperation] for arbitrary scroll ranges or alignment
          def scroll_to_iter(iterator, margin, align, x, y)
            valid = iterator.is_a?(TextBuffer::Iter) && iterator.buffer.equal?(@buffer) && iterator.offset == @buffer.end_iter.offset
            session.refuse(self, :scroll_to_iter) unless valid && margin == 0.0 && align == true && x == 0 && y == 0
            write(:follow, true)
          end

          # Copies the accepted end-follow intent before callers delete the mark.
          # The renderer never receives or later dereferences a Ruby mark object.
          def scroll_mark_onscreen(mark)
            session.style_operation(self, :scroll_mark_onscreen) do
              session.refuse(self, :scroll_mark_onscreen) if destroyed?
              @buffer.validate_mark!(mark, :scroll_mark_onscreen)
              write(:follow, true)
            end
          end

          protected

          # @return [Boolean] whether prepublication configuration selected a log
          def log? = @log
          # @return [Symbol] immutable core type once the view is materialized
          def component_type = @log ? :log : :textarea
          # @return [Symbol, nil] viewer-local text field; logs have no input state
          def input_property = @log ? nil : :value
          # @return [Hash] editable views alone accept browser change notifications
          def signal_map = @log ? {} : { 'changed' => :change, 'focus-out-event' => :blur }
          # Reads shared log lines or the core's callback-scoped editor draft.
          # @return [String]
          def buffer_text = @log ? @props.fetch(:lines, []).join("\n") : read(:value)

          # Removes properties belonging to the other presentation before validation.
          # @return [Hash] properties for the selected core component
          def component_props
            @log ? super.except(:value, :read_only, :cursor_visible).merge(max_lines: TextBuffer::MAX_LINES) : super.except(:lines)
          end

          # Writes through the existing widget/adapter path without a second draft store.
          # @param text [String] validated plain text for the active presentation
          # @return [TextView] self
          def apply_buffer_text(text)
            if @log
              lines = text.split("\n", -1)
              session.refuse(self, :text) if lines.length > TextBuffer::MAX_LINES || lines.any? { |line| line.length > Lich::WebUI::Contract::BOUNDS[:log_line] }
              write(:lines, lines)
            else
              write(:value, text)
            end
          end

          # Runs buffer listeners before view listeners in the same viewer callback.
          # @param event [Symbol] core event; nonchanges retain Widget behavior
          def bind_event(event)
            return super unless event == :change
            session.port.bind(@handle, event, proc do |context|
              session.callback(context, widget: self) do
                @buffer.notify_changed
                emit_handlers(:change)
              end
            end)
          end
        end

        # Plain expandable content delegates open state to the existing viewer store.
        class Expander < Widget
          include Container

          # Creates a collapsed single-child disclosure with a literal label.
          # @param label [#to_s] visible heading; markup is not interpreted
          def initialize(label = '')
            super()
            @props.merge!(label: String(label), open: false)
            @caption_label = Label.new(String(label))
            @caption_label.send(:caption_owner=, self)
          end

          # @return [String] literal heading
          def label = read(:label)

          # @return [Expander] self after replacing the literal heading
          def set_label(value)
            text = String(value)
            write(:label, text)
            @caption_label.text = text unless @caption_label.text == text
            self
          end

          # @return [Label] owned caption facade for live literal/markup edits
          def label_widget = @caption_label

          # Retires the caption together with the disclosure subtree.
          # @return [void]
          def mark_destroyed
            super
            @caption_label.mark_destroyed
          end

          # Releases the owned caption and any registered style context.
          # @return [Expander] self
          def destroy
            super
            @caption_label.destroy
            self
          end
          alias label= set_label
          # @return [Boolean] open state for the originating viewer or retained default
          def expanded? = read(:open)
          alias expanded expanded?

          # Explicit writes notify only when the effective expanded state changes.
          # @param value [Object] Ruby truthiness determines the expanded state
          # @return [Expander] self
          def set_expanded(value)
            changed = expanded? != !!value
            write(:open, !!value)
            emit_handlers(:toggle) if changed
            self
          end
          alias expanded= set_expanded

          # GtkExpander is a single-child container, unlike the core expander.
          # @param child [Widget] sole child, or the existing child added again
          # @raise [UnsupportedOperation] if another child already exists
          def add(child)
            session.refuse(self, :add) unless children.empty? || children.include?(child)
            super
          end

          protected

          # Copies literal text and warns once only when markup styling is omitted.
          # @param label [Label] owned caption whose content or fragments changed
          # @return [Object] write result, or nil for a retired/unchanged caption
          def refresh_caption(label)
            refresh_owned_caption(label, @caption_label,
                                  operation: :expander_caption_style,
                                  message: 'expander caption retains literal text; typography follows browser theme')
          end

          # @return [Symbol] existing disclosure component, with no shim renderer
          def component_type = :expander
          # @return [Symbol] viewer-scoped expansion field
          def input_property = :open
          # @return [Hash] GTK notification mapped to the core disclosure event
          def signal_map = { 'notify::expanded' => :toggle }
        end
      end
    end
  end
end
