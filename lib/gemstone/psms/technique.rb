module Lich
  module Gemstone
    module PSMS
      # Behaviour shared by every technique category (CMan, Shield, Weapon,
      # Feat, Armor, Warcry). A category module keeps its own table of
      # techniques, then extends this module and registers the table:
      #
      #   module CMan
      #     @@combat_mans = { "bull_rush" => { short_name: "bullrush", ... }, ... }
      #     extend PSMS::Technique
      #     techniques @@combat_mans, type: "CMan", verb: "cman"
      #   end
      #
      # A category that behaves differently overrides the method on itself
      # (+def Weapon.use+) and calls +super+ for the shared behaviour.
      #
      # Table entry keys:
      #   - +:short_name+ [String] the name Infomon tracks the rank under
      #   - +:type+ [Symbol] :setup, :attack, :area_of_effect, :assault, :buff, :passive, ...
      #   - +:cost+ [Hash] e.g. { stamina: 10 }
      #   - +:cooldown_cost+ [Hash, optional] the cost while the technique's own cooldown is active
      #   - +:target_cost+ [Hash, optional] the cost when used on a single target
      #   - +:regex+ [Regexp] the line(s) that answer the technique's command
      #   - +:usage+ [String, nil, optional] the command word; nil for techniques that
      #     cannot be used; +:short_name+ when absent
      #   - +:buff+ [String, Regexp, optional] the Effects::Buffs entry the technique grants
      #   - +:ignorable_cooldown+ [Boolean, optional] whether +ignore_cooldown: true+ applies
      module Technique
        # Registers the category's technique table, and defines a rank getter
        # for every technique by short and long name (+CMan.bullrush+,
        # +CMan.bull_rush+) and the category's +<type>_lookups+.
        #
        # @param table [Hash{String => Hash}] technique entries by long name
        # @param type [String] the category name PSMS knows it by ("CMan")
        # @param verb [String] the command verb ("cman")
        # @return [void]
        def techniques(table, type:, verb:)
          @table = table
          @type = type
          @verb = verb
          define_singleton_method("#{type.downcase}_lookups") { lookups }
          table.each do |long_name, psm|
            define_singleton_method(psm[:short_name]) { self[psm[:short_name]] }
            define_singleton_method(long_name) { self[psm[:short_name]] }
          end
        end

        # @return [Array<Hash>] each technique's :long_name, :short_name and base :cost
        def lookups
          @table.map { |long_name, psm| { long_name: long_name, short_name: psm[:short_name], cost: psm[:cost] } }
        end

        # A technique's table entry.
        #
        # @param name [String, Symbol] long or short name, in any case or spacing
        # @return [Hash]
        # @raise [ArgumentError] if the name is not a technique in this category
        def technique(name)
          find(name).last
        end

        # The rank known of a technique.
        #
        # @param name [String, Symbol] the technique name
        # @return [Integer] 0 when unknown
        def [](name)
          Infomon.get("#{@type.downcase}.#{technique(name)[:short_name]}").to_i
        end

        # @param name [String, Symbol] the technique name
        # @param min_rank [Integer] the rank to test against (default: 1, so known at all)
        # @return [Boolean]
        def known?(name, min_rank: 1)
          self[name] >= [min_rank, 1].max
        end

        # What a technique costs right now: its +:cooldown_cost+ while its own
        # cooldown is active, its +:target_cost+ when aimed at a single target,
        # else its +:cost+.
        #
        # @param name [String, Symbol] the technique name
        # @param target [String, Integer, GameObj] the target it will be used on
        # @return [Hash] e.g. { stamina: 30 }
        def cost(name, target: "")
          long_name, psm = find(name)
          return psm[:cooldown_cost] if psm[:cooldown_cost] && PSMS.effect_active?(Effects::Cooldowns, long_name)
          return psm[:target_cost] if psm[:target_cost] && PSMS.single_target?(target)

          psm[:cost]
        end

        # @param name [String, Symbol] the technique name
        # @param target [String, Integer, GameObj] the target it will be used on
        # @param forcert_count [Integer] FORCERTs used, including this one
        # @return [Boolean] whether the character can pay for the technique
        def affordable?(name, target: "", forcert_count: 0)
          return true if waived?(technique(name), :cost)

          PSMS.cost_affordable?(cost(name, target: target), forcert_count: forcert_count)
        end

        # Whether a technique can be used right now: known, affordable, off
        # cooldown (unless ignored), and the character is not overexerted.
        #
        # @param name [String, Symbol] the technique name
        # @param target [String, Integer, GameObj] the target it will be used on
        # @param ignore_cooldown [Boolean] skip the cooldown check, for techniques that allow it
        # @param min_rank [Integer] the rank required (default: 1)
        # @param forcert_count [Integer] FORCERTs used, including this one
        # @return [Boolean]
        def available?(name, target: "", ignore_cooldown: false, min_rank: 1, forcert_count: 0)
          long_name, psm = find(name)
          return false unless known?(name, min_rank: min_rank)
          return false unless affordable?(name, target: target, forcert_count: forcert_count)

          ignore = cooldown_ignored?(psm, ignore_cooldown)
          [long_name, name.to_s].uniq.all? { |n| PSMS.available?(n, ignore) }
        end

        # @param name [String, Symbol] the technique name
        # @return [Boolean] whether the buff the technique grants is active
        def buff_active?(name)
          buff = technique(name)[:buff]
          !buff.nil? && PSMS.effect_active?(Effects::Buffs, buff)
        end

        # Uses a technique if it is available, waiting out roundtime first
        # unless using FORCERT.
        #
        # @param name [String, Symbol] the technique name
        # @param target [String, Integer, GameObj] the target; the character when omitted
        # @param ignore_cooldown [Boolean] skip the cooldown check, for techniques that allow it
        # @param results_of_interest [Regexp, nil] extra lines to return on
        # @param forcert_count [Integer] FORCERTs used, including this one
        # @return [String, false, nil] the answering line, false on timeout, nil when not used
        def use(name, target = "", ignore_cooldown: false, results_of_interest: nil, forcert_count: 0)
          return unless available?(name, target: target, ignore_cooldown: ignore_cooldown, forcert_count: forcert_count)

          usage_cmd = command(name, target, forcert_count: forcert_count)
          return if usage_cmd.nil?

          # with forcert we don't want to wait for rt, but we need to otherwise
          unless forcert_count > 0
            waitrt?
            waitcastrt?
          end

          PSMS.dispatch(usage_cmd, results_regex(name, results_of_interest: results_of_interest))
        end

        # The command {#use} sends, without sending it.
        #
        # @param name [String, Symbol] the technique name
        # @param target [String, Integer, GameObj] the target (optional)
        # @param forcert_count [Integer] more than 0 appends FORCERT
        # @return [String, nil] e.g. "cman bullrush #12345", nil when the technique cannot be used
        def command(name, target = "", forcert_count: 0)
          psm = technique(name)
          usage = psm.key?(:usage) ? psm[:usage] : psm[:short_name]
          return nil if usage.nil?

          PSMS.command(verb_for(usage), usage, target, forcert_count: forcert_count)
        end

        # Every line that answers the technique's command: the regex {#use} waits on.
        #
        # @param name [String, Symbol] the technique name
        # @param results_of_interest [Regexp, nil] extra lines to match
        # @return [Regexp]
        def results_regex(name, results_of_interest: nil)
          PSMS.results_regex(name, regexp(name), PSMS::ROUNDTIME_REGEX, results_of_interest: results_of_interest)
        end

        # The line(s) that answer the technique's command. A match means the
        # technique was attempted, not that it succeeded.
        #
        # @param name [String, Symbol] the technique name
        # @return [Regexp]
        def regexp(name)
          technique(name)[:regex]
        end

        # Declares a buff under which the category's techniques (or only those
        # of one type) cost nothing and/or skip their cooldown check. Cost and
        # cooldown are separate, since a buff can waive one without the other.
        #
        # @param buff [String, Regexp] the Effects::Buffs entry
        # @param type [Symbol, nil] limit to techniques of this :type; nil for all
        # @param affects [Symbol, Array<Symbol>] :cost, :cooldown, or both
        # @return [void]
        # @example
        #   free_under "Glorious Momentum", type: :area_of_effect
        #   free_under "Ardor of the Scourge", type: :assault, affects: :cooldown
        def free_under(buff, type: nil, affects: %i[cost cooldown])
          (@free_conditions ||= []) << { buff: buff, type: type, affects: Array(affects) }
        end

        # @api private
        # The command verb for a usage word. Overridden by categories with bare commands.
        def verb_for(_usage)
          @verb
        end

        private

        # Whether the cooldown check is skipped: on request for techniques that
        # allow it, or under a {#free_under} buff.
        def cooldown_ignored?(psm, ignore_cooldown)
          (ignore_cooldown && psm[:ignorable_cooldown] == true) || waived?(psm, :cooldown)
        end

        # Whether an active {#free_under} buff waives +aspect+ (:cost or :cooldown) for the technique.
        def waived?(psm, aspect)
          (@free_conditions || []).any? do |c|
            c[:affects].include?(aspect) &&
              (c[:type].nil? || psm[:type] == c[:type]) &&
              PSMS.effect_active?(Effects::Buffs, c[:buff])
          end
        end

        # @return [Array(String, Hash)] the technique's long name and table entry
        def find(name)
          normal = PSMS.name_normal(name)
          return [normal, @table[normal]] if @table.key?(normal)

          @table.find { |_, psm| psm[:short_name] == normal } || PSMS.invalid_technique!(normal, @type)
        end
      end
    end
  end
end
