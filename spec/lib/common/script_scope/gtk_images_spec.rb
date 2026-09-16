# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'webui'
require 'common/script_scope'
require 'common/script_scope/gtk/boot'
require 'tmpdir'
require 'fileutils'
require 'zlib'
# Pixbuf work is the whole point of these examples, and the gem is a separate
# require from gtk3 -- without this they all skipped on a machine that has it.
begin
  require 'gdk_pixbuf2'
rescue LoadError
  nil
end
begin
  require 'cairo'
rescue LoadError
  nil
end

# Gtk::Image and Gtk::Layout were the two constants standing between ";map"
# and drawing anything: both fell through Gtk.const_missing and became empty
# containers, so a real pixbuf was loaded and then thrown away.
RSpec.describe 'GTK compatibility shim: images and layouts' do
  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('map') }
  let(:service) { Lich::WebUI::Service.new }
  let(:session) { gtk::Session.new(owner, service: service) }
  let(:validator) { Lich::WebUI::Validator.new }

  # A real PNG in a temp directory registered as a servable root, so the
  # spec does not depend on which maps happen to be installed.
  let(:root) { @root }
  let(:map_file) { File.join(root, 'Flotilla.png') }

  # The shape map draws its room marker as: a Cairo surface converted with
  # Pixbuf.new(data:), which has no file behind it.
  def cairo_marker(size)
    surface = Cairo::ImageSurface.new(Cairo::FORMAT_ARGB32, size, size)
    context = Cairo::Context.new(surface)
    context.set_source_rgba(0.0, 0.0, 1.0, 0.8)
    context.set_line_width(size * 0.1)
    context.arc(size / 2.0, size / 2.0, (size / 2.0) - 2, 0, 2 * Math::PI)
    context.stroke
    ::GdkPixbuf::Pixbuf.new(
      data: surface.data, colorspace: ::GdkPixbuf::Colorspace::RGB, has_alpha: true,
      bits_per_sample: 8, width: size, height: size, rowstride: surface.stride
    )
  end

  def png_bytes(width, height)
    chunk = lambda do |type, data|
      [data.bytesize].pack('N') + type + data + [Zlib.crc32(type + data)].pack('N')
    end
    header = [width, height].pack('N2') + [8, 0, 0, 0, 0].pack('C5')
    raw = ([0].pack('C') + ([0] * width).pack('C*')) * height
    # rubocop:disable Custom/AsciiOnlySource -- PNG's magic bytes
    "\x89PNG\r\n\x1A\n".b +
      chunk.call('IHDR', header) +
      chunk.call('IDAT', Zlib::Deflate.deflate(raw)) +
      chunk.call('IEND', '')
    # rubocop:enable Custom/AsciiOnlySource
  end

  before do
    @root = Dir.mktmpdir('gtk-images')
    stub_const('MAP_DIR', root)
    File.binwrite(map_file, png_bytes(607, 774))
    gtk::Session.browser_open = proc { |_url, geometry:, on_start:, on_exit:| [geometry, on_exit]; on_start.call(1); true }
    gtk::Session.browser_kill = proc { |_pid| nil }
    allow(gtk::Session).to receive(:for).with(anything).and_return(session)
  end

  after do
    gtk::Session.browser_open = nil
    gtk::Session.browser_kill = nil
    session.shutdown
    service.stop
    FileUtils.remove_entry(@root) if @root && File.directory?(@root)
  end

  describe 'serving a file to the browser' do
    it 'serves an image through the narrowest Lich root that contains it' do
      expect(session.send(:servable_root_for, File.dirname(map_file))).to eq(File.expand_path(root))
      expect(session.serve_file(map_file)).to match(%r{\A/files/gtk-map-\d+/Flotilla\.png\z})
    end

    # The suite points DATA_DIR at the system temp dir, so a sibling temp
    # directory is legitimately servable here. Naming the roots explicitly
    # keeps this about the containment check rather than the environment.
    it 'refuses a directory outside every Lich root' do
      stub_const('MAP_DIR', root)
      stub_const('DATA_DIR', root)
      stub_const('SCRIPT_DIR', root)
      stub_const('LICH_DIR', root)

      expect(session.send(:servable_root_for, File.expand_path('..', root))).to be_nil
      expect(session.serve_file(File.join(File.expand_path('..', root), 'nothing.png'))).to be_nil
    end

    # A prefix match alone would accept ".../maps-elsewhere" as being inside
    # ".../maps"; the containment check requires a separator.
    it 'does not serve a sibling of a permitted root' do
      stub_const('MAP_DIR', root)
      stub_const('DATA_DIR', root)
      stub_const('SCRIPT_DIR', root)
      stub_const('LICH_DIR', root)
      sibling = "#{root}-elsewhere"

      expect(session.send(:servable_root_for, sibling)).to be_nil
    end

    it 'registers one root per directory, not one per file' do
      second_file = File.join(root, 'Other.png')
      File.binwrite(second_file, png_bytes(8, 8))

      first = session.serve_file(map_file)
      second = session.serve_file(second_file)

      expect(first).not_to eq(second)
      expect(session.instance_variable_get(:@file_roots).size).to eq(1)
    end
  end

  describe 'Gtk::Image' do
    it 'renders a contract image the validator accepts' do
      props = session.sync { gtk::Image.new(file: map_file).send(:node_props) }

      expect(props[:src]).to include('Flotilla.png')
      expect { validator.validate_component!(:image, props, owner: 'map', page_id: 'p', cid: 'c') }
        .not_to raise_error
    end

    it 'is still a node when it has nothing to show' do
      props = session.sync { gtk::Image.new.send(:node_props) }

      expect(props[:src]).to eq('')
      expect { validator.validate_component!(:image, props, owner: 'map', page_id: 'p', cid: 'c') }
        .not_to raise_error
    end
  end

  describe 'Gtk::Layout' do
    it 'places its children as composite layers at their coordinates' do
      props = session.sync do
        layout = gtk::Layout.new
        layout.set_size(1200, 900)
        layout.put(gtk::Image.new(file: map_file), 10, 20)
        layout.send(:node_props)
      end

      expect(props[:layers].first).to include(kind: 'image', x: 10, y: 20)
      expect(props).to include(width: 1200, height: 900)
      expect { validator.validate_component!(:composite, props, owner: 'map', page_id: 'p', cid: 'c') }
        .not_to raise_error
    end

    # width and height are required on `composite`, and map does not call
    # set_size until a map loads -- so the Layout was dropped from its
    # parent, taking every child with it, and the window stayed blank even
    # once images worked.
    it 'is valid before the script has given it a size' do
      props = session.sync do
        window = gtk::Window.new('Map')
        window.set_default_size(800, 600)
        layout = gtk::Layout.new
        window.add(layout)
        layout.send(:node_props)
      end

      expect(props).to include(width: 800, height: 600)
      expect { validator.validate_component!(:composite, props, owner: 'map', page_id: 'p', cid: 'c') }
        .not_to raise_error
    end

    it 'falls back to a default size with no window and no request' do
      props = session.sync { gtk::Layout.new.send(:node_props) }

      expect(props).to include(width: 640, height: 480)
      expect { validator.validate_component!(:composite, props, owner: 'map', page_id: 'p', cid: 'c') }
        .not_to raise_error
    end

    it 'accepts can_focus, which scripts set directly rather than through Glade' do
      expect(session.sync { layout = gtk::Layout.new; layout.can_focus = true; layout }).to be_a(gtk::Layout)
    end

    it 'moves a child that is already placed' do
      props = session.sync do
        layout = gtk::Layout.new
        image = gtk::Image.new(file: map_file)
        layout.put(image, 0, 0)
        layout.move(image, 44, 55)
        layout.send(:node_props)
      end

      expect(props[:layers].first).to include(x: 44, y: 55)
    end

    it 'reports a child it cannot make a layer of rather than dropping it silently' do
      noted = []
      allow(gtk).to receive(:log_unsupported) { |_klass, what, **| noted << what }

      layers = session.sync do
        layout = gtk::Layout.new
        layout.put(gtk::Label.new('not an image'), 0, 0)
        layout.layers
      end

      expect(layers).to be_empty
      expect(noted.join).to include('Label')
    end
  end

  # const_missing const_sets whatever it returns, so stubbing a class the
  # shim actually defines is permanent: the stub shadows the real class for
  # the rest of the process and renders the empty box the class exists to
  # fix. Names the shim owns raise instead.
  describe 'a class the shim defines in a later file' do
    it 'is the real class, not a generated stub' do
      expect(gtk::Layout).not_to respond_to(:webui_stub?)
      expect(gtk::Image).not_to respond_to(:webui_stub?)
      expect(session.sync { gtk::Layout.new.send(:node_props) }).to include(:layers, :width, :height)
    end

    it 'refuses to stub one of its own names rather than shadowing it' do
      expect { gtk.const_missing(:Layout) }.to raise_error(NameError, /defined by the shim but not loaded/)
      expect { gtk.const_missing(:MenuItem) }.to raise_error(NameError, /defined by the shim but not loaded/)
    end

    it 'still stubs a class it genuinely does not implement' do
      stub = gtk.const_missing(:NeverImplementedProbe)

      expect(stub).to respond_to(:webui_stub?)
      expect(stub.new.send(:node_props)).to eq(gap: 0)
    end
  end

  # Tracking has to be installed for a pixbuf to know its own file. It was
  # written but never called, so every Image had a pixbuf, no source, and an
  # empty src -- a blank window rather than an error.
  describe 'pixbuf source tracking' do
    it 'is installed by boot, not left to the caller' do
      expect(File.read(File.join(__dir__, '../../../../lib/common/script_scope/gtk/boot.rb')))
        .to include('install_pixbuf_tracking!')
    end

    it 'gives an image built from a tracked pixbuf a real src' do
      skip 'gtk3 gem not available' unless defined?(::GdkPixbuf::Pixbuf)

      gtk.install_pixbuf_tracking!
      props = session.sync do
        pixbuf = ::GdkPixbuf::Pixbuf.new(file: map_file)
        gtk::Image.new(pixbuf: pixbuf).send(:node_props)
      end

      expect(props[:src]).to include('Flotilla.png')
    end

    # webui_data_uri was `@webui_data_uri ||=`, and a Pixbuf is mutable in
    # place, so a script that redrew one kept serving its first frame.
    it 'reflects a pixbuf redrawn in place rather than its first frame' do
      skip 'gtk3 gem not available' unless defined?(::GdkPixbuf::Pixbuf)

      gtk.install_pixbuf_tracking!
      pixbuf = ::GdkPixbuf::Pixbuf.new(
        colorspace: ::GdkPixbuf::Colorspace::RGB, has_alpha: true,
        bits_per_sample: 8, width: 8, height: 8
      )
      pixbuf.fill!(0xff0000ff)
      first = pixbuf.webui_data_uri
      pixbuf.fill!(0x00ff00ff)

      expect(first).to start_with('data:image/png;base64,')
      expect(pixbuf.webui_data_uri).not_to eq(first)
    end

    it 'carries the source across a scale, which is a different object' do
      skip 'gtk3 gem not available' unless defined?(::GdkPixbuf::Pixbuf)

      gtk.install_pixbuf_tracking!
      props = session.sync do
        pixbuf = ::GdkPixbuf::Pixbuf.new(file: map_file)
        scaled = pixbuf.scale_simple(300, 380, ::GdkPixbuf::InterpType::BILINEAR)
        gtk::Image.new(pixbuf: scaled).send(:node_props)
      end

      expect(props[:src]).to include('Flotilla.png')
      expect(props[:scale]).to be_within(0.01).of(300.0 / 607)
    end
  end

  # A script centring the viewport computes `x - viewport_width / 2`. The
  # only true viewport size the shim ever sees is the one the viewer reports
  # through the `scrolled` event; answering with the window's size instead
  # put map's target off by half the difference, so it opened on a corner of
  # empty canvas with the room 800px away.
  describe 'a scroller asked for its allocation' do
    it 'answers with the viewport the viewer reported' do
      scroller = session.sync do
        window = gtk::Window.new('Map')
        window.set_default_size(800, 600)
        sw = gtk::ScrolledWindow.new
        window.add(sw)
        sw.vadjustment.note_viewport(value: 0, upper: 3200, page_size: 250)
        sw.hadjustment.note_viewport(value: 0, upper: 3200, page_size: 400)
        sw
      end

      expect([scroller.allocation.width, scroller.allocation.height]).to eq([400, 250])
    end

    it 'falls back to the window until the viewer has reported' do
      scroller = session.sync do
        window = gtk::Window.new('Map')
        window.set_default_size(800, 600)
        sw = gtk::ScrolledWindow.new
        window.add(sw)
        sw
      end

      expect([scroller.allocation.width, scroller.allocation.height]).to eq([800, 600])
    end

    it 'keeps the window size on an axis the viewer said nothing about' do
      scroller = session.sync do
        window = gtk::Window.new('Map')
        window.set_default_size(800, 600)
        sw = gtk::ScrolledWindow.new
        window.add(sw)
        sw.vadjustment.note_viewport(value: 0, upper: 3200, page_size: 250)
        sw
      end

      expect([scroller.allocation.width, scroller.allocation.height]).to eq([800, 250])
    end
  end

  # map wires button_press/release to its Layout. The contract's answer for
  # a composite is surface_activate -- one completed gesture, not a pair --
  # so the shim synthesizes the press/release a GTK script expects. Without
  # this, 49 of map's controls were unreachable and failed silently.
  describe 'pointer gestures on a layout' do
    let(:layout) do
      session.sync do
        window = gtk::Window.new('Map')
        window.set_default_size(800, 600)
        l = gtk::Layout.new
        window.add(l)
        l
      end
    end

    def fire(payload)
      session.sync { layout.send(:receive_event, :surface_activate, Struct.new(:payload).new(payload)) }
    end

    it 'asks for surface events only once a script has connected one' do
      expect(session.sync { gtk::Layout.new.send(:node_props) }).not_to include(:surface_events)

      layout.signal_connect('button_press_event') { |_w, _e| nil }

      expect(layout.send(:node_props)[:surface_events]).to be(true)
      expect(layout.send(:always_bound_events)).to eq([:surface_activate])
    end

    it 'delivers a press and then a release, which is a click with no drag' do
      seen = []
      layout.signal_connect('button_press_event') { |_w, event| seen << [:press, event.button] }
      layout.signal_connect('button-release-event') { |_w, event| seen << [:release, event.button] }

      fire(x: 150, y: 260, button: 'secondary', modifiers: ['ctrl'])

      expect(seen).to eq([[:press, 3], [:release, 3]])
    end

    it 'hands the script a Gdk-shaped event it can read' do
      captured = nil
      layout.signal_connect('button_press_event') { |_w, event| captured = event }

      fire(x: 150, y: 260, button: 'primary', modifiers: %w[ctrl shift])

      expect([captured.button, captured.x, captured.y]).to eq([1, 150.0, 260.0])
      expect([captured.state.control_mask?, captured.state.shift_mask?]).to eq([true, true])
    end

    # get_pointer_position reads @layout.window.pointer rather than the
    # event, and window returned nil, so every click resolved to 0,0.
    it 'remembers the pointer where a script looks for it' do
      layout.signal_connect('button_press_event') { |_w, _e| nil }
      fire(x: 150, y: 260, button: 'primary', modifiers: [])

      _window, x, y = layout.window.pointer

      expect([x, y]).to eq([150, 260])
    end

    it 'validates as a composite with surface events enabled' do
      layout.signal_connect('button_press_event') { |_w, _e| nil }
      props = layout.send(:node_props)

      expect { validator.validate_component!(:composite, props, owner: 'map', page_id: 'p', cid: 'c') }
        .not_to raise_error
    end
  end

  # map draws its room marker, tag markers and note pins with Cairo and
  # converts them with Pixbuf.new(data:). Those have no file to serve, so
  # every one of them was dropped -- including the circle that marks the
  # room you are standing in.
  describe 'a pixbuf with no file behind it' do
    it 'travels inline as a data URI' do
      skip 'gtk3 gem not available' unless defined?(::GdkPixbuf::Pixbuf)

      gtk.install_pixbuf_tracking!
      props = session.sync { gtk::Image.new(pixbuf: cairo_marker(58)).send(:node_props) }

      expect(props[:src]).to start_with('data:image/png;base64,')
      expect { validator.validate_component!(:image, props, owner: 'map', page_id: 'p', cid: 'c') }
        .not_to raise_error
    end

    it 'appears as a composite layer at its coordinates' do
      skip 'gtk3 gem not available' unless defined?(::GdkPixbuf::Pixbuf)

      gtk.install_pixbuf_tracking!
      props = session.sync do
        l = gtk::Layout.new
        l.set_size(3200, 3200)
        l.put(gtk::Image.new(pixbuf: cairo_marker(58)), 1200, 1400)
        l.send(:node_props)
      end

      expect(props[:layers].first).to include(kind: 'image', x: 1200, y: 1400)
      expect(props[:layers].first[:src]).to start_with('data:image/png;base64,')
      # A marker is drawn at the size it is placed at.
      expect(props[:layers].first).to include(w: 58, h: 58)
    end

    # A script that zooms scales the pixbuf itself and then places everything
    # else in those scaled pixels. The image is still served from the original
    # file, so without a size the browser drew the map at its natural size
    # while the room marker sat at scaled coordinates -- and the circle drifted
    # further off the room the further the zoom was from 100%.
    it 'carries the size the script scaled a layer to, not the size of its file' do
      skip 'gtk3 gem not available' unless defined?(::GdkPixbuf::Pixbuf)

      gtk.install_pixbuf_tracking!
      props = session.sync do
        original = ::GdkPixbuf::Pixbuf.new(file: map_file)
        doubled = original.scale_simple(original.width * 2, original.height * 2,
                                        ::GdkPixbuf::InterpType::BILINEAR)
        layout = gtk::Layout.new
        layout.set_size(original.width * 4, original.height * 4)
        layout.put(gtk::Image.new(pixbuf: doubled), 0, 0)
        layout.send(:node_props)
      end

      layer = props[:layers].first
      expect(layer[:w]).to eq(607 * 2)
      expect(layer[:h]).to eq(774 * 2)
    end

    it 'refuses one too large to inline rather than sending a broken src' do
      skip 'gtk3 gem not available' unless defined?(::GdkPixbuf::Pixbuf)

      gtk.install_pixbuf_tracking!
      noted = []
      allow(gtk).to receive(:log_unsupported) { |_k, _m, **options| noted << options[:note] }

      props = session.sync { gtk::Image.new(pixbuf: cairo_marker(300)).send(:node_props) }

      expect(props[:src]).to eq('')
      expect(noted.join).to match(/exceeds \d+ bytes encoded/)
    end
  end

  describe 'reading a size from the file header' do
    it 'reads a PNG without decoding it' do
      expect(gtk::ImageHeader.size(map_file)).to eq([607, 774])
    end

    it 'returns nil for something that is not an image' do
      expect(gtk::ImageHeader.size(__FILE__)).to be_nil
    end
  end
end
