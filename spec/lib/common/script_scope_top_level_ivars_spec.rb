# frozen_string_literal: true

require_relative '../../spec_helper'
require 'open3'
require 'rbconfig'

# A plain script's top-level instance variables land on ScriptScope itself, the
# receiver of script_binding. The module's own state must not share those names.
RSpec.describe 'ScriptScope state versus script top-level instance variables' do
  # Every instance variable the module used for its own state before the
  # state names were made collision-proof.
  let(:former_state_names) do
    %i[
      @active @activation_failure @activation_mutex @core_aliases @adopt_nested_constants
      @legacy_helpers @legacy_constants @legacy_notices @plugin_names @plugin_modules @concealed_names
    ]
  end
  let(:lib_dir) { File.expand_path('../../../lib', __dir__) }

  def run_in_fresh_process(body)
    code = <<~RUBY_CODE
      require 'common/script_scope'
      scope = Lich::Common::ScriptScope
      scope.activate!
      #{body}
      puts 'ready'
    RUBY_CODE
    output, status = Open3.capture2e(RbConfig.ruby, '-I', lib_dir, '-e', code)
    expect(status.success?).to be(true), output
    expect(output).to eq("ready\n")
  end

  it 'keeps scope active, activation idempotent and core constant syncing on after a script sets @active and @core_aliases' do
    run_in_fresh_process(<<~'BODY')
      eval('@active = false; @core_aliases = nil', scope.script_binding)
      abort 'script ivar did not land on the shared receiver' unless scope.instance_variable_get(:@active) == false
      abort 'active? changed' unless scope.active? == true
      abort 'activate! not idempotent' unless scope.activate! == true
      Lich::Common.const_set(:LateCoreProbe, Object.new)
      probe = Lich::Common.const_get(:LateCoreProbe, false)
      abort 'late core constant not synced' unless scope.const_defined?(:LateCoreProbe, false) && scope.const_get(:LateCoreProbe, false).equal?(probe)
      abort 'late core constant not visible to a script' unless eval('LateCoreProbe', scope.script_binding).equal?(probe)
    BODY
  end

  it 'is unaffected by a script that sets every name the module formerly used for its own state' do
    assignments = former_state_names.map { |name| "#{name} = nil" }.join('; ')
    run_in_fresh_process(<<~BODY)
      eval(#{assignments.inspect}, scope.script_binding)
      abort 'active? changed' unless scope.active? == true
      abort 'activate! not idempotent' unless scope.activate! == true
      Lich::Common.const_set(:LateCoreProbe, Object.new)
      probe = Lich::Common.const_get(:LateCoreProbe, false)
      abort 'late core constant not synced' unless scope.const_get(:LateCoreProbe, false).equal?(probe)
      abort 'script constant lost adoption' unless eval('module ScriptOwnedProbe; end; ScriptOwnedProbe', scope.script_binding).include?(scope)
      abort 'legacy export lost' unless Object.const_defined?(:ScriptOwnedProbe)
      eval('def probe_helper = :helper', scope.script_binding)
      abort 'legacy helper lost' unless 1.probe_helper == :helper
    BODY
  end
end
