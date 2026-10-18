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
      # of a view, or of an element yielded by each, that can't be found in
      # the settings: a write through it is refused with a message instead
      # of being saved somewhere else.
      def initialize(settings_module, scope, path, target, detached: false, script_name: nil, source: nil, unlocated: false)
        @settings_module = settings_module # This should be the Settings module itself
        @scope  = scope
        @path   = path.dup
        @target = target
        @detached = detached
        @script_name = script_name
        @source = source
        @unlocated = unlocated
        @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "INIT scope: #{@scope.inspect}, path: #{@path.inspect}, target_class: #{@target.class}, target_object_id: #{@target.object_id}, detached: #{@detached}, script_name: #{@script_name.inspect}" })
      end

      attr_reader :target, :path, :scope, :script_name

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
      # @param new_target [Hash, Array] the live container resolved from root+path
      # @return [self]
      private def rebind_to_live!(new_target)
        @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> {
          "REBIND to live: old_target_oid=#{@target&.object_id}, new_target_oid=#{new_target&.object_id}, scope=#{@scope.inspect}, path=#{@path.inspect}"
        })
        @target = new_target
        @detached = false if instance_variable_defined?(:@detached)
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

      def respond_to?(method, include_private = false)
        super || @target.respond_to?(method, include_private)
      end

      # Minimal change: items yielded from #each are "views" over the container.
      # Mark them detached so mutations during a derived iteration won't clobber root.
      def each(&_block)
        return enum_for(:each) unless block_given?
        if @target.respond_to?(:each)
          @target.each do |item|
            if @settings_module.container?(item)
              yield SettingsProxy.new(@settings_module, @scope, [], item, detached: true, script_name: @script_name)
            else
              yield item
            end
          end
        end
        self
      end

      NON_DESTRUCTIVE_METHODS = [
        :+, :-, :&, :|, :*,
        :all?, :any?, :assoc, :at, :bsearch, :bsearch_index, :chunk, :chunk_while,
        :collect, :collect_concat, :compact, :compare_by_identity?, :count, :cycle,
        :default, :default_proc, :detect, :dig, :drop, :drop_while,
        :each_cons, :each_entry, :each_slice, :each_with_index, :each_with_object, :empty?,
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
          # In a detached view (what select or sort returned, or an element
          # yielded by each), a position is not the element's position in
          # the settings, so the element is looked up in the container the
          # view was taken from.
          (detached? && view_element_proxy([key], value)) ||
            SettingsProxy.new(@settings_module, @scope, @path.dup << key, value, script_name: @script_name)
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
        @target[key] = actual_value
        @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "SET   target_after_set: #{@target.inspect}" })
        replayed = @settings_module.save_proxy_changes(self, :[]=, [key, actual_value])
        take_stored_container(replayed[1]) if replayed
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
            if detached?
              unless @settings_module._reattach_live!(self)
                @settings_module._log(Settings::LOG_LEVEL_ERROR, LOG_PREFIX, -> { "CALL   reattach failed; aborting destructive op #{method} on detached view" })
                return self
              end
            end

            unwrapped_args = args.map { |arg| arg.is_a?(SettingsProxy) ? @settings_module.unwrap_proxies(arg) : arg } # Corrected
            return call_mutating_method(method, unwrapped_args, block) if MUTATING_METHODS.include?(method)

            # Any other method (key?, each_pair, ...) may or may not change the
            # container. What it changed, if anything, is saved.
            before = dump_of_target
            result = @target.send(method, *unwrapped_args, &block)
            save_changes_since(method, before) if before.nil? || dump_of_target != before
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
      private def call_mutating_method(method, args, block)
        result = @target.send(method, *args, &block)
        @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "CALL   target_after_op: #{@target.inspect}" })
        replayed = @settings_module.save_proxy_changes(self, method, args, block)
        return handle_mutating_result(result, method, args) unless replayed

        stored_result, stored_container = replayed
        take_stored_container(stored_container)
        stored_result.equal?(stored_container) ? self : handle_mutating_result(stored_result, method, args)
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
      # is never replayed, so it keeps its own contents.)
      #
      # A Hash that is being iterated (opts.each_pair { |k, v| opts[k] = ... },
      # in this thread or another one) can't be replaced, so it keeps this
      # session's copy until the next read; the write is stored all the same.
      private def take_stored_container(stored_container)
        return unless stored_container.instance_of?(@target.class)
        return if stored_container.equal?(@target)

        begin
          @target.replace(stored_container)
        rescue FrozenError
          raise
        rescue RuntimeError => e
          @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "stored container not shown (#{e.message}); the proxy keeps this session's copy" })
        end
      end

      # Saves what +method+ (one in neither method list) changed in the
      # target, +before+ being the target's Marshal bytes before the call.
      #
      # For a Hash, and for an Array whose size did not change, each entry
      # that changed is replayed on the stored container: delete for a key
      # that is gone, []= for a key or index whose value is new or
      # different. So entries that other sessions, or writes made inside the
      # call's block (opts.each_pair { |k, v| opts[k] = ... }), stored
      # meanwhile in the rest of the container are kept, although this
      # session's copy may not show them. Otherwise (an Array that grew or
      # shrank, or a target that can't be dumped) this session's copy of the
      # container is stored.
      private def save_changes_since(method, before)
        changes = changed_entries(load_dump(before))
        unless changes
          @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "CALL   #{method} changed the target; saving this session's copy" })
          @settings_module.save_proxy_changes(self)
          return
        end

        @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "CALL   #{method} changed #{changes.size} entries; replaying them" })
        replayed = nil
        changes.each do |operation, args|
          replayed = @settings_module.save_proxy_changes(self, operation, args) || replayed
        end
        take_stored_container(replayed[1]) if replayed
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
      # A detached view's elements are looked up in the container the view
      # was taken from (see #view_element_proxy).
      def handle_non_destructive_result(method, result, args = [])
        @settings_module.reset_path_and_return(
          if @settings_module.container?(result) && detached? && (element = view_element_proxy(keys_for(method, args), result))
            element
          elsif @settings_module.container?(result) && (element_path = element_path_for(method, args, result))
            SettingsProxy.new(@settings_module, @scope, element_path, result, script_name: @script_name)
          elsif @settings_module.container?(result) && pathless_element?
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
              # Existing behavior for all other non-destructive container methods
              is_view = NON_DESTRUCTIVE_CONTAINER_VIEWS.include?(method)
              SettingsProxy.new(@settings_module, @scope, @path.dup, result, detached: is_view, script_name: @script_name,
                                                                               source: is_view ? view_source : nil)
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
        elsif @settings_module.container?(result) && pathless_element?
          pathless_derived_proxy(result)
        elsif @settings_module.container?(result)
          # If a new container is returned (e.g. some destructive methods might return a new object)
          # Wrap it in a new proxy, maintaining the current path and scope.
          SettingsProxy.new(@settings_module, @scope, @path, result, script_name: @script_name)
        else
          result
        end
      end

      # True for the proxy of an element that has no path in the settings:
      # an element yielded by each, or a view's element not found in the
      # settings (detached, without a path, and not a view of a root proxy,
      # which has the root as its source).
      private def pathless_element?
        detached? && @path.empty? && @source.nil?
      end

      # The proxy for a new container (what merge or except return) built
      # from a #pathless_element? proxy. It is detached and has no path
      # either, so a write through it is not stored (and, for a view's
      # element, is refused with a message) instead of landing at the top of
      # the row.
      private def pathless_derived_proxy(result)
        SettingsProxy.new(@settings_module, @scope, [], result, detached: true, script_name: @script_name, unlocated: unlocated?)
      end

      # The path of +result+ when it is an element of this proxy's container:
      # for dig, fetch and at, the element their keys lead to; otherwise the
      # first element that is +result+ itself (not just equal to it). An
      # Array index is made non-negative. nil when +result+ is not one, and
      # for a detached view, whose positions are not positions in the
      # settings (see #view_element_proxy).
      private def element_path_for(method, args, result)
        return nil if detached?

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
      # the element is not there (a view of an element yielded by each, or
      # the container has since taken the stored row's elements), the proxy
      # is detached and unlocated, so a write through it is refused instead
      # of being saved by position somewhere else. nil when +value+ is not an
      # element of the view (a new container, such as what merge returns).
      private def view_element_proxy(keys, value)
        segments = segments_to(keys, value, @target)
        return nil unless segments

        base = @source && source_segment(segments.first)
        if base
          SettingsProxy.new(@settings_module, @scope, @path + base + segments.drop(1), value, script_name: @script_name)
        else
          @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "view element at #{segments.inspect} not found in the settings; writes through it are refused" })
          SettingsProxy.new(@settings_module, @scope, [], value, detached: true, script_name: @script_name, unlocated: true)
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

      # True when this view and its source are Hashes and +key+ holds, in
      # the source, a container of the same class as +element+.
      private def same_key_in_hash_source?(key, element)
        @target.is_a?(Hash) && @source.is_a?(Hash) && @source[key].instance_of?(element.class)
      end

      # The container a view taken from this proxy shares its elements with.
      private def view_source
        detached? ? @source : @target
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
