# frozen_string_literal: true

require_relative 'page'
require 'securerandom'

module Lich
  module WebUI
    # Server-owned page registry. Owner identity is never accepted from wire input.
    class Registry
      # Creates an empty registry with owner admission tracked by identity.
      def initialize
        @pages = {}
        @addresses = {}
        @page_addresses = {}.compare_by_identity
        @modal_pages = {}.compare_by_identity
        @terminated_owners = ObjectSpace::WeakMap.new
        @stopped = false
        @mutex = Mutex.new
      end

      # Registers a page only while its owner and this host accept new work.
      # @param page [Page] page to publish
      # @param modal [Boolean] whether descriptors route it to the owner's pages
      # @return [Page] registered page
      # @raise [Error] if the owner terminated or the registry stopped
      # @raise [DuplicatePageError] if the owner already registered this page ID
      def register(page, modal: false)
        raise ArgumentError, 'page must be a WebUI::Page' unless page.is_a?(Page)

        key = registry_key(page.owner, page.id)
        @mutex.synchronize do
          check_active!(page.owner)
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
          @modal_pages[page] = true if modal
        end
        page
      end

      # Rejects new work before owner cleanup takes a snapshot of existing pages.
      # Repeated calls are safe; a restarted script must use its new owner identity.
      # @param owner [Object] terminating owner
      # @return [void]
      def terminate_owner(owner)
        @mutex.synchronize { @terminated_owners[owner] = true }
      end

      # Closes registration for every owner without hiding pages still needing cleanup.
      # @return [void]
      def stop
        @mutex.synchronize { @stopped = true }
      end

      # Checks admission for operations that can precede page registration.
      # @param owner [Object] owner requesting work
      # @return [void]
      # @raise [Error] if the owner terminated or this registry stopped
      def ensure_active!(owner)
        @mutex.synchronize { check_active!(owner) }
      end

      # Finds a page by server-side owner identity and owner-local ID.
      # @return [Page] registered page
      # @raise [Error] if no such page is registered
      def fetch(owner, page_id)
        @mutex.synchronize { @pages.fetch(registry_key(owner, page_id)) }
      rescue KeyError
        raise Error.new('page is not registered', owner: owner_label(owner), page_id: page_id)
      end

      # Removes one page and its address/modal indexes without performing owner cleanup.
      # @return [Page, nil] removed page, or nil if absent
      def unregister(owner, page_id)
        @mutex.synchronize do
          page = @pages.delete(registry_key(owner, page_id))
          remove_address(page)
          page
        end
      end

      # Removes every page and address belonging to this exact owner object.
      # @return [Array<Page>] removed pages for subsequent runtime cleanup
      def unregister_owner(owner)
        owner_identity = owner.object_id
        @mutex.synchronize do
          removed = @pages.select { |(identity, _page_id), _page| identity == owner_identity }.values
          @pages.delete_if { |(identity, _page_id), _page| identity == owner_identity }
          removed.each { |page| remove_address(page) }
          removed
        end
      end

      # Snapshots pages belonging to this exact owner object.
      # @return [Array<Page>] currently registered pages
      def pages_for(owner)
        owner_identity = owner.object_id
        @mutex.synchronize do
          @pages.filter_map { |(identity, _page_id), page| page if identity == owner_identity }
        end
      end

      # Returns the registered page count under the registry lock.
      # @return [Integer]
      def size
        @mutex.synchronize { @pages.size }
      end

      # Takes a snapshot without holding the registry lock while pages render.
      # @return [Array<Page>] currently registered pages
      def pages
        @mutex.synchronize { @pages.values }
      end

      # Retrieves the opaque wire address for an exact registered page instance.
      # @return [String] address
      # @raise [Error] if the page is no longer registered
      def address_for(page)
        @mutex.synchronize { @page_addresses.fetch(page) }
      rescue KeyError
        raise Error.new('page is not registered', owner: owner_label(page.owner), page_id: page.id)
      end

      # Resolves an opaque wire address to a registered page.
      # @return [Page]
      # @raise [Error] if the address is unknown
      def fetch_address(address)
        @mutex.synchronize { @addresses.fetch(address.to_s) }
      rescue KeyError
        raise Error.new('page address is not registered', page_id: address)
      end

      # Builds viewer-visible page descriptors without exposing owner identities.
      # Modal targets include only normal pages belonging to the same owner.
      # @return [Array<Hash>] addresses, titles, versions, and optional modal targets
      def descriptors
        @mutex.synchronize do
          @addresses.map do |address, page|
            descriptor = { address: address, title: page.title, contract_version: Contract::VERSION }
            # Modal routing follows owner identity without exposing that identity
            # on the wire. Normal windows of the same owner remain independent.
            if @modal_pages.key?(page)
              descriptor[:modal_for] = @addresses.filter_map do |candidate_address, candidate|
                candidate_address if candidate.owner.equal?(page.owner) && !@modal_pages.key?(candidate)
              end
            end
            descriptor
          end
        end
      end

      private

      # Checks admission while the registry mutex is held.
      # @param owner [Object] owner requesting work
      # @return [void]
      # @raise [Error] if registration is no longer allowed
      # @api private
      def check_active!(owner)
        raise Error, 'page registry is stopped' if @stopped
        raise Error, 'page owner is terminated' if @terminated_owners[owner]
      end

      def registry_key(owner, page_id)
        [owner.object_id, page_id.to_s]
      end

      def owner_label(owner)
        Diagnostics.owner_label(owner)
      end

      def remove_address(page)
        return unless page

        address = @page_addresses.delete(page)
        @modal_pages.delete(page)
        @addresses.delete(address) if address
      end
    end
  end
end
