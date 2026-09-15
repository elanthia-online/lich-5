# frozen_string_literal: true

module Lich
  module Common
    # Shared behaviour for the down/upstream hook registries. DownstreamHook and
    # UpstreamHook are otherwise near-identical apart from their backing storage
    # and their per-direction +run+, so the registration/bookkeeping lives here
    # and a fix (e.g. to source tracking) lands in one place.
    #
    # An including class is +extend+ed with these as class methods and supplies
    # its own storage via +_hooks+, +_hook_sources+, +_hook_owners+,
    # +_hook_persist+ and +_hook_priorities+, keeping its own +run+.
    module HookRegistry
      # Initialize each registry's lock before it accepts registrations. Keep
      # the same lock if the registry is extended again during a reload.
      # @param registry [Class] the extending hook registry
      # @return [void]
      def self.extended(registry)
        registry.instance_variable_set(:@hook_mutex, Mutex.new) unless registry.instance_variable_defined?(:@hook_mutex)
      end

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
      # Higher-priority hooks run first. Hooks with equal priority retain their
      # registration order, preserving historical behaviour at the default of
      # zero. A named replacement keeps its original equal-priority position.
      #
      # @param name    [String]
      # @param action  [Proc]
      # @param persist  [Boolean, nil] hook lifetime relative to the script
      # @param priority [Numeric] execution priority; higher values run first
      # @return [Proc, false] the stored proc, or false if +action+ is not a Proc
      def add(name, action, persist: nil, priority: 0)
        unless action.is_a?(Proc)
          echo "#{hook_label}: not a Proc (#{action})"
          return false
        end
        unless priority.is_a?(Numeric) && priority.real? &&
               (!priority.respond_to?(:finite?) || priority.finite?)
          echo "#{hook_label}: priority must be a finite real Numeric (#{priority.inspect})"
          return false
        end
        script = Script.current
        @hook_mutex.synchronize do
          _hook_sources[name] = (script&.name || "Unknown")
          _hook_owners[name]  = script&.object_id
          _hook_persist[name] = persist
          _hook_priorities[name] = priority
          _hooks[name] = action
        end
        action
      end

      # Removes the hook registered under +name+ from every map.
      #
      # @param name [String]
      # @return [Proc, nil] the removed proc, if any
      def remove(name)
        @hook_mutex.synchronize { remove_hook(name) }
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
        removed    = 0
        undeclared = []
        @hook_mutex.synchronize do
          owned = _hook_owners.select { |_name, owner| owner == owner_id }.keys
          owned.each do |name|
            case _hook_persist[name]
            when false then (remove_hook(name); removed += 1)
            when true  then next
            else undeclared << name
            end
          end
        end
        warn_undeclared(undeclared)
        removed
      end

      # @return [Array<String>] a copy of the registered hook names
      def list
        @hook_mutex.synchronize { _hooks.keys }
      end

      # Prints a Hook -> Source table via Lich::Messaging.
      # @return [void]
      def sources
        rows = @hook_mutex.synchronize { _hook_sources.to_a }
        info_table = Terminal::Table.new :headings => ['Hook', 'Source'],
                                         :rows     => rows,
                                         :style    => { :all_separators => true }
        Lich::Messaging.mono(info_table.to_s)
      end

      # @return [Hash{String => String}] the live hook-name -> source map
      def hook_sources
        _hook_sources
      end

      # Snapshot names and priorities together with registration/removal excluded.
      # There is no order cache: legacy direct edits to the live maps are visible
      # on the next dispatch, but bypass synchronization; use add/remove for
      # concurrent mutations. Sorting and callbacks run outside the lock.
      #
      # New names and priority changes take effect on the next dispatch. Actions
      # are read live before invocation: removed names are skipped, and a name
      # replaced before its turn runs the new action at its old position for this
      # pass, preserving historical replacement behaviour.
      # @return [Array<String>]
      def ordered_hook_names
        entries = @hook_mutex.synchronize do
          _hooks.keys.each_with_index.map { |name, index| [name, _hook_priorities.fetch(name, 0), index] }
        end
        entries.sort_by { |_name, priority, index| [-priority, index] }.map(&:first)
      end

      private

      # @param name [String] registered hook name
      # @return [Proc, nil] the current action; callers invoke it outside the lock
      def hook_action(name)
        @hook_mutex.synchronize { _hooks[name] }
      end

      # Caller holds the registry lock so lifecycle cleanup cannot remove a
      # replacement registered by another owner partway through cleanup.
      # @param name [String] registered hook name
      # @return [Proc, nil] the removed action
      def remove_hook(name)
        _hook_sources.delete(name)
        _hook_owners.delete(name)
        _hook_persist.delete(name)
        _hook_priorities.delete(name)
        _hooks.delete(name)
      end

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
