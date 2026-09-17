# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/limitedarray'
require 'tmpdir'
require 'common/script_scope'

RSpec.describe Lich::Common::ScriptScope do
  let(:scope) { described_class }

  def with_scope_active(active)
    previous = scope.instance_variable_get(:@active)
    scope.instance_variable_set(:@active, active)
    yield
  ensure
    scope.instance_variable_set(:@active, previous)
  end

  describe '.activate!' do
    it 'loads every plugin boot file the glob finds, once, and reports active' do
      Dir.mktmpdir('script-scope-') do |dir|
        boot = File.join(dir, 'boot.rb')
        File.write(boot, "$script_scope_spec_booted = ($script_scope_spec_booted || 0) + 1\n")
        stub_const('Lich::Common::ScriptScope::PLUGIN_GLOB', File.join(dir, '*.rb'))
        $script_scope_spec_booted = 0

        with_scope_active(false) do
          expect(scope.activate!).to be(true)
          expect(scope.active?).to be(true)
          expect(scope.activate!).to be(true)
        end
        expect($script_scope_spec_booted).to eq(1)
      ensure
        $LOADED_FEATURES.delete_if { |path| path.start_with?(dir) }
        $script_scope_spec_booted = nil
      end
    end
  end

  describe '.script_binding' do
    it 'resolves bare constants through ScriptScope, then Lich::Common, then Lich' do
      binding = scope.script_binding

      expect(eval('Module.nesting', binding)).to eq([scope, Lich::Common, Lich])
      expect(eval('LimitedArray', binding)).to be(Lich::Common::LimitedArray)
    end

    it 'gives every script its own local-variable table' do
      first = scope.script_binding
      second = scope.script_binding
      eval('scope_spec_local = 1', first)

      expect(first.local_variable_defined?(:scope_spec_local)).to be(true)
      expect(second.local_variable_defined?(:scope_spec_local)).to be(false)
    end
  end

  # The one place the series touches core. It must hand out exactly the
  # historical binding while the scope is inactive, and the scope's while
  # it is active.
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

    it 'resolves constants through Lich::Common in the historical binding, not through the scope' do
      includer = Class.new { include Lich::Common }.new
      binding = includer._script

      expect(eval('Module.nesting', binding)).to eq([Lich::Common, Lich])
    end

    it 'hands out a ScriptScope binding while the scope is active' do
      with_scope_active(true) do
        binding = Lich::Common::Script.__trusted_binding

        expect(eval('Module.nesting', binding).first).to be(scope)
      end
    end
  end
end
