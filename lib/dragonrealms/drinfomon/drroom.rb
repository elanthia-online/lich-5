# frozen_string_literal: true

module Lich
  module DragonRealms
    class DRRoom
      @@npcs ||= [].freeze
      @@pcs ||= []
      @@group_members ||= []
      @@pcs_prone ||= []
      @@pcs_sitting ||= []
      @@dead_npcs ||= [].freeze
      @@room_objs ||= []
      @@exits ||= []
      # NOTE: @@title and @@description removed - getters delegate to XMLData

      # Living NPC nouns in the room, sorted, duplicates repeated
      # (["goblin", "goblin"]). Read-only: every script shares this array, so it
      # is frozen; take a copy (`DRRoom.npcs.dup`) to edit. Address a particular
      # creature by its Lich::DragonRealms::Creature id, not by position.
      # @return [Array<String>] frozen
      def self.npcs
        @@npcs
      end

      # Stores a frozen copy, leaving the caller's array untouched.
      # @param val [Array<String>]
      def self.npcs=(val)
        @@npcs = val.dup.freeze
      end

      def self.pcs
        @@pcs
      end

      def self.pcs=(val)
        @@pcs = val
      end

      def self.exits
        XMLData.room_exits
      end

      def self.title
        XMLData.room_title
      end

      def self.description
        XMLData.room_description
      end

      def self.group_members
        @@group_members
      end

      def self.group_members=(val)
        @@group_members = val
      end

      def self.pcs_prone
        @@pcs_prone
      end

      def self.pcs_prone=(val)
        @@pcs_prone = val
      end

      def self.pcs_sitting
        @@pcs_sitting
      end

      def self.pcs_sitting=(val)
        @@pcs_sitting = val
      end

      # Dead NPC nouns in the room; same shape and rules as {.npcs}.
      # @return [Array<String>] frozen
      def self.dead_npcs
        @@dead_npcs
      end

      # Stores a frozen copy, leaving the caller's array untouched.
      # @param val [Array<String>]
      def self.dead_npcs=(val)
        @@dead_npcs = val.dup.freeze
      end

      def self.room_objs
        @@room_objs
      end

      def self.room_objs=(val)
        @@room_objs = val
      end
    end
  end
end
