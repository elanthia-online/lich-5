# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require_relative '../../../lib/common/script_scope/gtk/session'
require_relative '../../../lib/common/script_scope/gtk/widgets'

# Widget text boundaries. Every text setter turns
# binary-tagged UTF-8 into UTF-8 and refuses other non-UTF-8 text at the call,
# as the model, table and text setters do, instead of at the next publication.
RSpec.describe 'script compatibility widget text' do
  port_class = Class.new do
    attr_reader :sets, :created

    def initialize
      @sets = []
      @created = []
    end

    def create(type, props)
      @created << [type, props]
      Object.new
    end

    def attach(*) = nil
    def detach(*) = nil
    def schema(type) = Lich::WebUI::Contract.schema(type)
    def bind(*) = 'binding'
    def set(_handle, property, value) = @sets << [property, value]
    def destroy(_handle) = nil
  end

  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name, :thread_group).new('widget_text.lic', ThreadGroup.new) }
  let(:port) { port_class.new }
  let(:session) { gtk::Session.new(owner) }
  let(:cafe) { 'caf'.b + [0xC3, 0xA9].pack('C*') }
  let(:accepted) { cafe.dup.force_encoding(Encoding::UTF_8) }
  # Binary-tagged non-UTF-8, valid ISO-8859-1, ISO-8859-1 bytes that happen to
  # form valid UTF-8, UTF-16 and UTF-8-tagged invalid bytes.
  let(:rejected) do
    [
      'caf'.b + [0xFF].pack('C*'),
      'caf'.dup.force_encoding(Encoding::ISO_8859_1) + [0xE9].pack('C*').force_encoding(Encoding::ISO_8859_1),
      'caf'.dup.force_encoding(Encoding::ISO_8859_1) + [0xC3, 0xA9].pack('C*').force_encoding(Encoding::ISO_8859_1),
      'hi'.encode(Encoding::UTF_16LE),
      ('caf'.b + [0xFF].pack('C*')).force_encoding(Encoding::UTF_8)
    ]
  end

  before do
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    allow(Lich::WebUI).to receive(:adapter).and_return(port)
    allow(Lich::WebUI).to receive(:callback_queue).and_return(proc { |&work| work.call })
    allow(Lich).to receive(:log)
    allow(gtk).to receive(:session) { session }
  end

  # [name, public operation named in the refusal, widget factory, setter, reader, published property]
  g = Lich::Common::ScriptScope::Gtk
  setters = [
    ['Label#text=', :text=, -> { g::Label.new('old') }, ->(w, v) { w.text = v }, :text, :content],
    ['Label#set_text', :text=, -> { g::Label.new('old') }, ->(w, v) { w.set_text(v) }, :text, :content],
    ['Label#text= with use_markup', :set_markup, -> { g::Label.new('old').tap { |l| l.use_markup = true } }, ->(w, v) { w.text = v }, :text, :content],
    ['Label#set_markup', :set_markup, -> { g::Label.new('old') }, ->(w, v) { w.set_markup(v) }, :text, :content],
    ['LinkButton#label=', :link, -> { g::LinkButton.new('https://example.com/', 'old') }, ->(w, v) { w.label = v }, :label, nil],
    ['ToggleButton#label=', :label=, -> { g::ToggleButton.new('old') }, ->(w, v) { w.label = v }, :label, :label],
    ['Button#label=', :label=, -> { g::Button.new('old') }, ->(w, v) { w.label = v }, :label, :label],
    ['Entry#text=', :text=, -> { g::Entry.new }, ->(w, v) { w.text = v }, :text, :value],
    ['Entry#placeholder_text=', :placeholder_text=, -> { g::Entry.new }, ->(w, v) { w.placeholder_text = v }, nil, :placeholder],
    ['Window#title=', :title=, -> { g::Window.new }, ->(w, v) { w.title = v }, :title, :title],
    ['Widget#tooltip_text=', :tooltip_text=, -> { g::Label.new('x') }, ->(w, v) { w.tooltip_text = v }, :tooltip_text, :tooltip],
    ['Widget#tooltip_markup=', :tooltip_markup=, -> { g::Label.new('x') }, ->(w, v) { w.tooltip_markup = v }, :tooltip_text, :tooltip],
    ['Frame#label=', :label=, -> { g::Frame.new('old') }, ->(w, v) { w.label = v }, :label, :label]
  ]

  setters.each do |name, operation, factory, setter, reader, property|
    it "#{name} re-tags binary-tagged UTF-8 and refuses other non-UTF-8 text at the call" do
      widget = factory.call
      widget.materialize
      before_value = reader && widget.public_send(reader)
      published = port.sets.dup

      rejected.each do |text|
        expect { setter.call(widget, text) }.to raise_error(gtk::UnsupportedOperation, /operation=#{operation}/)
      end
      expect(widget.public_send(reader)).to eq(before_value) if reader
      expect(port.sets).to eq(published)

      setter.call(widget, cafe)
      if reader
        value = widget.public_send(reader)
        expect([value, value.encoding]).to eq([accepted, Encoding::UTF_8])
      end
      expect(port.sets.last).to eq([property, accepted]) if property
      expect(port.sets.last.last.encoding).to eq(Encoding::UTF_8) if property
    end
  end

  it 'applies the same rule to text given at construction' do
    constructors = {
      label: [:new, ->(v) { gtk::Label.new(v).text }],
      toggle: [:new, ->(v) { gtk::ToggleButton.new(v).label }],
      button: [:new, ->(v) { gtk::Button.new(v).label }],
      window: [:new, ->(v) { gtk::Window.new(v).title }],
      frame: [:label=, ->(v) { gtk::Frame.new(v).label }],
      link: [:link, ->(v) { gtk::LinkButton.new('https://example.com/', v).label }]
    }
    constructors.each_value do |(operation, build)|
      rejected.each { |text| expect { build.call(text) }.to raise_error(gtk::UnsupportedOperation, /operation=#{operation}/) }
      value = build.call(cafe)
      expect([value, value.encoding]).to eq([accepted, Encoding::UTF_8])
    end
  end

  it 'publishes a re-tagged label as UTF-8 content' do
    window = gtk::Window.new
    window.add(gtk::Label.new(cafe))
    window.materialize
    contents = port.created.filter_map { |(_type, props)| props[:content] }

    expect(contents.map { |text| [text, text.encoding] }).to eq([[accepted, Encoding::UTF_8]])
  end
end
