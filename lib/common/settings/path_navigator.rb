module Lich
  module Common
    # Path navigator to encapsulate path navigation logic
    class PathNavigator
      def initialize(db_adapter)
        @db_adapter = db_adapter
        @path = []
      end

      attr_reader :path

      def reset_path
        @path = []
      end

      def reset_path_and_return(value)
        reset_path
        value
      end

      def navigate_to_path(script_name, create_missing = true, scope = ":")
        root = @db_adapter.get_settings(script_name, scope)
        return [root, root] if @path.empty?

        target = root
        @path.each do |key|
          if target.is_a?(Hash) && target.key?(key)
            target = target[key]
          elsif target.is_a?(Array) && key.is_a?(Integer) && key < target.length
            target = target[key]
          elsif create_missing
            # Path doesn't exist yet, create it
            target[key] = key.is_a?(Integer) ? [] : {}
            target = target[key]
          else
            # Path doesn't exist and we're not creating it
            return [nil, root]
          end
        end

        [target, root]
      end
    end
  end
end
