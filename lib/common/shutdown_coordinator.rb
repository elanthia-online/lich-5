# frozen_string_literal: true

module Lich
  module Common
    # Records why the process began shutting down.
    #
    # This is intentionally small: PR #1 only captures first-wins shutdown
    # attribution. Later shutdown work can make decisions from this state without
    # threading more globals through main.rb.
    module ShutdownCoordinator
      ALLOWED_REASONS = [
        :user_exit,
        :client_disconnect,
        :game_eof,
        :game_timeout,
        :connection_reset,
        :connection_pipe,
        :connection_aborted,
        :unrecoverable_game_thread_error,
      ].freeze

      CONNECTION_LOSS_REASONS = [
        :client_disconnect,
        :game_eof,
        :game_timeout,
        :connection_reset,
        :connection_pipe,
        :connection_aborted,
        :unrecoverable_game_thread_error,
      ].freeze

      Request = Struct.new(:reason, :source, :detail, :requested_at, keyword_init: true)

      class << self
        def request(reason:, source:, detail: nil)
          validate_reason!(reason)
          validate_source!(source)

          mutex.synchronize do
            @request ||= Request.new(
              reason: reason,
              source: source.to_s,
              detail: detail,
              requested_at: Time.now
            ).tap { |shutdown_request| log_request(shutdown_request) }
          end
        end

        def requested?
          !current.nil?
        end

        def current
          mutex.synchronize { @request }
        end

        def reason
          current&.reason
        end

        def orderly_user_exit?
          reason == :user_exit
        end

        def connection_loss?
          CONNECTION_LOSS_REASONS.include?(reason)
        end

        def reset!
          mutex.synchronize { @request = nil }
        end

        private

        def mutex
          @mutex ||= Mutex.new
        end

        def validate_reason!(reason)
          unless reason.is_a?(Symbol) && ALLOWED_REASONS.include?(reason)
            raise ArgumentError, "invalid shutdown reason: #{reason.inspect}"
          end
        end

        def validate_source!(source)
          if source.nil? || source.to_s.empty?
            raise ArgumentError, "shutdown source must be present"
          end
        end

        def log_request(shutdown_request)
          return unless defined?(Lich) && Lich.respond_to?(:log)

          detail = shutdown_request.detail
          detail_text = detail.nil? || detail.to_s.empty? ? "" : " detail=#{detail}"
          Lich.log("info: shutdown requested reason=#{shutdown_request.reason} source=#{shutdown_request.source}#{detail_text}")
        end
      end
    end
  end
end
