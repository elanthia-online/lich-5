# frozen_string_literal: true

require 'securerandom'
require 'monitor'
require_relative 'component'
require_relative 'protocol'
require_relative 'value_helpers'

module Lich
  module WebUI
    # Per-page viewer attachments and viewer-local state.
    class ViewerStore
      RECONNECT_WINDOW = 60
      WIDGET_ADMISSION_WINDOW = 30
      RELEASE_ADMISSION_WINDOW = 30
      Admission = Data.define(:render, :widget_revision, :accepted_at)
      ReleaseAdmission = Data.define(:render, :epoch, :cid, :accepted_at)
      ReleaseEpoch = Struct.new(:signature, :generation, :started_at)
      Snapshot = Data.define(:page, :viewer_id, :render, :values, :input_requests)

      # One viewer capability and its retained delivery/admission bookkeeping.
      class Attachment
        attr_accessor :connection_id, :render, :delivered_generation, :expires_at
        attr_accessor :widget_signature, :widget_generation, :widget_started_at, :widget_revision, :widget_request
        attr_reader :viewer_id, :resume_token, :address, :page, :values, :delivered_read_only, :input_requests
        attr_reader :release_epochs
        attr_accessor :release_request

        # Creates independent viewer identity, resume capability, and local state for a page.
        # The resume token is server-generated; no render is delivered yet.
        # @param connection_id [String] authenticated transport identity
        # @param address [String] opaque registered page address
        # @param page [Page] exact page receiving the viewer
        # @return [Attachment] independent viewer capability and state
        def initialize(connection_id:, address:, page:)
          @connection_id = connection_id
          @viewer_id = "attachment-#{SecureRandom.hex(16)}".freeze
          @resume_token = "resume-#{SecureRandom.hex(16)}".freeze
          @address = address.freeze
          @page = page
          @values = {}
          @input_requests = {}
          @delivered_read_only = {}
          @render = nil
          @delivered_generation = nil
          @expires_at = nil
          @widget_signature = @widget_generation = @widget_started_at = @widget_request = nil
          @widget_revision = 0
          @release_epochs = {}
          @release_request = nil
        end
      end

      # Creates connection/resume indexes with an injectable monotonic expiry clock.
      # @param clock [#call] elapsed seconds used for reconnect deadlines
      # @return [ViewerStore]
      def initialize(clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
        @clock = clock
        @by_connection = {}
        @by_resume = {}
        @mutex = Monitor.new
      end

      # Attaches one viewer per connection/page pair, or resumes a disconnected one.
      # @param connection_id [String] authenticated connection identifier
      # @param address [String] registered page address
      # @param page [Page] page receiving the viewer
      # @param resume_token [String, nil] previous attachment's reconnect token
      # @return [Attachment] the new or resumed viewer
      # @raise [Error] if this connection already views the page or resume is invalid
      def attach(connection_id:, address:, page:, resume_token: nil)
        @mutex.synchronize do
          expire_locked!
          raise Error, 'viewer is already attached' if @by_connection.key?([connection_id, address])

          attachment = resume_token && @by_resume[resume_token]
          if attachment
            raise Error, 'resume token belongs to another page' unless attachment.address == address
            raise Error, 'viewer is already attached' unless attachment.expires_at

            remove_connection_mapping!(attachment)
            attachment.connection_id = connection_id
            attachment.expires_at = nil
          else
            attachment = Attachment.new(connection_id: connection_id, address: address, page: page)
            @by_resume[attachment.resume_token] = attachment
          end
          @by_connection[[connection_id, address]] = attachment
          attachment
        end
      end

      # Finds a live connection/page attachment after expiring stale resume entries.
      # @param connection_id [String] authenticated transport identity
      # @param address [String] opaque registered page address
      # @return [Attachment]
      # @raise [Error] when the connection is not attached to that page
      def fetch(connection_id:, address:)
        @mutex.synchronize do
          expire_locked!
          @by_connection.fetch([connection_id, address])
        end
      rescue KeyError
        raise Error, 'viewer is not attached to page'
      end

      # Removes connection routing while retaining state for the bounded resume window.
      # @param connection_id [String] authenticated transport identity
      # @return [Array<Attachment>] disconnected attachments for lifecycle notifications
      def transient_disconnect(connection_id)
        @mutex.synchronize do
          attachments = @by_connection.each_value.select { |attachment| attachment.connection_id == connection_id }.uniq
          attachments.each do |attachment|
            attachment.expires_at = @clock.call + RECONNECT_WINDOW
            retire_widget_admission!(attachment)
          end
          @by_connection.delete_if { |(candidate, _address), _attachment| candidate == connection_id }
          attachments
        end
      end

      # Destroys one attachment immediately, including its resume capability and values.
      # @param connection_id [String] authenticated transport identity
      # @param address [String] opaque registered page address
      # @return [Attachment, nil] removed attachment
      def close(connection_id:, address:)
        @mutex.synchronize do
          attachment = @by_connection.delete([connection_id, address])
          destroy_locked!(attachment) if attachment
          attachment
        end
      end

      # Destroys all live and resumable attachments for this exact page instance.
      # @param page [Page] exact page instance receiving or retiring viewers
      # @return [void]
      def destroy_page(page)
        @mutex.synchronize do
          @by_resume.values.select { |attachment| attachment.page.equal?(page) }.uniq.each do |attachment|
            destroy_locked!(attachment)
          end
        end
      end

      # Snapshots active page attachments; disconnected resume entries do not count.
      # @param page [Page] exact page instance receiving or retiring viewers
      # @return [Array<Attachment>]
      def attachments_for(page)
        @mutex.synchronize do
          expire_locked!
          @by_resume.values.select { |attachment| attachment.page.equal?(page) && !attachment.expires_at }.uniq
        end
      end

      # Resolves an active viewer within an exact page instance.
      # @param page [Page] exact page instance receiving or retiring viewers
      # @param viewer_id [String] server-generated page viewer identity
      # @return [Attachment]
      # @raise [Error] for absent, expired, or disconnected viewers
      def attachment_for_viewer(page, viewer_id)
        @mutex.synchronize do
          expire_locked!
          @by_resume.values.find do |attachment|
            attachment.page.equal?(page) && attachment.viewer_id == viewer_id && !attachment.expires_at
          end
        end || raise(Error.new('viewer is not attached to page', page_id: page.id))
      end

      private

      # Destroys expired disconnected attachments while the store mutex is held.
      # @return [void]
      # @api private
      def expire_locked!
        now = @clock.call
        @by_resume.values.select { |attachment| attachment.expires_at && attachment.expires_at <= now }.uniq.each do |attachment|
          destroy_locked!(attachment)
        end
      end

      # Clears connection/resume indexes, values, and render references under the store mutex.
      # @param attachment [Attachment, nil] attachment to retire, or nil for an already-missing target
      # @return [void]
      # @api private
      def destroy_locked!(attachment)
        return unless attachment

        remove_connection_mapping!(attachment)
        @by_resume.delete(attachment.resume_token)
        attachment.values.clear
        attachment.input_requests.clear
        attachment.delivered_read_only.clear
        attachment.render = nil
        attachment.delivered_generation = nil
        retire_widget_admission!(attachment)
      end

      # Deletes only mappings to this exact attachment object, including superseded aliases.
      # @param attachment [Attachment] exact viewer/page association
      # @return [void]
      # @api private
      def remove_connection_mapping!(attachment)
        @by_connection.delete_if { |_key, candidate| candidate.equal?(attachment) }
      end
    end
  end
end

require_relative 'viewer_store/admission'
require_relative 'viewer_store/signatures'
require_relative 'viewer_store/values'
require_relative 'viewer_store/reconciliation'
require_relative 'viewer_store/snapshots'
