# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/script_scope'
require 'open3'
require 'fileutils'
require 'tmpdir'

RSpec.describe Lich::Common::ScriptScope do
  it 'isolates locals, including file, between fresh script bindings' do
    first = described_class.script_binding
    second = described_class.script_binding
    eval('file = :first; local_value = 1', first)

    expect(second.local_variable_defined?(:file)).to be(false)
    expect(second.local_variable_defined?(:local_value)).to be(false)
  end

  it 'resolves core constants without importing class methods into the script' do
    stub_const('Lich::Common::ScopeCoreExample', Class.new do
      def self.class_only = :class_method
    end)
    binding = described_class.script_binding

    expect(eval('ScopeCoreExample.class_only', binding)).to eq(:class_method)
    expect { eval('class_only', binding) }.to raise_error(NameError)
  end

  it 'forwards only declared helpers to inherited script instances' do
    described_class.activate!
    instances = eval(<<~RUBY, described_class.script_binding)
      def scope_runtime_helper; :helper; end
      ScopeRuntimeStruct = Struct.new(:value)
      ScopeRuntimeData = Data.define(:value)
      class ScopeRuntimeError < StandardError; end
      [ScopeRuntimeStruct.new(1), ScopeRuntimeData.new(1), ScopeRuntimeError.new]
    RUBY
    instances.each do |instance|
      expect(instance.scope_runtime_helper).to eq(:helper)
      expect(instance.respond_to?(:scope_runtime_helper)).to be(true)
      expect(instance.respond_to?(:const_get)).to be(false)
      expect(instance.respond_to?(:name)).to be(false)
      expect { instance.const_get(:Gtk) }.to raise_error(NoMethodError)
    end
  ensure
    %i[ScopeRuntimeStruct ScopeRuntimeData ScopeRuntimeError].each do |name|
      described_class.send(:remove_const, name) if described_class.const_defined?(name, false)
    end
    described_class.send(:remove_method, :scope_runtime_helper) if described_class.instance_methods(false).include?(:scope_runtime_helper)
  end

  it 'forwards positional and keyword arguments separately to a helper called from a subclass' do
    described_class.activate!
    result = eval(<<~RUBY, described_class.script_binding)
      def scope_keyword_helper(value, scale: 1, &block) = [value, scale, block&.call]
      class ScopeKeywordError < StandardError
        def probe = [scope_keyword_helper(2, scale: 3) { :block }, scope_keyword_helper({ scale: 5 })]
      end
      ScopeKeywordError.new.probe
    RUBY
    expect(result).to eq([[2, 3, :block], [{ scale: 5 }, 1, nil]])
  ensure
    described_class.send(:remove_const, :ScopeKeywordError) if described_class.const_defined?(:ScopeKeywordError, false)
    described_class.send(:remove_method, :scope_keyword_helper) if described_class.instance_methods(false).include?(:scope_keyword_helper)
  end

  it 'reports a failed plugin boot as a StandardError and never retries into partial state' do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'broken'))
      File.write(File.join(dir, 'broken', 'boot.rb'), <<~RUBY)
        $boot_attempts = ($boot_attempts || 0) + 1
        module Lich::Common::ScriptScope::BrokenPlugin; end
        raise LoadError, 'native dependency missing'
      RUBY
      source = <<~'RUBY'
        scope = Lich::Common::ScriptScope
        scope.send(:remove_const, :PLUGIN_GLOB)
        scope.const_set(:PLUGIN_GLOB, File.join(ARGV.fetch(0), '*', 'boot.rb'))
        errors = Array.new(2) do
          scope.activate!
          :activated
        rescue StandardError => error
          error
        end
        abort errors.inspect unless errors.all?(scope::ScopeActivationError)
        abort "retried #{$boot_attempts}" unless $boot_attempts == 1
        abort 'failure cause lost' unless errors.first.cause.is_a?(LoadError) && errors.last.message.include?('LoadError')
        abort 'activated after failure' if scope.active?
        abort 'hooks installed' if Object.ancestors.include?(scope::LegacyConstants) || Object.ancestors.include?(scope::LegacyHelpers)
      RUBY
      output, status = Open3.capture2e(RbConfig.ruby, '-I', File.expand_path('../../../lib', __dir__),
                                       '-rcommon/script_scope', '-e', source, dir)
      expect(status.success?).to be(true), output
    end
  end

  it 'does not mutate Comparable or core classes through a script constant alias' do
    source = <<~RUBY
      scope = Lich::Common::ScriptScope
      scope.activate!
      ancestors = [Comparable, String, Integer].map(&:ancestors)
      eval('def scope_alias_probe; :leaked; end; RuntimeComparable = ::Comparable', scope.script_binding)
      abort 'core ancestors changed' unless [Comparable, String, Integer].map(&:ancestors) == ancestors
      abort 'helper installed on core' if String.instance_methods(false).include?(:scope_alias_probe) || Integer.instance_methods(false).include?(:scope_alias_probe)
      abort 'scope mixed into core' if String.ancestors.include?(scope) || Integer.ancestors.include?(scope)
    RUBY
    # A regression must not contaminate the parent suite's core ancestors.
    output, status = Open3.capture2e(RbConfig.ruby, '-I', File.expand_path('../../../lib', __dir__),
                                     '-rcommon/script_scope', '-e', source)
    expect(status.success?).to be(true), output
  end

  it 'keeps newly defined nested script classes connected to their helpers' do
    described_class.activate!
    result = eval(<<~RUBY, described_class.script_binding)
      def scope_nested_probe; :available; end
      module RuntimeNamespace
        class Leaf
          def probe; scope_nested_probe; end
        end
      end
      RuntimeNamespace::Leaf.new.probe
    RUBY
    expect(result).to eq(:available)
  ensure
    described_class.send(:remove_const, :RuntimeNamespace) if described_class.const_defined?(:RuntimeNamespace, false)
    described_class.send(:remove_method, :scope_nested_probe) if described_class.instance_methods(false).include?(:scope_nested_probe)
  end

  it 'keeps a method defined by the script immediately callable' do
    binding = described_class.script_binding
    expect(eval('def scope_redux_helper; 42; end; scope_redux_helper', binding)).to eq(42)
  ensure
    described_class.send(:remove_method, :scope_redux_helper) if described_class.instance_methods(false).include?(:scope_redux_helper)
  end
  it 'preserves core reopening and legacy lookup across sequential scripts without exporting plugins' do
    source = <<~'RUBY'
      module Lich::Common
        class ScopeChar
          def self.core = :core
        end
      end
      scope = Lich::Common::ScriptScope
      scope.activate!
      original = Lich::Common::ScopeChar
      ancestors = original.ancestors
      eval('class ScopeChar; def self.polyfill = :patched; end', scope.script_binding, 'polyfill.lic')
      abort 'shadowed core class' unless eval('ScopeChar.core', scope.script_binding) == :core
      abort 'core patch missing' unless original.polyfill == :patched && original.ancestors == ancestors
      # Game-specific classes can arrive after the first script has started.
      module Lich::Common
        class ScopeMap
          def self.core = :map
        end
      end
      eval('class ScopeMap; def self.route = :route; end', scope.script_binding, 'map.lic')
      abort 'late core shadow' unless Lich::Common::ScopeMap.route == :route
      eval('LegacyNumber = 42; class LegacyHelper; end; def percent_of(total:) = self * 100 / total', scope.script_binding, 'helpers.lic')
      result = eval('[defined?(::LegacyHelper), Object.const_defined?(:LegacyHelper), ::LegacyNumber, 10.percent_of(total: 20)]', scope.script_binding, 'consumer.lic')
      abort result.inspect unless result == ['constant', true, 42, 50]
      eval('PluginAlias = Gtk; WidgetAlias = Gtk::Window', scope.script_binding)
      abort 'aliased plugin export' if Object.const_defined?(:PluginAlias) || Object.const_defined?(:WidgetAlias)
      scope.const_set(:LegacyHelper, scope::Gtk)
      abort 'stale export after plugin reassignment' if Object.const_defined?(:LegacyHelper)
      abort 'plugin export' if Object.const_defined?(:Gtk) || Object.const_defined?(:GLib) || Object.const_defined?(:LegacyHelpers)
      abort 'scope mixed into core' if String.ancestors.include?(scope) || Integer.ancestors.include?(scope)
      scope.send(:remove_const, :LegacyNumber)
      abort 'stale export' if Object.const_defined?(:LegacyNumber)
      scope.send(:remove_method, :percent_of)
      abort 'stale helper' if 10.respond_to?(:percent_of)
      eval('LegacyNumber = 43; def percent_of(total:) = :replacement', scope.script_binding)
      abort 'stale redefinition' unless ::LegacyNumber == 43 && 10.percent_of(total: 20) == :replacement
      eval('def to_s = :wrong', scope.script_binding)
      abort 'overrode real method' unless 10.to_s == '10'
    RUBY
    output, status = Open3.capture2e(RbConfig.ruby, '-I', File.expand_path('../../../lib', __dir__),
                                     '-rcommon/script_scope', '-e', source)
    expect(status.success?).to be(true), output
  end

  describe 'top-level include of script modules' do
    # Runs the same source in the script scope and in an ordinary module, so
    # Ruby's own include is the oracle.
    def scoped_and_native(source, probe)
      described_class.activate!
      native = Module.new.module_eval("#{source}; extend self; #{probe}")
      [eval("#{source}; #{probe}", described_class.script_binding), native]
    end

    after do
      described_class.constants(false).grep(/\AIncludeCase/).each { |name| described_class.send(:remove_const, name) }
      (described_class.instance_methods(false) + described_class.private_instance_methods(false)).grep(/\Ainclude_case/).each do |name|
        described_class.send(:remove_method, name)
      end
    end

    it 'gives the first module of one include call precedence' do
      scoped, native = scoped_and_native(<<~RUBY, 'include_order_lookup')
        module IncludeCaseOrderA; def include_order_lookup = :alpha; end
        module IncludeCaseOrderB; def include_order_lookup = :beta; end
        include IncludeCaseOrderA, IncludeCaseOrderB
      RUBY
      expect(native).to eq(:alpha)
      expect(scoped).to eq(native)
    end

    it 'gives the most recently included module precedence' do
      scoped, native = scoped_and_native(<<~RUBY, 'include_successive_lookup')
        module IncludeCaseLaterB; def include_successive_lookup = :beta; end
        include IncludeCaseLaterB
        module IncludeCaseLaterA; def include_successive_lookup = :alpha; end
        include IncludeCaseLaterA
      RUBY
      expect(native).to eq(:alpha)
      expect(scoped).to eq(native)
    end

    it 'reaches a helper and a constant the included module itself includes' do
      scoped, native = scoped_and_native(<<~RUBY, '[include_indirect_lookup, INCLUDE_INDIRECT_LIMIT]')
        module IncludeCaseMixin
          INCLUDE_INDIRECT_LIMIT = 7
          def include_indirect_lookup = [:mixin, include_indirect_base]
          def include_indirect_base = :base
        end
        module IncludeCaseOuter
          include IncludeCaseMixin
          def include_indirect_lookup = [:outer, super]
        end
        include IncludeCaseOuter
      RUBY
      expect(native).to eq([[:outer, [:mixin, :base]], 7])
      expect(scoped).to eq(native)
    end

    it 'keeps a method the script declares itself ahead of every included module' do
      scoped, native = scoped_and_native(<<~RUBY, 'include_case_direct')
        module IncludeCaseShadowed; def include_case_direct = :included; end
        def include_case_direct = :direct
        include IncludeCaseShadowed
      RUBY
      expect(native).to eq(:direct)
      expect(scoped).to eq(native)
    end

    it 'shows methods and constants added to a module after it was included' do
      scoped, native = scoped_and_native(<<~RUBY, '[include_late_lookup, include_late_changed, INCLUDE_LATE_VALUE, respond_to?(:include_late_removed)]')
        module IncludeCaseLate
          def include_late_changed = :old
          def include_late_removed = :gone
        end
        include IncludeCaseLate
        module IncludeCaseLate
          INCLUDE_LATE_VALUE = 5
          def include_late_lookup = :late
          def include_late_changed = :new
          remove_method :include_late_removed
        end
      RUBY
      expect(native).to eq([:late, :new, 5, false])
      expect(scoped).to eq(native)
    end

    it 'forwards an included public helper to a script class with a real superclass' do
      described_class.activate!
      result = eval(<<~RUBY, described_class.script_binding)
        module IncludeCaseForwarded
          def include_forwarded_helper = :forwarded

          private

          def include_forwarded_private = :private
        end
        include IncludeCaseForwarded
        class IncludeCaseError < StandardError
          def probe = [include_forwarded_helper, respond_to?(:include_forwarded_helper), respond_to?(:include_forwarded_private)]
        end
        IncludeCaseError.new.probe
      RUBY
      expect(result).to eq([:forwarded, true, false])
    end

    it 'raises TypeError for a class, as Ruby does, and includes nothing from the call' do
      described_class.activate!
      script = described_class.script_binding
      eval(<<~RUBY, script)
        module IncludeCasePartial; def include_partial_lookup = :partial; end
        class IncludeCaseClass
          def include_class_lookup = :class
        end
      RUBY
      expect { Module.new.include(Class.new) }.to raise_error(TypeError, /expected Module/)
      expect { eval('include IncludeCasePartial, IncludeCaseClass', script) }.to raise_error(TypeError, /wrong argument type Class \(expected Module\)/)
      expect { eval('include_class_lookup', script) }.to raise_error(NameError)
      expect { eval('include_partial_lookup', script) }.to raise_error(NameError)
    end

    it 'raises ArgumentError for an include without arguments, as Ruby does' do
      described_class.activate!
      expect { eval('include', described_class.script_binding) }.to raise_error(ArgumentError)
    end
  end
end
