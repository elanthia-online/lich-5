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
      miss = nil
      miss = yield(key) if block_given?
      # don't cache nils
      return miss if miss.nil?
      @records[key] = miss
    end

    def merge!(h)
      @records.merge!(h)
    end

    def to_a()
      @records.to_a
    end

    def to_h()
      @records
    end

    alias :clear :flush!
    alias :key? :include?
  end
end
