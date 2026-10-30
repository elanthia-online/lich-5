# frozen_string_literal: true

module WebUISpecSupport
  # Opt-in bindings for examples that provide scope, owner and service helpers.
  # Consumers retain their own setup hooks, diagnostics and cleanup.
  module ShimBindings
    # Installs bindings at the caller's chosen point in its before hook.
    # Adapter and callback stubs resolve the example's service only when called.
    # @return [void]
    def install_webui_shim_bindings
      scope.activate!
      stub_const('Lich::Common::Script', Class.new { def self.current; end })
      allow(Lich::Common::Script).to receive(:current).and_return(owner)
      allow(Lich::WebUI).to receive(:adapter) { |owner:, viewer: nil| Lich::WebUI::Adapter.new(owner: owner, service: service, viewer: viewer) }
      allow(Lich::WebUI).to receive(:callback_queue) { |owner:| proc { |&work| service.runtime.dispatch(owner: owner, &work) } }
    end
  end
end
