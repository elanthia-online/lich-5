# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'webui'
require 'common/script_scope'
require 'common/script_scope/gtk/boot'

RSpec.describe 'GTK compatibility shim (slice four: box packing)' do
  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('bigshot') }
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
  end

  describe 'the packing arguments' do
    # GTK's signature is pack_start(child, expand = true, fill = true,
    # padding = 0); the positional form is the GTK 2 C API, where the flags
    # are integers and 0 means false -- though 0 is truthy in Ruby.
    {
      'a bare pack takes GTK\'s expanding default' => [[], {}, { expand: true, fill: true, padding: 0 }],
      'keyword flags'                              => [[], { expand: false, fill: false, padding: 0 }, { expand: false, fill: false, padding: 0 }],
      'keyword padding'                            => [[], { expand: false, fill: false, padding: 5 }, { expand: false, fill: false, padding: 5 }],
      'positional integers, 0 meaning false'       => [[0, 0, 1], {}, { expand: false, fill: false, padding: 1 }],
      'positional integers, 1 meaning true'        => [[1, 1, 0], {}, { expand: true, fill: true, padding: 0 }],
      'a single positional false'                  => [[false], {}, { expand: false, fill: true, padding: 0 }],
      'mixed positional booleans'                  => [[false, true, 0], {}, { expand: false, fill: true, padding: 0 }],
    }.each do |description, (positional, options, expected)|
      it "reads #{description}" do
        packed = session.sync do
          child = gtk::Label.new('x')
          gtk::Box.new(:horizontal).pack_start(child, *positional, **options)
          child.packing
        end

        expect(packed).to eq(expected)
      end
    end
  end

  describe 'a horizontal box' do
    it 'gives an expanding child the leftover width and the rest their natural width' do
      # The shape every settings row in these scripts has.
      props = session.sync do
        row = gtk::Box.new(:horizontal, 4)
        row.pack_start(gtk::Label.new('Resting Room ID:'), expand: false, fill: false, padding: 0)
        row.pack_start(gtk::Entry.new, expand: true, fill: true, padding: 0)
        row.pack_start(gtk::Button.new(label: 'Go'), expand: false, fill: false, padding: 0)
        row.node_props
      end

      expect(props).to include(count: 3, weights: [0, 1, 0])
    end

    it 'leaves the weights out when every child expands' do
      props = session.sync do
        row = gtk::Box.new(:horizontal)
        2.times { row.pack_start(gtk::Entry.new, expand: true, fill: true, padding: 0) }
        row.node_props
      end

      expect(props).not_to include(:weights)
    end

    it 'carries padding as a child placement' do
      placement = session.sync do
        row = gtk::Box.new(:horizontal)
        child = gtk::Button.new(label: 'Go')
        row.pack_start(child, expand: false, fill: false, padding: 3)
        row.render_children
        child.placement
      end

      expect(placement).to eq(pad: 3)
    end
  end

  describe 'a vertical box' do
    it 'marks an expanding child to grow and leaves the others their natural height' do
      fixed, grows = session.sync do
        column = gtk::Box.new(:vertical, 6)
        row = gtk::Label.new('header')
        notes = gtk::TextView.new
        column.pack_start(row, expand: false, fill: false, padding: 0)
        column.pack_start(notes, expand: true, fill: true, padding: 0)
        column.render_children
        [row.placement, notes.placement]
      end

      expect(fixed).to be_nil
      expect(grows).to eq(grow: 1)
    end
  end

  describe 'the rendered tree' do
    it 'reaches the contract with weights on the row and grow on the column' do
      window = session.sync do
        window = gtk::Window.new('Setup')
        column = gtk::Box.new(:vertical, 6)
        row = gtk::Box.new(:horizontal, 4)
        row.pack_start(gtk::Label.new('Resting Room ID:'), expand: false, fill: false, padding: 0)
        row.pack_start(gtk::Entry.new, expand: true, fill: true, padding: 0)
        column.pack_start(row, expand: false, fill: false, padding: 0)
        column.pack_start(gtk::TextView.new, expand: true, fill: true, padding: 0)
        window.add(column)
        window.show_all
        window
      end
      session.show_window(window)
      session.sync {}

      tree = session.adapter.page_for(window.handle).last_render.tree
      columns = tree.each.find { |node| node.type == :columns }
      textarea = tree.each.find { |node| node.type == :textarea }

      expect(columns.props[:weights]).to eq([0, 1])
      expect(textarea.placement).to eq(grow: 1)
    end
  end

  # Gtk::Misc#set_padding(xpad, ypad) pads both sides of each axis. Nine
  # scripts space wrapped labels with it; it used to reach method_missing
  # and be dropped. Alignment#set_padding names four edges and is a
  # different method that must keep its own arity.
  describe 'Gtk::Misc#set_padding' do
    it 'pads a label on both axes, the contract taking the larger side' do
      props = session.sync do
        label = gtk::Label.new('x')
        label.set_wrap(true).set_width_request(600).set_padding(0, 10)
        label.send(:common_props)
      end

      expect(props[:margin]).to eq(10)
    end

    it 'treats zero padding as no margin at all' do
      props = session.sync { gtk::Label.new('x').set_padding(0, 0).send(:common_props) }

      expect(props).not_to have_key(:margin)
    end

    it 'returns self so the scripts can chain off it' do
      label = session.sync { l = gtk::Label.new('x'); [l, l.set_padding(1, 2)] }

      expect(label.first).to be(label.last)
    end

    it "leaves Alignment's own four-edge set_padding in place" do
      props = session.sync do
        gtk::Alignment.new(0, 0, 0, 0).set_padding(50, 0, 0, 40).send(:common_props)
      end

      expect(props[:margin]).to eq(50)
    end
  end
end
