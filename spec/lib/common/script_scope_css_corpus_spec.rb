# frozen_string_literal: true

require 'json'
require 'digest'
require_relative '../../spec_helper'
require_relative '../../../lib/common/script_scope'

RSpec.describe 'source-derived CSS decoration acceptance' do
  corpus = JSON.parse(File.read(File.expand_path('../../fixtures/webui/css-decoration.json', __dir__)))
  let(:scope) { Lich::Common::ScriptScope }
  let(:gtk) { scope.const_get(:Gtk, false) }
  let(:gdk) { scope.const_get(:Gdk, false) }
  let(:owner) { Struct.new(:name).new('css-corpus.lic') }
  let(:service) { Lich::WebUI::Service.new }
  let(:bar) { gtk.const_get(:ProgressBar).new }
  let(:label) { gtk.const_get(:Label).new('Retained text') }
  let(:target) do
    Module.new.tap do |mod|
      mod.const_set(:Gtk, gtk)
      mod.const_set(:Gdk, gdk)
    end
  end
  let(:source_binding) { target.module_eval('binding', __FILE__, __LINE__) }

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
    service.stop
  end

  # Only reviewed, pinned CSS-only excerpts are executable. Game setup, persistence,
  # downloads and excluded Builder construction are never included in this fixture.
  def run_excerpt(record, line, locals = {})
    excerpt = record.fetch('excerpts').find { |entry| entry.fetch('line') == line }
    expect(Digest::SHA256.hexdigest(excerpt.fetch('source'))).to eq(excerpt.fetch('sha256'))
    locals.each { |name, value| source_binding.local_variable_set(name, value) }
    eval(excerpt.fetch('source'), source_binding, "#{record.fetch('name')}.lic", line)
  end

  it 'retains all cached sources, the 30-script exposure subset and internally consistent sizes' do
    audit = JSON.parse(File.read(File.expand_path('../../fixtures/webui/css-provenance.json', __dir__)))
    cached = audit.fetch('whole_corpus_provider_references')
    expect(corpus.fetch('scripts').map { |r| [r['name'], r['source_sha256']] }).to eq(cached.map { |r| [r['name'], r['sha256']] })
    expect(corpus.fetch('scripts').count { |r| r['remaining_exposure'] }).to eq(30)
    corpus.fetch('scripts').each do |record|
      loads = record.fetch('calls').select { |call| %w[load load_from_data].include?(call['method']) }.map { |call| call['line'] }
      expect(record.fetch('samples').map { |sample| sample['loader_line'] }.uniq.sort).to eq(loads.uniq.sort)
      record.fetch('samples').each do |sample|
        expect(sample.fetch('css').length).to eq(sample.fetch('characters'))
        expect(sample.fetch('css').bytesize).to eq(sample.fetch('bytes'))
        expect(Digest::SHA256.hexdigest(sample.fetch('css'))).to eq(sample.fetch('sha256'))
        expect(sample.fetch('characters')).to be <= corpus.fetch('bound')
      end
    end
  end

  corpus.fetch('scripts').each do |record|
    it "accepts the measured #{record.fetch('name')} CSS inputs without changing unrelated controls" do
      provider = gtk.const_get(:CssProvider).new
      handle = bar.materialize
      bar.set_fraction(0.375)
      bar.style_context.add_provider(provider)
      before = label.send(:component_props).dup
      expected = %w[spellson staminabar2].include?(record.fetch('name')) ? :recognized : :omitted
      record.fetch('samples').each do |sample|
        value = sample.fetch('css')
        result = sample.fetch('loader_method') == 'load' ? provider.load(data: value) : provider.load_from_data(value)
        expect(result).to be true
        expect(provider.state).to eq(provider.label_rules.empty? ? expected : :recognized)
        expect(bar.session.port.get(handle, :value)).to eq(0.375)
        expect(bar.materialize).to equal(handle)
        expect(label.send(:component_props)).to eq(before)
        expect(bar.session.port.get(handle, :fill_color)).to be_nil if expected == :omitted
        expect(provider.instance_variables.map { |name| provider.instance_variable_get(name) }).not_to include(value)
      end
      if expected == :omitted
        expect(Lich).to have_received(:log).with(/operation=css_decoration/).once
      else
        expect(Lich).not_to have_received(:log).with(/operation=css_decoration/)
      end
    end
  end

  it 'accepts every observed priority and attachment call shape from the cached cohort' do
    provider = gtk.const_get(:CssProvider).new
    context = label.style_context
    styles = gtk.const_get(:StyleContext)
    screen = gdk.const_get(:Screen).default
    calls = corpus.fetch('scripts').flat_map { |r| r.fetch('calls') }
    calls.select { |c| %w[add_provider add_provider_for_screen].include?(c['method']) }.each do |call|
      prefix = call['method'] == 'add_provider' ? 1 : 2
      priority = call.fetch('arguments').drop(prefix).map do |source|
        expect(source).to match(/\AGtk::StyleProvider::PRIORITY_(USER|APPLICATION)\z/)
        gtk.const_get(:StyleProvider).const_get(source.split('::').last, false)
      end
      if prefix == 1
        context.add_provider(provider, *priority)
        context.remove_provider(provider)
      else
        styles.add_provider_for_screen(screen, provider, *priority)
        styles.remove_provider_for_screen(screen, provider)
      end
    end
    expect(provider.instance_variable_get(:@contexts)).to be_empty
    expect(Lich).to have_received(:log).with(/operation=css_decoration/).once
  end

  it 'continues tpick global/local CSS, required-setting and HeaderBar construction calls' do
    record = corpus.fetch('scripts').find { |r| r['name'] == 'tpick' }
    target.instance_variable_set(:@labels, { 'field' => label })
    run_excerpt(record, 94)
    run_excerpt(record, 2557, name: 'field')
    run_excerpt(record, 2939, label: label)
    expect(label.style_context.has_class?('required-setting')).to be true
    expect(label.send(:component_props)[:content]).to eq('Retained text')
    run_excerpt(record, 2084)
    expect(source_binding.local_variable_get(:welcome_titlebar)).to be_a(gtk.const_get(:HeaderBar))
    expect(Lich).to have_received(:log).with(/operation=css_decoration source=tpick.lic:95/).once
  end

  it 'executes manatimer attach-before-load and original proc reloads with inert decoration' do
    record = corpus.fetch('scripts').find { |r| r['name'] == 'manatimer' }
    bar.set_fraction(0.5)
    run_excerpt(record, 83, bar: bar, label: label)
    source_binding.local_variable_get(:normal_bar_style).call
    source_binding.local_variable_get(:bar_style).call
    expect(bar.send(:component_props)[:value]).to eq(0.5)
    expect(bar.send(:component_props)).not_to have_key(:fill_color)
    # Display is now supported; the original geometry excerpt still owns its position input.
    allow(service).to receive(:monitor_geometry).and_return(x: 0, y: 0, width: 1280, height: 800, source: 'native', fallback: false)
    expect { run_excerpt(record, 76, window_position: [20, 20]) }.not_to raise_error
  end

  %w[spellson staminabar2].each do |name|
    it "preserves recognized progress from the original #{name} load/attach excerpt" do
      record = corpus.fetch('scripts').find { |r| r['name'] == name }
      target.instance_variable_set(:@bar, bar)
      target.instance_variable_set(:@spell_p_bar, { 1 => bar })
      target.instance_variable_set(:@circle_color, 'powderblue')
      run_excerpt(record, record.fetch('excerpts').first.fetch('line'), spell: Struct.new(:num).new(1))
      expect(bar.send(:component_props)).to include(height: 24)
      expect(bar.send(:component_props)[:fill_color]).not_to be_nil
    end
  end

  it 'executes as_audit typography loading on real supported Window and TextView facades' do
    record = corpus.fetch('scripts').find { |r| r['name'] == 'as_audit' }
    target.instance_variable_set(:@window, gtk.const_get(:Window).new)
    text = gtk.const_get(:TextView).new
    target.instance_variable_set(:@textview, text)
    before = text.send(:component_props).dup
    run_excerpt(record, 2245, palette: { bg: '#112233', fg: '#ffffff' }, aw: { 'font_size' => 12 })
    expect(text.send(:component_props)).to eq(before)
  end

  it 'executes panelcontrol palette reloads without changing controls' do
    record = corpus.fetch('scripts').find { |r| r['name'] == 'panelcontrol' }
    provider = gtk.const_get(:CssProvider).new
    target.instance_variable_set(:@css_provider, provider)
    target.instance_variable_set(:@font_size, 12)
    gtk.const_get(:StyleContext).add_provider_for_screen(gdk.const_get(:Screen).default, provider)
    %w[#112233 #445566].each { |color| run_excerpt(record, 565, colors: Hash.new(color)) }
    expect(provider.state).to eq(:omitted)
    expect(Lich).to have_received(:log).with(/operation=css_decoration/).once
  end

  it 'executes Combatical screen registration and drag/drop class changes as omitted metadata' do
    record = corpus.fetch('scripts').find { |r| r['name'] == 'Combatical' }
    run_excerpt(record, 2342, s: Hash.new('#112233'))
    run_excerpt(record, 2192, new_child: label)
    expect(label.style_context.has_class?('combatical-drop-indicator')).to be true
    target.instance_variable_set(:@drop_indicator_child, label)
    run_excerpt(record, 2127)
    expect(label.style_context.list_classes).to be_empty
  end

  it 'executes all five grinsawl border tiers without relying on its blanket rescue' do
    record = corpus.fetch('scripts').find { |r| r['name'] == 'grinsawl' }
    palette = Module.new
    palette.const_set(:FOIL_COLORS, { gold: '#d4af37', silver: '#c0c0c0', bronze: '#cd7f32' })
    target.const_set(:Grinsawl, palette)
    run_excerpt(record, 2491)
    provider = source_binding.local_variable_get(:provider)
    expect(provider.state).to eq(:omitted)
    expect(source_binding.local_variable_get(:css)).to eq(record.fetch('samples').first.fetch('css'))
  end

  it 'executes stormsync selection CSS and omitted-priority attachments without running Builder' do
    record = corpus.fetch('scripts').find { |r| r['name'] == 'stormsync' }
    target.instance_variable_set(:@css, {})
    controls = Hash.new { |hash, key| hash[key] = gtk.const_get(:Label).new(key) }
    target.define_singleton_method(:[]) { |key| controls[key] }
    run_excerpt(record, 3572)
    expect(target.instance_variable_get(:@css).values.map(&:state)).to eq(%i[omitted omitted unloaded])
    expect(controls.values.all? { |widget| widget.style_context.is_a?(gtk.const_get(:StyleContext)) }).to be true
  end

  it 'executes timers progress CSS while preserving the control fraction' do
    record = corpus.fetch('scripts').find { |r| r['name'] == 'timers' }
    bar.set_fraction(0.6)
    run_excerpt(record, 378, settings: { 'Bar Height' => 22, 'Bar Color' => '#112233', 'Trough Color' => '#445566' })
    run_excerpt(record, 392)
    run_excerpt(record, 410, context: bar.style_context)
    expect(bar.send(:component_props)[:value]).to eq(0.6)
    expect(bar.send(:component_props)).not_to have_key(:height)
  end

  it 'executes grids image and gradient branches as inert data without file access' do
    record = corpus.fetch('scripts').find { |r| r['name'] == 'grids' }
    %w[Image Radial Linear].each do |kind|
      settings = Hash.new('12').merge('Widget Background' => kind, 'Image Location' => 'missing-css-image.png')
      expect(File).not_to receive(:read).with(/missing-css-image/)
      run_excerpt(record, 1731, needed_settings: settings, css_name: 'label', widget: label)
    end
    expect(label.send(:component_props)[:content]).to eq('Retained text')
    expect(label.send(:component_props)).not_to have_key(:fill_color)
  end
end
