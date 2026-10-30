# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/script_scope'

RSpec.describe 'owner-scoped CSS decoration bookkeeping' do
  let(:scope) { Lich::Common::ScriptScope }
  let(:gtk) { scope.const_get(:Gtk, false) }
  let(:gdk) { scope.const_get(:Gdk, false) }
  let(:owner) { Struct.new(:name).new('decoration.lic') }
  let(:service) { Lich::WebUI::Service.new }
  let(:label) { gtk.const_get(:Label).new('Unchanged') }
  let(:provider) { gtk.const_get(:CssProvider).new }
  let(:styles) { gtk.const_get(:StyleContext) }
  let(:screen) { gdk.const_get(:Screen).default }
  let(:application) { gtk.const_get(:StyleProvider)::PRIORITY_APPLICATION }
  let(:user) { gtk.const_get(:StyleProvider)::PRIORITY_USER }
  let(:progress_css) do
    'label { font-weight: bold; } trough { font-weight: bold; min-height: 22px; } progress { font-weight: bold; min-height: 20px; background-image: none; background-color: blue; }'
  end

  before do
    scope.activate!
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    allow(Lich::WebUI).to receive(:adapter) { |owner:, viewer: nil| Lich::WebUI::Adapter.new(owner: owner, service: service, viewer: viewer) }
    allow(Lich::WebUI).to receive(:callback_queue) { |owner:| proc { |&work| service.runtime.dispatch(owner: owner, &work) } }
    allow(Lich).to receive(:log)
  end

  after do
    Lich::Common::ScriptDeath.run(owner)
    Lich::Common::ScriptDeath.run(@other_owner) if @other_owner
    service.stop
  end

  it 'exposes cached contexts on supported widgets without changing their shared properties' do
    widgets = [label, gtk.const_get(:Entry).new, gtk.const_get(:Button).new('Click'), gtk.const_get(:Box).new(:vertical)]
    widgets.each do |widget|
      widget.materialize
      before = widget.send(:component_props).dup
      context = widget.style_context
      expect(widget.style_context).to equal(context)
      expect(widget.session.port).not_to receive(:set)
      context.add_provider(provider)
      provider.load(data: progress_css)
      context.add_class('required-setting')
      provider.load(data: 'label { color: red; }')
      context.remove_provider(provider)
      expect(widget.send(:component_props)).to eq(before)
    end
    expect(Lich).to have_received(:log).with(/operation=css_decoration/).once
  end

  it 'keeps class snapshots independent, bounded and local to each widget' do
    context = label.style_context
    name = +'required-setting'
    expect(context.add_class(name)).to equal(context)
    name.replace('changed')
    expect(context.has_class?('required-setting')).to be true
    snapshot = context.list_classes
    snapshot.first.replace('changed')
    snapshot << 'extra'
    expect(context.list_classes).to eq(['required-setting'])
    expect(gtk.const_get(:Label).new('Other').style_context.list_classes).to be_empty
    63.times { |index| context.add_class("class-#{index}") }
    expect(context.add_class('required-setting')).to equal(context)
    expect { context.add_class('overflow') }.to raise_error(gtk.const_get(:UnsupportedOperation))
    expect(context.remove_class('required-setting')).to equal(context)
    context.remove_class('required-setting')
    context.add_class('overflow')
    expect(context.has_class?('required-setting')).to be false
    expect(context.list_classes.length).to eq(64)
  end

  it 'refuses invalid class names and unknown methods with source attribution' do
    context = label.style_context
    [nil, 3, '', 'x' * 513, [255].pack('C').force_encoding('UTF-8'), 'valid'.encode('UTF-16LE')].each do |name|
      %i[add_class remove_class has_class?].each do |operation|
        expect { context.public_send(operation, name) }.to raise_error(gtk.const_get(:UnsupportedOperation))
      end
    end
    expect(context.list_classes).to be_empty
    expect { context.instance_eval('invented_style', 'decoration.lic', 17) }
      .to raise_error(gtk.const_get(:UnsupportedOperation), /operation=invented_style source=decoration.lic:17/)
    expect { styles.instance_eval('invented_style', 'decoration.lic', 18) }
      .to raise_error(gtk.const_get(:UnsupportedOperation), /operation=invented_style source=decoration.lic:18/)
    expect(styles).not_to respond_to(:invented_style)
    expect { context.list_classes('extra') }.to raise_error(ArgumentError)
  end

  it 'cleans descendant and unattached contexts, including providers and class names' do
    parent = gtk.const_get(:Box).new(:vertical)
    parent.add(label)
    context = label.style_context
    context.add_class('required-setting').add_provider(provider)
    parent.destroy
    expect(provider.instance_variable_get(:@contexts)).to be_empty
    expect(context.instance_variable_get(:@classes)).to be_empty
    expect { context.list_classes }.to raise_error(gtk.const_get(:UnsupportedOperation))
    expect { label.style_context }.to raise_error(gtk.const_get(:UnsupportedOperation))
    other = gtk.const_get(:Entry).new.style_context
    other.add_class('required-setting').add_provider(provider)
    Lich::Common::ScriptDeath.run(owner)
    expect(provider.instance_variable_get(:@contexts)).to be_empty
    expect(other.instance_variable_get(:@classes)).to be_empty
    expect { other.has_class?('required-setting') }.to raise_error(gtk.const_get(:UnsupportedOperation))
  end

  it 'bounds all widget contexts and releases the slot on destruction' do
    stub_const('Lich::WebUI::Contract::BOUNDS', Lich::WebUI::Contract::BOUNDS.merge(components: 1).freeze)
    label.style_context
    other = gtk.const_get(:Entry).new
    expect { other.style_context }.to raise_error(gtk.const_get(:UnsupportedOperation))
    label.destroy
    expect { other.style_context }.not_to raise_error
  end

  it 'keeps screen attachments inert across loads and accepts fresh default tokens for removal' do
    progress = gtk.const_get(:ProgressBar).new
    handle = progress.materialize
    expect(styles.add_provider_for_screen(screen, provider)).to be_nil
    provider.load(data: progress_css)
    expect(progress.session.port.get(handle, :fill_color)).to be_nil
    expect(progress.session.port.get(handle, :height)).to be_nil
    styles.add_provider_for_screen(gdk.const_get(:Screen).default, provider, user)
    registrations = progress.session.instance_variable_get(:@screen_style_providers)
    expect(registrations.to_a).to eq([[provider, user]])
    progress.style_context.add_provider(provider, application)
    styles.remove_provider_for_screen(gdk.const_get(:Screen).default, provider)
    styles.remove_provider_for_screen(screen, provider)
    expect(registrations).to be_empty
    expect(progress.session.port.get(handle, :fill_color)).to eq(r: 0, g: 0, b: 255, a: 1.0)
    provider.load(data: 'progress { border: 1px solid red; }')
    expect(progress.session.port.get(handle, :fill_color)).to be_nil
    expect(Lich).not_to have_received(:log).with(/screen_geometry/)
  end

  it 'bounds screen providers, allows reattachment at capacity and releases registrations' do
    providers = Array.new(64) { gtk.const_get(:CssProvider).new }
    providers.each { |candidate| styles.add_provider_for_screen(screen, candidate, application) }
    expect { styles.add_provider_for_screen(screen, provider) }.to raise_error(gtk.const_get(:UnsupportedOperation))
    styles.add_provider_for_screen(screen, providers.first, user)
    styles.remove_provider_for_screen(screen, providers.first)
    styles.add_provider_for_screen(screen, provider)
    registrations = provider.session.instance_variable_get(:@screen_style_providers)
    expect(registrations.length).to eq(64)
    Lich::Common::ScriptDeath.run(owner)
    expect(registrations).to be_empty
    expect { styles.add_provider_for_screen(screen, provider) }.to raise_error(gtk.const_get(:UnsupportedOperation))
    expect { styles.remove_provider_for_screen(screen, provider) }.to raise_error(gtk.const_get(:UnsupportedOperation))
  end

  it 'rejects invalid screens, providers, priorities and screen call shapes' do
    [nil, Object.new].each do |invalid|
      expect { styles.add_provider_for_screen(invalid, provider) }.to raise_error(gtk.const_get(:UnsupportedOperation))
      expect { styles.remove_provider_for_screen(screen, invalid) }.to raise_error(gtk.const_get(:UnsupportedOperation))
    end
    [0, 600.0, '800', nil].each do |priority|
      expect { styles.add_provider_for_screen(screen, provider, priority) }.to raise_error(gtk.const_get(:UnsupportedOperation))
    end
    expect { styles.remove_provider_for_screen(screen, provider, user) }.to raise_error(ArgumentError)
    expect(provider.session.instance_variable_get(:@screen_style_providers)).to be_empty
  end

  it 'rejects cross-owner screen, provider and cached-context use while keeping local classes separate' do
    first_screen, first_provider, first_label = screen, provider, label
    first_context = first_label.style_context
    first_context.add_class('required-setting')
    @other_owner = Struct.new(:name).new('other.lic')
    allow(Lich::Common::Script).to receive(:current).and_return(@other_owner)
    other_screen = gdk.const_get(:Screen).default
    other_provider = gtk.const_get(:CssProvider).new
    other_context = gtk.const_get(:Label).new('Other').style_context
    expect(other_context.list_classes).to be_empty
    other_context.add_class('required-setting')
    expect { first_context.remove_class('required-setting') }.to raise_error(gtk.const_get(:UnsupportedOperation))
    expect { first_label.style_context }.to raise_error(gtk.const_get(:UnsupportedOperation))
    expect { styles.add_provider_for_screen(first_screen, other_provider) }.to raise_error(gtk.const_get(:UnsupportedOperation))
    expect { styles.add_provider_for_screen(other_screen, first_provider) }.to raise_error(gtk.const_get(:UnsupportedOperation))
    expect { other_context.add_provider(first_provider) }.to raise_error(gtk.const_get(:UnsupportedOperation))
    expect { first_screen.width }.to raise_error(gtk.const_get(:UnsupportedOperation))
    styles.add_provider_for_screen(other_screen, other_provider)
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    expect(first_context.has_class?('required-setting')).to be true
    expect { styles.remove_provider_for_screen(other_screen, other_provider) }.to raise_error(gtk.const_get(:UnsupportedOperation))
  end

  it 'consolidates CSS notices and reports geometry only when dimensions are read' do
    allow(service).to receive(:monitor_geometry).and_return(source: 'unavailable', fallback: true)
    context = label.style_context
    context.instance_eval("add_class('required-setting')", 'decoration.lic', 71)
    context.add_provider(provider)
    provider.load(data: 'label { color: red; }')
    styles.add_provider_for_screen(screen, provider)
    expect(Lich).to have_received(:log).with(/operation=css_decoration source=decoration.lic:71/).once
    expect(Lich).not_to have_received(:log).with(/screen_geometry/)
    expect(screen.instance_eval('width', 'decoration.lic', 81)).to eq(1024)
    expect(screen.height).to eq(768)
    expect(Lich).to have_received(:log).with(/operation=screen_geometry source=decoration.lic:81/).once
  end
end
