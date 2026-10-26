# frozen_string_literal: true

# Explicit, interactive host smoke test; never loaded by the regular suite.
# Uses the production service, launcher, renderer, and shim with a stand-in
# script owner and console output. It does not run Map, Spellson, or game logic.
require 'tmpdir'
require 'fileutils'
require_relative '../lib/webui'
require_relative '../lib/common/script_scope'

module Lich
  # Route standalone fixture diagnostics to its launching terminal.
  # @param message [String] diagnostic text
  # @return [void]
  def self.log(message) = warn(message)

  module Common
    # Minimal owner lookup for this standalone fixture, not the game engine.
    module Script
      OWNER = Struct.new(:name, :thread_group).new('native-host-smoke', ThreadGroup::Default)

      # Returns the standalone fixture owner without starting a game or a real Script.
      # @return [Object] fixture lifecycle identity shared with callback threads
      def self.current = OWNER
    end
  end
end

# Stand-in for the frontend output used by the compatibility notice.
# @param message [String] compatibility notice
# @return [void]
def respond(message) = puts(message)

abort 'This smoke test requires macOS or Windows.' unless OS.mac? || OS.windows?

Dir.mktmpdir('lich-native-smoke-') do |directory|
  store = Lich::WebUI::WindowGeometryStore.new(directory: directory, context: -> { ['smoke', 'offline'] })
  service = Lich::WebUI::Service.new(geometry_store: store)
  Lich::WebUI.service = service
  owner = Lich::Common::Script.current
  topmost = true
  opacity = 1.0
  page = Lich::WebUI.page(owner: owner, id: 'native', title: 'Native host smoke',
                          props: { bare: true, size: [420, 190] },
                          on: { close: proc { Lich::WebUI.close(page) } }) do |tree|
    tree.presentation(always_on_top: topmost, opacity: opacity)
    tree.text(content: "Native page: always on top #{topmost ? 'ON' : 'OFF'}")
    tree.text_input(key: 'entry', value: 'Type here, then in your frontend.')
    tree.button(label: 'Toggle always on top', on: { activate: proc {
      topmost = !topmost
      Lich::WebUI.refresh(page)
    } })
    tree.button(label: "Opacity #{(opacity * 100).to_i}% - toggle 50/100", on: { activate: proc {
      opacity = opacity > 0.5 ? 0.5 : 1.0
      Lich::WebUI.refresh(page)
    } })
    tree.button(label: 'Close native window', on: { activate: proc { Lich::WebUI.close(page) } })
  end

  begin
    Lich::WebUI.refresh(page)
    Lich::WebUI.start
    raise 'Native helper could not start' unless Lich::WebUI.open(page: page)

    Lich::Common::ScriptScope.activate!
    gtk = Lich::Common::ScriptScope::Gtk
    window = gtk::Window.new('GTK shim host smoke')
    window.set_default_size(420, 150)
    window.keep_above = true
    box = gtk::Box.new(:vertical)
    box.add(gtk::Label.new('Shim window: native host through the GTK API'))
    entry = gtk::Entry.new
    entry.text = 'This input uses the unchanged GTK shim API.'
    box.add(entry)
    button = gtk::Button.new(label: 'Toggle always on top')
    shim_topmost = true
    button.signal_connect('clicked') do
      shim_topmost = !shim_topmost
      window.keep_above = shim_topmost
      button.label = "Always on top #{shim_topmost ? 'ON' : 'OFF'}"
    end
    box.add(button)
    window.add(box)
    window.show_all
    puts 'Two windows opened. Test focus/topmost and resizing; close each independently to finish.'
    sleep 0.1 until service.registry.pages.empty?
    puts 'Both pages closed.'
  ensure
    Lich::Common::ScriptDeath.run(owner)
    Lich::WebUI.reset!
  end
end
