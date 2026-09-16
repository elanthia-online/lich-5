# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'webui'
require 'common/script_scope'
require 'common/script_scope/gtk/boot'

RSpec.describe 'GTK compatibility shim (slice three: menus, markup, pointer)' do
  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('xnarost') }
  let(:service) { Lich::WebUI::Service.new }
  let(:session) { gtk::Session.new(owner, service: service) }
  let(:opened) { [] }

  before do
    gtk::Session.browser_open = proc { |url, geometry:, on_start:, on_exit:|
      opened << [url, geometry, on_exit]
      on_start.call(1)
      true
    }
    gtk::Session.browser_kill = proc { |_pid| nil }
    allow(gtk::Session).to receive(:for).with(anything).and_return(session)
  end

  after do
    gtk::Session.browser_open = nil
    gtk::Session.browser_kill = nil
    session.shutdown
  end

  def in_scope(&block)
    session.sync(&block)
  end

  def page
    session.adapter.page_for(@window.handle)
  end

  def tree
    page.last_render.tree
  end

  def component(key)
    tree.each.find { |candidate| candidate.props[:key] == key } || raise("no component with key #{key}")
  end

  def fire(key, event, payload: {})
    cid = component(key).cid
    callback = page.last_render.bindings[[cid, event]] || raise("no binding for #{cid}/#{event}")
    context = Lich::WebUI::Runtime::EventContext.new('attachment-spec', page, component(key), event, payload, nil)
    callback.call(context)
    session.sync {}
  end

  # An xnarost-shaped window: an event box holding a label, and a popup
  # menu with plain, check, separator, and a submenu of radio items.
  def build_menu_window
    in_scope do
      @window = gtk::Window.new('Map')
      @box = gtk::EventBox.new
      @label = gtk::Label.new
      @label.set_markup('<b>Town</b> <span color="#ff0000" size="12000">danger</span> &amp; ' \
                        '<a href="https://gswiki.play.net/x">https://gswiki.play.net/x</a>')
      @box.add(@label)
      @window.add(@box)

      @menu = gtk::Menu.new
      @find = gtk::MenuItem.new(label: 'find room')
      @follow = gtk::CheckMenuItem.new('follow current room')
      @scale = gtk::MenuItem.new('scale')
      @scale.submenu = gtk::Menu.new
      @half = gtk::RadioMenuItem.new(nil, '50 %')
      @full = gtk::RadioMenuItem.new(@half, '100 %')
      @scale.submenu.append(@half)
      @scale.submenu.append(@full)
      [@find, @follow, gtk::SeparatorMenuItem.new, @scale].each { |item| @menu.append(item) }

      @fired = []
      @find.signal_connect('activate') { @fired << :find }
      @follow.signal_connect('toggled') { @fired << [:follow, @follow.active?] }
      @full.signal_connect('toggled') { |item| @fired << [:full, item.active?] }
      @box.add_events(:button_press_mask)
      @box.signal_connect('button_press_event') do |_owner, event|
        @fired << [:press, event.button, event.x, event.state.control_mask?]
        @menu.popup(nil, nil, event.button, event.time) if event.button == 3
        true
      end
      @window.show_all
    end
    session.show_window(@window)
  end

  describe 'Label markup' do
    before { build_menu_window }

    it 'passes the Pango subset through and keeps a plain fallback with links as targets' do
      label = component(@label.key)
      expect(label.props[:content]).to eq('Town danger & https://gswiki.play.net/x')
      expect(label.props[:markup]).to eq('<b>Town</b> <span color="#ff0000" size="12000">danger</span> &amp; https://gswiki.play.net/x')
      expect(label.props[:wrap]).to be(false)
    end

    it 'drops markup the contract refuses and renders the plain text instead' do
      in_scope { @label.set_markup('<script>alert(1)</script>plain') }
      session.sync {}

      expect(component(@label.key).props).not_to include(:markup)
      expect(component(@label.key).props[:content]).to eq('alert(1)plain')
    end
  end

  describe 'popup menus' do
    before { build_menu_window }

    it 'is not on the page until popped up from a button-press handler' do
      expect(tree.each.none? { |candidate| candidate.type == :menu }).to be(true)

      fire(@box.key, :press, payload: { button: 'secondary', x: 3, y: 4, modifiers: ['ctrl'] })

      expect(@fired).to eq([[:press, 3, 3.0, true]])
      menu = component(@menu.key)
      expect(menu.type).to eq(:menu)
      expect(menu.props).to include(bar: false, open: true)
      items = menu.children.map { |item| item.props.slice(:label, :kind, :active) }
      expect(items).to eq([
                            { label: 'find room', kind: 'normal', active: false },
                            { label: 'follow current room', kind: 'check', active: false },
                            { kind: 'separator', active: false },
                            { label: 'scale', kind: 'normal', active: false },
                          ])
      radios = menu.children.last.children.first.children
      expect(radios.map { |item| item.props.slice(:kind, :active, :group) })
        .to eq([{ kind: 'radio', active: true, group: @half.key }, { kind: 'radio', active: false, group: @half.key }])
    end

    it 'runs activate and toggled handlers from item events and closes on dismissal' do
      fire(@box.key, :press, payload: { button: 'secondary', x: 0, y: 0, modifiers: [] })
      fire(@find.key, :activate)
      fire(@follow.key, :change, payload: { value: true })
      fire(@full.key, :change, payload: { value: true })
      fire(@menu.key, :close)

      expect(@fired.drop(1)).to eq([:find, [:follow, true], [:full, true]])
      expect(@follow.active?).to be(true)
      expect(@half.active?).to be(false)
      expect(@full.active?).to be(true)
      expect(@menu.open?).to be(false)
      expect(component(@menu.key).props[:open]).to be(false)
    end

    it 'deactivates the rest of a radio group from a script write' do
      fire(@box.key, :press, payload: { button: 'secondary', x: 0, y: 0, modifiers: [] })
      in_scope { @full.active = true }
      session.sync {}

      expect(@half.active?).to be(false)
      expect(component(@half.key).props[:active]).to be(false)
      expect(component(@full.key).props[:active]).to be(true)
    end
  end

  describe 'Gtk::MenuBar' do
    it 'renders as a bar with its items in place' do
      in_scope do
        @window = gtk::Window.new('Bar')
        bar = gtk::MenuBar.new
        file = gtk::MenuItem.new('_File')
        file.submenu = gtk::Menu.new
        file.submenu.append(gtk::MenuItem.new('Quit'))
        bar.append(file)
        @window.add(bar)
        @window.show_all
      end
      session.show_window(@window)

      bar = tree.children.first
      expect(bar.type).to eq(:menu)
      expect(bar.props).to include(bar: true, open: false)
      expect(bar.children.first.props[:label]).to eq('File')
      expect(bar.children.first.children.first.children.first.props[:label]).to eq('Quit')
    end
  end

  # Checked against real gtk3 3.24.52 with set_text_with_mnemonic, not
  # assumed: with mnemonics on -- Gtk::MenuItem.new's own default -- GTK
  # strips every single underscore, and renders a doubled one as a literal.
  describe 'a label carrying mnemonics' do
    def resolved(label)
      Lich::Common::ScriptScope::Gtk::MenuItem.new(label: label).label
    end

    it 'strips the underscore that marks the accelerator' do
      expect(resolved('E_xit')).to eq('Exit')
      expect(resolved('_Save & Close')).to eq('Save & Close')
    end

    # GTK does the same to these. A review read it as mangling; matching
    # GTK is the job, and diverging to "protect" the label would be the bug.
    it 'strips later underscores too, exactly as GTK does' do
      expect(resolved('snake_case_name')).to eq('snakecasename')
      expect(resolved('lootsack_2')).to eq('lootsack2')
    end

    # The one place the old blanket gsub was actually wrong.
    it 'renders a doubled underscore as one literal underscore' do
      expect(resolved('a__b')).to eq('a_b')
    end
  end
end
