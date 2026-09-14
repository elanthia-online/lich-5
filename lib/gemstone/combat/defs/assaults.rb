# frozen_string_literal: true

require_relative 'pattern_gate'

module Lich
  module Gemstone
    module Combat
      module Definitions
        # Assault pattern definitions.
        #
        # An ASSAULT is a single-target multi-round attack (flurry, barrage,
        # pummel, guardant thrusts, thrash): the assault_start line names the
        # ONLY target the whole assault can strike, the rounds in between
        # usually name no target at all (only incidental flares/crits do), and
        # the assault_end line closes it - the attacker cannot perform other
        # attacks until it ends. The target dying ends the assault early via
        # the normal end line.
        #
        # Distinct from Sequences (multi-TARGET brackets: mstrike, volley,
        # spawned AoE casts) - an assault's opener target is carried by the
        # processor onto every targetless round inside the bracket.
        module Assaults
          # One assault definition.
          #
          # @!attribute name
          #   @return [Symbol] assault identifier (e.g. +:flurry+)
          # @!attribute start_patterns
          #   @return [Array<Regexp>] opener lines; may capture +target+
          # @!attribute end_patterns
          #   @return [Array<Regexp>] closing lines (completion or broken assault)
          AssaultDef = Struct.new(:name, :start_patterns, :end_patterns)

          # All known assault definitions.
          # @return [Array<AssaultDef>]
          ASSAULT_DEFS = [
            AssaultDef.new(:flurry, [
              /You rotate your wrist, your .+? executing a casual spin to establish your flow as you advance upon (?<target>.+?)!/,
              /You rotate your wrists, your .+? and .+? executing a casual spin to establish your flow as you advance upon (?<target>[^!]+)!/
            ].freeze, [
              /The mesmerizing sway of body and blade glides to its inevitable end with one final twirl of (?:your|.+?'s) .+?\./,
              /Distracted, you hesitate, and your assault is broken\.  You give your blades a quick, sweeping flick of annoyance as you lower them\./
            ].freeze),
            # Barrage's opener names no target; the processor backfills the
            # assault target from the first named line inside the bracket.
            AssaultDef.new(:barrage, [
              /Drawing several arrows from your .+?, you grip them loosely between your fingers in preparation for a rapid barrage\./
            ].freeze, [
              /Upon firing your last arrow, you release a measured breath and lower your .+?\./,
              /Distracted, you hesitate, and your assault is broken\.  Frustrated, you return your remaining arrows\./
            ].freeze),
            AssaultDef.new(:pummel, [
              /You take a menacing step toward (?<target>.+?), sweeping your .+? out low to your side in your advance\./
            ].freeze, [
              /With a final snap of your wrist, you sweep your .+? back to the ready, your assault complete\./,
              /Distracted, you hesitate, and in doing so lose the rhythm of your assault\.  You return to the ready with a final, frustrated flick of your .+?\./
            ].freeze),
            AssaultDef.new(:guardant_thrust, [
              /Retaining a defensive profile, you raise your .+? in a hanging guard and prepare to unleash a barrage of guardant thrusts upon (?<target>[^!]+)!/
            ].freeze, [
              /You complete your assault, your weight on your rear foot as you snap your .+? back to a defensive angle\./,
              /Distracted, you hesitate, and in doing so lose the rhythm of your assault\.  You shift your grip on your .+? to a more neutral position and watch for new opportunities\./
            ].freeze),
            AssaultDef.new(:thrash, [
              /You rush (?<target>.+?), raising your .+? high to deliver a sound thrashing!/
            ].freeze, [
              /With a final, explosive breath, you pull your .+? back to a ready position\./,
              /Distracted, you hesitate, and in doing so lose the rhythm of your assault\.  You pull your .+? back to a ready position with a wary eye to your environs\./
            ].freeze)
          ].freeze

          # Flattened +[pattern, assault_name]+ pairs for opener lines.
          # @return [Array<Array(Regexp, Symbol)>]
          START_LOOKUP = ASSAULT_DEFS.flat_map { |d| d.start_patterns.map { |rx| [rx, d.name] } }.freeze

          # Flattened +[pattern, assault_name]+ pairs for closing lines.
          # @return [Array<Array(Regexp, Symbol)>]
          END_LOOKUP = ASSAULT_DEFS.flat_map { |d| d.end_patterns.map { |rx| [rx, d.name] } }.freeze

          # Fast-reject gates built from the lookup patterns (see PatternGate):
          # the gate is a single union regexp of literal prefixes, and the
          # +ALWAYS+ list holds patterns with no usable literal prefix.
          START_GATE, START_ALWAYS = PatternGate.build(START_LOOKUP.map(&:first))
          END_GATE, END_ALWAYS     = PatternGate.build(END_LOOKUP.map(&:first))

          # Parse an assault opener line.
          #
          # @param line [String] a single line of game text
          # @return [Hash{Symbol=>Symbol,String,nil}, nil] +{name:, target:}+
          #   for an assault_start line, or +nil+ if the line is not one.
          #   +:target+ is the raw capture text (nil when the opener names
          #   none, e.g. barrage) - the caller binds it to a creature id
          #   via the line's own link extraction.
          def self.parse_start(line)
            return nil unless START_GATE.match?(line) || START_ALWAYS.any? { |rx| rx.match?(line) }

            START_LOOKUP.each do |rx, name|
              next unless (m = rx.match(line))

              target = m.names.include?('target') ? m[:target] : nil
              return { name: name, target: target }
            end
            nil
          end

          # Parse an assault closing line.
          #
          # @param line [String] a single line of game text
          # @return [Symbol, nil] assault name whose end line this is, or
          #   +nil+ if the line is not an assault_end line
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
