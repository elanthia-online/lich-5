# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'webui'
require 'common/script_scope'
require 'common/script_scope/gtk/boot'

# ewaggle sets up drag-and-drop between its two spell lists before it
# connects anything else, and every part of that setup went through
# Gtk.const_missing. Two of them raised rather than degraded, so the window
# died mid-build and took the rest of the script's wiring with it --
# including the double-click handler that moves a spell without dragging.
RSpec.describe 'GTK compatibility shim: drag-and-drop vocabulary' do
  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:gdk) { Lich::Common::ScriptScope::Gdk }
  let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('ewaggle') }
  let(:service) { Lich::WebUI::Service.new }
  let(:session) { gtk::Session.new(owner, service: service) }

  before do
    gtk::Session.browser_open = proc { |_url, geometry:, on_start:, on_exit:| [geometry, on_exit]; on_start.call(1); true }
    gtk::Session.browser_kill = proc { |_pid| nil }
    allow(gtk::Session).to receive(:for).with(anything).and_return(session)
  end

  after do
    gtk::Session.browser_open = nil
    gtk::Session.browser_kill = nil
    session.shutdown
    service.stop
  end

  describe 'a flags namespace the shim does not implement' do
    # A CamelCase name was always stubbed as a widget CLASS, and a class has
    # no fallback for its own missing constants, so reading a member raised
    # NameError instead of degrading.
    it 'answers a member as a symbol instead of raising' do
      expect(gtk::TargetFlags::SAME_APP).to eq(:same_app)
    end

    it 'degrades every flags-shaped namespace the same way' do
      expect(gtk::DestDefaults::ALL).to eq(:all)
      expect(gtk::SomethingMask::FIRST).to eq(:first)
    end

    # The heuristic must not swallow the namespaces the shim really defines.
    it 'leaves the shim\'s own enums alone' do
      expect(gtk::SortType::ASCENDING).to eq(:ascending)
      expect(gtk::Stock::OK).to eq('OK')
      expect(gtk::PolicyType::NEVER).to eq(:never)
    end

    it 'still stubs an unknown widget as a container, not a namespace' do
      expect(gtk::Frobnicator.new).to be_a(gtk::Container)
    end

    # The tell for "class" was a lowercase SECOND letter, so GTK's
    # acronym-led class names -- UIManager, IMContext -- matched neither
    # branch and fell through to the enum-member fallback as a bare symbol.
    # `Gtk::UIManager.new` then raised NoMethodError on Symbol, which is the
    # same uncaught crash this path exists to prevent. Nothing in the census
    # names one today; the guarantee is supposed to be unconditional.
    it 'stubs an acronym-led class name as a widget rather than a symbol' do
      expect(gtk::UIManager.new).to be_a(gtk::Container)
      expect(gtk::IMContext.new).to be_a(gtk::Container)
    end

    # An enum MEMBER is what the symbol fallback is for, and those are all
    # caps -- read either through a flags namespace or straight off Gtk.
    it 'still answers an all-caps name as a member symbol' do
      expect(gtk::SomeOtherFlags::SCREAMING_MEMBER).to eq(:screaming_member)
      expect(gtk::WIDGET_UNKNOWN_MEMBER).to eq(:widget_unknown_member)
    end
  end

  describe 'a stubbed widget built with constructor arguments' do
    # GTK constructors take arguments; the stub's took none, so building one
    # raised ArgumentError rather than degrading to an empty box.
    it 'accepts them rather than raising' do
      entry = nil
      expect { entry = gtk::TargetEntry.new('STRING', gtk::TargetFlags::SAME_APP, 0) }.not_to raise_error
      expect(entry.stub_args).to eq(['STRING', :same_app, 0])
    end

    it 'accepts keyword arguments too' do
      expect { gtk::Frobnicator.new('a', size: 2) }.not_to raise_error
    end
  end

  # The whole point: ewaggle's setup runs unguarded, so anything that raises
  # takes the handlers registered after it with it.
  describe "ewaggle's list setup" do
    it 'builds the window and still connects the double-click move' do
      moved = []
      view = nil
      expect do
        session.sync do
          window = gtk::Window.new('ewaggle')
          window.set_default_size(400, 300)
          store = gtk::ListStore.new(String)
          ['101 Spirit Warding', '102 Spirit Barrier'].each { |value| store.append.set_value(0, value) }
          view = gtk::TreeView.new(store)
          # Exactly the order ewaggle uses, with no rescue around it.
          view.enable_model_drag_source(
            gdk::ModifierType::BUTTON1_MASK,
            [gtk::TargetEntry.new('STRING', gtk::TargetFlags::SAME_APP, 0)], gdk::DragAction::MOVE
          )
          view.enable_model_drag_dest(
            [gtk::TargetEntry.new('STRING', gtk::TargetFlags::SAME_APP, 0)], gdk::DragAction::MOVE
          )
          view.signal_connect('drag-data-get') { |*_args| }
          view.signal_connect('drag-data-received') { |*_args| }
          # Registered AFTER the calls that used to raise.
          view.signal_connect('row-activated') do |widget, path, _column|
            iter = widget.model.get_iter(path)
            moved << iter[0] unless iter.nil?
          end
          window.add(view)
          window.show_all
        end
        session.commit
      end.not_to raise_error

      page = service.registry.pages_for(owner).first
      table = page.last_render.tree.each.find { |component| component.type == :table }
      expect(table).not_to be_nil

      session.sync do
        view.send(:receive_event, :row_activate, Struct.new(:payload).new({ row: table.props[:rows].first[:key] }))
      end

      expect(moved).to eq(['101 Spirit Warding'])
    end
  end
end
