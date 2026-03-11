# Carve out from lich.rbw
# class DownstreamHook 2024-06-13

module Lich
  module Common
    class DownstreamHook
      @@downstream_hooks ||= Hash.new
      @@downstream_hook_sources ||= Hash.new

      def DownstreamHook.add(name, action)
        unless action.is_a?(Proc)
          echo "DownstreamHook: not a Proc (#{action})"
          return false
        end
        @@downstream_hook_sources[name] = (Script.current.name || "Unknown")
        @@downstream_hooks[name] = action
      end

      def DownstreamHook.run(server_string)
        for key in @@downstream_hooks.keys
          return nil if server_string.nil?
          begin
            server_string = @@downstream_hooks[key].call(server_string.dup) if server_string.is_a?(String)
          rescue
            @@downstream_hooks.delete(key)
            respond "--- Lich: DownstreamHook: #{$!}"
            respond $!.backtrace.first
          end
        end
        return server_string
      end

      def DownstreamHook.remove(name)
        @@downstream_hook_sources.delete(name)
        @@downstream_hooks.delete(name)
      end

      def DownstreamHook.list
        @@downstream_hooks.keys.dup
      end

      def DownstreamHook.sources
        info_table = Terminal::Table.new :headings => ['Hook', 'Source'],
                                         :rows     => @@downstream_hook_sources.to_a,
                                         :style    => { :all_separators => true }
        Lich::Messaging.mono(info_table.to_s)
      end

      def DownstreamHook.hook_sources
        @@downstream_hook_sources
      end
    end
  end
end
