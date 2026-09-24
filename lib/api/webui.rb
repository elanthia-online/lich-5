# frozen_string_literal: true

require_relative '../webui'

module Lich
  module API
    # Registers a native WebUI page owned by the supplied core or script object.
    def self.webui_page(owner:, id:, title:, props: {}, on: {}, &render_block)
      Lich::WebUI.page(owner: owner, id: id, title: title, props: props, on: on, &render_block)
    end

    # Exposes the immutable machine-readable component schema to authors.
    def self.webui_schema(type)
      Lich::WebUI::Contract.schema(type)
    end

    # Returns the contract version implemented by the author API.
    def self.webui_contract_version
      Lich::WebUI::Contract::VERSION
    end

    def self.webui_adapter(owner:, viewer: nil, service: Lich::WebUI.service)
      Lich::WebUI::Adapter.new(owner: owner, viewer: viewer, service: service)
    end

    def self.webui_start
      Lich::WebUI.start
    end

    def self.webui_launch_url(page: nil)
      Lich::WebUI.launch_url(page: page)
    end

    def self.webui_open(page: nil)
      Lich::WebUI.open(page: page)
    end

    def self.webui_refresh(page)
      Lich::WebUI.refresh(page)
    end

    def self.webui_terminate_owner(owner)
      Lich::WebUI.terminate_owner(owner)
    end

    def self.webui_modal(**options, &content)
      Lich::WebUI.modal(**options, &content)
    end
  end
end
