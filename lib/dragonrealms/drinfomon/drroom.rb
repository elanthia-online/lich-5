module Lich
  module DragonRealms
    class DRRoom
      @@npcs ||= []
      @@pcs ||= []
      @@group_members ||= []
      @@pcs_prone ||= []
      @@pcs_sitting ||= []
      @@dead_npcs ||= []
      @@room_objs ||= []
      @@exits ||= []
      @@title = ''
      @@description = ''

      def self.npcs
        @@npcs
      end

      def self.npcs=(val)
        @@npcs = val
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

      def self.dead_npcs
        @@dead_npcs
      end

      def self.dead_npcs=(val)
        @@dead_npcs = val
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
