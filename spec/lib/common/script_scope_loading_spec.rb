# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/script_scope'
require 'open3'

RSpec.describe 'GTK-free Ruby dependency boundary' do
  let(:scope) { Lich::Common::ScriptScope }

  before do
    scope.activate!
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(nil)
  end

  it 'refuses native entrypoints outside script ownership instead of loading installed gems' do
    Dir.mktmpdir('gtk-entrypoints') do |root|
      %w[gtk3 glib2 gio2 cairo cairo-gobject cairo_gobject gobject-introspection gobject_introspection
         gi gtk4 gdk3 gdk_pixbuf2 pango atk].each do |feature|
        target = File.join(root, "#{feature}.rb")
        File.write(target, 'raise "native entrypoint sentinel executed"')
        expect { Kernel.require(target) }.to raise_error(scope::Gtk::UnsupportedOperation, /script=none.*native GTK loading is disabled/)
      end
    end
  end

  %w[gdk_pixbuf2/loader gdk_pixbuf2/pixbuf-loader gobject_introspection cairo_gobject gi].each do |feature|
    it "refuses #{feature} before executing a direct subload" do
      Dir.mktmpdir('gtk-direct-subload') do |root|
        stub_const('GTK_SUBLOAD_EXECUTED', [])
        $LOAD_PATH.unshift(root)
        target = File.join(root, "#{feature}.rb")
        FileUtils.mkdir_p(File.dirname(target))
        File.write(target, 'GTK_SUBLOAD_EXECUTED << true')

        expect { Kernel.require(target) }.to raise_error(scope::Gtk::UnsupportedOperation, /native GTK loading is disabled/)
        expect(GTK_SUBLOAD_EXECUTED).to be_empty
        expect($LOADED_FEATURES).not_to include(target)
      ensure
        $LOAD_PATH.delete(root)
      end
    end
  end

  it 'refuses platform extension spellings of the GTK dependency stack' do
    %w[gtk2 gtk3 gtk4 gdk2 gdk3 gdk4 gdk_pixbuf2 glib2 gio2 gobject_introspection cairo cairo_gobject pango atk].each do |feature|
      %w[so bundle dll].each do |extension|
        # Inspect the guard directly: a regression must not load installed binaries.
        expect do
          scope::Gtk::RequireBoundary.handled?("#{feature}.#{extension}", :require, caller_locations(0, 1).first)
        end.to raise_error(scope::Gtk::UnsupportedOperation)
      end
    end
  end

  it 'guards Ruby autoload when the deferred native feature is resolved' do
    Dir.mktmpdir('gtk-autoload') do |root|
      stub_const('GTK_AUTOLOAD_EXECUTED', [])
      target = File.join(root, 'gdk_pixbuf2.rb')
      File.write(target, 'GTK_AUTOLOAD_EXECUTED << true')
      namespace = Module.new
      namespace.autoload(:NativeProbe, target)

      expect { namespace.const_get(:NativeProbe) }.to raise_error(scope::Gtk::UnsupportedOperation)
      expect(GTK_AUTOLOAD_EXECUTED).to be_empty
    end
  end

  it 'rejects absolute loads, relative loads and native extensions before executing them' do
    Dir.mktmpdir('gtk-load-boundary') do |root|
      File.write(File.join(root, 'gtk3.rb'), 'raise "native sentinel executed"')
      File.write(File.join(root, 'relative_probe.rb'), "require_relative 'gtk3'\n")
      [-> { Kernel.load(File.join(root, 'gtk3.rb')) },
       -> { Kernel.require(File.join(root, 'relative_probe.rb')) },
       -> { Kernel.require('gtk3.bundle') },
       -> { Kernel.require('gtk3/loader') }].each do |load|
        expect(&load).to raise_error(scope::Gtk::UnsupportedOperation, /native GTK loading is disabled/)
      end
    end
  end

  it 'preserves ordinary helper loading, relative resolution, return values and wrapped loads' do
    Dir.mktmpdir('ordinary-load-boundary') do |root|
      stub_const('DEPENDENCY_BOUNDARY_EVENTS', [])
      File.write(File.join(root, 'child.rb'), 'DEPENDENCY_BOUNDARY_EVENTS << :child')
      helper = File.join(root, 'helper.rb')
      File.write(helper, "DEPENDENCY_BOUNDARY_EVENTS << require_relative('child')\n")
      expect(Kernel.require(helper)).to be(true)
      expect(Kernel.require(helper)).to be(false)
      expect(Kernel.load(helper, true)).to be(true)
      expect(DEPENDENCY_BOUNDARY_EVENTS).to eq([:child, true, false])
    end
  end

  it 'keeps Kernel instance loaders private and explicit module loaders public' do
    expect(Kernel.private_instance_methods).to include(:require, :require_relative, :load)
    expect(Kernel.public_methods).to include(:require, :require_relative, :load)
  end

  it 'preserves dependency loader aliases, loaded features and native refusals in a fresh process' do
    Dir.mktmpdir('aliased-load-boundary') do |root|
      File.write(File.join(root, 'cached.rb'), 'LOADER_EVENTS << :cached')
      File.write(File.join(root, 'child.rb'), 'LOADER_EVENTS << :child')
      File.write(File.join(root, 'gtk3.rb'), 'abort "native sentinel executed"')
      dependency = File.join(root, 'dependency.rb')
      File.write(dependency, <<~RUBY)
        module LoaderAliasDependency
          extend self
          alias original_require require
          alias original_require_relative require_relative
          alias original_load load

          def self.check
            cached = File.join(__dir__, 'cached.rb')
            child = File.join(__dir__, 'child.rb')
            results = [original_require(cached), original_require(child),
                       original_require(child), original_require_relative('child'),
                       original_load(child, true)]
            abort "loader results: \#{results.inspect}" unless results == [false, true, false, false, true]
            abort "loader events: \#{LOADER_EVENTS.inspect}" unless LOADER_EVENTS == [:cached, :child, :child]
            begin
              original_require(File.join(__dir__, 'missing.rb'))
              abort 'missing dependency accepted'
            rescue LoadError
            end
            begin
              original_require_relative('gtk3')
              abort 'native dependency accepted'
            rescue Lich::Common::ScriptScope::Gtk::UnsupportedOperation
            end
          end
        end
        LoaderAliasDependency.check
      RUBY
      source = <<~RUBY
        LOADER_EVENTS = []
        require File.join(File.dirname(ARGV.fetch(0)), 'cached.rb')
        Lich::Common::ScriptScope.activate!
        require ARGV.fetch(0)
        abort 'instance loaders became public' unless [:require, :require_relative, :load].all? { |name| Kernel.private_instance_methods.include?(name) }
        abort 'module loaders became private' unless [:require, :require_relative, :load].all? { |name| Kernel.public_methods.include?(name) }
      RUBY
      output, status = Open3.capture2e(RbConfig.ruby, '-I', File.expand_path('../../../lib', __dir__),
                                       '-rcommon/script_scope', '-e', source, dependency)
      expect(status.success?).to be(true), output
    end
  end

  it 'loads ordinary files beneath GTK-like installation directories without widening native admission' do
    Dir.mktmpdir('ordinary-install') do |root|
      stub_const('ORDINARY_INSTALL_EVENTS', [])
      %w[Gi ATK Cairo pango gdk].each do |directory|
        base = File.join(root, directory, 'lich', 'lib')
        FileUtils.mkdir_p(base)
        File.write(File.join(base, 'child.rb'), 'ORDINARY_INSTALL_EVENTS << :child')
        File.write(File.join(base, 'parent.rb'), "require_relative 'child'\n")
        expect(Kernel.require(File.join(base, 'parent.rb'))).to be(true)
        expect(Kernel.load(File.join(base, 'child.rb'), true)).to be(true)
      end
      expect(ORDINARY_INSTALL_EVENTS).to eq([:child] * 10)
      expect(scope::Gtk::RequireBoundary.handled?('C:\\Users\\ATK\\Lich\\lib\\games.rb', :load, caller_locations.first)).to be(false)
    end
  end
end
