# Carve out from lich.rbw
# class DownstreamHook 2024-06-13

require_relative 'hook_registry'

module Lich
  module Common
    class DownstreamHook
      extend HookRegistry

      @@downstream_hooks ||= Hash.new
      @@downstream_hook_sources ||= Hash.new

      # Per-class storage for the shared HookRegistry methods.
      def self._hooks
        @@downstream_hooks
      end

      def self._hook_sources
        @@downstream_hook_sources
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
    end
  end
end
