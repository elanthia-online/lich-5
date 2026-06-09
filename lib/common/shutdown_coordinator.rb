# frozen_string_literal: true

module Lich
  module Common
    # Records process shutdown attribution and coarse shutdown progress.
    #
    # The coordinator is deliberately state-only. It records first-wins shutdown
    # intent and stores the result of any higher-level shutdown runner, but it
    # does not perform teardown work itself.
    module ShutdownCoordinator
      @mutex = Mutex.new

      # Shutdown reasons accepted by {request}.
      ALLOWED_REASONS = [
        :user_exit,
        :client_disconnect,
        :game_eof,
        :game_timeout,
        :connection_reset,
        :connection_pipe,
        :connection_aborted,
        :game_stream_desync,
        :unrecoverable_game_thread_error,
      ].freeze

      # Reasons that indicate local frontend loss or remote game connection loss.
      CONNECTION_LOSS_REASONS = [
        :client_disconnect,
        :game_eof,
        :game_timeout,
        :connection_reset,
        :connection_pipe,
        :connection_aborted,
        :game_stream_desync,
        :unrecoverable_game_thread_error,
      ].freeze

      # First shutdown request observed by the process.
      Request = Struct.new(:reason, :source, :detail, :requested_at, keyword_init: true)

      class << self
        # Records shutdown intent once.
        #
        # First request wins so later fallout, such as Game.close unblocking the
        # reader thread, does not overwrite the initiating reason.
        #
        # @param reason [Symbol] one of {ALLOWED_REASONS}
        # @param source [#to_s] subsystem that observed the request
        # @param detail [Object, nil] optional compact diagnostic detail
        # @return [Request] the stored first request
        # @raise [ArgumentError] when reason/source is invalid
        def request(reason:, source:, detail: nil)
          validate_reason!(reason)
          validate_source!(source)

          mutex.synchronize do
            @request ||= Request.new(
              reason: reason,
              source: source.to_s,
              detail: detail,
              requested_at: Time.now
            ).tap do |shutdown_request|
              log_request(shutdown_request)
              shutdown_request.freeze
            end
          end
        end

        # @return [Boolean] whether any shutdown request has been recorded
        def requested?
          !current.nil?
        end

        # @return [Request, nil] stored first shutdown request
        def current
          mutex.synchronize { @request }
        end

        # @return [Symbol, nil] stored shutdown reason
        def reason
          current&.reason
        end

        # @return [Boolean] whether shutdown was explicitly requested by user input
        def orderly_user_exit?
          reason == :user_exit
        end

        # @return [Boolean] whether shutdown began from local or remote connection loss
        def connection_loss?
          CONNECTION_LOSS_REASONS.include?(reason)
        end

        # Stores the in-progress or completed orderly-shutdown result once.
        #
        # @param result [#completed?] result object produced by the orderly runner
        # @return [Object] stored result; may be a previously stored result
        # @raise [ArgumentError] when result is nil or missing expected predicates
        def begin_orderly_shutdown(result)
          validate_orderly_shutdown_result!(result)

          mutex.synchronize do
            @orderly_shutdown_result ||= result
          end
        end

        # Stores the in-progress or completed best-effort cleanup result once.
        #
        # @param result [#completed?] result object produced by a cleanup runner
        # @return [Object] stored result; may be a previously stored result
        # @raise [ArgumentError] when result is nil or missing expected predicates
        def begin_best_effort_cleanup(result)
          validate_cleanup_result!(result)

          mutex.synchronize do
            @best_effort_cleanup_result ||= result
          end
        end

        # @return [Object, nil] orderly-shutdown result if a user-exit runner started
        def orderly_shutdown_result
          mutex.synchronize { @orderly_shutdown_result }
        end

        # @return [Object, nil] best-effort cleanup result if cleanup started
        def best_effort_cleanup_result
          mutex.synchronize { @best_effort_cleanup_result }
        end

        # @return [Boolean] whether the orderly-shutdown runner completed all steps
        def orderly_shutdown_completed?
          orderly_shutdown_result&.completed?
        end

        # @return [Boolean] whether best-effort cleanup completed all local steps
        def best_effort_cleanup_completed?
          best_effort_cleanup_result&.completed?
        end

        # @return [Boolean] whether orderly shutdown or best-effort cleanup fully drained scripts
        def scripts_drained?
          orderly_shutdown_result&.scripts_drained? || best_effort_cleanup_result&.scripts_drained?
        end

        # @return [Boolean] whether orderly shutdown or best-effort cleanup saved script settings
        def vars_saved?
          orderly_shutdown_result&.vars_saved? || best_effort_cleanup_result&.vars_saved?
        end

        # Records fatal client socket write failure context once.
        #
        # If no shutdown request exists yet, the write failure is treated as a
        # client disconnect. If another shutdown reason already exists, first-wins
        # attribution is preserved while the transport failure remains visible.
        #
        # @param error [Exception] fatal socket write error
        # @param source [#to_s] subsystem that observed the failed write
        # @return [Exception] stored first client socket write failure
        def record_client_socket_write_failure(error:, source: :client_socket_write)
          raise ArgumentError, "client socket write failure error must be present" if error.nil?

          validate_source!(source)

          mutex.synchronize do
            @client_socket_write_failure ||= error
          end

          request(
            reason: :client_disconnect,
            source: source,
            detail: "#{error.class}: #{error.message}"
          ) unless requested?

          client_socket_write_failure
        end

        # @return [Exception, nil] first fatal client socket write failure
        def client_socket_write_failure
          mutex.synchronize { @client_socket_write_failure }
        end

        # @return [Boolean] whether the client socket write path failed fatally
        def client_socket_write_failed?
          !client_socket_write_failure.nil?
        end

        # Clears coordinator state for tests and process reinitialization.
        #
        # @return [nil]
        def reset!
          mutex.synchronize do
            @request = nil
            @orderly_shutdown_result = nil
            @best_effort_cleanup_result = nil
            @client_socket_write_failure = nil
          end
        end

        private

        def mutex
          @mutex
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

        def validate_orderly_shutdown_result!(result)
          raise ArgumentError, "orderly shutdown result must be present" if result.nil?
          raise ArgumentError, "orderly shutdown result must respond to #completed?" unless result.respond_to?(:completed?)
          raise ArgumentError, "orderly shutdown result must respond to #scripts_drained?" unless result.respond_to?(:scripts_drained?)
          raise ArgumentError, "orderly shutdown result must respond to #vars_saved?" unless result.respond_to?(:vars_saved?)
        end

        def validate_cleanup_result!(result)
          raise ArgumentError, "best-effort cleanup result must be present" if result.nil?
          raise ArgumentError, "best-effort cleanup result must respond to #completed?" unless result.respond_to?(:completed?)
          raise ArgumentError, "best-effort cleanup result must respond to #scripts_drained?" unless result.respond_to?(:scripts_drained?)
          raise ArgumentError, "best-effort cleanup result must respond to #vars_saved?" unless result.respond_to?(:vars_saved?)
        end

        def log_request(shutdown_request)
          detail = shutdown_request.detail
          detail_text = detail.nil? || detail.to_s.empty? ? "" : " detail=#{detail}"
          log("info: shutdown requested reason=#{shutdown_request.reason} source=#{shutdown_request.source}#{detail_text}")
        end

        def log(message)
          return unless defined?(Lich) && Lich.respond_to?(:log)

          Lich.log(message)
        end
      end
    end
  end
end
