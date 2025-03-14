# carve out supporting infomon move to lib

module Lich
  module Common
    class Char
      def Char.init(_blah)
        echo 'Char.init is no longer used. Update or fix your script.'
      end

      def Char.name
        XMLData.name
      end

      def Char.stance
        XMLData.stance_text
      end

      def Char.percent_stance
        XMLData.stance_value
      end

      def Char.encumbrance
        XMLData.encumbrance_text
      end

      def Char.percent_encumbrance
        XMLData.encumbrance_value
      end

      def Char.health
        XMLData.health
      end

      def Char.mana
        XMLData.mana
      end

      def Char.spirit
        XMLData.spirit
      end

      def Char.stamina
        XMLData.stamina
      end

      def Char.max_health
        # Object.module_eval { XMLData.max_health }
        XMLData.max_health
      end

      def Char.maxhealth
        Lich.deprecated("Char.maxhealth", "Char.max_health", caller[0], fe_log: true)
        Char.max_health
      end

      def Char.max_mana
        Object.module_eval { XMLData.max_mana }
      end

      def Char.maxmana
        Lich.deprecated("Char.maxmana", "Char.max_mana", caller[0], fe_log: true)
        Char.max_mana
      end

      def Char.max_spirit
        Object.module_eval { XMLData.max_spirit }
      end

      def Char.maxspirit
        Lich.deprecated("Char.maxspirit", "Char.max_spirit", caller[0], fe_log: true)
        Char.max_spirit
      end

      def Char.max_stamina
        Object.module_eval { XMLData.max_stamina }
      end

      def Char.maxstamina
        Lich.deprecated("Char.maxstamina", "Char.max_stamina", caller[0], fe_log: true)
        Char.max_stamina
      end

      def Char.percent_health
        ((XMLData.health.to_f / XMLData.max_health.to_f) * 100).to_i
      end

      def Char.percent_mana
        if XMLData.max_mana == 0
          100
        else
          ((XMLData.mana.to_f / XMLData.max_mana.to_f) * 100).to_i
        end
      end

      def Char.percent_spirit
        ((XMLData.spirit.to_f / XMLData.max_spirit.to_f) * 100).to_i
      end

      def Char.percent_stamina
        if XMLData.max_stamina == 0
          100
        else
          ((XMLData.stamina.to_f / XMLData.max_stamina.to_f) * 100).to_i
        end
      end

      def Char.dump_info
        echo "Char.dump_info is no longer used. Update or fix your script."
      end

      def Char.load_info(_string)
        echo "Char.load_info is no longer used. Update or fix your script."
      end

      def Char.respond_to?(m, *args)
        [Stats, Skills, Spellsong].any? { |k| k.respond_to?(m) } or super(m, *args)
      end

      def Char.method_missing(meth, *args)
        polyfill = [Stats, Skills, Spellsong].find { |klass|
          klass.respond_to?(meth, *args)
        }
        if polyfill
          Lich.deprecated("Char.#{meth}", "#{polyfill}.#{meth}", caller[0])
          return polyfill.send(meth, *args)
        end
        super(meth, *args)
      end

      def Char.info
        echo "Char.info is no longer supported. Update or fix your script."
      end

      def Char.skills
        echo "Char.skills is no longer supported. Update or fix your script."
      end

      def Char.citizenship
        Infomon.get('citizenship') if XMLData.game =~ /^GS/
      end

      def Char.citizenship=(_val)
        echo "Updating via Char.citizenship is no longer supported. Update or fix your script."
      end

      def Char.che
        Infomon.get('che') if XMLData.game =~ /^GS/
      end
    end
  end
end
