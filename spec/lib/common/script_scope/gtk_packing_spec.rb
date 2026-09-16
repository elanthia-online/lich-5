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
    it 'pads a label on both axes, each side keeping its own value' do
      props = session.sync do
        label = gtk::Label.new('x')
        label.set_wrap(true).set_width_request(600).set_padding(0, 10)
        label.send(:common_props)
      end

      expect(props[:margin]).to eq(top: 10, bottom: 10)
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

      expect(props[:margin]).to eq(top: 50, right: 40)
    end
  end

  # Scripts scroll by writing pixels to an Adjustment, but they derive the
  # number from an extent only the viewer knows -- `upper - page_size` is
  # scroll-to-bottom in vars, alias and localchat. The shim reported the
  # constructor defaults, so the arithmetic was nonsense and nothing reached
  # the browser either way.
  describe 'scroll adjustments' do
    def scroll_props(scrolled)
      scrolled.send(:node_props)
    end

    it 'says nothing about a scroll the script never touched' do
      props = session.sync { scroll_props(gtk::ScrolledWindow.new) }

      expect(props).not_to have_key(:scroll_position)
    end

    it 'reads a write at the extent as the bottom, not as a pixel offset' do
      props = session.sync do
        scrolled = gtk::ScrolledWindow.new
        adjustment = scrolled.vadjustment
        adjustment.value = adjustment.upper - adjustment.page_size
        scroll_props(scrolled)
      end

      expect(props[:scroll_position]).to eq(bottom: true)
    end

    it 'passes a mid-range offset through as pixels' do
      props = session.sync do
        scrolled = gtk::ScrolledWindow.new
        scrolled.vadjustment.note_viewport(upper: 2400.0, page_size: 400.0)
        scrolled.vadjustment.value = 300
        scroll_props(scrolled)
      end

      expect(props[:scroll_position]).to eq(y: 300)
    end

    it 'clamps a negative offset rather than emitting one the contract refuses' do
      props = session.sync do
        scrolled = gtk::ScrolledWindow.new
        scrolled.hadjustment.value = -40
        scroll_props(scrolled)
      end

      expect(props[:scroll_position]).to include(x: 0)
    end

    it 'takes the extent from the scrolled event so the scripts can do their arithmetic' do
      adjustment = session.sync do
        scrolled = gtk::ScrolledWindow.new
        context = Struct.new(:payload).new({ position: 1800, upper: 2400, page_size: 400 })
        scrolled.receive_event(:scrolled, context)
        scrolled.vadjustment
      end

      expect([adjustment.value, adjustment.upper, adjustment.page_size]).to eq([1800.0, 2400.0, 400.0])
    end

    it 'stops requesting a scroll once the viewer reports its own' do
      props = session.sync do
        scrolled = gtk::ScrolledWindow.new
        scrolled.vadjustment.value = 900
        context = Struct.new(:payload).new({ position: 120, upper: 2400, page_size: 400 })
        scrolled.receive_event(:scrolled, context)
        scroll_props(scrolled)
      end

      expect(props).not_to have_key(:scroll_position)
    end

    it 'binds scrolled whether or not the script connected a handler' do
      events = session.sync { gtk::ScrolledWindow.new.always_bound_events }

      expect(events).to include(:scrolled)
    end
  end

  # Window presentation properties were no-op stubs. They travel as the
  # `presentation` facility, which the runtime refuses per-property and
  # records as a degradation, and scripts read them back (creaturebar
  # persists `decorated?` to its config file).
  describe 'window presentation' do
    def shown_window(&setup)
      window = session.sync do
        win = gtk::Window.new('bar')
        setup&.call(win)
        win.add(gtk::Label.new('x'))
        win.show_all
        win
      end
      session.show_window(window)
      session.sync {}
      window
    end

    it "reports GTK's own defaults when the script has set nothing" do
      window = session.sync { gtk::Window.new('bar') }

      expect([window.decorated?, window.resizable?, window.keep_above?, window.opacity])
        .to eq([true, true, false, 1.0])
    end

    it 'declares no facility for a window nobody configured' do
      window = shown_window

      expect(session.adapter.page_for(window.handle).last_render.facilities).to eq({})
    end

    it 'carries keep_above, undecoration and opacity as the presentation facility' do
      window = shown_window do |win|
        win.set_keep_above(true)
        win.set_decorated(false)
        win.set_opacity(0.6)
      end

      expect(session.adapter.page_for(window.handle).last_render.facilities[:presentation])
        .to eq(always_on_top: true, borderless: true, opacity: 0.6)
    end

    # Window#presentation omits a property that is false and returns nil once
    # nothing is set, so a script turning keep-above off never arrives as a
    # value -- only as an absence. Applying what the facility contains would
    # therefore leave the window stuck topmost forever, which is exactly what
    # map's "Keep window on top" menu item does.
    it 'carries a toggled-off property to the window as an explicit default' do
      applied = []
      allow(Lich::WebUI::WindowPresentation).to receive(:available?).and_return(true)
      allow(Lich::WebUI::WindowPresentation).to receive(:apply) do |_hwnd, always_on_top:, opacity:, borderless: false|
        applied << [always_on_top, opacity, borderless]
        true
      end

      window = shown_window { |win| win.set_keep_above(true); win.set_opacity(0.5) }
      session.instance_variable_get(:@window_handles)[window] = Fiddle::Pointer.new(1234)

      session.sync { window.set_keep_above(false) }
      session.sync { window.set_opacity(1.0) }

      expect(applied.last).to eq([false, 1.0, false])
    end

    it 'records the properties a browser host cannot honor as degradations' do
      window = shown_window { |win| win.set_keep_above(true); win.set_decorated(false) }
      page = session.adapter.page_for(window.handle)

      # Both are degradations only where the host cannot reach the real
      # window; where it can, the shim raises and undecorates it directly.
      refused = page.degradations.map { |refusal| refusal[:property] }
      support = Lich::WebUI::WindowPresentation.support
      %i[always_on_top borderless].each do |property|
        if support[property]
          expect(refused).not_to include(property)
        else
          expect(refused).to include(property)
        end
      end
    end

    # creaturebar spells "hide the window" as set_opacity(0.0). The contract
    # floor is 0.1, so the facility clamps -- but the script still reads back
    # what it wrote, and the refusal is the honest answer.
    it 'clamps a zero opacity to the contract floor while reading back the write' do
      window = shown_window { |win| win.set_opacity(0.0) }

      expect(window.opacity).to eq(0.0)
      expect(session.adapter.page_for(window.handle).last_render.facilities[:presentation])
        .to eq(opacity: 0.1)
    end

    it 're-renders the page when only the presentation changed' do
      window = shown_window { |win| win.set_opacity(0.9) }
      before = session.adapter.page_for(window.handle).last_render.generation
      session.sync { window.set_opacity(0.3) }
      session.sync {}
      after = session.adapter.page_for(window.handle).last_render

      expect(after.generation).to be > before
      expect(after.facilities[:presentation]).to eq(opacity: 0.3)
    end

    it 'does not re-render when nothing about the presentation moved' do
      window = shown_window { |win| win.set_opacity(0.9) }
      before = session.adapter.page_for(window.handle).last_render.generation
      session.sync {}

      expect(session.adapter.page_for(window.handle).last_render.generation).to eq(before)
    end

    it 'keeps resizable readable without inventing a facility for it' do
      window = shown_window { |win| win.resizable = false }

      expect(window.resizable?).to be(false)
      expect(session.adapter.page_for(window.handle).last_render.facilities).to eq({})
    end
  end

  # A contract grid shared its width equally between every column, so a label
  # column was as wide as the entry beside it. GTK's own signal is narrower
  # than it looks: only 8 attach sites pass EXPAND, and they all name the
  # entry column, while every Alignment in the corpus is xscale 0.
  describe 'grid column weights' do
    it 'gives the free width to the column a table attached with EXPAND' do
      props = session.sync do
        table = gtk::Table.new(2, 2)
        table.attach(gtk::Label.new('Name:'), 0, 1, 0, 1, gtk::FILL, gtk::FILL, 3, 3)
        table.attach(gtk::Entry.new, 1, 2, 0, 1,
                     gtk::AttachOptions::EXPAND | gtk::AttachOptions::FILL, gtk::FILL, 3, 3)
        table.send(:node_props)
      end

      expect(props[:weights]).to eq([0, 1])
    end

    it 'says nothing when no column asked to expand, so the client keeps auto' do
      props = session.sync do
        table = gtk::Table.new(2, 2)
        table.attach(gtk::Label.new('a'), 0, 1, 0, 1)
        table.attach(gtk::Label.new('b'), 1, 2, 0, 1)
        table.send(:node_props)
      end

      expect(props).not_to have_key(:weights)
    end

    it 'ignores a FILL-only attach, which asks to fill its cell and not to grow' do
      props = session.sync do
        table = gtk::Table.new(2, 2)
        table.attach(gtk::Label.new('a'), 0, 1, 0, 1, gtk::FILL, gtk::FILL)
        table.attach(gtk::Entry.new, 1, 2, 0, 1, gtk::FILL, gtk::FILL)
        table.send(:node_props)
      end

      expect(props).not_to have_key(:weights)
    end

    # Gtk::Grid has no attach options: the child asks with hexpand, and it can
    # be set after attaching, so the weights are read at render time.
    it 'takes a Gtk::Grid column from a child hexpand set after the attach' do
      props = session.sync do
        grid = gtk::Grid.new
        entry = gtk::Entry.new
        grid.attach(gtk::Label.new('x'), 0, 0, 1, 1)
        grid.attach(entry, 1, 0, 1, 1)
        entry.hexpand = true
        grid.send(:node_props)
      end

      expect(props[:weights]).to eq([0, 1])
    end

    it 'renders the weights onto the grid node the client reads' do
      window = session.sync do
        win = gtk::Window.new('t')
        table = gtk::Table.new(2, 2)
        table.attach(gtk::Label.new('Name:'), 0, 1, 0, 1, gtk::FILL, gtk::FILL, 3, 3)
        table.attach(gtk::Entry.new, 1, 2, 0, 1,
                     gtk::AttachOptions::EXPAND | gtk::AttachOptions::FILL, gtk::FILL, 3, 3)
        win.add(table)
        win.show_all
        win
      end
      session.show_window(window)
      session.sync {}

      tree = session.adapter.page_for(window.handle).last_render.tree
      grid = tree.each.find { |component| component.type == :grid }

      expect(grid.props[:weights]).to eq([0, 1])
    end
  end

  # pack_end packs against the far edge, and GTK places the leftover width
  # between the two groups even when nothing expands. Without that the
  # children all clumped at the start, which is why vars.lic's labels came
  # out left aligned against the GTK original's right.
  describe 'pack_end placement' do
    it 'aligns a box whose only child is packed end against the far edge' do
      props = session.sync do
        box = gtk::Box.new(:horizontal)
        box.pack_end(gtk::Label.new('day_pass_sack'), expand: false, fill: false, padding: 0)
        box.send(:common_props)
      end

      expect(props[:align]).to eq('end')
    end

    it 'puts the free width between a start group and an end group' do
      props = session.sync do
        box = gtk::Box.new(:horizontal)
        box.pack_start(gtk::Label.new('L'), expand: false, fill: false, padding: 0)
        box.pack_end(gtk::Button.new('R'), expand: false, fill: false, padding: 0)
        box.send(:node_props)
      end

      expect(props[:weights]).to eq([0, 1])
    end

    it 'leaves a box packed only from the start alone' do
      common, node = session.sync do
        box = gtk::Box.new(:horizontal)
        box.pack_start(gtk::Label.new('L'), expand: false, fill: false, padding: 0)
        [box.send(:common_props), box.send(:node_props)]
      end

      expect(common).not_to have_key(:align)
      expect(node[:weights]).to eq([0])
    end

    it 'does not shrink an expanding end child to its content' do
      props = session.sync do
        box = gtk::Box.new(:horizontal)
        box.pack_end(gtk::Entry.new, expand: true, fill: true, padding: 0)
        box.send(:common_props)
      end

      expect(props).not_to have_key(:align)
    end

    it 'keeps an explicit halign over the inferred one' do
      props = session.sync do
        box = gtk::Box.new(:horizontal)
        box.halign = :center
        box.pack_end(gtk::Label.new('x'), expand: false, fill: false, padding: 0)
        box.send(:common_props)
      end

      expect(props[:align]).to eq('center')
    end
  end

  # map.lic walks Gdk::Display.default.default_screen to a monitor rectangle
  # and crashed on the missing constant. There is no X display behind a
  # browser, so the shim reports one monitor the size of the default screen.
  describe 'Gdk display geometry' do
    let(:gdk) { Lich::Common::ScriptScope::Gdk }

    it 'walks the display to a monitor rectangle the way map.lic does' do
      screen = gdk::Display.default.default_screen
      geometry = screen.get_monitor_geometry(screen.get_monitor_at_point(100, 50))

      expect([geometry.x, geometry.y, geometry.width, geometry.height]).to eq([0, 0, 1280, 800])
    end

    it 'still answers the width and height seven scripts read off the screen' do
      expect([gdk::Screen.default.width, gdk::Screen.default.height]).to eq([1280, 800])
    end
  end

  # method_missing answered Ruby's own conversion protocol, so arithmetic on
  # a widget raised "coerce must return [x, y]" from inside Integer#+, naming
  # neither the widget nor the call site.
  describe 'the conversion protocol' do
    it 'refuses to coerce a widget into a number' do
      widget = session.sync { gtk::Label.new('x') }

      expect { 1 + widget }.to raise_error(TypeError, /can't be coerced/)
      expect(widget).not_to respond_to(:coerce)
    end

    it 'still answers the respond_to? guards scripts branch on' do
      window = session.sync { gtk::Window.new('t') }

      expect(window).to respond_to(:set_opacity)
      expect(window).to respond_to(:some_gtk_setter_we_do_not_have=)
    end
  end

  # GTK sets one edge at a time. Collapsing the four sides to their max put a
  # one-sided indent on all four sides: bigshot's glade has 518 one-sided
  # margins, and a label with margin-start 100 came out inside a 100px box.
  describe 'per-side margins' do
    it 'keeps a one-sided indent on the one side' do
      props = session.sync do
        label = gtk::Label.new('Note: ...')
        label.margin_left = 100
        label.margin_right = 10
        label.send(:common_props)
      end

      expect(props[:margin]).to eq(left: 100, right: 10)
    end

    it 'still sends a plain integer when every side agrees' do
      props = session.sync do
        label = gtk::Label.new('x')
        label.margin = 8
        label.send(:common_props)
      end

      expect(props[:margin]).to eq(8)
    end

    it 'says nothing when no side has a margin' do
      props = session.sync { gtk::Label.new('x').send(:common_props) }

      expect(props).not_to have_key(:margin)
    end

    it 'reaches the contract in both shapes' do
      validator = Lich::WebUI::Validator.new
      context = { owner: 't', page_id: 'p', cid: 'text:t1' }

      expect { validator.validate_component!(:text, { content: 'x', margin: { left: 100 } }, **context) }
        .not_to raise_error
      expect { validator.validate_component!(:text, { content: 'x', margin: 8 }, **context) }
        .not_to raise_error
      expect { validator.validate_component!(:text, { content: 'x', margin: { bogus: 5 } }, **context) }
        .to raise_error(Lich::WebUI::Error)
    end
  end

  # A child the contract refuses is skipped, and in a grid every later cell
  # slides into the hole it left, so the table renders transposed. The drop
  # used to share the once-per-class dedupe with unsupported methods, so the
  # second and later drops were silent -- which is what made bigshot's
  # over-long tooltip so hard to find.
  describe 'a dropped child' do
    it 'names every dropped widget, not just the first of its class' do
      logged = []
      allow(Lich).to receive(:log) { |message| logged << message }
      gtk.instance_variable_set(:@dropped, {})

      window = session.sync do
        win = gtk::Window.new('t')
        grid = gtk::Grid.new
        2.times do |row|
          label = gtk::Label.new("r#{row}")
          label.instance_variable_set(:@text, 'x' * 20_000)
          grid.attach(label, 0, row, 1, 1)
        end
        win.add(grid)
        win.show_all
        win
      end
      session.show_window(window)
      session.sync {}

      drops = logged.grep(/dropped Gtk::Label/)
      expect(drops.size).to eq(2)
      expect(drops.first).to match(/key=w\d+ from its parent: .*8192/)
    end

    it 'reports a widget once however many times the page commits' do
      logged = []
      allow(Lich).to receive(:log) { |message| logged << message }
      gtk.instance_variable_set(:@dropped, {})

      window = session.sync do
        win = gtk::Window.new('t')
        label = gtk::Label.new('x')
        label.instance_variable_set(:@text, 'x' * 20_000)
        win.add(label)
        win.show_all
        win
      end
      session.show_window(window)
      3.times { session.sync {} }

      expect(logged.grep(/dropped Gtk::Label/).size).to eq(1)
    end
  end

  # bigshot pushes its Close button to the right edge of the footer with
  # hexpand plus halign end, packed non-expanding. Without hexpand reaching
  # the weights the button's column was natural width, so align had nothing
  # to push against and the button sat next to its label.
  describe 'hexpand in a horizontal box' do
    it 'gives the free width to a child that asked for it with hexpand' do
      props = session.sync do
        box = gtk::Box.new(:horizontal)
        box.pack_start(gtk::Label.new('To save properly...'), expand: false, fill: false, padding: 0)
        button = gtk::Button.new('Close')
        button.halign = :end
        button.hexpand = true
        box.pack_start(button, expand: false, fill: true, padding: 0)
        box.send(:node_props)
      end

      expect(props[:weights]).to eq([0, 1])
    end

    it 'leaves a box alone when nothing asked to expand' do
      props = session.sync do
        box = gtk::Box.new(:horizontal)
        box.pack_start(gtk::Label.new('a'), expand: false, fill: false, padding: 0)
        box.pack_start(gtk::Button.new('b'), expand: false, fill: false, padding: 0)
        box.send(:node_props)
      end

      expect(props[:weights]).to eq([0, 0])
    end
  end

  # Glade sets use-markup on a label whose text is Pango markup. The shim
  # ignored the property, so bigshot's wiki blurb rendered its raw
  # <a href=...> as literal text.
  describe 'use-markup from a Glade file' do
    let(:wiki) do
      'Additional details: <a href="https://gswiki.play.net/x" title="x">' + 'https://gswiki.play.net/x</a>'
    end

    it 'parses the markup rather than printing the tags' do
      content = session.sync do
        label = gtk::Label.new(wiki)
        label.apply_builder_property('use-markup', 'True')
        label.send(:node_props)[:content]
      end

      expect(content).not_to include('<a href')
      expect(content).to include('https://gswiki.play.net/x')
    end

    it 'leaves a label alone when the property is not set' do
      content = session.sync { gtk::Label.new(wiki).send(:node_props)[:content] }

      expect(content).to include('<a href')
    end
  end

  # A tree view used as a plain list names its columns for the model and
  # hides the header row. eloot has twelve, and every one of them showed a
  # bare "Exclusion" heading inside the box.
  describe 'headers-visible on a tree view' do
    def tree_with(headers:)
      session.sync do
        view = gtk::TreeView.new
        view.apply_builder_property('headers-visible', headers) unless headers.nil?
        view.append_column(gtk::TreeViewColumn.new('Exclusion', gtk::CellRendererText.new, text: 0))
        view.send(:node_props)
      end
    end

    it 'hides the header row when the Glade file asked it to' do
      expect(tree_with(headers: 'False')[:headers]).to be(false)
    end

    it 'says nothing when the file left headers alone' do
      expect(tree_with(headers: nil)).not_to have_key(:headers)
    end
  end

  # GTK opens a window at its default size but never smaller than its size
  # request. eloot asks for a default of 800 and a minimum of 900, so it
  # opened clipped and its boxes did not fit.
  describe 'a window whose size request is larger than its default' do
    let(:window) do
      session.sync do
        win = gtk::Window.new('ELoot')
        win.set_default_size(800, 830)
        win.set_size_request(900, 640)
        win
      end
    end

    it 'sizes the page to the larger of the two on each axis' do
      expect(window.send(:node_props)[:size]).to eq([900, 830])
    end

    it 'opens the browser window at that same size' do
      expect(window.browser_geometry).to eq(width: 900, height: 830)
    end

    it 'leaves a window that only set a default size alone' do
      plain = session.sync { win = gtk::Window.new('t'); win.set_default_size(640, 480); win }

      expect(plain.send(:node_props)[:size]).to eq([640, 480])
    end
  end

  # map.lic's center_viewport_on reads `@scroller.allocation.width` and does
  # arithmetic on it. allocation existed only on Window, so on a
  # ScrolledWindow it fell through to method_missing and the arithmetic blew
  # up several frames from the script line that asked -- which is the whole
  # of ";map"'s "coerce must return [x, y]".
  describe 'allocation on a widget that is not the window' do
    it 'reports the enclosing window size for a child that asked for none' do
      scroller = session.sync do
        win = gtk::Window.new('Map')
        win.set_default_size(800, 600)
        sw = gtk::ScrolledWindow.new
        win.add(sw)
        sw
      end

      expect(scroller.allocation.width).to eq(800)
      expect(scroller.allocation.height).to eq(600)
      # The arithmetic map.lic actually does, which used to raise.
      expect(100 - (scroller.allocation.width / 2)).to eq(-300)
    end

    it 'prefers the widget own size request over the window default' do
      scroller = session.sync do
        win = gtk::Window.new('Map')
        win.set_default_size(800, 600)
        sw = gtk::ScrolledWindow.new
        sw.set_size_request(300, 200)
        win.add(sw)
        sw
      end

      expect([scroller.allocation.width, scroller.allocation.height]).to eq([300, 200])
    end

    it 'names x and y first, as Gdk::Rectangle does' do
      expect(gtk::Widget::Allocation.members).to eq(%i[x y width height])
    end

    it 'still answers on a parentless widget' do
      expect(session.sync { gtk::ScrolledWindow.new }.allocation.width).to eq(640)
    end
  end

  # The cell renderer family are not Widgets, so they never got Widget's
  # protocol guard: their method_missing answered `coerce` with nil, and Ruby
  # turned that into "coerce must return [x, y]" -- naming neither the object
  # nor the call site.
  describe 'arithmetic on a cell renderer' do
    it 'raises naming the class instead of a bare coerce failure' do
      renderer = gtk::CellRendererText.new

      # The message matters as much as the class: "coerce must return [x, y]"
      # is what Ruby says when method_missing answers coerce with nil, and it
      # names neither the object nor the call site.
      expect { 100 - renderer }.to raise_error(TypeError, /CellRendererText can't be coerced/)
      expect { 100 - renderer }.to raise_error(TypeError) { |error|
        expect(error.message).not_to include('coerce must return')
      }
    end

    it 'still answers the unknown setters scripts call on it' do
      renderer = gtk::CellRendererText.new

      expect(renderer.set_fixed_height_from_font(1)).to be(renderer)
      expect(renderer.respond_to?(:coerce)).to be(false)
    end
  end

  # Lich evals a script under its bare name, so its backtrace frames read
  # "map:2466", not ".../map.lic:2466". Matching only ".lic:" found no frame at
  # all and the error was reported with no location.
  describe 'naming the script frame in a Gtk.queue error' do
    let(:reporter) do
      described = Lich::Common::ScriptScope::Gtk::Session.allocate
      described.instance_variable_set(:@owner, Struct.new(:name).new('map'))
      described
    end

    it 'finds a frame labelled with the bare script name' do
      backtrace = [
        "map:2466:in 'Integer#-'",
        "map:2466:in 'ElanthiaMap::Window#center_viewport_on'",
        'C:/Gemstone/lich-5/lib/common/script_scope/gtk/session.rb:436:in \'block\''
      ]

      expect(reporter.send(:script_frame, reporter.send(:script_origin, backtrace))).to eq('map:2466')
    end

    it 'still finds a frame from a script loaded by path' do
      reporter.instance_variable_set(:@owner, Struct.new(:name).new('bigshot'))
      backtrace = ["C:/Gemstone/scripts/scripts/bigshot.lic:99:in 'x'"]

      expect(reporter.send(:script_frame, reporter.send(:script_origin, backtrace))).to eq('bigshot.lic:99')
    end

    it 'falls back to any .lic frame when the owner name does not appear' do
      reporter.instance_variable_set(:@owner, Struct.new(:name).new('unrelated'))
      backtrace = ["C:/Gemstone/scripts/scripts/bigshot.lic:99:in 'x'"]

      expect(reporter.send(:script_origin, backtrace)).to include('bigshot.lic:99')
    end

    it 'reports no frame when the backtrace is all shim' do
      backtrace = ['C:/Gemstone/lich-5/lib/common/script_scope/gtk/session.rb:436:in \'block\'']

      expect(reporter.send(:script_origin, backtrace)).to be_nil
    end
  end

  # An unimplemented constant becomes an empty container so the script keeps
  # running, but a missing widget class costs the script everything it meant
  # to put there -- map's Gtk::Image is the map. That used to log exactly
  # like a missing enum member, which costs nothing.
  describe 'a constant the shim does not implement' do
    around do |example|
      previous = gtk.instance_variable_get(:@unsupported)
      gtk.instance_variable_set(:@unsupported, {})
      example.run
      gtk.instance_variable_set(:@unsupported, previous)
    end

    it 'tells the script when a widget class is only a stub' do
      messages = []
      allow(gtk).to receive(:report_stubbed_widget).and_wrap_original do |original, name|
        messages << name
        original.call(name)
      end

      gtk.const_missing(:DrawingAreaProbe)

      expect(messages).to eq([:DrawingAreaProbe])
      expect(gtk.const_get(:DrawingAreaProbe).superclass).to be(gtk::Container)
    end

    it 'says it only once for the same widget' do
      logged = []
      allow(gtk).to receive(:log_unsupported) { |*args, **kwargs| logged << [args, kwargs] }
      stub_const('Lich', Module.new)
      allow(Lich).to receive(:log) { |message| logged << message }

      2.times { gtk.send(:report_stubbed_widget, :RepeatedProbe) }

      expect(logged.grep(/RepeatedProbe/).size).to eq(1)
    end

    it 'keeps an enum member on the quiet path' do
      noted = []
      allow(gtk).to receive(:log_unsupported) { |_klass, name, **| noted << name }

      gtk.const_missing(:POLICY_PROBE)

      expect(noted).to eq([:POLICY_PROBE])
      expect(gtk.const_get(:POLICY_PROBE)).to eq(:policy_probe)
    end

    it 'still returns the stub when nothing can be told' do
      hide_const('Lich')

      expect(gtk.const_missing(:SilentProbe).superclass).to be(gtk::Container)
    end
  end
end
