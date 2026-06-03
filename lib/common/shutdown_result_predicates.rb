# frozen_string_literal: true

module Lich
  module Common
    # Shared predicates for shutdown result structs.
    module ShutdownResultPredicates
      # @return [Boolean] whether every required shutdown step completed
      def completed?
        completed
      end

      # @return [Boolean] whether any shutdown step raised
      def failed?
        !failures.empty?
      end

      # @return [Boolean] whether script shutdown ran and left no registered scripts
      def scripts_drained?
        scripts_drained
      end

      # @return [Boolean] whether local script settings were saved
      def vars_saved?
        vars_saved
      end
    end
  end
end
