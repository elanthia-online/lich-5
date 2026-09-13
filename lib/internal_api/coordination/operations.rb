# frozen_string_literal: true

require 'digest'
require 'json'
require 'securerandom'

module Lich
  module InternalAPI
    module Coordination
      # Bounded, explicitly granted operation delivery for one exact pair of
      # independent sessions. Transport workers validate and reserve work; only
      # the owning thread can take or settle it. This module never sends game
      # commands, starts scripts, or invokes caller callbacks.
      module Operations
        PROTOCOL_VERSION = 1
        MAX_FRAME_BYTES = 16_384
        DEFAULT_CAPACITY = 32
        DEFAULT_TICKET_SECONDS = 5.0
        DEFAULT_TIMEOUT = 0.25

        STATES = %w[reserved pending running settled expired revoked].freeze
        OUTCOMES = %w[succeeded failed cancelled unknown].freeze
        CLEANUP = %w[not_required pending complete unknown].freeze

        # Validation and canonical-copy helpers shared by the owner and peer.
        # These are deliberately data-only: no executable validators cross the
        # transport seam.
        module Contract
          MAX_DEPTH = 8
          MAX_COLLECTION = 64
          MAX_STRING_BYTES = 2_048
          NAME = /\A[a-z][a-z0-9_]{0,63}\z/
          ARGUMENT = /\A[a-z][a-z0-9_]{0,63}\z/

          module_function

          def name?(value)
            value.is_a?(String) && value.match?(NAME)
          end

          def request_id?(value)
            Coordination::Schema.string?(value) && value.bytesize <= 128
          end

          def owner_tick?(value)
            value.is_a?(Integer) && value.positive?
          end

          def value?(value, depth = 0)
            return false if depth > MAX_DEPTH

            case value
            when nil, true, false, Integer
              true
            when Float
              value.finite?
            when String
              value.bytesize <= MAX_STRING_BYTES
            when Array
              value.size <= MAX_COLLECTION && value.all? { |item| value?(item, depth + 1) }
            when Hash
              value.size <= MAX_COLLECTION && value.all? do |key, item|
                (key.is_a?(String) || key.is_a?(Symbol)) && key.to_s.bytesize <= 128 && value?(item, depth + 1)
              end
            else
              false
            end
          end

          def operations(value)
            unless value.is_a?(Hash) && !value.empty? && value.size <= MAX_COLLECTION
              raise ArgumentError, 'operations must be a non-empty bounded hash'
            end

            normalized = value.to_h do |name, definition|
              name = name.to_s
              raise ArgumentError, "invalid operation name: #{name}" unless name?(name)
              unless Coordination::Schema.exact_keys?(definition, %i[required optional])
                raise ArgumentError, "operation #{name} requires required and optional argument lists"
              end

              required = argument_names(name, definition[:required])
              optional = argument_names(name, definition[:optional])
              raise ArgumentError, "operation #{name} repeats an argument" unless (required & optional).empty?

              [name.freeze, { required: required.freeze, optional: optional.freeze }.freeze]
            end
            normalized.freeze
          end

          def arguments?(value, definition)
            return false unless value.is_a?(Hash) && value?(value)

            return false unless value.keys.all? do |key|
              (key.is_a?(String) || key.is_a?(Symbol)) && key.to_s.match?(ARGUMENT)
            end

            keys = value.keys.map(&:to_s)
            keys.uniq.size == keys.size &&
              (definition[:required] - keys).empty? &&
              (keys - definition[:required] - definition[:optional]).empty?
          end

          def digest(value)
            Digest::SHA256.hexdigest(JSON.generate(canonical(value)))
          end

          def copy(value)
            Coordination::Schema.immutable(value)
          end

          def receipt?(value)
            required = %i[identity peer request_id operation argument_digest state outcome cleanup reason owner_tick result]
            return false unless Coordination::Schema.exact_keys?(value, required)
            return false unless Coordination::Schema.identity?(value[:identity]) && Coordination::Schema.identity?(value[:peer])
            return false unless request_id?(value[:request_id]) && name?(value[:operation])
            return false unless value[:argument_digest].is_a?(String) && value[:argument_digest].match?(/\A[0-9a-f]{64}\z/)
            return false unless STATES.include?(value[:state]) && (value[:outcome].nil? || OUTCOMES.include?(value[:outcome]))
            return false unless CLEANUP.include?(value[:cleanup]) && (value[:reason].nil? || Coordination::Schema.string?(value[:reason]))
            return false unless value[:owner_tick].nil? || owner_tick?(value[:owner_tick])

            value?(value[:result])
          end

          def descriptor?(value)
            Coordination::Schema.exact_keys?(value, %i[protocol_version host port identity peer]) &&
              value[:protocol_version] == PROTOCOL_VERSION && value[:host] == '127.0.0.1' &&
              value[:port].is_a?(Integer) && value[:port].between?(1, 65_535) &&
              Coordination::Schema.identity?(value[:identity]) && Coordination::Schema.identity?(value[:peer])
          end

          def argument_names(operation, value)
            unless value.is_a?(Array) && value.size <= MAX_COLLECTION
              raise ArgumentError, "operation #{operation} arguments must be bounded arrays"
            end

            names = value.map(&:to_s)
            unless names.uniq.size == names.size && names.all? { |name| name.match?(ARGUMENT) }
              raise ArgumentError, "operation #{operation} has invalid arguments"
            end

            names.map!(&:freeze)
          end
          private_class_method :argument_names

          def canonical(value)
            case value
            when Hash
              value.map { |key, item| [key.to_s, canonical(item)] }.sort.to_h
            when Array
              value.map { |item| canonical(item) }
            else
              value
            end
          end
          private_class_method :canonical
        end

        # Owner-side grant and bounded receipt store. The network handler may
        # reserve and submit work, but only #next_request, #settle and
        # #finish_cleanup cross the owner-thread seam.
        class Grant
          # @param session [#identity] current native coordination Session
          # @param peer [Hash] exact granted peer identity
          # @param control_token [String] credential separate from read/discovery tokens
          # @param operations [Hash] operation => {required: [], optional: []}
          # @param enabled [Boolean] false keeps the grant completely inert
          # @param capacity [Integer] maximum retained request receipts
          # @param ticket_seconds [Numeric] receiver-local issuance-to-use allowance
          # @param clock [#call, nil] receiver-local monotonic seconds
          def initialize(session:, peer:, control_token:, operations:, enabled: false,
                         capacity: DEFAULT_CAPACITY, ticket_seconds: DEFAULT_TICKET_SECONDS, clock: nil)
            identity = session.identity
            unless Coordination::Schema.identity?(identity) && Coordination::Schema.identity?(peer)
              raise ArgumentError, 'grant requires exact session and peer identities'
            end
            raise ArgumentError, 'control token required' unless Coordination::Schema.string?(control_token)
            unless capacity.is_a?(Integer) && capacity.positive? && capacity <= 1_024
              raise ArgumentError, 'invalid receipt capacity'
            end
            unless Coordination::Schema.age?(ticket_seconds) && ticket_seconds.positive? && ticket_seconds <= 60
              raise ArgumentError, 'invalid ticket lifetime'
            end

            @session = session
            @identity = Contract.copy(identity)
            @peer = Contract.copy(peer)
            @token = control_token.dup.freeze
            @operations = Contract.operations(operations)
            @enabled = enabled == true
            @capacity = capacity
            @ticket_seconds = ticket_seconds
            @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
            @owner_thread = Thread.current
            @mutex = Mutex.new
            @entries = {}
            @server = nil
            @closed = false
            @retired = false
            @last_owner_tick = 0
          end

          # Starts the explicitly enabled control endpoint.
          # @return [Boolean]
          def start
            assert_owner!
            @mutex.synchronize do
              return false unless @enabled && !@closed && !@retired && identity_current?
              return true if @server&.running?

              @server = ActiveSessions::Server.new(
                host: '127.0.0.1', port: 0, registry: nil, auth_token: @token,
                request_handler: method(:route), max_frame_bytes: MAX_FRAME_BYTES,
                max_clients: 4, timeout: DEFAULT_TIMEOUT
              )
              @server.start
            end
          end

          # Token-free endpoint metadata for explicit exchange with the peer.
          # @return [Hash, nil]
          def descriptor
            @mutex.synchronize do
              return nil unless @server&.running? && !@closed && !@retired && identity_current?

              Contract.copy(protocol_version: PROTOCOL_VERSION, host: @server.host, port: @server.port,
                            identity: @identity, peer: @peer)
            end
          end

          # Takes the oldest pending request for execution by this exact owner.
          # No callback runs and no side effect has yet been confirmed.
          # @param owner_tick [Integer] completed controller progression identifier
          # @return [Hash, nil] immutable request or nil when none is admissible
          def next_request(owner_tick:)
            assert_owner!
            raise ArgumentError, 'owner tick must strictly advance' unless Contract.owner_tick?(owner_tick) && owner_tick > @last_owner_tick

            @mutex.synchronize do
              @last_owner_tick = owner_tick
              revoke_locked('session_replaced') unless identity_current?
              expire_locked
              return nil if @closed

              entry = @entries.values.find { |candidate| candidate[:state] == 'pending' }
              return nil unless entry

              entry[:state] = 'running'
              entry[:cleanup] = 'pending'
              entry[:owner_tick] = owner_tick
              entry[:observed_at] = @clock.call
              Contract.copy(request_id: entry[:request_id], operation: entry[:operation],
                            arguments: entry[:arguments], argument_digest: entry[:argument_digest],
                            owner_tick: owner_tick)
            end
          end

          # Records the owning controller's truthful operation outcome.
          # Cleanup may remain pending after the logical outcome is known.
          # @param request_id [String]
          # @param owner_tick [Integer]
          # @param outcome [String, Symbol] succeeded, failed, cancelled or unknown
          # @param result [Object] bounded JSON-compatible result
          # @param cleanup [String, Symbol] not_required, pending, complete or unknown
          # @param reason [String, Symbol, nil]
          # @return [Hash] immutable receipt
          def settle(request_id:, owner_tick:, outcome:, result: nil, cleanup: :complete, reason: nil)
            assert_owner!
            outcome = outcome.to_s
            cleanup = cleanup.to_s
            unless Contract.request_id?(request_id) && Contract.owner_tick?(owner_tick) && OUTCOMES.include?(outcome) &&
                   CLEANUP.include?(cleanup) && Contract.value?(result) &&
                   (reason.nil? || Coordination::Schema.string?(reason.to_s))
              raise ArgumentError, 'invalid operation settlement'
            end

            @mutex.synchronize do
              entry = @entries[request_id]
              raise ArgumentError, 'request is not running' unless entry && entry[:state] == 'running'
              raise ArgumentError, 'owner tick predates request admission' if owner_tick < entry[:owner_tick]
              raise ArgumentError, 'owner tick regressed' if owner_tick < @last_owner_tick

              entry[:state] = 'settled'
              entry[:outcome] = outcome
              entry[:cleanup] = cleanup
              entry[:reason] = reason&.to_s&.dup&.freeze
              entry[:result] = Contract.copy(result)
              entry[:owner_tick] = owner_tick
              entry[:observed_at] = @clock.call
              receipt(entry)
            end
          end

          # Confirms teardown after an already settled operation.
          # @param request_id [String]
          # @param owner_tick [Integer]
          # @return [Hash] immutable receipt
          def finish_cleanup(request_id:, owner_tick:)
            assert_owner!
            unless Contract.request_id?(request_id) && Contract.owner_tick?(owner_tick)
              raise ArgumentError, 'invalid cleanup confirmation'
            end

            @mutex.synchronize do
              entry = @entries[request_id]
              unless entry && entry[:state] == 'settled' && entry[:cleanup] == 'pending' && owner_tick >= entry[:owner_tick]
                raise ArgumentError, 'request has no pending cleanup'
              end
              raise ArgumentError, 'owner tick regressed' if owner_tick < @last_owner_tick

              entry[:cleanup] = 'complete'
              entry[:owner_tick] = owner_tick
              entry[:observed_at] = @clock.call
              receipt(entry)
            end
          end

          # Closes admission without claiming that running work has stopped.
          # Pending work is revoked; running receipts remain running until their
          # owner settles them or the endpoint disappears with unknown outcome.
          # @param reason [String, Symbol]
          # @return [nil]
          def revoke(reason = 'grant_revoked')
            reason = reason.to_s
            raise ArgumentError, 'invalid revocation reason' unless Coordination::Schema.string?(reason)

            @mutex.synchronize { revoke_locked(reason) }
            nil
          end

          # @return [Boolean] whether new admission has been closed
          def revoked?
            @mutex.synchronize { @closed }
          end

          # Owner-thread endpoint teardown. Callers must settle/clean exact local
          # work before treating closure as a successful handoff.
          # @return [nil]
          def close
            assert_owner!
            server = @mutex.synchronize do
              revoke_locked('grant_closed')
              @retired = true
              current = @server
              @server = nil
              current
            end
            server&.stop
            nil
          end

          private

          def route(request)
            return failure('invalid_request') unless Coordination::Schema.exact_keys?(request, %i[command auth payload]) &&
                                                     Coordination::Schema.string?(request[:auth])

            @mutex.synchronize { handle_locked(request[:command], request[:payload]) }
          end

          def handle_locked(command, payload)
            return failure('invalid_request') unless payload.is_a?(Hash)
            return failure('unsupported_command') unless %w[ticket submit result].include?(command)

            required = %i[protocol_version identity peer request_id]
            required += %i[operation arguments] if command == 'ticket'
            required += [:ticket] if command == 'submit'
            return failure('invalid_request') unless Coordination::Schema.exact_keys?(payload, required)
            return failure('protocol_mismatch') unless payload[:protocol_version] == PROTOCOL_VERSION
            return failure('identity_mismatch') unless payload[:identity] == @identity && payload[:peer] == @peer && identity_current?
            return failure('invalid_request') unless Contract.request_id?(payload[:request_id])

            entry = @entries[payload[:request_id]]
            return entry ? success(receipt(entry)) : failure('unknown_request') if command == 'result'
            return failure('grant_closed') if @closed

            command == 'ticket' ? reserve_locked(payload, entry) : submit_locked(entry, payload[:ticket])
          end

          def reserve_locked(payload, entry)
            operation = payload[:operation]
            definition = @operations[operation]
            return failure('unsupported_operation') unless definition
            return failure('invalid_arguments') unless Contract.arguments?(payload[:arguments], definition)

            arguments = Contract.copy(payload[:arguments].transform_keys(&:to_s))
            argument_digest = Contract.digest(arguments)
            if entry
              unless entry[:operation] == operation && entry[:argument_digest] == argument_digest
                return failure('request_conflict')
              end

              expire_entry(entry)
              return success(ticket(entry))
            end
            return failure('grant_capacity') if @entries.size >= @capacity

            entry = {
              request_id: payload[:request_id].dup.freeze, operation: operation.dup.freeze,
              arguments: arguments, argument_digest: argument_digest.freeze,
              ticket: SecureRandom.hex(16).freeze, deadline: @clock.call + @ticket_seconds,
              state: 'reserved', outcome: nil, cleanup: 'not_required', reason: nil,
              owner_tick: nil, result: nil, observed_at: @clock.call
            }
            @entries[entry[:request_id]] = entry
            success(ticket(entry))
          end

          def submit_locked(entry, token)
            return failure('invalid_ticket') unless entry && Coordination::Schema.string?(token) && token == entry[:ticket]

            expire_entry(entry)
            entry[:state] = 'pending' if entry[:state] == 'reserved'
            entry[:observed_at] = @clock.call if entry[:state] == 'pending'
            success(receipt(entry))
          end

          def ticket(entry)
            { request_id: entry[:request_id], ticket: entry[:ticket], state: entry[:state],
              remaining_seconds: [entry[:deadline] - @clock.call, 0.0].max }
          end

          def receipt(entry)
            Contract.copy(
              identity: @identity, peer: @peer, request_id: entry[:request_id], operation: entry[:operation],
              argument_digest: entry[:argument_digest],
              state: entry[:state], outcome: entry[:outcome], cleanup: entry[:cleanup], reason: entry[:reason],
              owner_tick: entry[:owner_tick], result: entry[:result]
            )
          end

          def expire_locked
            @entries.each_value { |entry| expire_entry(entry) }
          end

          def expire_entry(entry)
            return unless %w[reserved pending].include?(entry[:state]) && @clock.call >= entry[:deadline]

            entry[:state] = 'expired'
            entry[:outcome] = 'cancelled'
            entry[:reason] = 'ticket_expired'
            entry[:observed_at] = @clock.call
          end

          def revoke_locked(reason)
            @closed = true
            @entries.each_value do |entry|
              next unless %w[reserved pending].include?(entry[:state])

              entry[:state] = 'revoked'
              entry[:outcome] = 'cancelled'
              entry[:reason] = reason.dup.freeze
              entry[:observed_at] = @clock.call
            end
          end

          def identity_current?
            @session.identity == @identity
          rescue StandardError
            false
          end

          def assert_owner!
            raise ThreadError, 'operation grant must run on its owner thread' unless Thread.current.equal?(@owner_thread)
          end

          def success(payload)
            { ok: true, payload: payload }
          end

          def failure(reason)
            { ok: false, error: reason }
          end
        end

        # Peer-side convenience wrapper for ticket, submit and result. Reusing a
        # request ID retries the same immutable operation; it never renews its
        # validity window.
        class Client
          # @param descriptor [Hash] token-free Grant descriptor
          # @param control_token [String] separately exchanged grant credential
          # @param local_identity [Hash] exact identity named as descriptor peer
          # @param timeout [Numeric] bounded connect/write/read deadline
          # @param transport [#request, nil] injected transport for tests
          def initialize(descriptor:, control_token:, local_identity:, timeout: DEFAULT_TIMEOUT, transport: nil)
            unless Contract.descriptor?(descriptor) && descriptor[:peer] == local_identity
              raise ArgumentError, 'invalid operation descriptor or peer identity'
            end
            raise ArgumentError, 'control token required' unless Coordination::Schema.string?(control_token)

            @descriptor = Contract.copy(descriptor)
            @identity = @descriptor[:identity]
            @peer = @descriptor[:peer]
            @transport = transport || ActiveSessions::Client.new(
              host: descriptor[:host], port: descriptor[:port], auth_token: control_token,
              max_frame_bytes: MAX_FRAME_BYTES, timeout: timeout
            )
          end

          # Reserves and submits one immutable operation.
          # @return [Hash] validated receipt response or normalized failure
          def submit(request_id:, operation:, arguments: {})
            unless Contract.request_id?(request_id) && Contract.name?(operation) && Contract.value?(arguments) && arguments.is_a?(Hash)
              return failure('invalid_request')
            end

            response = @transport.request('ticket', base(request_id).merge(operation: operation, arguments: arguments))
            return failure_response(response) unless response.is_a?(Hash) && response[:ok] == true

            ticket = response[:payload]
            required = %i[request_id ticket state remaining_seconds]
            unless Coordination::Schema.exact_keys?(ticket, required) && ticket[:request_id] == request_id &&
                   Coordination::Schema.string?(ticket[:ticket]) && STATES.include?(ticket[:state]) &&
                   Coordination::Schema.age?(ticket[:remaining_seconds])
              return failure('invalid_ticket_response')
            end

            validate_receipt(@transport.request('submit', base(request_id).merge(ticket: ticket[:ticket])), request_id)
          rescue StandardError
            failure('operation_unavailable')
          end

          # Reads the retained receipt for a previously submitted request.
          # @return [Hash] validated receipt response or normalized failure
          def result(request_id:)
            return failure('invalid_request') unless Contract.request_id?(request_id)

            validate_receipt(@transport.request('result', base(request_id)), request_id)
          rescue StandardError
            failure('operation_unavailable')
          end

          private

          def base(request_id)
            { protocol_version: PROTOCOL_VERSION, identity: @identity, peer: @peer, request_id: request_id }
          end

          def validate_receipt(response, request_id)
            return failure_response(response) unless response.is_a?(Hash) && response[:ok] == true
            unless Contract.receipt?(response[:payload]) && response[:payload][:request_id] == request_id &&
                   response[:payload][:identity] == @identity && response[:payload][:peer] == @peer
              return failure('invalid_receipt')
            end

            { ok: true, payload: Contract.copy(response[:payload]) }
          end

          def failure_response(response)
            return failure(response[:error]) if response.is_a?(Hash) && response[:ok] == false && Coordination::Schema.string?(response[:error])

            failure('operation_unavailable')
          end

          def failure(reason)
            { ok: false, error: reason }
          end
        end
      end
    end
  end
end
