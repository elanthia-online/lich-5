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

  def recovery(installer: nil, &launcher)
    helper = lambda do |path|
      launcher.call(path)
      FileUtils.rm_rf(File.dirname(path)) # Mirrors detached helper cleanup in unit tests.
    end
    described_class.new(lich_dir: @lich_dir, gem_home: @gem_home, helper_launcher: helper, installer: installer)
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

  describe '.run_macos_replacement' do
    it 'logs malformed helper payloads in the Lich temp directory inferred from the payload path' do
      temp = File.join(@lich_dir, 'temp')
      FileUtils.mkdir_p(temp)
      workspace = Dir.mktmpdir('promotion-', temp)
      payload_path = File.join(workspace, 'macos-gem-promotion.json')
      File.write(payload_path, '{invalid-json')

      expect(described_class.run_macos_replacement(payload_path)).to be(false)
      expect(File.read(File.join(temp, described_class::LOG_FILENAME))).to include('macOS gem promotion failed')
    end
  end

  describe '#recover' do
    before do
      allow_any_instance_of(described_class).to receive(:preflight).and_return(nil)
      allow_any_instance_of(described_class).to receive(:promotion_packages)
        .and_return([{ 'name' => 'ox', 'version' => '2.14.28', 'full_name' => 'ox-2.14.28', 'path' => '/verified/ox.gem' }])
      allow(Open3).to receive(:capture3).and_return(['installed', '', status])
    end

    it 'stages Bundler work in temp, then schedules an exit-time canonical promotion' do
      payload = nil
      subject = recovery { |path| payload = JSON.parse(File.read(path)) }

      result = subject.recover(['ox'])

      expect(result).to be_success
      expect(result.restart_required).to be(true)
      expect(payload).to include('gem_home' => @gem_home, 'lich_dir' => @lich_dir)
      expect(payload.fetch('packages')).to eq([{ 'name' => 'ox', 'version' => '2.14.28', 'full_name' => 'ox-2.14.28', 'path' => '/verified/ox.gem' }])
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

  describe 'detached promotion transaction' do
    def write_installed_spec(name, version, marker:)
      spec = Gem::Specification.new do |entry|
        entry.name = name
        entry.version = version
        entry.summary = 'test'
        entry.authors = ['Lich']
      end
      FileUtils.mkdir_p([File.join(@gem_home, 'specifications'), File.join(@gem_home, 'gems', spec.full_name)])
      File.write(File.join(@gem_home, 'specifications', "#{spec.full_name}.gemspec"), spec.to_ruby)
      File.write(File.join(@gem_home, 'gems', spec.full_name, 'marker'), marker)
      spec
    end

    def payload_for(work_dir, spec)
      archive = File.join(work_dir, "#{spec.full_name}.gem")
      File.write(archive, 'verified test archive')
      path = File.join(work_dir, 'macos-gem-promotion.json')
      payload = {
        'schema' => 1, 'parent_pid' => Process.pid, 'lich_dir' => @lich_dir,
        'gem_home' => @gem_home, 'temp_dir' => File.dirname(work_dir), 'work_dir' => work_dir,
        'packages' => [{ 'name' => spec.name, 'version' => spec.version.to_s, 'full_name' => spec.full_name, 'path' => archive }],
        'restart' => { 'program' => File.join(@lich_dir, 'lich.rbw'), 'argv' => [], 'chdir' => @lich_dir }
      }
      File.write(path, JSON.generate(payload))
      [payload, path]
    end

    def install_spec(spec, marker:)
      FileUtils.mkdir_p([File.join(@gem_home, 'specifications'), File.join(@gem_home, 'gems', spec.full_name)])
      File.write(File.join(@gem_home, 'specifications', "#{spec.full_name}.gemspec"), spec.to_ruby)
      File.write(File.join(@gem_home, 'gems', spec.full_name, 'marker'), marker)
    end

    it 'promotes the exact package, preserves another version, validates, and restarts' do
      original = write_installed_spec('recovery-target', '1.0.0', marker: 'preserve')
      replacement = write_installed_spec('recovery-target', '2.0.0', marker: 'old')
      work_dir = Dir.mktmpdir('promotion-', @lich_dir)
      payload, path = payload_for(work_dir, replacement)
      subject = recovery(installer: ->(_) { install_spec(replacement, marker: 'new') }) { |_| }
      allow(subject).to receive(:wait_for_parent_exit)
      expect(subject).to receive(:restart_lich).with(payload.fetch('restart'))

      subject.send(:run_macos_replacement!, payload, payload_path: path)

      expect(File.read(File.join(@gem_home, 'gems', replacement.full_name, 'marker'))).to eq('new')
      expect(File.read(File.join(@gem_home, 'gems', original.full_name, 'marker'))).to eq('preserve')
      expect(File).not_to exist(work_dir)
    end

    it 'keeps Ruby default gems available while verifying the promoted package' do
      replacement = write_installed_spec('recovery-target', '2.0.0', marker: 'new')
      subject = recovery { |_| }
      package = { 'name' => replacement.name, 'version' => replacement.version.to_s, 'full_name' => replacement.full_name }

      expect(Gem).to receive(:use_paths).with(@gem_home, [@gem_home, Gem.default_dir].uniq)
      subject.send(:verify_packages!, [package])
    end

    it 'restores the exact backed-up package and does not restart when installation fails' do
      replacement = write_installed_spec('recovery-target', '2.0.0', marker: 'old')
      work_dir = Dir.mktmpdir('promotion-', @lich_dir)
      payload, path = payload_for(work_dir, replacement)
      subject = recovery(installer: lambda { |_|
        install_spec(replacement, marker: 'new')
        raise 'install failed'
      }) { |_| }
      allow(subject).to receive(:wait_for_parent_exit)
      expect(subject).not_to receive(:restart_lich)

      expect { subject.send(:run_macos_replacement!, payload, payload_path: path) }.to raise_error('install failed')
      expect(File.read(File.join(@gem_home, 'gems', replacement.full_name, 'marker'))).to eq('old')
      expect(File).to exist(File.join(@gem_home, 'specifications', "#{replacement.full_name}.gemspec"))
      expect(File).not_to exist(work_dir)
    end

    it 'does not clean a payload-supplied workspace unless it matches the payload directory' do
      replacement = Gem::Specification.new { |entry| entry.name = 'recovery-target'; entry.version = '2.0.0'; entry.summary = 'test'; entry.authors = ['Lich'] }
      work_dir = Dir.mktmpdir('promotion-', @lich_dir)
      payload, path = payload_for(work_dir, replacement)
      protected_dir = Dir.mktmpdir('protected-', @lich_dir)
      payload['work_dir'] = protected_dir
      File.write(path, JSON.generate(payload))
      subject = recovery { |_| }

      expect { subject.send(:run_macos_replacement!, payload, payload_path: path) }.to raise_error('invalid macOS gem promotion workspace')
      expect(File).to exist(protected_dir)
      FileUtils.rm_rf([work_dir, protected_dir])
    end
  end
end
