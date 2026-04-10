# frozen_string_literal: true

require 'ostruct'

# Tests for global functions and sentinels added to global_defs.rb.
#
# get_settings and get_data are trivial one-line delegators to $setupfiles
# and are tested indirectly via the SetupFiles specs. This spec focuses on:
# 1. Sentinel constants (CORE_GET_SETTINGS, CORE_SCRIPT_LOADER) are defined
# 2. start_scripts_if_available behavior (the non-trivial function)
#
# Designed to run both standalone and as part of the full suite alongside
# spec_helper-based specs.

# Minimal stubs for runtime dependencies used by the extracted function
class Script; end unless defined?(Script)
def start_script(*_args); end unless defined?(start_script)
def pause(_seconds = 0); end unless respond_to?(:pause)

# Load the sentinel constants and start_scripts_if_available from global_defs.rb
dep_path = File.join(File.dirname(__FILE__), '..', '..', '..', 'lib', 'global_defs.rb')
dep_lines = File.readlines(dep_path)

# Extract the sentinel constants block
sentinel_start = dep_lines.index { |l| l =~ /Sentinel constants for dependency/ }
if sentinel_start
  ends_found = 0
  sentinel_end = nil
  (sentinel_start..dep_lines.length - 1).each do |i|
    ends_found += 1 if dep_lines[i].strip == 'end'
    if ends_found == 2
      sentinel_end = i
      break
    end
  end
  eval(dep_lines[sentinel_start..sentinel_end].join, TOPLEVEL_BINDING, dep_path, sentinel_start + 1)
end

# Extract start_scripts_if_available
fn_start = dep_lines.index { |l| l =~ /^def start_scripts_if_available\b/ }
fn_end = dep_lines[fn_start + 1..].index { |l| l =~ /^end\s*$/ }
eval(dep_lines[fn_start..fn_start + 1 + fn_end].join, TOPLEVEL_BINDING, dep_path, fn_start + 1)

# Verify get_settings and get_data exist in the source (structural test)
GET_SETTINGS_DEFINED = dep_lines.any? { |l| l =~ /^def get_settings\b/ }
GET_DATA_DEFINED = dep_lines.any? { |l| l =~ /^def get_data\b/ }

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
    expect(GET_SETTINGS_DEFINED).to be true
  end

  it 'defines get_data as a top-level function' do
    expect(GET_DATA_DEFINED).to be true
  end

  it 'get_settings delegates to $setupfiles' do
    source = dep_lines.select { |l| l =~ /\$setupfiles/ }
    expect(source.any? { |l| l.include?('$setupfiles.get_settings') }).to be true
  end

  it 'get_data delegates to $setupfiles' do
    source = dep_lines.select { |l| l =~ /\$setupfiles/ }
    expect(source.any? { |l| l.include?('$setupfiles.get_data') }).to be true
  end

  it 'get_settings lazy-initializes $setupfiles' do
    source = dep_lines.select { |l| l =~ /\$setupfiles\s*\|\|=/ }
    expect(source).not_to be_empty
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
