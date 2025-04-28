module Lich
  module Common
    # This module provides a proxy class for settings objects, allowing them to be accessed
    # in a Ruby-compatible way. It handles both scalar and container types, and
    # provides methods for comparison, conversion, and enumeration.
    #
    # The proxy is designed to work with settings objects that are either Hashes or Arrays.
    # It allows for nested access to settings, while also providing a way to save changes
    # made to the settings.

    # The proxy also provides a way to handle non-destructive methods, which return a new
    # object instead of modifying the original. This is done by creating a duplicate of the
    # target object before calling the method, and then returning a new proxy for the result
    # if it is a container type.

    # The proxy also handles method delegation, allowing methods to be called directly on
    # the target object. It uses method_missing to catch calls to methods that are not
    # defined on the proxy itself, and delegates them to the target object.

    # The proxy also provides a way to handle results of non-destructive methods, which
    # return a new object instead of modifying the original. This is done by creating a
    # duplicate of the target object before calling the method, and then returning a new
    # proxy for the result if it is a container type.

    class SettingsProxy
      def initialize(settings, path, target)
        @settings = settings
        @path = path.dup
        @target = target
      end

      # Allow access to the target for debugging
      attr_reader :target, :path

      #
      # Standard Ruby methods
      #

      def nil?
        @target.nil?
      end

      # Helper method for binary operators to reduce repetition
      def binary_op(operator, other)
        other_value = other.is_a?(SettingsProxy) ? other.target : other
        @target.send(operator, other_value)
      end

      # Define comparison operators using metaprogramming to reduce repetition
      # NB: not all operators apply to all objects (e.g. <, >, <=, >= on Arrays)
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

      def inspect
        @target.inspect
      end

      def pretty_print(pp)
        pp.pp(@target)
      end

      #
      # Type checking methods
      #

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

      #
      # Conversion methods
      #

      def to_hash
        return nil unless @target.is_a?(Hash)

        @target.dup
      end

      def to_h
        to_hash
      end

      def to_ary
        return nil unless @target.is_a?(Array)

        @target.dup
      end

      def to_a
        to_ary
      end

      # Define conversion methods using metaprogramming to reduce repetition
      [:to_int, :to_i, :to_str, :to_sym, :to_proc].each do |method|
        define_method(method) do
          @target.send(method) if @target.respond_to?(method)
        end
      end

      #
      # Enumerable support
      #

      def each(&_block)
        return enum_for(:each) unless block_given?

        if @target.respond_to?(:each)
          @target.each do |item|
            if Settings.container?(item)
              yield SettingsProxy.new(@settings, [], item)
            else
              yield item
            end
          end
        end

        self
      end

      # Non-destructive enumerable methods that should not save changes
      NON_DESTRUCTIVE_METHODS = [
        :select, :map, :filter, :reject, :collect, :find, :detect,
        :find_all, :grep, :grep_v, :group_by, :partition, :min, :max,
        :minmax, :min_by, :max_by, :minmax_by, :sort, :sort_by,
        :flat_map, :collect_concat, :reduce, :inject, :sum, :count,
        :cycle, :drop, :drop_while, :take, :take_while, :first, :all?,
        :any?, :none?, :one?, :find_index, :values_at, :zip, :reverse,
        :entries, :to_a, :to_h, :include?, :member?, :each_with_index,
        :each_with_object, :each_entry, :each_slice, :each_cons, :chunk,
        :slice_before, :slice_after, :slice_when, :chunk_while, :lazy
      ].freeze

      #
      # Container access
      #

      def [](key)
        value = @target[key]

        if Settings.container?(value)
          # For container types, return a new proxy with updated path
          new_path = @path.dup
          new_path << key
          SettingsProxy.new(@settings, new_path, value)
        else
          # For scalar values, return the value directly
          value
        end
      end

      def []=(key, value)
        @target[key] = value
        @settings.save_proxy_changes(self)
        # value
      end

      #
      # Method delegation
      #

      def method_missing(method, *args, &block)
        if @target.respond_to?(method)
          # For non-destructive methods, operate on a duplicate to avoid modifying original
          if NON_DESTRUCTIVE_METHODS.include?(method)
            # Create a duplicate of the target for non-destructive operations
            target_dup = @target.dup
            result = target_dup.send(method, *args, &block)

            # Return the result without saving changes
            return handle_non_destructive_result(result)
          else
            # For destructive methods, operate on the original and save changes
            result = @target.send(method, *args, &block)
            @settings.save_proxy_changes(self)
            return handle_method_result(result)
          end
        else
          super
        end
      end

      # Helper method to handle results of non-destructive methods
      def handle_non_destructive_result(result)
        # No need to capture path since we're using empty path
        @settings.reset_path_and_return(
          if Settings.container?(result)
            # For container results, wrap in a new proxy with empty path
            SettingsProxy.new(@settings, [], result)
          else
            # For scalar results, return directly
            result
          end
        )
      end

      # Helper method to handle results of destructive methods
      def handle_method_result(result)
        if result.equal?(@target)
          # If result is the original target, return self
          self
        elsif Settings.container?(result)
          # For container results, wrap in a new proxy with current path
          SettingsProxy.new(@settings, @path, result)
        else
          # For scalar results, return directly
          result
        end
      end

      def respond_to_missing?(method, include_private = false)
        @target.respond_to?(method, include_private) || super
      end
    end
  end
end
