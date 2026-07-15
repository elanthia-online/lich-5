# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/util/gtk_compaction'
require 'tmpdir'
require 'fileutils'

# Requiring this file is inert -- it does not call install! (deliberately;
# see install!'s own doc). Only lich.rbw calling install! explicitly, right
# after requiring this file and before lib/init.rb's `require 'gtk3'`, ever
# activates the pinning wrapper for real. That correctness is the entire
# difference between "GC.compact runs safely" and "GC.compact occasionally
# crashes the process." Its state (@installed, @pinning_active,
# @native_gem_patched, @compaction_disabled_warned) is process-global,
# though, so a plain rspec run can still have it set by the time this file
# loads -- if some other spec earlier in the run called install! itself, or
# (before this file's own fixes) merely required gtk3/gdk3/glib2 in a way
# that used to trigger it as a side effect. Every example below explicitly
# resets that state before exercising the method under test and restores
# whatever was there before, via the `around` hook, so this file can
# neither depend on nor pollute ambient process state or the rest of the
# suite.
RSpec.describe Lich::Util::GtkCompaction do
  def memoized_ivars
    %i[@installed @pinning_active @native_gem_patched @compaction_disabled_warned]
  end

  def clear_memoized_state!
    memoized_ivars.each do |ivar|
      described_class.remove_instance_variable(ivar) if described_class.instance_variable_defined?(ivar)
    end
  end

  around do |example|
    saved = memoized_ivars.to_h do |ivar|
      [ivar, described_class.instance_variable_defined?(ivar) ? described_class.instance_variable_get(ivar) : :__unset__]
    end

    example.run

    saved.each do |ivar, value|
      if value == :__unset__
        described_class.remove_instance_variable(ivar) if described_class.instance_variable_defined?(ivar)
      else
        described_class.instance_variable_set(ivar, value)
      end
    end
  end

  # ---------------------------------------------------------------------
  # gtk_loaded?
  # ---------------------------------------------------------------------
  describe '.gtk_loaded?' do
    it 'returns false when none of GLib, Gtk, or Gdk are defined' do
      %w[GLib Gtk Gdk].each { |name| hide_const(name) if Object.const_defined?(name) }

      expect(described_class.gtk_loaded?).to be(false)
    end

    it 'returns true when GLib is defined' do
      stub_const('GLib', Module.new)

      expect(described_class.gtk_loaded?).to be(true)
    end

    it 'returns true when Gtk is defined' do
      stub_const('Gtk', Module.new)

      expect(described_class.gtk_loaded?).to be(true)
    end

    it 'returns true when Gdk is defined' do
      stub_const('Gdk', Module.new)

      expect(described_class.gtk_loaded?).to be(true)
    end
  end

  # ---------------------------------------------------------------------
  # native_gem_patched?
  # ---------------------------------------------------------------------
  describe '.native_gem_patched?' do
    around do |example|
      original_loaded_features = $LOADED_FEATURES.dup
      # Strip any real gobject_introspection entry before each example, not
      # just whatever the fake-path tests happen to append. native_gem_patched?
      # does $LOADED_FEATURES.find { ... } -- first match wins -- so on any
      # machine that actually has the real gem installed and loaded (which
      # is most dev boxes, just not CI, which runs with BUNDLE_WITHOUT: gtk),
      # a real, stock, unpatched entry earlier in the array would win over
      # the fake one these tests append, silently testing the wrong thing.
      # This is a defense-in-depth guarantee -- install! no longer runs as a
      # require-time side effect (see install!'s own doc), so in practice
      # nothing should inject a real entry here anymore, but this describe
      # block shouldn't depend on that alone to stay correct.
      $LOADED_FEATURES.reject! { |f| f =~ /gobject_introspection\.(bundle|so)\z/ }
      example.run
      $LOADED_FEATURES.replace(original_loaded_features)
    end

    def write_fake_gem(dir, bundle_ext:, source_body:)
      gem_dir = File.join(dir, 'gobject-introspection-4.3.6')
      src_dir = File.join(gem_dir, 'ext', 'gobject-introspection')
      lib_dir = File.join(gem_dir, 'lib')
      FileUtils.mkdir_p(src_dir)
      FileUtils.mkdir_p(lib_dir)
      File.write(File.join(src_dir, 'rb-gi-loader.c'), source_body)
      bundle_path = File.join(lib_dir, "gobject_introspection.#{bundle_ext}")
      File.write(bundle_path, '')
      bundle_path
    end

    it 'memoizes its result -- a second call does not recompute' do
      clear_memoized_state!
      $LOADED_FEATURES << '/fake/lib/gobject_introspection.bundle'
      allow(File).to receive(:exist?).and_return(false)

      first = described_class.native_gem_patched?

      # If this were not memoized, flipping the underlying answer would
      # change the second call's result.
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:read).and_return(described_class::NATIVE_PATCH_MARKER)
      second = described_class.native_gem_patched?

      expect(first).to be(false)
      expect(second).to eq(first)
    end

    it 'returns false when no gobject_introspection bundle/so entry is in $LOADED_FEATURES' do
      clear_memoized_state!
      $LOADED_FEATURES.reject! { |f| f =~ /gobject_introspection/ }

      expect(described_class.native_gem_patched?).to be(false)
    end

    it 'returns true when the loaded gem source carries the patch marker' do
      clear_memoized_state!
      Dir.mktmpdir do |dir|
        bundle_path = write_fake_gem(dir, bundle_ext: 'bundle', source_body: "before\n#{described_class::NATIVE_PATCH_MARKER}\nafter")
        $LOADED_FEATURES << bundle_path

        expect(described_class.native_gem_patched?).to be(true)
      end
    end

    it 'returns false when the loaded gem source does not carry the patch marker (stock gem)' do
      clear_memoized_state!
      Dir.mktmpdir do |dir|
        bundle_path = write_fake_gem(dir, bundle_ext: 'bundle', source_body: 'nothing relevant here')
        $LOADED_FEATURES << bundle_path

        expect(described_class.native_gem_patched?).to be(false)
      end
    end

    it 'matches a .so extension the same as .bundle (Linux, and Windows via RubyInstaller/mingw)' do
      clear_memoized_state!
      Dir.mktmpdir do |dir|
        bundle_path = write_fake_gem(dir, bundle_ext: 'so', source_body: described_class::NATIVE_PATCH_MARKER)
        $LOADED_FEATURES << bundle_path

        expect(described_class.native_gem_patched?).to be(true)
      end
    end

    it 'returns false, without raising, when the loaded path resolves outside any real gem (source missing)' do
      clear_memoized_state!
      $LOADED_FEATURES << '/definitely/does/not/exist/lib/gobject_introspection.bundle'

      expect { described_class.native_gem_patched? }.not_to raise_error
      expect(described_class.native_gem_patched?).to be(false)
    end

    it 'returns false, without raising, when reading the source file raises' do
      clear_memoized_state!
      $LOADED_FEATURES << '/fake/lib/gobject_introspection.bundle'
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:read).and_raise(Errno::EACCES, 'permission denied')

      expect { described_class.native_gem_patched? }.not_to raise_error
      expect(described_class.native_gem_patched?).to be(false)
    end

    it 'returns false, without raising, when the marker string is merely a substring elsewhere (adversarial near-miss)' do
      clear_memoized_state!
      Dir.mktmpdir do |dir|
        # A near-miss should not match: a comment merely *mentioning* the
        # function name, without the exact call-site marker, must not be
        # read as "patched" -- that would be a false sense of safety.
        bundle_path = write_fake_gem(dir, bundle_ext: 'bundle', source_body: '// see rb_gc_register_mark_object for background, not used here')
        $LOADED_FEATURES << bundle_path

        expect(described_class.native_gem_patched?).to be(false)
      end
    end
  end

  # ---------------------------------------------------------------------
  # install!
  # ---------------------------------------------------------------------
  describe '.install!' do
    it 'is idempotent -- a second call does not re-run the installation logic' do
      clear_memoized_state!
      call_count = 0
      allow(described_class).to receive(:gtk_loaded?) { call_count += 1; true }

      described_class.install!
      described_class.install!

      expect(call_count).to eq(1)
    end

    it 'does not attempt to require gobject-introspection when gtk3 is already loaded' do
      clear_memoized_state!
      allow(described_class).to receive(:gtk_loaded?).and_return(true)
      allow(described_class).to receive(:require)

      described_class.install!

      expect(described_class).not_to have_received(:require)
      expect(described_class.instance_variable_get(:@pinning_active)).to be(false)
    end

    it 'sets pinning_active false, without raising, when gobject-introspection is not installed (headless/no-gtk)' do
      clear_memoized_state!
      allow(described_class).to receive(:gtk_loaded?).and_return(false)
      allow(described_class).to receive(:require).with('gobject-introspection').and_raise(LoadError)

      expect { described_class.install! }.not_to raise_error
      expect(described_class.instance_variable_get(:@pinning_active)).to be(false)
    end

    it 'sets pinning_active false, without raising, when Fiddle symbol resolution fails' do
      # Adversarial: this is the exact gap found and fixed in this session
      # -- an unusual Ruby implementation (JRuby, TruffleRuby), or a future
      # libruby that renames/removes this exported symbol, must degrade
      # gracefully rather than crashing Lich's entire boot (install! runs
      # eagerly, unconditionally, at file-require time).
      clear_memoized_state!
      allow(described_class).to receive(:gtk_loaded?).and_return(false)
      allow(described_class).to receive(:require).with('gobject-introspection')
      allow(Fiddle::Function).to receive(:new).and_raise(Fiddle::DLError, 'unknown symbol "rb_gc_register_mark_object"')

      expect { described_class.install! }.not_to raise_error
      expect(described_class.instance_variable_get(:@pinning_active)).to be(false)
    end

    it 'sets pinning_active false, without raising, when the loader does not define the expected methods' do
      # Adversarial: a future gobject-introspection release renames or
      # removes register_boxed_class_converter/register_object_class_converter.
      clear_memoized_state!
      allow(described_class).to receive(:gtk_loaded?).and_return(false)
      allow(described_class).to receive(:require).with('gobject-introspection')
      stub_const('GObjectIntrospection::Loader', Class.new)

      expect { described_class.install! }.not_to raise_error
      expect(described_class.instance_variable_get(:@pinning_active)).to be(false)
    end

    context 'successful installation' do
      let(:fake_loader) do
        Class.new do
          class << self
            def boxed_calls
              @boxed_calls ||= []
            end

            def object_calls
              @object_calls ||= []
            end

            def register_boxed_class_converter(gtype, &block)
              boxed_calls << [gtype, block]
              :boxed_original_return
            end

            def register_object_class_converter(gtype, &block)
              object_calls << [gtype, block]
              :object_original_return
            end
          end
        end
      end

      before do
        clear_memoized_state!
        allow(described_class).to receive(:gtk_loaded?).and_return(false)
        allow(described_class).to receive(:require).with('gobject-introspection')
        stub_const('GObjectIntrospection::Loader', fake_loader)
      end

      it 'sets pinning_active true' do
        described_class.install!

        expect(described_class.instance_variable_get(:@pinning_active)).to be(true)
      end

      it 'pins the block via rb_gc_register_mark_object, called through Fiddle, before forwarding' do
        pinned = []
        fake_function = instance_double(Fiddle::Function)
        allow(Fiddle::Function).to receive(:new)
          .with(Fiddle::Handle::DEFAULT['rb_gc_register_mark_object'], [Fiddle::TYPE_UINTPTR_T], Fiddle::TYPE_VOID)
          .and_return(fake_function)
        allow(fake_function).to receive(:call) { |raw| pinned << raw }
        allow(Fiddle).to receive(:dlwrap) { |obj| obj.object_id }

        described_class.install!
        my_block = proc { :converter_result }
        fake_loader.register_boxed_class_converter(:some_gtype, &my_block)

        expect(pinned).to eq([my_block.object_id])
        expect(fake_loader.boxed_calls).to eq([[:some_gtype, my_block]])
      end

      it 'wraps register_object_class_converter the same way as register_boxed_class_converter' do
        fake_function = instance_double(Fiddle::Function, call: nil)
        allow(Fiddle::Function).to receive(:new).and_return(fake_function)

        described_class.install!
        my_block = proc { :whatever }
        fake_loader.register_object_class_converter(:another_gtype, &my_block)

        expect(fake_loader.object_calls).to eq([[:another_gtype, my_block]])
      end

      it "forwards the original method's return value, not the pin call's" do
        fake_function = instance_double(Fiddle::Function, call: :pin_call_return_value_should_be_ignored)
        allow(Fiddle::Function).to receive(:new).and_return(fake_function)

        described_class.install!
        result = fake_loader.register_boxed_class_converter(:x) {}

        expect(result).to eq(:boxed_original_return)
      end

      it 'pins before forwarding to the original method, not after' do
        # Adversarial: ordering matters here specifically because the
        # original registration call can itself raise (e.g. re-registering
        # an already-registered GType on a stock gem -- see the module
        # doc). A "pin after forward" ordering would silently skip pinning
        # whenever that happens, defeating the whole point.
        order = []
        fake_function = instance_double(Fiddle::Function)
        allow(Fiddle::Function).to receive(:new).and_return(fake_function)
        allow(fake_function).to receive(:call) { order << :pin }
        allow(Fiddle).to receive(:dlwrap).and_return(0)

        described_class.install!

        fake_loader.singleton_class.send(:alias_method, :__real_original, :__gtk_compaction_unpinned_register_boxed_class_converter)
        fake_loader.singleton_class.send(:define_method, :__gtk_compaction_unpinned_register_boxed_class_converter) do |gtype, &block|
          order << :forward
          __real_original(gtype, &block)
        end

        fake_loader.register_boxed_class_converter(:x) {}

        expect(order).to eq(%i[pin forward])
      end
    end
  end

  # ---------------------------------------------------------------------
  # safe_compact!
  # ---------------------------------------------------------------------
  describe '.safe_compact!' do
    def stub_compact_supported(supported)
      allow(GC).to receive(:respond_to?).and_call_original
      allow(GC).to receive(:respond_to?).with(:compact).and_return(supported)
      allow(GC).to receive(:compact)
    end

    it 'does not call GC.compact when GC does not respond_to?(:compact)' do
      stub_compact_supported(false)

      described_class.safe_compact!

      expect(GC).not_to have_received(:compact)
    end

    it 'does not evaluate gtk_loaded? at all when GC.compact is unsupported (short-circuits first)' do
      stub_compact_supported(false)
      allow(described_class).to receive(:gtk_loaded?)

      described_class.safe_compact!

      expect(described_class).not_to have_received(:gtk_loaded?)
    end

    it 'compacts unconditionally when gtk3 is not loaded' do
      stub_compact_supported(true)
      allow(described_class).to receive(:gtk_loaded?).and_return(false)

      described_class.safe_compact!

      expect(GC).to have_received(:compact)
    end

    it 'compacts when gtk3 is loaded and pinning is active, without consulting native_gem_patched?' do
      stub_compact_supported(true)
      allow(described_class).to receive(:gtk_loaded?).and_return(true)
      described_class.instance_variable_set(:@pinning_active, true)
      allow(described_class).to receive(:native_gem_patched?)

      described_class.safe_compact!

      expect(GC).to have_received(:compact)
      expect(described_class).not_to have_received(:native_gem_patched?)
    end

    it 'compacts when gtk3 is loaded, pinning is not active, but the installed gem is natively patched' do
      stub_compact_supported(true)
      allow(described_class).to receive(:gtk_loaded?).and_return(true)
      described_class.instance_variable_set(:@pinning_active, false)
      allow(described_class).to receive(:native_gem_patched?).and_return(true)

      described_class.safe_compact!

      expect(GC).to have_received(:compact)
    end

    it 'does NOT compact when gtk3 is loaded, pinning is not active, and the gem is not natively patched' do
      # This is the whole point of the module: the one combination where
      # compacting would risk a dangling-Proc crash.
      stub_compact_supported(true)
      allow(described_class).to receive(:gtk_loaded?).and_return(true)
      described_class.instance_variable_set(:@pinning_active, false)
      allow(described_class).to receive(:native_gem_patched?).and_return(false)

      described_class.safe_compact!

      expect(GC).not_to have_received(:compact)
    end

    it 'warns once when compaction is disabled for the rest of the process' do
      clear_memoized_state!
      stub_compact_supported(true)
      allow(described_class).to receive(:gtk_loaded?).and_return(true)
      allow(described_class).to receive(:native_gem_patched?).and_return(false)
      allow(described_class).to receive(:warn)

      described_class.safe_compact!
      described_class.safe_compact!
      described_class.safe_compact!

      expect(described_class).to have_received(:warn).once
    end

    it 'does not warn on any branch that actually compacts' do
      clear_memoized_state!
      stub_compact_supported(true)
      allow(described_class).to receive(:warn)

      allow(described_class).to receive(:gtk_loaded?).and_return(false)
      described_class.safe_compact!

      described_class.instance_variable_set(:@pinning_active, true)
      allow(described_class).to receive(:gtk_loaded?).and_return(true)
      described_class.safe_compact!

      expect(described_class).not_to have_received(:warn)
    end

    it 'treats pinning_active as false when never set (fresh/uninstalled state), not as an error' do
      # Adversarial: @pinning_active is only ever set inside install!. If
      # something calls safe_compact! before install! has run for this
      # process (shouldn't happen given lich.rbw's ordering, but "shouldn't
      # happen" is exactly what adversarial tests are for), an unset ivar
      # must read as falsy, not raise or blow up truthiness checks.
      clear_memoized_state!
      stub_compact_supported(true)
      allow(described_class).to receive(:gtk_loaded?).and_return(true)
      allow(described_class).to receive(:native_gem_patched?).and_return(false)

      expect { described_class.safe_compact! }.not_to raise_error
      expect(GC).not_to have_received(:compact)
    end
  end
end
