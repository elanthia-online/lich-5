module Infomon
  # in-memory cache with db read fallbacks
  class Cache
    attr_reader :records

    def initialize()
      @records = {}
    end

    def put(key, value)
      @records[key] = value
      self
    end

    def include?(key)
      @records.include?(key)
    end

    def flush!
      @records.clear
    end

    def delete(key)
      @records.delete(key)
    end

    def get(key)
      return @records[key] if self.include?(key)
      miss = yield(key)
      # don't cache nils
      return miss if miss.nil?
      @records[key] = miss
    end
  end
end
