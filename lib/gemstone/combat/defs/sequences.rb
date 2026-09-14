# frozen_string_literal: true

#
# Sequence Pattern Definitions
# Converted from ctparser/SEQUENCE_DEFS to Lich::Gemstone::Combat namespace
#
# A sequence brackets a multi-part combat action: the start line announces
# it, per-target attack events unfold inside it, and the end line closes
# it. Used to attribute spawned casts (a Blink flare firing an imbedded
# Nature's Fury produces a full AoE sequence whose per-target events are
# children of the flare, not independent casts) and to bound multi-TARGET
# attacks like mstrike and volley. Single-target multi-round attacks
# (flurry, barrage, pummel...) are ASSAULTS - see defs/assaults.rb.
#

require_relative 'pattern_gate'

module Lich
  module Gemstone
    module Combat
      module Definitions
        module Sequences
          SequenceDef = Struct.new(:name, :start_patterns, :end_patterns)

          SEQUENCE_DEFS = [
            SequenceDef.new(:earthen_fury, [
              /The ground beneath (?<target>.+?) begins to boil violently!/,
              /The ground beneath (?<target>.+?) suddenly frosts and rumbles violently!/,
              /The ground beneath (?<target>.+?) boils with renewed vigor!/,
              /The ground beneath (?<target>.+?) rumbles with renewed vigor!/
            ].freeze, [/The ground beneath (?<target>.+?) suddenly calms\./].freeze),
            SequenceDef.new(:mstrike, [
              /With great haste, you let loose a volley of shots!/,
              /With instinctive motions, you weave to and fro striking with deliberate and unrelenting fury!/,
              /You explode into a fury of strikes and ripostes, moving with a singular purpose and will!/
            ].freeze, [
              /Your series of strikes and ripostes leaves you winded and out of position./,
              /Your series of strikes and ripostes leaves you off-balance and out of position./,
              /Your series of rapid shots and maneuvers leaves you off-balance and out of position./
            ].freeze),
            SequenceDef.new(:natures_fury, [
              /You close your eyes in a moment of intense concentration, channeling the pure natural power of your surroundings\./
            ].freeze, [/As swiftly as the chaos came to be, it recedes again into the surroundings\./].freeze),
            # Volley: the hail-shadow line opens EVERY round (rounds 2+ have
            # no bow line); per-arrow :volley attack events unfold inside.
            # The 2p bow-raise line is this sequence's PREFIX - not a def.
            SequenceDef.new(:volley, [
              /An ominous shadow falls over your surroundings as a whistling hail of arrows arcs down from above!/
            ].freeze, [/The air clears as the deadly volley of arrows abates\./].freeze)
          ].freeze

          START_LOOKUP = SEQUENCE_DEFS.flat_map { |d| d.start_patterns.map { |rx| [rx, d.name] } }.freeze
          END_LOOKUP   = SEQUENCE_DEFS.flat_map { |d| d.end_patterns.map { |rx| [rx, d.name] } }.freeze

          START_GATE, START_ALWAYS = PatternGate.build(START_LOOKUP.map(&:first))
          END_GATE, END_ALWAYS     = PatternGate.build(END_LOOKUP.map(&:first))

          # @return [Symbol, nil] sequence name whose start line this is
          def self.parse_start(line)
            return nil unless START_GATE.match?(line) || START_ALWAYS.any? { |rx| rx.match?(line) }

            START_LOOKUP.each { |rx, name| return name if rx.match?(line) }
            nil
          end

          # @return [Symbol, nil] sequence name whose end line this is
          def self.parse_end(line)
            return nil unless END_GATE.match?(line) || END_ALWAYS.any? { |rx| rx.match?(line) }

            END_LOOKUP.each { |rx, name| return name if rx.match?(line) }
            nil
          end
        end
      end
    end
  end
end
