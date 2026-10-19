module Lich
  module Common
    # SettingsProxy is defined here but relies on Settings module being fully defined first,
    # especially Settings._log. The actual require_relative for settings_proxy.rb
    # is now at the end of settings.rb.
    class SettingsProxy
      LOG_PREFIX = "[SettingsProxy]".freeze

      # Minimal change: add detached flag (default false)
      # Added script_name parameter to support InstanceSettings (core Lich functionality
      # that runs outside of Script context). When script_name is provided, it takes
      # precedence over Script.current.name in the save path.
      #
      # +source+, for a detached view (what select or sort returned), is the
      # container the view was taken from, so that an element taken from the
      # view (view.first) can be found in it and saved where it is.
      #
      # +unlocated+ marks a proxy (detached, without a path) for an element
      # of a view that can't be found in the settings: a write through it is
      # refused with a message instead of being saved somewhere else.
      #
      # +refusals+, shared by the unlocated elements one call to #each
      # yields (and the containers taken from them), counts the writes
      # through them that were refused, so that the user is told once per
      # loop (see #refusals).
      def initialize(settings_module, scope, path, target, detached: false, script_name: nil, source: nil, unlocated: false, refusals: nil)
        @settings_module = settings_module # This should be the Settings module itself
        @scope  = scope
        @path   = path.dup
        @target = target
        @detached = detached
        @script_name = script_name
        @source = source
        @unlocated = unlocated
        @refusals = refusals
        @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "INIT scope: #{@scope.inspect}, path: #{@path.inspect}, target_class: #{@target.class}, target_object_id: #{@target.object_id}, detached: #{@detached}, script_name: #{@script_name.inspect}" })
      end

      attr_reader :target, :path, :scope, :script_name

      # For an unlocated element yielded by #each, or a container taken from
      # one: a Hash shared by everything that one call to #each yielded,
      # whose :count is the number of writes through them that were refused
      # (Settings.refuse_proxy_save tells the user about the first one only).
      # nil for any other proxy.
      attr_reader :refusals

      # Minimal change: expose detached? status
      def detached?
        !!@detached
      end

      # True for the proxy of a view's element that can't be found in the
      # settings (see #initialize).
      def unlocated?
        !!@unlocated
      end

      def nil?
        @target.nil?
      end

      def binary_op(operator, other)
        other_value = other.is_a?(SettingsProxy) ? other.target : other
        @target.send(operator, other_value)
      end

      [:==, :!=, :eql?, :equal?, :<=>, :<, :<=, :>, :>=, :|, :&].each do |op|
        define_method(op) do |other|
          binary_op(op, other)
        end
      end

      def hash
        @target.hash
      end

      # Helper method for delegating conversion methods with appropriate return types
      private def delegate_conversion(method, options = {})
        if @target.respond_to?(method)
          @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "#{method}: delegating" })
          @target.send(method)
        else
          @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "#{method}: not supported" })

          if options[:strict]
            # For strict methods, raise NoMethodError
            raise NoMethodError.new("undefined method `#{method}' for #{@target.inspect}:#{@target.class}")
          else
            # For permissive methods, return the default value
            options[:default]
          end
        end
      end

      # Internal: rebind this proxy to the live container and clear detached state.
      # This centralizes target swaps so invariants/logging stay consistent.
      # Private: Settings._reattach_live! is its one caller, and calls it
      # with __send__.
      # @param new_target [Hash, Array] the live container resolved from root+path
      # @return [self]
      private def rebind_to_live!(new_target)
        @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> {
          "REBIND to live: old_target_oid=#{@target&.object_id}, new_target_oid=#{new_target&.object_id}, scope=#{@scope.inspect}, path=#{@path.inspect}"
        })
        @target = new_target
        @detached = false if instance_variable_defined?(:@detached)
        @source = nil
        self
      end

      # String conversions
      def to_s
        delegate_conversion(:to_s, default: '')
      end

      def to_str
        delegate_conversion(:to_str, strict: true)
      end

      def to_sym
        delegate_conversion(:to_sym, strict: true)
      end

      # Numeric conversions
      def to_i
        delegate_conversion(:to_i, default: 0)
      end

      def to_int
        delegate_conversion(:to_int, strict: true)
      end

      def to_f
        delegate_conversion(:to_f, default: 0.0)
      end

      def to_r
        delegate_conversion(:to_r, strict: true)
      end

      def to_c
        delegate_conversion(:to_c, default: Complex(0, 0))
      end

      # Collection conversions
      def to_a
        delegate_conversion(:to_a, default: [])
      end

      def to_ary
        delegate_conversion(:to_ary, strict: true)
      end

      def to_h
        delegate_conversion(:to_h, default: {})
      end

      def to_hash
        delegate_conversion(:to_hash, strict: true)
      end

      # added 20250620 for JSON.pretty_generate
      def to_json(*args)
        if @target.respond_to?(:to_json)
          @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "to_json: delegating with args" })
          @target.to_json(*args)
        else
          raise NoMethodError, "undefined method :to_json for #{@target.inspect}:#{@target.class}"
        end
      end

      # Other common conversions
      def to_proc
        delegate_conversion(:to_proc, strict: true)
      end

      def to_io
        delegate_conversion(:to_io, strict: true)
      end

      def to_path
        delegate_conversion(:to_path, strict: true)
      end

      # Special case for to_enum
      def to_enum(*args, &block)
        if @target.respond_to?(:to_enum)
          @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "to_enum: delegating" })
          @target.to_enum(*args, &block)
        else
          @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "to_enum: using default enum_for" })
          self.enum_for(*args, &block)
        end
      end

      # A copy of the container is not part of the settings, so dup and clone
      # return a plain copy of the target (proxies unwrapped, containers
      # inside it copied too) instead of a proxy that shares the target and
      # the path, through which a change to the copy (list.dup.pop) would
      # change and store the settings. A value that can't be copied whole is
      # copied container by container.
      def dup
        Marshal.load(Marshal.dump(@target))
      rescue TypeError
        @settings_module.unwrap_proxies(@target)
      end

      # As #dup; the copy is frozen when +freeze+ is true, or when it is nil
      # and the target is frozen, as Object#clone does.
      def clone(freeze: nil)
        copy = dup
        copy.freeze if freeze || (freeze.nil? && @target.frozen?)
        copy
      end

      # Updated inspect method to show the target's inspect string
      def inspect
        @target.inspect
      end

      # New method to show the proxy's internal details
      def proxy_details
        "<SettingsProxy scope=#{@scope.inspect} path=#{@path.inspect} target_class=#{@target.class} target_object_id=#{@target.object_id} detached=#{@detached} script_name=#{@script_name.inspect}>"
      end

      def pretty_print(pp)
        pp.pp(@target)
      end

      def is_a?(klass)
        @target.is_a?(klass)
      end

      def kind_of?(klass)
        @target.kind_of?(klass)
      end

      def instance_of?(klass)
        @target.instance_of?(klass)
      end

      # The implicit conversions this class defines for every target
      # (to_ary, to_hash, ...). Whether a proxy has one is whether its
      # target has it.
      IMPLICIT_CONVERSIONS = [:to_str, :to_sym, :to_int, :to_r, :to_ary, :to_hash, :to_proc, :to_io, :to_path].freeze

      # An implicit conversion (see IMPLICIT_CONVERSIONS) is reported only
      # when the target has it, so that Ruby, which asks before converting,
      # treats a proxy as it treats its target: a Hash proxy is not taken
      # apart like an Array by |key, (a, b)| or a, b = proxy.
      def respond_to?(method, include_private = false)
        return @target.respond_to?(method, include_private) if IMPLICIT_CONVERSIONS.include?(method.to_sym)

        super || @target.respond_to?(method, include_private)
      end

      # Yields each element as Array#each and Hash#each do, a container
      # element as a proxy with that element's path, so that a write through
      # it (rows.each { |row| row[:count] = 1 }) is stored at that element,
      # as for rows[i] or rows.find { ... }. A Hash yields one [key, value]
      # Array per entry, value proxied, which a |key, value| block takes
      # apart, exactly as Hash#each's own blocks do.
      #
      # For a detached view (what select or sort returned), or another
      # container built from one (what reverse, last(2) or list - x
      # returned), an element is proxied with the path it has in the
      # container it was taken from (see #view_element_proxy); a [key,
      # value] pair of a Hash (what sort_by returned for a Hash) is yielded
      # as the Hash yields it, with its value proxied at that key. One the
      # settings don't hold (an element of what map returned) is yielded
      # detached and unlocated, so a write through it is refused, and the
      # user is told once per loop (see #refusals).
      def each(&block)
        return enum_for(:each) { size_of_target } unless block

        each_element(&block)
      end

      # As Enumerable#each_with_index, with the elements #each yields.
      def each_with_index
        return enum_for(:each_with_index) { size_of_target } unless block_given?

        index = 0
        each_element do |element|
          yield element, index
          index += 1
        end
      end

      # As Enumerable#each_with_object, with the elements #each yields.
      def each_with_object(memo)
        return enum_for(:each_with_object, memo) { size_of_target } unless block_given?

        each_element { |element| yield element, memo }
        memo
      end

      # Yields one object per element of the target (see #each); returns self.
      private def each_element
        refusals = { count: 0 }
        case @target
        when Hash
          @target.each_pair { |key, value| yield [key, element_for(key, value, refusals)] }
        when Array
          @target.each_with_index { |value, index| yield element_for(index, value, refusals) }
        else
          @target.each { |item| yield item } if @target.respond_to?(:each)
        end
        self
      end

      # The size of the Enumerators #each, #each_with_index and
      # #each_with_object return without a block, as for the target's own.
      private def size_of_target
        @target.size if @target.respond_to?(:size)
      end

      # +value+, the target's element at +key+ (a Hash key or an Array
      # index), or for a container the proxy that writes to it where the
      # settings hold it (see #each). An element of a container built from
      # another one (a view, or what reverse, last(2) or merge returned) is
      # looked up in the container it was built from (see
      # #view_element_proxy), since its key or index there is not +key+.
      private def element_for(key, value, refusals)
        return value unless @settings_module.container?(value)
        return view_element_proxy([key], value, refusals) if built_from_source?

        SettingsProxy.new(@settings_module, @scope, @path + [key], value, script_name: @script_name)
      end

      # True for a proxy whose elements are looked up in the container it
      # was built from (+source+), not by their own key or index: a detached
      # view (what select or sort returned), or a new container another
      # non-destructive method built (reverse, rotate, last(2), list - x,
      # merge, ...), whose positions are not positions in the settings.
      private def built_from_source?
        detached? || !@source.nil?
      end

      NON_DESTRUCTIVE_METHODS = [
        :+, :-, :&, :|, :*,
        :all?, :any?, :assoc, :at, :bsearch, :bsearch_index, :chunk, :chunk_while,
        :collect, :collect_concat, :compact, :compare_by_identity?, :count, :cycle,
        :default, :default_proc, :detect, :dig, :drop, :drop_while,
        :each_cons, :each_entry, :each_slice, :empty?, # each_with_index and each_with_object are defined above
        :entries, :except, :fetch, :fetch_values, :filter, :find, :find_all, :find_index,
        :first, :flat_map, :flatten, :frozen?, :grep, :grep_v, :group_by, :has_value?,
        :include?, :inject, :invert, :join, :key, :keys, :last, :lazy, :length,
        :map, :max, :max_by, :member?, :merge, :min, :min_by, :minmax, :minmax_by,
        :none?, :one?, :pack, :partition, :permutation, :product, :rassoc, :reduce,
        :reject, :reverse, :rotate, :sample, :select, :shuffle, :size, :slice,
        :slice_after, :slice_before, :slice_when, :sort, :sort_by, :sum,
        :take, :take_while, :to_a, :to_h, :to_proc, :transform_keys, :transform_values,
        :uniq, :values, :values_at, :zip
      ].freeze

      # Subset of non-destructive methods that return container "views"
      NON_DESTRUCTIVE_CONTAINER_VIEWS = [
        :map, :collect, :select, :filter, :reject, :find_all, :grep, :grep_v,
        :sort, :sort_by, :uniq, :compact, :flatten, :slice, :take, :drop, :values
      ].freeze

      def [](key)
        @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "GET scope: #{@scope.inspect}, path: #{@path.inspect}, key: #{key.inspect}, target_object_id: #{@target.object_id}" })
        value = @target[key]
        if @settings_module.container?(value)
          # In a detached view (what select or sort returned), or a container
          # built from another one (#built_from_source?), a position is not
          # the element's position in the settings, so the element is looked
          # up in the container it was taken from. A negative Array index is
          # made positive, as for at and dig.
          (built_from_source? && view_element_proxy([key], value)) ||
            SettingsProxy.new(@settings_module, @scope, @path + (segment_in(@target, key) || [key]), value, script_name: @script_name)
        else
          value
        end
      end

      # Core Ruby methods that change a Hash or an Array in place. A call to
      # one of them through a proxy is applied to this session's copy and then
      # replayed on the row as stored (Settings.save_proxy_changes), so that
      # what other sessions saved in the same container is kept. Their blocks
      # (delete_if { ... }) therefore run once on this session's copy and again
      # on the stored container, and once more each time another session's
      # write makes the save start over, so they must not have side effects.
      # Both runs hold the lock of the script's settings in that scope (see
      # Settings.with_proxy_lock), so a slow block delays the script's other
      # threads writing settings in that scope until it returns.
      MUTATING_METHODS = [
        :<<, :[]=, :append, :clear, :collect!, :compact!, :compare_by_identity,
        :concat, :default=, :default_proc=, :delete, :delete_at, :delete_if,
        :fill, :filter!, :flatten!, :insert, :keep_if, :map!, :merge!, :pop,
        :prepend, :push, :rehash, :reject!, :replace, :reverse!, :rotate!,
        :select!, :shift, :shuffle!, :slice!, :sort!, :sort_by!, :store,
        :transform_keys!, :transform_values!, :uniq!, :unshift, :update
      ].freeze

      def []=(key, value)
        @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "SET scope: #{@scope.inspect}, path: #{@path.inspect}, key: #{key.inspect}, value: #{value.inspect}, target_object_id: #{@target.object_id}" })
        actual_value = value.is_a?(SettingsProxy) ? @settings_module.unwrap_proxies(value) : value # Corrected to use @settings_module
        # Under the entry's lock from the change to this session's copy until
        # the proxy shows the stored container (see Settings.with_proxy_lock).
        @settings_module.with_proxy_lock(self) do
          change_and_replay(:[]=, [key, actual_value], nil)
        end
        # rubocop:disable Lint/Void
        # This is Ruby expected behavior to return the value.
        value
        # rubocop:enable Lint/Void
      end

      def method_missing(method, *args, &block)
        @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "CALL scope: #{@scope.inspect}, path: #{@path.inspect}, method: #{method}, args: #{args.inspect}, target_object_id: #{@target.object_id}" })
        if @target.respond_to?(method)
          if NON_DESTRUCTIVE_METHODS.include?(method)
            @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "CALL   non-destructive method: #{method}" })
            target_dup = @target.dup
            unwrapped_args = args.map { |arg| arg.is_a?(SettingsProxy) ? @settings_module.unwrap_proxies(arg) : arg } # Corrected
            result = target_dup.send(method, *unwrapped_args, &block)
            # Minimal change: pass method name so we can tag views as detached and keep path
            return handle_non_destructive_result(method, result, unwrapped_args)
          else
            @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "CALL   destructive method: #{method}" })

            # NEW (5.12.7+): auto-reattach derived views before mutating
            # ensure destructive methods (.push) do not target a proxy non-destructive method (.sort)
            #
            # The view is bound to the container at its path, as the stored
            # row holds it (Settings._reattach_live!), and the call is made on
            # that container and stored there. When there is none of the
            # view's kind, nothing is changed or stored, the user is told,
            # and the call returns nil.
            #
            # A detached proxy without a path (a view's element not found in
            # the settings, a view of a root proxy, the default fetch
            # returned, or a container built from one) is never reattached:
            # with an empty path that would bind it to the whole row. The
            # call runs on its copy, and the save that follows stores nothing
            # and tells the user (Settings.save_proxy_changes).
            if detached? && !@path.empty?
              unless @settings_module._reattach_live!(self, method)
                @settings_module._log(Settings::LOG_LEVEL_ERROR, LOG_PREFIX, -> { "CALL   reattach failed; aborting destructive op #{method} on detached view" })
                return nil
              end
            end

            unwrapped_args = args.map { |arg| arg.is_a?(SettingsProxy) ? @settings_module.unwrap_proxies(arg) : arg } # Corrected
            return call_mutating_method(method, unwrapped_args, block) if MUTATING_METHODS.include?(method)

            # Any other method (key?, each_pair, ...) may or may not change the
            # container. What it changed, if anything, is saved.
            before = dump_of_target
            known = own_containers
            result = @target.send(method, *unwrapped_args, &block)
            save_changes_since(method, before, known) if before.nil? || dump_of_target != before
            return handle_method_result(result, method, unwrapped_args)
          end
        else
          super
        end
      end

      # Applies a MUTATING_METHODS call to this session's copy, then replays it
      # on the stored row. When it was replayed, the result is the one from the
      # stored container (what pop or delete took from what was saved), and
      # this proxy now shows that container.
      #
      # All of it runs under the entry's lock (see Settings.with_proxy_lock).
      private def call_mutating_method(method, args, block)
        @settings_module.with_proxy_lock(self) do
          result, replayed = change_and_replay(method, args, block)
          if replayed
            stored_result, stored_container = replayed
            stored_result.equal?(stored_container) ? self : handle_mutating_result(stored_result, method, args)
          else
            handle_mutating_result(result, method, args)
          end
        end
      end

      # Applies +method+ (a MUTATING_METHODS call, or []=) to this session's
      # copy, replays it on the stored row (Settings.save_proxy_changes) and,
      # when it was replayed, shows the stored container through this proxy
      # (#take_stored_container). Called under the entry's lock.
      #
      # For an Array method whose arguments include a position
      # (POSITION_METHODS), a negative index or range bound is first made
      # positive against this session's copy (see #positions_in_copy), and
      # the call is replayed on the stored Array's first elements, as many as
      # this session's copy had, keeping the ones another session appended
      # after them (see Settings.replay_at_positions).
      #
      # Returns [the call's result on this session's copy, the [result,
      # container] pair from the replay or nil]; the replay's result is,
      # when it is one of the stored containers, the container of this
      # session's copy that now shows it.
      private def change_and_replay(method, args, block)
        known = own_containers
        if @target.is_a?(Array) && POSITION_METHODS.include?(method)
          args = positions_in_copy(method, args, block)
          before = @target.dup
          result = @target.send(method, *args, &block)
          replay_args = [before.size, first_changed_position(before, @target), method, args]
          replayed = @settings_module.save_proxy_changes(self, Settings::REPLAY_AT_POSITIONS, replay_args, block, label: method)
        else
          result = @target.send(method, *args, &block)
          replayed = @settings_module.save_proxy_changes(self, method, args, block)
        end
        @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "CALL   target_after_op: #{@target.inspect}" })
        return [result, nil] unless replayed

        stored_result, stored_container = replayed
        [result, [take_stored_container(stored_container, stored_result, known), stored_container]]
      end

      # The first position at which +after+ (an Array) no longer holds the
      # same object as +before+, a shallow copy of it taken before a call;
      # nil when it holds the same objects.
      private def first_changed_position(before, after)
        (0...[before.size, after.size].max).find { |i| i >= before.size || i >= after.size || !before[i].equal?(after[i]) }
      end

      # The containers of this proxy's copy that #show_stored may fill in
      # place after a replayed write (see #containers_in). For a container
      # built from another one (what reverse, last(2) or merge returned, see
      # #built_from_source?), only the container itself: its elements are
      # the elements of the container it was built from, at other positions
      # or keys, and filling them in place would make a proxy kept for that
      # container show the stored elements of other positions.
      private def own_containers
        return {}.compare_by_identity.merge!(@target => true) if !detached? && !@source.nil?

        containers_in(@target)
      end

      # The containers in +container+ (itself included, and those inside its
      # elements), as an identity Hash. Taken before a call changes this
      # session's copy, so that #show_stored fills in place only containers
      # the copy held before it, and never one the call put there (a Hash
      # given to push, a []= value, what a block returned), which the caller
      # may still hold and use.
      private def containers_in(container, found = {}.compare_by_identity)
        return found if found.key?(container)

        found[container] = true
        (container.is_a?(Hash) ? container.each_value : container.each).each do |value|
          containers_in(value, found) if @settings_module.container?(value)
        end
        found
      end

      # Array methods whose arguments include a position (an index, a start or
      # a range): []=, delete_at, insert, fill and slice!.
      POSITION_METHODS = [:[]=, :delete_at, :insert, :fill, :slice!].freeze

      # An index no Array reaches: delete_at and slice! with it change
      # nothing and return nil, whatever the size of the stored Array.
      NO_POSITION = -(2**62)

      # +args+ of a POSITION_METHODS call on an Array, with each position
      # counted from the end (a negative index, start or range bound) turned
      # into the position it has in this session's copy, so that the call
      # replayed on the stored Array (Settings.save_proxy_changes) changes
      # the elements this session saw there, as a proxy for an element
      # (list[-1]['k'] = v) does, and not the stored Array's last elements.
      # So list[-1] = v, list.delete_at(-1) or list.slice!(-2..) keep an
      # element another session appended meanwhile. When such a call runs to
      # the end from that position (fill without a length, an endless range,
      # a slice! length past the end), it stops at this session's end too.
      # A position counted from the start is left as it is: the replay runs
      # on as many of the stored Array's first elements as this session's
      # copy had (Settings.replay_at_positions), so it does not reach past
      # this session's end either. (pop, shift, push and unshift still act
      # on the stored Array's ends.)
      #
      # On this session's copy the call does exactly what it would with the
      # original arguments. A position before the start that makes the call
      # raise ([]=, insert, fill with a range) is left as it is, so the call
      # raises before anything is saved; one that makes it do nothing
      # (delete_at, slice!) becomes NO_POSITION, so it does nothing on the
      # stored Array either.
      private def positions_in_copy(method, args, block)
        return args unless @target.is_a?(Array) && POSITION_METHODS.include?(method)

        index = method == :fill && block.nil? ? 1 : 0
        position = args[index]
        return args unless args.size > index && (position.is_a?(Range) || (position.is_a?(Integer) && position.negative?))

        size = @target.size
        replaced = position.is_a?(Range) ? range_in_copy(method, position, size) : index_in_copy(method, position, size)
        return args if replaced.nil?

        replaced = replaced.first(1) if method == :fill && !args[index + 1].nil? # a length of its own

        copy = args.dup
        copy[index, replaced.size] = replaced
        if method == :slice! && position.is_a?(Integer) && copy[index] >= 0 && copy[index + 1].is_a?(Integer)
          copy[index + 1] = [copy[index + 1], size - copy[index]].min # a length past the end
        end
        copy
      end

      # The arguments that replace +position+, a negative Integer, in a
      # +method+ call on an Array of +size+ elements (see
      # #positions_in_copy); nil to leave it as it is.
      private def index_in_copy(method, position, size)
        case method
        when :insert
          # insert(-1, x) inserts after the last element.
          [position + size + 1] if position + size + 1 >= 0
        when :fill
          # fill starts at the first element for a start before it, and with
          # no length runs to the end.
          start = [position + size, 0].max
          [start, size - start]
        else
          if position + size >= 0
            [position + size]
          elsif method != :[]=
            [NO_POSITION]
          end
        end
      end

      # [+range+ with each negative Integer bound turned into its position
      # in this session's copy of +size+ elements], for a +method+ call (see
      # #positions_in_copy). A range from a negative start that runs to the
      # end (an endless one, or for []= and slice! one ending past the end)
      # ends at that copy's end. A range whose end then comes before its
      # start becomes an empty range at its start. A range that starts
      # before the first element is left as it is (nil), or is
      # [NO_POSITION] for slice!, which then does nothing.
      private def range_in_copy(method, range, size)
        first = range.begin
        last = range.end
        return nil unless (first.nil? || first.is_a?(Integer)) && (last.nil? || last.is_a?(Integer))
        return nil unless first&.negative? || last&.negative?

        if first&.negative?
          first += size
          return (method == :slice! ? [NO_POSITION] : nil) if first.negative?

          past_end = last.nil? || (method != :fill && !last.negative? && (range.exclude_end? ? last : last + 1) > size)
          return [Range.new(first, size, true)] if past_end
        end
        return [Range.new(first, last, range.exclude_end?)] unless last.negative?

        last += size
        [last.negative? ? Range.new(first || 0, first || 0, true) : Range.new(first, last, range.exclude_end?)]
      end

      # The result of a MUTATING_METHODS call. A container that is still one
      # of this proxy's elements (what store returns) is a proxy for that
      # element. Any other container is what the call took out (delete, pop,
      # shift, slice!): it is no longer part of the settings, so it is
      # returned as the plain value, and changing it saves nothing.
      private def handle_mutating_result(result, method, args)
        return self if result.equal?(@target)
        return result unless @settings_module.container?(result)

        element_path = element_path_for(method, args, result)
        element_path ? SettingsProxy.new(@settings_module, @scope, element_path, result, script_name: @script_name) : result
      end

      # After a write was replayed on the stored row, shows that container
      # (with whatever other sessions saved in it) through this proxy and
      # through every view sharing this proxy's container. (A detached view
      # is never replayed, so it keeps its own contents.) Runs under the
      # entry's lock, right after the store (see Settings.with_proxy_lock).
      #
      # The copy's containers are updated in place, not swapped for the
      # stored ones, wherever the stored container has a container of the
      # same class at the same key or index (see #show_stored), so a proxy
      # kept for a container inside this one (opts and opts['sub']) still
      # shows what this proxy shows, and the other way round.
      #
      # A Hash that is being iterated (opts.each_pair { |k, v| opts[k] = ... },
      # in this thread or another one) can't be replaced, so it keeps this
      # session's copy until the next read; the write is stored all the same.
      #
      # Returns +stored_result+, or, when it is one of the stored containers
      # whose contents a container of the copy now shows, that container.
      #
      # +known+ (from #containers_in) holds the containers the copy held
      # before the write; only those are filled in place.
      private def take_stored_container(stored_container, stored_result = nil, known = own_containers)
        return stored_result unless stored_container.instance_of?(@target.class)
        return stored_result if stored_container.equal?(@target)

        shown_by = {}.compare_by_identity
        show_stored(@target, stored_container, shown_by, {}.compare_by_identity, known)
        # It now shows the container at its path, so its positions are that
        # container's (what reverse returned shows the container itself).
        @source = nil if shown_by.key?(stored_container)
        shown_by.fetch(stored_result, stored_result)
      end

      # Makes +mine+ (a container of this session's copy) hold what +stored+
      # holds. Where +stored+ has a container at a key (or index) where
      # +mine+ has one of the same class that the copy held before the write
      # (+known+), +mine+ keeps its own and that one is made to hold the
      # stored one's contents, and so on down. An Array is matched by
      # position, as a proxy's path addresses it. A container the write put
      # in the copy (push(entry), opts['k'] = h) is never changed: the stored
      # copy of it takes its place. Each container of the copy is used once
      # (+used+). +shown_by+ maps each stored container to the container of
      # the copy that now shows it.
      private def show_stored(mine, stored, shown_by, used, known)
        used[mine] = true
        kept = (mine.is_a?(Hash) ? stored.keys : stored.each_index.to_a).filter_map do |at|
          own = mine.is_a?(Hash) ? (mine.key?(at) ? mine[at] : nil) : mine[at]
          theirs = stored[at]
          next unless @settings_module.container?(theirs) && own.instance_of?(theirs.class) && !own.equal?(theirs) && known.key?(own) && !used.key?(own)

          used[own] = true
          [at, own, theirs]
        end
        begin
          mine.replace(stored)
        rescue FrozenError
          raise
        rescue RuntimeError => e
          @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "stored container not shown (#{e.message}); the proxy keeps this session's copy" })
          return
        end
        shown_by[stored] = mine
        kept.each { |at, own, _theirs| mine[at] = own }
        kept.each { |_at, own, theirs| show_stored(own, theirs, shown_by, used, known) }
      end

      # Saves what +method+ (one in neither method list) changed in the
      # target, +before+ being the target's Marshal bytes before the call.
      #
      # For a Hash, and for an Array whose size did not change, the entries
      # that changed are replayed on the stored container, all in one update
      # of the row: delete for a key that is gone, []= for a key or index
      # whose value is new or different (a changed value is stored whole).
      # So entries that other sessions, or writes made inside the
      # call's block (opts.each_pair { |k, v| opts[k] = ... }), stored
      # meanwhile in the rest of the container are kept, although this
      # session's copy may not show them. Otherwise (an Array that grew or
      # shrank, or a target that can't be dumped) this session's copy of the
      # container is stored.
      private def save_changes_since(method, before, known)
        changes = changed_entries(load_dump(before))
        unless changes
          @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "CALL   #{method} changed the target; saving this session's copy" })
          @settings_module.save_proxy_changes(self)
          return
        end

        return if changes.empty?

        @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "CALL   #{method} changed #{changes.size} entries; replaying them" })
        @settings_module.with_proxy_lock(self) do
          replayed = @settings_module.save_proxy_changes(self, Settings::REPLAY_ENTRY_CHANGES, [changes], label: method)
          take_stored_container(replayed[1], nil, known) if replayed
        end
      end

      # The [operation, args] pairs that turn +old+ into the target, for a
      # Hash or an Array of the same size: [:delete, [key]] for a key that
      # is gone, then [:[]=, [key_or_index, value]] for each entry that is
      # new or whose value differs (compared by Marshal.dump). nil for any
      # other pair of containers.
      private def changed_entries(old)
        if @target.is_a?(Hash) && old.is_a?(Hash)
          removed = old.each_key.reject { |key| @target.key?(key) }.map { |key| [:delete, [key]] }
          changed = @target.reject { |key, value| old.key?(key) && same_dump?(old[key], value) }
          removed + changed.map { |key, value| [:[]=, [key, value]] }
        elsif @target.is_a?(Array) && old.is_a?(Array) && @target.size == old.size
          @target.each_index.reject { |index| same_dump?(old[index], @target[index]) }.map { |index| [:[]=, [index, @target[index]]] }
        end
      end

      # True when +a+ and +b+ have the same Marshal bytes; false when either
      # can't be dumped.
      private def same_dump?(a, b)
        Marshal.dump(a) == Marshal.dump(b)
      rescue StandardError
        false
      end

      # The object +bytes+ (from #dump_of_target) hold; nil for nil, or when
      # they can't be loaded.
      private def load_dump(bytes)
        bytes && Marshal.load(bytes)
      rescue StandardError
        nil
      end

      # Marshal bytes of the target, or nil when it can't be dumped.
      private def dump_of_target
        Marshal.dump(@target)
      rescue StandardError
        nil
      end

      # A container returned by a non-destructive method. When it is one of
      # this proxy's elements (find, first, last, at, fetch, min_by, sample,
      # ...) or, for dig, an element further down, the proxy for it has that
      # element's path, so that a write through it saves to that element.
      # Any other container (a new one, such as what merge or first(2)
      # return) keeps this proxy's path, and the views listed in
      # NON_DESTRUCTIVE_CONTAINER_VIEWS are tagged as detached.
      #
      # The elements of such a container are looked up in the container it
      # was built from (see #built_from_source? and #view_element_proxy).
      def handle_non_destructive_result(method, result, args = [])
        @settings_module.reset_path_and_return(
          if @settings_module.container?(result) && built_from_source? && (element = view_element_proxy(keys_for(method, args), result))
            element
          elsif @settings_module.container?(result) && (element_path = element_path_for(method, args, result))
            SettingsProxy.new(@settings_module, @scope, element_path, result, script_name: @script_name)
          elsif @settings_module.container?(result) && (pathless_element? || fetch_default?(method, args))
            pathless_derived_proxy(result)
          elsif @settings_module.container?(result)
            if @target.is_a?(Array) && [:find, :detect].include?(method)
              # For Array#find / Array#detect, identify the element index in the
              # original array and create a proxy that points to that element.
              idx = @target.index(result)

              if !idx.nil?
                element_path = @path.dup
                element_path << idx
                SettingsProxy.new(@settings_module, @scope, element_path, result, script_name: @script_name)
              else
                # Fallback: if we somehow can't locate the element, preserve
                # the old behavior (path == @path, no index).
                is_view = NON_DESTRUCTIVE_CONTAINER_VIEWS.include?(method)
                SettingsProxy.new(@settings_module, @scope, @path.dup, result, detached: is_view, script_name: @script_name)
              end
            else
              # Existing behavior for all other non-destructive container
              # methods. Every such container keeps the container it was
              # built from as its source, so that its elements are found
              # where the settings hold them (see #built_from_source?).
              is_view = NON_DESTRUCTIVE_CONTAINER_VIEWS.include?(method)
              SettingsProxy.new(@settings_module, @scope, @path.dup, result, detached: is_view, script_name: @script_name,
                                                                               source: view_source)
            end
          else
            # Non-container results (e.g., Hash#keys) stay as plain values
            result
          end
        )
      end

      def handle_method_result(result, method = nil, args = [])
        if result.equal?(@target)
          self # Return self if the method modified the target in-place and returned it
        elsif @settings_module.container?(result) && (element_path = element_path_for(method, args, result))
          SettingsProxy.new(@settings_module, @scope, element_path, result, script_name: @script_name)
        elsif @settings_module.container?(result)
          # If a new container is returned (e.g. some destructive methods might return a new object)
          # Wrap it in a new proxy, maintaining the current path and scope.
          SettingsProxy.new(@settings_module, @scope, @path, result, script_name: @script_name)
        else
          result
        end
      end

      # True for the proxy of an element that has no path in the settings:
      # a view's element not found in the settings, or the default fetch
      # returned (detached, without a path, and not a view of a root proxy,
      # which has the root as its source).
      private def pathless_element?
        detached? && @path.empty? && @source.nil?
      end

      # True when fetch returned its default (its second argument or what its
      # block gave) because the key is not in the container. The default is
      # not part of the settings, so a write through it is not stored, as for
      # a plain Hash, instead of being written into or over the container.
      private def fetch_default?(method, args)
        method == :fetch && segment_in(@target, args.first).nil?
      end

      # The proxy for a new container (what merge or except return) built
      # from a #pathless_element? proxy, or for the default fetch returned
      # (#fetch_default?). It is detached and has no path either, so a write
      # through it is refused with a message instead of landing at the top of
      # the row.
      private def pathless_derived_proxy(result)
        SettingsProxy.new(@settings_module, @scope, [], result, detached: true, script_name: @script_name, unlocated: unlocated?, refusals: @refusals)
      end

      # The path of +result+ when it is an element of this proxy's container:
      # for dig, fetch and at, the element their keys lead to; otherwise the
      # first element that is +result+ itself (not just equal to it). An
      # Array index is made non-negative. nil when +result+ is not one, and
      # for a detached view or another container built from one
      # (#built_from_source?), whose positions are not positions in the
      # settings (see #view_element_proxy).
      private def element_path_for(method, args, result)
        return nil if built_from_source?

        segments = segments_to(keys_for(method, args), result, @target)
        segments && @path + segments
      end

      # The keys that dig, fetch and at follow; none for other methods.
      private def keys_for(method, args)
        case method
        when :dig then args
        when :fetch, :at then args.first(1)
        else []
        end
      end

      # The segments from +container+ to +result+: along +keys+ (from
      # #keys_for) when they lead to +result+ itself, otherwise the index or
      # key of the first element of +container+ that is +result+. nil when
      # +result+ is neither.
      private def segments_to(keys, result, container)
        (keys.empty? ? nil : segments_along(container, keys, result)) || child_segment(container, result)
      end

      # For a detached view: the proxy for +value+ when it is one of the
      # view's elements (or, along +keys+, one further down). Its path is
      # where that element is in the container the view was taken from. When
      # the element is not there (an element of what map returned, or the
      # container has since taken a stored row that has no container of
      # the element's kind at its key or index, see #take_stored_container), the proxy
      # is detached and unlocated, so a write through it is refused instead
      # of being saved by position somewhere else. nil when +value+ is not an
      # element of the view (a new container, such as what merge returns).
      #
      # A [key, value] pair of a view of a Hash (what sort, sort_by, min_by(2)
      # or first(2) returned) whose value is a container the Hash holds at that
      # key is the plain pair [key, proxy for the value at that key], as the
      # Hash's own #each yields it, so that a |key, value| block writes to
      # the value where the settings hold it; a container further down the
      # value has its path under that key.
      private def view_element_proxy(keys, value, refusals = @refusals)
        segments = segments_to(keys, value, @target)
        return nil unless segments

        base = @source && source_segment(segments.first)
        if base
          SettingsProxy.new(@settings_module, @scope, @path + base + segments.drop(1), value, script_name: @script_name)
        elsif (key = pair_key_in_hash_source(segments.first)) && (segments.size == 1 || segments[1] == 1)
          if segments.size == 1
            # The pair itself, as the Hash's each yields it: [key, the proxy
            # for the value there], which |key, value| takes apart.
            [value.first, SettingsProxy.new(@settings_module, @scope, @path + [key], value.last, script_name: @script_name)]
          else
            SettingsProxy.new(@settings_module, @scope, @path + [key] + segments.drop(2), value, script_name: @script_name)
          end
        else
          @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "view element at #{segments.inspect} not found in the settings; writes through it are refused" })
          SettingsProxy.new(@settings_module, @scope, [], value, detached: true, script_name: @script_name, unlocated: true, refusals: refusals)
        end
      end

      # The segment, in the container the view was taken from, of the view's
      # element at +view_segment+: the same key or index when that is where
      # it is, otherwise where it is found. A Hash view of a Hash (select,
      # reject, slice, compact) keeps the keys, so its key also addresses
      # the element after the container has taken the stored row's elements,
      # as long as that key still holds the same kind of container; a fresh
      # read of that key would address the same entry.
      private def source_segment(view_segment)
        element = @target[view_segment]
        same = segment_in(@source, view_segment)
        return same if same && (@source[same.first].equal?(element) || same_key_in_hash_source?(same.first, element))

        child_segment(@source, element)
      end

      # For a view whose source is a Hash: the key of the view's element at
      # +view_segment+ when that element is a [key, value] pair (what
      # Hash#sort or Hash#first(2) build) whose value is the very container
      # the source holds at that key. nil otherwise (a value another write
      # has since replaced, or an Array value of the Hash that only looks
      # like a pair), so a write through it is refused.
      private def pair_key_in_hash_source(view_segment)
        return nil unless @source.is_a?(Hash) && @target.is_a?(Array)

        pair = @target[view_segment]
        return nil unless pair.instance_of?(Array) && pair.size == 2 && @settings_module.container?(pair.last)

        key, value = pair
        key if @source.key?(key) && @source[key].equal?(value)
      end

      # True when this view and its source are Hashes and +key+ holds, in
      # the source, a container of the same class as +element+.
      private def same_key_in_hash_source?(key, element)
        @target.is_a?(Hash) && @source.is_a?(Hash) && @source[key].instance_of?(element.class)
      end

      # The container a view (or another container) taken from this proxy
      # shares its elements with: this proxy's source when it has one (see
      # #built_from_source?), otherwise its target. Settings._reattach_live!
      # also calls it, with __send__, for this session's copy of a view's
      # container.
      private def view_source
        detached? ? @source : (@source || @target)
      end

      # The segments along +keys+ when they lead from +node+ to +result+
      # itself; nil otherwise.
      private def segments_along(node, keys, result)
        segments = keys.map do |key|
          segment = segment_in(node, key)
          return nil unless segment

          node = node[segment.first]
          segment.first
        end
        node.equal?(result) ? segments : nil
      end

      # [key], or [index] made non-negative, when +key+ finds an entry in
      # +node+; nil otherwise.
      private def segment_in(node, key)
        case node
        when Hash
          [key] if node.key?(key)
        when Array
          return nil unless key.is_a?(Integer)

          index = key.negative? ? key + node.size : key
          [index] if index >= 0 && index < node.size
        end
      end

      # [index] or [key] of the first element of +container+ that is
      # +result+ itself; nil when there is none.
      private def child_segment(container, result)
        case container
        when Array
          index = container.index { |element| element.equal?(result) }
          [index] if index
        when Hash
          entry = container.find { |_key, value| value.equal?(result) }
          [entry.first] if entry
        end
      end

      def respond_to_missing?(method, include_private = false)
        @target.respond_to?(method, include_private) || super
      end
    end
  end
end
