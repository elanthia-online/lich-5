# The root namespace for Lich scripting components.
module Lich
  # GemStone IV-specific modules and extensions.
  module Gemstone
    # Class for managing and using Warcries in GemStone IV.
    #
    # Warcries are cost-based vocal abilities that provide buffs or perform effects. This class provides:
    # - Metadata for each known warcry (cost, regex, optional buff name)
    # - Checks for knowledge, affordability, cooldown, and buff activity
    # - Execution logic including FORCERT handling
    #
    # Dynamic singleton methods are created for each warcry by long and short name.
    class Warcry
      # Internal table of all warcry abilities.
      #
      # @return [Hash<String, Hash>] Mapping from long name to metadata, including:
      #   - `:long_name` [String]
      #   - `:short_name` [String]
      #   - `:cost` [Hash]
      #   - `:target_cost` [Hash, optional] cost when used on a single target
      #   - `:regex` [Regexp]
      #   - `:buff` [String, optional]
      @@warcries = {
        "bertrandts_bellow" => {
          :long_name   => "bertrandts_bellow",
          :short_name  => "bellow",
          :type        => :setup,
          :cost        => { stamina: 20 },
          :target_cost => { stamina: 10 },
          :regex       => /You glare at .+ and let out a nerve-shattering bellow!/,
        },
        "yerties_yowlp"     => {
          :long_name  => "yerties_yowlp",
          :short_name => "yowlp",
          :type       => :buff,
          :cost       => { stamina: 20 },
          :regex      => /You throw back your shoulders and let out a resounding yowlp!/,
          :buff       => "Yertie's Yowlp",
        },
        "gerrelles_growl"   => {
          :long_name   => "gerrelles_growl",
          :short_name  => "growl",
          :type        => :setup,
          :cost        => { stamina: 14 },
          :target_cost => { stamina: 7 },
          :regex       => /Your face contorts as you unleash a guttural, deep-throated growl at .+!/,
        },
        "seanettes_shout"   => {
          :long_name  => "seanettes_shout",
          :short_name => "shout",
          :type       => :buff,
          :cost       => { stamina: 20 },
          :regex      => /You let loose an echoing shout!/,
          :buff       => 'Empowered (+20)',
        },
        "carns_cry"         => {
          :long_name  => "carns_cry",
          :short_name => "cry",
          :type       => :setup,
          :cost       => { stamina: 20 },
          :regex      => /You stare down .+ and let out an eerie, modulating cry!/,
        },
        "horlands_holler"   => {
          :long_name  => "horlands_holler",
          :short_name => "holler",
          :type       => :buff,
          :cost       => { stamina: 20 },
          :regex      => /You throw back your head and let out a thundering holler!/,
          :buff       => 'Enh. Health (+20)',
        },
      }

      extend PSMS::Technique
      techniques @@warcries, type: "Warcry", verb: "warcry"

      # Whether a warcry can be used right now: the shared checks, and the
      # character can make a sound.
      #
      # @see PSMS::Technique#available?
      def Warcry.available?(name, **options)
        super && !Status.cutthroat? && !Status.silenced?
      end

      # Uses a warcry, unless its buff is already active.
      #
      # @see PSMS::Technique#use
      def Warcry.use(name, target = "", **options)
        return if buff_active?(name)

        super
      end

      # DEPRECATED: Use {Warcry.buff_active?} instead.
      def Warcry.buffActive?(name)
        Lich.deprecated("Warcry.buffActive?", "Warcry.buff_active?", caller[0], fe_log: false)
        buff_active?(name)
      end
    end
  end
end
