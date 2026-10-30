# frozen_string_literal: true

require_relative '../webui'

module Lich
  module API
    # Registers a native WebUI page owned by the supplied core or script object.
    # Registration does not render or open a window. Render the page, start the
    # host, then open it; the owner remains responsible for its domain behavior.
    #
    # @param owner [Object] lifetime identity used for page cleanup
    # @param id [String] page identifier unique within this owner
    # @param title [String] window title
    # @param props [Hash] page properties from the component contract
    # @param on [Hash{Symbol => Proc}] page lifecycle callbacks
    # @yieldparam builder [Lich::WebUI::TreeBuilder] component authoring context
    # @return [Lich::WebUI::Page] registered page bound to the current runtime
    # @see Lich::WebUI.page
    def self.webui_page(owner:, id:, title:, props: {}, on: {}, &render_block)
      Lich::WebUI.page(owner: owner, id: id, title: title, props: props, on: on, &render_block)
    end

    # Exposes the immutable machine-readable component schema to authors.
    #
    # @param type [Symbol, String] component type in the bounded contract
    # @return [Hash] property, event, and child rules for the component
    # @raise [Lich::WebUI::UnknownTypeError] if the type is unsupported
    def self.webui_schema(type)
      Lich::WebUI::Contract.schema(type)
    end

    # Returns the contract version implemented by the author API.
    # @return [String] semantic contract version
    def self.webui_contract_version
      Lich::WebUI::Contract::VERSION
    end

    # Creates a hosted imperative adapter; its first valid page render opens
    # the window automatically. Consumers must not create their own server.
    #
    # @param owner [Object] lifetime identity used for adapter page cleanup
    # @param viewer [String, nil] attachment id for viewer-local properties;
    #   reads require viewer attribution. Before publication, unattributed writes
    #   initialize defaults; after publication, writes require an explicit viewer
    #   or the originating callback's viewer context
    # @return [Lich::WebUI::Adapter] bounded component adapter
    def self.webui_adapter(owner:, viewer: nil)
      Lich::WebUI.adapter(owner: owner, viewer: viewer)
    end

    # Starts the shared loopback host, or returns the already running host.
    # @return [Lich::WebUI::Service] active service
    def self.webui_start
      Lich::WebUI.start
    end

    # Issues a short-lived, single-use authentication URL. Start the host first.
    # The URL grants local UI access; do not persist it or include it in logs.
    #
    # @param page [Lich::WebUI::Page, nil] registered page, or the page selector
    # @return [String] authenticated loopback launch URL
    # @raise [Lich::WebUI::Error] if the host is not running or the page is unknown
    def self.webui_launch_url(page: nil)
      Lich::WebUI.launch_url(page: page)
    end

    # Opens a browser app window. Render the page and start the host first.
    # Reopening an already owned page reuses its existing window.
    #
    # @param page [Lich::WebUI::Page, nil] registered page, or the page selector
    # @return [Boolean] whether opening succeeded or the page was already open
    def self.webui_open(page: nil)
      Lich::WebUI.open(page: page)
    end

    # Renders current server state and delivers it to connected page viewers.
    # @param page [Lich::WebUI::Page] page whose render block should run
    # @return [Integer] generated revision; concurrent work may deliver a newer one
    def self.webui_refresh(page)
      Lich::WebUI.refresh(page)
    end

    # Cancels the owner's modal work, revokes file access, and removes its pages.
    # @param owner [Object] same lifetime identity used when creating pages
    # @return [Array<Lich::WebUI::Page>] pages removed from the registry
    def self.webui_terminate_owner(owner)
      Lich::WebUI.terminate_owner(owner)
    end

    # Requests a modal without blocking a WebUI callback. The caller must choose
    # a no-viewer policy; completion may represent a response or cancellation.
    #
    # @param options [Hash] keywords accepted by ModalCoordinator#open
    # @param content [Proc, nil] optional dialog content builder
    # @return [Lich::WebUI::Future] single-assignment modal completion
    # @see Lich::WebUI::ModalCoordinator#open
    def self.webui_modal(**options, &content)
      Lich::WebUI.modal(**options, &content)
    end
  end
end
