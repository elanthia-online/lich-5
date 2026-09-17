# frozen_string_literal: true

require_relative 'contract'

module Lich
  module WebUI
    # Immutable component in a validated neutral render tree.
    #
    # A {TreeBuilder} materializes one of these per drafted component once the
    # whole page has validated; the runtime and {ViewerStore} then read them
    # without further checks.
    class Component
      # @!attribute [r] type
      #   @return [Symbol] the contract component type
      # @!attribute [r] cid
      #   @return [String] the component identity, `parent-cid/type:segment`
      # @!attribute [r] props
      #   @return [Hash{Symbol => Object}] validated, frozen properties
      # @!attribute [r] children
      #   @return [Array<Component>] frozen child components
      # @!attribute [r] slot
      #   @return [String, nil] the named slot this component fills in its parent
      # @!attribute [r] placement
      #   @return [Hash{Symbol => Object}] frozen parent-defined placement properties
      attr_reader :type, :cid, :props, :children, :slot, :placement

      # Builds and freezes a component.
      #
      # @param type [Symbol] the contract component type
      # @param cid [String] the component identity
      # @param props [Hash{Symbol => Object}] validated properties
      # @param children [Array<Component>] child components
      # @param slot [String, nil] the named slot this component fills
      # @param placement [Hash{Symbol => Object}] parent-defined placement properties
      # @return [Component] the frozen component
      def initialize(type:, cid:, props:, children: [], slot: nil, placement: {})
        @type = type
        @cid = cid.freeze
        @props = props.freeze
        @children = children.freeze
        @slot = slot
        @placement = placement.freeze
        freeze
      end

      # The wire form of this subtree, with a sensitive `value` left out.
      #
      # @return [Hash{Symbol => Object}] `type`, `cid`, `props`, `children`, and `slot`/`placement` when set
      def to_h
        serialized_props = props.reject do |name, _value|
          name == :value && sensitive_value?
        end
        result = { type: type.to_s, cid: cid, props: serialized_props, children: children.map(&:to_h) }
        result[:slot] = slot if slot
        result[:placement] = placement unless placement.empty?
        result
      end

      # Walks this component and every descendant, depth first.
      #
      # @yield [component] each component in the subtree, self first
      # @yieldparam component [Component]
      # @return [Enumerator, void] an enumerator when no block is given
      def each(&block)
        return enum_for(:each) unless block

        yield self
        children.each { |child| child.each(&block) }
      end

      private

      # Whether the `value` property must never leave the server.
      # @api private
      def sensitive_value?
        type == :password_input || props[:sensitive] == true
      end
    end
  end
end
