module Lich
  module Common
    # SettingsProxy is defined here but relies on Settings module being fully defined first,
    # especially Settings._log. The actual require_relative for settings_proxy.rb
    # is now at the end of settings.rb.
    class SettingsProxy
      LOG_PREFIX = "[SettingsProxy]".freeze

      def initialize(settings_module, scope, path, target)
        @settings_module = settings_module # This should be the Settings module itself
        @scope = scope
        @path = path.dup
        @target = target
        @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "INIT scope: #{@scope.inspect}, path: #{@path.inspect}, target_class: #{@target.class}, target_object_id: #{@target.object_id}" })
      end

      attr_reader :target, :path, :scope

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

      def to_s
        @target.to_s
      end

      # Updated inspect method to show the target's inspect string
      def inspect
        @target.inspect
      end

      # New method to show the proxy's internal details
      def proxy_details
        "<SettingsProxy scope=#{@scope.inspect} path=#{@path.inspect} target_class=#{@target.class} target_object_id=#{@target.object_id}>"
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

      # Updated to_hash method to work with any object that responds to to_hash
      def to_hash
        if @target.respond_to?(:to_hash)
          @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "to_hash: target responds to to_hash, delegating" })
          @target.to_hash
        else
          @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "to_hash: target does not respond to to_hash, returning nil" })
          nil
        end
      end

      # Updated to_h method to work with any object that responds to to_h
      def to_h
        if @target.respond_to?(:to_h)
          @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "to_h: target responds to to_h, delegating" })
          @target.to_h
        else
          @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "to_h: target does not respond to to_h, returning nil" })
          nil
        end
      end

      def to_ary
        return nil unless @target.is_a?(Array)
        @target.dup
      end

      def to_a
        to_ary
      end

      [:to_int, :to_i, :to_str, :to_sym, :to_proc].each do |method|
        define_method(method) do
          @target.send(method) if @target.respond_to?(method)
        end
      end

      def each(&_block)
        return enum_for(:each) unless block_given?
        if @target.respond_to?(:each)
          @target.each do |item|
            if @settings_module.container?(item)
              yield SettingsProxy.new(@settings_module, @scope, [], item)
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
        :collect, :collect_concat, :combination, :compact, :compare_by_identity?, :count, :cycle,
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

      def [](key)
        @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "GET scope: #{@scope.inspect}, path: #{@path.inspect}, key: #{key.inspect}, target_object_id: #{@target.object_id}" })
        value = @target[key]
        if @settings_module.container?(value)
          new_path = @path.dup
          new_path << key
          SettingsProxy.new(@settings_module, @scope, new_path, value)
        else
          value
        end
      end

      def []=(key, value)
        @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "SET scope: #{@scope.inspect}, path: #{@path.inspect}, key: #{key.inspect}, value: #{value.inspect}, target_object_id: #{@target.object_id}" })
        actual_value = value.is_a?(SettingsProxy) ? @settings_module.unwrap_proxies(value) : value # Corrected to use @settings_module
        @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "SET   target_before_set: #{@target.inspect}" })
        @target[key] = actual_value
        @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "SET   target_after_set: #{@target.inspect}" })
        @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "SET   calling save_proxy_changes on settings module" })
        @settings_module.save_proxy_changes(self)
        value
      end

      def method_missing(method, *args, &block)
        @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "CALL scope: #{@scope.inspect}, path: #{@path.inspect}, method: #{method}, args: #{args.inspect}, target_object_id: #{@target.object_id}" })
        if @target.respond_to?(method)
          if NON_DESTRUCTIVE_METHODS.include?(method)
            @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "CALL   non-destructive method: #{method}" })
            target_dup = @target.dup
            unwrapped_args = args.map { |arg| arg.is_a?(SettingsProxy) ? @settings_module.unwrap_proxies(arg) : arg } # Corrected
            result = target_dup.send(method, *unwrapped_args, &block)
            return handle_non_destructive_result(result)
          else
            @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "CALL   destructive method: #{method}" })
            unwrapped_args = args.map { |arg| arg.is_a?(SettingsProxy) ? @settings_module.unwrap_proxies(arg) : arg } # Corrected
            @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "CALL   target_before_op: #{@target.inspect}" })
            result = @target.send(method, *unwrapped_args, &block)
            @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "CALL   target_after_op: #{@target.inspect}" })
            @settings_module._log(Settings::LOG_LEVEL_DEBUG, LOG_PREFIX, -> { "CALL   calling save_proxy_changes on settings module" })
            @settings_module.save_proxy_changes(self)
            return handle_method_result(result)
          end
        else
          super
        end
      end

      def handle_non_destructive_result(result)
        @settings_module.reset_path_and_return(
          if @settings_module.container?(result)
            SettingsProxy.new(@settings_module, @scope, [], result)
          else
            result
          end
        )
      end

      def handle_method_result(result)
        if result.equal?(@target)
          self # Return self if the method modified the target in-place and returned it
        elsif @settings_module.container?(result)
          # If a new container is returned (e.g. some destructive methods might return a new object)
          # Wrap it in a new proxy, maintaining the current path and scope.
          SettingsProxy.new(@settings_module, @scope, @path, result)
        else
          result
        end
      end

      def respond_to_missing?(method, include_private = false)
        @target.respond_to?(method, include_private) || super
      end
    end
  end
end
