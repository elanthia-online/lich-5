# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        # ------------------------------------------------------------------
        # Images and absolute-positioning layouts.
        #
        # A script's `GdkPixbuf` is the real gem -- the shim shadows only
        # Gtk, Gdk and GLib -- so `Pixbuf.new(file:)` already returns a
        # working pixbuf with real dimensions. What was missing is the other
        # half: `Gtk::Image` and `Gtk::Layout` did not exist, so
        # Gtk.const_missing turned them into empty containers and the pixbuf
        # went nowhere.
        #
        # The browser cannot be handed a bitmap, so an image is served as a
        # file: the shim registers the pixbuf's own directory with the
        # FileService and sends the resulting URL as the `src` prop. That is
        # why the source path is tracked at all -- a GdkPixbuf cannot report
        # the file it was loaded from.
        # ------------------------------------------------------------------

        # Remembers where a pixbuf came from, without keeping it alive. Two
        # pixbufs of the same file stay distinct entries.
        #
        # This started as a Hash keyed on `pixbuf.object_id`, which held no
        # reference to the pixbuf but leaked an integer key once it was
        # collected. Rubocop reads object_id keys as a compare_by_identity
        # that was spelled by hand, and taking that advice turned every key
        # into a STRONG reference: `@sources` then owned every bitmap the
        # global tracking patch ever recorded, for the life of the process,
        # with no production caller for forget_all. That is worse than the
        # leak it replaced -- an integer against a native image buffer.
        #
        # ObjectSpace::WeakKeyMap is the structure both versions were
        # reaching for: identity comparison, and the entry goes when the
        # pixbuf does.
        module PixbufSources
          @sources = ObjectSpace::WeakKeyMap.new
          @mutex = Mutex.new

          class << self
            def record(pixbuf, path)
              return pixbuf unless pixbuf && path

              @mutex.synchronize { @sources[pixbuf] = File.expand_path(path.to_s) }
              pixbuf
            end

            def path_for(pixbuf)
              return nil unless pixbuf

              @mutex.synchronize { @sources[pixbuf] }
            end

            # A scaled pixbuf is a different object; it still shows the same
            # file, so the source carries across. The browser does the
            # scaling itself from the `scale` prop.
            def inherit(from, to)
              path = path_for(from)
              record(to, path) if path
              to
            end

            def forget_all
              @mutex.synchronize { @sources.clear }
            end

            # WeakKeyMap answers key? but not size; tests need a way to ask
            # whether a specific pixbuf is still recorded.
            def recorded?(pixbuf)
              @mutex.synchronize { @sources.key?(pixbuf) }
            end

            # A `body_text` prop is bounded, and base64 costs a third on top
            # of the PNG. A marker is small -- map's fixed one is 58px, about
            # 2.5KB encoded -- but a dynamic one grows with the zoom, so a
            # pixbuf that would not fit is reported rather than sent as a
            # truncated src the browser would refuse.
            MAX_DATA_URI = 8192

            def data_uri(pixbuf)
              return nil unless pixbuf.respond_to?(:save)

              png = encode_png(pixbuf)
              return nil unless png

              encoded = "data:image/png;base64,#{[png].pack('m0')}"
              if encoded.bytesize > MAX_DATA_URI
                Gtk.log_unsupported('GdkPixbuf', 'inline image',
                                    note: "#{pixbuf.width}x#{pixbuf.height} exceeds #{MAX_DATA_URI} bytes encoded")
                return nil
              end
              encoded
            rescue StandardError => error
              Gtk.log_unsupported('GdkPixbuf', 'inline image', note: error.message)
              nil
            end

            private

            # save(nil, type) returns the bytes; older bindings only have
            # save_to_buffer, which is deprecated but still present.
            def encode_png(pixbuf)
              pixbuf.save(nil, 'png')
            rescue StandardError
              begin
                pixbuf.send(:save_to_buffer, 'png')
              rescue StandardError
                nil
              end
            end
          end
        end

        # Wraps the real GdkPixbuf so `new(file:)` and `scale_simple` keep
        # the source path. Everything else is delegated untouched: scripts
        # read width, height, and pixel data from the genuine object.
        #
        # Installed only when the gem is present. Without it a script that
        # builds a pixbuf fails the same way it did before, which is the
        # honest outcome -- the shim cannot decode an image itself.
        def self.install_pixbuf_tracking!
          return false unless defined?(::GdkPixbuf::Pixbuf)
          return true if ::GdkPixbuf::Pixbuf.respond_to?(:webui_shim_installed?)

          ::GdkPixbuf::Pixbuf.singleton_class.prepend(Module.new do
            def new(*args, **options)
              pixbuf = super
              PixbufSources.record(pixbuf, options[:file]) if options[:file]
              pixbuf
            end

            def webui_shim_installed?
              true
            end
          end)

          # A pixbuf built in memory has no file to serve. map draws its room
          # marker, tag markers and note pins with Cairo and converts them
          # with Pixbuf.new(data:), so every one of them was dropped for want
          # of a source. Encoded to PNG on demand instead and sent as a
          # data: URI, which the page's CSP already allows (img-src 'self'
          # data:).
          ::GdkPixbuf::Pixbuf.prepend(Module.new do
            # Not memoised, deliberately. A Pixbuf is mutable in place -- fill!
            # and a writable #pixels both exist -- so `@webui_data_uri ||=` served
            # the first frame forever once a script redrew one, silently.
            #
            # Keying a memo on the pixel content was measured and rejected: the
            # fingerprint has to read #pixels, and at 200x200 that costs 1.6x the
            # PNG encode it was meant to avoid (1.98ms against 1.23ms). At the size
            # markers actually are -- map draws an X of a dozen pixels -- the encode
            # is 0.033ms, which is not worth guarding at all.
            #
            # So: correct and cheap rather than stale and clever. If a large inline
            # image ever lands on a hot path, the fix is a memo the MUTATOR
            # invalidates, not one that re-derives the content to check.
            def webui_data_uri
              PixbufSources.data_uri(self)
            end
          end)

          ::GdkPixbuf::Pixbuf.prepend(Module.new do
            def scale_simple(*args)
              PixbufSources.inherit(self, super)
            end

            def scale(*args)
              PixbufSources.inherit(self, super)
            end
          end)
          true
        rescue StandardError => error
          Gtk.log_unsupported('GdkPixbuf', 'source tracking', note: error.message)
          false
        end

        # Gtk::Image. Holds a pixbuf and renders as a contract `image` whose
        # src is a served URL.
        class Image < Widget
          def initialize(*args, **options)
            super()
            @pixbuf = nil
            @file = nil
            @scale = 1.0
            @alt = nil
            self.pixbuf = options[:pixbuf] if options[:pixbuf]
            self.file = options[:file] if options[:file]
            # Gtk::Image.new(path) is not in the corpus, but it is the other
            # GTK 2 form and costs nothing to accept.
            self.file = args.first if args.first.is_a?(String)
          end

          attr_reader :pixbuf, :file

          def pixbuf=(value)
            @pixbuf = value
            @file = PixbufSources.path_for(value)
            @natural = nil
            changed!
          end
          def_setter :set_pixbuf, :pixbuf=

          def file=(path)
            @file = path && File.expand_path(path.to_s)
            @pixbuf = nil
            @natural = nil
            changed!
          end
          def_setter :set_from_file, :file=

          def set_from_pixbuf(value)
            self.pixbuf = value
            self
          end

          def clear
            @pixbuf = nil
            @file = nil
            changed!
            self
          end

          # The browser scales; a script that scaled the pixbuf itself gets
          # the ratio back out of it so the rendered size still matches.
          def scale
            return @scale unless @pixbuf && natural_width&.positive?

            (@pixbuf.width.to_f / natural_width).clamp(0.1, 8.0)
          end

          def node_type
            :image
          end

          def node_props
            src = served_src
            # An image with nothing to show is still a node, so the layout
            # does not shift when the script sets a pixbuf a moment later.
            return { src: '', alt: @alt || 'no image' } unless src

            props = { src: src }
            props[:alt] = @alt if @alt
            ratio = scale
            props[:scale] = ratio unless ratio.nil? || (ratio - 1.0).abs < 0.001
            props
          end

          def alt=(value)
            @alt = value&.to_s
            changed!
          end

          # The size this image should occupy: the pixbuf's own dimensions,
          # which is what the script scaled it to. Nil when there is no pixbuf
          # to ask -- an image set from a file is shown at its natural size,
          # which is what the browser does anyway.
          def rendered_size
            return nil unless @pixbuf.respond_to?(:width) && @pixbuf.respond_to?(:height)

            width = @pixbuf.width
            height = @pixbuf.height
            return nil unless width.to_i.positive? && height.to_i.positive?

            [width.to_i, height.to_i]
          rescue StandardError
            nil
          end

          private

          # The natural size of the file on disk, which is what the served
          # URL delivers. Read from the header rather than by decoding.
          def natural_width
            @natural ||= ImageHeader.size(@file)
            @natural&.first
          end

          def served_src
            return @session.serve_file(@file) if @file && File.file?(@file)
            # No file behind it: a Cairo-drawn marker, which travels inline.
            return @pixbuf.webui_data_uri if @pixbuf.respond_to?(:webui_data_uri)

            nil
          rescue StandardError => error
            Gtk.log_unsupported('Gtk::Image', 'serving file', note: error.message)
            nil
          end
        end

        # If anything touched Gtk::Image or Gtk::Layout before this file
        # loaded, const_missing already answered with a stub container and
        # const_set it. Reopening `class Layout < Container` then extends
        # that stub instead of replacing it, and node_props stays the stub's
        # {gap: 0} -- which renders an empty box exactly as before the class
        # existed. Remove the stub first so the real definitions below take.
        # Gtk::Layout and Gtk::Fixed: children at absolute coordinates.
        # Rendered as a contract `composite`, whose layers carry x and y.
        class Layout < Container
          def initialize(*_args)
            super()
            @positions = {}
            @width = nil
            @height = nil
          end

          def put(child, x = 0, y = 0)
            add(child)
            @positions[child.key] = [x.to_i, y.to_i]
            changed!
            self
          end
          alias add_with_viewport put

          def move(child, x = 0, y = 0)
            return self unless child

            @positions[child.key] = [x.to_i, y.to_i]
            changed!
            self
          end

          def remove(child)
            @positions.delete(child.key) if child.respond_to?(:key)
            super
          end

          def set_size(width, height)
            @width = width.to_i
            @height = height.to_i
            changed!
            self
          end

          def position_of(child)
            @positions[child.key] || [0, 0]
          end

          def node_type
            :composite
          end

          # map.lic wires four pointer signals to its Layout. The contract's
          # answer for a composite is `surface_activate`, which reports one
          # completed gesture with its position, button and modifiers -- not
          # a press/release pair, because the browser pans the scroller
          # itself and a drag never needs to reach the script.
          #
          # So the shim synthesizes the pair a GTK script expects: press
          # then release, both carrying the same Gdk-shaped event. A script
          # that starts a drag on press and decides click-versus-drag on
          # release sees a press followed immediately by a release with no
          # motion between, which is exactly a click.
          #
          # Motion and scroll have no contract event; scroll-to-pan is the
          # browser's own and ctrl+scroll zoom is reported separately.
          SURFACE_SIGNALS = {
            button_press_event: :press,
            button_release_event: :release,
          }.freeze

          # Every signal a script connects here becomes the one contract
          # event a composite has. Returning :press/:release instead -- as
          # this did at first -- makes sync_bindings! bind them, and the
          # adapter refuses the widget outright: composite has no such
          # events, so the whole Layout was dropped and the map went blank.
          def event_for(signal)
            return :surface_activate if SURFACE_SIGNALS.key?(signal)

            super
          end

          def always_bound_events
            return [] unless surface_wanted?

            [:surface_activate]
          end

          def receive_event(event, context)
            return super unless event == :surface_activate

            payload = context.payload || {}
            @session.note_pointer(window_root)
            remember_pointer(payload)
            note_scroll_offset(payload)
            %i[button_press button_release].each do |kind|
              gdk = Event.pointer(kind, payload)
              wanted = kind == :button_press ? :press : :release
              @handlers.each_key do |signal|
                emit(signal, gdk) if SURFACE_SIGNALS[signal] == wanted
              end
            end
            nil
          end

          # A script reads the pointer back through `window.pointer` rather
          # than from the event it was handed, so the last position has to
          # be recorded where that can find it.
          def remember_pointer(payload)
            x = (payload[:x] || payload['x']).to_i
            y = (payload[:y] || payload['y']).to_i
            @pointer = [x, y]
          end

          # 2.15: the gesture reports where the enclosing scroller actually
          # sat, which is the other half of the coordinate a script computes.
          # The adjustments only ever learned an offset from a `scrolled`
          # report, so a click arriving before one -- or after a re-render
          # reset them -- was translated against a stale value. Recording the
          # viewer's real offset here makes the script's own arithmetic,
          # `adjustment.value + pointer`, exact at the moment it runs.
          def note_scroll_offset(payload)
            scroller = enclosing_scroller
            return unless scroller

            x = payload[:scroll_x] || payload['scroll_x']
            y = payload[:scroll_y] || payload['scroll_y']
            scroller.hadjustment.note_viewport(value: x) if x
            scroller.vadjustment.note_viewport(value: y) if y
          end

          def enclosing_scroller
            node = parent
            node = node.parent while node && !node.is_a?(ScrolledWindow)
            node
          end

          def window
            PointerWindow.new(@pointer || [0, 0])
          end

          # Gdk::Window, only as far as a script needs it: `window.pointer`
          # returns [window, x, y] in GTK, and callers index [1] and [2].
          PointerWindow = Struct.new(:position) do
            def pointer
              [self, position[0], position[1]]
            end
          end

          def surface_wanted?
            @handlers.keys.any? { |signal| SURFACE_SIGNALS.key?(signal) }
          end

          # `composite` takes no children: its content is the `layers` prop,
          # not a subtree. The children a script puts here are still real
          # widgets -- it holds them, shows and hides them, destroys them --
          # so they stay in @children and are read by #layers; they are just
          # never materialized as nodes of their own. Returning them here
          # instead got the whole Layout dropped with "component accepts no
          # children", which is a blank window, not a missing image.
          def render_children
            []
          end

          # width and height are required on `composite`, and a script sets
          # them with set_size only once it has something to show -- map
          # calls it from update_map_display, which does not run until a map
          # loads. Rendering before then dropped the whole Layout, and with
          # it every child, so the window stayed blank even once the image
          # worked. Fall back to the widget's own request, then its window,
          # so the node is always valid.
          def node_props
            props = { layers: layers, width: composite_width, height: composite_height }
            # The validator refuses surface_activate unless the node asks
            # for it, so the property and the binding go together.
            props[:surface_events] = true if surface_wanted?
            props
          end

          def composite_width
            return @width if @width&.positive?
            return @width_request if @width_request&.positive?

            window_root&.default_width || 640
          end

          def composite_height
            return @height if @height&.positive?
            return @height_request if @height_request&.positive?

            window_root&.default_height || 480
          end

          # A composite layer names an image and where it sits. Children
          # that are not images have nothing to contribute to a composite,
          # so they are reported rather than silently dropped.
          def layers
            visible_children.filter_map do |child|
              x, y = position_of(child)
              unless child.is_a?(Image)
                Gtk.log_unsupported('Gtk::Layout', "child #{child.short_class_name}",
                                    note: 'only images can be composite layers')
                next
              end
              src = child.send(:served_src)
              next unless src

              layer = { kind: 'image', src: src, x: x, y: y }
              # The size the script drew at, not the size of the file behind
              # it. A script that zooms scales the pixbuf itself and places
              # everything else in those scaled pixels, but the image is served
              # from the original file -- so without this the map rendered at
              # its natural size while the room marker sat at scaled
              # coordinates, and the circle drifted further off the room the
              # further the zoom was from 100%.
              width, height = child.send(:rendered_size)
              layer[:w] = width if width
              layer[:h] = height if height
              layer
            end
          end

          private

          def visible_children
            @children.select { |child| child.respond_to?(:visible?) ? child.visible? : true }
          end
        end

        class Fixed < Layout; end

        # PNG and JPEG dimensions from the file header. stdlib only -- the
        # gem may be absent, and an Image still needs the natural size to
        # report a scale against.
        module ImageHeader
          module_function

          def size(path)
            return nil unless path && File.file?(path)

            # rubocop:disable Custom/AsciiOnlySource -- the formats' own magic
            # bytes; there is no ASCII spelling of them.
            File.open(path, 'rb') do |io|
              header = io.read(24).to_s
              return png_size(header) if header.start_with?("\x89PNG\r\n\x1A\n".b)
              return gif_size(header) if header.start_with?('GIF8')

              io.rewind
              return jpeg_size(io) if header.start_with?("\xFF\xD8".b)
            end
            # rubocop:enable Custom/AsciiOnlySource
            nil
          rescue StandardError
            nil
          end

          def png_size(header)
            return nil if header.bytesize < 24

            header[16, 8].unpack('N2')
          end

          def gif_size(header)
            return nil if header.bytesize < 10

            header[6, 4].unpack('v2')
          end

          # Walk the segment chain to the frame header, which is the only
          # place a JPEG states its size.
          def jpeg_size(io)
            io.read(2)
            while (marker = io.read(2))
              break unless marker.getbyte(0) == 0xFF

              code = marker.getbyte(1)
              length = io.read(2).to_s.unpack1('n').to_i
              # SOF0..SOF15, excluding the non-frame markers in that range.
              if code >= 0xC0 && code <= 0xCF && ![0xC4, 0xC8, 0xCC].include?(code)
                frame = io.read(5).to_s
                return nil if frame.bytesize < 5

                height, width = frame[1, 4].unpack('n2')
                return [width, height]
              end
              io.seek(length - 2, IO::SEEK_CUR)
            end
            nil
          end
        end
      end
    end
  end
end
