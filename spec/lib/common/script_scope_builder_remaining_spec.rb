# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/script_scope'
require_relative '../../support/webui_browser'
require_relative '../../support/webui_builder_source_repairs'
require 'timeout'
require 'digest'
require 'yaml'

RSpec.describe 'remaining Builder setup families' do
  let(:scope) { Lich::Common::ScriptScope }
  let(:owner) { Struct.new(:name).new('remaining-builder.lic') }
  let(:service) { Lich::WebUI::Service.new }
  let(:gtk) { scope.const_get(:Gtk, false) }

  around do |example|
    Dir.mktmpdir('remaining-builder-settings-') do |directory|
      @settings_directory = directory
      old_data, old_scripts = $data_dir, $script_dir
      $data_dir = $script_dir = directory
      example.run
    ensure
      $data_dir, $script_dir = old_data, old_scripts
    end
  end

  before do
    scope.activate!
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    allow(Lich::WebUI).to receive(:adapter) { |owner:, viewer: nil| Lich::WebUI::Adapter.new(owner: owner, service: service, viewer: viewer) }
    allow(Lich::WebUI).to receive(:callback_queue) { |owner:| proc { |&work| service.runtime.dispatch(owner: owner, &work) } }
    @diagnostics, @downloads, @saved = [], [], []
    allow(Lich).to receive(:log) { |message| @diagnostics << message }
  end

  after do
    Lich::Common::ScriptDeath.run(owner)
    service.stop
    @runner&.join(2)
    @runner&.kill if @runner&.alive?
  end

  def drain(expect_success: true)
    2.times do
      barrier = Queue.new
      service.runtime.dispatch(owner: owner) { barrier << true }
      expect(barrier.pop(timeout: 3)).to be(true)
    end
    expect(@diagnostics.grep(/callback failed/)).to be_empty, @diagnostics.join("\n") if expect_success
  end

  # Keep all original construction and callbacks. Only game lookups, waiting
  # and external command/persistence destinations belong to this isolated harness.
  def original(name, game: 'GS', listing: nil, source_failure: false, corrected: false, settings: {})
    sandbox = Module.new
    sandbox.const_set(:Gtk, gtk)
    sandbox.const_set(:XMLData, double(game: game))
    sandbox.const_set(:Stats, double(prof: 'Warrior'))
    sandbox.const_set(:Society, double(membership: 'None', rank: 0))
    sandbox.const_set(:Char, double(name: 'Fixture'))
    variables = sandbox.const_set(:UserVars, Module.new)
    variables.define_singleton_method(:op=) { |settings| @saved_settings = settings.dup }
    variables.define_singleton_method(:op) { @saved_settings }
    @variables = variables
    messaging = Module.new
    messaging.define_singleton_method(:msg) { |*_args| nil }
    sandbox.const_set(:Lich, Module.new).const_set(:Messaging, messaging)
    go2 = sandbox.const_set(:Go2, Module.new)
    saved, downloads = @saved, @downloads
    go2.define_singleton_method(:load) { |settings| saved << settings.dup }
    go2.define_singleton_method(:get_script_version) { 'fixture' }
    script = Object.new
    script.define_singleton_method(:run) { |*args, **options| downloads << [args, options] }
    sandbox.const_set(:Script, script)
    path = File.expand_path("../../fixtures/webui/#{name}_setup.lic", __dir__)
    source = File.read(path)
    expected = { 'repository' => 'ac0107e3149a487f61cfd345a3b962b7673df65ec99921f4b9fdd74d47dd86e5',
                 'go2'        => '8bdcf8959473c59d9da2eba4dbc69a2dd13185acd9a3c556288b1bd8198862b2',
                 'bigshot'    => 'da564437b0eb893e8abd3757afdbbe35bd57b4b134d24e562e4f17d1af76ad34',
                 'huntplan'   => '14d3be8481c1d1abc76cf7394c9dc7d7fb4aca8966b33fb4d3940f9bcabf92a5' }
    wrappers = { 'repository' => 3, 'go2' => 2, 'bigshot' => 1, 'huntplan' => 1 }.fetch(name)
    expect(Digest::SHA256.hexdigest(source.lines[wrappers...-wrappers].join.lstrip.chomp)).to eq(expected.fetch(name))
    source = WebUIBuilderSourceRepairs.apply(name, source) if corrected
    sandbox.module_eval(source, path)
    klass = case name
            when 'repository' then sandbox::Repository::RepositoryGUI::Setup
            when 'go2' then go2::Setup
            when 'bigshot' then sandbox::Bigshot::Setup
            when 'huntplan'
              sandbox::HuntPlan.define_singleton_method(:save_profile) { |settings| saved << settings.dup }
              sandbox::HuntPlan::Setup
            end
    klass.define_method(:wait_while) { |&condition| sleep 0.005 while condition.call }
    @settings = settings
    if name == 'bigshot'
      @profile_directory = File.join(@settings_directory, game, 'Fixture', 'bigshot_profiles')
      FileUtils.mkdir_p(@profile_directory)
      defaults = klass.class_variable_get(:@@categories).values.each_with_object({}) do |entries, values|
        entries.each { |key, definition| values[key.to_s] = definition[:default] }
      end
      File.write(File.join(@profile_directory, 'fixture.yaml'), defaults.merge('resting_room_id' => '1234', 'fog_return' => '6').to_yaml)
    end
    @form = nil
    if name == 'repository'
      rows = listing || [['header'], ['zeta.lic', 'GS', '2048', '1700000000', 'Zed', '1200', '8', '2', 'hunting', 'Zeta comments'],
                         ['alpha.lic', 'GS', '10240', '1700000000', 'Ada', '90', '5', '1', 'travel', 'Alpha comments']]
      # Its constructor owns the wait loop, so retain the allocated instance for cleanup.
      @form = klass.allocate
      @runner = Thread.new { @form.send(:initialize, rows) }
      Timeout.timeout(3) { sleep 0.005 until @form.instance_variable_get(:@running) }
    else
      @form = klass.new(@settings)
      if source_failure
        drain(expect_success: false)
        return @form
      end
      drain
      @runner = Thread.new { @form.start }
    end
    page = nil
    Timeout.timeout(4) do
      loop do
        drain
        page = service.registry.pages_for(owner).first
        break if page&.last_render
        sleep 0.005
      end
    end
    @page = page
    @form
  end

  def connect
    @messages = []
    @connection = double('viewer', viewer_id: 'fixture', alive?: true)
    allow(@connection).to receive(:send_text) { |json| @messages << JSON.parse(json) }
    service.runtime.handle(@connection, type: 'attach', page: service.registry.address_for(@page))
  end

  def cid(widget)
    handle = widget.instance_variable_get(:@handle)
    widget.session.port.send(:node!, handle).cid
  end

  # Each render of these forms costs tens of milliseconds. Only a :current
  # submission needs a fresh tree: viewer value changes do not re-render, so the
  # last delivered tree can hold stale input values. Other events only need the
  # delivered generation; queue_event already retries a stale one once.
  def render_for(submission)
    render = @messages.reverse.find { |message| message['type'] == 'render' }
    return render if render && submission != :current

    service.runtime.refresh(@page)
    @messages.reverse.find { |message| message['type'] == 'render' }
  end

  def event(widget, name, payload, submission: nil)
    render = render_for(submission)
    message = { type: 'event', page: service.registry.address_for(@page), generation: render['generation'],
                cid: cid(widget), event: name, payload: payload }
    if submission == :current
      pending = [render.fetch('tree')]
      inputs = {}
      until pending.empty?
        node = pending.pop
        inputs[node['cid']] = node
        pending.concat(node.fetch('children', []))
      end
      message[:submission] = @page.last_render.submissions.fetch(cid(widget), []).map do |id|
        node = inputs.fetch(id)
        property = case node.fetch('type')
                   when 'checkbox', 'radio_option', 'toggle' then 'checked'
                   when 'radio', 'table' then 'selected'
                   else 'value'
                   end
        node.fetch('props').fetch(property)
      end
    elsif submission
      message[:submission] = submission
    end
    queue_event(message)
    drain
  end

  def queue_event(message)
    2.times do |attempt|
      first_response = @messages.length
      result = service.runtime.handle(@connection, message)
      responses = @messages.drop(first_response)
      refusal = responses.reverse.find do |response|
        response['type'] == 'refusal' && %i[page cid event].all? { |key| response[key.to_s] == message[key] }
      end
      if attempt.zero? && result == :refused && refusal&.fetch('reason') == 'stale_generation'
        render = responses.reverse.find { |response| response['type'] == 'render' && response['page'] == message[:page] }
        if render
          message = message.merge(generation: render.fetch('generation'))
          next
        end
      end
      expect(result).to eq(:queued), "Event #{message[:event]} for #{message[:cid]}: #{refusal.inspect} (result: #{result.inspect})"
      break
    end
  end

  it 'retries a stale event once with its original payload and submission' do
    @messages, @connection = [], double('viewer')
    message = { type: 'event', page: 'fixture', cid: 'entry', event: 'change', generation: 1,
                payload: { value: 'draft' }, submission: ['original'] }
    refusal = { 'type' => 'refusal', 'page' => 'fixture', 'cid' => 'entry', 'event' => 'change', 'reason' => 'stale_generation' }
    expect(service.runtime).to receive(:handle).with(@connection, message).ordered do
      @messages.push(refusal, { 'type' => 'render', 'page' => 'fixture', 'generation' => 2 })
      :refused
    end
    expect(service.runtime).to receive(:handle).with(@connection, message.merge(generation: 2)).ordered.and_return(:queued)
    queue_event(message)
    expect(message[:generation]).to eq(1)
  end

  it 'reports a repeated stale refusal without a third attempt' do
    @messages, @connection = [], double('viewer')
    message = { type: 'event', page: 'fixture', cid: 'entry', event: 'change', generation: 1, payload: { value: 'draft' } }
    expect(service.runtime).to receive(:handle).twice do
      @messages.push({ 'type' => 'refusal', 'page' => 'fixture', 'cid' => 'entry', 'event' => 'change', 'reason' => 'stale_generation' },
                     { 'type' => 'render', 'page' => 'fixture', 'generation' => 2 })
      :refused
    end
    expect { queue_event(message) }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /stale_generation/)
  end

  it 'reports other refusals without retrying or reusing an earlier stale refusal' do
    @connection = double('viewer')
    message = { type: 'event', page: 'fixture', cid: 'entry', event: 'change', generation: 1, payload: { value: 'draft' } }
    refusal = { 'type' => 'refusal', 'page' => 'fixture', 'cid' => 'entry', 'event' => 'change', 'reason' => 'stale_generation' }
    @messages = [refusal]
    expect(service.runtime).to receive(:handle).once do
      @messages << refusal.merge('reason' => 'payload')
      :refused
    end
    expect { queue_event(message) }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /"reason" => "payload"/)
  end

  it 'preserves all untouched margins consistently through Builder and direct edge setters' do
    %i[top right bottom left].each do |side|
      widget = gtk::Box.new(:vertical, 0)
      widget.set_border_width(10)
      widget.public_send("set_margin_#{side}", 5)
      expected = %i[top right bottom left].to_h { |key| [key, key == side ? 5 : 10] }
      expect(widget.send(:component_props)[:margin]).to eq(expected)
      builder = gtk::Builder.new
      builder.add_from_string(<<~XML)
        <interface><object class="GtkBox" id="box">
          <property name="border-width">10</property>
          <property name="margin-#{side}">5</property>
        </object></interface>
      XML
      expect(builder['box'].send(:component_props)[:margin]).to eq(expected)
      widget.public_send("set_margin_#{side}", 0)
      expect(widget.send(:component_props)[:margin]).to eq(expected.merge(side => 0))
    end
    widget = gtk::Box.new(:vertical, 0)
    widget.set_margin_start(3)
    widget.set_margin_end(7)
    widget.set_margin_bottom(2)
    expect(widget.send(:component_props)[:margin]).to eq(right: 7, bottom: 2, left: 3)
  end

  it 'loads repository, preserves numeric sorting and filters before activating the original download callback' do
    form = original('repository')
    connect
    tabs = @page.last_render.tree.each.find { |node| node.type == :tabs }
    expect(tabs.props[:show_tabs]).to be(false)
    table = @page.last_render.tree.each.find { |node| node.type == :table }
    expect(table.props).to include(activation: 'single', grid_lines: 'both')
    expect(table.props).not_to have_key(:search_column)
    expect(table.props[:columns].map { |column| column[:align] }).to include('end')
    size_column = form['repository'].columns.find { |column| column.sort_column_id == 3 }
    event(form['repository'], 'sort_change', { column: size_column.key, direction: 'asc' })
    expect(form['repository_store'].rows.map { |iter| iter[0] }).to eq(['zeta.lic', 'alpha.lic'])
    event(form['search_entry'], 'change', { value: 'travel' })
    row = form['repository_store'].iter_first
    expect(row[0]).to eq('alpha.lic')
    event(form['repository'], 'row_activate', { row: row.key }, submission: :current)
    expect(form['comments'].text).to eq('Alpha comments')
    event(form['download_link'], 'activate', {}, submission: :current)
    expect(@downloads).to eq([[['repository', 'download alpha.lic --author=Ada --game=GS'], { force: true }]])
    form.on_close_clicked
    drain
    expect(@runner.join(2)).to equal(@runner)
    expect(service.registry.pages_for(owner)).to be_empty
  end

  it 'populates repository with long and absent comments and displays each without truncation' do
    comment = 'Full description. ' * 1000
    listing = [['header'], ['long.lic', 'GS', '2048', '1700000000', 'Test', '1', '0', '0', '', comment],
               ['absent.lic', 'GS', '2048', '1700000000', 'Test', '1', '0', '0', '', nil]]
    form = original('repository', listing: listing)
    connect
    rows = form['repository_store'].rows
    expect(rows.map { |iter| iter[13] }).to eq([nil, comment])
    rows.reverse_each do |iter|
      event(form['repository'], 'row_activate', { row: iter.key }, submission: :current)
      expect(form['comments'].text).to eq(iter[13].to_s)
      service.runtime.refresh(@page)
      node = @page.last_render.tree.each.find { |item| item.cid == cid(form['comments']) }
      expect(node.props[:content]).to eq(iter[13].to_s)
    end
    form.on_close_clicked
    drain
    expect(@runner.join(2)).to equal(@runner)
  end

  %w[GS DR].each do |game|
    it "loads go2 #{game} settings and runs the original update/Close callbacks" do
      form = original('go2', game: game)
      connect
      event(form['delay'], 'change', { value: 7 })
      event(form['echo_input'], 'change', { value: false })
      expect(@settings).to include(delay: 7, echo_input: false)
      form.on_close_clicked
      drain
      expect(@saved.last).to include(delay: 7, echo_input: false)
      expect(@runner.join(2)).to equal(@runner)
      expect(service.registry.pages_for(owner)).to be_empty
    end
  end

  it 'reports the unchanged bigshot obsolete tooltip target instead of inventing a widget' do
    allow(owner).to receive(:kill)
    form = original('bigshot', source_failure: true)
    failures = @diagnostics.grep(/callback failed/)
    expect(failures.length).to eq(1), @diagnostics.join("\n")
    expect(failures.first).to include('BuilderError', 'object=boon_flee_from', 'property=get_object', 'undeclared object identifier')
    expect { form['boon_flee_from'] }.to raise_error(gtk::BuilderError, /object=boon_flee_from/)
    expect(form['main']).to be_destroyed
    expect(service.registry.pages_for(owner)).to be_empty
    expect(owner).to have_received(:kill).with(async: true)
    expect(gtk.queue { raise 'late work must not run' }).to be_nil
  end

  it 'loads the explicitly corrected bigshot candidate and saves through its original Close handler' do
    form = original('bigshot', corrected: true)
    connect
    event(form['resting_room_id'], 'change', { value: '1234' })
    event(form['wander_wait'], 'change', { value: 0.7 })
    event(form['attack_drop'], 'change', { value: 'text:Guarded' })
    expect(form['hunting_stance'].class).to eq(gtk::Entry)
    expect(@settings[:hunting_stance]).to eq('Guarded')
    event(form['notes'], 'blur', { value: "Acceptance notes\nsecond line" })
    close = form.objects.find { |widget| widget.is_a?(gtk::Button) && widget.label == 'Close' }
    event(close, 'activate', {}, submission: :current)
    expect(@variables.op).to include('resting_room_id' => '1234', 'wander_wait' => '0.7', 'notes' => "Acceptance notes\nsecond line")
    expect(@runner.join(2)).to equal(@runner)
    expect(service.registry.pages_for(owner)).to be_empty
  end

  [true, false, nil].each do |legacy|
    it "migrates corrected bigshot legacy boon flag #{legacy.inspect} without replaying it", :slow do
      form = original('bigshot', corrected: true, settings: { boon_flee_from: legacy })
      connect
      expect(form.settings).not_to have_key(:boon_flee_from)
      expect(form['boons_all:flee'].active?).to eq(legacy == true)
      event(form['boons_all:ignore'], 'change', { value: true })
      form.refresh_boon_settings
      expect(form.settings[:boons_all]).to eq(['ignore'])
      expect(form.settings[:boons_flee]).to be_empty
      expect(form.settings[:boons_ignore].length).to eq(form.instance_variable_get(:@groups).values.flatten.length)
      form.load_settings(false)
      drain
      expect(form['boons_all:ignore'].active?).to be(true)
      expect(form['boons_all:flee'].active?).to be(false)
      event(form['boons_all:common'], 'change', { value: true })
      form.refresh_boon_settings
      expect(form.settings[:boons_all]).to eq(['common'])
      expect(form.settings[:boons_flee]).to be_empty
      expect(form.settings[:boons_ignore]).to be_empty
      form['main'].destroy
      drain
      expect(@runner.join(2)).to equal(@runner)
      expect(@variables.op).to be_nil
    end
  end

  it 'loads a corrected bigshot profile and applies its dependent fog control' do
    form = original('bigshot', corrected: true)
    connect
    choice = form['profile_name'].send(:component_props)[:options].find { |option| option[:label] == 'fixture' }
    event(form['profile_name'], 'change', { value: choice.fetch(:value) })
    event(form['profile_button'], 'activate', {}, submission: :current)
    # Profile loading queues further changed handlers after drain's markers.
    # Wait for their effects together; a fixed number of markers cannot prove completion.
    Timeout.timeout(3, Timeout::Error, 'Bigshot profile callbacks did not reach the expected state') do
      loop do
        expect(@diagnostics.grep(/callback failed/)).to be_empty, @diagnostics.join("\n")
        break if form['resting_room_id'].text == '1234' && form['profile_current'].text == 'fixture' && form['custom_fog'].sensitive?

        sleep 0.005
      end
    end
    expect(form['resting_room_id'].text).to eq('1234')
    expect(form['profile_current'].text).to eq('fixture')
    expect(form['custom_fog'].sensitive?).to be(true)
    form['main'].destroy
    drain
    expect(@runner.join(2)).to equal(@runner)
    expect(@variables.op).to be_nil
  end

  it 'updates corrected bigshot scalar fields and text areas through their original handlers' do
    form = original('bigshot', corrected: true)
    connect
    custom = form['fog_return'].send(:component_props)[:options].find { |option| option[:label] == 'Custom' }
    event(form['fog_return'], 'change', { value: custom.fetch(:value) })
    expect(form['custom_fog'].is_sensitive?).to be(true)
    # Event admission uses delivered sensitivity; publish the callback's enable
    # before sending an edit, just as a browser waits for its disabled field.
    service.runtime.refresh(@page)
    controls = form.objects.select { |widget| widget.respond_to?(:builder_name) && form.class.get_setting(widget.builder_name.to_sym) }
    entries = controls.select { |widget| widget.instance_of?(gtk::Entry) && !widget.send(:component_props)[:read_only] }
    expect(entries.length).to be > 20
    entries.each do |entry|
      target = entry.is_a?(gtk::ComboEntry) ? entry.parent : entry
      next if entry.is_a?(gtk::ComboEntry) && !target.send(:component_props)[:editable]

      value = "fixture #{entry.builder_name}"
      value = value[0, entry.instance_variable_get(:@props)[:max_length] || value.length]
      event(target, 'change', { value: entry.is_a?(gtk::ComboEntry) ? "text:#{value}" : value })
      expect(form.settings[entry.builder_name.to_sym]).to eq(value)
    end
    spins = controls.select { |widget| widget.instance_of?(gtk::SpinButton) }
    expect(spins).not_to be_empty
    spins.each do |spin|
      value = ((spin.adjustment.lower + spin.adjustment.upper) / 2.0).floor
      event(spin, 'change', { value: value })
      expect(form.settings[spin.builder_name.to_sym].to_f).to eq(value)
    end
    texts = controls.select { |widget| widget.instance_of?(gtk::TextView) }
    expect(texts).not_to be_empty
    texts.each do |text|
      value = "fixture #{text.builder_name}\nsecond line"
      event(text, 'blur', { value: value })
      expect(form.settings[text.builder_name.to_sym]).to eq(value)
    end
    form['main'].destroy
    drain
    expect(@runner.join(2)).to equal(@runner)
    expect(@variables.op).to be_nil
  end

  it 'runs corrected bigshot new-profile, overwrite/cancel and update-profile paths', :slow do
    form = original('bigshot', corrected: true)
    connect
    existing = Dir.children(@profile_directory)
    event(form['profile_save'], 'activate', {}, submission: :current)
    expect(form['test_label'].text).to eq('Please enter a name before saving the profile')
    event(form['save_current'], 'activate', {}, submission: :current)
    expect(form['no_current_profile'].text).to eq('Please enter a name before saving the profile')
    expect(Dir.children(@profile_directory)).to match_array(existing)
    event(form['save_profile_name'], 'change', { value: 'new-profile' })
    event(form['profile_save'], 'activate', {}, submission: :current)
    path = File.join(@profile_directory, 'new-profile.yaml')
    expect(File).to exist(path)
    expect(form['profile_current'].text).to eq('new-profile')
    original_file = File.read(path)
    event(form['resting_room_id'], 'change', { value: '5678' })
    event(form['save_profile_name'], 'change', { value: 'new-profile' })
    event(form['profile_save'], 'activate', {}, submission: :current)
    expect(form['profile_overwrite'].visible?).to be(true)
    event(form['profile_cancel'], 'activate', {}, submission: :current)
    expect(File.read(path)).to eq(original_file)
    event(form['save_profile_name'], 'change', { value: 'new-profile' })
    event(form['profile_save'], 'activate', {}, submission: :current)
    event(form['profile_overwrite'], 'activate', {}, submission: :current)
    expect(YAML.unsafe_load_file(path)).to include('resting_room_id' => '5678')
    event(form['resting_room_id'], 'change', { value: '9012' })
    event(form['save_current'], 'activate', {}, submission: :current)
    expect(YAML.unsafe_load_file(path)).to include('resting_room_id' => '9012')
    form['main'].destroy
    drain
    expect(@runner.join(2)).to equal(@runner)
  end

  it 'loads unchanged huntplan, rejects an invalid slot and saves the original settings' do
    form = original('huntplan')
    connect
    expect(form['ebounty_slot'].name).to eq('ebounty_slot_label')
    expect(form['ebounty_slot'].builder_name).to eq('ebounty_slot')
    save = form.objects.find { |widget| widget.is_a?(gtk::Button) && widget.label == 'Save & Exit' }
    event(form['default_profile'], 'change', { value: 'fixture-default' })
    event(form['bounty_profile'], 'change', { value: 'fixture-bounty' })
    event(form['ebounty_slot'], 'change', { value: 'z' })
    event(save, 'activate', {}, submission: :current)
    expect(form['status_label'].text).to eq('invalid ebounty profile slot: z')
    expect(@saved).to be_empty
    expect(form['main']).not_to be_destroyed
    event(form['ebounty_slot'], 'change', { value: 'j' })
    event(save, 'activate', {}, submission: :current)
    expect(@saved.last).to include(default_profile: 'fixture-default', bounty_profile: 'fixture-bounty', ebounty_slot: 'j')
    expect(@runner.join(2)).to equal(@runner)
    expect(service.registry.pages_for(owner)).to be_empty
  end

  it 'runs the corrected bigshot candidate through Chrome controls, boons and profile saving', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'

    form = original('bigshot', corrected: true)
    controls = form.objects.filter_map do |widget|
      next unless widget.respond_to?(:builder_name) && widget.instance_variable_get(:@handle)
      [widget.builder_name, cid(widget)]
    end.to_h
    WebUIBrowser.check(service: service, page: @page, scenario: 'shim-bigshot-corrected', controls: controls)
    drain
    expect(@runner.join(2)).to equal(@runner)
    expect(@variables.op).to include('resting_room_id' => '1234', 'wander_wait' => '0.7', 'hunting_stance' => 'Guarded', 'notes' => "Acceptance notes\nsecond line")
    expect(@variables.op['boons_ignore']).to include('crit_death_immune')
    expect(@variables.op['boons_flee']).not_to include('crit_death_immune')
    expect(YAML.unsafe_load_file(File.join(@profile_directory, 'browser-profile.yaml'))).to include('hunting_stance' => 'Guarded')
    expect(form['main']).to be_destroyed
    expect(service.registry.pages_for(owner)).to be_empty
  end

  [['repository', 'GS'], ['go2', 'GS'], ['go2', 'DR'], ['huntplan', 'GS']].each do |name, game|
    it "runs original #{name} #{game} setup interactions in Chrome", browser: true do
      skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'

      # Include production-shaped missing and long metadata in the browser path,
      # while retaining deterministic names, sorting and inert download targets.
      listing = if name == 'repository'
                  [['header'], ['zeta.lic', 'GS', '2048', '1700000000', 'Zed', '1200', '8', '2', 'hunting', nil],
                   ['alpha.lic', 'GS', '10240', '1700000000', 'Ada', '90', '5', '1', 'travel', 'Alpha comments Dreaven' + (' more details.' * 1000)]] +
                    Array.new(40) { |index| ["filler-#{index}.lic", 'GS', '20480', '1700000000', 'Fixture', '1', '0', '0', '', ''] }
                end
      form = original(name, game: game, listing: listing)
      controls = form.objects.filter_map do |widget|
        next unless widget.respond_to?(:builder_name) && widget.instance_variable_get(:@handle)
        [widget.builder_name, cid(widget)]
      end.to_h
      WebUIBrowser.check(service: service, page: @page, scenario: "shim-#{name}", controls: controls)
      drain
      expect(form['main']).to be_destroyed
      expect(@runner.join(2)).to equal(@runner)
      expect(service.registry.pages_for(owner)).to be_empty
      if name == 'repository'
        expect(@downloads).to eq([[['repository', 'download alpha.lic --author=Ada --game=GS'], { force: true }]])
      elsif name == 'huntplan'
        expect(@saved.last).to include(default_profile: 'fixture-default', bounty_profile: 'fixture-bounty', ebounty_slot: 'j')
      else
        expect(@saved.last).to include(delay: 7, echo_input: false)
      end
    end
  end

  it 'refuses visible or multiple-page notebook reordering and unsupported search icon actions' do
    page = '<child><object class="GtkLabel"/></child><child type="tab"><object class="GtkLabel"/>' \
           '<packing><property name="reorderable">True</property></packing></child>'
    ["<object class=\"GtkNotebook\">#{page}</object>",
     "<object class=\"GtkNotebook\"><property name=\"show-tabs\">False</property>#{page}#{page}</object>"].each do |notebook|
      candidate = gtk::Builder.new
      expect { candidate.add_from_string("<interface>#{notebook}</interface>") }.to raise_error(gtk::BuilderError, /reorderable/)
      expect(candidate.objects).to be_empty
    end
    search = gtk::SearchEntry.new
    expect { search.primary_icon_name = 'document-open' }.to raise_error(gtk::UnsupportedOperation)
    expect { search.primary_icon_activatable = true }.to raise_error(gtk::UnsupportedOperation)
    expect { search.primary_icon_sensitive = true }.to raise_error(gtk::UnsupportedOperation)
    expect { gtk::Label.new.justify = :fill }.to raise_error(gtk::UnsupportedOperation)
  end
end
