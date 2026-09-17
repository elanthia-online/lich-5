# frozen_string_literal: true

require 'json'

require_relative 'contract'

module Lich
  module WebUI
    # Serializes the contract to JSON so a NON-RUBY client can be generated
    # from it instead of hand-tracking it.
    #
    # The contract is already machine-readable -- {Contract.schemas} resolves
    # properties, required flags, children rules, events, value types and
    # scope for every type. What it was not, until this, is *reachable* from
    # outside Ruby. A second renderer (VellumFE's native panels) therefore
    # maintained its own hand-written copy of the vocabulary, and the two
    # drifted in both directions without anything noticing: VellumFE grew
    # four component types the contract never defined, and missed twelve it
    # did.
    #
    # Emitting the contract as data makes the contract the single source of
    # truth in fact and not just in intent. A client generates its types from
    # this file, so a new component type becomes a compile error naming what
    # is unhandled rather than a silently-unrendered box.
    #
    # == Stability
    #
    # The payload is a direct projection of {Contract.schemas}; it is not a
    # second schema language that could itself drift. Ruby symbols become
    # strings (JSON has no symbol), which is the only transformation applied.
    # Everything else -- nesting, key names, value shapes -- is passed through,
    # so a consumer reads the same structure the validator enforces.
    #
    # `contract_version` and `contract_major` are the negotiation handles:
    # a consumer compares majors, exactly as {Contract.negotiate!} does on
    # the server side.
    module Export
      # Schema-of-the-export, bumped when THIS file's envelope changes shape
      # (not when the contract it carries does). A consumer that understands
      # envelope 1 can read any contract version delivered inside it.
      ENVELOPE_VERSION = 1

      module_function

      # The whole contract as plain JSON-ready data.
      #
      # @return [Hash] string-keyed, symbol-free, ready for JSON.generate
      def payload
        {
          'envelope_version' => ENVELOPE_VERSION,
          'contract_version' => Contract::VERSION,
          'contract_major'   => Contract::MAJOR_VERSION,
          'types'            => Contract::TYPES.map(&:to_s),
          'tones'            => Contract::TONES.dup,
          'emphases'         => Contract::EMPHASES.dup,
          'aligns'           => Contract::ALIGNS.dup,
          'bounds'           => stringify(Contract::BOUNDS),
          'schemas'          => stringify(Contract.schemas)
        }
      end

      # @return [String] pretty JSON, newline-terminated so the file is a
      #   well-formed text file and diffs cleanly.
      def to_json_text
        "#{JSON.pretty_generate(payload)}\n"
      end

      # Writes the export, creating parent directories as needed.
      #
      # @param path [String]
      # @return [String] the path written
      def write(path)
        require 'fileutils'
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, to_json_text)
        path
      end

      # Recursively converts symbols (keys and values) to strings and ranges
      # to explicit min/max records.
      #
      # Symbols are how the contract spells enum members, scopes and type
      # names; JSON cannot carry them, and a consumer should not have to
      # guess which strings were once symbols. Ranges appear in BOUNDS
      # (`geometry`, `timeout`) and become `{"min":...,"max":...}` so a client
      # reads bounds uniformly rather than parsing "a..b".
      def stringify(value)
        case value
        when Hash
          value.to_h { |k, v| [k.to_s, stringify(v)] }
        when Array
          value.map { |v| stringify(v) }
        when Symbol
          value.to_s
        when Range
          { 'min' => value.begin, 'max' => value.end }
        when Regexp
          value.source
        else
          value
        end
      end
    end
  end
end
