# frozen_string_literal: true

require_relative 'contract'
require_relative 'value_helpers'

module Lich
  module WebUI
    # Immutable component in a validated neutral render tree.
    class Component
      attr_reader :type, :cid, :props, :children, :slot, :placement

      # Captures a validated tree node and freezes its immediate containers.
      # Validation and recursive property normalization belong to TreeBuilder.
      # @param type [Symbol] contract component type
      # @param cid [String] page-local component identifier
      # @param props [Hash] validated component properties
      # @param children [Array<Component>] ordered child nodes
      # @param slot [String, nil] named parent slot
      # @param placement [Hash] validated layout hints
      def initialize(type:, cid:, props:, children: [], slot: nil, placement: {})
        @type = type
        @cid = cid.freeze
        @props = props.freeze
        @children = children.freeze
        @slot = slot
        @placement = placement.freeze
        freeze
      end

      # Builds the wire representation, omitting sensitive input values at every level.
      # @return [Hash] serializable component tree
      def to_h
        serialized_props = props.reject do |name, _value|
          name == :value && sensitive_value?
        end
        result = { type: type.to_s, cid: cid, props: serialized_props, children: children.map(&:to_h) }
        result[:slot] = slot if slot
        result[:placement] = placement unless placement.empty?
        result
      end

      # Visits this node before its children, preserving child order.
      # @yield [component] each node in depth-first order
      # @yieldparam component [Component] visited node
      # @return [Enumerator] when no block is supplied
      def each(&block)
        return enum_for(:each) unless block

        yield self
        children.each { |child| child.each(&block) }
      end

      # Finds an exact component ID in depth-first order without coercing it.
      # Callers retain their own absent-component errors and ID normalization.
      # @param cid [String] component identifier to match
      # @return [Component, nil] first matching component, or nil
      def find(cid)
        each.find { |component| component.cid == cid }
      end

      private

      def sensitive_value?
        ValueHelpers.sensitive_value?(self)
      end
    end
  end
end
