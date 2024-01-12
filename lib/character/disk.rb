module Games
  module Gemstone
    class Disk
      NOUNS = %w{disk coffin}

      def self.is_disk?(thing)
        NOUNS.include?(thing.noun)
      end

      def self.find_by_name(name)
        disk = GameObj.loot.find do |item|
          is_disk?(item) && item.name.include?(name)
        end
        return nil if disk.nil?
        Disk.new(disk)
      end

      def self.all()
        (GameObj.loot || []).select do |item|
          is_disk?(item)
        end.map do |i|
          Disk.new(i)
        end
      end

      attr_reader :id, :name
  
      def initialize(obj)
        @id   = obj.id
        @name = obj.name.split(" ").find do |word|
          word[0].upcase.eql?(word[0])
        end
      end

      def method_missing(method, *args)
        GameObj[@id].send(method, *args)
      end

      def to_container
        if defined?(Container)
          Container.new(@id)
        else
          GameObj["#{@id}"]
        end
      end
    end
  end
end
