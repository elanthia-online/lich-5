# frozen_string_literal: true

module Lich
  module Gemstone
    # Gift class for tracking gift box status
    class Gift
      class << self
        attr_reader :gift_start, :pulse_count

        def init_gift
          @gift_start = Time.now
          @pulse_count = 0
        end

        def started
          @gift_start = Time.now
          @pulse_count = 0
        end

        def pulse
          @pulse_count += 1
        end

        def remaining
          ([360 - @pulse_count, 0].max * 60).to_f
        end

        def restarts_on
          @gift_start + 594000
        end

        def serialize
          [@gift_start, @pulse_count]
        end

        def load_serialized=(array)
          @gift_start = array[0]
          @pulse_count = array[1].to_i
        end

        def ended
          @pulse_count = 360
        end

        def stopwatch
          nil
        end
      end

      # Initialize the class
      init_gift
    end
  end
end
