# Carve out class SpellRanks
# 2024-06-13

module Lich
  module Gemstone
    class SpellRanks
      @@list      ||= Array.new
      @@timestamp ||= 0
      @@loaded    ||= false
      attr_reader :name
      attr_accessor :minorspiritual, :majorspiritual, :cleric, :minorelemental, :majorelemental, :minormental, :ranger, :sorcerer, :wizard, :bard, :empath, :paladin, :arcanesymbols, :magicitemuse, :monk

      def SpellRanks.load
        if File.exist?(File.join(DATA_DIR, "#{XMLData.game}", "spell-ranks.dat"))
          begin
            File.open(File.join(DATA_DIR, "#{XMLData.game}", "spell-ranks.dat"), 'rb') { |f|
              @@timestamp, @@list = Marshal.load(f.read)
            }
            # minor mental circle added 2012-07-18; old data files will have @minormental as nil
            @@list.each { |rank_info| rank_info.minormental ||= 0 }
            # monk circle added 2013-01-15; old data files will have @minormental as nil
            @@list.each { |rank_info| rank_info.monk ||= 0 }
            @@loaded = true
          rescue
            respond "--- Lich: error: SpellRanks.load: #{$!}"
            Lich.log "error: SpellRanks.load: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            @@list      = Array.new
            @@timestamp = 0
            @@loaded = true
          end
        else
          @@loaded = true
        end
      end

      def SpellRanks.save
        begin
          File.open(File.join(DATA_DIR, "#{XMLData.game}", "spell-ranks.dat"), 'wb') { |f|
            f.write(Marshal.dump([@@timestamp, @@list]))
          }
        rescue
          respond "--- Lich: error: SpellRanks.save: #{$!}"
          Lich.log "error: SpellRanks.save: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        end
      end

      def SpellRanks.timestamp
        SpellRanks.load unless @@loaded
        @@timestamp
      end

      def SpellRanks.timestamp=(val)
        SpellRanks.load unless @@loaded
        @@timestamp = val
      end

      def SpellRanks.[](name)
        SpellRanks.load unless @@loaded
        @@list.find { |n| n.name == name }
      end

      def SpellRanks.list
        SpellRanks.load unless @@loaded
        @@list
      end

      def SpellRanks.method_missing(arg = nil)
        echo "error: unknown method #{arg} for class SpellRanks"
        respond caller[0..1]
      end

      def initialize(name)
        SpellRanks.load unless @@loaded
        @name = name
        @minorspiritual, @majorspiritual, @cleric, @minorelemental, @majorelemental, @ranger, @sorcerer, @wizard, @bard, @empath, @paladin, @minormental, @arcanesymbols, @magicitemuse = 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        @@list.push(self)
      end
    end
  end
end
