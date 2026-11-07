# frozen_string_literal: true

module Lich
  module Genie
    # Port of the genie-spell-timer plugin (SpellTimerPlugin/PluginProgram.cs v1.10,
    # the genie-spell-timer repository), which DragonRealms Genie users install to
    # get `$SpellTimer.<Spell>.active` / `.duration` (and `.charge` for Stellar
    # Collector). Remix hands a plugin every window line (ParsePluginText, Game.cs:3057,
    # 3381-3421 R) and every XML buffer (EventParseXML, Game.cs:965 R); {GameState}
    # calls {#parse_text} for the rows routed to the active-spells window and
    # {#parse_xml} for each buffer.
    #
    # The plugin writes its values with `#var` (SendText("#var ..."), PluginProgram.cs:
    # 268-300), so they are ordinary saved globals: a script's `#var` overwrites them
    # until the next update, `#var save` writes them, and variables.cfg seeds them at
    # start. We do the same through the {GlobalStore}; each write is also a variable change
    # ({#take_changes}), so `action ... when eval ($SpellTimer.X.active = 0)` fires.
    #
    # Deliberate differences:
    #   * The plugin's own spell list file (SpellTimerSpells<char>.xml, readSpellList/
    #     serializeSpellList) is not kept. Instead the spells whose
    #     `SpellTimer.<name>.active` variable is in the store when the first spell update
    #     arrives are the known spells, so a stale `active 1` from variables.cfg is reset
    #     by the first update that does not list it, as the saved list would make the
    #     plugin do.
    #   * Spells are matched by their variable name (spaces, apostrophes and hyphens
    #     removed), not by the display name, so a seeded entry and the spell's real name
    #     are one entry.
    #   * The cast bar, the `/spelltimer` command and the plugin's echoes are not ported.
    class SpellTimer
      Spell = Struct.new(:name, :active, :duration, :charge)

      # PluginProgram.cs:110 `(.+?)\s+\((.+)\)`.
      LINE = /(.+?)\s+\((.+)\)/.freeze
      PERCENT = /(\d+)%/.freeze
      ROISAEN = /(\d+) roisaen/.freeze
      SLIVERS = 'small orbiting slivers of lunar magic'
      CLEAR_XML = '<clearStream id="percWindow"/>'
      WINDOW = 'percwindow'
      ACTIVE_VAR = /\ASpellTimer\.(.+)\.active\z/.freeze

      # @param store [#get, #set, #keys] the global store the plugin's `#var`s write to
      def initialize(store:)
        @store = store
        @spells = nil # lazily seeded (see the class comment)
        @popped = []
        @changes = []
      end

      # The variables written since the last call, in write order: each `#var` the plugin
      # sends raises a variable change in Remix (Command.cs:931-933 R), which {GameState}
      # dispatches after the row.
      # @return [Array<String>] names without the "$"
      def take_changes
        changes = @changes
        @changes = []
        changes
      end

      # ParseText (PluginProgram.cs:96-209): one line of a window.
      # @param text [String] the line as Remix prints it (CRLF included)
      # @param window [String] Remix's lower-cased target window name
      # @return [void]
      def parse_text(text, window)
        return unless window == WINDOW

        spell = parse_line(text.to_s)
        return unless spell

        known = spells.find { |s| var_name(s.name) == var_name(spell.name) }
        if known
          known.name = spell.name # a seeded entry only knew the variable name
          known.active = spell.active
          known.duration = spell.duration
          known.charge = spell.charge
        else
          spells << spell
        end
        @popped << spell
        set_genie_variables
      end

      # ParseXML (PluginProgram.cs:211-231): a percWindow clear ends the previous update.
      # @param xml [String] one ProcessXML buffer
      # @return [void]
      def parse_xml(xml)
        return unless xml == CLEAR_XML

        finish_pop
        @popped = []
      end

      # spellNameToVariableName (PluginProgram.cs:381-388).
      # @param name [String]
      # @return [String]
      def var_name(name)
        name.delete(" '-")
      end

      private

      def spells
        @spells ||= @store.keys.filter_map { |key| key[ACTIVE_VAR, 1] }.uniq.map { |name| Spell.new(name, false, 0, 0) }
      end

      # The body of ParseText for the percwindow (PluginProgram.cs:107-183).
      # @return [Spell, nil] nil when the line is not a spell line
      def parse_line(text)
        match = text.match(LINE)
        name = match ? Text.net_trim(match[1]) : Text.net_trim(text)
        return parse_timed(name, match[2]) if match
        return unless name.end_with?(SLIVERS)

        if name.start_with?('Many') then Spell.new('Moonblade Slivers', true, 2, 0)
        elsif name.start_with?('No') then Spell.new('Moonblade Slivers', false, 0, 0)
        else Spell.new('Moonblade Slivers', true, 1, 0)
        end
      end

      def parse_timed(name, detail)
        duration = 0
        charge = 0
        charge = Integer(detail[PERCENT, 1], 10) if name == 'Stellar Collector' && detail.match?(PERCENT)
        if name == 'Osrel Meraud'
          duration = Integer(detail[PERCENT, 1], 10) if detail.match?(PERCENT)
        elsif detail.match?(ROISAEN)
          duration = Integer(detail[ROISAEN, 1], 10)
        elsif %w[OM Indefinite].include?(detail)
          duration = 999
        end
        Spell.new(name, true, duration, charge)
      end

      # finishPop (PluginProgram.cs:233-266): every known spell not in the last update
      # goes inactive.
      def finish_pop
        popped = @popped.map { |spell| var_name(spell.name) }
        spells.each do |spell|
          next if popped.include?(var_name(spell.name))

          spell.active = false
          spell.duration = 0
          spell.charge = 0
        end
        set_genie_variables
      end

      # setGenieVariables (PluginProgram.cs:267-311): `#var` only what changed.
      def set_genie_variables
        spells.each do |spell|
          base = "SpellTimer.#{var_name(spell.name)}"
          write("#{base}.active", spell.active ? '1' : '0')
          write("#{base}.duration", spell.duration.to_s)
          write("#{base}.charge", spell.charge.to_s) if spell.name == 'Stellar Collector'
        end
      end

      def write(name, value)
        return if @store.get(name).to_s == value

        @store.set(name, value)
        @changes << name
      end
    end
  end
end
