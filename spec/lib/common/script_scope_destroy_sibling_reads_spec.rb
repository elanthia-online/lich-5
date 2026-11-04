# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require_relative '../../../lib/common/script_scope/gtk/session'
require_relative '../../../lib/common/script_scope/gtk/widgets'

# P12 share of 1844:RC8: a destroy handler that reads a sibling input while the
# owner's destroy sequence runs must get the sibling's last value from shadow
# state. The recording port retires handles on destroy and raises on any later
# read, as the adapter does.
RSpec.describe 'script compatibility destroy-time sibling reads' do
  port_class = Class.new do
    attr_reader :gets, :bindings

    def initialize
      @bindings = {}
      @values = {}
      @children = Hash.new { |hash, key| hash[key] = [] }
      @retired = {}.compare_by_identity
      @gets = []
    end

    def create(_type, _props) = Object.new
    def attach(parent, child, **) = @children[parent] << child
    def detach(*) = nil
    def schema(type) = Lich::WebUI::Contract.schema(type)

    def bind(handle, event, callback)
      @bindings[[handle, event]] = callback
      "binding-#{@bindings.size}"
    end

    def set(handle, property, value) = @values[[handle, property]] = value
    def seed(handle, property, value) = @values[[handle, property]] = value

    def get(handle, property)
      @gets << [handle, property]
      raise Lich::WebUI::Error, 'handle is already destroyed' if @retired.key?(handle)

      @values[[handle, property]]
    end

    def destroy(handle)
      @retired[handle] = true
      @children[handle].each { |child| destroy(child) }
    end
  end
  event_context = Struct.new(:viewer_id, :payload)

  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name, :thread_group).new('destroy_reads.lic', ThreadGroup.new) }
  let(:port) { port_class.new }
  let(:session) { gtk::Session.new(owner) }
  let(:logs) { [] }
  let(:window) { gtk::Window.new('form') }
  let(:first) { gtk::Entry.new }
  let(:second) { gtk::Entry.new }
  let(:button) { gtk::Button.new('Close') }
  let(:seen) { [] }

  before do
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    allow(Lich::WebUI).to receive(:adapter).and_return(port)
    allow(Lich::WebUI).to receive(:callback_queue).and_return(proc { |&work| work.call })
    allow(Lich).to receive(:log) { |message| logs << message }
    allow(gtk).to receive(:session) { session }

    box = gtk::VBox.new
    [first, second, button].each { |child| box.add(child) }
    window.add(box)
    # Each entry's destroy handler reads its sibling; the first one runs while
    # the second is not yet marked destroyed, the case 1844:RC8 reports.
    first.signal_connect('destroy') { seen << [:first, second.text] }
    second.signal_connect('destroy') { seen << [:second, first.text] }
    window.materialize
    port.seed(handle_of(first), :value, 'typed-one')
    port.seed(handle_of(second), :value, 'typed-two')
  end

  def cleanup_failures = logs.grep(/cleanup failed/)

  def handle_of(widget) = widget.instance_variable_get(:@handle)

  def input_reads(widgets)
    handles = widgets.map { |widget| handle_of(widget) }
    port.gets.select { |handle, property| property == :value && handles.include?(handle) }
  end

  it 'serves the sibling value when a button click destroys the window (1844:RC8)' do
    button.signal_connect('clicked') { window.destroy }

    port.bindings.fetch([handle_of(button), :activate]).call(event_context.new('viewer', {}))

    expect(cleanup_failures).to be_empty
    expect(seen).to eq([[:first, 'typed-two'], [:second, 'typed-one']])
    expect(window.destroyed?).to be(true)
  end

  it 'serves the sibling value on the browser close path, delete_event to destroy (1844:RC8)' do
    window.signal_connect('delete_event') { false }

    port.bindings.fetch([handle_of(window), :close]).call(event_context.new('viewer', {}))

    expect(cleanup_failures).to be_empty
    expect(seen).to eq([[:first, 'typed-two'], [:second, 'typed-one']])
    expect(window.destroyed?).to be(true)
  end

  it 'serves the sibling value when a handler closes the window through Window#close (1844:RC8)' do
    button.signal_connect('clicked') { window.close }

    port.bindings.fetch([handle_of(button), :activate]).call(event_context.new('viewer', {}))

    expect(cleanup_failures).to be_empty
    expect(seen).to eq([[:first, 'typed-two'], [:second, 'typed-one']])
  end

  it 'adds no port traffic during the destroy sequence beyond the terminal commit (1844:RC8)' do
    button.signal_connect('clicked') { window.destroy }
    port.bindings.fetch([handle_of(button), :activate]).call(event_context.new('viewer', {}))

    # The terminal action's commit_inputs reads each input once, before the
    # destroy; the destroy handlers add none.
    expect(input_reads([first, second]).size).to eq(2)
  end

  it 'keeps live reads for a widget outside a destroy sequence (1844:RC8)' do
    value = nil
    button.signal_connect('clicked') do
      port.seed(handle_of(first), :value, 'edited')
      value = first.text
    end

    port.bindings.fetch([handle_of(button), :activate]).call(event_context.new('viewer', {}))

    expect(value).to eq('edited')
  end
end
