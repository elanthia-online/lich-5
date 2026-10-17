# frozen_string_literal: true

require_relative 'spec_helper'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

# spec_helper's per-example reset must run before a group's own before hooks
# whether the group was defined before or after spec_helper loaded. A group is
# defined first when parallel_rspec loads a spec file that does not require
# spec_helper ahead of every file that does. That load order needs a fresh
# process, so these examples run a throwaway spec file through a child RSpec
# process and check what its examples saw.
RSpec.describe 'spec_helper reset hook load order' do
  probe_source = <<~'RUBY'
    # frozen_string_literal: true

    # Defined before spec_helper loads. Like the settings specs, the group
    # stubs Script with a module that has no current= and sets up state the
    # reset clears; if the reset ran after these hooks it would raise on
    # Script.current = nil, and without the stub it would wipe the buffer.
    RSpec.describe 'early group' do
      before do
        stub_const('Script', Module.new)
        $_SERVERBUFFER_ << 'set by the group'
      end

      it('keeps its own before-hook setup') { expect($_SERVERBUFFER_).to eq(['set by the group']) }

      context 'nested' do
        it('keeps its own before-hook setup') { expect($_SERVERBUFFER_).to eq(['set by the group']) }
      end
    end

    RSpec.describe 'early group without a Script stub' do
      before { $_SERVERBUFFER_ << 'set by the group' }

      it('keeps its own before-hook setup') { expect($_SERVERBUFFER_).to eq(['set by the group']) }
    end

    require ENV.fetch('LOAD_ORDER_SPEC_HELPER')
    RSpec.configure { |config| config.example_status_persistence_file_path = nil }

    RSpec.describe 'late group' do
      before do
        stub_const('Script', Module.new)
        $_SERVERBUFFER_ << 'set by the group'
      end

      it('keeps its own before-hook setup') { expect($_SERVERBUFFER_).to eq(['set by the group']) }
    end
  RUBY

  # One child run serves every example below, so whichever example runs first
  # pays for one child RSpec boot plus a spec_helper load (a few tenths of a
  # second today). That cost grows with whatever spec_helper loads; if it ever
  # nears the slow-example warning threshold, tag the group :slow.
  cached_result = nil
  define_method(:probe_result) do
    cached_result ||= Dir.mktmpdir('load-order-probe') do |dir|
      file = File.join(dir, 'load_order_probe_spec.rb')
      File.write(file, probe_source)
      result = File.join(dir, 'result.json')
      # An empty options file stands in for ~/.rspec, .rspec and .rspec-local,
      # and SPEC_OPTS is cleared, so a developer's --fail-fast or extra
      # formatter cannot change what the probe runs or reports.
      options = File.join(dir, 'options')
      File.write(options, '')
      root = File.expand_path('..', __dir__)
      env = { 'LOAD_ORDER_SPEC_HELPER' => File.expand_path('spec_helper.rb', __dir__), 'SPEC_OPTS' => nil }
      runner = 'require "rspec/core"; exit RSpec::Core::Runner.run(ARGV)'
      stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, '-e', runner, '--', file, '--options', options,
                                              '--format', 'json', '--out', result, '--order', 'defined', chdir: root)
      raise "load order probe wrote no results (#{status}):\n#{stdout}\n#{stderr}" unless File.exist?(result)

      JSON.parse(File.read(result))
    end
  end

  def outcome_of(full_description)
    example = probe_result['examples'].find { |e| e['full_description'] == full_description }
    raise "no probe example #{full_description.inspect}: #{Array(probe_result['messages']).join}" unless example

    [example['status'], example.dig('exception', 'message')].compact
  end

  it 'runs the reset before the own before hooks of a group defined before spec_helper loaded', :aggregate_failures do
    expect(outcome_of('early group keeps its own before-hook setup')).to eq(['passed'])
    expect(outcome_of('early group nested keeps its own before-hook setup')).to eq(['passed'])
    expect(outcome_of('early group without a Script stub keeps its own before-hook setup')).to eq(['passed'])
  end

  it 'runs the reset before the own before hooks of a group defined after spec_helper loaded' do
    expect(outcome_of('late group keeps its own before-hook setup')).to eq(['passed'])
  end
end
