# spec/lib/dependency_recovery_spec.rb
require 'digest'
require 'fileutils'
require 'json'
require 'tmpdir'

require_relative '../../lib/dependency_recovery'

RSpec.describe Lich::DependencyRecovery do
  let(:gem_home) { Dir.mktmpdir('lich-recovery-gems') }
  let(:manifest_url) { 'https://example.test/R4L5-gem-manifest.json' }
  let(:artifact_url) { 'https://example.test/sqlite3.gem' }
  let(:artifact_body) { 'verified gem payload' }
  let(:installed) { [] }
  let(:recovery_temp_dir) { Dir.mktmpdir('lich-recovery-temp') }
  let(:platform) { Gem::Platform.local.to_s }
  let(:ruby_abi) { RUBY_VERSION.split('.').first(2).join('.') }

  after do
    FileUtils.remove_entry(gem_home) if Dir.exist?(gem_home)
    FileUtils.remove_entry(recovery_temp_dir) if Dir.exist?(recovery_temp_dir)
  end

  before do
    allow(Gem::Specification).to receive(:find_all_by_name).and_return([])
    allow(Gem::Specification).to receive(:reset)
    allow(Gem).to receive(:clear_paths)
  end

  def sha256(value)
    "sha256:#{Digest::SHA256.hexdigest(value)}"
  end

  def manifest_for(units, ruby_abi:, platform:)
    JSON.generate(
      'schema'  => 1,
      'targets' => [{ 'ruby_abi' => ruby_abi, 'platform' => platform, 'units' => units }]
    )
  end

  def gem_unit(name:, artifact_url:, body:, members: nil)
    {
      'id'            => name,
      'members'       => members || [name],
      'artifact'      => {
        'url'      => artifact_url,
        'filename' => "#{name}.gem",
        'sha256'   => sha256(body),
        'archive'  => 'gem'
      },
      'packages'      => [{
        'name'     => name,
        'version'  => '1.2.3',
        'filename' => "#{name}.gem",
        'sha256'   => sha256(body)
      }],
      'install_order' => [name]
    }
  end

  def recovery(artifacts:, extract_zip: nil, install_gem: nil, powershell_runner: nil, helper_launcher: nil)
    described_class.new(
      manifest_url: manifest_url,
      gem_home: gem_home,
      temp_dir: recovery_temp_dir,
      http_get: ->(url) { artifacts.fetch(url) },
      install_gem: install_gem || ->(path, home) { installed << [File.basename(path), home, File.binread(path)] },
      extract_zip: extract_zip,
      powershell_runner: powershell_runner,
      helper_launcher: helper_launcher
    )
  end

  it 'installs an exact, hash-verified single-gem unit into the runtime Gem.dir' do
    unit = gem_unit(name: 'sqlite3', artifact_url: artifact_url, body: artifact_body)
    manifest = manifest_for([unit], ruby_abi: ruby_abi, platform: platform)
    subject = recovery(artifacts: { manifest_url => manifest, artifact_url => artifact_body })

    result = subject.recover(['sqlite3'])

    expect(result).to be_success
    expect(result.installed_gems).to eq(['sqlite3'])
    expect(installed).to eq([['sqlite3.gem', gem_home, artifact_body]])
  end

  it 'uses a retained workspace beneath Lich TEMP_DIR during extraction diagnosis' do
    unit = gem_unit(name: 'sqlite3', artifact_url: artifact_url, body: artifact_body)
    manifest = manifest_for([unit], ruby_abi: ruby_abi, platform: platform)
    workspaces = []
    installer = lambda do |path, home|
      workspaces << File.dirname(path)
      installed << [File.basename(path), home, File.binread(path)]
    end
    subject = recovery(artifacts: { manifest_url => manifest, artifact_url => artifact_body }, install_gem: installer)

    expect(subject.recover(['sqlite3'])).to be_success
    expect(workspaces.first).to start_with(recovery_temp_dir)
    expect(Dir.exist?(workspaces.first)).to be(true)
  end

  it 'does not recreate an existing Lich TEMP_DIR' do
    unit = gem_unit(name: 'sqlite3', artifact_url: artifact_url, body: artifact_body)
    manifest = manifest_for([unit], ruby_abi: ruby_abi, platform: platform)
    subject = recovery(artifacts: { manifest_url => manifest, artifact_url => artifact_body })

    expect(FileUtils).not_to receive(:mkdir_p).with(recovery_temp_dir)
    expect(subject.recover(['sqlite3'])).to be_success
  end

  it 'retains the workspace while Windows extraction is being diagnosed' do
    unit = gem_unit(name: 'sqlite3', artifact_url: artifact_url, body: artifact_body)
    manifest = manifest_for([unit], ruby_abi: ruby_abi, platform: platform)
    workspaces = []
    installer = lambda do |path, home|
      workspaces << File.dirname(path)
      installed << [File.basename(path), home, File.binread(path)]
    end
    subject = recovery(artifacts: { manifest_url => manifest, artifact_url => artifact_body }, install_gem: installer)

    expect(subject.recover(['sqlite3'])).to be_success
    expect(Dir.exist?(workspaces.first)).to be(true)
  end

  it 'reports the runtime destination when gem installation is denied' do
    subject = described_class.new(gem_home: gem_home, temp_dir: recovery_temp_dir)
    allow(Gem::Installer).to receive(:at).and_raise(Errno::EACCES, 'permission denied')

    expect { subject.send(:install_gem_file, 'sqlite3.gem', gem_home) }
      .to raise_error(described_class::Error, /#{Regexp.escape(gem_home)}/)
  end

  it 'creates a recovery plan before downloading or installing artifacts' do
    unit = gem_unit(name: 'sqlite3', artifact_url: artifact_url, body: artifact_body)
    manifest = manifest_for([unit], ruby_abi: ruby_abi, platform: platform)
    subject = recovery(artifacts: { manifest_url => manifest, artifact_url => artifact_body })

    plan = subject.recovery_plan(['sqlite3'])

    expect(plan).to be_success
    expect(plan.units).to eq([unit])
    expect(installed).to be_empty
  end

  it 'rejects a corrupted artifact before invoking the installer' do
    unit = gem_unit(name: 'sqlite3', artifact_url: artifact_url, body: artifact_body)
    manifest = manifest_for([unit], ruby_abi: ruby_abi, platform: platform)
    subject = recovery(artifacts: { manifest_url => manifest, artifact_url => 'tampered payload' })

    result = subject.recover(['sqlite3'])

    expect(result).not_to be_success
    expect(result.error).to include('SHA-256 does not match')
    expect(installed).to be_empty
  end

  it 'fails closed when the manifest has no unit for the requested gem' do
    manifest = manifest_for([], ruby_abi: ruby_abi, platform: platform)
    subject = recovery(artifacts: { manifest_url => manifest })

    result = subject.recover(['unapproved-gem'])

    expect(result).not_to be_success
    expect(result.error).to include('does not approve recovery')
    expect(installed).to be_empty
  end

  it 'rejects a manifest aimed at a different Ruby platform' do
    unit = gem_unit(name: 'sqlite3', artifact_url: artifact_url, body: artifact_body)
    manifest = manifest_for([unit], ruby_abi: ruby_abi, platform: 'x64-mingw-ucrt')
    subject = recovery(artifacts: { manifest_url => manifest })

    result = subject.recover(['sqlite3'])

    expect(result).not_to be_success
    expect(result.error).to include('has no target')
  end

  it 'restores every package in the GTK bundle in its declared install order' do
    bundle_url = 'https://example.test/gtk3-runtime.zip'
    bundle_body = 'verified zip payload'
    packages = [
      { 'name' => 'glib2', 'version' => '4.3.6', 'filename' => 'glib2.gem', 'sha256' => sha256('glib') },
      { 'name' => 'gtk3', 'version' => '4.3.6', 'filename' => 'gtk3.gem', 'sha256' => sha256('gtk') }
    ]
    unit = {
      'id'            => 'gtk3-runtime',
      'members'       => %w[glib2 gtk3],
      'artifact'      => {
        'url'      => bundle_url,
        'filename' => 'gtk3-runtime.zip',
        'sha256'   => sha256(bundle_body),
        'archive'  => 'zip'
      },
      'packages'      => packages,
      'install_order' => %w[glib2 gtk3]
    }
    manifest = manifest_for([unit], ruby_abi: ruby_abi, platform: platform)
    extractor = lambda do |_archive, destination|
      File.binwrite(File.join(destination, 'glib2.gem'), 'glib')
      File.binwrite(File.join(destination, 'gtk3.gem'), 'gtk')
    end
    subject = recovery(artifacts: { manifest_url => manifest, bundle_url => bundle_body },
                       extract_zip: extractor)

    result = subject.recover(['gtk3'])

    expect(result).to be_success
    expect(result.installed_gems).to eq(%w[glib2 gtk3])
    expect(installed.map(&:first)).to eq(%w[glib2.gem gtk3.gem])
    expect(installed.map { |entry| entry[1] }.uniq).to eq([gem_home])
  end

  it 'hands a complete native runtime unit to the hidden replacement helper' do
    bundle_url = 'https://example.test/gtk3-runtime.zip'
    bundle_body = 'verified zip payload'
    packages = [
      { 'name' => 'glib2', 'version' => '4.3.6', 'filename' => "glib2-4.3.6-#{platform}.gem", 'sha256' => sha256('glib') },
      { 'name' => 'gtk3', 'version' => '4.3.6', 'filename' => "gtk3-4.3.6-#{platform}.gem", 'sha256' => sha256('gtk') }
    ]
    unit = {
      'id'            => 'gtk3-runtime',
      'members'       => %w[glib2 gtk3],
      'artifact'      => { 'url' => bundle_url, 'filename' => 'gtk3-runtime.zip', 'sha256' => sha256(bundle_body), 'archive' => 'zip' },
      'packages'      => packages,
      'install_order' => %w[glib2 gtk3]
    }
    payloads = []
    extractor = lambda do |_archive, destination|
      File.binwrite(File.join(destination, packages[0]['filename']), 'glib')
      File.binwrite(File.join(destination, packages[1]['filename']), 'gtk')
    end
    allow(Gem).to receive(:win_platform?).and_return(true)
    subject = recovery(
      artifacts: { manifest_url => manifest_for([unit], ruby_abi: ruby_abi, platform: platform), bundle_url => bundle_body },
      extract_zip: extractor,
      helper_launcher: ->(payload_path) { payloads << JSON.parse(File.read(payload_path)) }
    )

    result = subject.recover(['gtk3'], force: true)

    expect(result).to be_success
    expect(result.restart_required).to be(true)
    expect(installed).to be_empty
    expect(payloads.first.fetch('packages').map { |package| package.fetch('name') }).to eq(%w[glib2 gtk3])
  end

  describe '#parse_https_uri!' do
    let(:subject) { described_class.new(manifest_url: manifest_url, gem_home: gem_home) }

    it 'returns an HTTPS URI object rather than opening a string through URI.open' do
      uri = subject.send(:parse_https_uri!, 'https://example.test/gem.gem', 'artifact URL')

      expect(uri).to be_a(URI::HTTPS)
      expect(uri).to respond_to(:open)
    end

    it 'rejects non-HTTPS and command-like values' do
      %w[http://example.test/gem.gem |not-a-command].each do |value|
        expect { subject.send(:parse_https_uri!, value, 'artifact URL') }
          .to raise_error(described_class::Error)
      end
    end
  end

  describe '#unsafe_archive_entry?' do
    let(:subject) { described_class.new(manifest_url: manifest_url, gem_home: gem_home) }

    it 'rejects empty, absolute, and parent-traversal archive entries' do
      ['', '/absolute.gem', '\\absolute.gem', 'C:\\absolute.gem', '../escape.gem', 'gems/../escape.gem'].each do |entry|
        expect(subject.send(:unsafe_archive_entry?, entry)).to be(true)
      end
    end

    it 'accepts safe relative archive filenames and subpaths' do
      %w[sqlite3.gem gems/sqlite3.gem gems/native/sqlite3.gem].each do |entry|
        expect(subject.send(:unsafe_archive_entry?, entry)).to be(false)
      end
    end
  end

  describe 'Windows ZIP extraction' do
    let(:zip_path) { File.join(recovery_temp_dir, 'bundle.zip') }
    let(:destination) { File.join(recovery_temp_dir, 'packages') }

    before { allow(Gem).to receive(:win_platform?).and_return(true) }

    it 'uses a hidden WScript launcher for parameterized PowerShell extraction' do
      command = nil
      success = double('status', success?: true)
      runner = lambda do |*args|
        command = args
        ['', '', success]
      end
      subject = described_class.new(gem_home: gem_home, temp_dir: recovery_temp_dir,
                                    powershell_runner: runner)

      subject.send(:extract_zip_file, zip_path, destination)

      launcher_path = command.last
      script_path = File.join(File.dirname(destination), 'extract-r4l5-bundle.ps1')
      expect(command).to eq(['wscript.exe', '//nologo', launcher_path])
      expect(File.read(launcher_path)).to include('shell.Run(command, 0, True)', '-Archive', '-Destination')
      expect(File.read(script_path)).to include('[string]$Archive', '[string]$Destination')
    end

    it 'includes captured PowerShell diagnostics when extraction fails' do
      failure = double('status', success?: false, exitstatus: 1)
      runner = ->(*) { ['standard output', 'access denied', failure] }
      subject = described_class.new(gem_home: gem_home, temp_dir: recovery_temp_dir,
                                    powershell_runner: runner)

      expect { subject.send(:extract_zip_file, zip_path, destination) }
        .to raise_error(described_class::Error, /PowerShell exit 1.*access denied/)
    end
  end

  describe '#require_filename!' do
    let(:subject) { described_class.new(manifest_url: manifest_url, gem_home: gem_home) }

    it 'rejects dot-only filenames' do
      %w[. .. ...].each do |filename|
        expect { subject.send(:require_filename!, filename, 'artifact') }
          .to raise_error(described_class::Error, /filename is unsafe/)
      end
    end

    it 'accepts ordinary filenames' do
      expect { subject.send(:require_filename!, 'sqlite3.gem', 'artifact') }.not_to raise_error
    end
  end
end
