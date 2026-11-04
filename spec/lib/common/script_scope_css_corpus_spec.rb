# frozen_string_literal: true

require 'json'
require 'digest'
require_relative '../../spec_helper'
require_relative '../../../lib/common/script_scope'

RSpec.describe 'source-derived CSS decoration acceptance' do
  corpus_path = File.expand_path('../../fixtures/webui/css-decoration.json', __dir__)
  audit_path = File.expand_path('../../fixtures/webui/css-provenance.json', __dir__)
  excerpts_path = File.expand_path('../../fixtures/webui/css-decoration-excerpts.json', __dir__)
  corpus = JSON.parse(File.read(corpus_path))
  # Test-level attribution (settled B5): script, tested version or exact source
  # revision, and credited author exactly as recorded from the pinned source header.
  credit = lambda do |name|
    record = corpus.fetch('scripts').find { |r| r['name'] == name }
    by = record.fetch('attribution')
    version = by['version'] ? "version #{by['version']}" : 'no stated version'
    author = [by['author'] ? "author #{by['author']}" : 'author not stated', by['contributors'] && "contributors #{by['contributors']}"].compact.join('; ')
    "[#{name} #{version}, #{record.fetch('source')} #{record.fetch('revision')}, #{author}]"
  end
  # Credit values as recorded from each pinned source header: [author, contributors,
  # version]. Pinned here so a changed credit fails a normal spec run; the opt-in
  # rebuild below is the only other check. Update a row only with a header re-read.
  expected_credits = {
    'Combatical' => ['Kyrandos', nil, '1.3.1'], 'UberBarWiz' => ['Deathravin', nil, '2022.05'],
    'as_audit' => ['RuseofFools', nil, '1.0.2'], 'bug-catcher' => ['Timbalt', nil, '1.5'],
    'calibrate_creaturebar' => ['Elanthia Online', 'Nisugi', '1.0'], 'creaturebar' => ['Elanthia Online', 'Nisugi', '1.1'],
    'creaturewindow' => ['RuseofFools (Very Little)', nil, '1.37.0'], 'exitwindow' => ['Phocosoen', nil, '1.3'],
    'gemstone-tracker' => ['Dreaven', nil, '17'], 'gemstonev' => ['Dreaven', nil, '3'],
    'generate-gemstone' => ['Dreaven', nil, '11'], 'grids' => ['Dreaven', nil, '5'],
    'grinsawl' => ['Zedarius', nil, '0.5.19'], 'gshunting4all' => ['Falvicar', nil, '3.2.2'],
    'hazardwindow' => ['Phocosoen', nil, '1.2.0'], 'jastev' => ['Dreaven', nil, '5'],
    'manatimer' => ['Drafix', nil, '0.1'], 'manatimer-gtk3' => ['Drafix (with updates from Doug and Deysh)', nil, '0.12'],
    'merchantical' => ['Kyrandos', nil, '1.6.0'], 'mission-gemstone' => ['Dreaven', nil, '8'],
    'nautical-charts' => ['Peggyanne', nil, '1.2.4'], 'panelcontrol' => [nil, nil, '1.8.0'],
    'playerwindow' => ['Phocosoen', nil, '2.4.0'], 'rafflewindow' => ['Phocosoen', nil, nil],
    'spellson' => ['elanthia-online', 'Tillmen, Elanthia-Online', '1.0.0'], 'staminabar2' => [nil, nil, nil],
    'stormsync' => ['LostRanger', nil, '0.0.3-PREVIEW (2022-03-07)'], 'test-tpick' => ['Dreaven', nil, '13'],
    'thunder' => ['Dreaven', nil, '18'], 'timers' => ['Dreaven', nil, '5'],
    'tpick' => ['Dreaven', nil, '48'], 'tpick2' => ['Dreaven', 'Renian', '33-beta1'],
    'treasurewindow' => ['Phocosoen', nil, '1.6.1'],
  }.freeze
  # Ruby-level file routes the grids image branch could use to read its image.
  # Bounded on purpose; the shim's image-file seam is checked separately.
  file_routes = {
    File   => %i[read binread readlines foreach open new realpath exist? file? stat size],
    IO     => %i[read binread readlines foreach open sysopen],
    Dir    => %i[glob [] entries children exist?],
    Kernel => %i[open],
  }
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

  # Only the synthetic CSS-only excerpts are executable; they carry no verbatim script
  # text. Game setup, persistence, downloads and excluded Builder construction are never
  # included in this fixture.
  def run_excerpt(record, line, locals = {})
    excerpt = record.fetch('excerpts').find { |entry| entry.fetch('line') == line }
    expect(Digest::SHA256.hexdigest(excerpt.fetch('source'))).to eq(excerpt.fetch('sha256'))
    locals.each { |name, value| source_binding.local_variable_set(name, value) }
    eval(excerpt.fetch('source'), source_binding, "#{record.fetch('name')}.lic", line)
  end

  it 'retains all cached sources, the 30-script exposure subset and internally consistent sizes (per-script credits in each record attribution)' do
    audit = JSON.parse(File.read(audit_path))
    cached = audit.fetch('whole_corpus_provider_references')
    expect(corpus.fetch('audit_sha256')).to eq(Digest::SHA256.file(audit_path).hexdigest)
    expect(corpus.fetch('scripts').map { |r| [r['name'], r['source_sha256']] }).to eq(cached.map { |r| [r['name'], r['sha256']] })
    expect(corpus.fetch('scripts').count { |r| r['remaining_exposure'] }).to eq(30)
    corpus.fetch('scripts').each do |record|
      expect(record.fetch('source')).to eq(record.fetch('path').start_with?('scripts/') ? 'eo' : 'mirror')
      expect(record.fetch('revision')).to match(/\A\h{40}\z/)
      expect(record.fetch('attribution').keys).to eq(%w[author contributors version lines])
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

  it 'pins the credited author, contributors and version of every corpus script' do
    recorded = corpus.fetch('scripts').to_h do |record|
      by = record.fetch('attribution')
      [record.fetch('name'), by.values_at('author', 'contributors', 'version')]
    end
    expect(recorded.keys).to match_array(expected_credits.keys)
    expected_credits.each { |name, credits| expect(recorded.fetch(name)).to eq(credits), "credit changed for #{name}" }
  end

  it 'carries only the synthetic excerpt text, with the original range and hash kept as provenance' do
    synthetic = JSON.parse(File.read(excerpts_path)).fetch('excerpts')
    records = corpus.fetch('scripts').reject { |record| record.fetch('excerpts').empty? }
    expect(corpus.fetch('description')).to match(/synthetic.*no verbatim script text/)
    expect(records.map { |record| record.fetch('name') }).to match_array(synthetic.keys)
    expect(records.sum { |record| record.fetch('excerpts').size }).to eq(19)
    records.each do |record|
      expect(record.fetch('excerpts').map { |entry| entry.fetch('line').to_s }).to match_array(synthetic.fetch(record.fetch('name')).keys)
      record.fetch('excerpts').each do |entry|
        text = "#{synthetic.fetch(record.fetch('name')).fetch(entry.fetch('line').to_s).join("\n")}\n"
        expect(entry.keys).to eq(%w[line end_line source original_sha256 sha256])
        expect(entry.fetch('end_line')).to be >= entry.fetch('line')
        expect(entry.fetch('source')).to eq(text)
        expect(text).to be_ascii_only
        expect(entry.fetch('sha256')).to eq(Digest::SHA256.hexdigest(text))
        expect(entry.fetch('original_sha256')).to match(/\A\h{64}\z/)
        expect(entry.fetch('original_sha256')).not_to eq(entry.fetch('sha256'))
      end
    end
  end

  it 'rebuilds the committed corpus byte for byte from the pinned EO and mirror sources' do
    eo_repo = ENV.fetch('CSS_CORPUS_EO_REPO', nil)
    mirror_repo = ENV.fetch('CSS_CORPUS_MIRROR_REPO', nil)
    skip 'set CSS_CORPUS_EO_REPO and CSS_CORPUS_MIRROR_REPO to local scripts and lich_repo_mirror clones' unless eo_repo && mirror_repo
    require_relative '../../support/build_css_decoration_corpus'
    expect("#{JSON.pretty_generate(CssDecorationCorpus.build(eo_repo, mirror_repo))}\n").to eq(File.binread(corpus_path))
  end

  corpus.fetch('scripts').each do |record|
    it "accepts the measured #{record.fetch('name')} CSS inputs without changing unrelated controls #{credit.call(record.fetch('name'))}" do
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

  it 'accepts every observed priority and attachment call shape from the cached cohort (per-script credits in each record attribution)' do
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

  it "continues tpick global/local CSS, required-setting and HeaderBar construction calls #{credit.call('tpick')}" do
    record = corpus.fetch('scripts').find { |r| r['name'] == 'tpick' }
    target.instance_variable_set(:@labels, { 'field' => label })
    run_excerpt(record, 94)
    run_excerpt(record, 2557, name: 'field')
    run_excerpt(record, 2939, flagged_label: label)
    expect(label.style_context.has_class?('needs-value')).to be true
    expect(label.send(:component_props)[:content]).to eq('Retained text')
    run_excerpt(record, 2084)
    expect(source_binding.local_variable_get(:title_bar)).to be_a(gtk.const_get(:HeaderBar))
    expect(Lich).to have_received(:log).with(/operation=css_decoration source=tpick.lic:95/).once
  end

  it "executes manatimer attach-before-load and proc reloads with inert decoration #{credit.call('manatimer')}" do
    record = corpus.fetch('scripts').find { |r| r['name'] == 'manatimer' }
    bar.set_fraction(0.5)
    run_excerpt(record, 83, bar: bar, label: label)
    source_binding.local_variable_get(:calm_style).call
    source_binding.local_variable_get(:alarm_style).call
    expect(bar.send(:component_props)[:value]).to eq(0.5)
    expect(bar.send(:component_props)).not_to have_key(:fill_color)
    # Display is now supported; the geometry excerpt still owns its position input.
    allow(service).to receive(:monitor_geometry).and_return(x: 0, y: 0, width: 1280, height: 800, source: 'native', fallback: false)
    expect { run_excerpt(record, 76, pos: [20, 20]) }.not_to raise_error
  end

  %w[spellson staminabar2].each do |name|
    it "preserves recognized progress from the #{name} load/attach excerpt #{credit.call(name)}" do
      record = corpus.fetch('scripts').find { |r| r['name'] == name }
      target.instance_variable_set(:@bar, bar)
      target.instance_variable_set(:@spell_p_bar, { 1 => bar })
      target.instance_variable_set(:@circle_color, 'powderblue')
      run_excerpt(record, record.fetch('excerpts').first.fetch('line'), spell: Struct.new(:num).new(1))
      expect(bar.send(:component_props)).to include(height: 24)
      expect(bar.send(:component_props)[:fill_color]).not_to be_nil
    end
  end

  it "executes as_audit typography loading on real supported Window and TextView facades #{credit.call('as_audit')}" do
    record = corpus.fetch('scripts').find { |r| r['name'] == 'as_audit' }
    target.instance_variable_set(:@window, gtk.const_get(:Window).new)
    text = gtk.const_get(:TextView).new
    target.instance_variable_set(:@textview, text)
    before = text.send(:component_props).dup
    run_excerpt(record, 2245, theme: { bg: '#112233', fg: '#ffffff' }, prefs: { 'font_size' => 12 })
    expect(text.send(:component_props)).to eq(before)
  end

  it "executes panelcontrol palette reloads without changing controls #{credit.call('panelcontrol')}" do
    record = corpus.fetch('scripts').find { |r| r['name'] == 'panelcontrol' }
    provider = gtk.const_get(:CssProvider).new
    target.instance_variable_set(:@css_provider, provider)
    target.instance_variable_set(:@font_size, 12)
    gtk.const_get(:StyleContext).add_provider_for_screen(gdk.const_get(:Screen).default, provider)
    %w[#112233 #445566].each { |color| run_excerpt(record, 565, colors: Hash.new(color)) }
    expect(provider.state).to eq(:omitted)
    expect(Lich).to have_received(:log).with(/operation=css_decoration/).once
  end

  it "executes Combatical screen registration and drag/drop class changes as omitted metadata #{credit.call('Combatical')}" do
    record = corpus.fetch('scripts').find { |r| r['name'] == 'Combatical' }
    run_excerpt(record, 2342, s: Hash.new('#112233'))
    run_excerpt(record, 2192, target_row: label)
    expect(label.style_context.has_class?('demo-marker')).to be true
    target.instance_variable_set(:@marker_row, label)
    run_excerpt(record, 2127)
    expect(label.style_context.list_classes).to be_empty
  end

  it "executes all five grinsawl border tiers without relying on a blanket rescue #{credit.call('grinsawl')}" do
    record = corpus.fetch('scripts').find { |r| r['name'] == 'grinsawl' }
    palette = Module.new
    palette.const_set(:TIER_COLORS, { gold: '#d4af37', silver: '#c0c0c0', bronze: '#cd7f32' })
    target.const_set(:TierPalette, palette)
    run_excerpt(record, 2491)
    provider = source_binding.local_variable_get(:provider)
    expect(provider.state).to eq(:omitted)
    tiers = { 'gold' => '#d4af37', 'silver' => '#c0c0c0', 'bronze' => '#cd7f32', 'none' => '#808080', 'empty' => '#505050' }
    expected = ['.demo-slot { border-width: 3px; border-style: solid; border-radius: 4px; }'] +
               tiers.map { |tier, tint| ".demo-slot.tier-#{tier} { border-color: #{tint}; border-style: #{tier == 'empty' ? 'dashed' : 'solid'}; }" }
    expect(source_binding.local_variable_get(:sheet)).to eq(expected.join(' '))
  end

  it "executes stormsync selection CSS and omitted-priority attachments without running Builder #{credit.call('stormsync')}" do
    record = corpus.fetch('scripts').find { |r| r['name'] == 'stormsync' }
    target.instance_variable_set(:@css, {})
    controls = Hash.new { |hash, key| hash[key] = gtk.const_get(:Label).new(key) }
    target.define_singleton_method(:[]) { |key| controls[key] }
    run_excerpt(record, 3572)
    expect(target.instance_variable_get(:@css).values.map(&:state)).to eq(%i[omitted omitted unloaded])
    expect(controls.values.all? { |widget| widget.style_context.is_a?(gtk.const_get(:StyleContext)) }).to be true
  end

  it "executes timers progress CSS while preserving the control fraction #{credit.call('timers')}" do
    record = corpus.fetch('scripts').find { |r| r['name'] == 'timers' }
    bar.set_fraction(0.6)
    run_excerpt(record, 378, opts: { 'Bar Height' => 22, 'Bar Color' => '#112233', 'Trough Color' => '#445566' })
    run_excerpt(record, 392)
    run_excerpt(record, 410, ctx: bar.style_context)
    expect(bar.send(:component_props)[:value]).to eq(0.6)
    expect(bar.send(:component_props)).not_to have_key(:height)
  end

  it "executes grids image and gradient branches as inert data without file access #{credit.call('grids')}" do
    record = corpus.fetch('scripts').find { |r| r['name'] == 'grids' }
    session = gtk.session
    accessed = []
    watch = lambda do |receiver, name, tag = "#{receiver}.#{name}"|
      allow(receiver).to receive(name).and_wrap_original do |original, *args, **options, &block|
        accessed << tag if args.any? { |arg| arg.to_s.include?('missing-css-image') }
        original.call(*args, **options, &block)
      end
    end
    file_routes.each { |receiver, names| names.each { |name| watch.call(receiver, name) } }
    watch.call(target, :open, 'Kernel#open') # Called without a receiver inside the excerpt.
    # The shim's only image-file seam; any call would register a file route.
    allow(session).to receive(:image_source).and_wrap_original do |original, path|
      accessed << "Session#image_source(#{path})"
      original.call(path)
    end
    %w[Image Radial Linear].each do |kind|
      settings = Hash.new('12').merge('Widget Background' => kind, 'Image Location' => 'missing-css-image.png')
      run_excerpt(record, 1731, opts: settings, selector: 'label', widget: label)
    end
    expect(accessed).to be_empty
    expect(label.send(:component_props)[:content]).to eq('Retained text')
    expect(label.send(:component_props)).not_to have_key(:fill_color)
  end
end
