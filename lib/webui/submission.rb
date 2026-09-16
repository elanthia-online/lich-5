# frozen_string_literal: true

require_relative 'sensitive_value'

module Lich
  module WebUI
    # Immutable viewer snapshot supplied to a submission callback.
    class Submission
      attr_reader :viewer_id

      def initialize(viewer_id:, values:)
        @viewer_id = viewer_id.freeze
        @values = values.freeze
        @committed = false
      end

      def [](cid)
        @values.fetch(cid.to_s)
      end

      def fetch(cid, &block)
        @values.fetch(cid.to_s, &block)
      end

      def cids
        @values.keys.freeze
      end

      def sensitive_cids
        @values.filter_map { |cid, value| cid if value.is_a?(SensitiveValue) }.freeze
      end

      def committed?
        @committed
      end

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
