# frozen_string_literal: true

require 'timeout'
require_relative '../../../spec_helper'
require 'webui'
require 'common/script_scope'
require 'common/script_scope/gtk/boot'

# Slice five's long tail: Paned, Overlay, ProgressBar, ListBox and custom
# Dialog, plus the Stock labels a dialog's OK button names. Each used to
# fall through Gtk.const_missing into an empty box.
RSpec.describe 'GTK compatibility shim: slice five widgets' do
  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('slice5') }
  let(:service) { Lich::WebUI::Service.new }
  let(:session) { gtk::Session.new(owner, service: service) }
  let(:validator) { Lich::WebUI::Validator.new }

  before do
    gtk::Session.browser_open = proc { |_url, on_start:, **| on_start.call(1); true }
    allow(gtk::Session).to receive(:for).with(anything).and_return(session)
  end

  after do
    gtk::Session.browser_open = nil
    session.shutdown
    service.stop
  end

  def props_of(type, &build)
    node = nil
    session.sync do
      window = gtk::Window.new('Slice5')
      window.set_default_size(600, 400)
      window.add(build.call)
      window.show_all
      node = build.call
    end
    session.commit
    page = service.registry.pages_for(owner).fetch(0)
    found = nil
    page.last_render.tree.each { |component| found = component if component.type == type }
    found
  end

  it 'gives every slice-five class a real implementation, not a stub' do
    %i[Paned HPaned VPaned Overlay ListBox ListBoxRow ProgressBar].each do |name|
      expect(gtk.const_get(name)).not_to respond_to(:webui_stub?)
    end
  end

  describe 'ProgressBar' do
    # Real GTK (3.24.52, checked): `text =` alone leaves show-text false and
    # the text does not render. The shim's guard was tautological, so the
    # label went out either way and a bar whose text a script had switched
    # off still showed it. creaturebar's calibrator drives this from a "Text"
    # checkbox, so it is a live difference rather than a theoretical one.
    it 'renders a progress node with a fraction and label' do
      bar = session.sync do
        b = gtk::ProgressBar.new
        b.fraction = 0.4
        b.text = 'Spirit Warding I'
        b.show_text = true
        b
      end
      props = bar.send(:node_props)

      expect(props).to include(value: 0.4, label: 'Spirit Warding I')
      expect { validator.validate_component!(:progress, props, owner: 's', page_id: 'p', cid: 'c') }.not_to raise_error
    end

    it 'withholds the label until show_text asks for it, as GTK does' do
      bar = session.sync { b = gtk::ProgressBar.new; b.fraction = 0.4; b.text = 'hidden'; b }

      expect(bar.send(:node_props)).to include(value: 0.4)
      expect(bar.send(:node_props)).not_to have_key(:label)
    end

    it 'reports a pulse as indeterminate, and a later fraction ends it' do
      bar = session.sync { gtk::ProgressBar.new }
      session.sync { bar.pulse }
      expect(bar.send(:node_props)).to include(indeterminate: true)

      session.sync { bar.fraction = 0.5 }
      expect(bar.send(:node_props)).not_to include(:indeterminate)
    end
  end

  describe 'Paned' do
    it 'renders as a split with its panes in slot order' do
      component = props_of(:split) do
        paned = gtk::Paned.new(:horizontal)
        paned.add1(gtk::Label.new('left'))
        paned.add2(gtk::Label.new('right'))
        paned
      end

      expect(component.props[:orientation]).to eq('horizontal')
      expect(component.children.map(&:slot)).to eq(%w[first second])
      expect { validator.validate_component!(:split, component.props, owner: 's', page_id: 'p', cid: 'c') }.not_to raise_error
    end

    # The adapter assigns named slots by INDEX, so sorting by intended slot
    # was not enough: a paned holding only add2's child gave that child the
    # `first` slot, and the browser's split renderer put it on the wrong side.
    it 'keeps the second pane in its own slot when the first is absent' do
      component = props_of(:split) do
        paned = gtk::Paned.new(:horizontal)
        paned.add2(gtk::Label.new('right only'))
        paned
      end

      expect(component.children.map(&:slot)).to eq(%w[first second])
      expect(component.children.last.props[:content]).to eq('right only')
    end

    it 'keeps the second pane in its own slot when the first is hidden' do
      component = props_of(:split) do
        paned = gtk::Paned.new(:horizontal)
        hidden = gtk::Label.new('left')
        paned.add1(hidden)
        paned.add2(gtk::Label.new('right'))
        hidden.visible = false
        paned
      end

      expect(component.children.map(&:slot)).to eq(%w[first second])
      expect(component.children.last.props[:content]).to eq('right')
    end

    it 'converts a pixel position to a percent of the window axis' do
      paned = session.sync do
        window = gtk::Window.new('P'); window.set_default_size(400, 300)
        p = gtk::Paned.new(:horizontal); window.add(p); window.show_all
        p.position = 100
        p
      end

      # 100 of a 400px window is a quarter.
      expect(paned.send(:node_props)[:position]).to eq(25)
    end

    # Re-adding a child to the slot it already holds skipped the eviction
    # but still ran Container#add, so the child was listed twice.
    it 'lists a child once when it is added to its own slot again' do
      paned = gtk::Paned.new(:horizontal)
      child = gtk::Label.new('left')

      paned.add1(child)
      paned.add1(child)

      expect(paned.render_children).to eq([child])
      expect(paned.children).to eq([child])
    end

    # position= hand-wrote changed! plus session.viewer_write, the exact
    # pair Widget#viewer_push exists so nobody writes by hand.
    it 'pushes its position through the shared viewer push' do
      paned = session.sync do
        window = gtk::Window.new('P'); window.set_default_size(400, 300)
        p = gtk::Paned.new(:horizontal); window.add(p); window.show_all
        p
      end
      session.commit
      pushed = []
      paned.define_singleton_method(:viewer_push) { |name, value| pushed << [name, value] }

      session.sync { paned.position = 200 }

      expect(pushed).to eq([[:position, 50]])
    end
  end

  describe 'Overlay' do
    it 'renders the base and its overlays as one overlay node' do
      component = props_of(:overlay) do
        overlay = gtk::Overlay.new
        overlay.add(gtk::Label.new('base'))
        overlay.add_overlay(gtk::Label.new('on top'))
        overlay
      end

      expect(component.children.length).to eq(2)
      expect { validator.validate_component!(:overlay, component.props, owner: 's', page_id: 'p', cid: 'c') }.not_to raise_error
    end
  end

  describe 'ListBox' do
    it 'renders as a stack of group rows' do
      component = props_of(:stack) do
        list = gtk::ListBox.new
        list.selection_mode = :single
        2.times { |i| row = gtk::ListBoxRow.new; row.add(gtk::Label.new("row #{i}")); list.add(row) }
        list
      end

      expect(component.children.map(&:type)).to eq(%i[group group])
    end

    # Selection is kept so a script can read it back, but the contract has
    # no list type and the browser never shows it. Quietly maintaining
    # state the script may act on is the silent degradation the shim's
    # ledger exists to report.
    it 'keeps a selection locally and reports it as unsupported, once' do
      gtk.reset_unsupported!
      list = gtk::ListBox.new
      row = gtk::ListBoxRow.new
      list.add(row)

      list.select_row(row)
      list.select_row(row)

      expect(list.selected_row).to equal(row)
      entries = gtk.unsupported_report.values.reduce({}, :merge)
      select = entries.find { |api, _entry| api.end_with?('ListBox#select_row') }&.last
      expect(select).to include(count: 2, note: a_string_matching(/not shown in the browser/))
      expect(entries.keys.join).to include('ListBox#selected_row')
    ensure
      gtk.reset_unsupported!
    end

    # The guard was parent.respond_to?(:children), which every shim widget
    # answers true to, so a row under a non-container asked a Label for
    # its children instead of answering -1.
    it 'answers -1 for a row whose parent is not a container' do
      row = gtk::ListBoxRow.new
      row.attach_to(gtk::Label.new('not a list'))

      expect(row.index).to eq(-1)
      expect(gtk::ListBoxRow.new.index).to eq(-1)
    end

    it 'answers its position under a list' do
      list = gtk::ListBox.new
      first = gtk::ListBoxRow.new
      second = gtk::ListBoxRow.new
      list.add(first)
      list.add(second)

      expect(second.index).to eq(1)
    end
  end
end
