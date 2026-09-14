# frozen_string_literal: true

module Lich
  module Common
    # Shared behaviour for the down/upstream hook registries. DownstreamHook and
    # UpstreamHook are otherwise near-identical apart from their backing storage
    # and their per-direction +run+, so the registration/bookkeeping lives here
    # and a fix (e.g. to source tracking) lands in one place.
    #
    # An including class is +extend+ed with these as class methods and supplies
    # its own storage via +_hooks+, +_hook_sources+, +_hook_owners+ and
    # +_hook_persist+, keeping its own +run+.
    module HookRegistry
      # Registers +action+ under +name+, recording the current script's name as
      # the source (used by {#sources} for display), its object_id as the owner,
      # and the declared +persist+ disposition (used by {#cleanup_on_death}).
      #
      # +persist+ declares what should happen to the hook when the registering
      # script dies:
      #   * +true+  - keep it (it is meant to outlive the script, e.g. ;alias)
      #   * +false+ - remove it (it is scoped to this script's lifetime)
      #   * +nil+   - undeclared: kept for backwards compatibility, but the death
      #               path warns once so the author can declare intent.
      #
      # @param name    [String]
      # @param action  [Proc]
      # @param persist [Boolean, nil] hook lifetime relative to the script
      # @return [Proc, false] the stored proc, or false if +action+ is not a Proc
      def add(name, action, persist: nil)
        unless action.is_a?(Proc)
          echo "#{hook_label}: not a Proc (#{action})"
          return false
        end
        _hook_sources[name] = (Script.current&.name || "Unknown")
        _hook_owners[name]  = Script.current&.object_id
        _hook_persist[name] = persist
        _hooks[name] = action
      end

      # Removes the hook registered under +name+ from every map.
      #
      # @param name [String]
      # @return [Proc, nil] the removed proc, if any
      def remove(name)
        _hook_sources.delete(name)
        _hook_owners.delete(name)
        _hook_persist.delete(name)
        _hooks.delete(name)
      end

      # Invoked from the {ScriptDeath} handler when a script dies. For each hook
      # the script registered (matched by object_id, so a +force: true+ sibling
      # sharing its name is unaffected), removes the ones explicitly scoped to
      # the script (+persist: false+), keeps explicitly persistent ones
      # (+persist: true+), and leaves undeclared ones in place but warns once so
      # the author can declare intent. Default behaviour is therefore unchanged
      # (hooks persist) until a script opts in to +persist: false+.
      #
      # @param owner_id [Integer] the dying script's +object_id+
      # @return [Integer] the number of hooks removed
      def cleanup_on_death(owner_id)
        owned = _hook_owners.select { |_name, owner| owner == owner_id }.keys
        return 0 if owned.empty?

        removed    = 0
        undeclared = []
        owned.each do |name|
          case _hook_persist[name]
          when false then (remove(name); removed += 1)
          when true  then next
          else undeclared << name
          end
        end
        warn_undeclared(undeclared)
        removed
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

      # Warns (once per hook name per session) that a script left a hook
      # registered without declaring +persist:+. Surfaces accidental leaks
      # without removing anything, so a careless script is visible while
      # intentional persistent hooks keep working.
      #
      # @param names [Array<String>] undeclared hook names left by a dead script
      # @return [void]
      def warn_undeclared(names)
        fresh = names.reject { |n| warned_undeclared.key?(n) }
        return if fresh.empty?

        fresh.each { |n| warned_undeclared[n] = true }
        msg = "#{hook_label}: a script exited leaving #{fresh.size} hook(s) registered " \
              "without declaring intent (#{fresh.join(', ')}). Pass persist: true to keep " \
              "them past script exit, or persist: false (or remove them in a before_dying " \
              "block) to have them cleaned up automatically."
        Lich.log("warning: #{msg}") if defined?(Lich) && Lich.respond_to?(:log)
        respond("--- Lich: #{msg}")
      end

      # Hook names already warned about this session (used as a set), so a script
      # that runs repeatedly does not warn every time.
      # @return [Hash{String => true}]
      def warned_undeclared
        @warned_undeclared ||= {}
      end

      # Short class name (e.g. "DownstreamHook") for user-facing messages.
      # @return [String]
      def hook_label
        name.to_s.split('::').last
      end
    end
  end
end
