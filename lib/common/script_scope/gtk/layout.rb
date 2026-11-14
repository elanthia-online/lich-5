# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        module PolicyType
          AUTOMATIC = :automatic
          ALWAYS = :always
          NEVER = :never
        end

        module AttachOptions
          EXPAND = 1
          SHRINK = 2
          FILL = 4
        end

        EXPAND = AttachOptions::EXPAND
        FILL = AttachOptions::FILL
      end
    end
  end
end

# Keep the legacy entry path and definition order; boot loads later class extensions.
require_relative 'layout/positioned'
require_relative 'layout/grid'
require_relative 'layout/scrolling'
