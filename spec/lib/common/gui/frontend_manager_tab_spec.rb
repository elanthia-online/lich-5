# frozen_string_literal: true

require 'rspec'
require_relative '../../../../lib/common/gui/frontend_manager_tab'

module FrontendManagerTabSpecSupport
  class Row
    def initialize
      @values = {}
    end

    def [](column)
      @values[column]
    end

    def []=(column, value)
      @values[column] = value
    end
  end

  class ListStore
    attr_reader :rows

    def initialize(*)
      @rows = []
    end

    def append
      Row.new.tap { |row| @rows << row }
    end

    def clear
      @rows.clear
    end
  end

  class Selection
    attr_reader :selected

    def initialize
      @handlers = []
    end

    def signal_connect(signal, &handler)
      @handlers << handler if signal == 'changed'
    end

    def select_iter(iter)
      @selected = iter
      @handlers.each(&:call)
    end

    def unselect_all
      @selected = nil
      @handlers.each(&:call)
    end
  end

  class TreeView
    attr_reader :selection

    def initialize(*)
      @selection = Selection.new
    end

    def append_column(*)
      nil
    end
  end

  class TreeViewColumn
    attr_accessor :resizable

    def initialize(*, **)
      nil
    end
  end

  class CellRendererText
  end

  class Container
    attr_accessor :border_width
    attr_reader :children

    def initialize(*)
      @children = []
    end

    def pack_start(child, **)
      @children << child
    end

    def add(child)
      @children << child
    end

    def add1(child)
      @children << child
    end

    def add2(child)
      @children << child
    end

    def set_policy(*)
      nil
    end
  end

  Box = Class.new(Container)

  class Paned < Container
    attr_accessor :position
    attr_reader :orientation

    def initialize(orientation)
      super()
      @orientation = orientation
    end
  end

  ScrolledWindow = Class.new(Container)

  class Label
    attr_accessor :text

    def initialize(text)
      @text = text
    end

    def set_width_chars(*)
      nil
    end
  end

  class Entry
    attr_accessor :placeholder_text, :sensitive, :text

    def initialize
      @text = ''
      @sensitive = true
    end
  end

  class CheckButton
    attr_accessor :active, :sensitive
    attr_reader :label

    def initialize(label)
      @label = label
      @active = false
      @sensitive = true
    end

    def active?
      @active == true
    end
  end

  class Button
    attr_accessor :sensitive
    attr_reader :label

    def initialize(label:)
      @label = label
      @handlers = []
      @sensitive = true
    end

    def signal_connect(signal, &handler)
      @handlers << handler if signal == 'clicked'
    end

    def click
      @handlers.each(&:call)
    end
  end

  class Settings
    attr_accessor :next_document
    attr_reader :load_calls, :replace_calls

    def initialize(document)
      @document = deep_copy(document)
      @load_calls = []
      @replace_calls = []
    end

    def current
      deep_copy(@document)
    end

    def settings_for(frontend_id)
      current.fetch('builtins').fetch(frontend_id, nil) ||
        current.fetch('custom').fetch(frontend_id, nil)
    end

    def replace!(data_dir:, builtins:, custom:)
      @replace_calls << { data_dir: data_dir, builtins: deep_copy(builtins), custom: deep_copy(custom) }
      @document = { 'version' => 1, 'builtins' => deep_copy(builtins), 'custom' => deep_copy(custom) }
      current
    end

    def load!(data_dir:)
      @load_calls << data_dir
      @document = deep_copy(@next_document) if @next_document
      current
    end

    private

    def deep_copy(value)
      Marshal.load(Marshal.dump(value))
    end
  end

  class Frontend
    def initialize(settings)
      @settings = settings
    end

    def built_in_frontends
      %w[stormfront wizard]
    end

    def capability_vocabulary
      %i[xml gsl streams]
    end

    def registered_frontends
      built_in_frontends + ['wrayth'] + @settings.current.fetch('custom').keys
    end

    def display_name(frontend_id)
      return 'Wrayth' if frontend_id == 'stormfront'
      return 'Wizard' if frontend_id == 'wizard'

      @settings.current.fetch('custom').fetch(frontend_id).fetch('label')
    end

    def definition_for(frontend_id)
      capabilities = if frontend_id == 'stormfront'
                       %i[xml streams]
                     elsif frontend_id == 'wizard'
                       [:gsl]
                     else
                       @settings.current.fetch('custom').fetch(frontend_id).fetch('capabilities').map(&:to_sym)
                     end
      { id: frontend_id, capabilities: capabilities, metadata: {} }
    end
  end

  Resolution = Struct.new(:source, :executable_path, keyword_init: true)

  class Locator
    attr_reader :refresh_count

    def initialize(resolutions = {})
      @resolutions = resolutions
      @refresh_count = 0
    end

    def resolve(frontend_id)
      @resolutions[frontend_id]
    end

    def refresh!
      @refresh_count += 1
    end
  end
end

RSpec.describe Lich::Common::GUI::FrontendManagerTab do
  let(:document) do
    {
      'version'  => 1,
      'builtins' => { 'stormfront' => { 'arguments' => ['--wine-prefix', 'Lich Games'] } },
      'custom'   => {
        'vellum' => {
          'label'        => 'VellumFE',
          'command'      => '/opt/vellum/vellum-fe',
          'directory'    => '/opt/vellum',
          'arguments'    => ['--profile', 'Test Profile'],
          'capabilities' => %w[xml streams]
        }
      }
    }
  end
  let(:settings) { FrontendManagerTabSpecSupport::Settings.new(document) }
  let(:frontend) { FrontendManagerTabSpecSupport::Frontend.new(settings) }
  let(:locator) do
    FrontendManagerTabSpecSupport::Locator.new(
      'stormfront' => FrontendManagerTabSpecSupport::Resolution.new(
        source: :path,
        executable_path: '/games/Wrayth.exe'
      )
    )
  end
  let(:changes) { [] }
  let(:manager) do
    described_class.new(
      data_dir: '/saved',
      settings: settings,
      frontend: frontend,
      locator: locator,
      on_changed: -> { changes << :changed }
    )
  end

  before do
    stub_const('Gtk', FrontendManagerTabSpecSupport)
  end

  def rows_by_id
    model = manager.instance_variable_get(:@model)
    model.rows.to_h { |row| [row[described_class::ID_COLUMN], row] }
  end

  def editor(name)
    manager.instance_variable_get(name)
  end

  it 'stacks the catalog and editor vertically so the default-width window stays usable' do
    content = manager.widget.children.first

    expect(content.orientation).to eq(:vertical)
    expect(content.position).to eq(described_class::DEFAULT_CATALOG_HEIGHT)
    expect(content.children.last).to be_a(FrontendManagerTabSpecSupport::ScrolledWindow)
  end

  it 'generates capability controls from the registry vocabulary' do
    checks = editor(:@capability_checks)

    expect(checks.keys).to eq(frontend.capability_vocabulary)
  end

  it 'lists built-ins and custom definitions with stable hidden identities and detection-only status' do
    rows = rows_by_id

    expect(rows.keys).to eq(%w[stormfront wizard vellum])
    expect(rows.fetch('stormfront')[described_class::LABEL_COLUMN]).to eq('Wrayth')
    expect(rows.fetch('stormfront')[described_class::STATUS_COLUMN]).to eq('Detected')
    expect(rows.fetch('stormfront')[described_class::LAUNCH_COLUMN]).to eq('/games/Wrayth.exe')
    expect(rows.fetch('wizard')[described_class::STATUS_COLUMN]).to eq('Unavailable')
    expect(rows.fetch('vellum')[described_class::TYPE_COLUMN]).to eq('Custom')
    expect(rows.fetch('vellum')[described_class::STATUS_COLUMN]).to eq('Configured')
    expect(rows.fetch('vellum')[described_class::LAUNCH_COLUMN]).to eq('/opt/vellum/vellum-fe')
    expect(rows.fetch('vellum')[described_class::ARGUMENTS_COLUMN]).to eq('--profile Test\\ Profile')
  end

  it 'replaces only a built-in launch override and retains its selection' do
    editor(:@command_entry).text = '/custom/Wrayth.exe'
    editor(:@arguments_entry).text = '--wine-prefix "Lich Games"'

    expect(manager.send(:save_current)).to be true

    replacement = settings.replace_calls.last
    expect(replacement[:builtins]).to eq(
      'stormfront' => {
        'executable' => '/custom/Wrayth.exe',
        'arguments'  => ['--wine-prefix', 'Lich Games']
      }
    )
    expect(replacement[:custom]).to eq(document.fetch('custom'))
    expect(editor(:@id_entry).text).to eq('stormfront')
    expect(editor(:@id_entry).sensitive).to be false
    expect(locator.refresh_count).to eq(1)
    expect(changes).to eq([:changed])
  end

  it 'creates a custom frontend with an immutable normalized ID and declared capabilities' do
    manager.send(:begin_new_custom)
    editor(:@id_entry).text = 'My_FE'
    editor(:@label_entry).text = 'My Frontend'
    editor(:@command_entry).text = '/opt/my-fe'
    editor(:@directory_entry).text = '/opt'
    editor(:@arguments_entry).text = '--host localhost --title "GemStone IV"'
    editor(:@capability_checks).fetch(:xml).active = true
    editor(:@capability_checks).fetch(:mono).active = true if editor(:@capability_checks).key?(:mono)
    editor(:@capability_checks).fetch(:streams).active = true

    expect(manager.send(:save_current)).to be true

    definition = settings.replace_calls.last.fetch(:custom).fetch('my_fe')
    expect(definition).to eq(
      'label'        => 'My Frontend',
      'command'      => '/opt/my-fe',
      'directory'    => '/opt',
      'arguments'    => ['--host', 'localhost', '--title', 'GemStone IV'],
      'capabilities' => %w[xml streams]
    )
    expect(editor(:@id_entry).text).to eq('my_fe')
    expect(editor(:@id_entry).sensitive).to be false
  end

  it 'accepts explicitly quoted empty and whitespace-bearing arguments' do
    editor(:@arguments_entry).text = '--title "" "  keep me  " --next'
    expect(manager.send(:save_current)).to be true
    expect(settings.replace_calls.last[:builtins]['stormfront']['arguments'])
      .to eq(['--title', '', '  keep me  ', '--next'])
  end

  it 'rejects duplicate IDs without replacing the settings document' do
    manager.send(:begin_new_custom)
    editor(:@id_entry).text = 'wrayth'
    editor(:@label_entry).text = 'Duplicate'
    editor(:@command_entry).text = '/opt/duplicate'

    expect(manager.send(:save_current)).to be false
    expect(settings.replace_calls).to be_empty
    expect(editor(:@status_label).text).to include('Frontend ID is already in use')
  end

  it 'deletes custom definitions but refuses to delete built-ins' do
    tree_view = manager.instance_variable_get(:@tree_view)
    tree_view.selection.select_iter(rows_by_id.fetch('vellum'))

    expect(manager.send(:delete_current)).to be true
    expect(settings.replace_calls.last.fetch(:custom)).to be_empty
    expect(locator.refresh_count).to eq(1)
    expect(changes).to eq([:changed])

    expect(manager.send(:delete_current)).to be false
    expect(editor(:@status_label).text).to include('Built-in frontends cannot be deleted')
  end

  it 'reloads from disk, refreshes detection, retains selection, and notifies its caller' do
    tree_view = manager.instance_variable_get(:@tree_view)
    tree_view.selection.select_iter(rows_by_id.fetch('vellum'))
    settings.next_document = document.merge(
      'custom' => document.fetch('custom').merge(
        'vellum' => document.fetch('custom').fetch('vellum').merge('label' => 'Vellum Reloaded')
      )
    )

    expect(manager.reload!).to be true

    expect(settings.load_calls).to eq(['/saved'])
    expect(locator.refresh_count).to eq(1)
    expect(editor(:@id_entry).text).to eq('vellum')
    expect(rows_by_id.fetch('vellum')[described_class::LABEL_COLUMN]).to eq('Vellum Reloaded')
    expect(changes).to eq([:changed])
  end
end
