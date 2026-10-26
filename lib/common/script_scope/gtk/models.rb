# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        # Nonvisual compatibility objects share the script monitor and refusal boundary.
        class ModelObject
          attr_reader :session

          # Captures an existing owner session without introducing another dispatcher.
          # @param session [Session] script session, defaulting to the current script
          def initialize(session: Gtk.session)
            @session = session
          end

          # Refuses unimplemented model/renderer methods with script attribution.
          # @raise [UnsupportedOperation] always
          def method_missing(name, *, **, &)
            session.refuse(self, name)
          end

          def respond_to_missing?(*args) = super
        end

        # A positional snapshot, not a row identity. Paths may change after mutation/sort.
        class TreePath < ModelObject
          attr_reader :indices

          # Validates and freezes a positional snapshot with no mutable model reference.
          # @param value [String, Integer, Array<Integer>, TreePath] nonnegative indices
          # @raise [UnsupportedOperation] for malformed or excessively deep paths
          def initialize(value = [])
            super()
            parts = case value
                    when TreePath then value.indices
                    when Integer then [value]
                    when Array then value
                    when String
                      session.refuse(self, :new) unless value.match?(/\A\d+(?::\d+)*\z/)
                      value.split(':').map(&:to_i)
                    else session.refuse(self, :new)
                    end
            valid = parts.length <= Lich::WebUI::Contract::BOUNDS[:tree_depth] && parts.all? { |index| index.is_a?(Integer) && index >= 0 }
            session.refuse(self, :new) unless valid
            @indices = parts.dup.freeze
          end

          def to_s = indices.join(':')
          alias to_str to_s
          def ==(other) = other.is_a?(TreePath) && indices == other.indices
          def depth = indices.length
        end

        # A movable handle to a model-owned row. Advancing never rewrites stored rows.
        class TreeIter < ModelObject
          attr_reader :model, :key

          # Wraps one identity without handing out the stored row object.
          # @param model [ListStore] owning model
          # @param key [String, nil] immutable row identity; nil denotes an invalid handle
          # @api private
          def initialize(model, key)
            super(session: model.session)
            @model, @key = model, key
          end

          def [](column) = model.get_value(self, column)

          def []=(column, value)
            model.set_value(self, column, value)
          end
          alias get_value []
          alias set_value []=
          def path = model.get_path(self)

          # Advances within the current sibling list, invalidating this handle at its end.
          # @return [Boolean] whether a next row exists
          def next!
            model.session.synchronize { @key = model.iter_after(self)&.key }
            !@key.nil?
          end

          def ==(other) = other.is_a?(TreeIter) && model.equal?(other.model) && key == other.key

          # Repositions only this handle after removal; other handles to the deleted row stay invalid.
          # @param key [String, nil] next sibling identity
          # @return [void]
          # @api private
          def reposition(key)
            @key = key
          end
        end

        # A rejected cell reports bounded schema metadata without its contents.
        class ModelValueError < UnsupportedOperation
          # Reports only schema metadata, never the rejected cell contents.
          attr_reader :diagnostic

          def initialize(message, column:, expected:, actual:, length:, limit:)
            @diagnostic = "column=#{column} expected=#{expected} actual=#{actual} length=#{length || 'n/a'} limit=#{limit}"
            super("#{message} #{@diagnostic}")
          end
        end

        # Script-owned scalar rows, reusable by multiple same-owner views. Viewer selection
        # never lives in the model. Observers are detached when views change models or die.
        class ListStore < ModelObject
          Row = Struct.new(:key, :parent, :cells)
          TYPES = [String, Integer, Float, TrueClass, FalseClass].freeze
          # Model-only metadata need not fit a short display label. Projections
          # enforce their own contracts; storage remains bounded and lossless.
          MAX_STRING_LENGTH = 65_536
          attr_reader :column_types

          # Creates an empty store with a fixed bounded scalar schema.
          # @param types [Array<Class>] String, Integer, Float or boolean column classes
          # @raise [UnsupportedOperation] for unsupported/empty/oversized schemas
          def initialize(*types)
            super()
            valid = types.length.between?(1, Lich::WebUI::Contract::BOUNDS[:table_columns]) && (types - TYPES).empty?
            session.refuse(self, :new) unless valid
            @column_types = types.map { |type| type == FalseClass ? TrueClass : type }.freeze
            @rows, @observers = [], []
            @prefix, @serial = SecureRandom.hex(8), 0
            @sort = nil
            @revision = 0
            rebuild_indexes
          end

          def n_columns = column_types.length
          def size = session.synchronize { @rows.length }
          alias length size
          def empty? = size.zero?

          # Checks the schema index before exposing its declared scalar type.
          # @param column [Integer] schema column
          # @return [Class] declared scalar type
          def get_column_type(column)
            check_column(column)
            column_types[column]
          end

          # Appends a zero-valued row. ListStore never accepts a parent argument.
          # @return [TreeIter] independent handle to the inserted row
          def append = insert(-1)
          def prepend = insert(0)

          # Inserts a root without changing the identities of existing rows.
          # @param position [Integer] sibling position; -1 appends
          # @return [TreeIter] independent handle
          def insert(position)
            insert_row(nil, position)
          end

          # Removes the entire subtree and advances the supplied handle to its next sibling.
          # @param iter [TreeIter] live same-model handle
          # @return [Boolean] whether the supplied handle now names a next sibling
          def remove(iter)
            original_key = iter.key if iter.is_a?(TreeIter)
            following = mutate do
              row = row_for(iter)
              following = iter_after(iter)&.key
              removed = ordered_rows(row.key).to_h { |child| [child.key, true] }
              removed[row.key] = true
              @rows.reject! { |candidate| removed.key?(candidate.key) }
              following
            end
            @batch_iterators[iter] ||= original_key if @batch_iterators
            iter.reposition(following)
            !following.nil?
          end

          # Invalidates all existing row handles without recycling their identities.
          # @return [ListStore] self
          def clear
            mutate { @rows.clear }
            self
          end

          # Iterates a snapshot in model order, skipping rows removed by an earlier callback.
          # @yieldparam model [ListStore] this model
          # @yieldparam path [TreePath] current positional path
          # @yieldparam iter [TreeIter] independent row handle
          # @return [Enumerator, ListStore]
          def each
            return enum_for(:each) unless block_given?

            session.synchronize do
              ordered_rows.each do |row|
                next unless @rows_by_key.key?(row.key)
                iter = TreeIter.new(self, row.key)
                yield self, get_path(iter), iter
              end
            end
            self
          end

          def iter_first = iter_children

          # Resolves a positional path against the current model order.
          # @param path [TreePath, String, Array<Integer>, Integer] positional row path
          # @return [TreeIter, nil] nil for a well-formed path without a row
          def get_iter(path)
            session.synchronize do
              indices = TreePath.new(path).indices
              return nil if indices.empty?
              parent = nil
              indices.each do |index|
                row = siblings(parent)[index]
                return nil unless row
                parent = row.key
              end
              TreeIter.new(self, parent)
            end
          end
          alias get_iter_from_string get_iter

          # Computes a fresh path so insertion and sorting cannot leave cached positions stale.
          # @param iter [TreeIter] live same-model handle
          # @return [TreePath] current path after insertion, removal or sorting
          def get_path(iter)
            session.synchronize do
              row = row_for(iter)
              indices = []
              loop do
                indices.unshift(sibling_position(row))
                break unless row.parent
                row = @rows_by_key.fetch(row.parent)
              end
              TreePath.new(indices)
            end
          end

          # Finds the next sibling without advancing the caller's handle.
          # @param iter [TreeIter] live same-model handle
          # @return [TreeIter, nil] an independent next-sibling handle
          # @api private
          def iter_after(iter)
            session.synchronize do
              row = row_for(iter)
              peers = siblings(row.parent)
              following = peers[sibling_position(row) + 1]
              following && TreeIter.new(self, following.key)
            end
          end

          # @param parent [TreeIter, nil] parent or nil for roots
          # @return [TreeIter, nil] first child
          def iter_children(parent = nil) = iter_nth_child(parent, 0)

          # Looks up an immediate child in the current sibling order.
          # @param parent [TreeIter, nil] parent or nil for roots
          # @param index [Integer] child index
          # @return [TreeIter, nil] independent child handle
          def iter_nth_child(parent, index)
            session.synchronize do
              session.refuse(self, :iter_nth_child) unless index.is_a?(Integer) && index >= 0
              row = siblings(parent && row_for(parent).key)[index]
              row && TreeIter.new(self, row.key)
            end
          end

          # Counts immediate children, excluding deeper descendants.
          # @param parent [TreeIter, nil] parent or nil for roots
          # @return [Integer] immediate child count
          def iter_n_children(parent = nil)
            session.synchronize { siblings(parent && row_for(parent).key).length }
          end

          def iter_has_child?(iter) = iter_n_children(iter).positive?

          # Returns an independent handle to the immediate parent.
          # @param iter [TreeIter] live child
          # @return [TreeIter, nil] parent, or nil for roots
          def iter_parent(iter)
            session.synchronize do
              key = row_for(iter).parent
              key && TreeIter.new(self, key)
            end
          end

          # Checks model ownership and liveness without raising for an invalid handle.
          # @param iter [TreeIter] candidate handle
          # @return [Boolean] whether it still names a row in this model
          def iter_is_valid?(iter)
            session.synchronize { iter.is_a?(TreeIter) && iter.model.equal?(self) && @rows_by_key.key?(iter.key) }
          end

          # Reads a scalar without exposing a mutable model-owned String.
          # @param iter [TreeIter] live row
          # @param column [Integer] schema column
          # @return [String, nil, Integer, Float, Boolean] copied scalar value
          def get_value(iter, column)
            session.synchronize do
              check_column(column)
              value = row_for(iter).cells[column]
              value.is_a?(String) ? value.dup : value
            end
          end

          # Validates before changing the row; strings are copied to prevent hidden mutation.
          # @param iter [TreeIter] live row
          # @param column [Integer] schema column
          # @param value [String, nil, Integer, Float, Boolean] nil is allowed only in String columns
          # @return [ListStore] self
          def set_value(iter, column, value)
            mutate(structural: false) do
              check_column(column)
              row = row_for(iter)
              type = column_types[column]
              valid = type == TrueClass ? value == true || value == false : value.is_a?(type)
              valid ||= type == String && value.nil?
              valid &&= value.finite? if value.is_a?(Float)
              valid &&= value.length <= MAX_STRING_LENGTH if value.is_a?(String)
              unless valid
                actual = [String, Integer, Float, TrueClass, FalseClass, NilClass].find { |klass| value.is_a?(klass) }
                session.refuse(self, :set_value, error_class: ModelValueError, column: column,
                                               expected: type.name, actual: actual&.name || 'other',
                                               length: value.is_a?(String) ? value.length : nil, limit: MAX_STRING_LENGTH)
              end
              row.cells[column] = value.is_a?(String) ? value.dup.freeze : value
            end
            self
          end

          # Sorts every sibling list using its declared scalar type, retaining stable row IDs.
          # @param column [Integer] model column, or -2 to restore insertion order
          # @param direction [Symbol] :ascending or :descending
          # @return [ListStore] self
          def set_sort_column_id(column, direction = :ascending)
            mutate(structural: false) do
              check_column(column) unless column == -2
              session.refuse(self, :set_sort_column_id) unless %i[ascending descending].include?(direction)
              @sort = column == -2 ? nil : [column, direction]
            end
            self
          end

          # Registers a same-owner dependent view or renderer.
          # @param observer [ModelObject, Widget] object receiving model_changed!
          # @return [void]
          # @api private
          def watch(observer)
            session.refuse(self, :watch) unless observer.session.equal?(session)
            session.synchronize { @observers << observer unless @observers.include?(observer) }
          end

          def unwatch(observer) = session.synchronize { @observers.delete(observer) }

          # @return [Array<TreeIter>] preorder snapshot for rendering; values stay model-owned
          # @api private
          def rows = session.synchronize { ordered_rows.map { |row| TreeIter.new(self, row.key) } }

          # Changes on both candidate publication and rollback, invalidating observer snapshots.
          # @return [Integer] internal model snapshot revision
          # @api private
          attr_reader :revision

          # Resolves an event identity independently of its former positional path.
          # @param key [String] stable wire identity
          # @return [TreeIter, nil] nil if the row has since disappeared
          # @api private
          def find_key(key)
            session.synchronize { @rows_by_key.key?(key) ? TreeIter.new(self, key) : nil }
          end

          # A callback keeps one rollback snapshot, never one per scalar write.
          # @api private
          def begin_batch!
            @batch_snapshot = [@rows.map { |row| Row.new(row.key, row.parent, row.cells.dup) }, @sort]
            @batch_iterators = {}.compare_by_identity
          end

          # Validate every observer before any view sees the candidate data.
          # @api private
          def validate_batch! = @observers.dup.each(&:model_will_change!)
          # @api private
          def publish_batch! = @observers.dup.each(&:model_changed!)

          # @api private
          def finish_batch!
            @batch_snapshot = @batch_iterators = nil
          end

          # Restores identities and values after a failed/interrupted callback.
          # Serial IDs are never rewound, so rolled-back handles stay invalid.
          # @api private
          def rollback_batch!
            return unless @batch_snapshot
            @rows, @sort = @batch_snapshot
            @batch_iterators.each { |iter, key| iter.reposition(key) }
            finish_batch!
            rebuild_indexes
          end

          protected

          # Inserts in sibling order without exposing mutable row objects.
          # @param parent [TreeIter, nil] same-model parent
          # @param position [Integer] sibling position or -1
          # @return [TreeIter]
          # @api private
          def insert_row(parent, position)
            mutate do
              parent_key = parent && row_for(parent).key
              # Appending needs only a count, not a freshly sorted peer list.
              peers = position == -1 ? (@children[parent_key] || []) : siblings(parent_key)
              valid = position.is_a?(Integer) && position.between?(-1, peers.length)
              valid &&= @rows.length < Lich::WebUI::Contract::BOUNDS[:table_rows]
              valid &&= !parent || get_path(parent).depth < Lich::WebUI::Contract::BOUNDS[:tree_depth]
              session.refuse(self, :insert) unless valid
              @serial += 1
              # GTK leaves string cells unset (nil); a blank rendered label must
              # not erase the script-visible distinction from an explicit ''.
              defaults = column_types.map { |type| type == String ? nil : type == TrueClass ? false : type == Float ? 0.0 : 0 }
              row = Row.new("r#{@prefix}-#{@serial}".freeze, parent_key, defaults)
              before = peers[position] unless position == -1
              before ? @rows.insert(@insertion_rank.fetch(before.key), row) : @rows << row
              TreeIter.new(self, row.key)
            end
          end

          private

          # Refuses Ruby's negative-index behavior at the typed schema boundary.
          # @param column [Integer] requested column
          # @return [void]
          # @api private
          def check_column(column)
            session.refuse(self, :column) unless column.is_a?(Integer) && column.between?(0, n_columns - 1)
          end

          # Rejects foreign and retired identities instead of reusing their old position.
          # @param iter [TreeIter] candidate row handle
          # @return [Row] internal mutable row; never returned to scripts
          # @api private
          def row_for(iter)
            session.refuse(self, :iterator) unless iter.is_a?(TreeIter) && iter.model.equal?(self)
            @rows_by_key[iter.key] || session.refuse(self, :iterator)
          end

          # Rebuilds indexes once per candidate/rollback, never once per row lookup.
          # Ranks reflect explicit prepend/insert positions, not identity creation time.
          # Cached sibling snapshots and positions belong only to this revision.
          # @return [void]
          # @api private
          def rebuild_indexes
            @rows_by_key, @children, @insertion_rank = {}, {}, {}
            @rows.each_with_index do |row, index|
              @rows_by_key[row.key] = row
              (@children[row.parent] ||= []) << row
              @insertion_rank[row.key] = index
            end
            @ordered_siblings, @sibling_positions = {}, {}
            @revision += 1
          end

          # Sorts only peers, breaking equal-value ties by insertion order.
          # @param parent [String, nil] parent identity or roots
          # @return [Array<Row>] ordered peer snapshot
          # @api private
          def siblings(parent)
            @ordered_siblings[parent] ||= begin
              rows = @children.fetch(parent, [])
              if @sort
                column, direction = @sort
                rows = rows.sort do |left, right|
                  a, b = left.cells[column], right.cells[column]
                  # GTK compares null and empty strings equally. Normalize only
                  # for comparison, retaining nil in script-visible model data.
                  a, b = a.to_s, b.to_s if column_types[column] == String
                  a, b = a ? 1 : 0, b ? 1 : 0 if column_types[column] == TrueClass
                  comparison = a <=> b
                  comparison = -comparison if direction == :descending
                  comparison.zero? ? @insertion_rank.fetch(left.key) <=> @insertion_rank.fetch(right.key) : comparison
                end
              end
              rows.each_with_index { |row, index| @sibling_positions[row.key] = index }
              rows
            end
          end

          # Resolves paths without rescanning every sibling for each row.
          # @param row [Row] indexed row
          # @return [Integer] position among ordered peers
          # @api private
          def sibling_position(row)
            siblings(row.parent)
            @sibling_positions.fetch(row.key)
          end

          # Traverses the model independently of any viewer's expansion state.
          # @param parent [String, nil] parent identity or roots
          # @return [Array<Row>] preorder snapshot
          # @api private
          def ordered_rows(parent = nil, result = [])
            siblings(parent).each do |row|
              result << row
              ordered_rows(row.key, result)
            end
            result
          end

          # Validates every projection before publishing a changed model to any view.
          # Failed schema/choice bounds restore data, ordering and row identities.
          # @yield model mutation under the reentrant session monitor
          # @return [Object] mutation result
          # @api private
          def mutate(structural: true)
            session.synchronize do
              if session.defer_model(self)
                result = yield
                structural ? rebuild_indexes : invalidate_order
                return result
              end
              previous_rows = @rows.map { |row| Row.new(row.key, row.parent, row.cells.dup) }
              previous_sort = @sort
              begin
                result = yield
                structural ? rebuild_indexes : invalidate_order
                @observers.dup.each(&:model_will_change!)
              rescue StandardError
                @rows, @sort = previous_rows, previous_sort
                rebuild_indexes
                raise
              end
              @observers.dup.each(&:model_changed!)
              result
            end
          end

          # Scalar edits cannot change row identity or parent indexes. Sorting
          # snapshots still expire so reads inside the callback see current values.
          def invalidate_order
            @ordered_siblings, @sibling_positions = {}, {}
            @revision += 1
          end
        end

        # The same typed store with parent-aware insertion and recursive subtree removal.
        class TreeStore < ListStore
          # @param parent [TreeIter, nil] nil creates a root
          # @return [TreeIter] new row
          def append(parent = nil) = insert_row(parent, -1)
          def prepend(parent = nil) = insert_row(parent, 0)

          # Inserts under the supplied parent, or at the root for nil, preserving existing row identities.
          # @param parent [TreeIter, nil] parent or nil for roots
          # @param position [Integer] sibling index, or -1 to append
          # @return [TreeIter] new row
          def insert(parent, position) = insert_row(parent, position)
        end
      end
    end
  end
end
