module Lich
  module Gemstone
    class Container < Exist
      include Enumerable

      def initialize(obj)
        super(obj)
        fput "look in ##{obj.id}" unless GameObj.containers.fetch(id, false)
      end

      def check_contents
        fput %w(table).include?(noun) ? "look on ##{id}" : "look in ##{id}"
      end

      def contents
        GameObj.containers.fetch(id, []).map do |item| Item.new(item, self) end
      end

      def closed?
        not GameObj.containers[id]
      end

      def each(&block)
        contents.each(&block)
      end

      # def where(**query)
      #   contents.select(&Where[**query])
      # end

      # def rummage
      #   Rummage.new(self)
      # end


      def add(*items)
        items.flatten.each do |item|
          Command.try_or_fail(command: "_drag ##{item.id} ##{id}") do
            contents.map(&:id).include?(item.id.to_s)
          end
        end
      end
    end
  end
end