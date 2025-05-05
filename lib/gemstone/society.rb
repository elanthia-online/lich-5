# Carveout for Infomon rewrite
module Lich
  module Gemstone
    class Society
      # Determines character's society membership
      # @return [String] The name of the society: "Order of Voln", "Council of Light", "Guardians of Sunfist", or None
      def self.member_of
        Infomon.get("society.status")
      end

      # @return [Integer] The rank number or 0 if not a member
      def self.rank
        Infomon.get("society.rank")
      end

      # @return [String] The current society task, or "You are not currently in a society." if not a member, or
      # "It is your eternal duty to release undead creatures from their suffering in the name of the Great Spirit Voln." if
      # a voln master.
      def self.task
        XMLData.society_task
      end

      ## DEPRECATED METHODS ##

      # @deprecated Use {#member_of} instead.
      # @return [String] The name of the society: "Order of Voln", "Council of Light", "Guardians of Sunfist", or None
      def self.membership
        Lich.deprecated("Society.membership", "Society.member_of", caller[0], fe_log: false)
        Infomon.get("society.status")
      end

      # @deprecated Use {#member_of} instead.
      # @return [String] The current society membership
      def self.member
        Lich.deprecated("Society.member", "Society.member_of", caller[0], fe_log: false)
        self.status.dup
      end

      # @deprecated Use {#membership} instead.
      # @return [String] The current society membership
      def self.status
        Lich.deprecated("Society.status", "Society.membership", caller[0], fe_log: false)
        Infomon.get("society.status")
      end

      # @deprecated Use {#rank} instead.
      # @return [Integer] The current society rank
      def self.step
        Lich.deprecated("Society.step", "Society.rank", caller[0], fe_log: false)
        self.rank
      end

      # @deprecated Use {Voln.favor} instead.
      # @return [Integer] The amount of Voln favor
      def self.favor
        Lich.deprecated("Society.favor", "Society::Voln.favor", caller[0], fe_log: false)
        Infomon.get('resources.voln_favor')
      end

      # Serializes the current society status and rank.
      #
      # @return [Array<(String, Integer)>] An array containing the society status and rank
      def self.serialize
        [self.status, self.rank]
      end
    end
  end
end
