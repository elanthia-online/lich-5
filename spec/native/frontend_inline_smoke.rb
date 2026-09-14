# frozen_string_literal: true

# Standalone real-GTK regression. Run under xvfb-run; uses synthetic accounts only.
require_relative '../../lib/util/gtk_compaction'
Lich::Util::GtkCompaction.install!
require 'gtk3'
require 'yaml'
require 'fileutils'
require 'tmpdir'
$stdout.sync = true
module Lich
  def self.log(_message); end

  module Util
    def self.install_gem_requirements(*)
      require 'os'
      require 'ffi'
      true
    end
  end
end

def Gtk.queue(&block)
  GLib::Idle.add { block.call; false }
end
require_relative '../../lib/common/gui_login'

def descendants(widget)
  [widget] + (widget.is_a?(Gtk::Container) ? widget.children.flat_map { |child| descendants(child) } : [])
end

def drain
  Gtk.main_iteration while Gtk.events_pending?
end

Dir.mktmpdir('lich-inline-ui') do |directory|
  failures = []
  account = Lich::Common::GUI::AccountManager
  account.add_or_update_account(directory, 'TEST', 'synthetic-password', [
                                  { char_name: 'Tester', game_code: 'GS3', game_name: 'GemStone IV', frontend: 'stormfront' }
                                ])
  path = Lich::Common::Authentication::EntryStore.yaml_file_path(directory)
  window = Gtk::Window.new
  window.set_default_size(600, 500)
  notebook = Gtk::Notebook.new
  window.add(notebook)
  manager = Lich::Common::GUI::AccountManagerUI.new(directory)
  manager.instance_variable_set(:@window, window)
  manager.create_accounts_tab(notebook)
  window.show_all
  view = descendants(window).find { |widget| widget.is_a?(Gtk::TreeView) }
  view.expand_all
  drain
  abort 'Obsolete button is still present' if descendants(window).any? { |w| w.is_a?(Gtk::Button) && w.label == 'Change Frontend' }
  column = view.columns.find { |col| col.title == 'Frontend' }
  cell = column.cells.first
  abort 'Frontend is not a dropdown' unless cell.is_a?(Gtk::CellRendererCombo)
  option = nil
  cell.model.each { |_model, _path, iter| option = iter if iter[0] == 'profanity' }
  abort 'Profanity is missing' unless option
  before = File.binread(path)
  cell.signal_emit('changed', '0:0', option)
  failures << 'selection was persisted before edited' unless File.binread(path) == before
  cell.signal_emit('editing-canceled')
  drain
  failures << 'Escape did not preserve the saved entry' unless File.binread(path) == before
  cell.signal_emit('changed', '0:0', option)
  cell.signal_emit('edited', '0:0', 'Profanity (unavailable)')
  drain
  entry = YAML.load_file(path)['accounts']['TEST']['characters'].first
  abort 'Frontend selection not saved' unless entry['frontend'] == 'profanity'
  abort 'GUI headless controls remain' if view.columns.any? { |col| ['Launch mode', 'Local port'].include?(col.title) }
  abort 'Editing collapsed account' unless view.row_expanded?(Gtk::TreePath.new('0'))
  abort 'Credentials changed' unless YAML.load_file(path)['accounts']['TEST']['password'] == 'synthetic-password'
  locator = Object.new
  def locator.available(**)
    []
  end
  selector = Lich::Common::GUI::ManualFrontendSelector.new(locator: locator)
  abort 'Unavailable frontends are shown in Manual Login' unless selector.widget.children.map(&:label) == ['Custom']
  abort 'Custom does not use Wrayth compatibility' unless selector.custom? && selector.selected_id == 'stormfront'
  manual = Lich::Common::GUI::ManualLoginTab.allocate
  checkbox = manual.send(:create_custom_launch_options)
  manual.send(:setup_custom_launch_handler, checkbox)
  manual.send(:setup_native_launch_handler, selector, checkbox)
  abort 'Custom did not reveal its controls' unless checkbox.active? &&
                                                    manual.instance_variable_get(:@custom_launch_entry).visible? &&
                                                    manual.instance_variable_get(:@custom_launch_dir).visible?
  def locator.available(**)
    [Lich::Common::FrontendLocator::Resolution.new(frontend_id: 'stormfront', executable_path: '/synthetic/wrayth', source: :path)]
  end
  selector.reload!
  abort 'Reload lost Custom selection' unless selector.custom?
  selector.widget.children.find { |radio| radio.label == 'Wrayth' }.active = true
  abort 'Detected Wrayth selection failed' unless selector.selected_id == 'stormfront' && !selector.custom?
  checkbox.active = false
  selector.widget.children.find { |radio| radio.label == 'Custom' }.active = true
  abort 'Selecting Custom did not enable the command' unless checkbox.active?
  def locator.available(**)
    []
  end
  selector.reload!
  abort 'Missing clients did not fall back to Custom' unless selector.custom?
  window.destroy
  abort failures.join("\n") unless failures.empty?
  puts 'PASS: real GTK commit/cancel, account expansion and credentials, detected radios, Custom fallback and command controls'
end
