# spec/lib/dependency_recovery_spec.rb
require 'digest'
require 'fileutils'
require 'json'
require 'stringio'
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

  it 'uses a workspace beneath Lich TEMP_DIR and cleans it after direct recovery' do
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
    expect(Dir.exist?(workspaces.first)).to be(false)
  end

  it 'does not recreate an existing Lich TEMP_DIR' do
    unit = gem_unit(name: 'sqlite3', artifact_url: artifact_url, body: artifact_body)
    manifest = manifest_for([unit], ruby_abi: ruby_abi, platform: platform)
    subject = recovery(artifacts: { manifest_url => manifest, artifact_url => artifact_body })

    allow(FileUtils).to receive(:mkdir_p).and_call_original
    expect(FileUtils).not_to receive(:mkdir_p).with(recovery_temp_dir)
    expect(subject.recover(['sqlite3'])).to be_success
  end

  it 'cleans the workspace after a direct recovery succeeds' do
    unit = gem_unit(name: 'sqlite3', artifact_url: artifact_url, body: artifact_body)
    manifest = manifest_for([unit], ruby_abi: ruby_abi, platform: platform)
    workspaces = []
    installer = lambda do |path, home|
      workspaces << File.dirname(path)
      installed << [File.basename(path), home, File.binread(path)]
    end
    subject = recovery(artifacts: { manifest_url => manifest, artifact_url => artifact_body }, install_gem: installer)

    expect(subject.recover(['sqlite3'])).to be_success
    expect(Dir.exist?(workspaces.first)).to be(false)
  end

  it 'does not turn a successful recovery into a failure when workspace cleanup is denied' do
    unit = gem_unit(name: 'sqlite3', artifact_url: artifact_url, body: artifact_body)
    manifest = manifest_for([unit], ruby_abi: ruby_abi, platform: platform)
    workspaces = []
    installer = lambda do |path, home|
      workspaces << File.dirname(File.dirname(File.dirname(path)))
      installed << [File.basename(path), home, File.binread(path)]
    end
    subject = recovery(artifacts: { manifest_url => manifest, artifact_url => artifact_body }, install_gem: installer)
    allow(FileUtils).to receive(:remove_entry).and_wrap_original do |original, path|
      raise Errno::EACCES, 'permission denied' if workspaces.include?(path)

      original.call(path)
    end

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

  it 'does not lock or install anything when a later unit artifact is unreachable' do
    first_url = 'https://example.test/first.gem'
    second_url = 'https://example.test/second.gem'
    first = gem_unit(name: 'first', artifact_url: first_url, body: 'first payload')
    second = gem_unit(name: 'second', artifact_url: second_url, body: 'second payload')
    manifest = manifest_for([first, second], ruby_abi: ruby_abi, platform: platform)
    subject = described_class.new(
      manifest_url: manifest_url,
      gem_home: gem_home,
      temp_dir: recovery_temp_dir,
      http_get: lambda do |url|
        case url
        when manifest_url then manifest
        when first_url    then 'first payload'
        when second_url   then raise SocketError, 'release endpoint unavailable'
        end
      end,
      install_gem: ->(path, home) { installed << [File.basename(path), home, File.binread(path)] }
    )
    expect(subject).not_to receive(:with_install_lock)

    result = subject.recover(%w[first second])

    expect(result).not_to be_success
    expect(result.error).to include('Could not stage recovery unit second', 'release endpoint unavailable')
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

  it 'downloads and extracts a shared bundle artifact only once per recovery' do
    bundle_url = 'https://example.test/runtime-bundle.zip'
    bundle_body = 'verified zip payload'
    first = {
      'id'            => 'first',
      'members'       => ['first'],
      'artifact'      => { 'url' => bundle_url, 'filename' => 'runtime-bundle.zip', 'sha256' => sha256(bundle_body), 'archive' => 'zip' },
      'packages'      => [{ 'name' => 'first', 'version' => '1.2.3', 'filename' => 'first.gem', 'sha256' => sha256('first') }],
      'install_order' => ['first']
    }
    second = {
      'id'            => 'second',
      'members'       => ['second'],
      'artifact'      => first.fetch('artifact'),
      'packages'      => [{ 'name' => 'second', 'version' => '1.2.3', 'filename' => 'second.gem', 'sha256' => sha256('second') }],
      'install_order' => ['second']
    }
    downloads = []
    extractions = []
    extractor = lambda do |_archive, destination|
      extractions << destination
      File.binwrite(File.join(destination, 'first.gem'), 'first')
      File.binwrite(File.join(destination, 'second.gem'), 'second')
    end
    subject = described_class.new(
      manifest_url: manifest_url, gem_home: gem_home, temp_dir: recovery_temp_dir,
      http_get: ->(url) { downloads << url; url == manifest_url ? manifest_for([first, second], ruby_abi: ruby_abi, platform: platform) : bundle_body },
      extract_zip: extractor,
      install_gem: ->(path, home) { installed << [File.basename(path), home] }
    )

    result = subject.recover(%w[first second])

    expect(result).to be_success
    expect(downloads.count(bundle_url)).to eq(1)
    expect(extractions).to have_attributes(length: 1)
    expect(installed).to eq([['first.gem', gem_home], ['second.gem', gem_home]])
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

  it 'installs a native single-gem artifact in process rather than scheduling a replacement' do
    body = 'native gem payload'
    unit = {
      'id'            => 'ox',
      'members'       => ['ox'],
      'artifact'      => { 'url' => artifact_url, 'filename' => "ox-1.2.3-#{platform}.gem", 'sha256' => sha256(body), 'archive' => 'gem' },
      'packages'      => [{ 'name' => 'ox', 'version' => '1.2.3', 'filename' => "ox-1.2.3-#{platform}.gem", 'sha256' => sha256(body) }],
      'install_order' => ['ox']
    }
    allow(Gem).to receive(:win_platform?).and_return(true)
    launcher = spy('replacement helper')
    subject = recovery(
      artifacts: { manifest_url => manifest_for([unit], ruby_abi: ruby_abi, platform: platform), artifact_url => body },
      helper_launcher: launcher
    )

    result = subject.recover(['ox'])

    expect(result).to be_success
    expect(result.restart_required).to be_nil
    expect(launcher).not_to have_received(:call)
    expect(installed.map(&:first)).to eq(["ox-1.2.3-#{platform}.gem"])
  end

  describe 'native replacement rollback' do
    let(:work_dir) { File.join(recovery_temp_dir, 'replacement work') }
    let(:rollback_dir) { File.join(work_dir, 'previous-runtime') }
    let(:runtime_specs) do
      %w[f63_first f63_second].map do |name|
        spec = Gem::Specification.new do |entry|
          entry.name = name
          entry.version = '1.2.3'
          entry.platform = Gem::Platform.new('x64-mingw-ucrt')
        end
        spec.loaded_from = File.join(gem_home, 'specifications', "#{spec.full_name}.gemspec")
        spec
      end
    end
    let(:original_files) do
      runtime_specs.flat_map do |spec|
        [File.join(spec.full_gem_path, 'original.rb'), spec.loaded_from,
         File.join(spec.extension_dir, 'original.dll')]
      end
    end
    let(:packages) do
      runtime_specs.map do |spec|
        path = File.join(work_dir, "#{spec.full_name}.gem")
        { 'name' => spec.name, 'version' => spec.version.to_s, 'filename' => File.basename(path),
          'path' => path, 'sha256' => sha256(spec.name) }
      end
    end
    let(:payload) do
      { 'schema' => 1, 'parent_pid' => Process.pid, 'gem_home' => gem_home,
        'temp_dir' => recovery_temp_dir, 'work_dir' => work_dir, 'packages' => packages,
        'restart' => { 'program' => __FILE__, 'argv' => [], 'chdir' => work_dir } }
    end
    let(:installer) do
      lambda do |path, _home|
        spec = runtime_specs.find { |entry| File.basename(path) == "#{entry.full_name}.gem" }
        [File.join(spec.full_gem_path, 'original.rb'), spec.loaded_from,
         File.join(spec.extension_dir, 'original.dll')].each do |file|
          FileUtils.mkdir_p(File.dirname(file))
          File.write(file, 'replacement')
        end
      end
    end
    let(:subject) do
      described_class.new(gem_home: gem_home, temp_dir: recovery_temp_dir, install_gem: installer)
    end

    before do
      FileUtils.mkdir_p(work_dir)
      original_files.each do |file|
        FileUtils.mkdir_p(File.dirname(file))
        File.write(file, 'original')
      end
      packages.each_with_index do |package, index|
        File.write(package.fetch('path'), package.fetch('name'))
        spec = runtime_specs[index]
        allow(Gem::Specification).to receive(:find_all_by_name).with(spec.name).and_return([spec])
        allow(Gem::Specification).to receive(:find_all_by_name).with(spec.name, anything).and_return([spec])
        allow(Gem::Installer).to receive(:at).with(package.fetch('path'), install_dir: gem_home)
                             .and_return(Gem::Installer.for_spec(spec, install_dir: gem_home))
      end
      allow(subject).to receive(:wait_for_parent_exit)
      allow(subject).to receive(:restart_lich)
    end

    it 'restores completed moves and preserves untouched originals after a partial backup' do
      blocked = runtime_specs.first.loaded_from
      allow(FileUtils).to receive(:mv).and_wrap_original do |move, from, to|
        raise Errno::EACCES, 'later backup denied' if from == blocked

        move.call(from, to)
      end
      expect(installer).not_to receive(:call)
      expect(subject).not_to receive(:restart_lich)

      expect { subject.send(:run_windows_replacement!, payload) }
        .to raise_error(described_class::Error, /later backup denied/)

      expect(original_files.map { |file| File.read(file) }).to eq(['original'] * original_files.size)
    end

    it 'removes a partial installation before its gemspec exists and restores the original suite' do
      allow(installer).to receive(:call).and_wrap_original do |install, path, home|
        if path == packages.last.fetch('path')
          file = File.join(runtime_specs.last.full_gem_path, 'partial.dll')
          FileUtils.mkdir_p(File.dirname(file))
          File.write(file, 'partial replacement')
          raise IOError, 'second install failed before gemspec'
        end
        install.call(path, home)
      end
      expect(subject).not_to receive(:restart_lich)

      expect { subject.send(:run_windows_replacement!, payload) }
        .to raise_error(IOError, /second install failed before gemspec/)

      expect(original_files.map { |file| File.read(file) }).to eq(['original'] * original_files.size)
      expect(File).not_to exist(File.join(runtime_specs.last.full_gem_path, 'partial.dll'))
    end

    it 'retains a recoverable backup when replacement cleanup fails while restoring other originals' do
      blocked = runtime_specs.first.full_gem_path
      allow(installer).to receive(:call).and_wrap_original do |install, path, home|
        install.call(path, home)
        raise IOError, 'installation interrupted' if path == packages.last.fetch('path')
      end
      allow(FileUtils).to receive(:remove_entry).and_wrap_original do |remove, path|
        raise Errno::EACCES, 'replacement locked' if path == blocked

        remove.call(path)
      end
      expect(subject).not_to receive(:restart_lich)

      expect { subject.send(:run_windows_replacement!, payload) }
        .to raise_error(described_class::Error, /installation interrupted.*rollback incomplete.*backups retained/)

      backup = File.join(rollback_dir, 'gems', runtime_specs.first.full_name, 'original.rb')
      expect(File.read(backup)).to eq('original')
      expect(File.read(File.join(blocked, 'original.rb'))).to eq('replacement')
      expect(original_files.drop(1).map { |file| File.read(file) }).to eq(['original'] * (original_files.size - 1))
    end

    it 'continues restoring other originals when a backup restore move is denied' do
      blocked = runtime_specs.last.loaded_from
      allow(installer).to receive(:call).and_raise(IOError, 'install failed')
      allow(FileUtils).to receive(:mv).and_wrap_original do |move, from, to|
        raise Errno::EACCES, 'restore denied' if to == blocked

        move.call(from, to)
      end

      expect { subject.send(:run_windows_replacement!, payload) }
        .to raise_error(described_class::Error, /install failed.*rollback incomplete.*restore denied/)

      backup = File.join(rollback_dir, 'specifications', "#{runtime_specs.last.full_name}.gemspec")
      expect(File.read(backup)).to eq('original')
      expect((original_files - [blocked]).map { |file| File.read(file) }).to all(eq('original'))
      expect(File).not_to exist(blocked)
    end

    it 'preserves an unregistered existing replacement destination rather than overwriting it' do
      orphan = File.join(runtime_specs.first.full_gem_path, 'unregistered.dll')
      allow(Gem::Specification).to receive(:find_all_by_name).with(runtime_specs.first.name).and_return([])
      File.write(orphan, 'untouched')
      expect(installer).not_to receive(:call)

      expect { subject.send(:run_windows_replacement!, payload) }
        .to raise_error(described_class::Error, /replacement gem path already exists/)

      expect(File.read(orphan)).to eq('untouched')
      expect(original_files.map { |file| File.read(file) }).to all(eq('original'))
    end

    it 'keeps the verified replacement when old-backup cleanup is denied' do
      allow(FileUtils).to receive(:remove_entry).and_wrap_original do |remove, path|
        raise Errno::EACCES, 'backup cleanup denied' if [rollback_dir, work_dir].include?(path)

        remove.call(path)
      end

      subject.send(:run_windows_replacement!, payload)

      expect(original_files.map { |file| File.read(file) }).to all(eq('replacement'))
      expect(subject).to have_received(:restart_lich).with(payload.fetch('restart'))
      expect(Dir).to exist(rollback_dir)
    end
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

  describe 'bounded HTTPS transfers' do
    let(:subject) { described_class.new(gem_home: gem_home, temp_dir: recovery_temp_dir) }
    let(:uri) { double('HTTPS URI') }
    let(:options) do
      {
        'User-Agent' => 'Lich5 dependency recovery',
        open_timeout: described_class::HTTP_OPEN_TIMEOUT_SECONDS,
        read_timeout: described_class::HTTP_READ_TIMEOUT_SECONDS
      }
    end

    it 'uses explicit connection and read timeouts when downloading an artifact' do
      remote = StringIO.new('artifact')
      allow(remote).to receive(:base_uri).and_return(nil)
      allow(subject).to receive(:parse_https_uri!).and_return(uri)
      expect(uri).to receive(:open).with(options).and_yield(remote)
      destination = File.join(recovery_temp_dir, 'artifact.gem')

      subject.send(:download_to, 'https://example.test/artifact.gem', destination)

      expect(File.binread(destination)).to eq('artifact')
    end

    it 'uses the same timeouts when fetching the manifest' do
      remote = StringIO.new('{"schema":1}')
      allow(remote).to receive(:base_uri).and_return(nil)
      allow(subject).to receive(:parse_https_uri!).and_return(uri)
      expect(uri).to receive(:open).with(options).and_yield(remote)

      expect(subject.send(:fetch, 'https://example.test/manifest.json')).to eq('{"schema":1}')
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

    it 'renders Windows paths as VBScript literals without Ruby backslash escapes' do
      subject = described_class.new(gem_home: gem_home, temp_dir: recovery_temp_dir)

      expect(subject.send(:vbscript_literal, 'C:\\Ruby4Lich5\\temp')).to eq('"C:\\Ruby4Lich5\\temp"')
      expect(subject.send(:vbscript_literal, 'a"b')).to eq('"a""b"')
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
