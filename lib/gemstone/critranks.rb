# frozen_string_literal: true

#
# module CritRanks used to resolve critical hits into their mechanical results
# queries against crit_tables files in lib/crit_tables/
# 20240625
#

#
# See generic_critical_table.rb for the general template used
#
module Lich
  module Gemstone
    module CritRanks
      @critical_table ||= {}
      @types           = []
      @locations       = []
      @ranks           = []

      def self.init
        return unless @critical_table.empty?
        Dir.glob("#{File.join(LIB_DIR, "gemstone", "critranks", "*critical_table.rb")}").each do |file|
          # load, not require: require makes reload! a no-op (already-required
          # table files never re-run, leaving the emptied table empty forever)
          load file
        end
        create_indices
      end

      def self.table
        @critical_table
      end

      def self.reload!
        @critical_table = {}
        @types = []
        @locations = []
        @ranks = []
        init
      end

      def self.tables
        @tables = []
        @types.each do |type|
          @tables.push(type.to_s.gsub(':', ''))
        end
        @tables
      end

      def self.types
        @types
      end

      def self.locations
        @locations
      end

      def self.ranks
        @ranks
      end

      def self.clean_key(key)
        return key.to_i if key.is_a?(Integer) || key =~ (/^\d+$/)
        return key.downcase if key.is_a?(Symbol)

        key.strip.downcase.gsub(/[ -]/, '_')
      end

      def self.validate(key, valid)
        clean = clean_key(key)
        raise "Invalid key '#{key}', expecting one of #{valid.join(',')}" unless valid.include?(clean)

        clean
      end

      # Builds the pattern indices. Tolerates nil location/rank rows in the
      # table data (some tables carry explicit nil placeholders); a nil row
      # means that crit is simply unrecognized rather than a load failure.
      #
      # Patterns are indexed by the leading literal word of their (anchored)
      # regex, so parse only has to test the handful of patterns that could
      # possibly match a given line instead of all ~2400. Patterns that are
      # not ^-anchored to a literal word are kept in a small residual list
      # that is always checked.
      def self.create_indices
        @index_buckets = Hash.new { |hash, key| hash[key] = [] }
        @index_residual = []
        @critical_table.each do |type, typedata|
          @types.append(type)
          typedata.each do |loc, locdata|
            @locations.append(loc) unless @locations.include?(loc)
            next if locdata.nil?
            locdata.each do |rank, record|
              @ranks.append(rank) unless @ranks.include?(rank)
              next if record.nil? || record[:regex].nil?
              source = record[:regex].source
              if source.start_with?('^') && (first_word = source[1..].match(/\A([A-Za-z']+)\b/))
                @index_buckets[first_word[1].downcase].push(record)
              else
                @index_residual.push(record)
              end
            end
          end
        end
        @index_buckets.each_value(&:freeze)
        @index_buckets.default = nil # drop the auto-vivifying default proc
        @index_buckets.freeze
        @index_residual.freeze
      end

      def self.parse(line)
        stripped = line.strip # need to strip spaces to support anchored regex in tables
        first_word = stripped[/\A[A-Za-z']+/]&.downcase
        candidates = @index_buckets.fetch(first_word, nil) ? @index_buckets[first_word] + @index_residual : @index_residual
        candidates.each_with_object({}) do |record, matches|
          matches[record[:regex]] = record if record[:regex] =~ stripped
        end
      end

      def self.fetch(type, location, rank)
        table.dig(
          validate(type, types),
          validate(location, locations),
          validate(rank, ranks)
        )
      rescue StandardError => e
        Lich::Messaging.msg('error', "Error! #{e}")
      end
      # startup
      init
    end
  end
end
