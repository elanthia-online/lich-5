module Lich
  module DragonRealms
    class DRItems
      @@list ||= Array.new

      attr_reader :list

      def initialize
        @@list = Array.new
      end

      def self.list
        @@list
      end

      def self.reset
        @@list = Array.new
      end

      def self.update_item(item_string, cmd, full_description)
        item = Hash.new
        item[:name] = item_string
        item[:cmd] = cmd
        item[:full_description] = full_description
        @@list << item
      end
    end
  end
end
