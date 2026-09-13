# frozen_string_literal: true

require 'securerandom'
require_relative 'active_sessions/server'
require_relative 'active_sessions/client'

module Lich
  module InternalAPI
    # Experimental, explicitly loaded read-only prototype. No runtime hooks or
    # discovery registration occur on require or construction. The owner must
    # publish a completed tick; transport workers only read that frozen copy.
    module Coordination
      PROTOCOL_VERSION = 1
      MAX_FRAME_BYTES = 16_384
      FIELDS = %w[room readiness].freeze
      IDENTITY_KEYS = %i[game character incarnation connection_generation run_id].freeze

      # Strict projection schema shared by owner admission and peer validation.
      # Source versions describe the real contributing observations, not polls.
      # All hashes use symbol keys; field names in protocol requests are strings.
      # Validation predicates return Boolean and never invoke game-state readers.
      module Schema
        module_function

        def exact_keys?(value, required, optional = [])
          value.is_a?(Hash) && (required - value.keys).empty? && (value.keys - required - optional).empty?
        end

        def string?(value)
          value.is_a?(String) && !value.empty? && value.bytesize <= 256
        end

        def count?(value)
          value.is_a?(Integer) && value >= 0
        end

        def age?(value)
          value.is_a?(Numeric) && value.finite? && value >= 0
        end

        def boolean?(value)
          value == true || value == false || value.nil?
        end

        def identity?(value)
          exact_keys?(value, IDENTITY_KEYS) &&
            %i[game character incarnation run_id].all? { |key| string?(value[key]) } &&
            count?(value[:connection_generation])
        end

        # @param value [Object] optional native discovery metadata
        # @return [Boolean] whether this is an exact token-free loopback descriptor
        def descriptor?(value)
          exact_keys?(value, %i[protocol_version host port identity]) &&
            value[:protocol_version] == PROTOCOL_VERSION && value[:host] == '127.0.0.1' &&
            value[:port].is_a?(Integer) && value[:port].between?(1, 65_535) && identity?(value[:identity])
        end

        def room?(value)
          exact_keys?(value, %i[id epoch]) &&
            (value[:id].nil? || string?(value[:id]) || count?(value[:id])) &&
            (value[:epoch].nil? || count?(value[:epoch]))
        end

        def readiness?(value)
          return false unless exact_keys?(value, %i[ready coherence], %i[limitations owner roundtime looting movement_ready])
          return false unless boolean?(value[:ready]) && %w[coherent unknown mixed].include?(value[:coherence])
          return false unless %i[roundtime looting movement_ready].all? { |key| boolean?(value[key]) }
          if value.key?(:limitations)
            return false unless value[:limitations].is_a?(Array) && value[:limitations].size <= 8 && value[:limitations].all? { |item| string?(item) }
          end
          if value.key?(:owner)
            owner = value[:owner]
            return false unless exact_keys?(owner, %i[state behavior]) && string?(owner[:state]) && (owner[:behavior].nil? || string?(owner[:behavior]))
          end
          true
        end

        def source?(value)
          value.nil? || (exact_keys?(value, %i[version age room_epoch connection_generation]) &&
            count?(value[:version]) && age?(value[:age]) && count?(value[:room_epoch]) && count?(value[:connection_generation]))
        end

        # @param value [Object] owner publication, without wire version or age
        # @return [Boolean] whether selected values have the supported strict shape
        def projection?(value)
          exact_keys?(value, %i[identity sequence owner_tick connected room readiness sources]) &&
            identity?(value[:identity]) && count?(value[:sequence]) && count?(value[:owner_tick]) &&
            boolean?(value[:connected]) && room?(value[:room]) && readiness?(value[:readiness]) &&
            exact_keys?(value[:sources], %i[room readiness]) && value[:sources].values.all? { |source| source?(source) }
        end

        # Checks declared source bindings; it cannot establish source atomicity.
        # @param value [Hash] validated projection or wire snapshot
        # @return [Boolean, nil] truthy only for connected, declared coherent sources
        def coherent?(value)
          value[:connected] && !value[:room][:id].nil? && value[:readiness][:coherence] == 'coherent' &&
            value[:sources].values.all? do |source|
              source && source[:room_epoch] == value[:room][:epoch] &&
                source[:connection_generation] == value[:identity][:connection_generation]
            end
        end

        # @param value [Hash, Array, String, Numeric, Boolean, nil] validated data
        # @return [Object] recursively frozen copy, without writable owner references
        def immutable(value)
          case value
          when Hash
            value.to_h { |key, item| [key, immutable(item)] }.freeze
          when Array
            value.map { |item| immutable(item) }.freeze
          when String
            value.dup.freeze
          else
            value.freeze
          end
        end
      end

      class Session
        # Identity and explicit read credential are separate from native discovery
        # credentials. Callers exchange this token outside the public descriptor.
        # @param game [String] game instance identifier
        # @param character [String] character name
        # @param run_id [String] owning controller run identifier
        # @param read_token [String] explicitly supplied per-endpoint read credential
        # @param enabled [Boolean] opt-in switch; false creates no listener/workers
        # @param clock [#call, nil] local monotonic seconds, injectable for tests
        # @return [Session]
        def initialize(game:, character:, run_id:, read_token:, enabled: false, clock: nil)
          raise ArgumentError, 'read token required' unless Schema.string?(read_token)

          @identity = Schema.immutable(game: game, character: character, run_id: run_id,
                                       incarnation: SecureRandom.hex(16), connection_generation: 0)
          raise ArgumentError, 'invalid identity' unless Schema.identity?(@identity)

          @read_token = read_token.dup.freeze
          @enabled = enabled == true
          @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
          @mutex = Mutex.new
          @server = nil
          @retired = false
          @snapshot = nil
          @source_times = {}
        end

        # @return [Hash] immutable current incarnation, connection and run identity
        def identity
          @mutex.synchronize { @identity }
        end

        # @return [Boolean] whether the explicitly enabled loopback listener started
        def start
          @mutex.synchronize do
            return false unless @enabled && !@retired
            return true if @server&.running?

            @server = ActiveSessions::Server.new(
              host: '127.0.0.1', port: 0, registry: nil, auth_token: @read_token,
              request_handler: method(:route),
              max_frame_bytes: MAX_FRAME_BYTES, max_clients: 4, timeout: 0.25
            )
            @server.start
          end
        end

        # @return [Hash, nil] immutable token-free endpoint metadata, or unavailable
        def descriptor
          @mutex.synchronize do
            return nil unless @server&.running? && !@retired

            Schema.immutable(protocol_version: PROTOCOL_VERSION, host: @server.host,
                             port: @server.port, identity: @identity)
          end
        end

        # Runs only on the owner path. A room/connection fence is insufficient
        # evidence of atomic vitals or ownership: callers must report unknown
        # coherence unless their contributing source actually guarantees it.
        # @param identity [Hash] identity captured with the owner's observations
        # @param sequence [Integer] strictly increasing publication sequence
        # @param owner_tick [Integer] strictly increasing completed owner tick
        # @param connected [Boolean, nil] actual connection state, nil if unknown
        # @param room [Hash] selected room id and native room epoch, nil if unknown
        # @param readiness [Hash] readiness, coherence and selected owner diagnostics
        # @param sources [Hash] room/readiness metadata or nil per unknown source;
        #   each known source has version, age in seconds at publication, room_epoch
        #   and connection_generation. Repeated versions retain their earlier age.
        # @return [Boolean] whether this immutable owner publication was admitted
        def publish(identity:, sequence:, owner_tick:, connected:, room:, readiness:, sources:)
          candidate = { identity: identity, sequence: sequence, owner_tick: owner_tick,
                        connected: connected, room: room, readiness: readiness, sources: sources }
          return false unless Schema.projection?(candidate)

          candidate = Schema.immutable(candidate)
          @mutex.synchronize do
            return false unless @enabled && !@retired && candidate[:identity] == @identity
            if @snapshot
              return false unless sequence > @snapshot[:sequence] && owner_tick > @snapshot[:owner_tick]
            end
            now = @clock.call
            times = {}
            candidate[:sources].each do |field, source|
              next unless source

              previous = @source_times[field]
              return false if previous && source[:version] < previous[:version]

              observed_at = now - source[:age]
              if previous && source[:version] == previous[:version]
                # A repeated observation cannot change its value or acquire a
                # younger age simply because an owner tick completed again.
                return false unless candidate[field] == previous[:value] &&
                                    source[:room_epoch] == previous[:room_epoch] &&
                                    source[:connection_generation] == previous[:connection_generation]

                observed_at = [observed_at, previous[:observed_at]].min
              end
              times[field] = { version: source[:version], value: candidate[field], observed_at: observed_at,
                               room_epoch: source[:room_epoch], connection_generation: source[:connection_generation] }
            end
            @source_times.merge!(times)
            @snapshot = candidate
            @published_at = now
            true
          end
        end

        # Called explicitly by the connection owner on reconnect. An old peer
        # descriptor cannot read even an empty snapshot from the new generation.
        # @return [Hash, false] new immutable identity, or false if disabled/retired
        def reconnect
          @mutex.synchronize do
            return false if @retired || !@enabled

            @identity = Schema.immutable(@identity.merge(connection_generation: @identity[:connection_generation] + 1))
            @snapshot = nil
            @source_times.clear
            @identity
          end
        end

        # Retires the listener and published data permanently for this Session.
        # @return [nil]
        def close
          server = @mutex.synchronize do
            @retired = true
            @snapshot = nil
            @source_times.clear
            current = @server
            @server = nil
            current
          end
          server&.stop
          nil
        end

        private

        def route(request)
          return failure('invalid request') unless Schema.exact_keys?(request, %i[command auth payload]) &&
                                                   Schema.string?(request[:auth])

          handle(request[:command], request[:payload])
        end

        def handle(command, payload)
          @mutex.synchronize do
            return failure('unavailable') if @retired || !@enabled
            return failure('unsupported command') unless %w[ping snapshot].include?(command)
            required = %i[protocol_version expected_identity]
            required += [:fields] if command == 'snapshot'
            return failure('invalid request') unless Schema.exact_keys?(payload, required)
            return failure('protocol mismatch') unless payload[:protocol_version] == PROTOCOL_VERSION
            return failure('identity mismatch') unless payload[:expected_identity] == @identity
            if command == 'ping'
              return { ok: true, payload: { protocol_version: PROTOCOL_VERSION, identity: @identity } }
            end
            return failure('unsupported fields') unless payload[:fields] == FIELDS
            return failure('snapshot unavailable') unless @snapshot

            now = @clock.call
            sources = @snapshot[:sources].to_h do |field, source|
              [field, source && source.merge(age: [now - @source_times.fetch(field)[:observed_at], 0.0].max)]
            end
            result = @snapshot.merge(protocol_version: PROTOCOL_VERSION,
                                     age: [now - @published_at, 0.0].max, sources: sources)
            unless Schema.coherent?(result)
              result = result.merge(readiness: result[:readiness].merge(ready: nil))
            end
            { ok: true, payload: result }
          end
        end

        def failure(message)
          { ok: false, error: message }
        end
      end

      # Pure consumer: no game globals, controller callbacks or remote writes.
      # It measures only its own round trip, never subtracts a peer's clock.
      class Client
        # @param descriptor [Hash] strict endpoint metadata from explicit discovery
        # @param read_token [String] read credential exchanged separately
        # @param max_age [Numeric] maximum conservative observation age in seconds
        # @param timeout [Numeric] shared connect/write/read deadline in seconds
        # @param clock [#call, nil] receiver-local monotonic seconds
        # @param transport [#request, nil] bounded transport injection for tests
        # @return [Client]
        def initialize(descriptor:, read_token:, max_age: 1.0, timeout: 0.25, clock: nil, transport: nil)
          raise ArgumentError, 'invalid descriptor' unless Schema.descriptor?(descriptor)
          raise ArgumentError, 'read token required' unless Schema.string?(read_token)
          raise ArgumentError, 'invalid maximum age' unless Schema.age?(max_age) && max_age.positive?

          @identity = Schema.immutable(descriptor[:identity])
          @max_age = max_age
          @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
          @transport = transport || ActiveSessions::Client.new(
            host: descriptor[:host], port: descriptor[:port], auth_token: read_token,
            max_frame_bytes: MAX_FRAME_BYTES, timeout: timeout
          )
          @mutex = Mutex.new
          @last = nil
          @source_history = {}
        end

        # Proves endpoint identity/version only; does not freshen any observation.
        # @return [Boolean] whether the exact endpoint answered within its deadline
        def ping
          response = @transport.request('ping', protocol_version: PROTOCOL_VERSION, expected_identity: @identity)
          response.is_a?(Hash) && response[:ok] == true &&
            Schema.exact_keys?(response[:payload], %i[protocol_version identity]) &&
            response[:payload][:protocol_version] == PROTOCOL_VERSION && response[:payload][:identity] == @identity
        rescue StandardError
          false
        end

        # No calls queue behind another snapshot: a busy client fails immediately.
        # Wire ages include server-local elapsed time; consumer ages additionally
        # include full RTT and receiver-local age floors for repeated observations.
        # @return [Hash] {ok: true, payload: frozen_snapshot} with conservative ready
        #   Boolean, or {ok: false, error: String}; unknown/stale/mixed is never ready
        def snapshot
          return failure('snapshot busy') unless @mutex.try_lock

          begin
            started = @clock.call
            response = @transport.request('snapshot', protocol_version: PROTOCOL_VERSION,
                                                      expected_identity: @identity, fields: FIELDS)
            received_at = @clock.call
            elapsed = [received_at - started, 0.0].max
            return failure('snapshot unavailable') unless response.is_a?(Hash) && response[:ok] == true

            value = response[:payload]
            return failure('invalid snapshot') unless valid_snapshot?(value)
            return failure('out of order snapshot') unless advancing?(value)

            # Keep wire watermarks separate from local age bounds. Repeating
            # an accepted sequence/version cannot erase elapsed local time or
            # a previous slower round trip, including across unavailable gaps.
            observed_at = received_at - value[:age] - elapsed
            if @last && value[:sequence] == @last[:sequence]
              observed_at = [observed_at, @snapshot_observed_at].min
            end
            @snapshot_observed_at = observed_at
            wire = Schema.immutable(value)
            sources = wire[:sources].to_h do |field, source|
              next [field, nil] unless source

              history = @source_history[field]
              source_observed_at = received_at - source[:age] - elapsed
              if history && source[:version] == history[:source][:version]
                source_observed_at = [source_observed_at, history[:observed_at]].min
              end
              @source_history[field] = { source: source, value: wire[field], observed_at: source_observed_at }
              [field, source.merge(age: [received_at - source_observed_at, 0.0].max)]
            end
            @last = wire
            value = value.merge(age: [received_at - observed_at, 0.0].max, sources: sources)
            fresh = value[:age] <= @max_age && sources.values.all? { |source| source && source[:age] <= @max_age }
            ready = !!(Schema.coherent?(value) && fresh && value[:readiness][:ready] == true)
            { ok: true, payload: Schema.immutable(value.merge(ready: ready)) }
          rescue StandardError
            failure('snapshot unavailable')
          ensure
            @mutex.unlock
          end
        end

        private

        def valid_snapshot?(value)
          return false unless value.is_a?(Hash) && value[:protocol_version] == PROTOCOL_VERSION &&
                              value[:identity] == @identity && Schema.age?(value[:age])

          projection = value.reject { |key, _| %i[protocol_version age].include?(key) }
          Schema.projection?(projection)
        end

        def advancing?(value)
          return true unless @last
          return false if value[:sequence] < @last[:sequence] || value[:owner_tick] < @last[:owner_tick]
          return false if value[:sequence] > @last[:sequence] && value[:owner_tick] <= @last[:owner_tick]

          value[:sources].each do |field, source|
            history = @source_history[field]
            previous = history && history[:source]
            next unless source && previous
            return false if source[:version] < previous[:version]
            if source[:version] == previous[:version]
              return false if source[:age] < previous[:age] || value[field] != history[:value] ||
                              source[:room_epoch] != previous[:room_epoch] ||
                              source[:connection_generation] != previous[:connection_generation]
            end
          end
          return true if value[:sequence] > @last[:sequence]

          without_ages(value) == without_ages(@last) && value[:age] >= @last[:age]
        end

        def without_ages(value)
          value.reject { |key, _| key == :age }.merge(
            sources: value[:sources].transform_values { |source| source&.reject { |key, _| key == :age } }
          )
        end

        def failure(message)
          { ok: false, error: message }
        end
      end
    end
  end
end
