# frozen_string_literal: true

require_relative '../webui'

module Lich
  # Script-facing entry points for the WebUI, each a thin forward to {Lich::WebUI}.
  module API
    # Registers a native WebUI page owned by the supplied core or script object.
    #
    # @param owner [Object] the script or core object that owns the page
    # @param id [String] page identifier matching the contract identifier syntax
    # @param title [String] window title
    # @param props [Hash{Symbol => Object}] root page properties
    # @param on [Hash{Symbol => #call}] page lifecycle callbacks keyed by event name
    # @yield the render block, evaluated against a {Lich::WebUI::TreeBuilder} on every render
    # @return [Lich::WebUI::Page] the registered page
    def self.webui_page(owner:, id:, title:, props: {}, on: {}, &render_block)
      Lich::WebUI.page(owner: owner, id: id, title: title, props: props, on: on, &render_block)
    end

    # Exposes the immutable machine-readable component schema to authors.
    #
    # @param type [Symbol, String] a contract component type
    # @return [Hash{Symbol => Object}] the frozen schema for that type
    # @raise [Lich::WebUI::UnknownTypeError] when the type is not in the contract
    def self.webui_schema(type)
      Lich::WebUI::Contract.schema(type)
    end

    # Returns the contract version implemented by the author API.
    #
    # @return [String] the contract version
    def self.webui_contract_version
      Lich::WebUI::Contract::VERSION
    end

    # Builds an adapter that renders on behalf of an owner.
    #
    # @param owner [Object] the script or core object the adapter acts for
    # @param viewer [String, nil] a viewer id to scope viewer-local reads and writes to
    # @param service [Lich::WebUI::Service] the service to render through
    # @return [Lich::WebUI::Adapter] the adapter
    def self.webui_adapter(owner:, viewer: nil, service: Lich::WebUI.service)
      Lich::WebUI::Adapter.new(owner: owner, viewer: viewer, service: service)
    end

    # Starts the loopback server.
    #
    # @return [Lich::WebUI::Service] the started service
    def self.webui_start
      Lich::WebUI.start
    end

    # A single-use authenticated URL for the launcher or one page.
    #
    # @param page [Lich::WebUI::Page, nil] the page to land on, or nil for the launcher
    # @return [String] the URL
    def self.webui_launch_url(page: nil)
      Lich::WebUI.launch_url(page: page)
    end

    # Opens a browser window on the launcher or one page.
    #
    # @param page [Lich::WebUI::Page, nil] the page to open, or nil for the launcher
    # @return [Boolean] whether a browser was opened
    def self.webui_open(page: nil)
      Lich::WebUI.open(page: page)
    end

    # Re-renders a page for every attached viewer.
    #
    # @param page [Lich::WebUI::Page] the page to re-render
    # @return [void]
    def self.webui_refresh(page)
      Lich::WebUI.refresh(page)
    end

    # Tears down everything an owner registered.
    #
    # @param owner [Object] the script or core object being torn down
    # @return [void]
    def self.webui_terminate_owner(owner)
      Lich::WebUI.terminate_owner(owner)
    end

    # Raises a modal dialog; see {Lich::WebUI::ModalCoordinator#open}.
    #
    # @param options [Hash{Symbol => Object}] the dialog options
    # @yield optional body content, evaluated against the dialog's {Lich::WebUI::TreeBuilder}
    # @return [Lich::WebUI::Future] resolves with the button pressed or the reason it closed
    def self.webui_modal(**options, &content)
      Lich::WebUI.modal(**options, &content)
    end
  end
end
