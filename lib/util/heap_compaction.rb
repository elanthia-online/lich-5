# frozen_string_literal: true

module Lich
  module Util
    # Process-wide entry point for heap compaction.
    #
    # MemoryReleaser and Combat::AsyncProcessor call {compact!} instead of
    # GC.compact so that core never has to know which runtime is loaded. By
    # default this is a plain GC.compact (when the Ruby supports it). A
    # runtime that needs compaction guarded -- the GTK stack, see
    # lib/util/gtk_compaction.rb -- installs a strategy when it is required,
    # and every later compaction goes through it.
    module HeapCompaction
      class << self
        # Replaces the compaction strategy.
        #
        # @param value [#call, nil] runs one compaction; nil restores GC.compact
        attr_writer :strategy

        # @return [#call, nil] the installed strategy, or nil for GC.compact
        def strategy
          defined?(@strategy) ? @strategy : nil
        end

        # Compacts the heap through the installed strategy.
        #
        # @return [Object, nil] the strategy's result, or nil when the Ruby
        #   cannot compact
        def compact!
          return unless GC.respond_to?(:compact)

          installed = strategy
          installed ? installed.call : GC.compact
        end
      end
    end
  end
end
