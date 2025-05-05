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
        # attr_accessor :checked

        def stow_list
          @stow_list
        end

        def checked?
          @checked
        end

        def checked=(value)
          @checked = value
        end
      end
    end
  end
end
