module Lich
  module Gemstone
    class ReadyList
      @checked = false
      @ready_list = {
        shield: nil,
        weapon: nil,
        secondary_weapon: nil,
        ranged_weapon: nil,
        ammo_bundle: nil,
        ammo2_bundle: nil,
        sheath: nil,
        secondary_sheath: nil,
      }

      # Define class-level accessors for ready list entries
      @ready_list.each_key do |type|
        define_singleton_method(type) { @ready_list[type] }
        define_singleton_method("#{type}=") { |value| @ready_list[type] = value }
      end

      class << self
        def ready_list
          @ready_list
        end

        def checked?
          @checked
        end

        def checked=(value)
          @checked = value
        end

        def valid?
          # check if existing ready items are valid or not
          return false unless checked?
          @ready_list.each_value do |value|
            unless value.nil? || GameObj.inv.map(&:id).include?(value.id) || GameObj.containers.values.flatten.map(&:id).include?(value.id)
              @checked = false
              return false
            end
          end
          return true
        end

        def reset
          @checked = false
          @ready_list.each_key do |key|
            @ready_list[key] = nil
          end
        end

        def check(silent: false, quiet: false)
          if quiet
            start_pattern = /<output class="mono"\/>/
          else
            start_pattern = /Your current settings are:/
          end
          waitrt?
          Lich::Util.issue_command("ready list", start_pattern, silent: silent, quiet: quiet)
          @checked = true
        end
      end
    end
  end
end
