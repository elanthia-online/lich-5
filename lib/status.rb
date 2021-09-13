module Lich
  module Status
    def self.parse(status_string)
      status_string = status_string.strip

      return [] if status_string.empty?

      if status_string.start_with?("(") && status_string.end_with?(")")
        return status_string.slice(1..-2).split(",").map(&:downcase).map(&:strip)
      end

      if status_string.start_with? "that "
        return status_string.slice(7..-1)
          .gsub(", and", ",")
          .gsub("\sand\s", ",")
          .gsub(/\b(is|appears|and)\s/, "")
          .split(",")
          .map(&:downcase)
          .map(&:strip)
      end

      fail "Status.parse / err: unhandled case -> #{status_string}"
    end
  end
end