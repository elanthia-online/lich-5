module Lich
  module Gemstone
    module Effects
      class Registry
        include Enumerable

        def initialize(dialog)
          @dialog = dialog
        end

        # A snapshot of the dialog's effects. The XML parser thread writes the
        # live Hash, and adding a key to a Hash while another thread iterates
        # it raises in the thread doing the adding: the parser, not the script.
        # Iterating a copy keeps a script's scan from breaking the parser.
        #
        # @return [Hash{String, Integer => Time}] effect name or id => expiry
        def to_h
          live.dup
        end

        # The dialog's progress bar id => text. Unlike {#to_h}, two effects
        # sharing one name keep separate entries here, and the id is the
        # game's bar id, which is not always a Lich spell number.
        #
        # @return [Hash{Integer => String}]
        def names
          XMLData.dialog_names.fetch(@dialog, {}).dup
        end

        def each()
          to_h.each { |k, v| yield(k, v) }
        end

        def expiration(effect)
          if effect.is_a?(Regexp)
            (to_h.find { |k, _v| k.to_s =~ effect } || [nil, 0])[1]
          else
            # a single lookup does not iterate, so it can read the live Hash
            live.fetch(effect, 0)
          end
        end

        def active?(effect)
          expiration(effect).to_f > Time.now.to_f
        end

        def time_left(effect)
          if expiration(effect) != 0
            ((expiration(effect) - Time.now) / 60.to_f)
          else
            expiration(effect)
          end
        end

        private

        # The parser's own Hash for this dialog. Never iterate it; see {#to_h}.
        def live
          XMLData.dialogs.fetch(@dialog, {})
        end
      end

      Spells    = Registry.new("Active Spells")
      Buffs     = Registry.new("Buffs")
      Debuffs   = Registry.new("Debuffs")
      Cooldowns = Registry.new("Cooldowns")

      def self.display
        effect_out = Terminal::Table.new :headings => ["ID", "Type", "Name", "Duration"]
        titles = ["Spells", "Cooldowns", "Buffs", "Debuffs"]
        existing_spell_nums = []
        active_spells = Spell.active
        active_spells.each { |s| existing_spell_nums << s.num }
        circle = nil
        [Effects::Spells, Effects::Cooldowns, Effects::Buffs, Effects::Debuffs].each { |effect|
          title = titles.shift
          id_effects = effect.to_h.select { |k, _v| k.is_a?(Integer) }
          text_effects = effect.to_h.reject { |k, _v| k.is_a?(Integer) }
          # The parser records each bar's text by id. Failing that, names and
          # ids pair up by position only when every effect has its own name:
          # spell names disabled leaves no names, and two effects sharing a
          # name (two Sword Hymns) share one name key. Then the spell list is
          # the last resort, and the bar id is not always a spell number.
          names = effect.names
          positional = id_effects.length == text_effects.length ? text_effects.keys : []
          if id_effects.length == 0
            effect_out.add_row ["", title, "No #{title.downcase} found!", ""]
          else
            id_effects.each_with_index { |(sn, end_time), i|
              stext = names[sn] || positional[i] || Spell[sn]&.name || sn.to_s
              duration = ((end_time - Time.now) / 60.to_f)
              if duration < 0
                next
              elsif duration > 86400
                duration = "Indefinite"
              else
                duration = duration.as_time
              end
              if Spell[sn]&.circlename && circle != Spell[sn].circlename && title == 'Spells'
                circle = Spell[sn].circlename
              end
              effect_out.add_row [sn, title, stext, duration]
              existing_spell_nums.delete_if { |s| Spell[s].name =~ /#{Regexp.escape(stext)}/ || stext =~ /#{Regexp.escape(Spell[s].name)}/ || s == sn }
            }
          end
          effect_out.add_separator unless title == 'Debuffs' && existing_spell_nums.empty?
        }
        existing_spell_nums.each { |sn|
          effect_out.add_row [sn, "Other", Spell[sn].name, (Spell[sn].timeleft.as_time)]
        }
        Lich::Messaging.mono(effect_out.to_s)
      end
    end
  end
end
