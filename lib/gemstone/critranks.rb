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
          require file
        end
        create_indices
      end

      def self.table
        @critical_table
      end

      def self.reload!
        @critical_table = {}
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

      def self.create_indices
        @index_rx ||= {}
        @critical_table.each do |type, typedata|
          @types.append(type)
          typedata.each do |loc, locdata|
            @locations.append(loc) unless @locations.include?(loc)
            locdata.each do |rank, record|
              @ranks.append(rank) unless @ranks.include?(rank)
              @index_rx[record[:regex]] = record
            end
          end
        end
      end

      def self.parse(line)
        @index_rx.filter do |rx, _data|
          rx =~ line.strip # need to strip spaces to support anchored regex in tables
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
