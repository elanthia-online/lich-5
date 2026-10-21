# frozen_string_literal: true

require 'ostruct'

# Tests for global functions and sentinels added to global_defs.rb.
#
# get_settings and get_data are trivial one-line delegators to $setupfiles
# and are tested indirectly via the SetupFiles specs. This spec focuses on:
# 1. Sentinel constants (CORE_GET_SETTINGS, CORE_SCRIPT_LOADER) are defined
# 2. start_scripts_if_available behavior (the non-trivial function)
#
# The extracted function calls Script, start_script and pause; the shared
# stubs in spec_helper provide them (Kernel#start_script, Kernel#pause).
# Do not define top-level stubs here: a top-level `def` is a private method
# owned by Object, and in the same process it shadows the Kernel stubs and
# breaks allow_any_instance_of(Object) overrides in other files (for example
# common_moonmage_spec's check_moonwatch examples).
require_relative '../../spec_helper'
require_relative '../../support/global_defs_spec_source'

# Load the sentinel constants and start_scripts_if_available from global_defs.rb
GlobalDefsSpecSource.eval_toplevel_block('Sentinel constants for dependency')
GlobalDefsSpecSource.define_toplevel('start_scripts_if_available')

RSpec.describe 'global_defs.rb sentinel constants' do
  describe 'CORE_GET_SETTINGS' do
    it 'is defined in Lich::Common' do
      expect(Lich::Common.const_defined?(:CORE_GET_SETTINGS, false)).to be true
    end
  end

  describe 'CORE_SCRIPT_LOADER' do
    it 'is defined in Lich::Common' do
      expect(Lich::Common.const_defined?(:CORE_SCRIPT_LOADER, false)).to be true
    end
  end
end

RSpec.describe 'global_defs.rb function definitions' do
  it 'defines get_settings as a top-level function' do
    expect(GlobalDefsSpecSource.line_of('get_settings')).to be_a(Integer)
  end

  it 'defines get_data as a top-level function' do
    expect(GlobalDefsSpecSource.line_of('get_data')).to be_a(Integer)
  end

  it 'get_settings delegates to $setupfiles' do
    expect(GlobalDefsSpecSource.method_source('get_settings').first).to include('$setupfiles.get_settings')
  end

  it 'get_data delegates to $setupfiles' do
    expect(GlobalDefsSpecSource.method_source('get_data').first).to include('$setupfiles.get_data')
  end

  it 'get_settings and get_data lazy-initialize $setupfiles' do
    %w[get_settings get_data].each do |name|
      expect(GlobalDefsSpecSource.method_source(name).first).to match(/\$setupfiles\s*\|\|=/)
    end
  end
end

RSpec.describe '#start_scripts_if_available' do
  before do
    allow(Script).to receive(:running?).and_return(false)
    allow(Script).to receive(:exists?).and_return(true)
  end

  it 'checks if each script exists before starting' do
    start_scripts_if_available('moonwatch')
    expect(Script).to have_received(:exists?).with('moonwatch')
  end

  it 'checks if each script is already running' do
    start_scripts_if_available('moonwatch')
    expect(Script).to have_received(:running?).with('moonwatch').at_least(:once)
  end

  it 'accepts an array of script names and checks each' do
    start_scripts_if_available(%w[moonwatch textsubs])
    expect(Script).to have_received(:exists?).with('moonwatch')
    expect(Script).to have_received(:exists?).with('textsubs')
  end

  it 'skips scripts that are already running' do
    allow(Script).to receive(:running?).with('moonwatch').and_return(true)
    start_scripts_if_available('moonwatch')
    expect(Script).not_to have_received(:exists?).with('moonwatch')
  end

  it 'skips scripts that do not exist' do
    allow(Script).to receive(:exists?).with('nonexistent').and_return(false)
    expect { start_scripts_if_available('nonexistent') }.not_to raise_error
  end

  it 'handles empty array without error' do
    expect { start_scripts_if_available([]) }.not_to raise_error
    expect(Script).not_to have_received(:running?)
  end

  it 'calls start_script for scripts that exist and are not running' do
    allow(self).to receive(:start_script)
    start_scripts_if_available('moonwatch')
    expect(self).to have_received(:start_script).with('moonwatch')
  end

  it 'handles single string argument (auto-wraps to array)' do
    start_scripts_if_available('moonwatch')
    expect(Script).to have_received(:exists?).with('moonwatch').at_least(:once)
  end

  it 'handles nil input without error' do
    expect { start_scripts_if_available(nil) }.not_to raise_error
    expect(Script).not_to have_received(:running?)
  end

  it 'filters nil values from arrays' do
    start_scripts_if_available(['moonwatch', nil, 'textsubs'])
    expect(Script).to have_received(:exists?).with('moonwatch')
    expect(Script).to have_received(:exists?).with('textsubs')
    expect(Script).not_to have_received(:exists?).with(nil)
  end
end
