# frozen_string_literal: true

require 'rspec'
require_relative '../../../../lib/common/front-end'
require_relative '../../../../lib/common/frontend_locator'
require_relative '../../../../lib/common/gui/frontend_selector'

RSpec.describe Lich::Common::GUI::FrontendSelector do
  let(:box_class) do
    Class.new do
      attr_reader :children

      def initialize(*)
        @children = []
      end

      def pack_start(child, **)
        @children << child
      end
    end
  end
  let(:label_class) do
    Class.new do
      attr_reader :text

      def initialize(text)
        @text = text
      end
    end
  end
  let(:radio_button_class) do
    Class.new do
      attr_accessor :tooltip_text
      attr_reader :group, :label

      def initialize(label:, member: nil)
        @label = label
        @group = member ? member.group : []
        @group << self
        self.active = member.nil?
      end

      def active?
        @active == true
      end

      def active=(value)
        @group.each { |button| button.instance_variable_set(:@active, false) } if value
        @active = value
      end

      def signal_connect(_signal, &callback)
        @callback = callback
      end

      def trigger
        @callback&.call
      end
    end
  end
  let(:locator) { double('frontend locator') }

  before do
    gtk = Module.new
    gtk.const_set(:Box, box_class)
    gtk.const_set(:Label, label_class)
    gtk.const_set(:RadioButton, radio_button_class)
    stub_const('Gtk', gtk)
  end

  def resolution(frontend_id, path = nil)
    Lich::Common::FrontendLocator::Resolution.new(
      frontend_id: frontend_id,
      executable_path: path || "/frontends/#{frontend_id}",
      source: :path
    )
  end

  it 'selects the requested available frontend' do
    allow(locator).to receive(:available).and_return(
      [resolution('stormfront'), resolution('avalon')]
    )

    selector = described_class.new(selected_id: 'avalon', locator: locator)

    expect(selector.selected_id).to eq('avalon')
  end

  it 'canonicalizes a requested frontend alias' do
    allow(locator).to receive(:available).and_return([resolution('stormfront')])

    selector = described_class.new(selected_id: 'wrayth', locator: locator)

    expect(selector.selected_id).to eq('stormfront')
  end

  it 'falls back to Wrayth and then the first available frontend' do
    allow(locator).to receive(:available).and_return(
      [resolution('avalon'), resolution('stormfront')],
      [resolution('avalon')]
    )

    expect(described_class.new(selected_id: 'wizard', locator: locator).selected_id)
      .to eq('stormfront')
    expect(described_class.new(selected_id: 'wizard', locator: locator).selected_id)
      .to eq('avalon')
  end

  it 'renders an explicit empty state' do
    allow(locator).to receive(:available).and_return([])

    selector = described_class.new(locator: locator)

    expect(selector).to be_empty
    expect(selector.selected_id).to be_nil
    expect(selector.widget.children.first.text).to eq('No supported frontend detected')
  end

  it 'reports native-only launch metadata for the selection' do
    allow(locator).to receive(:available).and_return([resolution('avalon')])

    expect(described_class.new(locator: locator)).to be_native_launch_only
  end

  it 'marks temporary launcher status in the option tooltip' do
    allow(locator).to receive(:available).and_return([resolution('saga')])

    selector = described_class.new(locator: locator)
    saga_button = selector.instance_variable_get(:@buttons).fetch('saga')

    expect(saga_button.tooltip_text).to include('Temporary Saga launch bridge')
  end

  it 'revalidates the selected frontend through the locator' do
    selected = resolution('stormfront')
    allow(locator).to receive(:available).and_return([selected])
    allow(locator).to receive(:resolve).with('stormfront', refresh: true).and_return(selected)

    selector = described_class.new(locator: locator)

    expect(selector.resolve_selected).to eq(selected)
  end

  it 'notifies listeners only when an option becomes active' do
    allow(locator).to receive(:available).and_return(
      [resolution('stormfront'), resolution('avalon')]
    )
    selector = described_class.new(locator: locator)
    changes = []
    selector.on_change { |changed| changes << changed.selected_id }
    buttons = selector.instance_variable_get(:@buttons)

    buttons['stormfront'].active = false
    buttons['stormfront'].trigger
    buttons['avalon'].active = true
    buttons['avalon'].trigger

    expect(changes).to eq(['avalon'])
  end
end
