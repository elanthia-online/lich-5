# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../support/webui_shim_bindings'
require_relative '../../../lib/common/script_scope'
require_relative '../../support/webui_browser'
require 'digest'
require 'json'
require 'timeout'

RSpec.describe 'HeaderBar and tpick titlebar acceptance' do
  include WebUISpecSupport::ShimBindings

  let(:scope) { Lich::Common::ScriptScope }
  let(:gtk) { scope.const_get(:Gtk, false) }
  let(:owner) { Struct.new(:name).new('tpick.lic') }
  let(:service) { Lich::WebUI::Service.new }
  let(:window) { gtk::Window.new('Titlebar fixture') }
  let(:header) { gtk::HeaderBar.new }

  before do
    install_webui_shim_bindings
    @diagnostics = []
    allow(Lich).to receive(:log) { |message| @diagnostics << message }
  end

  after do
    Lich::Common::ScriptDeath.run(owner)
    Lich::Common::ScriptDeath.run(@other_owner) if @other_owner
    service.stop
  end

  def drain
    2.times do
      barrier = Queue.new
      service.runtime.dispatch(owner: owner) { barrier << true }
      expect(barrier.pop(timeout: 3)).to be(true)
    end
    expect(@diagnostics.grep(/callback failed|refresh failed|operation=queue.*error=/)).to be_empty
  end

  def page_for(widget)
    page = nil
    Timeout.timeout(4) do
      sleep 0.005 until (page = service.registry.pages_for(owner).find { |p| p.title == widget.title })&.last_render
    end
    page
  end

  def original
    record = JSON.parse(File.read(File.expand_path('../../fixtures/webui/tpick-titlebar.json', __dir__)))
    Module.new.tap do |mod|
      mod.const_set(:Gtk, gtk)
      mod.const_set(:Char, Struct.new(:name).new('Fixture'))
      mod.const_set(:Stats, Struct.new(:prof).new('Warrior'))
      mod.const_set(:Spell, Hash.new(Struct.new(:known?).new(false)))
      record.fetch('methods').first(8).each do |method|
        expect(Digest::SHA256.hexdigest(method.fetch('source'))).to eq(method.fetch('sha256'))
        mod.module_eval(method.fetch('source'), 'tpick.lic', method.fetch('line'))
      end
      %w[windows grids entries buttons menus non_settings_menus check_boxes labels spin_buttons adjustments
         all_textviews all_buffers scrolled_windows all_notebooks needed_values window_assets].each do |name|
        mod.instance_variable_set("@#{name}", {})
      end
      %w[container_names other_names spell_names popping_names required_settings].each { |name| mod.instance_variable_set("@#{name}", []) }
      mod.instance_variable_set(:@all_characters, ['Fixture'])
      mod.instance_variable_set(:@script_version, '48')
    end
  end

  it 'populates an already visible empty notebook without replacing its handle' do
    notebook = gtk::Notebook.new
    window.add(notebook)
    window.show_all
    handle = notebook.materialize
    expect(notebook.session.port.get(handle, :names)).to eq([])
    first = gtk::Entry.new
    notebook.append_page(first, gtk::Label.new('First'))
    notebook.append_page(gtk::Label.new('Second page'), gtk::Label.new('Second'))
    expect(notebook.session.port.get(handle, :names)).to eq(%w[First Second])
    expect(notebook.materialize).to equal(handle)
    expect(notebook.children.first).to equal(first)
  end

  it 'rebases live signed Grid origins without replacing controls or losing spans' do
    grid = gtk::Grid.new
    entry = gtk::Entry.new
    entry.text = 'Retained value'
    grid.attach(entry, 0, 0, 2, 1)
    window.add(grid)
    window.show_all
    handle = entry.materialize
    left = gtk::Label.new('Before')
    grid.attach(left, -2, -1, 1, 1)
    expect(entry.instance_variable_get(:@placement)).to include(column: 3, row: 2, span: 2)
    expect(grid.session.port.get(grid.materialize, :cols)).to eq(4)
    expect(entry.materialize).to equal(handle)
    grid.remove(left)
    expect(entry.instance_variable_get(:@placement)).to include(column: 1, row: 1)
    grid.attach(left, -1, -2, 1, 2)
    left.destroy
    expect(entry.instance_variable_get(:@placement)).to include(column: 1, row: 1)
    expect(entry.text).to eq('Retained value')
    invalid = gtk::Label.new('Invalid')
    [[-25, 0, 1, 1], [0, -4097, 1, 1], [0, 0, 0, 1], [0, 0, 1, 1025], ['bad', 0, 1, 1]].each do |coordinates|
      expect { grid.attach(invalid, *coordinates) }.to raise_error(gtk::UnsupportedOperation)
      expect(invalid.parent).to be_nil
      expect(grid.children).to eq([entry])
    end
    expect { gtk::Table.new(1, 1).attach(invalid, 0, 1, -1, 0) }.to raise_error(gtk::UnsupportedOperation)
  end

  %i[adapter_attach refused_insert completed_insert].each do |failure|
    it "rolls back a live Grid after #{failure} fails and permits retry" do
      grid = gtk::Grid.new
      entry = gtk::Entry.new
      entry.text = 'Retained value'
      grid.attach(entry, 0, 0, 1, 1)
      grid.resize(4, 3)
      window.add(grid)
      window.show_all
      port = grid.session.port
      handle = entry.materialize
      candidate = gtk::Label.new('Retry me')
      placement = { column: 6, row: 3, span: 2, row_span: 1 }
      candidate.placement = placement
      candidate_handle = candidate.materialize
      nodes = port.instance_variable_get(:@nodes)
      before = nodes.fetch(handle).dup
      error = RuntimeError.new('injected attachment failure')
      case failure
      when :adapter_attach
        allow(port).to receive(:attach).with(grid.materialize, candidate_handle, 1).and_raise(error)
      when :refused_insert
        allow(grid).to receive(:insert_child).and_raise(error)
      when :completed_insert
        allow(grid).to receive(:insert_child).and_wrap_original do |method, *args|
          method.call(*args)
          raise error
        end
      end

      expect { grid.attach(candidate, -2, -1, 1, 1) }.to(raise_error { |raised| expect(raised).to equal(error) })
      expect(grid.children).to eq([entry])
      expect(candidate.parent).to be_nil
      expect(nodes.fetch(candidate_handle).parent).to be_nil
      expect(candidate.instance_variable_get(:@placement)).to eq(placement)
      expect(nodes.fetch(candidate_handle).placement).to eq(placement)
      expect(grid.n_rows).to eq(4)
      expect(port.get(grid.materialize, :cols)).to eq(3)
      expect(nodes.fetch(handle).placement).to eq(before.placement)
      expect(nodes.fetch(handle).bindings).to eq(before.bindings)
      expect(entry.materialize).to equal(handle)
      expect(entry.text).to eq('Retained value')
      expect(grid.instance_variable_get(:@grid_origins).keys).to eq([entry])
      allow(port).to receive(:attach).and_call_original
      allow(grid).to receive(:insert_child).and_call_original
      grid.attach(candidate, -1, 0, 1, 1)
      expect(grid.children).to eq([entry, candidate])
      expect(nodes.fetch(handle).placement).to include(column: 2, row: 1)
      expect(candidate.materialize).to equal(candidate_handle)
      grid.remove(candidate)
      expect(nodes.fetch(handle).placement).to include(column: 1, row: 1)
    end
  end

  it 'rolls back an unmaterialized Grid without allocating handles' do
    grid = gtk::Grid.new
    label = gtk::Label.new('Existing')
    candidate = gtk::Label.new('Rejected')
    grid.attach(label, 0, 0, 1, 1)
    allow(grid).to receive(:insert_child).and_raise(RuntimeError, 'refused insertion')
    expect { grid.attach(candidate, -1, -1, 1, 1) }.to raise_error(RuntimeError, 'refused insertion')
    expect(grid.children).to eq([label])
    expect(grid.instance_variable_get(:@grid_origins).keys).to eq([label])
    expect(label.instance_variable_get(:@placement)).to include(column: 1, row: 1)
    expect(candidate.instance_variable_get(:@placement)).to be_nil
    expect([grid, label, candidate].map { |widget| widget.instance_variable_get(:@handle) }).to eq([nil, nil, nil])
  end

  it 'keeps rollback within the placement-map bound for a full Grid' do
    grid = gtk::Grid.new
    Lich::WebUI::Contract::BOUNDS.fetch(:children).times { grid.add(gtk::Label.new('Existing')) }
    window.add(grid)
    window.show_all
    candidate = gtk::Label.new('Over capacity')
    port = grid.session.port
    allow(port).to receive(:attach).and_raise(RuntimeError, 'refused attachment')
    expect { grid.attach(candidate, -1, -1, 1, 1) }.to raise_error(RuntimeError, 'refused attachment')
    expect(candidate.parent).to be_nil
    expect(candidate.instance_variable_get(:@placement)).to be_nil
    expect(grid.instance_variable_get(:@grid_origins)).to be_empty
    allow(port).to receive(:attach).and_call_original
    grid.remove(grid.children.last)
    expect { grid.attach(candidate, 0, 0, 1, 1) }.not_to raise_error
    expect(candidate.parent).to equal(grid)
  end

  it 'keeps header and content distinct, preserving page and content handles during replacement' do
    content = gtk::Entry.new
    window.add(content)
    window.set_border_width(12)
    window.show_all
    page_handle = window.materialize
    content_handle = content.materialize
    window.set_titlebar(header)
    window.show_all
    expect(window.children).to eq([header, content])
    expect(header.send(:component_props)[:margin]).to be_nil
    expect(content.send(:component_props)[:margin]).to eq(12)
    replacement = gtk::HeaderBar.new
    window.set_titlebar(replacement)
    expect(header.parent).to be_nil
    expect(header).not_to be_destroyed
    expect(window.children).to eq([replacement, content])
    window.set_titlebar(nil)
    expect(replacement.parent).to be_nil
    expect(window.children).to eq([content])
    expect(window.materialize).to equal(page_handle)
    expect(content.materialize).to equal(content_handle)
  end

  it 'retains custom title identity, callbacks and start/end action order' do
    title = gtk::Label.new('Custom title')
    first, last, earlier = %w[First Last Earlier].map { |text| gtk::Button.new(text) }
    header.title = 'Fallback title'
    header.set_custom_title(title)
    header.pack_start(first)
    header.pack_end(last)
    header.pack_end(earlier)
    window.set_titlebar(header)
    window.show_all
    expect(header.children[0].children).to eq([first])
    expect(header.children[1].children).to eq([title])
    expect(header.children[2].children).to eq([earlier, last])
    handle = title.materialize
    header.set_custom_title(nil)
    expect(title.parent).to be_nil
    expect(title.materialize).to equal(handle)
    expect(header.children[1].children.first.text).to eq('Fallback title')
    header.set_custom_title(title)
    expect(header.custom_title).to equal(title)
    expect(title.toplevel).to equal(window)
    header.remove(first)
    expect(first.parent).to be_nil
    title.destroy
    expect(header.custom_title).to be_nil
    header.set_custom_title(nil)
    expect(header.children[1].children.first.text).to eq('Fallback title')
  end

  it 'rejects foreign, parented, destroyed and cyclic title widgets without losing the old title' do
    window.set_titlebar(header)
    title = gtk::Label.new('Current')
    header.set_custom_title(title)
    parented = gtk::Label.new('Parented')
    gtk::Box.new.add(parented)
    dead = gtk::Label.new('Dead')
    dead.destroy
    [window, parented, dead, 'invalid', false].each do |candidate|
      expect { header.set_custom_title(candidate) }.to raise_error(gtk::UnsupportedOperation)
      expect(header.custom_title).to equal(title)
    end
    @other_owner = Struct.new(:name).new('other.lic')
    allow(Lich::Common::Script).to receive(:current).and_return(@other_owner)
    foreign = gtk::HeaderBar.new
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    expect { window.set_titlebar(foreign) }.to raise_error(gtk::UnsupportedOperation)
    expect { header.set_custom_title(foreign) }.to raise_error(gtk::UnsupportedOperation)
    expect(window.titlebar).to equal(header)
    expect(window.children).to eq([header])
    expect { window.set_titlebar(false) }.to raise_error(gtk::UnsupportedOperation)
    window.show_all
    invalid = gtk::Label.new('Invalid dimensions')
    invalid.set_width_request(Lich::WebUI::Contract::BOUNDS[:geometry].end + 1)
    expect { header.set_custom_title(invalid) }.to raise_error(Lich::WebUI::Error)
    expect(header.custom_title).to equal(title)
    expect(title.parent).to equal(header.children[1])
  end

  it 'detaches a removed or destroyed titlebar and cleans up the active header with its window' do
    window.set_titlebar(header)
    window.remove(header)
    expect(window.titlebar).to be_nil
    window.set_titlebar(header)
    header.destroy
    expect(window.titlebar).to be_nil
    active = gtk::HeaderBar.new
    title = gtk::Label.new('Owned')
    active.set_custom_title(title)
    window.set_titlebar(active)
    window.show_all
    window.destroy
    expect(active).to be_destroyed
    expect(title).to be_destroyed
    expect { window.set_titlebar(nil) }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'keeps the close flag through show_all and refuses unimplemented header behavior' do
    window.set_titlebar(header)
    window.show_all
    expect(header.children.last).not_to be_visible
    header.show_close_button = true
    window.show_all
    expect(header.children.last).to be_visible
    header.show_close_button = false
    window.show_all
    expect(header.children.last).not_to be_visible
    expect { header.show_close_button = :yes }.to raise_error(gtk::UnsupportedOperation)
    expect { header.instance_eval('set_decoration_layout("menu:minimize")', 'header.lic', 12) }
      .to raise_error(gtk::UnsupportedOperation, /operation=set_decoration_layout source=header.lic:12/)
  end

  it 'honors close vetoes and makes repeated close after destruction inert' do
    calls = []
    veto = true
    window.signal_connect('delete-event') { calls << :delete; veto }
    window.signal_connect('destroy') { calls << :destroy; window.close }
    window.set_titlebar(header)
    window.show_all
    window.close
    drain
    expect(window).not_to be_destroyed
    veto = false
    window.close
    drain
    window.close
    drain
    expect(calls).to eq(%i[delete delete destroy])
    expect(service.registry.pages_for(owner)).to be_empty
  end

  it 'runs the original tpick welcome setup and its original destroy handler' do
    tpick = original
    Dir.mktmpdir do |directory|
      tpick.instance_variable_set(:@save_file, File.join(directory, 'missing.json'))
      tpick.create_welcome_window
      welcome = tpick.instance_variable_get(:@windows).fetch('Welcome')
      expect(welcome.titlebar.custom_title.text).to include('WELCOME TO TPICK')
      expect(tpick.instance_variable_get(:@all_buffers).fetch('Welcome').text).to include('Welcome to ;tpick!')
      expect(page_for(welcome).last_render).not_to be_nil
      welcome.close
      drain
      expect(tpick.instance_variable_get(:@windows)['Welcome']).to be_nil
      expect(welcome).to be_destroyed
    end
  end

  it 'runs both original information and settings header methods without rewriting their widgets' do
    tpick = original
    windows = tpick.instance_variable_get(:@windows)
    windows['Information'] = gtk::Window.new('Information')
    windows['Settings'] = gtk::Window.new('Settings')
    tpick.create_information_headerbar
    tpick.create_settings_headerbar
    expect(windows['Information'].titlebar.custom_title.text).to include('TPICK v48 - Fixture')
    expect(windows['Settings'].titlebar.custom_title.text).to include('TPICK SETTINGS v48 - Fixture')
    windows.each_value do |widget|
      widget.add(gtk::Label.new('Independent content'))
      widget.show_all
      expect(page_for(widget).last_render).not_to be_nil
    end
  end

  it 'constructs the original main-tab controls on their negative Grid row' do
    tpick = original
    tpick.instance_variable_get(:@grids)['Main Main'] = gtk::Grid.new
    tpick.create_main_tab
    expect(tpick.instance_variable_get(:@buttons).keys).to eq(%w[Save Load Defaults])
  end

  it 'renders header actions and preserves input and close vetoes in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'

    entry = gtk::Entry.new
    title = gtk::Label.new('Header actions')
    header.set_custom_title(title)
    header.show_close_button = true
    action = gtk::Button.new('Header action')
    action.signal_connect('clicked') { title.text = 'Header action worked' }
    header.pack_start(action)
    window.set_titlebar(header)
    window.add(entry)
    calls = []
    window.signal_connect('delete_event') do
      calls << entry.text
      title.text = 'Close vetoed' if calls.length == 1
      calls.length == 1
    end
    window.show_all
    WebUIBrowser.check(service: service, page: page_for(window), scenario: 'shim-headerbar')
    expect(calls).to eq(['Unsaved draft', 'Unsaved draft'])
    expect(window).to be_destroyed
    drain
  end

  it 'renders and closes the original tpick welcome window in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'

    tpick = original
    Dir.mktmpdir do |directory|
      tpick.instance_variable_set(:@save_file, File.join(directory, 'missing.json'))
      tpick.create_welcome_window
      welcome = tpick.instance_variable_get(:@windows).fetch('Welcome')
      WebUIBrowser.check(service: service, page: page_for(welcome), scenario: 'shim-tpick-welcome')
      expect(tpick.instance_variable_get(:@windows)['Welcome']).to be_nil
      expect(welcome).to be_destroyed
      drain
    end
  end
end
