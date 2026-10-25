# frozen_string_literal: true

require_relative 'sensitive_value'

module Lich
  module WebUI
    # Immutable viewer snapshot supplied to a submission callback.
    class Submission
      attr_reader :viewer_id, :input_changes

      # Captures a viewer submission whose sensitive carriers remain explicitly disposable.
      # @param viewer_id [String] originating viewer
      # @param values [Hash] component IDs mapped to validated values or sensitive carriers
      # @param input_changes [Array<Component>] nonsensitive inputs changed by
      #   this submission, compared with the previously accepted viewer state
      def initialize(viewer_id:, values:, input_changes: [])
        @viewer_id = viewer_id.freeze
        @values = values.freeze
        @input_changes = input_changes.dup.freeze
        @committed = false
      end

      # Fetches a submitted component value using its string ID.
      # @return [Object] submitted value
      # @raise [KeyError] if the component was not included
      def [](cid)
        @values.fetch(cid.to_s)
      end

      # Fetches a submitted value, optionally yielding a missing ID to a fallback block.
      # Positional default arguments are not supported.
      # @param cid [#to_s] submitted component ID
      # @yield [missing_cid] fallback when the ID is absent
      # @yieldparam missing_cid [String] missing component ID
      # @return [Object] submitted value or fallback block result
      # @raise [KeyError] if the ID is absent and no block is supplied
      def fetch(cid, &block)
        @values.fetch(cid.to_s, &block)
      end

      # Lists submitted component IDs in submission order.
      # @return [Array<String>] frozen ID list
      def cids
        @values.keys.freeze
      end

      # Lists component IDs whose submitted values use sensitive carriers.
      # @return [Array<String>] frozen ID list
      def sensitive_cids
        @values.filter_map { |cid, value| cid if value.is_a?(SensitiveValue) }.freeze
      end

      # Disposes any unused sensitive carriers; safe after normal consumption as well.
      # @return [nil]
      def discard_sensitive!
        @values.each_value { |value| value.discard! if value.is_a?(SensitiveValue) }
        nil
      end

      # Explicitly hands non-sensitive snapshot values to author-owned domain mutation code.
      # Sensitive carriers remain carriers and are not converted by this method.
      def commit
        raise ArgumentError, 'commit requires a block' unless block_given?
        raise Error, 'submission snapshot has already been committed' if @committed

        @committed = true
        yield @values.dup.freeze
      end
    end
  end
end
