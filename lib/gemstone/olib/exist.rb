
module Lich
  module Gemstone
    class Exist
      GETTER  = %r[\w$]
      PATTERN = %r(<a exist=(?:'|")(?<id>.*?)(?:'|") noun=(?:'|")(?<noun>.*?)(?:'|")>(?<name>.*?)</a>)

      def self.all
        [ GameObj.inv, GameObj.containers.values,
          GameObj.loot, GameObj.room_desc,
          GameObj.pcs, GameObj.npcs,
          GameObj.right_hand, GameObj.left_hand ].flatten
      end

      def self.fetch(id)
        self.all.find do |item| item.id.to_s.eql?(id.to_s) end
      end

      def self.scan(str)
        str.scan(PATTERN).map do |matches| Item.new(GameObj.new(*matches)) end
      end

      def self.normalize_type_data(type)
        (type or "").gsub(",", " ").split(" ").compact
      end

      attr_reader :id, :gameobj
      def initialize(obj)
        if obj.respond_to?(:id)
          @id = obj.id
        else
          @id = obj
        end
        self.fetch
        fail Exception, "could not find #{obj.inspect}" if @gameobj.nil?
      end

      def fetch()
        @gameobj ||= Exist.fetch(id)
      end

      def respond_to_missing?(method, *args)
        fetch.respond_to?(method) and method.to_s.match(GETTER)
      end

      def method_missing(method, *args)
        return nil if fetch.nil?

        if respond_to_missing?(method)
          fetch.send(method, *args)
        else
          super
        end
      end

      def exists?
        not GameObj[id].nil?
      end

      def gone?
        not exists?
      end

      def tags
        Exist.normalize_type_data("#{type},#{sellable}").map(&:to_sym)
      end

      def effects
        (status or "").split(",").map(&:to_sym)
      end

      def to_h()
        {id: id, name: name, noun: noun}
      end

      def ==(other)
        id.to_s.eql?(other.id.to_s)
      end

      alias_method :eql?, :==

      def to_s()
        inspect()
      end

      def deconstruct_keys(keys)
        keys.each_with_object({}) do |key, acc|
          acc[key] = self.send(key)
        end
      end
    end
  end
end