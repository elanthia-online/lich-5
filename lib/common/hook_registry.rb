# frozen_string_literal: true

module Lich
  module Common
    # Shared behaviour for the down/upstream hook registries. DownstreamHook and
    # UpstreamHook are otherwise near-identical apart from their backing storage
    # and their per-direction +run+, so the registration/bookkeeping lives here
    # and a fix (e.g. to source tracking) lands in one place.
    #
    # An including class is +extend+ed with these as class methods and supplies
    # its own storage via +_hooks+, +_hook_sources+ and +_hook_owners+, keeping
    # its own +run+.
    module HookRegistry
      # Registers +action+ under +name+, recording the current script's name as
      # the source (used by {#sources} for display) and its object_id as the
      # owner (used by {#remove_by_owner} for cleanup on script death).
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
        _hook_owners[name]  = Script.current.object_id
        _hooks[name] = action
      end

      # Removes the hook registered under +name+ from every map.
      #
      # @param name [String]
      # @return [Proc, nil] the removed proc, if any
      def remove(name)
        _hook_sources.delete(name)
        _hook_owners.delete(name)
        _hooks.delete(name)
      end

      # Removes every hook owned by the given script, identified by its
      # object_id rather than its name. Two scripts started with +force: true+
      # can share a name, so name-based removal would tear out a still-running
      # sibling's hooks; object_id is unique per instance.
      #
      # @param owner_id [Integer] the owning script's +object_id+
      # @return [Integer] the number of hooks removed
      def remove_by_owner(owner_id)
        names = _hook_owners.select { |_name, owner| owner == owner_id }.keys
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
