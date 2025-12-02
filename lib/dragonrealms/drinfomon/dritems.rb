module Lich
  module DragonRealms
    class DRItems

      @@list ||= Array.new
      
      attr_reader :list
      
      def initialize
        @@list = Array.new
      end
      
      def self.list
        Lich.log("DRItems.list: current list='#{@@list.inspect}'")
        @@list
      end

      def self.reset
        @@list = Array.new
      end

      def self.update_item(item_string, cmd, full_description)
        # Lich.log("DRItems.update_item: item='#{item_string}', cmd='#{cmd}', full_description='#{full_description}'")
        item = Hash.new
        item[:name] = item_string
        item[:cmd] = cmd
        item[:full_description] = full_description
        # Lich.log("DRItems.update_item: storing item='#{item.inspect}'")
        @@list << item
        Lich.log("DRItems.update_item: current list='#{@@list.inspect}'")
      end
    end
  end
end
