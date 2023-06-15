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

    def delete(key)
      @records.delete(key)
    end

    def get(key)
      return @records[key] if @records.include?(key)
      miss = yield
      # don't cache nils
      return miss if miss.nil?
      @records[key] = miss
    end
  end
end
