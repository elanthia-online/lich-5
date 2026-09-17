# frozen_string_literal: true

require_relative 'sensitive_value'

module Lich
  module WebUI
    # Immutable viewer snapshot supplied to a submission callback.
    #
    # The runtime builds one from the viewer's current values for the cids a
    # terminal component named in its `submit:` scope. Sensitive inputs arrive
    # as {SensitiveValue} carriers; everything else is the plain value.
    class Submission
      # @return [String] the viewer whose values these are
      attr_reader :viewer_id

      # Builds a snapshot.
      #
      # @param viewer_id [String] the submitting viewer
      # @param values [Hash{String => Object}] values keyed by cid
      # @return [Submission] the snapshot
      def initialize(viewer_id:, values:)
        @viewer_id = viewer_id.freeze
        @values = values.freeze
        @committed = false
      end

      # The value submitted for one cid.
      #
      # @param cid [String, #to_s] the input's component identity
      # @return [Object, SensitiveValue] the value
      # @raise [KeyError] when the cid was not part of the submission
      def [](cid)
        @values.fetch(cid.to_s)
      end

      # The value submitted for one cid, with a block for a missing one.
      #
      # @param cid [String, #to_s] the input's component identity
      # @yield [cid] when the cid was not part of the submission
      # @return [Object, SensitiveValue] the value, or the block's result
      # @raise [KeyError] when the cid is missing and no block is given
      def fetch(cid, &block)
        @values.fetch(cid.to_s, &block)
      end

      # Every cid in the snapshot.
      #
      # @return [Array<String>] the cids
      def cids
        @values.keys.freeze
      end

      # The cids whose values are sensitive carriers.
      #
      # @return [Array<String>] the sensitive cids
      def sensitive_cids
        @values.filter_map { |cid, value| cid if value.is_a?(SensitiveValue) }.freeze
      end

      # Whether {#commit} has already run.
      #
      # @return [Boolean]
      def committed?
        @committed
      end

      # Discards every sensitive carrier that has not been consumed.
      #
      # @return [nil]
      def discard_sensitive!
        @values.each_value { |value| value.discard! if value.is_a?(SensitiveValue) }
        nil
      end

      # Explicitly hands non-sensitive snapshot values to author-owned domain mutation code.
      # Sensitive carriers remain carriers and are not converted by this method.
      #
      # @yield [values] once, with a frozen copy of the snapshot
      # @yieldparam values [Hash{String => Object}] values keyed by cid
      # @return [Object] the block's result
      # @raise [ArgumentError] when no block is given
      # @raise [Error] when the snapshot has already been committed
      def commit
        raise ArgumentError, 'commit requires a block' unless block_given?
        raise Error, 'submission snapshot has already been committed' if @committed

        @committed = true
        yield @values.dup.freeze
      end
    end
  end
end
