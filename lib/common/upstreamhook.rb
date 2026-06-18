# Carve out from lich.rbw
# UpstreamHook class 2024-06-13

require_relative 'hook_registry'

module Lich
  module Common
    class UpstreamHook
      extend HookRegistry

      @@upstream_hooks ||= Hash.new
      @@upstream_hook_sources ||= Hash.new
      @@upstream_hook_owners ||= Hash.new

      # Per-class storage for the shared HookRegistry methods.
      def self._hooks
        @@upstream_hooks
      end

      def self._hook_sources
        @@upstream_hook_sources
      end

      def self._hook_owners
        @@upstream_hook_owners
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
    end
  end
end
