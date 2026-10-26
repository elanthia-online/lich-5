# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/script_scope'
require_relative '../../support/webui_browser'
require_relative '../../support/webui_builder_source_repairs'
require 'timeout'
require 'digest'

RSpec.describe 'bounded Gtk Builder compatibility' do
  let(:scope) { Lich::Common::ScriptScope }
  let(:owner) { Struct.new(:name).new('builder.lic') }
  let(:service) { Lich::WebUI::Service.new }
  let(:gtk) { scope.const_get(:Gtk, false) }
  let(:builder) { gtk::Builder.new }

  around do |example|
    Dir.mktmpdir('builder-settings-') do |directory|
      @settings_directory = directory
      example.run
    end
  end

  # Original list callbacks rely on Lich's real nil extension (uniq!.sort!).
  # Exercise that production environment without contaminating the parent suite
  # or replacing source callbacks. Each browser case still runs independently.
  def production_nil_example(example)
    return false if ENV['WEBUI_PRODUCTION_NIL'] == '1'

    extension = File.expand_path('../../../lib/common/class_exts/nilclass.rb', __dir__)
    output, status = Open3.capture2e(
      { 'WEBUI_PRODUCTION_NIL' => '1' }, RbConfig.ruby, '-S', 'rspec', '--require', extension, example.id
    )
    expect(status.success?).to be(true), output
    expect(output).to match(/1 example, 0 failures(?:\n|\r)/), output
    true
  end

  before do
    scope.activate!
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    allow(Lich::WebUI).to receive(:adapter) { |owner:, viewer: nil| Lich::WebUI::Adapter.new(owner: owner, service: service, viewer: viewer) }
    allow(Lich::WebUI).to receive(:callback_queue) { |owner:| proc { |&work| service.runtime.dispatch(owner: owner, &work) } }
    # Kept quiet unless the example fails: runtime refusals and callback errors
    # are the only evidence of a lost browser event (see the after hook).
    @lich_log = []
    allow(Lich).to receive(:log) { |message| @lich_log << message }
  end

  after do |example|
    if example.exception
      warn "Lich.log during #{example.full_description}:\n  #{@lich_log.last(50).join("\n  ")}" if @lich_log.any?
      warn "Script messages:\n  #{@messages.last(20).join("\n  ")}" if @messages&.any?
    end
    Lich::Common::ScriptDeath.run(owner)
    service.stop
  end

  def load_xml(body)
    builder.add_from_string("<interface>#{body}</interface>")
  end

  # Run the original setup module with inert game lookups and an isolated save path.
  # Its XML, load_settings, change, Close and destroy handlers are not rewritten.
  def original_ecleanse(settings = {})
    sandbox = Module.new
    sandbox.const_set(:Gtk, gtk)
    sandbox.const_set(:Util, double(get_script_version: 'fixture'))
    spells = Object.new
    spells.define_singleton_method(:[]) { |key| Struct.new(:known?).new(key != 113) }
    sandbox.const_set(:Spell, spells)
    sandbox.const_set(:CMan, double(known?: true, stun_maneuvers: 5))
    sandbox.const_set(:Feat, double(known?: true))
    sandbox.const_set(:DATA_DIR, @settings_directory)
    sandbox.const_set(:XMLData, double(game: 'GS'))
    sandbox.const_set(:Char, double(name: 'Fixture'))
    FileUtils.mkdir_p(File.join(@settings_directory, 'GS', 'Fixture'))
    @messages = []
    messages = @messages
    messaging = Module.new
    messaging.define_singleton_method(:msg) { |_type, message| messages << message }
    stub_const('Lich::Messaging', messaging)
    path = File.expand_path('../../fixtures/webui/ecleanse_setup.lic', __dir__)
    sandbox.module_eval(File.read(path), path)
    mod = sandbox.const_get(:Ecleanse)
    mod.define_singleton_method(:data) { Struct.new(:settings).new(settings) }
    klass = mod.const_get(:Setup)
    klass.define_method(:respond) { |*_args| nil }
    instance = klass.new(settings)
    drain_gtk
    expect(instance.objects.length).to eq(54)
    instance
  end

  # Two FIFO barriers include work enqueued by the initial queue block itself.
  def drain_gtk
    2.times do
      completed = Queue.new
      service.runtime.dispatch(owner: owner) { completed << true }
      completed.pop(timeout: 2)
    end
  end

  def saved_settings_path = File.join(@settings_directory, 'GS', 'Fixture', 'ecleanse.yaml')

  # The original setup class runs unchanged. Game catalogs and persistence are
  # isolated here; no callback or widget logic is replaced to make a test pass.
  def original_e_setup(name, settings = {}, source_failure: false, corrected: false, refreshed: false)
    sandbox = Module.new
    sandbox.const_set(:Gtk, gtk)
    sandbox.const_set(:XMLData, double(game: 'GS'))
    sandbox.const_set(:Char, double(name: 'Fixture', prof: 'Ranger'))
    sandbox.const_set(:Stats, double(prof: 'Ranger'))
    sandbox.const_set(:Skills, double(slblessings: 20))
    sandbox.const_set(:Society, double(status: 'Council of Light', rank: 20))
    spells = Object.new
    spells.define_singleton_method(:[]) { |id| Struct.new(:known?, :num, :name).new(false, id.to_i, "Fixture spell #{id}") }
    sandbox.const_set(:Spell, spells)
    town = "the town of Wehnimer's Landing"
    sandbox.const_set(:Map, double(list: [double(tags: ['publiclockers', 'ranger alchemy administrator'], location: town, find_nearest_by_tag: 1)]))
    sandbox.const_set(:Room, double(:rooms, :[] => double(location: town)))
    sandbox.const_set(:UserVars, double(mapdb_fwi_trinket: false))
    path = File.expand_path("../../fixtures/webui/#{name}_setup.lic", __dir__)
    source = File.read(path)
    if name == 'eloot'
      expect(Digest::SHA256.hexdigest(source)).to eq('629e8f9f1b845f5348068a5ba75c42bd74006d5c59e45bf218c6cc2d5d4a00e0')
    end
    if refreshed
      entry = JSON.parse(File.read(File.expand_path('../../fixtures/webui/source-refresh.json', __dir__)))['scripts'].fetch(name)['blocks'].fetch('setup')
      expect(Digest::SHA256.hexdigest(entry.fetch('source'))).to eq(entry.fetch('sha256'))
      source = "module ELoot\nif defined?(Gtk)\n#{entry.fetch('source')}\nend\nend\n"
    end
    source = WebUIBuilderSourceRepairs.apply(name, source) if corrected
    sandbox.module_eval(source, path)
    mod = sandbox.const_get({ 'eloot' => :ELoot, 'ebounty' => :EBounty, 'eherbs' => :EHerbs, 'blackarts' => :BlackArts }.fetch(name))
    if name == 'eloot'
      @tip_requests, @setup_messages = [], []
      requests = @tip_requests
      mod.const_set(:Sell, Module.new).define_singleton_method(:locksmith_tip) do |*args|
        requests << args
        200
      end
      table = Class.new do
        attr_reader :title, :rows

        def initialize(title:, rows:)
          @title, @rows = title, rows
        end

        def align_column(*); end
      end
      sandbox.const_set(:Terminal, Module.new).const_set(:Table, table)
    end
    mod.define_singleton_method(:get_script_version) { 'fixture' }
    mod.define_singleton_method(:data) { Struct.new(:settings).new(settings) }
    destination = File.join(@settings_directory, "#{name}.yaml")
    mod.define_singleton_method(:save_profile) { |values = settings| File.write(destination, YAML.dump(values)) }
    # eherbs commits into script data; the outer game command owns disk saving.
    @eherbs_loaded = []
    loaded = @eherbs_loaded
    mod.define_singleton_method(:load) { |values| loaded << values.dup }
    klass = mod.const_get(:Setup)
    messages = @setup_messages
    klass.define_method(:respond) { |*args| messages&.concat(args) }
    klass.define_method(:wait_while) { |&block| sleep 0.005 while block.call }
    # Profile discovery is a game-data lookup; avoid touching real character data.
    allow(Dir).to receive(:children).and_call_original
    allow(Dir).to receive(:children).with(/bigshot_profiles\z/).and_return(%w[fixture.yaml travel.yaml])
    allow(Dir).to receive(:foreach).and_call_original
    allow(Dir).to receive(:foreach).with(/bigshot_profiles\z/).and_yield('fixture.yaml').and_yield('travel.yaml')
    @setup_diagnostics = []
    allow(Lich).to receive(:log) { |message| @setup_diagnostics << message }
    form = klass.new(settings)
    2.times { drain_gtk }
    failures = @setup_diagnostics.grep(/callback failed/)
    if source_failure
      expect(failures.length).to eq(1), @setup_diagnostics.join("\n")
      expect(failures.first).to include('BuilderError', 'object=exclusions_label', 'property=get_object', 'undeclared object identifier')
    else
      expect(failures).to eq([]), @setup_diagnostics.join("\n")
    end
    expect(form.objects.length).to eq({ 'eloot' => refreshed ? 471 : 469, 'ebounty' => 435, 'eherbs' => 31, 'blackarts' => 216 }.fetch(name))
    form
  end

  %w[ebounty eherbs blackarts].each do |name|
    it "loads and publishes the unchanged #{name} setup with original callbacks" do |example|
      next if name != 'eherbs' && production_nil_example(example)

      settings = {}
      form = original_e_setup(name, settings)
      if name == 'eherbs'
        form['herb_container'].text = 'herb sack'
        form.on_update(form['herb_container'])
        drain_gtk
        expect(settings[:herb_container]).to eq('herb sack')
      elsif name == 'blackarts'
        form['guild_pause'].text = '25'
        form.on_update(form['guild_pause'])
        drain_gtk
        expect(settings[:guild_pause]).to eq('25')
      else
        key = 'culling_max'
        form[key].value = 25
        drain_gtk
        expect(settings[key.to_sym].to_f).to eq(25)
      end
      form['main'].show_all
      page = nil
      Timeout.timeout(3) { sleep 0.005 until (page = service.registry.pages_for(owner).first)&.last_render }
      expect(page.last_render.tree.each.count).to be > 10
      form.on_close_clicked
      drain_gtk
      expect(form['main']).to be_destroyed
      expect(@setup_diagnostics.grep(/callback failed/)).to eq([]), @setup_diagnostics.join("\n")
      if name == 'eherbs'
        expect(@eherbs_loaded.last).to include(herb_container: 'herb sack')
      else
        expect(YAML.unsafe_load_file(File.join(@settings_directory, "#{name}.yaml"))).to eq(settings)
      end
    end
  end

  it 'retains the refreshed eloot original missing-label failure' do |example|
    next if production_nil_example(example)

    allow(owner).to receive(:kill)
    form = original_e_setup('eloot', {}, source_failure: true, refreshed: true)
    expect(form['main']).to be_destroyed
    expect(owner).to have_received(:kill).with(async: true)
  end

  it 'loads and saves all seven refreshed eloot stance choices in the repaired candidate' do |example|
    next if production_nil_example(example)

    settings = { loot_stance: 'guarded' }
    form = original_e_setup('eloot', settings, corrected: true, refreshed: true)
    combo = form['loot_stance']
    expect(combo.active_id).to eq('guarded')
    choices = %w[none offensive advance forward neutral guarded defensive]
    expect(combo.model.rows.length).to eq(choices.length)
    choices.each do |choice|
      combo.active_id = choice
      drain_gtk
      expect(settings[:loot_stance]).to eq(choice)
    end
    form.on_close_clicked
    drain_gtk
    expect(YAML.unsafe_load_file(File.join(@settings_directory, 'eloot.yaml'))[:loot_stance]).to eq('defensive')
  end

  it 'validates the refreshed eloot stance selector and save in the browser', browser: true do |example|
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    next if production_nil_example(example)

    settings = {}
    form = original_e_setup('eloot', settings, corrected: true, refreshed: true)
    form['main'].show_all
    drain_gtk
    page = nil
    Timeout.timeout(3) { sleep 0.005 until (page = service.registry.pages_for(owner).first)&.last_render }
    handle = form['loot_stance'].instance_variable_get(:@handle)
    cid = form['loot_stance'].session.port.send(:node!, handle).cid
    WebUIBrowser.check(service: service, page: page, scenario: 'shim-eloot-stance', controls: { stance: cid })
    drain_gtk
    expect(@setup_diagnostics.grep(/callback failed/)).to be_empty
    expect(YAML.unsafe_load_file(File.join(@settings_directory, 'eloot.yaml'))[:loot_stance]).to eq('defensive')
    expect(form['main']).to be_destroyed
  end

  it 'loads the explicitly corrected eloot candidate and preserves its Close/save callback' do |example|
    next if production_nil_example(example)

    settings = {}
    form = original_e_setup('eloot', settings, corrected: true)
    expect(form['exclusions_label'].send(:component_props)[:tooltip]).to include('aquamarine')
    form['main'].show_all
    drain_gtk
    form.on_close_clicked
    drain_gtk
    expect(form['main']).to be_destroyed
    expect(@setup_diagnostics.grep(/callback failed/)).to be_empty, @setup_diagnostics.join("\n")
    expect(YAML.unsafe_load_file(File.join(@settings_directory, 'eloot.yaml'))).to eq(settings)
  end

  it 'exercises every corrected eloot list add/delete handler and retains the empty lists on save' do |example|
    next if production_nil_example(example)

    settings = {}
    form = original_e_setup('eloot', settings, corrected: true)
    lists = form.objects.select { |widget| widget.instance_of?(gtk::TreeView) }
    expect(lists.length).to eq(12)
    lists.each do |list|
      key = list.builder_name
      value = key == 'sell_keep_scrolls' ? '215' : "fixture #{key}"
      previous = settings.fetch(key.to_sym).dup
      form["#{key}_entry"].text = value
      form["#{key}_add"].send(:emit_handlers, :activate)
      drain_gtk
      expect(settings.fetch(key.to_sym)).to include(value), key
      iter = list.model.rows.find { |row| row[0].to_s == value }
      expect(iter).not_to be_nil, key
      list.selection.select_iter(iter)
      form["#{key}_delete"].send(:emit_handlers, :activate)
      drain_gtk
      expect(settings.fetch(key.to_sym)).to match_array(previous), key
    end
    expect(@setup_diagnostics.grep(/callback failed/)).to be_empty, @setup_diagnostics.join("\n")
    form.on_close_clicked
    drain_gtk
    expect(YAML.unsafe_load_file(File.join(@settings_directory, 'eloot.yaml'))).to eq(settings)
  end

  it 'updates every corrected eloot scalar entry and spin setting through its connected handler' do |example|
    next if production_nil_example(example)

    settings = {}
    form = original_e_setup('eloot', settings, corrected: true)
    entries = form.objects.select { |widget| widget.instance_of?(gtk::Entry) && form.class.get_setting(widget.builder_name.to_sym) }
    expect(entries.length).to be > 10
    entries.each do |entry|
      entry.text = "fixture #{entry.builder_name}"
      drain_gtk
      expect(settings.fetch(entry.builder_name.to_sym)).to eq(entry.text)
    end
    spins = form.objects.select { |widget| widget.instance_of?(gtk::SpinButton) && form.class.get_setting(widget.builder_name.to_sym) }
    expect(spins).not_to be_empty
    spins.each do |spin|
      spin.value = (spin.adjustment.lower + spin.adjustment.upper) / 2.0
      drain_gtk
      expect(settings.fetch(spin.builder_name.to_sym).to_f).to eq(spin.text.to_f)
    end
    expect(@setup_diagnostics.grep(/callback failed/)).to be_empty, @setup_diagnostics.join("\n")
    form['main'].destroy
    drain_gtk
    expect(File).not_to exist(File.join(@settings_directory, 'eloot.yaml'))
  end

  it 'dispatches the corrected eloot tipping preview with the current settings' do |example|
    next if production_nil_example(example)

    settings = {}
    form = original_e_setup('eloot', settings, corrected: true)
    form['alpha_rate'].value = 3.5
    drain_gtk
    form['tipping_test'].send(:emit_handlers, :activate)
    expect(@tip_requests.length).to eq(22)
    expect(@tip_requests.map { |args| args.drop(1) }.uniq).to eq([[settings[:base_tip], settings[:max_tip], '3.5']])
    expect(@setup_messages.last.title).to eq('Incremental Tipping (alpha: 3.5)')
    expect(@setup_messages.last.rows.length).to eq(15)
    form['main'].destroy
    drain_gtk
    expect(File).not_to exist(File.join(@settings_directory, 'eloot.yaml'))
  end

  it 'runs the corrected eloot candidate through Chrome settings, lists, dependencies and saving', browser: true do |example|
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    next if production_nil_example(example)

    settings = {}
    form = original_e_setup('eloot', settings, corrected: true)
    form['main'].show_all
    page = nil
    Timeout.timeout(3) { sleep 0.005 until (page = service.registry.pages_for(owner).first)&.last_render }
    controls = form.objects.filter_map do |widget|
      handle = widget.instance_variable_get(:@handle)
      next unless handle && widget.respond_to?(:builder_name)
      [widget.builder_name, widget.session.port.send(:node!, handle).cid]
    end.to_h
    WebUIBrowser.check(service: service, page: page, scenario: 'shim-eloot-corrected', controls: controls)
    drain_gtk
    expect(@setup_diagnostics.grep(/callback failed/)).to be_empty, @setup_diagnostics.join("\n")
    expect(settings).to include(sell_locksmith: true, locksmith_priority: 'locksmith', use_incremental_tipping: true, use_standard_tipping: false,
                                alpha_rate: 3.5, skin_enable: true, gem_horde: true, gem_horde_che_rooms: '1234')
    expect(settings[:loot_types]).to include('alchemy')
    expect(settings[:gem_list]).to include('ruby')
    expect(YAML.unsafe_load_file(File.join(@settings_directory, 'eloot.yaml'))).to eq(settings)
    expect(form['main']).to be_destroyed
  end

  it 'refuses the original eloot missing tooltip target with a conversion diagnostic' do |example|
    next if production_nil_example(example)

    allow(owner).to receive(:kill)
    form = original_e_setup('eloot', {}, source_failure: true)
    expect { form['exclusions_label'] }.to raise_error(gtk::BuilderError, /object=exclusions_label.*native WebUI/)
    expect(form['main']).to be_destroyed
    expect(service.registry.pages_for(owner)).to be_empty
    expect(owner).to have_received(:kill).with(async: true)
    expect(gtk.queue { raise 'late work must not run' }).to be_nil
  end

  %w[ebounty eherbs blackarts].each do |name|
    it "validates #{name} original interactions and layout in Chrome", browser: true do |example|
      skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
      next if name != 'eherbs' && production_nil_example(example)

      settings = {}
      form = original_e_setup(name, settings)
      form['main'].show_all
      page = nil
      Timeout.timeout(3) { sleep 0.005 until (page = service.registry.pages_for(owner).first)&.last_render }
      # Private handles are inspected only by this test harness, avoiding any
      # production script-name IDs or changes to original setup declarations.
      controls = form.objects.filter_map do |widget|
        handle = widget.instance_variable_get(:@handle)
        next unless handle && widget.respond_to?(:builder_name)
        [widget.builder_name, widget.session.port.send(:node!, handle).cid]
      end.to_h
      WebUIBrowser.check(service: service, page: page, scenario: "shim-#{name}", controls: controls)
      drain_gtk
      expect(form['main']).to be_destroyed
      expect(@setup_diagnostics.grep(/callback failed/)).to eq([]), @setup_diagnostics.join("\n")
      if name == 'ebounty'
        expect(settings).to include(culling_max: 25, selling_script: 'fixture-sell', once_and_done: false, new_bounty_on_exit: false)
        expect(settings[:creature_exclude]).to eq([])
        expect(YAML.unsafe_load_file(File.join(@settings_directory, "#{name}.yaml"))).to eq(settings)
      elsif name == 'eherbs'
        expect(@eherbs_loaded.last).to include(herb_container: 'herb sack', buy_missing: true)
      else
        expect(settings).to include(guild_pause: '25', profile_a: 'travel', home_guild: "Wehnimer's Landing")
        expect(settings[:item_include]).to eq(form.instance_variable_get(:@default_buy))
        expect(settings[:consignment_include]).to eq(form.instance_variable_get(:@default_sell))
        expect(YAML.unsafe_load_file(File.join(@settings_directory, "#{name}.yaml"))).to eq(settings)
      end
    end
  end

  # Preserve the original setup and its handlers; only game services and the save
  # destination are substituted. This is not an execution of the casting loop.
  def original_ewaggle
    sandbox = Module.new
    sandbox.const_set(:Gtk, gtk)
    sandbox.const_set(:Gdk, scope.const_get(:Gdk))
    sandbox.const_set(:Script, Lich::Common::Script)
    spells = [Struct.new(:num, :name, :time_per).new(101, 'Spirit Warding I', 1), Struct.new(:num, :name, :time_per).new(102, 'Spirit Barrier', 1)]
    spells.each { |spell| spell.define_singleton_method(:known?) { true } }
    catalog = Object.new
    catalog.define_singleton_method(:list) { spells }
    catalog.define_singleton_method(:[]) { |number| spells.find { |spell| spell.num == number } || Struct.new(:known?).new(number != 511) }
    sandbox.const_set(:Spell, catalog)
    sandbox.const_set(:Armor, double(known?: false))
    sandbox.const_set(:Society, double(member: 'Council of Light', rank: 20))
    @messages = []
    messages = @messages
    messaging = Module.new
    messaging.define_singleton_method(:msg) { |_type, message| messages << message }
    stub_const('Lich::Messaging', messaging)
    path = File.expand_path('../../fixtures/webui/ewaggle_setup.lic', __dir__)
    sandbox.module_eval(File.read(path), path)
    mod = sandbox.const_get(:Ewaggle)
    @ewaggle_settings = { cast_list: ['101  Spirit Warding I'], sonic_armor: 'Robes' }
    settings, destination = @ewaggle_settings, File.join(@settings_directory, 'ewaggle.yaml')
    mod.define_singleton_method(:get_script_version) { 'fixture' }
    mod.define_singleton_method(:armor_spells) { {} }
    mod.define_singleton_method(:data) { Struct.new(:settings).new(settings) }
    mod.define_singleton_method(:save_profile) { File.write(destination, YAML.dump(settings)) }
    klass = mod.const_get(:Setup)
    klass.define_method(:respond) { |*_args| nil }
    klass.define_method(:wait_while) { |&block| sleep 0.005 while block.call }
    form = klass.new(settings)
    drain_gtk
    expect(form['main']).to be_a(gtk::Window)
    expect(form['cast_list_store'].size).to eq(1)
    form
  end

  it 'loads the original ewaggle setup, named choices and numeric callbacks without source edits' do
    form = original_ewaggle
    expect(Digest::SHA256.hexdigest(form.class.ewaggle_ui)).to eq('c617157ee342adb4bfcb9d3281de5d63c17ef777d4f75fcad60544ec6049eddf')
    expect(form['sonic_armor'].active_id).to eq('Robes')
    expect(form['sonic_armor'].set_active_id('Full Plate')).to be(true)
    expect(@ewaggle_settings[:sonic_armor]).to eq('Full Plate')
    expect(form['sonic_armor'].set_active_id('missing')).to be(false)
    expect(form['sonic_armor'].active_id).to eq('Full Plate')
    form['start_at'].value = 90
    expect(@ewaggle_settings[:start_at]).to eq(90)
    form['sonic_armor'].remove_all
    expect(form['sonic_armor'].active_id).to be_nil
    form['main'].destroy
    drain_gtk
    expect(File.exist?(File.join(@settings_directory, 'ewaggle.yaml'))).to be(false)
    expect(@messages.join).to include('WITHOUT saving')
  end

  it 'routes validated row drops through the original ewaggle callbacks without automatic model edits' do
    diagnostics = []
    allow(Lich).to receive(:log) { |message| diagnostics << message }
    form = original_ewaggle
    allow(gtk.session).to receive(:refuse).and_wrap_original do |method, receiver, operation|
      diagnostics << "#{receiver.class}: #{operation}"
      method.call(receiver, operation)
    end
    form['main'].show_all
    page = nil
    Timeout.timeout(3) { sleep 0.005 until (page = service.registry.pages_for(owner).first)&.last_render }
    sent = []
    connection = double('connection', viewer_id: 'ewaggle-drop', alive?: true)
    allow(connection).to receive(:send_text) { |message| sent << JSON.parse(message) }
    address = service.registry.address_for(page)
    service.runtime.handle(connection, type: 'attach', page: address)
    tables = page.last_render.tree.each.select { |component| component.type == :table }
    source = tables.find { |table| table.props[:rows].any? { |row| row[:cells].values.include?('102  Spirit Barrier') } }
    target = tables.find { |table| table != source }
    service.runtime.handle(connection, type: 'event', page: address, generation: page.generation,
                                       cid: target.cid, event: 'row_drop', payload: { source: source.cid, row: source.props[:rows].first[:key] })
    drain_gtk
    expect(form['cast_list_store'].rows.map { |row| row[0] }).to contain_exactly('101  Spirit Warding I', '102  Spirit Barrier'), diagnostics.join("\n")
    expect(form['not_to_cast_store'].size).to eq(0)
    expect(sent.select { |message| message['type'] == 'error' }).to be_empty
  end

  it 'refuses unsafe label markup and unimplemented transfer protocols without publishing a partial form' do
    [
      '<a href="javascript:alert(1)">bad</a>',
      '<a href="https://user:pass@example.org/">bad</a>',
      '<a href="https://example.org/" onclick="bad()">bad</a>',
      '<a href="https://example.org/"><b>nested</b></a>',
    ].each do |text|
      expect do
        load_xml("<object class=\"GtkLabel\"><property name=\"label\">#{CGI.escapeHTML(text)}</property><property name=\"use-markup\">True</property></object>")
      end.to raise_error(gtk::BuilderError)
      expect(builder.objects).to be_empty
    end
    expect { gtk::TargetEntry.new('text/uri-list', gtk::TargetFlags::SAME_APP, 0) }.to raise_error(gtk::UnsupportedOperation)
    expect { gtk::DragContext.new.finish(success: true, delete: true, time: 0) }.to raise_error(gtk::UnsupportedOperation)
    combo = gtk::ComboBoxText.new
    combo.append('one', 'Duplicate label')
    combo.append('two', 'Duplicate label')
    expect { combo.append('one', 'new') }.to raise_error(gtk::UnsupportedOperation)
    expect(combo.model.size).to eq(2)
    combo.set_active_id('two')
    expect(combo.active).to eq(1)
    spin = gtk::SpinButton.new(0, 100, 1)
    spin.text = '0'
    spin.text = '10'
    expect(spin.value).to eq(10)
    expect { spin.text = 'not a number' }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'saves original ewaggle settings when Close overtakes its input change events' do
    form = original_ewaggle
    form['main'].show_all
    page = nil
    Timeout.timeout(3) { sleep 0.005 until (page = service.registry.pages_for(owner).first)&.last_render }
    connection = double('connection', viewer_id: 'ewaggle-close', alive?: true, send_text: true)
    address = service.registry.address_for(page)
    service.runtime.handle(connection, type: 'attach', page: address)
    render = page.last_render
    components = render.tree.each.to_h { |component| [component.cid, component] }
    close = components.values.find { |component| component.type == :button && component.props[:label] == 'Close' }
    combo_cid = form['sonic_armor'].session.port.send(:node!, form['sonic_armor'].instance_variable_get(:@handle)).cid
    spin_cid = form['start_at'].session.port.send(:node!, form['start_at'].instance_variable_get(:@handle)).cid
    values = render.submissions.fetch(close.cid).map do |cid|
      component = components.fetch(cid)
      case cid
      when combo_cid then component.props[:options].find { |option| option[:label] == 'Full Plate (20)' }.fetch(:value)
      when spin_cid then 90
      else component.props.fetch(%i[checkbox toggle radio_option].include?(component.type) ? :checked : :value)
      end
    end
    service.runtime.handle(connection, type: 'event', page: address, generation: render.generation,
                                       cid: close.cid, event: 'activate', payload: {}, submission: values)
    drain_gtk
    expect(form['main']).to be_destroyed
    expect(YAML.unsafe_load_file(File.join(@settings_directory, 'ewaggle.yaml'))).to include(sonic_armor: 'Full Plate', start_at: 90)
  end

  # Emits a finite render batch after the browser starts its third native drag.
  # The browser's bounded run owns the wait lifetime; its ensure kills and joins
  # this worker, so browser startup cannot exhaust a separate fixture deadline.
  # @param form [Object] original EWaggle form with its unchanged callbacks
  # @param signal [String] temporary file written by the browser test after dragstart
  # @return [Thread] worker whose exceptions propagate when joined
  def ewaggle_drag_renders(form, signal)
    Thread.new do
      Thread.current.report_on_exception = false
      sleep 0.005 until File.exist?(signal)
      100.times do |index|
        title = index == 99 ? 'EWaggle drag fixture complete' : "EWaggle drag fixture #{index}"
        gtk.queue { form['main'].title = title unless form['main'].destroyed? }
        sleep 0.01
      end
    end
  end

  it 'preserves ewaggle search, transfers, choice edits and original save callbacks in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    form = original_ewaggle
    runner = Thread.new { form.start }
    page = nil
    Timeout.timeout(3) { sleep 0.005 until (page = service.registry.pages_for(owner).first)&.last_render }
    Dir.mktmpdir('ewaggle-drag-') do |directory|
      signal = File.join(directory, 'drag-ready')
      churn = ewaggle_drag_renders(form, signal)
      begin
        WebUIBrowser.check(service: service, page: page, scenario: 'shim-ewaggle', controls: { drag_ready: signal })
      ensure
        browser_error = $!
        churn.kill
        begin
          churn.join
        rescue StandardError => error
          raise unless browser_error

          warn "EWaggle render fixture also failed: #{error.class}: #{error.message}"
        end
      end
    end
    drain_gtk
    runner.join(2)
    saved = YAML.unsafe_load_file(File.join(@settings_directory, 'ewaggle.yaml'))
    expect(saved).to include(sonic_armor: 'Full Plate', start_at: 90)
    expect(saved[:cast_list]).to contain_exactly('101  Spirit Warding I', '102  Spirit Barrier', '102  Spirit Barrier')
    expect(saved[:not_to_cast]).to be_empty
    expect(form['main']).to be_destroyed
  ensure
    form&.[]('main')&.destroy
    runner&.join(2)
  end

  it 'loads unchanged ecleanse XML and preserves original initialization, changes and Close saving' do
    settings = { stop_scripts: 'bigshot', cleanse_disease: true, cleanse_poison: false }
    form = original_ecleanse(settings)
    expect(Digest::SHA256.hexdigest(form.class.ui)).to eq('1dec1310d30d6b3f1e34beb7a39aeccdffdd6da70e87c476818759405be13eea')
    expect(form['stop_scripts'].text).to eq('bigshot')
    expect(form['stop_scripts'].send(:component_props)).to include(min_width_chars: 59)
    expect(form['cleanse_disease'].send(:component_props)).to include(disabled: true, checked: false)
    expect(settings[:cleanse_disease]).to be(false)
    gtk.queue do
      form['cleanse_poison'].active = true
      form['use_stance1'].active = true
    end
    drain_gtk
    gtk.queue { form['use_flee'].active = true }
    drain_gtk
    expect(settings).to include(cleanse_poison: true, use_flee: true, use_stance1: false)
    expect(form['use_stance1'].active?).to be(false)
    expect(File.exist?(saved_settings_path)).to be(false)
    close = form.objects.find { |object| object.instance_of?(gtk::Button) && object.label == 'Close' }
    gtk.queue { close.send(:emit_handlers, :activate) }
    drain_gtk
    expect(YAML.unsafe_load_file(saved_settings_path)).to include(cleanse_poison: true, use_flee: true)
    expect(form['main']).to be_destroyed
    expect(@messages.grep(/WITHOUT saving/)).to be_empty
    expect(Lich).to have_received(:log).with(/shadow-type=in accepted; inset decoration omitted/).once
  end

  %i[detach process_exit].each do |close_path|
    it "runs the original destroy callback without saving changed settings on #{close_path}" do
      settings = {}
      form = original_ecleanse(settings)
      form['main'].show_all
      page = nil
      Timeout.timeout(2) { sleep 0.001 until (page = service.registry.pages_for(owner).first)&.last_render }
      connection = double('connection', viewer_id: 'ecleanse-close', alive?: true, send_text: true)
      address = service.registry.address_for(page)
      service.runtime.handle(connection, type: 'attach', page: address)
      check = page.last_render.tree.each.find { |component| component.props[:label] == 'Cure Poison' }
      service.runtime.handle(connection, type: 'event', page: address, generation: page.generation,
                                         cid: check.cid, event: 'change', payload: { value: true })
      drain_gtk
      if close_path == :detach
        service.runtime.handle(connection, type: 'detach', page: address, generation: page.generation)
      else
        service.runtime.disconnect(connection)
        service.runtime.browser_closed(page)
      end
      drain_gtk
      expect(settings[:cleanse_poison]).to be(true)
      expect(File.exist?(saved_settings_path)).to be(false)
      expect(@messages.join).to include('WITHOUT saving')
      expect(form['main']).to be_destroyed
      expect(form.instance_variable_get(:@running)).to be(false)
    end
  end

  it 'keeps widget names separate from Builder IDs and enforces the Entry character limit' do
    load_xml('<object class="GtkEntry" id="entry"><property name="name">label</property><property name="text">abc</property><property name="max-length">1</property></object><object class="GtkLabel" id="label"/>')
    expect(builder['entry'].name).to eq('label')
    expect(builder['entry'].builder_name).to eq('entry')
    expect(builder['entry'].text).to eq('a')
    builder['entry'].text = 'xy'
    expect(builder['entry'].text).to eq('x')
    expect(builder['label']).not_to equal(builder['entry'])
    expect { builder['entry'].max_length = -1 }.to raise_error(gtk::UnsupportedOperation)
    expect { builder['entry'].max_length = 8193 }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'refuses internal combo entry character limits without retaining a partial Builder load' do
    expect do
      load_xml(<<~XML)
        <object class="GtkComboBoxText" id="combo">
          <property name="has-entry">True</property>
          <child internal-child="entry"><object class="GtkEntry" id="entry">
            <property name="text">Existing text</property>
            <property name="max-length">3</property>
          </object></child>
        </object>
      XML
    end.to raise_error(gtk::BuilderError, /max_length=/)
    expect(builder.objects).to be_empty
  end

  it 'retains keyboard focus and server-owned values in read-only entries in either property order' do
    [['can-focus', 'editable'], ['editable', 'can-focus']].each do |order|
      candidate = gtk::Builder.new
      props = order.map { |key| "<property name=\"#{key}\">#{key == 'editable' ? 'False' : 'True'}</property>" }.join
      candidate.add_from_string("<interface><object class=\"GtkEntry\" id=\"entry\">#{props}</object></interface>")
      entry = candidate['entry']
      entry.text = 'server value'
      expect(entry.send(:component_type)).to eq(:text_input)
      expect(entry.send(:component_props)).to include(read_only: true, value: 'server value')
    end
  end

  it 'emits programmatic Entry changes once after a valid write, including read-only entries' do
    entry = gtk::Entry.new
    entry.editable = false
    seen = []
    entry.signal_connect('changed') do |widget|
      seen << widget.text
      widget.set_text(widget.text) # Equal writes inside the handler must not recurse.
    end
    expect(entry.set_text('profile')).to equal(entry)
    entry.text = 'profile'
    expect(seen).to eq(['profile'])
    window = gtk::Window.new
    window.add(entry)
    window.show_all
    drain_gtk
    expect { entry.text = 'x' * 8193 }.to raise_error(Lich::WebUI::Error)
    expect(entry.text).to eq('profile')
    expect(seen).to eq(['profile'])
    window.destroy
  end

  it 'bounds single-line labels and image-free checkbox hints without inventing content' do
    load_xml('<object class="GtkLabel" id="label"><property name="label">One line</property><property name="single-line-mode">True</property></object><object class="GtkCheckButton" id="check"><property name="always-show-image">True</property></object>')
    expect(builder['label'].text).to eq('One line')
    expect { builder['label'].text = "Two\nlines" }.to raise_error(gtk::UnsupportedOperation)
    expect { builder['label'].wrap = true }.to raise_error(gtk::UnsupportedOperation)
    expect { builder['check'].always_show_image = 'yes' }.to raise_error(gtk::UnsupportedOperation)
    expect(Lich).to have_received(:log).with(/single.line.*browser font metrics/)
    expect(Lich).to have_received(:log).with(/always-show-image.*image-free checkbox/)
  end

  it 'maps safe anchor titles to literal tooltips and forwards internal combo tooltips and height' do
    label = gtk::Label.new
    label.set_markup('<a href="https://example.org/help" title="A &quot;quote&quot;">Help</a>')
    label.set_can_focus(true)
    expect(label.send(:component_props)[:content]).to eq('[Help](https://example.org/help "A \"quote\"")')
    expect { label.set_markup('<a href="https://example.org/" onclick="alert(1)">Unsafe</a>') }.to raise_error(gtk::UnsupportedOperation)
    combo = gtk::ComboBoxText.new(entry: true)
    combo.child.tooltip_text = 'Literal help'
    combo.set_height_request(42)
    expect(combo.send(:component_props)).to include(tooltip: 'Literal help', min_height: 42)
  end

  it 'coerces finite numeric and blank adjustment strings while refusing malformed values' do
    adjustment = gtk::Adjustment.new(1, 0, 100, 0.1, 1, 0)
    adjustment.value = '0.3'
    expect(adjustment.value).to eq(0.3)
    adjustment.value = ' '
    expect(adjustment.value).to eq(0)
    %w[bad NaN Infinity].each do |value|
      expect { adjustment.value = value }.to raise_error(gtk::UnsupportedOperation)
    end
  end

  it 'routes Builder inset Frame requests through the same bounded frame setter' do
    load_xml('<object class="GtkFrame" id="frame"><property name="shadow-type">in</property></object>')
    expect(builder['frame'].send(:component_props)[:border_width]).to eq(1)
    expect(builder['frame'].set_label('Live caption')).to equal(builder['frame'])
    expect(builder['frame'].label).to eq('Live caption')
    builder['frame'].shadow_type = :none
    expect(builder['frame'].send(:component_props)[:border_width]).to eq(0)
    expect { builder['frame'].shadow_type = :out }.to raise_error(gtk::UnsupportedOperation)
    expect(builder['frame'].send(:component_props)[:border_width]).to eq(0)
  end

  it 'uses shared character metrics and borderless frames while refusing unsupported focus and alignment values' do
    load_xml('<object class="GtkLabel" id="label"><property name="width-chars">17</property></object><object class="GtkFrame" id="frame"><property name="shadow-type">none</property></object>')
    expect(builder['label'].send(:component_props)).to include(min_width_chars: 17)
    expect(builder['label'].send(:component_props)).not_to have_key(:width)
    expect(builder['frame'].send(:component_props)).to include(border_width: 0)
    [
      '<object class="GtkComboBoxText"><property name="has-entry">True</property><property name="can-focus">True</property></object>',
      '<object class="GtkLabel"><property name="can-focus">True</property></object>',
      '<object class="GtkCheckButton"><property name="valign">baseline</property></object>',
      '<object class="GtkCheckButton"><property name="draw-indicator">False</property></object>',
      '<object class="GtkCheckButton"><property name="receives-default">invalid</property></object>',
      '<object class="GtkButton"><property name="receives-default">False</property></object>',
      '<object class="GtkScrolledWindow"><property name="shadow-type">out</property></object>',
    ].each { |xml| expect { load_xml(xml) }.to raise_error(gtk::BuilderError) }
    expect(builder.objects.length).to eq(2)
  end

  it 'keeps label content alignment, padding and margins independent of declaration order' do
    load_xml(<<~XML)
      <object class="GtkGrid" id="grid"><property name="row-homogeneous">True</property>
        <child><object class="GtkLabel" id="caption">
          <property name="yalign">0</property><property name="xalign">1</property>
          <property name="xpad">5</property><property name="ypad">3</property>
          <property name="margin-start">9</property><property name="angle">90</property>
          <property name="valign">center</property>
          <attributes><attribute name="foreground" value="#ffff00000000"/></attributes>
        </object></child>
      </object>
    XML
    expect(builder['grid'].send(:component_props)).to include(equal_rows: true)
    expect(builder['caption'].send(:component_props)).to include(
      align: :end, content_vertical_align: :start, vertical_align: :center,
      padding_x: 5, padding_y: 3, rotation: '90', margin: { left: 9 }, foreground: { r: 255, g: 0, b: 0, a: 1.0 }
    )
    expect { builder['caption'].angle = 45 }.to raise_error(gtk::UnsupportedOperation)
    expect { builder['caption'].set_padding(-1, 3) }.to raise_error(gtk::UnsupportedOperation)
    expect { gtk::TextView.new.accepts_tab = true }.to raise_error(gtk::UnsupportedOperation)
    validator = Lich::WebUI::Validator.new
    expect { validator.validate_component!(:grid, { cols: 2, equal_rows: true, row_sizing: :spread }, owner: owner.name, page_id: nil, cid: nil) }.to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'keeps line justification independent of label placement in either declaration order' do
    %w[left center right].each do |justify|
      properties = ['<property name="halign">start</property>', "<property name=\"justify\">#{justify}</property>"]
      [properties, properties.reverse].each do |ordered|
        name = "label_#{builder.objects.length}"
        load_xml("<object class=\"GtkLabel\" id=\"#{name}\">#{ordered.join}</object>")
        label = builder[name]
        expect(label.send(:component_props)).to include(align: :start, line_justify: justify.to_sym)
        label.xalign = 1
        expect(label.send(:component_props)).to include(align: :end, line_justify: justify.to_sym)
      end
    end
    label = gtk::Label.new('Caption')
    expect { label.justify = :fill }.to raise_error(gtk::UnsupportedOperation)
    label.justify = :right
    expect { label.set_markup('<a href="https://example.com">Link</a>') }.to raise_error(gtk::UnsupportedOperation)
    linked = gtk::Label.new
    linked.set_markup('<a href="https://example.com">Link</a>')
    expect { linked.justify = :right }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'maps a Builder internal entry width to its single shared combo input' do
    load_xml(<<~XML)
      <object class="GtkWindow" id="window"><child>
        <object class="GtkComboBoxText" id="choice"><property name="has-entry">True</property>
          <child internal-child="entry"><object class="GtkEntry" id="entry">
            <property name="width-request">400</property><property name="tooltip-text">Profile name</property>
            <property name="margin-start">12</property><property name="margin-top">3</property>
          </object></child><items><item>First</item></items>
        </object>
      </child></object>
    XML
    choice, entry = builder['choice'], builder['entry']
    expect(entry.class).to equal(gtk::Entry)
    expect(choice.send(:component_props)).to include(control_width: 400, tooltip: 'Profile name', control_margin: { left: 12, top: 3 })
    expect(choice.send(:component_props)).not_to have_key(:width)
    expect(entry.tooltip_text).to eq('Profile name')
    builder['window'].show_all
    page = nil
    Timeout.timeout(3) { sleep 0.005 until (page = service.registry.pages_for(owner).first)&.last_render }
    expect(page.last_render.tree.each.count { |node| node.type == :select }).to eq(1)
    expect(page.last_render.tree.each.none? { |node| node.type == :text_input }).to be(true)
    choice.margin = 20
    entry.margin_end = 9
    expect(choice.session.port.get(choice.materialize, :control_margin)).to eq(left: 12, top: 3, right: 9)
    expect(choice.session.port.get(choice.materialize, :margin)).to eq(20)
    expect(entry.set_margin_start(12)).to equal(entry)
    expect { entry.margin_bottom = 513 }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect(choice.session.port.get(choice.materialize, :control_margin)).to eq(left: 12, top: 3, right: 9)
    expect(entry.set_width_request(320)).to equal(entry)
    expect(choice.session.port.get(choice.materialize, :control_width)).to eq(320)
    [0, -1, 1025, 1.5, '400'].each do |value|
      expect { entry.width_request = value }.to raise_error(gtk::UnsupportedOperation)
      expect(choice.session.port.get(choice.materialize, :control_width)).to eq(320)
    end
  end

  it 'reuses one closed select for a noneditable combo entry and one numeric change stream' do
    load_xml(<<~XML)
      <object class="GtkComboBoxText" id="choice"><property name="has-entry">True</property>
        <property name="can-focus">False</property>
        <child internal-child="entry"><object class="GtkEntry" id="entry">
          <property name="editable">False</property><property name="can-focus">True</property>
          <property name="width-chars">12</property>
        </object></child><items><item>First</item></items>
      </object>
    XML
    expect(builder['choice'].send(:component_props)).to include(editable: false, min_width_chars: 12)
    builder['entry'].text = 'First'
    expect(builder['choice'].active_text).to eq('First')
    expect { builder['entry'].text = 'Unknown' }.to raise_error(gtk::UnsupportedOperation)
    spin = gtk::SpinButton.new(0, 100, 1)
    events = []
    spin.signal_connect('changed') { events << [:text, spin.buffer.text] }
    spin.signal_connect('value_changed') { events << [:value, spin.value] }
    spin.value = 15
    expect(events).to eq([[:text, '15'], [:value, 15]])
    expect { spin.buffer.text = '18' }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'keeps combo entry focus on one shared input and maps button requests to minima' do
    load_xml(<<~XML)
      <object class="GtkComboBoxText" id="choice"><property name="has-entry">True</property>
        <child internal-child="entry"><object class="GtkEntry" id="entry">
          <property name="can-focus">False</property>
        </object></child><items><item>First</item></items>
      </object>
      <object class="GtkButton" id="action"><property name="label">Action</property>
        <property name="height-request">40</property><property name="width-request">80</property>
      </object>
    XML
    builder['entry'].text = 'Custom'
    expect(builder['choice'].active_text).to eq('Custom')
    expect(builder['choice'].send(:component_props)).to include(editable: true)
    expect(builder['action'].send(:component_props)).to include(min_height: 40, min_width: 80)
    expect(builder['action'].send(:component_props)).not_to have_key(:height)
    expect(builder['action'].send(:component_props)).not_to have_key(:width)
    expect(Lich).to have_received(:log).with(/internal combo entry focus hint is ignored/).once
    expect { builder['entry'].can_focus = :invalid }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'reports ignored modality without limiting same-owner or other-owner windows' do
    first = gtk::Window.new
    first.modal = true
    second = gtk::Window.new
    [first, second].each(&:show_all)
    other = Struct.new(:name).new('other-setup.lic')
    allow(Lich::Common::Script).to receive(:current).and_return(other)
    third = gtk::Window.new
    third.modal = true
    third.show_all
    Timeout.timeout(3) { sleep 0.005 until service.registry.descriptors.length == 3 }
    expect(service.registry.pages_for(owner).length).to eq(2)
    expect(service.registry.pages_for(other).length).to eq(1)
    expect(service.registry.descriptors).to all(satisfy { |descriptor| !descriptor.key?(:modal_for) })
  ensure
    Lich::Common::ScriptDeath.run(other) if other
  end

  it 'preserves object identity, literal text and subclass handler resolution' do
    derived = Class.new(gtk::Builder) do
      attr_reader :clicked

      def save
        @clicked = self['entry'].text
      end
    end.new
    derived.add_from_string(<<~XML)
      <interface><requires lib="gtk+" version="3.20"/>
        <object class="GtkWindow" id="main"><child><object class="GtkBox">
          <property name="orientation">vertical</property>
          <child><object class="GtkEntry" id="entry"><property name="text">001 True &amp; False</property></object></child>
          <child><object class="GtkButton" id="save"><property name="label">Save</property><signal name="clicked" handler="save" swapped="no"/></object></child>
        </object></child></object>
      </interface>
    XML
    expect(derived.get_object(:entry)).to equal(derived['entry'])
    expect(derived['entry'].builder_name).to eq('entry')
    expect(derived.objects.size).to eq(4)
    expect(derived.objects.map(&:builder_name)).to all(be_a(String))
    derived.objects.clear
    expect(derived.objects.size).to eq(4)
    derived.connect_signals { |handler| derived.method(handler) }
    derived['save'].send(:emit_handlers, :activate)
    expect(derived.clicked).to eq('001 True & False')
    expect(service.registry.pages_for(owner)).to be_empty
  end

  it 'refuses undeclared IDs through both lookup APIs without damaging loaded objects' do
    load_xml('<object class="GtkEntry" id="retained"><property name="text">Keep</property></object>')
    original = builder['retained']
    %i[get_object []].each do |lookup|
      expect { builder.public_send(lookup, :missing) }.to raise_error(gtk::BuilderError) do |error|
        expect(error.message).to match(/script=builder.lic.*object=missing.*property=get_object.*native WebUI/)
        expect(error.issues.first).to include(object: 'missing', property: 'get_object')
        expect(error.diagnostic).to include('object=missing', 'property=get_object', 'blockers=1')
      end
    end
    expect(builder.get_object(:retained)).to equal(original)
    expect(original.text).to eq('Keep')
  end

  it 'resolves forward model, adjustment and buffer references with typed values' do
    load_xml(<<~XML)
      <object class="GtkComboBox" id="combo"><property name="model">choices</property><property name="active">0</property>
        <child><object class="GtkCellRendererText"/><attributes><attribute name="text">1</attribute></attributes></child>
      </object>
      <object class="GtkSpinButton" id="spin"><property name="adjustment">range</property><property name="digits">1</property></object>
      <object class="GtkTextView" id="text"><property name="buffer">buffer</property></object>
      <object class="GtkListStore" id="choices"><columns><column type="gint"/><column type="gchararray"/></columns><data><row><col id="0">3</col><col id="1">001</col></row></data></object>
      <object class="GtkAdjustment" id="range"><property name="upper">10</property><property name="step-increment">0.5</property><property name="value">2.5</property></object>
      <object class="GtkTextBuffer" id="buffer"><property name="text">True</property></object>
    XML
    expect(builder['combo'].active_text).to eq('001')
    expect(builder['spin'].value).to eq(2.5)
    expect(builder['text'].buffer).to equal(builder['buffer'])
    expect(builder['buffer'].text).to eq('True')
  end

  it 'assembles notebook tabs and grid packing while retaining italic label presentation' do
    load_xml(<<~XML)
      <object class="GtkNotebook" id="tabs">
        <child><object class="GtkGrid" id="grid"><child><object class="GtkEntry" id="entry"/>
          <packing><property name="left-attach">1</property><property name="top-attach">2</property><property name="width">2</property></packing>
        </child></object></child>
        <child type="tab"><object class="GtkLabel" id="caption"><property name="label">Settings</property></object></child>
      </object>
      <object class="GtkLabel" id="notice"><property name="label">Save with Close</property><attributes><attribute name="style" value="italic"/></attributes></object>
    XML
    expect(builder['tabs'].children).to eq([builder['grid']])
    expect(builder['tabs'].send(:component_props)[:names]).to eq(['Settings'])
    expect(builder['entry'].instance_variable_get(:@placement)).to include(column: 2, row: 3, span: 2)
    expect(builder['notice'].send(:component_props)[:font_style]).to eq('italic')
  end

  it 'reuses the real TreeSelection and applies renderer bindings and false properties' do
    load_xml(<<~XML)
      <object class="GtkTreeView" id="view"><property name="model">store</property>
        <child internal-child="selection"><object class="GtkTreeSelection" id="selection"><property name="mode">multiple</property></object></child>
        <child><object class="GtkTreeViewColumn" id="column"><property name="title">Enabled</property>
          <child><object class="GtkCellRendererToggle" id="toggle"><property name="activatable">False</property></object><attributes><attribute name="active">0</attribute></attributes></child>
        </object></child>
      </object>
      <object class="GtkListStore" id="store"><columns><column type="gboolean"/></columns><data><row><col id="0">True</col></row></data></object>
    XML
    expect(builder['selection']).to equal(builder['view'].selection)
    expect(builder['selection'].mode).to eq(:multiple)
    expect(builder['toggle'].activatable?).to be(false)
    expect(builder['view'].send(:component_props)[:rows].first[:cells].values).to eq([true])
  end

  it 'rejects additions atomically with object, property and owner attribution' do
    load_xml('<object class="GtkEntry" id="retained"><property name="text">Keep</property></object>')
    original = builder.objects
    expect do
      load_xml('<object class="GtkWindow" id="candidate"><child><object class="GtkLabel" id="bad"><property name="angle">45</property></object></child></object>')
    end.to raise_error(gtk::BuilderError, /script=builder.lic.*object=bad.*property=angle/)
    expect(builder.objects).to eq(original)
    expect(builder['retained'].text).to eq('Keep')
    expect { builder['candidate'] }.to raise_error(gtk::BuilderError, /object=candidate/)
    expect(gtk.session.instance_variable_get(:@windows)).to be_empty
    expect(service.registry.pages_for(owner)).to be_empty
    expect { load_xml('<object class="GtkEntry" id="retained"/>') }.to raise_error(gtk::BuilderError, /duplicate identifier/)
    expect { load_xml('<object class="GtkTreeView"><property name="model">missing</property></object>') }.to raise_error(gtk::BuilderError, /unresolved.*missing/)
    expect do
      load_xml('<object class="GtkWindow" id="candidate"><child><object class="GtkEntry"><property name="width-request">70000</property></object></child></object>')
    end.to raise_error(gtk::BuilderError, /component properties/)
    expect(gtk.session.instance_variable_get(:@windows)).to be_empty
    expect(builder.objects).to eq(original)
  end

  it 'retains all unmapped properties and keeps structural diagnostics in queued failures' do
    xml = '<interface><object class="GtkWindow" id="main"><property name="decorated">False</property><property name="transient-for">peer</property></object></interface>'
    expect { builder.add_from_string(xml) }.to raise_error(gtk::BuilderError) { |error| expect(error.issues.map { |issue| issue[:property] }).to eq(%w[decorated transient-for]) }
    messages = Queue.new
    allow(Lich).to receive(:log) { |message| messages << message if message.include?('blockers=') }
    gtk.queue { builder.add_from_string(xml) }
    message = messages.pop(timeout: 2)
    expect(message).to include('object=main', 'property=decorated', 'reason=unsupported property', 'blockers=2')
    expect(message).not_to include('<interface>', '>False<')
  end

  it 'loads local files and exposes the actual internal combo entry' do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'form.ui')
      File.write(path, <<~XML)
        <interface><object class="GtkComboBoxText" id="combo"><property name="has-entry">True</property>
          <child internal-child="entry"><object class="GtkEntry" id="entry"><property name="text">Custom</property></object></child>
          <items><item>First</item><item>Second</item></items>
        </object></interface>
      XML
      builder.add_from_file(path)
      expect(builder['entry']).to equal(builder['combo'].child)
      expect(builder['combo'].active_text).to eq('Custom')
    end
  end

  it 'runs unchanged ecleanse setup through Chrome with the original callbacks', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'

    settings = { stop_scripts: 'bigshot', cleanse_poison: false }
    form = original_ecleanse(settings)
    form['main'].show_all
    page = nil
    Timeout.timeout(2) { sleep 0.005 until (page = service.registry.pages_for(owner).first)&.last_render }
    WebUIBrowser.check(service: service, page: page, scenario: 'shim-builder')
    drain_gtk
    expect(settings).to include(stop_scripts: 'hunting, travel', cleanse_poison: true, use_flee: true, use_stance1: false)
    expect(YAML.unsafe_load_file(saved_settings_path)).to include(stop_scripts: 'hunting, travel', cleanse_poison: true)
    expect(form['main']).to be_destroyed
    expect(@messages.grep(/WITHOUT saving/)).to be_empty
  end

  it 'validates every handler before connecting and preserves close veto return values' do
    load_xml(<<~XML)
      <object class="GtkWindow" id="main"><signal name="delete-event" handler="veto"/></object>
      <object class="GtkButton" id="button"><signal name="clicked" handler="save"/></object>
    XML
    calls = []
    expect { builder.connect_signals { |name| name == 'veto' ? proc { true } : nil } }.to raise_error(gtk::BuilderError, /handler must/)
    builder['button'].send(:emit_handlers, :activate)
    expect(calls).to be_empty
    builder.connect_signals { |name| name == 'veto' ? proc { true } : proc { calls << :saved } }
    builder.connect_signals { raise 'already connected' }
    expect(builder['main'].send(:emit_handlers, :close)).to be(true)
    builder['button'].send(:emit_handlers, :activate)
    expect(calls).to eq([:saved])
  end

  it 'refuses unknown structure, unsupported signal flags and unsafe or oversized XML' do
    [
      '<object class="GtkMissing" id="bad"/>',
      '<object class="GtkButton" id="bad"><signal name="clicked" handler="save" after="true"/></object>',
      '<object class="GtkLabel" id="bad"><style><class name="unknown"/></style></object>',
      '<object class="GtkEntry" id="bad"><property name="editable">not-a-boolean</property></object>',
      '<object class="GtkBox"><child><object class="GtkEntry"/><placeholder/></child></object>',
      '<object class="GtkFrame"><child type="label"><object class="GtkLabel"/><packing><property name="expand">True</property></packing></child></object>',
      '<object class="GtkComboBoxText"><property name="has-entry">True</property><child internal-child="entry"><object class="GtkEntry"><signal name="activate" handler="save"/></object></child></object>',
      '<object class="GtkNotebook"><child><object class="GtkBox"/></child><child type="tab"><object class="GtkLabel"><attributes><attribute name="style" value="italic"/></attributes></object></child></object>',
      '<object class="GtkTreeViewColumn"><child><object class="GtkCellRendererText"/><attributes><attribute name="text">0</attribute><attribute name="text">1</attribute></attributes></child></object>',
    ].each do |body|
      expect { load_xml(body) }.to raise_error(gtk::BuilderError)
      expect(builder.objects).to be_empty
    end
    expect { builder.add_from_string('<!DOCTYPE interface><interface/>') }.to raise_error(gtk::BuilderError, /DTD/)
    expect { builder.add_from_string('x' * (gtk::Builder::MAX_BYTES + 1)) }.to raise_error(gtk::BuilderError, /bounded/)
    expect { builder.add_from_string('<interface>') }.to raise_error(gtk::BuilderError, /malformed/)
  end

  it 'connects both combo choice signal spellings without replacing the edited text contract' do
    builder.add_from_string(<<~XML)
      <interface>
        <object class="GtkListStore" id="choices"><columns><column type="gchararray"/></columns>
          <data><row><col id="0">Chosen</col></row></data>
        </object>
        <object class="GtkCellRendererCombo" id="cell">
          <property name="model">choices</property><property name="editable">True</property>
          <signal name="changed" handler="choice_changed"/><signal name="edited" handler="text_edited"/>
        </object>
        <object class="GtkLabel" id="label"><property name="selectable">True</property></object>
      </interface>
    XML
    calls = []
    builder.connect_signals { |name| proc { |_cell, _path, value| calls << [name, value] } }
    choice = builder['choices'].iter_first
    builder['cell'].emit_edit('0', choice.key)
    expect(calls[0][0]).to eq('choice_changed')
    expect(calls[0][1].model).to equal(builder['choices'])
    expect(calls[1]).to eq(['text_edited', 'Chosen'])
  end
end
