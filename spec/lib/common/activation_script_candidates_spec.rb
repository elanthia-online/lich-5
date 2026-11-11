# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/script_scope'
require 'digest'
require 'json'
require 'sqlite3'
require 'timeout'
require 'base64'
require 'ostruct'

# Use the real Vars persistence provider without leaving its autosave timer alive.
unless defined?(Lich::Common::Vars)
  previous_threads = Thread.list
  require_relative '../../../lib/common/vars'
  (Thread.list - previous_threads).each { |thread| thread.kill.join }
end

RSpec.describe 'prepared activation script setup paths' do
  let(:fixture) { JSON.parse(File.read(File.expand_path('../../fixtures/webui/activation-candidates.json', __dir__))) }
  let(:scope) { Lich::Common::ScriptScope }
  let(:gtk) { scope::Gtk }
  let(:owner) { Struct.new(:name, :thread_group).new('activation-candidate.lic', ThreadGroup.new) }
  let(:service) { Lich::WebUI::Service.new }
  let(:db) { SQLite3::Database.new(':memory:') }

  around do |example|
    vars = Lich::Common::Vars
    saved = %i[@@vars @@md5 @@load_state @@autosave_error].to_h { |key| [key, vars.class_variable_get(key)] }
    example.run
  ensure
    saved.each { |key, value| vars.class_variable_set(key, value) }
  end

  before do
    scope.activate!
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    allow(Lich::WebUI).to receive(:service).and_return(service)
    allow(Lich::WebUI).to receive(:start).and_return(service)
    allow(Lich::WebUI).to receive(:open).and_return(true)
    allow(Lich::WebUI).to receive(:adapter) { |owner:, viewer: nil| Lich::WebUI::Adapter.new(owner: owner, service: service, viewer: viewer) }
    allow(Lich::WebUI).to receive(:callback_queue) { |owner:| proc { |&work| service.runtime.dispatch(owner: owner, &work) } }
    @logs = []
    allow(Lich).to receive(:log) { |message| @logs << message }
    allow(Lich).to receive(:db).and_return(db)
    allow(Lich).to receive(:db_mutex).and_return(Mutex.new)
    db.execute('CREATE TABLE uservars(scope TEXT PRIMARY KEY, hash BLOB)')
    vars = Lich::Common::Vars
    vars.class_variable_set(:@@vars, { 'kept' => 'before' })
    vars.class_variable_set(:@@md5, nil)
    vars.class_variable_set(:@@load_state, vars::LoadState::LOADED)
    vars.class_variable_set(:@@autosave_error, nil)
  end

  after do
    @native&.close
    Lich::Common::ScriptDeath.run(owner)
    service.stop
    @runner&.join(0.2)
    @runner&.kill&.join(1) if @runner&.alive?
    db.close
    $alias_setup_window = nil
  end

  def entry(name)
    record = fixture.fetch('scripts').fetch(name)
    expect(Digest::SHA256.hexdigest(record.fetch('source'))).to eq(record.fetch('sha256'))
    record
  end

  def drain
    2.times do
      done = Queue.new
      service.runtime.dispatch(owner: owner) { done << true }
      expect(done.pop(timeout: 4)).to be(true)
    end
    expect(@logs.grep(/callback failed|setup UI error/)).to be_empty, @logs.join("\n")
  end

  def await_page
    Timeout.timeout(5) do
      loop do
        drain
        @page = service.registry.pages_for(owner).first
        break if @page&.last_render
        @runner.value if @runner && !@runner.alive?
        sleep 0.005
      end
    end
  end

  def editor(name)
    record = entry(name)
    target = Module.new
    { Gtk: gtk, Gdk: scope::Gdk, Vars: Lich::Common::Vars,
      Char: double(name: 'Fixture'), XMLData: double(game: 'GS', name: 'Fixture') }.each { |key, value| target.const_set(key, value) }
    target.module_eval("def self.run(db, update_regex, service_owner)\n#{record.fetch('source')}\nend", "#{name}.lic", record.fetch('line') - 1)
    target.define_singleton_method(:wait_until) do |&condition|
      Timeout.timeout(5) { sleep 0.005 until condition.call }
    end
    target.define_singleton_method(:report_errors) { |&work| work.call }
    target.define_singleton_method(:echo) { |_| }
    target.define_singleton_method(:respond) { |_| }
    if name == 'alias'
      db.execute('CREATE TABLE gs_fixture(trigger TEXT PRIMARY KEY, target TEXT)')
      db.execute('CREATE TABLE global(trigger TEXT PRIMARY KEY, target TEXT)')
      db.execute("INSERT INTO gs_fixture VALUES('kept', 'before')")
      @runner = target.run(db, proc {}, owner)
    else
      @runner = Thread.new { target.run(db, proc {}, owner) }
    end
    await_page
    @window = gtk.session.instance_variable_get(:@windows).find { |window| !window.destroyed? }
  end

  def descendants(widget = @window)
    [widget] + widget.children.flat_map { |child| descendants(child) }
  end

  def in_viewer(&work)
    unless @viewer
      connection = double('viewer', viewer_id: 'activation-fixture', alive?: true, send_text: nil)
      address = service.registry.address_for(@page)
      service.runtime.handle(connection, type: 'attach', page: address)
      @viewer = service.runtime.instance_variable_get(:@viewers).fetch(connection_id: 'activation-fixture', address: address).viewer_id
    end
    gtk.session.send(:with_callback_context, @viewer, @window, &work)
  end

  def finish_editor(action)
    in_viewer do
      gtk.queue do
        if action == :close
          @window.send(:emit_handlers, :close)
        else
          label = action == :save ? 'Save & Close' : 'Cancel'
          descendants.find { |widget| widget.is_a?(gtk::Button) && widget.label == label }.send(:emit_handlers, :activate)
        end
      end
    end
    drain
    expect(@runner.join(5)).to equal(@runner)
    @runner.value
    drain
    expect(@window).to be_destroyed
    expect(service.registry.pages_for(owner)).to be_empty
  end

  %w[vars alias].each do |name|
    { save: true, cancel: false, close: false, unchanged: false }.each do |action, edited_save|
      it "runs #{name} prepared #{action} with finite completion and retained data [#{name == 'vars' ? 'version 1.2.0, author Tillmen; maintained by Elanthia-Online' : 'version 1.0.5, author elanthia-online; contributor Tillmen'}]" do
        editor(name)
        textbox = descendants.find { |widget| widget.is_a?(gtk::Entry) && widget.text == 'before' }
        expect(textbox).not_to be_nil
        in_viewer { textbox.text = 'after' } unless action == :unchanged
        finish_editor(action == :unchanged ? :close : action)
        expected = edited_save ? 'after' : 'before'
        if name == 'vars'
          expect(Lich::Common::Vars['kept']).to eq(expected)
          # The script changes Vars; its ordinary provider owns persistence.
          Lich::Common::Vars.save
          blob = db.get_first_value('SELECT hash FROM uservars WHERE scope=?', ["#{XMLData.game}:#{XMLData.name}"])
          expect(Marshal.load(blob)).to eq('kept' => expected)
        else
          expect(db.get_first_value("SELECT target FROM gs_fixture WHERE trigger='kept'")).to eq(expected)
          expect($alias_setup_window).to be_nil
          expect(owner.thread_group.list).to include(@runner) if @runner.alive?
        end
      end
    end
  end

  def components(page)
    visit = lambda { |node| [node] + node.children.flat_map { |child| visit.call(child) } }
    visit.call(page.last_render.tree)
  end

  it 'renders native Map 2.1.4 markers and Find editor and cleans up (author elanthia-online)' do
    record = entry('map')
    sandbox = Module.new
    sandbox.module_eval(record.fetch('source') + "end\n", 'map.lic', record.fetch('line'))
    room = Struct.new(:id, :image, :image_coords, :tags, :location).new(1, 'fixture.png', [0, 0, 1, 1], ['test-tag'], 'test-location')
    rooms = double(list: [room], current: room)
    allow(rooms).to receive(:[]).with('1').and_return(room)
    settings = {}
    settings.define_singleton_method(:save) {}
    Dir.mktmpdir('activation-map') do |directory|
      File.binwrite(File.join(directory, 'fixture.png'), Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aB9sAAAAASUVORK5CYII='))
      @native = sandbox::ElanthiaMap::NativeMap.new(owner: owner, map_dir: directory, rooms: rooms, settings: settings,
                                                    char_settings: {}, notes_path: File.join(directory, 'notes.json'), output: proc { |_| }, travel: proc { |_| })
      @native.show
      @native.instance_variable_set(:@active_tag, 'test-tag')
      @native.instance_variable_set(:@active_location, 'test-location')
      layers = @native.send(:layers)
      expect(layers.count { |layer| layer[:kind] == :marker }).to be >= 3
      expect(components(@native.page).map(&:type)).to include(:composite)
      find = @native.send(:open_find)
      input = components(find).find { |node| node.type == :text_input }
      submit = components(find).find { |node| node.type == :button }
      find.last_render.bindings.fetch([submit.cid, :activate]).call(double(submission: { input.cid => '1' }))
      expect(@native.page.title).to include('#1')
      expect(service.registry.pages_for(owner)).not_to include(find)
      @native.close
      expect(service.registry.pages_for(owner)).to be_empty
    end
  end

  it 'resolves the original Jinx 0.8.1 gui command to its native Browser (author elanthia-online)' do
    record = entry('jinx')
    jinx = Module.new
    stub_const('Lich::Common::Jinx', jinx)
    log = Module.new
    log.define_singleton_method(:observe_native_gui) { |_| :listener }
    log.define_singleton_method(:stop_observing_native_gui) { |_| }
    jinx.const_set(:Log, log)
    options = OpenStruct.new(gui: true)
    jinx.const_set(:Opts, double(parse: options))
    Object.module_eval(record.fetch('source'), 'jinx.lic', record.fetch('line'))
    service_record = record.fetch('service')
    expect(Digest::SHA256.hexdigest(service_record.fetch('source'))).to eq(service_record.fetch('sha256'))
    Object.module_eval(service_record.fetch('source'), 'jinx.lic', service_record.fetch('line'))
    jinx.const_set(:Script, double(current: owner))
    jinx.const_set(:Repo, double('offline catalog'))
    jinx.const_set(:CLI, double('offline actions'))
    jinx.const_set(:Folder, double('offline folders'))
    allow_any_instance_of(jinx::GUI::Browser).to(receive(:show).and_wrap_original { |original| original.call(load: false) })
    @runner = Thread.new { jinx::Service.main(['gui']) }
    await_page
    expect(components(@page).find { |node| node.type == :tabs }.props[:names]).to eq(%w[Log Repos Scripts Data])
    @page.lifecycle_bindings.fetch(:close).call
    expect(@runner.join(5)).to equal(@runner)
    @runner.value
    expect(service.registry.pages_for(owner)).to be_empty
  end
end
