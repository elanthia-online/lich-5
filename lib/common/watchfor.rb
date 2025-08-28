# Carve out class WatchFor
# 2024-06-13
# has rubocop Lint issues (return nil) - overriding until it can be further researched

module Lich
  module Common
    class Watchfor
      # rubocop:disable Lint/ReturnInVoidContext
      def initialize(line, theproc = nil, &block)
        return nil unless (script = Script.current)

        if line.is_a?(String)
          line = Regexp.new(Regexp.escape(line))
        elsif !line.is_a?(Regexp)
          echo 'watchfor: no string or regexp given'
          return nil
        end
        if block.nil?
          if theproc.respond_to? :call
            block = theproc
          else
            echo 'watchfor: no block or proc given'
            return nil
          end
        end
        script.watchfor[line] = block
      end

      # rubocop:enable Lint/ReturnInVoidContext
      def Watchfor.clear
        script.watchfor = Hash.new
      end
    end
  end
end
