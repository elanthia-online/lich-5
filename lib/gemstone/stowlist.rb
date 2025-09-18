module Lich
  module Gemstone
    class StowList
      @checked = false
      @stow_list = {
        box: nil,
        gem: nil,
        herb: nil,
        skin: nil,
        wand: nil,
        scroll: nil,
        potion: nil,
        trinket: nil,
        reagent: nil,
        lockpick: nil,
        treasure: nil,
        forageable: nil,
        collectible: nil,
        default: nil
      }

      # Define class-level accessors for stow list entries
      @stow_list.each_key do |type|
        define_singleton_method(type) { @stow_list[type] }
        define_singleton_method("#{type}=") { |value| @stow_list[type] = value }
      end

      class << self
        def stow_list
          @stow_list
        end

        def checked?
          @checked
        end

        def checked=(value)
          @checked = value
        end

        def valid?
          # check if existing containers are valid or not
          return false unless checked?
          @stow_list.each_value do |value|
            unless value.nil? || GameObj.inv.map(&:id).include?(value.id)
              @checked = false
              return false
            end
          end
          return true
        end

        def reset
          @checked = false
          @stow_list.each_key do |key|
            @stow_list[key] = nil
          end
        end

        def check(silent: false, quiet: false)
          if quiet
            start_pattern = /<output class="mono"\/>/
          else
            start_pattern = /You have the following containers set as stow targets:/
          end
          waitrt?
          Lich::Util.issue_command("stow list", start_pattern, silent: silent, quiet: quiet)
          @checked = true
        end
      end
    end
  end
end
