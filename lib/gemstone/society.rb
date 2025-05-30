# Carveout for Infomon rewrite
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
      def self.member_of
        Infomon.get("society.status")
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
      # a voln master.
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
        [self.member_of, self.rank]
      end

      ########################
      ## DEPRECATED METHODS ##
      ########################

      ##
      # @deprecated Use {#member_of} instead.
      #
      # @return [String] The name of the society: "Order of Voln", "Council of Light", "Guardians of Sunfist", or None
      def self.membership
        Lich.deprecated("Society.membership", "Society.member_of", caller[0], fe_log: false)
        Infomon.get("society.status")
      end

      ##
      # @deprecated Use {#member_of} instead.
      #
      # @return [String] The current society membership
      def self.member
        Lich.deprecated("Society.member", "Society.member_of", caller[0], fe_log: false)
        self.status.dup
      end

      ##
      # @deprecated Use {#membership} instead.
      #
      # @return [String] The current society membership
      def self.status
        Lich.deprecated("Society.status", "Society.membership", caller[0], fe_log: false)
        Infomon.get("society.status")
      end

      ##
      # @deprecated Use {#rank} instead.
      #
      # @return [Integer] The current society rank
      def self.step
        Lich.deprecated("Society.step", "Society.rank", caller[0], fe_log: false)
        self.rank
      end

      ##
      # @deprecated Use {Voln.favor} instead.
      #
      # @return [Integer] The amount of Voln favor
      def self.favor
        Lich.deprecated("Society.favor", "Society::Voln.favor", caller[0], fe_log: false)
        Infomon.get('resources.voln_favor')
      end
    end
  end
end
