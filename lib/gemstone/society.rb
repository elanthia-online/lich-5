require_relative '../util/util.rb' # needed to ensure it loads before Society tries to load

module Lich
  module Gemstone
    ##
    # The Society class provides accessors for a character's society membership, rank, and task data.
    #
    # All methods rely on Infomon or XMLData, and a future rewrite might shift responsibility to
    # character-specific data models or direct game scraping.
    class Society
      ##
      # Retrieves the character's society membership status.
      #
      # @return [String, nil] The name of the society:
      #   - "Order of Voln"
      #   - "Council of Light"
      #   - "Guardians of Sunfist"
      #   - or `nil`/"None" if not a member
      def self.membership
        Infomon.get("society.status")
      end

      ##
      # Retrieves the character's society membership status.
      #
      # @return [String, nil] The name of the society:
      #   - "Order of Voln"
      #   - "Council of Light"
      #   - "Guardians of Sunfist"
      #   - or `nil`/"None" if not a member
      def self.status
        self.membership
      end

      ##
      # Retrieves the character's current rank within their society.
      #
      # @return [Integer] The rank number, or 0 if not a member
      def self.rank
        Infomon.get("society.rank")
      end

      ##
      # Retrieves the current task assigned by the society, if any.
      #
      # The current society task, or "You are not currently in a society." if not a member, or
      # "It is your eternal duty to release undead creatures from their suffering in the name of the Great Spirit Voln." if
      # a Voln Master.
      #
      # @return [String] The current society task message.
      #   Examples:
      #   - A task description
      #   - "You are not currently in a society."
      #   - "It is your eternal duty to release undead creatures..." (Voln masters)
      def self.task
        XMLData.society_task
      end

      ##
      # Bundles the current society status and rank into a simple structure.
      #
      # @return [Array<(String, Integer)>] An array in the format `[status, rank]`
      def self.serialize
        [self.membership, self.rank]
      end

      ########################
      ## DEPRECATED METHODS ##
      ########################

      ##
      # @deprecated Use {#member_of} instead.  Deprecated 6/2025
      #
      # @return [String] The current society membership
      def self.member
        Lich.deprecated("Society.member", "Society.membership", caller[0], fe_log: false)
        self.membership
      end

      ##
      # @deprecated Use {#rank} instead.  Deprecated 6/2025
      #
      # @return [Integer] The current society rank
      def self.step
        Lich.deprecated("Society.step", "Society.rank", caller[0], fe_log: false)
        self.rank
      end

      ##
      # @deprecated Use {OrderOfVoln.favor} instead.  Deprecated 6/2025
      #
      # @return [Integer] The amount of Voln favor
      def self.favor
        Lich.deprecated("Society.favor", "Society::OrderOfVoln.favor", caller[0], fe_log: false)
        # Infomon.get('resources.voln_favor')
        Societies::OrderOfVoln.favor
      end

      ##
      # Looks up an ability definition from a society hash using a normalized short or long name.
      #
      # @param name [String] The user-facing name (short or long) of the ability
      # @param entries [Hash<String, Hash>] The base hash keyed by short_name
      # @param lookups [Array<Hash>] An array of hashes containing at least `:short_name` and `:long_name`
      # @return [Hash, nil] The matching entry from the base hash, or nil if not found
      #
      def self.lookup(name, lookups)
        normalized = Lich::Util.normalize_name(name)

        lookups.find do |entry|
          [entry[:short_name], entry[:long_name]]
            .compact
            .map { |n| Lich::Util.normalize_name(n) }
            .include?(normalized)
        end
      end

      ##
      # Resolves a value that may be a static literal or a lambda/proc.
      #
      # If the value responds to `:call` (i.e., is a `Proc` or `lambda`), it is called and
      # the result is returned. Otherwise, the value is returned as-is.
      #
      # This allows society metadata fields such as `:duration` or `:summary` to be defined
      # as either static values or dynamically evaluated lambdas.
      #
      # @param value [Object, Proc] The value to resolve
      # @return [Object] The resolved value, or the original value if not callable
      #
      def self.resolve(value, context = nil)
        return value.call if value.respond_to?(:call) && value.arity == 0
        return value.call(context) if value.respond_to?(:call) && value.arity == 1
        value
      end

      ##
      # Defines singleton accessors for both short and long names on a given target class.
      #
      # Method names are normalized using {Lich::Util.normalize_name}, which ensures
      # compatibility with Ruby method naming (e.g., downcased, underscores instead of spaces, etc.).
      #
      # Example:
      #   "Symbol of Recognition" => `symbol_of_recognition`
      #   "Kai's Strike"          => `kais_strike`
      #
      # @param target_class [Class] The class to define singleton methods on (typically `self`)
      # @param data [Hash<String, Hash>] The metadata hash (e.g., `@@voln_symbols`)
      #
      def self.define_name_methods(target_class, data)
        data.values.each do |entry|
          short_method = Lich::Util.normalize_name(entry[:short_name])
          long_method  = Lich::Util.normalize_name(entry[:long_name])

          target_class.define_singleton_method(short_method) { target_class[entry[:short_name]] }
          target_class.define_singleton_method(long_method)  { target_class[entry[:short_name]] }
        end
      end
    end
  end
end

# these are at the bottom because Society has to be loaded first before the sub-classes can be loaded
require_relative 'societies/council_of_light.rb'
require_relative 'societies/guardians_of_sunfist.rb'
require_relative 'societies/order_of_voln.rb'

# This module provides a simple namespace for accessing society classes.
module Lich::Gemstone::Societies
  def self.voln
    OrderOfVoln
  end

  def self.col
    CouncilOfLight
  end

  def self.sunfist
    GuardiansOfSunfist
  end
end
