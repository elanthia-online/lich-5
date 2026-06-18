# Carve out from lich.rbw
# UpstreamHook class 2024-06-13

module Lich
  module Common
    class UpstreamHook
      @@upstream_hooks ||= Hash.new
      @@upstream_hook_sources ||= Hash.new

      def UpstreamHook.add(name, action)
        unless action.is_a?(Proc)
          echo "UpstreamHook: not a Proc (#{action})"
          return false
        end
        @@upstream_hook_sources[name] = (Script.current.name || "Unknown")
        @@upstream_hooks[name] = action
      end

      def UpstreamHook.run(client_string)
        for key in @@upstream_hooks.keys
          begin
            client_string = @@upstream_hooks[key].call(client_string)
          rescue
            @@upstream_hooks.delete(key)
            respond "--- Lich: UpstreamHook: #{$!}"
            respond $!.backtrace.first
          end
          return nil if client_string.nil?
        end
        return client_string
      end

      def UpstreamHook.remove(name)
        @@upstream_hook_sources.delete(name)
        @@upstream_hooks.delete(name)
      end

      # Removes every hook registered by the named script. Called from the
      # script kill path so a script that exits without removing its own hooks
      # does not leak them. Each hook proc lives in this global registry and
      # captures the registering script's binding, so an orphaned hook keeps the
      # entire dead script reachable and unreclaimable. Idempotent - a no-op for
      # scripts that already removed their hooks in a before_dying block.
      #
      # @param source [String] the originating script name (Script#name)
      # @return [Integer] the number of hooks removed
      def UpstreamHook.remove_by_source(source)
        names = @@upstream_hook_sources.select { |_name, src| src == source }.keys
        names.each { |name| remove(name) }
        names.size
      end

      def UpstreamHook.list
        @@upstream_hooks.keys.dup
      end

      def UpstreamHook.sources
        info_table = Terminal::Table.new :headings => ['Hook', 'Source'],
                                         :rows     => @@upstream_hook_sources.to_a,
                                         :style    => { :all_separators => true }
        Lich::Messaging.mono(info_table.to_s)
      end

      def UpstreamHook.hook_sources
        @@upstream_hook_sources
      end
    end
  end
end
