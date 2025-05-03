# Carveout for Infomon rewrite
module Lich
  module Gemstone
    module Society
      class Society
        # @return [String] The name of the society: "Order of Voln", "Council of Light", "Guardians of Sunfist", or None
        def self.membership
          Infomon.get("society.status")
        end

        # Determines if the character is a member of a given society, and optionally at a specific rank.
        #
        # @param society_name [String] The name of the society to check
        # @param rank [Integer, nil] The optional rank to verify
        # @return [Boolean] True if the character is a member of the given society (and at the rank, if specified), false otherwise
        def self.memberOf?(society_name, rank = nil)
          status = Infomon.get("society.status").to_s.downcase
          return false unless status == society_name.to_s.downcase

          rank.nil? || Infomon.get("society.rank") == rank
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

        # @deprecated Use {#membership} instead.
        # @return [String] The current society membership
        def self.member
          Lich.deprecated("Society.member", "Society.membership", caller[0], fe_log: true)
          self.status.dup
        end

        # @deprecated Use {#membership} instead.
        # @return [String] The current society membership
        def self.status
          Lich.deprecated("Society.status", "Society.membership", caller[0], fe_log: true)
          Infomon.get("society.status")
        end

        # @deprecated Use {#rank} instead.
        # @return [Integer] The current society rank
        def self.step
          Lich.deprecated("Society.step", "Society.rank", caller[0], fe_log: true)
          self.rank
        end

        # @deprecated Use {Voln.favor} instead.
        # @return [Integer] The amount of Voln favor
        def self.favor
          Lich.deprecated("Society.favor", "Society::Voln.favor", caller[0], fe_log: true)
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
end
