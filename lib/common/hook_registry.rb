# frozen_string_literal: true

module Lich
  module Common
    # Shared behaviour for the down/upstream hook registries. DownstreamHook and
    # UpstreamHook are otherwise near-identical apart from their backing storage
    # and their per-direction +run+, so the registration/bookkeeping lives here
    # and a fix (e.g. to source tracking) lands in one place.
    #
    # An including class is +extend+ed with these as class methods and supplies
    # its own storage via +_hooks+ and +_hook_sources+, keeping its own +run+.
    module HookRegistry
      # Registers +action+ under +name+, recording the current script's name as
      # the source (used by {#sources} for display).
      #
      # @param name   [String]
      # @param action [Proc]
      # @return [Proc, false] the stored proc, or false if +action+ is not a Proc
      def add(name, action)
        unless action.is_a?(Proc)
          echo "#{hook_label}: not a Proc (#{action})"
          return false
        end
        _hook_sources[name] = (Script.current.name || "Unknown")
        _hooks[name] = action
      end

      # Removes the hook registered under +name+ from both maps.
      #
      # @param name [String]
      # @return [Proc, nil] the removed proc, if any
      def remove(name)
        _hook_sources.delete(name)
        _hooks.delete(name)
      end

      # Removes every hook whose recorded source equals +source+.
      #
      # @param source [String] the originating script name (Script#name)
      # @return [Integer] the number of hooks removed
      def remove_by_source(source)
        names = _hook_sources.select { |_name, src| src == source }.keys
        names.each { |name| remove(name) }
        names.size
      end

      # @return [Array<String>] a copy of the registered hook names
      def list
        _hooks.keys.dup
      end

      # Prints a Hook -> Source table via Lich::Messaging.
      # @return [void]
      def sources
        info_table = Terminal::Table.new :headings => ['Hook', 'Source'],
                                         :rows     => _hook_sources.to_a,
                                         :style    => { :all_separators => true }
        Lich::Messaging.mono(info_table.to_s)
      end

      # @return [Hash{String => String}] the live hook-name -> source map
      def hook_sources
        _hook_sources
      end

      private

      # Short class name (e.g. "DownstreamHook") for user-facing messages.
      # @return [String]
      def hook_label
        name.to_s.split('::').last
      end
    end
  end
end
