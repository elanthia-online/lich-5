module Lich
  module Gemstone
    module Containers
      @@containers ||= {}

      def self.lookup!(pattern)
        #raise ArgumentError.new("cannot lookup a container using #{pattern.class.name}") unless [String, Regexp, Integer].include?(pattern.class)

        candidates = GameObj.inv.select do |item|
          case pattern
          when String
            item.name.ends_with?(pattern)
          when Regexp
            item.name.match(pattern)
          when Integer
            item.id.to_i.eql?(pattern)
          end
        end

        case candidates.size
        when 1
          return Container.new(candidates.first)
        when 0
          fail Exception, <<~ERROR
            Source(GameObj.inv)

            reason: no matches for #{pattern} found in GameObj.inv
          ERROR
        else
          fail Exception, <<~ERROR
            Source(GameObj.inv)

            reason: #{pattern.to_s} matches more than 1 container
            matches: #{candidates.map(&:name)}
          ERROR
        end
      end

      def self.define(name)
        # todo: maybe build clickable menu from GameObj.inv?
        var = Vars[name.to_s] or fail Exception, "Var[#{name}] is not set\n\t;vars set #{name}=<whatever>"
        pattern = %r[#{var}]
        @@containers[name] = Containers.lookup!(pattern)
        @@containers[name]
      end

      def self.[](name)
        return define(name) if name.is_a?(Symbol)
        self.lookup!(name)
      end

      def self.right_hand
        Container.new(GameObj.right_right)
      end

      def self.left_hand
        Container.new(GameObj.left_hand)
      end

      def self.registry
        @@containers
      end

      def self.method_missing(name, *args)
        @@containers[name] ||= self.define(name)
      end

      def self.respond_to_missing?(symbol, include_private = false)
        Vars[symbol.to_s] || super
      end
    end
  end
end