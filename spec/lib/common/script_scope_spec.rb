# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/limitedarray'
require 'webui'
require 'common/script_scope'
require 'common/script_scope/gtk/boot'

RSpec.describe Lich::Common::ScriptScope do
  let(:scope) { described_class }
  let(:gtk) { scope::Gtk }
  let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('scope') }
  let(:service) { Lich::WebUI::Service.new }
  let(:session) { gtk::Session.new(owner, service: service) }

  before do
    gtk::Session.browser_open = proc { |_url, on_start:, **| on_start.call(1); true }
    allow(gtk::Session).to receive(:for).with(anything).and_return(session)
  end

  after do
    gtk::Session.browser_open = nil
    session.shutdown
    service.stop
  end

  # Evaluates +source+ in a script binding with nested-constant adoption on,
  # the way a running script has it, and removes the constants it defined.
  def as_script(source, *constants)
    scope.instance_variable_set(:@adopt_nested_constants, true)
    session.sync { eval(source, scope.script_binding) }
  ensure
    scope.instance_variable_set(:@adopt_nested_constants, false)
    constants.each { |name| scope.send(:remove_const, name) if scope.const_defined?(name, false) }
  end

  # A script class that subclasses a shim widget gets its helpers through
  # InheritedHelpers, a module `include`d on the class. Ruby places an
  # included module directly above the class, so its method_missing runs
  # BEFORE Gtk::Widget#method_missing: a real inherited method still wins
  # (it is found before any method_missing), but a helper that shares a
  # name with an unimplemented GTK call is reached rather than degraded.
  describe 'InheritedHelpers' do
    it 'reaches a top-level helper from a script class that subclasses a shim widget' do
      result = as_script(<<~SCRIPT, :ScopeSpecWindow)
        def __scope_spec_title = "FROM-HELPER"

        class ScopeSpecWindow < Gtk::Window
          def initialize
            super(__scope_spec_title)
          end

          def helper_reaches = __scope_spec_title
        end

        window = ScopeSpecWindow.new
        [window.helper_reaches, window.title, window.class.superclass == Gtk::Window]
      SCRIPT

      expect(result).to eq(['FROM-HELPER', 'FROM-HELPER', true])
    end

    it 'reaches a top-level helper from a class nested two modules deep' do
      result = as_script(<<~SCRIPT, :ScopeSpecFoo)
        def __scope_spec_deep = "DEEP"

        module ScopeSpecFoo
          module Bar
            class Baz
              def go = __scope_spec_deep
            end
          end
        end

        ScopeSpecFoo::Bar::Baz.new.go
      SCRIPT

      expect(result).to eq('DEEP')
    end

    it 'lets a helper answer before the shim degrades an unimplemented call on a subclass' do
      result = as_script(<<~SCRIPT, :ScopeSpecPreempt)
        def set_some_gtk_thing_the_shim_lacks = "HELPER-FIRST"

        class ScopeSpecPreempt < Gtk::Window
          def go = set_some_gtk_thing_the_shim_lacks
        end

        [ScopeSpecPreempt.new("t").go, ScopeSpecPreempt.ancestors]
      SCRIPT

      answer, ancestors = result
      expect(answer).to eq('HELPER-FIRST')
      expect(ancestors.index(scope::InheritedHelpers)).to be < ancestors.index(gtk::Widget)
    end

    it 'still lets a real inherited method win over a same-named helper' do
      result = as_script(<<~SCRIPT, :ScopeSpecShadow)
        def title = "SHADOW"

        class ScopeSpecShadow < Gtk::Window
          def go = title
        end

        ScopeSpecShadow.new("REAL").go
      SCRIPT

      expect(result).to eq('REAL')
    end
  end

  # The one core symbol the scope touches. Loaded here rather than at file
  # level so the rest of the suite never sees Script; the other script specs
  # do the same.
  describe 'Script.__trusted_binding' do
    before(:context) do
      require_relative '../../../lib/common/script'
    end

    after(:context) do
      %i[SubScript ExecScript WizardScript Script Scripting TRUSTED_SCRIPT_BINDING].each do |const_name|
        Lich::Common.send(:remove_const, const_name) if Lich::Common.const_defined?(const_name, false)
      end
      $LOADED_FEATURES.delete_if { |path| path.end_with?('/lib/common/script.rb') }
    end

    def with_scope_active(active)
      previous = scope.instance_variable_get(:@active)
      scope.instance_variable_set(:@active, active)
      yield
    ensure
      scope.instance_variable_set(:@active, previous)
    end

    # TRUSTED_SCRIPT_BINDING calls `_script` on Lich::Common itself, which
    # only resolves because production includes Lich::Common into Object.
    # The suite does not, so the branch is proved in two halves: the
    # delegation, and the cref of the binding _script hands out.
    it 'hands out the historical Lich::Common binding while the scope is inactive' do
      with_scope_active(false) do
        historical = Object.new
        allow(Lich::Common::TRUSTED_SCRIPT_BINDING).to receive(:call).and_return(historical)

        expect(Lich::Common::Script.__trusted_binding).to be(historical)
      end
    end

    it "resolves constants through Lich::Common in the historical binding, not through the scope" do
      includer = Class.new { include Lich::Common }.new
      binding = includer._script

      expect(eval('Module.nesting', binding)).to eq([Lich::Common, Lich])
      expect(eval('defined?(ScriptScope::Gtk::Window)', binding)).to be_truthy
      expect(eval('defined?(Gtk) && Gtk', binding)).not_to be(gtk)
    end

    it 'hands out a ScriptScope binding while the scope is active' do
      with_scope_active(true) do
        binding = Lich::Common::Script.__trusted_binding

        expect(eval('Module.nesting', binding).first).to be(scope)
        expect(eval('Gtk', binding)).to be(gtk)
      end
    end

    it 'gives every script its own local-variable table' do
      with_scope_active(true) do
        first = Lich::Common::Script.__trusted_binding
        second = Lich::Common::Script.__trusted_binding
        eval('scope_spec_local = 1', first)

        expect(first.local_variable_defined?(:scope_spec_local)).to be(true)
        expect(second.local_variable_defined?(:scope_spec_local)).to be(false)
      end
    end
  end
end
