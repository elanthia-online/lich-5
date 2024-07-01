# frozen_string_literal: true

#
# module CritRanks used to resolve critical hits into their mechanical results
# queries against crit_tables files in lib/crit_tables/
# 20240625
#

#
# See generic_critical_table.rb for the general template used
#

module CritRanks
  @critical_table ||= {}
  @types           = []
  @locations       = []
  @ranks           = []

  def self.init
    return unless @critical_table.empty?

    files_to_load = ['acid_critical_table.rb', 'cold_critical_table.rb', 'crush_critical_table.rb',
                     'disintegrate_critical_table.rb', 'disruption_critical_table.rb', 'fire_critical_table.rb', 'generic_critical_table.rb', 'grapple_critical_table.rb', 'impact_critical_table.rb', 'lightning_critical_table.rb', 'non_corporeal_critical_table.rb', 'plasma_critical_table.rb',
                     'puncture_critical_table.rb', 'slash_critical_table.rb', 'steam_critical_table.rb', 'ucs_grapple_critical_table.rb', 'ucs_jab_critical_table.rb', 'ucs_kick_critical_table.rb', 'ucs_punch_critical_table.rb', 'unbalance_critical_table.rb', 'vacuum_critical_table.rb']

    files_to_load.each do |file|
      require File.join(LIB_DIR, 'crit_tables', file)
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
    return key.upcase if key.is_a?(Symbol)

    key.strip.upcase.gsub(' ', '_')
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

  def self.match(line)
    @index_rx.filter do |rx, _data|
      rx =~ line
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
