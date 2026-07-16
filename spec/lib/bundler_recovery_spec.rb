# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

require_relative '../../lib/bundler_recovery'

RSpec.describe Lich::BundlerRecovery do
  let(:status) { instance_double(Process::Status, success?: true) }

  before do
    allow(described_class).to receive(:supported?).and_return(true)
  end

  around do |example|
    Dir.mktmpdir('lich-bundler-recovery-spec') do |dir|
      @lich_dir = dir
      File.write(File.join(dir, 'Gemfile'), "source 'https://rubygems.org'\n")
      File.write(File.join(dir, 'Gemfile.lock'), "GEM\n  specs:\n")
      example.run
    end
  end

  subject(:recovery) { described_class.new(lich_dir: @lich_dir) }

  describe '#preflight' do
    it 'requires the macOS native build tools when Ox is missing' do
      allow(recovery).to receive(:command_available?).and_return(true)
      allow(recovery).to receive(:ruby_headers).and_return('/missing/ruby/headers')

      expect(recovery.preflight(['ox'])).to include('Ruby development headers')
    end

    it 'does not require a compiler for a pure Ruby missing gem' do
      allow(recovery).to receive(:command_available?).and_return(true)

      expect(recovery.preflight(['ascii_charts'])).to be_nil
    end

    it 'does not require a shipped lockfile' do
      FileUtils.rm_f(File.join(@lich_dir, 'Gemfile.lock'))
      allow(recovery).to receive(:command_available?).and_return(true)

      expect(recovery.preflight(['ascii_charts'])).to be_nil
    end
  end

  describe '#recover' do
    before do
      allow(recovery).to receive(:preflight).and_return(nil)
      allow(Open3).to receive(:capture3) do |*arguments, **_options|
        environment = arguments.first
        if environment.is_a?(Hash)
          @install_environment = environment
          bundle_path = environment.fetch('BUNDLE_PATH')
          FileUtils.mkdir_p(File.join(bundle_path, 'ruby', RbConfig::CONFIG.fetch('ruby_version')))
          File.write(File.join(bundle_path, 'Gemfile.lock'), "GEM\n  specs:\n")
          ['installed', '', status]
        else
          ['Bundler 4', '', status]
        end
      end
    end

    it 'stages the non-GTK bundle before atomically activating it' do
      result = recovery.recover(['ox'])
      store = File.join(@lich_dir, described_class::STORE_DIRNAME)
      record = JSON.parse(File.read(File.join(store, described_class::ACTIVE_FILENAME)))

      expect(result).to be_success
      expect(record).to include('schema' => 1, 'ruby_api' => RbConfig::CONFIG.fetch('ruby_version'))
      expect(File.directory?(File.join(store, record.fetch('bundle_id'), 'ruby', record.fetch('ruby_api')))).to be(true)
      expect(Dir.children(store)).not_to include(a_string_starting_with('.staging-'))
    end

    it 'excludes GTK and non-runtime groups from the Bundler child environment' do
      recovery.recover(['ox'])

      expect(@install_environment.fetch('BUNDLE_FROZEN')).to eq('true')
      expect(@install_environment.fetch('BUNDLE_WITHOUT').split(':'))
        .to include('gtk', 'development', 'vscode', 'profanity')
    end

    it 'resolves only in staging when the release package has no lockfile' do
      FileUtils.rm_f(File.join(@lich_dir, 'Gemfile.lock'))

      result = recovery.recover(['ox'])
      store = File.join(@lich_dir, described_class::STORE_DIRNAME)
      record = JSON.parse(File.read(File.join(store, described_class::ACTIVE_FILENAME)))
      promoted_lockfile = File.join(store, record.fetch('bundle_id'), 'Gemfile.lock')

      expect(result).to be_success
      expect(@install_environment.fetch('BUNDLE_FROZEN')).to eq('false')
      expect(File).not_to exist(File.join(@lich_dir, 'Gemfile.lock'))
      expect(File).to exist(promoted_lockfile)
    end

    it 'does not activate or retain a staged bundle when Bundler fails' do
      allow(status).to receive(:success?).and_return(false)

      result = recovery.recover(['ox'])
      store = File.join(@lich_dir, described_class::STORE_DIRNAME)

      expect(result).not_to be_success
      expect(File).not_to exist(File.join(store, described_class::ACTIVE_FILENAME))
      expect(Dir.children(store)).not_to include(a_string_starting_with('.staging-'))
    end
  end

  describe '#activate!' do
    it 'adds only a compatible promoted bundle to RubyGems' do
      store = File.join(@lich_dir, described_class::STORE_DIRNAME)
      bundle_id = 'bundle-test'
      home = File.join(store, bundle_id, 'ruby', RbConfig::CONFIG.fetch('ruby_version'))
      FileUtils.mkdir_p(home)
      active_record = {
        'schema'      => 1,
        'bundle_id'   => bundle_id,
        'ruby_api'    => RbConfig::CONFIG.fetch('ruby_version'),
        'ruby_engine' => RUBY_ENGINE,
        'platform'    => RUBY_PLATFORM
      }
      File.write(File.join(store, described_class::ACTIVE_FILENAME), JSON.generate(active_record))

      expect(Gem).to receive(:use_paths).with(Gem.dir, array_including(home))
      expect(Gem::Specification).to receive(:reset)

      expect(recovery.activate!).to be(true)
    end

    it 'ignores a malformed active record without changing RubyGems paths' do
      store = File.join(@lich_dir, described_class::STORE_DIRNAME)
      FileUtils.mkdir_p(store)
      File.write(File.join(store, described_class::ACTIVE_FILENAME), '{not-json')

      expect(Gem).not_to receive(:use_paths)
      expect(recovery.activate!).to be(false)
    end
  end
end
