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
  cell.signal_emit('edited', '0:0', 'Profanity (external client)')
  drain
  entry = YAML.load_file(path)['accounts']['TEST']['characters'].first
  abort 'Profanity / headless selection not saved' unless entry['frontend'] == 'profanity' && entry['launch_mode'] == 'external'
  abort 'Editing collapsed account' unless view.row_expanded?(Gtk::TreePath.new('0'))
  port_cell = view.columns.find { |col| col.title == 'Local port' }.cells.first
  port_cell.signal_emit('edited', '0:0', '8001')
  drain
  saved = YAML.load_file(path)['accounts']['TEST']
  abort 'Port not saved' unless saved['characters'].first['listen_port'] == 8001
  abort 'Credentials changed' unless saved['password'] == 'synthetic-password'
  before = File.binread(path)
  cell.signal_emit('editing-canceled')
  drain
  abort 'Cancel changed entries' unless File.binread(path) == before
  # Simulate a hand-edited invalid port, then exercise the actual cell gate.
  data = YAML.load_file(path)
  data['accounts']['TEST']['characters'].first['listen_port'] = 65536
  File.write(path, YAML.dump(data))
  manager.send(:refresh_accounts_display)
  port_column = view.columns.find { |col| col.title == 'Local port' }
  port_column.cell_set_cell_data(view.model, view.model.get_iter('0:0'), false, false)
  failures << 'invalid external port cannot be edited' unless port_cell.editable?
  port_cell.signal_emit('edited', '0:0', '8001')
  drain
  entry = YAML.load_file(path)['accounts']['TEST']['characters'].first
  abort 'Invalid port correction failed' unless entry['listen_port'] == 8001
  # Exercise a real bound port, not just the mocked unit-test seam.
  occupied = TCPServer.new('127.0.0.1', 0)
  begin
    Lich::Common::GUI::LaunchSettings.preflight!(frontend: 'profanity', listen_port: occupied.addr[1])
    abort 'Occupied port accepted'
  rescue ArgumentError => e
    abort e.message unless e.message.include?('unavailable')
  ensure
    occupied.close
  end
  window.destroy
  abort failures.join("\n") unless failures.empty?
  puts 'PASS: real GTK commit/cancel, invalid-port repair, preserved account expansion and credentials; occupied-port rejection'
end
