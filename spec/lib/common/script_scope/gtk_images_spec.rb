# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'webui'
require 'common/script_scope'
require 'common/script_scope/gtk/boot'
require 'tmpdir'
require 'fileutils'
require 'zlib'

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

  def png_bytes(width, height)
    chunk = lambda do |type, data|
      [data.bytesize].pack('N') + type + data + [Zlib.crc32(type + data)].pack('N')
    end
    header = [width, height].pack('N2') + [8, 0, 0, 0, 0].pack('C5')
    raw = ([0].pack('C') + ([0] * width).pack('C*')) * height
    "\x89PNG\r\n\x1A\n".b +
      chunk.call('IHDR', header) +
      chunk.call('IDAT', Zlib::Deflate.deflate(raw)) +
      chunk.call('IEND', '')
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

    # A prefix match alone would accept "…/maps-elsewhere" as being inside
    # "…/maps"; the containment check requires a separator.
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

  describe 'reading a size from the file header' do
    it 'reads a PNG without decoding it' do
      expect(gtk::ImageHeader.size(map_file)).to eq([607, 774])
    end

    it 'returns nil for something that is not an image' do
      expect(gtk::ImageHeader.size(__FILE__)).to be_nil
    end
  end
end
