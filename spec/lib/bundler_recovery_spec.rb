# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

require_relative '../../lib/bundler_recovery'

RSpec.describe Lich::BundlerRecovery do
  let(:status) { instance_double(Process::Status, success?: true) }

  around do |example|
    Dir.mktmpdir('lich-bundler-recovery-spec') do |dir|
      @lich_dir = dir
      @gem_home = File.join(dir, 'runtime-gems')
      File.write(File.join(dir, 'Gemfile'), "source 'https://rubygems.org'\n")
      example.run
    end
  end

  def recovery(&launcher)
    helper = lambda do |path|
      launcher.call(path)
      FileUtils.rm_rf(File.dirname(path)) # Mirrors detached helper cleanup in unit tests.
    end
    described_class.new(lich_dir: @lich_dir, gem_home: @gem_home, helper_launcher: helper)
  end

  before { allow(described_class).to receive(:supported?).and_return(true) }

  describe '#preflight' do
    it 'requires native build tools when Ox is missing' do
      subject = recovery { |_| }
      allow(subject).to receive(:command_available?).and_return(true)
      allow(subject).to receive(:ruby_headers).and_return('/missing/ruby/headers')

      expect(subject.preflight(['ox'])).to include('Ruby development headers')
    end

    it 'does not require a lockfile for a pure Ruby missing gem' do
      subject = recovery { |_| }
      allow(subject).to receive(:command_available?).and_return(true)

      expect(subject.preflight(['ascii_charts'])).to be_nil
    end
  end

  describe '#recover' do
    before do
      allow_any_instance_of(described_class).to receive(:preflight).and_return(nil)
      allow_any_instance_of(described_class).to receive(:promotion_packages)
        .and_return([{ 'name' => 'ox', 'version' => '2.14.28', 'path' => '/verified/ox.gem' }])
      allow(Open3).to receive(:capture3).and_return(['installed', '', status])
    end

    it 'stages Bundler work in temp, then schedules an exit-time canonical promotion' do
      payload = nil
      subject = recovery { |path| payload = JSON.parse(File.read(path)) }

      result = subject.recover(['ox'])

      expect(result).to be_success
      expect(result.restart_required).to be(true)
      expect(payload).to include('gem_home' => @gem_home, 'lich_dir' => @lich_dir)
      expect(payload.fetch('packages')).to eq([{ 'name' => 'ox', 'version' => '2.14.28', 'path' => '/verified/ox.gem' }])
      expect(File.directory?(payload.fetch('work_dir'))).to be(false)
      expect(File).not_to exist(File.join(@lich_dir, '.lich-bundler-gems'))
    end

    it 'uses a staged lockfile in frozen mode when one was shipped' do
      File.write(File.join(@lich_dir, 'Gemfile.lock'), "GEM\n")
      environment = nil
      allow(Open3).to receive(:capture3) do |env, *_args, **_options|
        environment = env
        ['installed', '', status]
      end
      subject = recovery { |_| }

      subject.recover(['ox'])

      expect(environment.fetch('BUNDLE_FROZEN')).to eq('true')
      expect(environment.fetch('BUNDLE_WITHOUT').split(':')).to include('gtk', 'development', 'vscode', 'profanity')
    end

    it 'cleans staging when Bundler fails before a helper is scheduled' do
      allow(status).to receive(:success?).and_return(false)
      called = false
      subject = recovery { |_| called = true }

      result = subject.recover(['ox'])

      expect(result).not_to be_success
      expect(called).to be(false)
      expect(Dir.glob(File.join(subject.send(:temp_dir), 'lich-bundler-recovery-*'))).to be_empty
    end
  end

  describe 'staged package selection' do
    it 'selects only missing gems and unavailable runtime dependencies' do
      staging = File.join(@lich_dir, 'staging')
      home = File.join(staging, 'ruby', RbConfig::CONFIG.fetch('ruby_version'))
      specs = File.join(home, 'specifications')
      cache = File.join(home, 'cache')
      FileUtils.mkdir_p([specs, cache])

      ox = Gem::Specification.new do |spec|
        spec.name = 'ox'
        spec.version = '2.14.28'
        spec.summary = 'test'
        spec.authors = ['Lich']
        spec.add_runtime_dependency 'lich-recovery-support', '>= 4.0'
      end
      support = Gem::Specification.new { |spec| spec.name = 'lich-recovery-support'; spec.version = '4.1.2'; spec.summary = 'test'; spec.authors = ['Lich'] }
      unrelated = Gem::Specification.new { |spec| spec.name = 'redis'; spec.version = '5.4.1'; spec.summary = 'test'; spec.authors = ['Lich'] }
      [ox, support, unrelated].each do |spec|
        File.write(File.join(specs, "#{spec.full_name}.gemspec"), spec.to_ruby)
        File.write(File.join(cache, spec.file_name), '')
      end

      packages = recovery { |_| }.send(:promotion_packages, ['ox'], staging)

      expect(packages.map { |package| package.fetch('name') }).to contain_exactly('ox', 'lich-recovery-support')
    end
  end
end
