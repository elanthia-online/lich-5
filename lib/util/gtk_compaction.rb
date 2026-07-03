require 'fiddle'

module Lich
  module Util
    # Keeps Lich's periodic GC.compact calls (MemoryReleaser,
    # Combat::AsyncProcessor) safe to use alongside gtk3/glib2/gdk3/pango --
    # on a stock, unpatched ruby-gnome install, with GC.compact still
    # actually running.
    #
    # ruby-gnome's native gems cache a Ruby Proc for each "boxed"/"object"
    # GType conversion (Gdk::Event, Pango::Attribute, ...) inside a plain C
    # struct that Ruby's GC can't see or update (BoxedInstance2RObjData /
    # ObjectInstance2RObjData in gobject-introspection's rb-gi-loader.c).
    # GC.compact can relocate that Proc without anything updating this one
    # untracked reference to it, so the next GTK signal marshaled through it
    # dereferences a dangling pointer and crashes with SIGBUS/SIGSEGV.
    #
    # The clean fix is a one-line C patch: pin each converter Proc as a
    # permanent GC root (rb_gc_register_mark_object) instead of caching a
    # raw, GC-invisible reference to it. That function is a public,
    # documented libruby API -- exported from an already-loaded shared
    # library -- which means we can call it ourselves, from pure Ruby, via
    # Fiddle, without patching or recompiling anything:
    #
    #   1. GObjectIntrospection::Loader.register_boxed_class_converter and
    #      .register_object_class_converter are the same *public* methods
    #      gdk3/pango/etc. call to install these converters in the first
    #      place. We wrap them so our wrapper captures the block as `&block`
    #      (a real, addressable Proc -- Ruby always reifies `&block`
    #      params, and identity is preserved when forwarding it on), pins
    #      *that* object via rb_gc_register_mark_object, then calls the
    #      original method with the same block. Whatever the C
    #      implementation's own rb_block_proc() resolves to is that exact,
    #      now-pinned Proc -- confirmed empirically (forced compaction via
    #      GC.verify_compaction_references against a stock gem, before and
    #      after this wrapper: crashes without it, survives with it).
    #   2. This has to happen on the *original* registration -- there is no
    #      re-registration involved, ever. (Re-registering an
    #      already-registered GType is a separate, deterministic crash on
    #      stock gems: the free callback on the replaced entry dereferences
    #      a field g_new never initializes. We never trigger that path.)
    #
    # Timing is everything here: this only works if our wrapper is defined
    # before gdk3/pango/etc. ever call register_boxed_class_converter for
    # the first time -- i.e. before gobject-introspection is first
    # required, transitively or otherwise. `gtk_compaction.rb` is required
    # at the top of lich.rbw specifically so this file loads (and installs
    # its wrapper) before lib/init.rb's `require 'gtk3'` runs. If something
    # still manages to load gtk3 before we get a chance to install the
    # wrapper (a custom boot path, a script requiring it unusually early),
    # we can't retroactively pin what's already registered -- in that edge
    # case we fall back to checking whether the *installed gem itself*
    # happens to carry the equivalent native patch (see
    # native_gem_patched?), and only disable compaction outright if neither
    # applies.
    #
    # RETIREMENT: this whole module is a stopgap, not permanent
    # architecture. It exists because most users run a stock
    # gobject-introspection gem that doesn't carry the native fix. Once
    # Lich's enforced minimum gobject-introspection version is one that
    # includes rb_gc_register_mark_object in rb-gi-loader.c upstream (i.e.
    # GemCheck can assert gobject-introspection >= that version the same
    # way it already asserts other minimums), every installed gem
    # satisfies native_gem_patched? by construction and this module's
    # Fiddle-based pinning wrapper (install!, and everything it sets up)
    # is provably redundant -- delete it, and have MemoryReleaser /
    # Combat::AsyncProcessor call GC.compact directly again. Don't let
    # "it works" be the reason it's still here a year from now; the
    # removal condition is a version-floor check, not a feeling.
    module GtkCompaction
      NATIVE_PATCH_MARKER = 'rb_gc_register_mark_object(data->rb_converter)'.freeze

      class << self
        # @return [Boolean] whether gtk3 (or glib2/gdk3/pango directly) has
        #   been loaded into this process. Once true, it stays true for the
        #   life of the process -- Ruby never unloads C extensions, and
        #   Lich runs every script in one shared VM.
        def gtk_loaded?
          !!(defined?(GLib) || defined?(Gtk) || defined?(Gdk))
        end

        # Installs the pinning wrapper around
        # GObjectIntrospection::Loader's converter-registration methods.
        # Safe to call more than once (no-ops after the first successful
        # install). Called eagerly at the bottom of this file -- not
        # lazily from safe_compact! -- because by the time MemoryReleaser
        # or AsyncProcessor first calls safe_compact!, gtk3 has almost
        # always already been loaded and it would be too late.
        #
        # @return [void]
        def install!
          return if defined?(@installed)
          @installed = true

          if gtk_loaded?
            # Something already required gtk3/gdk3/pango/glib2 before we
            # got here -- the original converter registrations already
            # happened, unpinned, and there's no way to retroactively find
            # and pin them. native_gem_patched? is the fallback for this.
            @pinning_active = false
            return
          end

          begin
            require 'gobject-introspection'
          rescue LoadError
            # gtk3 isn't installed at all for this Lich install (headless
            # / --no-gtk). Nothing to protect -- gtk_loaded? will always
            # be false, so safe_compact! never touches any of this.
            @pinning_active = false
            return
          end

          begin
            register_mark_object = Fiddle::Function.new(
              Fiddle::Handle::DEFAULT['rb_gc_register_mark_object'],
              [Fiddle::TYPE_UINTPTR_T],
              Fiddle::TYPE_VOID
            )

            loader_singleton = GObjectIntrospection::Loader.singleton_class
            loader_singleton.send(:alias_method, :__gtk_compaction_unpinned_register_boxed_class_converter, :register_boxed_class_converter)
            loader_singleton.send(:alias_method, :__gtk_compaction_unpinned_register_object_class_converter, :register_object_class_converter)

            loader_singleton.send(:define_method, :register_boxed_class_converter) do |gtype, &block|
              register_mark_object.call(Fiddle.dlwrap(block))
              __gtk_compaction_unpinned_register_boxed_class_converter(gtype, &block)
            end

            loader_singleton.send(:define_method, :register_object_class_converter) do |gtype, &block|
              register_mark_object.call(Fiddle.dlwrap(block))
              __gtk_compaction_unpinned_register_object_class_converter(gtype, &block)
            end

            @pinning_active = true
          rescue StandardError, ::Fiddle::DLError
            # Anything going wrong here -- a Ruby implementation that
            # doesn't export this libruby symbol the same way (JRuby,
            # TruffleRuby), a future gobject-introspection release renaming
            # these methods, whatever -- must not take the rest of Lich
            # down with it. install! runs unconditionally, eagerly, at
            # file-require time for every boot; a raised exception here
            # propagates straight out of that require and crashes startup
            # entirely, which is a strictly worse failure mode than the
            # thing this module exists to prevent. Fail into the same
            # conservative fallback as any other "can't pin" case.
            @pinning_active = false
          end
        end

        # @return [Boolean] whether the currently-loaded
        #   gobject-introspection gem carries the GC.compact safety patch
        #   natively (i.e. someone applied the native gem patch directly).
        #   Fallback for the case where install! ran too late to install
        #   our own pinning wrapper. Memoized: a loaded C extension can't
        #   be swapped out mid-process, so this can't change once computed.
        def native_gem_patched?
          return @native_gem_patched if defined?(@native_gem_patched)

          @native_gem_patched = begin
            loaded = $LOADED_FEATURES.find { |f| f =~ /gobject_introspection\.(bundle|so)\z/ }
            gem_dir = loaded && File.expand_path(File.join(File.dirname(loaded), '..'))
            src = gem_dir && File.join(gem_dir, 'ext', 'gobject-introspection', 'rb-gi-loader.c')
            !!(src && File.exist?(src) && File.read(src).include?(NATIVE_PATCH_MARKER))
          rescue StandardError
            false
          end
        end

        # Runs GC.compact safely.
        #
        # If gtk3 hasn't been loaded, compacts immediately -- nothing in
        # this module applies. If it has, compacts whenever we know it's
        # safe: either our own pinning wrapper caught the original
        # converter registrations (the common case), or the installed gem
        # carries the native patch directly. Only gives up on compaction
        # -- for the rest of the process -- if neither applies.
        #
        # @return [void]
        def safe_compact!
          return unless GC.respond_to?(:compact)
          return GC.compact unless gtk_loaded?
          return GC.compact if @pinning_active
          return GC.compact if native_gem_patched?
        end
      end
    end
  end
end

Lich::Util::GtkCompaction.install!
