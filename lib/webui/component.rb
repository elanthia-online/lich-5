# frozen_string_literal: true

require_relative 'contract'

module Lich
  module WebUI
    # Immutable component in a validated neutral render tree.
    class Component
      attr_reader :type, :cid, :props, :children, :slot, :placement

      def initialize(type:, cid:, props:, children: [], slot: nil, placement: {})
        @type = type
        @cid = cid.freeze
        @props = props.freeze
        @children = children.freeze
        @slot = slot
        @placement = placement.freeze
        freeze
      end

      def to_h
        serialized_props = props.reject do |name, _value|
          name == :value && sensitive_value?
        end
        result = { type: type.to_s, cid: cid, props: serialized_props, children: children.map(&:to_h) }
        result[:slot] = slot if slot
        result[:placement] = placement unless placement.empty?
        result
      end

      def each(&block)
        return enum_for(:each) unless block

        yield self
        children.each { |child| child.each(&block) }
      end

      private

      def sensitive_value?
        type == :password_input || props[:sensitive] == true
      end
    end
  end
end
