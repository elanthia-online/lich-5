# frozen_string_literal: true

require_relative 'page'
require 'securerandom'

module Lich
  module WebUI
    # Server-owned page registry. Owner identity is never accepted from wire input.
    #
    # Pages are keyed by owner identity and page id on the Ruby side, and by
    # an opaque random address on the wire, so a client can name a page
    # without learning or forging who owns it.
    class Registry
      # Builds an empty registry.
      #
      # @return [Registry] the registry
      def initialize
        @pages = {}
        @addresses = {}
        @page_addresses = {}.compare_by_identity
        @mutex = Mutex.new
      end

      # Adds a page and assigns it a wire address.
      #
      # @param page [Page] the page to register
      # @return [Page] the same page
      # @raise [ArgumentError] when +page+ is not a {Page}
      # @raise [DuplicatePageError] when the owner already has a page with this id
      def register(page)
        raise ArgumentError, 'page must be a WebUI::Page' unless page.is_a?(Page)

        key = registry_key(page.owner, page.id)
        @mutex.synchronize do
          if @pages.key?(key)
            raise DuplicatePageError.new(
              "page id #{page.id.inspect} is already registered for owner",
              owner: owner_label(page.owner), page_id: page.id
            )
          end
          @pages[key] = page
          address = "page-#{SecureRandom.hex(16)}"
          @addresses[address] = page
          @page_addresses[page] = address
        end
        page
      end

      # Looks a page up by owner and id.
      #
      # @param owner [Object] the page's owner
      # @param page_id [String, #to_s] the page id
      # @return [Page] the page
      # @raise [Error] when no such page is registered
      def fetch(owner, page_id)
        @mutex.synchronize { @pages.fetch(registry_key(owner, page_id)) }
      rescue KeyError
        raise Error.new('page is not registered', owner: owner_label(owner), page_id: page_id)
      end

      # Removes one page and its address.
      #
      # @param owner [Object] the page's owner
      # @param page_id [String, #to_s] the page id
      # @return [Page, nil] the removed page, or nil when none was registered
      def unregister(owner, page_id)
        @mutex.synchronize do
          page = @pages.delete(registry_key(owner, page_id))
          remove_address(page)
          page
        end
      end

      # Removes every page an owner registered.
      #
      # @param owner [Object] the owner
      # @return [Array<Page>] the removed pages
      def unregister_owner(owner)
        owner_identity = owner.object_id
        @mutex.synchronize do
          removed = @pages.select { |(identity, _page_id), _page| identity == owner_identity }.values
          @pages.delete_if { |(identity, _page_id), _page| identity == owner_identity }
          removed.each { |page| remove_address(page) }
          removed
        end
      end

      # Every page an owner has registered.
      #
      # @param owner [Object] the owner
      # @return [Array<Page>] the owner's pages
      def pages_for(owner)
        owner_identity = owner.object_id
        @mutex.synchronize do
          @pages.filter_map { |(identity, _page_id), page| page if identity == owner_identity }
        end
      end

      # How many pages are registered.
      #
      # @return [Integer]
      def size
        @mutex.synchronize { @pages.size }
      end

      # The wire address of a registered page.
      #
      # @param page [Page] the page
      # @return [String] the opaque address
      # @raise [Error] when the page is not registered
      def address_for(page)
        @mutex.synchronize { @page_addresses.fetch(page) }
      rescue KeyError
        raise Error.new('page is not registered', owner: owner_label(page.owner), page_id: page.id)
      end

      # The page behind a wire address.
      #
      # @param address [String, #to_s] the opaque address
      # @return [Page] the page
      # @raise [Error] when the address is not registered
      def fetch_address(address)
        @mutex.synchronize { @addresses.fetch(address.to_s) }
      rescue KeyError
        raise Error.new('page address is not registered', page_id: address)
      end

      # The launcher's view of every page: what a client needs to list and open them.
      #
      # `owner` and `modal` let a window opened for one page recognise a
      # modal its own script raised. Without them a page-scoped window
      # ignores every other page, so a dialog opened from a script's window
      # never appeared while the script sat blocked waiting for an answer.
      #
      # @return [Array<Hash{Symbol => Object}>] `address`, `title`, `contract_version`, `owner`, `modal` per page
      def descriptors
        @mutex.synchronize do
          @addresses.map do |address, page|
            {
              address: address, title: page.title, contract_version: Contract::VERSION,
              owner: owner_label(page.owner), modal: page.modal == true
            }
          end
        end
      end

      private

      def registry_key(owner, page_id)
        [owner.object_id, page_id.to_s]
      end

      def owner_label(owner)
        return owner.webui_owner_id if owner.respond_to?(:webui_owner_id)
        return owner.name if owner.respond_to?(:name) && owner.name

        "#{owner.class}:#{owner.object_id}"
      end

      def remove_address(page)
        return unless page

        address = @page_addresses.delete(page)
        @addresses.delete(address) if address
      end
    end
  end
end
