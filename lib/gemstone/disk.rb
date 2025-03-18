module Lich
  module Gemstone
    class Disk
      NOUNS = %w{cassone chest coffer coffin coffret disk hamper saucer sphere trunk tureen}

      def self.is_disk?(thing)
        thing.name =~ /\b([A-Z][a-z]+) #{Regexp.union(NOUNS)}\b/
      end

      def self.find_by_name(name)
        disk = GameObj.loot.find do |item|
          is_disk?(item) && item.name.include?(name)
        end
        return nil if disk.nil?
        Disk.new(disk)
      end

      def self.mine
        find_by_name(Char.name)
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

      def ==(other)
        other.is_a?(Disk) && other.id == self.id
      end

      def eql?(other)
        self == other
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
