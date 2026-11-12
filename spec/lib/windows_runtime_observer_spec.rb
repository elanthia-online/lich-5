# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

RSpec.describe 'Windows CI runtime observer' do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:observer) { File.join(root, '.github/scripts/windows_runtime_observer.rb') }

  def observe(needed:, activated:, unrelated: false)
    Dir.mktmpdir('windows-runtime-observer') do |directory|
      program = <<~RUBY
        require 'json'
        check = Struct.new(:needed, :plan).new(#{needed.inspect}, Struct.new(:units).new([{'id' => 'runtime'}]))
        probe = Object.new
        probe.instance_variable_set(:@check, check)
        eval('def probe.check; @check; end; def probe.activate!; #{activated.inspect}; end', binding, #{File.join(root, unrelated ? 'other/accepted_gem_policy.rb' : 'lib/accepted_gem_policy.rb').inspect})
        raise 'observer changed check return' unless probe.check.equal?(check)
        raise 'observer changed activation return' unless probe.activate! == #{activated.inspect}
        eval('def probe.fetch; "manifest receipt"; end', binding, #{File.join(root, 'lib/dependency_recovery.rb').inspect})
        probe.fetch unless #{activated.inspect}
      RUBY
      stdout, stderr, status = Open3.capture3(
        { 'LICH_CI_RUNTIME_ARTIFACTS' => directory }, RbConfig.ruby, '-r', observer, '-e', program
      )
      expect(status.success?).to be(true), "#{stdout}\n#{stderr}"
      yield directory
    end
  end

  it 'records compliant policy and successful activation without changing returns' do
    observe(needed: [], activated: true) do |directory|
      ready = JSON.parse(File.read(File.join(directory, 'ready.json')))
      policy = JSON.parse(File.read(File.join(directory, "policy-#{ready.fetch('pid')}.json")))
      expect(ready.fetch('accepted_runtime_activated')).to be(true)
      expect(policy.fetch('needed')).to eq([])
      expect(policy.fetch('gem_home')).not_to be_empty
      expect(Dir.glob(File.join(directory, 'process-*.txt')).length).to eq(1)
    end
  end

  it 'retains missing-gem and manifest receipts without declaring failed activation ready' do
    observe(needed: ['example'], activated: false) do |directory|
      policy_path = Dir.glob(File.join(directory, 'policy-*.json')).fetch(0)
      expect(JSON.parse(File.read(policy_path)).fetch('needed')).to eq(['example'])
      expect(File.read(Dir.glob(File.join(directory, 'manifest-*.json')).fetch(0))).to eq('manifest receipt')
      expect(File.exist?(File.join(directory, 'ready.json'))).to be(false)
    end
  end

  it 'ignores same-named methods outside the production policy file' do
    observe(needed: [], activated: true, unrelated: true) do |directory|
      expect(Dir.glob(File.join(directory, 'policy-*.json'))).to be_empty
      expect(File.exist?(File.join(directory, 'ready.json'))).to be(false)
    end
  end
end
