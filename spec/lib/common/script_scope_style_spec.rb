# frozen_string_literal: true

require 'timeout'
require_relative '../../spec_helper'
require_relative '../../../lib/common/script_scope'

RSpec.describe 'progress provider lifecycle' do
  let(:scope) { Lich::Common::ScriptScope }
  let(:gtk) { scope.const_get(:Gtk, false) }
  let(:owner) { Struct.new(:name).new('style.lic') }
  let(:service) { Lich::WebUI::Service.new }
  let(:bar) { gtk.const_get(:ProgressBar).new }
  let(:provider) { gtk.const_get(:CssProvider).new }
  let(:application) { gtk.const_get(:StyleProvider)::PRIORITY_APPLICATION }
  let(:user) { gtk.const_get(:StyleProvider)::PRIORITY_USER }
  let(:blue) { { r: 0, g: 0, b: 255, a: 1.0 } }

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

  it 'applies arbitrary class-qualified label cues through provider and ancestor lifecycles' do
    screen = scope.const_get(:Gdk, false)::Screen.default
    window = gtk::Window.new('Cues')
    window.set_name('review_form')
    grid = gtk::Grid.new
    label = gtk::Label.new('Required value')
    label.style_context.add_class('mandatory')
    grid.attach(label, 0, 0, 1, 1)
    window.add(grid)
    gtk::StyleContext.add_provider_for_screen(screen, provider, user)
    provider.load(data: '#review_form grid label.mandatory { color: #ff4d4d; }')
    window.show_all
    handle = label.materialize
    expect(label.session.port.get(handle, :foreground)).to eq(r: 255, g: 77, b: 77, a: 1.0)
    label.style_context.remove_class('mandatory')
    expect(label.session.port.get(handle, :foreground)).to be_nil
    label.style_context.add_class('mandatory')
    window.name = 'different'
    expect(label.session.port.get(handle, :foreground)).to be_nil
    window.name = 'review_form'
    provider.load_from_data('label.mandatory {color: #0000ff}')
    expect(label.session.port.get(handle, :foreground)).to eq(blue)
    local = gtk::CssProvider.new
    local.load(data: 'label.mandatory {color: #00ff00}')
    label.style_context.add_provider(local, user)
    expect(label.session.port.get(handle, :foreground)).to eq(r: 0, g: 255, b: 0, a: 1.0)
    label.style_context.remove_provider(local)
    expect(label.session.port.get(handle, :foreground)).to eq(blue)
    gtk::StyleContext.remove_provider_for_screen(screen, provider)
    expect(label.session.port.get(handle, :foreground)).to be_nil
    expect(label.materialize).to equal(handle)
    provider.load(data: 'label.mandatory {color: url(https://invalid.example)}')
    expect(provider.label_rules).to be_empty
  end

  it 'isolates label rules across owners and releases contexts after destruction' do
    label = gtk::Label.new('First')
    label.style_context.add_class('notice')
    provider.load(data: 'label.notice {color: #0000ff}')
    gtk::StyleContext.add_provider_for_screen(scope.const_get(:Gdk, false)::Screen.default, provider)
    expect(label.send(:component_props)[:foreground]).to eq(blue)
    @other_owner = Struct.new(:name).new('other.lic')
    allow(Lich::Common::Script).to receive(:current).and_return(@other_owner)
    other = gtk::Label.new('Other')
    other.style_context.add_class('notice')
    expect(other.send(:component_props)).not_to have_key(:foreground)
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    label.destroy
    expect { provider.load(data: 'label.notice {color: #00ff00}') }.not_to raise_error
  end

  def stylesheet(color = 'blue', terminator = ';')
    "label { font-weight: bold; } trough {font-weight: bold; min-height: 22px; } progress {font-weight: bold; min-height: 20px; background-image: none; background-color: #{color}#{terminator}}"
  end

  def live_bar
    window = gtk.const_get(:Window).new
    window.add(bar)
    window.materialize
    bar.materialize
  end

  it 'accepts the staminabar2 progress declarations with no final semicolon' do
    # Mirror lib/staminabar2.lic:34-36, whitespace normalized, unchanged declarations.
    # SHA256 c6d2d696ac57ea13d8359dc4650a4a7a209706ecf6c8af06e6be252e3058d377.
    provider.load(data: stylesheet('blue', ''))
    bar.style_context.add_provider(provider, user)
    expect(bar.send(:component_props)).to include(height: 24, fill_color: blue)
  end

  it 'updates every attached live bar when loaded after attachment or reloaded positionally' do
    handle = live_bar
    other = gtk.const_get(:ProgressBar).new
    other_handle = other.materialize
    bar.style_context.add_provider(provider, application)
    other.style_context.add_provider(provider)
    expect(provider.loaded?).to be false
    expect(bar.session.port.get(handle, :fill_color)).to be_nil
    expect(provider.load_from_data(stylesheet)).to be true
    expect(provider.loaded?).to be true
    expect(bar.session.port.get(handle, :fill_color)).to eq(blue)
    provider.load(data: stylesheet('gold'))
    [handle, other_handle].each do |target|
      expect(bar.session.port.get(target, :fill_color)).to eq(r: 255, g: 215, b: 0, a: 1.0)
    end
    bar.set_fraction(0.75)
    expect(bar.session.port.get(handle, :value)).to eq(0.75)
    expect(bar.materialize).to equal(handle)
  end

  it 'restores omitted live properties without replacing the handle or disturbing fraction' do
    handle = live_bar
    provider.load(data: stylesheet)
    bar.style_context.add_provider(provider, user)
    bar.set_fraction(0.4)
    bar.style_context.remove_provider(provider)
    bar.style_context.remove_provider(provider)
    expect(bar.materialize).to equal(handle)
    expect(bar.session.port.get(handle, :fill_color)).to be_nil
    expect(bar.session.port.get(handle, :height)).to be_nil
    expect(bar.session.port.get(handle, :value)).to eq(0.4)
    expect(bar.send(:component_props)).not_to have_key(:fill_color)
    expect(bar.send(:component_props)).not_to have_key(:height)
  end

  it 'restores a height authored before attachment and preserves later explicit writes through reloads' do
    bar.height_request = 31
    handle = live_bar
    provider.load(data: stylesheet)
    bar.style_context.add_provider(provider)
    expect(bar.session.port.get(handle, :height)).to eq(24)
    bar.style_context.remove_provider(provider)
    expect(bar.session.port.get(handle, :height)).to eq(31)
    bar.style_context.add_provider(provider)
    bar.height_request = 42
    provider.load(data: stylesheet('gold'))
    expect(bar.session.port.get(handle, :height)).to eq(42)
    bar.style_context.remove_provider(provider)
    expect(bar.session.port.get(handle, :height)).to eq(42)
  end

  it 'uses priority then attachment order and reveals the remaining provider on removal' do
    provider.load(data: stylesheet)
    second = gtk.const_get(:CssProvider).new
    second.load(data: stylesheet('gold'))
    bar.style_context.add_provider(provider, user)
    bar.style_context.add_provider(second, application)
    expect(bar.send(:component_props)[:fill_color]).to eq(blue)
    bar.style_context.add_provider(second, user)
    expect(bar.send(:component_props)[:fill_color][:r]).to eq(255)
    bar.style_context.remove_provider(second)
    expect(bar.send(:component_props)[:fill_color]).to eq(blue)
    bar.style_context.remove_provider(provider)
    expect(bar.send(:component_props)).not_to have_key(:fill_color)
  end

  it 'ignores unloaded higher-priority providers until successfully loaded' do
    provider.load(data: stylesheet)
    pending = gtk.const_get(:CssProvider).new
    bar.style_context.add_provider(provider, application)
    bar.style_context.add_provider(pending, user)
    expect(bar.send(:component_props)[:fill_color]).to eq(blue)
    pending.load(data: stylesheet('gold'))
    expect(bar.send(:component_props)[:fill_color][:r]).to eq(255)
  end

  it 'refuses invalid input without changing the previous style' do
    provider.load(data: stylesheet)
    handle = live_bar
    bar.style_context.add_provider(provider)
    [nil, 12, 'x' * 8193, [255].pack('C').force_encoding('UTF-8'), stylesheet.encode('UTF-16LE')].each do |input|
      expect { provider.load(data: input) }.to raise_error(gtk.const_get(:UnsupportedOperation), /operation=load/)
      expect(provider.fill_color).to eq(blue)
      expect(bar.session.port.get(handle, :fill_color)).to eq(blue)
    end
  end

  it 'distinguishes unloaded, recognized and omitted providers without retaining source CSS' do
    expect(provider.state).to eq(:unloaded)
    expect(provider.loaded?).to be false
    expect(provider.load_from_data('button { color: red; }')).to be true
    expect(provider.state).to eq(:omitted)
    expect(provider.loaded?).to be true
    expect(provider.fill_color).to be_nil
    provider.load(data: stylesheet)
    expect(provider.state).to eq(:recognized)
    expect(provider.fill_color).to eq(blue)
    ['', 'x' * 8192, stylesheet('unknown'), stylesheet.sub('22px', '23px'),
     stylesheet + 'button { color: red; }', stylesheet.sub('bold;', 'bold'),
     '@import url(https://invalid/private); progress { background: url(file:///private/secret); }'].each do |css|
      expect(provider.load(data: css)).to be true
      expect(provider.state).to eq(:omitted)
      expect(provider.fill_color).to be_nil
      expect(provider.instance_variables.map { |name| provider.instance_variable_get(name) }).not_to include(css)
    end
    expect(Lich).to have_received(:log).with(/operation=css_decoration/).once
    expect(Lich).not_to have_received(:log).with(/private\/secret|https:\/\/invalid/)
  end

  it 'clears recognized effects on every live bar when reloaded as omitted and can restore them' do
    handle = live_bar
    other = gtk.const_get(:ProgressBar).new
    other.height_request = 31
    other_handle = other.materialize
    bar.style_context.add_provider(provider)
    other.style_context.add_provider(provider)
    provider.load(data: 'button { color: red; }')
    expect(bar.session.port.get(handle, :fill_color)).to be_nil
    provider.load(data: stylesheet)
    bar.set_fraction(0.4)
    other.set_fraction(0.7)
    provider.load_from_data('progress { background-image: url(https://invalid); }')
    [handle, other_handle].each { |target| expect(bar.session.port.get(target, :fill_color)).to be_nil }
    expect(bar.session.port.get(handle, :height)).to be_nil
    expect(bar.session.port.get(other_handle, :height)).to eq(31)
    expect(bar.session.port.get(handle, :value)).to eq(0.4)
    expect(bar.session.port.get(other_handle, :value)).to eq(0.7)
    expect(bar.materialize).to equal(handle)
    expect(other.materialize).to equal(other_handle)
    provider.load(data: stylesheet('gold'))
    [handle, other_handle].each do |target|
      expect(bar.session.port.get(target, :fill_color)).to eq(r: 255, g: 215, b: 0, a: 1.0)
      expect(bar.session.port.get(target, :height)).to eq(24)
    end
    other.height_request = 42
    provider.load(data: 'label { color: red; }')
    expect(bar.session.port.get(other_handle, :height)).to eq(42)
  end

  it 'reveals another recognized provider when the higher priority one becomes omitted' do
    provider.load(data: stylesheet)
    second = gtk.const_get(:CssProvider).new
    second.load(data: stylesheet('gold'))
    bar.style_context.add_provider(provider, application)
    bar.style_context.add_provider(second, user)
    second.load(data: 'progress { border: 1px solid red; }')
    expect(bar.send(:component_props)).to include(fill_color: blue, height: 24)
    bar.style_context.remove_provider(provider)
    expect(bar.send(:component_props)).not_to have_key(:fill_color)
    expect(bar.send(:component_props)).not_to have_key(:height)
    second.load(data: stylesheet('gold'))
    expect(bar.send(:component_props)[:fill_color][:r]).to eq(255)
    bar.style_context.remove_provider(second)
    expect(bar.send(:component_props)).not_to have_key(:fill_color)
  end

  it 'preserves unloaded and omitted states on invalid input and refuses unsupported call shapes' do
    [false, true].each do |loaded|
      provider.load(data: 'label { color: red; }') if loaded
      state = provider.state
      expect { provider.load(data: nil) }.to raise_error(gtk.const_get(:UnsupportedOperation))
      expect { provider.load('label {}') }.to raise_error(ArgumentError)
      expect { provider.load(data: '', unrelated: true) }.to raise_error(ArgumentError)
      expect(provider.state).to eq(state)
      expect(provider.loaded?).to eq(loaded)
    end
  end

  it 'attributes one omission notice per owner and keeps omitted providers isolated and detached' do
    first_provider, first_bar = provider, bar
    first_bar.style_context.add_provider(first_provider)
    2.times { first_provider.instance_eval("load(data: 'label { color: red; }')", 'style.lic', 95) }
    gtk.const_get(:CssProvider).new.load(data: 'button { color: red; }')
    expect(Lich).to have_received(:log).with(/script=style.lic .*operation=css_decoration source=style.lic:95/).once
    @other_owner = Struct.new(:name).new('other.lic')
    allow(Lich::Common::Script).to receive(:current).and_return(@other_owner)
    other_provider = gtk.const_get(:CssProvider).new
    other_provider.instance_eval("load(data: 'label { color: red; }')", 'other.lic', 21)
    expect(Lich).to have_received(:log).with(/script=other.lic .*operation=css_decoration source=other.lic:21/).once
    expect { first_provider.load(data: stylesheet) }.to raise_error(gtk.const_get(:UnsupportedOperation))
    expect(first_provider.state).to eq(:omitted)
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    first_bar.destroy
    expect(first_provider.instance_variable_get(:@contexts)).to be_empty
    expect { first_provider.load(data: stylesheet) }.not_to raise_error
    Lich::Common::ScriptDeath.run(owner)
    expect { first_provider.load(data: 'label {}') }.to raise_error(gtk.const_get(:UnsupportedOperation))
  end

  it 'rejects invalid attachments and attributes unknown style calls to source' do
    [nil, Object.new].each do |invalid|
      expect { bar.style_context.add_provider(invalid) }.to raise_error(gtk.const_get(:UnsupportedOperation))
    end
    [0, 600.0, '800', nil].each do |priority|
      expect { bar.style_context.add_provider(provider, priority) }.to raise_error(gtk.const_get(:UnsupportedOperation))
    end
    expect { bar.style_context.instance_eval('invented_style', 'style.lic', 71) }
      .to raise_error(gtk.const_get(:UnsupportedOperation), /operation=invented_style source=style.lic:71/)
    expect(bar.style_context).not_to respond_to(:invented_style)
    expect { provider.instance_eval('invented_style', 'style.lic', 72) }
      .to raise_error(gtk.const_get(:UnsupportedOperation), /source=style.lic:72/)
  end

  it 'isolates owners and refuses cross-owner attachment and mutation' do
    first_provider, first_bar = provider, bar
    first_provider.load(data: stylesheet)
    first_bar.style_context.add_provider(first_provider)
    @other_owner = Struct.new(:name).new('other.lic')
    allow(Lich::Common::Script).to receive(:current).and_return(@other_owner)
    other = gtk.const_get(:ProgressBar).new
    expect { other.style_context.add_provider(first_provider) }.to raise_error(gtk.const_get(:UnsupportedOperation))
    expect { first_provider.load(data: stylesheet('gold')) }.to raise_error(gtk.const_get(:UnsupportedOperation))
    expect { first_bar.style_context.remove_provider(first_provider) }.to raise_error(gtk.const_get(:UnsupportedOperation))
    expect(first_bar.send(:component_props)[:fill_color]).to eq(blue)
    expect(other.send(:component_props)).not_to have_key(:fill_color)
  end

  it 'releases providers when a parent retires descendants and on owner death for unattached bars' do
    parent = gtk.const_get(:Box).new(:vertical)
    parent.add(bar)
    bar.style_context.add_provider(provider)
    retained = bar.style_context
    parent.destroy
    expect { provider.load(data: stylesheet) }.not_to raise_error
    expect(bar.send(:component_props)).not_to have_key(:fill_color)
    expect { retained.add_provider(provider) }.to raise_error(gtk.const_get(:UnsupportedOperation))
    other = gtk.const_get(:ProgressBar).new
    other.style_context.add_provider(provider)
    Lich::Common::ScriptDeath.run(owner)
    expect { provider.load(data: stylesheet('gold')) }.to raise_error(gtk.const_get(:UnsupportedOperation))
    expect { other.style_context.remove_provider(provider) }.to raise_error(gtk.const_get(:UnsupportedOperation))
    expect(provider.instance_variable_get(:@contexts)).to be_empty
  end

  %i[bar window].each do |target_kind|
    it "serializes #{target_kind} destruction with reloads of a shared provider" do
      window = gtk.const_get(:Window).new
      window.add(bar)
      window.materialize
      handle = bar.materialize
      other = gtk.const_get(:ProgressBar).new
      other_handle = other.materialize
      provider.load(data: stylesheet)
      bar.style_context.add_provider(provider)
      other.style_context.add_provider(provider)
      target = target_kind == :bar ? bar : window
      destroyed = []
      bar.signal_connect('destroy') { destroyed << :bar }
      entered, resume, started = Queue.new, Queue.new, Queue.new
      port = bar.session.port
      allow(port).to receive(:set).and_wrap_original do |original, control, property, value|
        if control.equal?(handle) && property == :fill_color
          entered << true
          resume.pop
        end
        original.call(control, property, value)
      end
      loader = Thread.new { provider.load(data: stylesheet('gold')) }
      Timeout.timeout(3) { entered.pop }
      destroyer = Thread.new do
        started << true
        target.destroy
      end
      Timeout.timeout(3) do
        started.pop
        sleep 0.001 until destroyer.status == 'sleep' || !destroyer.alive?
      end
      # The publisher has checked liveness but has not yet written the new fill.
      # Destruction must wait before retiring the adapter handle, not just cleanup.
      expect(port.get(handle, :fill_color)).to eq(blue)
      resume << true
      expect(Timeout.timeout(3) { loader.value }).to be true
      expect(Timeout.timeout(3) { destroyer.value }).to equal(target)
      expect(port.get(other_handle, :fill_color)).to eq(r: 255, g: 215, b: 0, a: 1.0)
      expect(destroyed).to eq([:bar])
      expect(target.destroy).to equal(target)
      expect(destroyed).to eq([:bar])
      provider.load(data: stylesheet('orchid'))
      expect(port.get(other_handle, :fill_color)).to eq(r: 218, g: 112, b: 214, a: 1.0)
      expect(provider.instance_variable_get(:@contexts).keys).to eq([other.style_context])
    ensure
      resume << true if resume
      [loader, destroyer].compact.each do |worker|
        worker.report_on_exception = false
        worker.join(3) || worker.kill.join
      rescue StandardError
        # Preserve the original assertion failure while cleaning up test threads.
      end
    end
  end

  it 'serializes repeated window destruction including its retained geometry snapshot' do
    window = gtk.const_get(:Window).new
    window.set_default_size(320, 180)
    handle = window.materialize
    entered, resume, started = Queue.new, Queue.new, Queue.new
    port = window.session.port
    first = nil
    allow(port).to receive(:get).and_wrap_original do |original, control, property|
      if Thread.current.equal?(first) && control.equal?(handle) && property == :size
        entered << true
        resume.pop
      end
      original.call(control, property)
    end
    first = Thread.new do
      started.pop
      window.destroy
    end
    started << true
    Timeout.timeout(3) { entered.pop }
    second = Thread.new do
      started << true
      window.destroy
    end
    Timeout.timeout(3) do
      started.pop
      sleep 0.001 until second.status == 'sleep' || !second.alive?
    end
    expect(port.get(handle, :size)).to eq([320, 180])
    resume << true
    expect(Timeout.timeout(3) { first.value }).to equal(window)
    expect(Timeout.timeout(3) { second.value }).to equal(window)
    expect([window.allocation.width, window.allocation.height]).to eq([320, 180])
  ensure
    resume << true if resume
    [first, second].compact.each do |worker|
      worker.report_on_exception = false
      worker.join(3) || worker.kill.join
    rescue StandardError
      # Preserve the original assertion failure while cleaning up test threads.
    end
  end

  it 'bounds registrations, permits reattachment at capacity and frees slots on removal' do
    providers = Array.new(64) { gtk.const_get(:CssProvider).new }
    providers.each { |candidate| bar.style_context.add_provider(candidate) }
    expect { bar.style_context.add_provider(provider) }.to raise_error(gtk.const_get(:UnsupportedOperation))
    expect { bar.style_context.add_provider(providers.first, user) }.not_to raise_error
    bar.style_context.remove_provider(providers.first)
    expect { bar.style_context.add_provider(provider) }.not_to raise_error
  end

  it 'bounds session contexts and releases their slots when widgets retire' do
    stub_const('Lich::WebUI::Contract::BOUNDS', Lich::WebUI::Contract::BOUNDS.merge(components: 1).freeze)
    bar.style_context
    other = gtk.const_get(:ProgressBar).new
    expect { other.style_context }.to raise_error(gtk.const_get(:UnsupportedOperation))
    bar.destroy
    expect { other.style_context }.not_to raise_error
  end

  it 'keeps unsupported drawing and unrelated style operations as explicit hard stops' do
    area = gtk.const_get(:DrawingArea).new
    area.signal_connect('draw') { |_widget, context| context.arc(0, 0, 1) }
    expect { area.queue_draw }.to raise_error(gtk.const_get(:UnsupportedOperation))
    label = gtk.const_get(:Label).new('Unchanged')
    expect { label.style_context.get_property('color') }.to raise_error(gtk.const_get(:UnsupportedOperation))
    expect { gtk.const_get(:StyleContext).reset_widgets }.to raise_error(gtk.const_get(:UnsupportedOperation))
  end

  it 'projects numeric RGBA onto label text before and after publication without changing content' do
    gdk = scope.const_get(:Gdk)
    label = gtk::Label.new('Original')
    color = gdk::RGBA.new(0.5, 0, 1, 0.25)
    expect(color.to_h).to eq(r: 128, g: 0, b: 255, a: 0.25)
    expect(color.to_h).to be_frozen
    expect(label.override_color(gtk::StateFlags::NORMAL, color)).to equal(label)
    label.set_xalign(0)
    label.set_yalign(0)
    entry = gtk::Entry.new
    entry.width_chars = 12
    expect(entry.send(:component_props)[:min_width_chars]).to eq(12)
    expect { entry.width_chars = 0 }.to raise_error(gtk::UnsupportedOperation)
    label.label = 'Updated'
    window = gtk::Window.new
    window.add(label)
    window.show_all
    page = nil
    Timeout.timeout(2) { sleep 0.001 until (page = service.registry.pages_for(owner).first)&.last_render }
    text = page.last_render.tree.each.find { |node| node.type == :text }
    expect(text.props).to include(content: 'Updated', foreground: color.to_h, align: 'start', content_vertical_align: 'start')
    label.override_color(:normal, gdk::RGBA.new(0, 1, 0, 1))
    expect(label.session.port.get(label.materialize, :foreground)).to eq(r: 0, g: 255, b: 0, a: 1.0)
    expect(label.label).to eq('Updated')
  end

  it 'preserves a matching CSS label cue until its provider is removed' do
    label = gtk::Label.new('Color precedence')
    label.style_context.add_class('required')
    provider.load(data: 'label.required { color: blue; }')
    label.style_context.add_provider(provider)
    window = gtk::Window.new
    window.add(label)
    window.show_all
    label.override_color(:normal, scope.const_get(:Gdk)::RGBA.new(1, 0, 0, 1))
    expect(label.session.port.get(label.materialize, :foreground)).to eq(blue)
    label.style_context.remove_provider(provider)
    expect(label.session.port.get(label.materialize, :foreground)).to eq(r: 255, g: 0, b: 0, a: 1.0)
  end

  it 'reports theme-owned control colors once and refuses invalid or foreign color operations' do
    color = scope.const_get(:Gdk)::RGBA.new(1, 0, 0, 1)
    button = gtk::CheckButton.new('Theme caption')
    2.times { button.override_color(:normal, color) }
    expect(button.label).to eq('Theme caption')
    expect(Lich).to have_received(:log).with(/control caption colors follow the WebUI theme/).once
    label = gtk::Label.new('Bounded')
    expect { label.override_color(:active, color) }.to raise_error(gtk::UnsupportedOperation)
    expect { label.override_color(:normal, 'red') }.to raise_error(gtk::UnsupportedOperation)
    [Float::NAN, Float::INFINITY, -0.1, 1.1, '1', Complex(0, 1)].each do |value|
      expect { scope.const_get(:Gdk)::RGBA.new(value, 0, 0, 1) }.to raise_error(gtk::UnsupportedOperation)
    end
    other = Struct.new(:name).new('other.lic')
    allow(Lich::Common::Script).to receive(:current).and_return(other)
    expect { label.override_color(:normal, color) }.to raise_error(gtk::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    label.destroy
    expect { label.override_color(:normal, color) }.to raise_error(gtk::UnsupportedOperation)
  end
end
