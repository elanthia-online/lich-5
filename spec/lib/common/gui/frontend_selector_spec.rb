# frozen_string_literal: true

require 'rspec'
require_relative '../../../../lib/common/front-end'
require_relative '../../../../lib/common/frontend_locator'
require_relative '../../../../lib/common/gui/frontend_selector'

RSpec.describe Lich::Common::GUI::FrontendSelector do
  let(:combo_box_text_class) do
    Class.new do
      attr_accessor :tooltip_text
      attr_reader :entries

      def initialize(*)
        @entries = []
        @handlers = []
      end

      def append(id, label)
        @entries << [id, label]
      end

      def remove_all
        @entries.clear
        @active_id = nil
      end

      def active_id
        @active_id
      end

      def active_id=(id)
        @active_id = id
      end

      def signal_connect(signal, &callback)
        @handlers << callback if signal == 'changed'
      end

      def select(id)
        self.active_id = id
        @handlers.each(&:call)
      end
    end
  end
  let(:locator) { double('frontend locator') }

  before do
    gtk = Module.new
    gtk.const_set(:ComboBoxText, combo_box_text_class)
    stub_const('Gtk', gtk)
  end

  def resolution(frontend_id, path = nil)
    Lich::Common::FrontendLocator::Resolution.new(
      frontend_id: frontend_id,
      executable_path: path || "/frontends/#{frontend_id}",
      source: :path
    )
  end

  it 'selects the requested configurable frontend even when it is unavailable' do
    allow(Lich::Common::Frontend).to receive(:platform_key).and_return(:darwin)
    allow(locator).to receive(:available).and_return(
      [resolution('stormfront')]
    )

    selector = described_class.new(selected_id: 'avalon', locator: locator)

    expect(selector.selected_id).to eq('avalon')
  end

  it 'canonicalizes a requested frontend alias' do
    allow(locator).to receive(:available).and_return([resolution('stormfront')])

    selector = described_class.new(selected_id: 'wrayth', locator: locator)

    expect(selector.selected_id).to eq('stormfront')
  end

  it 'falls back to Wrayth when the requested frontend is not configurable' do
    allow(locator).to receive(:available).and_return([resolution('avalon')])

    expect(described_class.new(selected_id: 'unknown', locator: locator).selected_id)
      .to eq('stormfront')
  end

  it 'keeps all configurable frontends visible when none are detected' do
    allow(locator).to receive(:available).and_return([])

    selector = described_class.new(locator: locator)

    expect(selector).not_to be_empty
    expect(selector.widget.entries).to include(
      ['stormfront', 'Wrayth (unavailable)'],
      ['wizard', 'Wizard (unavailable)'],
      ['saga', 'Saga (unavailable)']
    )
  end

  it 'keeps the historical Wrayth default selectable when no executable is detected' do
    allow(locator).to receive(:available).and_return([])

    selector = described_class.new(locator: locator)

    expect(selector.selected_id).to eq('stormfront')
  end

  it 'preserves a saved Profanity association instead of silently selecting Wrayth' do
    allow(locator).to receive(:available).and_return([])

    selector = described_class.new(selected_id: 'profanity', locator: locator)

    expect(selector.widget.entries.map(&:first)).to include('profanity')
    expect(selector.selected_id).to eq('profanity')
  end

  it 'reports native-only launch metadata for the selection' do
    allow(Lich::Common::Frontend).to receive(:platform_key).and_return(:darwin)
    allow(locator).to receive(:available).and_return([resolution('avalon')])

    expect(described_class.new(selected_id: 'avalon', locator: locator)).to be_native_launch_only
  end

  it 'marks the Saga cold-start limitation in the option tooltip' do
    allow(locator).to receive(:available).and_return([resolution('saga')])

    selector = described_class.new(selected_id: 'saga', locator: locator)

    expect(selector.widget.tooltip_text).to include('Saga 0.8.5 environment handoff; cold start only')
  end

  it 'labels detected frontends and exposes their resolved path in the tooltip' do
    allow(locator).to receive(:available).and_return([resolution('stormfront', '/frontends/Wrayth.exe')])

    selector = described_class.new(locator: locator)

    expect(selector.widget.entries.first).to eq(['stormfront', 'Wrayth (detected)'])
    expect(selector.widget.tooltip_text).to include('/frontends/Wrayth.exe')
  end

  it 'revalidates the selected frontend through the locator' do
    selected = resolution('stormfront')
    allow(locator).to receive(:available).and_return([selected])
    allow(locator).to receive(:resolve).with('stormfront', refresh: true).and_return(selected)

    selector = described_class.new(locator: locator)

    expect(selector.resolve_selected).to eq(selected)
  end

  it 'treats a configured custom command as launchable without native executable discovery' do
    configurable = double('frontend catalog')
    definitions = [
      {
        id: 'vellum',
        metadata: {
          display_name: 'VellumFE',
          gui_selectable: true,
          launcher_adapter: :custom,
          launch_command: 'vellum-fe'
        }
      }
    ]
    allow(configurable).to receive(:definitions).with(gui_selectable: true).and_return(definitions)
    allow(configurable).to receive(:platform_key).and_return(:linux)
    allow(configurable).to receive(:canonical_name) { |id| id.to_s }
    allow(configurable).to receive(:definition_for).with('vellum').and_return(definitions.first)
    allow(configurable).to receive(:display_name).with('vellum').and_return('VellumFE')
    allow(locator).to receive(:available).and_return([])
    allow(locator).to receive(:resolve)
    selector = described_class.new(selected_id: 'vellum', locator: locator, frontend: configurable)

    expect(selector).to be_launchable
    expect(selector.widget.entries).to eq([['vellum', 'VellumFE (configured)']])
    expect(selector.widget.tooltip_text).to eq('vellum-fe')
    expect(locator).not_to have_received(:resolve)
  end

  it 'notifies listeners when the dropdown selection changes' do
    allow(locator).to receive(:available).and_return(
      [resolution('stormfront'), resolution('avalon')]
    )
    selector = described_class.new(locator: locator)
    changes = []
    selector.on_change { |changed| changes << changed.selected_id }

    selector.widget.select('avalon')

    expect(changes).to eq(['avalon'])
  end

  it 'reloads definitions and detection state in place while retaining the stable selection' do
    configurable = double('frontend catalog')
    definitions = [
      { id: 'stormfront', metadata: { display_name: 'Wrayth' } },
      { id: 'custom-one', metadata: { display_name: 'Custom One' } }
    ]
    allow(configurable).to receive(:definitions).with(gui_selectable: true) { definitions }
    allow(configurable).to receive(:platform_key).and_return(:linux)
    allow(configurable).to receive(:canonical_name) { |id| id.to_s }
    allow(configurable).to receive(:definition_for) do |id|
      definitions.find { |definition| definition[:id] == id }
    end
    allow(configurable).to receive(:display_name) { |id| id == 'stormfront' ? 'Wrayth' : 'Custom One' }
    allow(locator).to receive(:available).and_return([], [resolution('custom-one')])
    selector = described_class.new(selected_id: 'custom-one', locator: locator, frontend: configurable)

    selector.reload!

    expect(selector.selected_id).to eq('custom-one')
    expect(selector.widget.entries).to include(['custom-one', 'Custom One (detected)'])
    expect(selector.widget.tooltip_text).to include('/frontends/custom-one')
  end

  it 'filters definitions explicitly unsupported on the current platform' do
    configurable = double('frontend catalog')
    allow(configurable).to receive(:definitions).with(gui_selectable: true).and_return(
      [
        { id: 'stormfront', metadata: { display_name: 'Wrayth' } },
        { id: 'mac-only', metadata: { display_name: 'Mac only', gui_platforms: [:darwin] } }
      ]
    )
    allow(configurable).to receive(:platform_key).and_return(:linux)
    allow(configurable).to receive(:canonical_name) { |id| id.to_s }
    allow(configurable).to receive(:definition_for) do |id|
      { id: id, metadata: { display_name: id == 'stormfront' ? 'Wrayth' : 'Mac only' } }
    end
    allow(configurable).to receive(:display_name) { |id| id.to_s.capitalize }
    allow(locator).to receive(:available).and_return([])

    selector = described_class.new(locator: locator, frontend: configurable)

    expect(selector.widget.entries).to eq([['stormfront', 'Wrayth (unavailable)']])
  end
end
