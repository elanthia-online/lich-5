# spec/lib/dependency_recovery_spec.rb
require 'digest'
require 'fileutils'
require 'json'
require 'pp'
require 'rubygems/package'
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

  context 'Lich version ranges' do
    let(:legacy) { gem_unit(name: 'sqlite3', artifact_url: artifact_url, body: artifact_body) }
    let(:modern) do
      gem_unit(name: 'sqlite3', artifact_url: 'https://example.test/new.gem', body: 'new payload').merge(
        'id' => 'sqlite3-current', 'lich_versions' => { 'min_inclusive' => '5.24.0', 'max_exclusive' => '6.0' }
      ).tap { |unit| unit.fetch('packages').first['version'] = '2.10.2' }
    end

    def ranged_recovery(version, units: [legacy, modern])
      described_class.new(manifest_url: manifest_url, gem_home: gem_home, temp_dir: recovery_temp_dir,
                          lich_version: version, http_get: ->(_url) { manifest_for(units, ruby_abi: ruby_abi, platform: platform) })
    end

    it 'keeps the legacy closure below the lower bound and at the exclusive upper bound' do
      %w[5.23.9 6.0].each do |version|
        expect(ranged_recovery(version).recovery_plan(['sqlite3']).units.map { |unit| unit['id'] }).to eq(['sqlite3'])
      end
    end

    it 'selects the modern closure at the inclusive lower bound for recovery and startup policy' do
      recovery = ranged_recovery('5.24.0')
      expect(recovery.recovery_plan(['sqlite3']).units).to eq([modern])
      expect(recovery.policy_plan(['sqlite3']).target.fetch('units')).to eq([modern])
    end

    it 'rejects invalid, ambiguous or unknown-version range policy before downloading packages' do
      expect(ranged_recovery(nil).recovery_plan(['sqlite3'])).not_to be_success
      modern['lich_versions']['max_exclusive'] = '5.0'
      expect(ranged_recovery('5.24').policy_plan(['sqlite3']).error).to include('empty Lich version range')
      modern['lich_versions'].delete('max_exclusive')
      duplicate = Marshal.load(Marshal.dump(modern)).merge('id' => 'overlap')
      duplicate.fetch('packages').first['version'] = '2.10.3'
      expect(ranged_recovery('5.24', units: [legacy, modern, duplicate]).recovery_plan(['sqlite3']).error).to include('ambiguous ranged')
    end

    it 'requires legacy coverage to precede ranges and rejects withdrawal through alternate units' do
      expect(ranged_recovery('5.24', units: [modern, legacy]).recovery_plan(['sqlite3']).error).to include('legacy coverage')
      target = { 'units' => [legacy], 'withdrawn_members' => ['sqlite3'] }
      expect { Lich::RecoveryUnitPolicy.select(target, '5.24') }.to raise_error(Lich::RecoveryUnitPolicy::Error, /withdrawn member/)
    end

    it 'recovers an added transitive package only with the applicable newer closure' do
      modern['members'] << 'added-child'
      child = { 'name' => 'added-child', 'version' => '1.0', 'filename' => 'added-child.gem', 'sha256' => sha256('child bytes') }
      modern['packages'] << child
      modern['install_order'] = ['added-child', 'sqlite3']
      modern['artifact'] = { 'url' => 'https://example.test/new.zip', 'filename' => 'new.zip', 'archive' => 'zip', 'sha256' => sha256('zip bytes') }
      manifest = manifest_for([legacy, modern], ruby_abi: ruby_abi, platform: platform)
      fetches = []
      fetch = lambda do |url|
        fetches << url
        { manifest_url => manifest, 'https://example.test/new.zip' => 'zip bytes' }.fetch(url)
      end
      extractor = lambda do |_zip, destination|
        File.write(File.join(destination, 'sqlite3.gem'), 'new payload')
        File.write(File.join(destination, 'added-child.gem'), 'child bytes')
      end
      engine = described_class.new(manifest_url: manifest_url, gem_home: gem_home, temp_dir: recovery_temp_dir,
                                   lich_version: '5.24', http_get: fetch, extract_zip: extractor,
                                   install_gem: ->(path, _home) { installed << File.basename(path) })
      expect(engine.recover(['sqlite3'])).to be_success
      expect(installed).to eq(['added-child.gem', 'sqlite3.gem'])
      expect(fetches).not_to include(artifact_url)
      expect(ranged_recovery('5.23').recovery_plan(['sqlite3']).units).to eq([legacy])
    end

    it 'never installs an older shared package via an overlapping legacy closure' do
      legacy['members'] << 'parent'
      legacy['packages'] << legacy['packages'].first.merge('name' => 'parent')
      legacy['install_order'] << 'parent'
      result = ranged_recovery('5.24').recovery_plan(['parent', 'sqlite3'])
      expect(result).not_to be_success
      expect(result.error).to include('does not approve recovery')
    end
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
    other_platform = platform == 'x64-mingw-ucrt' ? 'x86_64-linux' : 'x64-mingw-ucrt'
    manifest = manifest_for([unit], ruby_abi: ruby_abi, platform: other_platform)
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

  it 'defers a native single-gem artifact until the current process has exited' do
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
    expect(result.restart_required).to be(true)
    expect(launcher).to have_received(:call)
    expect(installed).to be_empty
  end

  describe 'native replacement rollback' do
    let(:work_dir) { File.join(recovery_temp_dir, 'replacement work') }
    let(:rollback_dir) { Dir.glob(File.join(gem_home, '.lich-previous-runtime-*')).fetch(0) }
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

    it 'rolls back Windows sharing contention with a second DLL holder, then retries and relaunches with native load' do
      skip 'requires the native Windows loader and sharing rules' unless Gem.win_platform?

      require 'digest/sha2'
      native = $LOADED_FEATURES.find { |path| File.basename(path).match?(/\Asha2\.(?:so|dll)\z/i) }
      raise 'Ruby digest native fixture is unavailable' unless native && File.file?(native)
      blocked = runtime_specs.first.extension_dir
      held_library = File.join(blocked, 'original.dll')
      FileUtils.cp(native, held_library)
      originals = original_files.to_h { |path| [path, File.binread(path)] }
      helper = File.expand_path('../support/native_dll_holder.rb', __dir__)
      environment = { 'RUBYOPT' => nil, 'RUBYLIB' => nil, 'BUNDLER_SETUP' => nil, 'RUBYGEMS_GEMDEPS' => nil }
      input, output, errors, holder = Open3.popen3(environment, RbConfig.ruby, helper, held_library, blocked)
      ready = Timeout.timeout(15) { output.gets }
      unless ready == "native-library-held\n"
        diagnostics = Timeout.timeout(5) { errors.read }
        raise "native library holder failed: #{diagnostics}"
      end
      allow(subject).to receive(:backup_path).and_call_original
      allow(installer).to receive(:call).and_wrap_original do |install, path, home|
        install.call(path, home)
        spec = runtime_specs.find { |entry| File.basename(path) == "#{entry.full_name}.gem" }
        FileUtils.cp(native, File.join(spec.extension_dir, 'original.dll'))
      end
      expect { subject.send(:run_windows_replacement!, payload) }.to raise_error(described_class::Error)
      expect(subject).to have_received(:backup_path).with(blocked, kind_of(String), kind_of(Array))
      expect(installer).not_to have_received(:call)
      expect(subject).not_to have_received(:restart_lich)
      expect(originals.keys.to_h { |path| [path, File.binread(path)] }).to eq(originals)
      expect(Dir.glob(File.join(gem_home, '.lich-previous-runtime-*'))).to be_empty

      input.write('x')
      input.close
      released = Timeout.timeout(15) { holder.value }
      expect(released.success?).to be(true), errors.read
      marker = File.join(recovery_temp_dir, 'native-relaunch-complete')
      relaunch = File.join(recovery_temp_dir, 'native-relaunch.rb')
      File.write(relaunch, "require 'fiddle'\nFiddle.dlopen(#{held_library.inspect}).close\nFile.write(#{marker.inspect}, 'native-load-ok')\n")
      payload['restart'] = { 'program' => relaunch, 'argv' => [], 'chdir' => recovery_temp_dir }
      allow(subject).to receive(:restart_lich).and_call_original
      restarted = subject.send(:run_windows_replacement!, payload)
      _pid, status = Timeout.timeout(15) { Process.waitpid2(restarted) }
      restarted = nil
      expect(status.success?).to be(true)
      expect(File.read(marker)).to eq('native-load-ok')
      expect(subject).to have_received(:restart_lich).once
    ensure
      input.close if input && !input.closed?
      if holder&.alive?
        Process.kill('KILL', holder.pid) rescue nil
        holder.join(5)
      end
      [output, errors].compact.each { |io| io.close unless io.closed? }
      if restarted
        Process.kill('KILL', restarted) rescue nil
        Process.waitpid(restarted) rescue nil
      end
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
      expect(Dir.glob(File.join(gem_home, '.lich-previous-runtime-*'))).to be_empty
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
      expect(Dir.glob(File.join(gem_home, '.lich-previous-runtime-*'))).to be_empty
    end

    it 'preserves leftover content while removing only empty rollback directories' do
      allow(installer).to receive(:call).and_raise(IOError, 'install failed')
      allow(subject).to receive(:restore_backup).and_wrap_original do |restore, moved|
        restore.call(moved)
        File.write(File.join(rollback_dir, 'retained'), 'recovery evidence')
      end

      expect { subject.send(:run_windows_replacement!, payload) }.to raise_error(IOError, /install failed/)

      expect(Dir.children(rollback_dir)).to eq(['retained'])
      expect(File.read(File.join(rollback_dir, 'retained'))).to eq('recovery evidence')
    end

    it 'does not follow or remove symlinks during empty rollback cleanup' do
      backup_root = File.join(gem_home, 'empty-backup')
      link = File.join(backup_root, 'retained-link')
      FileUtils.mkdir_p(link)
      # Model lstat's symlink result without requiring Windows symlink privileges.
      allow(File).to receive(:lstat).and_call_original
      allow(File).to receive(:lstat).with(link).and_return(instance_double(File::Stat, directory?: false))
      allow(Dir).to receive(:children).and_call_original
      allow(Dir).to receive(:rmdir).and_call_original

      subject.send(:remove_empty_backup_directories, backup_root)

      expect(Dir).not_to have_received(:children).with(link)
      expect(Dir).not_to have_received(:rmdir).with(link)
      expect(Dir.children(backup_root)).to eq(['retained-link'])
    ensure
      allow(File).to receive(:lstat).and_call_original
    end

    it 'preserves the original error when empty rollback cleanup is denied' do
      allow(installer).to receive(:call).and_raise(IOError, 'install failed')
      allow(Dir).to receive(:rmdir).and_raise(Errno::EACCES, 'cleanup denied')

      expect { subject.send(:run_windows_replacement!, payload) }.to raise_error(IOError, /install failed/)

      expect(original_files.map { |file| File.read(file) }).to all(eq('original'))
      expect(Dir).to exist(rollback_dir)
    ensure
      allow(Dir).to receive(:rmdir).and_call_original
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

    it 'replaces an unregistered existing destination after moving it aside' do
      orphan = File.join(runtime_specs.first.full_gem_path, 'unregistered.dll')
      allow(Gem::Specification).to receive(:find_all_by_name).with(runtime_specs.first.name).and_return([])
      File.write(orphan, 'untouched')

      subject.send(:run_windows_replacement!, payload)

      expect(File).not_to exist(orphan)
      expect(original_files.map { |file| File.read(file) }).to all(eq('replacement'))
      expect(subject).to have_received(:restart_lich).once
    end

    it 'restores an unregistered destination if replacement fails without restarting' do
      orphan = File.join(runtime_specs.first.full_gem_path, 'unregistered.dll')
      allow(Gem::Specification).to receive(:find_all_by_name).with(runtime_specs.first.name).and_return([])
      File.write(orphan, 'untouched')
      allow(installer).to receive(:call).and_wrap_original do |install, path, home|
        install.call(path, home)
        raise IOError, 'replacement failed'
      end
      expect(subject).not_to receive(:restart_lich)

      expect { subject.send(:run_windows_replacement!, payload) }
        .to raise_error(IOError, /replacement failed/)

      expect(File.read(orphan)).to eq('untouched')
      expect(original_files.map { |file| File.read(file) }).to all(eq('original'))
    end

    it 'keeps backup moves under the gem home independently of Lich temp storage' do
      moves = []
      allow(FileUtils).to receive(:mv).and_wrap_original do |move, from, to|
        moves << [from, to]
        move.call(from, to)
      end

      subject.send(:run_windows_replacement!, payload)

      expect(moves).not_to be_empty
      expect(moves.map(&:last)).to all(start_with(File.join(gem_home, '.lich-previous-runtime-')))
      expect(moves.flatten).not_to include(start_with(recovery_temp_dir))
    end

    it 'refuses an occupied backup destination without moving or nesting the source' do
      backup_root = File.join(gem_home, 'occupied-backup')
      source = runtime_specs.first.full_gem_path
      destination = File.join(backup_root, 'gems', runtime_specs.first.full_name)
      FileUtils.mkdir_p(destination)
      File.write(File.join(destination, 'retained'), 'earlier backup')
      moved = []

      expect { subject.send(:backup_path, source, backup_root, moved) }
        .to raise_error(described_class::Error, /backup destination already exists/)

      expect(moved).to be_empty
      expect(File.read(File.join(source, 'original.rb'))).to eq('original')
      expect(Dir.children(destination)).to eq(['retained'])
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

  describe 'native replacement rollback with real RubyGems' do
    let(:gem_home) { File.realpath(Dir.mktmpdir('lich-recovery-real-gems')) }
    let(:gem_name) { 'lich_f63_fixture' }
    let(:work_dir) { File.join(recovery_temp_dir, 'real replacement') }
    let(:replacement_body) { "FIXTURE_VERSION = '2.0.0'\n" }
    let(:package) do
      path = build_recovery_gem('2.0.0', replacement_body)
      { 'name' => gem_name, 'version' => '2.0.0', 'filename' => File.basename(path),
        'path' => path, 'sha256' => sha256(File.binread(path)) }
    end
    let(:payload) do
      { 'schema' => 1, 'parent_pid' => Process.pid, 'gem_home' => gem_home,
        'temp_dir' => recovery_temp_dir, 'work_dir' => work_dir, 'packages' => [package],
        'restart' => { 'program' => __FILE__, 'argv' => [], 'chdir' => work_dir } }
    end
    let(:subject) { described_class.new(gem_home: gem_home, temp_dir: recovery_temp_dir) }

    around do |example|
      original_home = Gem.dir
      original_path = Gem.path
      original_environment = ENV.to_h.slice('GEM_HOME', 'GEM_PATH')
      # Ambient reset hooks must not repopulate the isolated fixture registry.
      original_reset_hooks = Gem.post_reset_hooks.dup
      Gem.post_reset_hooks.clear
      ENV['GEM_HOME'] = gem_home
      ENV['GEM_PATH'] = gem_home
      Gem.use_paths(gem_home, [gem_home])
      example.run
    ensure
      %w[GEM_HOME GEM_PATH].each { |name| ENV[name] = original_environment[name] }
      Gem.post_reset_hooks.replace(original_reset_hooks)
      Gem.use_paths(original_home, original_path)
    end

    before do
      allow(Gem::Specification).to receive(:find_all_by_name).and_call_original
      allow(Gem::Specification).to receive(:reset).and_call_original
      allow(Gem).to receive(:clear_paths).and_call_original
      FileUtils.mkdir_p(work_dir)
      seed = build_recovery_gem('1.0.0', "FIXTURE_VERSION = '1.0.0'\n")
      subject.send(:install_gem_file, seed, gem_home)
      Gem::Specification.reset
      allow(subject).to receive(:wait_for_parent_exit)
      allow(subject).to receive(:restart_lich)
    end

    def build_recovery_gem(version, body)
      source = File.join(recovery_temp_dir, "source-#{version}")
      FileUtils.mkdir_p(File.join(source, 'lib'))
      File.write(File.join(source, 'lib', "#{gem_name}.rb"), body)
      spec = Gem::Specification.new do |entry|
        entry.name = gem_name
        entry.version = version
        entry.summary = 'Isolated dependency recovery regression fixture'
        entry.authors = ['Lich contributors']
        entry.files = ["lib/#{gem_name}.rb"]
        entry.license = 'MIT'
        entry.homepage = 'https://example.test/'
      end
      filename = Dir.chdir(source) do
        Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) { Gem::Package.build(spec) }
      end
      destination = File.join(work_dir, filename)
      FileUtils.mv(File.join(source, filename), destination)
      destination
    end

    def installed_versions
      Gem::Specification.reset
      Gem::Specification.find_all_by_name(gem_name).map { |spec| spec.version.to_s }
    end

    def expect_original_runtime
      expect(installed_versions).to eq(['1.0.0'])
      file = File.join(gem_home, 'gems', "#{gem_name}-1.0.0", 'lib', "#{gem_name}.rb")
      expect(File.read(file)).to eq("FIXTURE_VERSION = '1.0.0'\n")
      expect(subject).not_to have_received(:restart_lich)
    end

    def fail_after_real_install
      allow(Gem::Installer).to receive(:at).and_wrap_original do |at, *args, **options|
        installer = at.call(*args, **options)
        if options[:force]
          allow(installer).to receive(:install).and_wrap_original do |install|
            install.call
            raise IOError, 'after real install'
          end
        end
        installer
      end
    end

    it 'uses real installer paths and recovers after failure before gemspec publication' do
      paths = subject.send(:replacement_package_paths, package)
      allow(Gem::Installer).to receive(:at).and_wrap_original do |at, *args, **options|
        installer = at.call(*args, **options)
        if options[:force]
          allow(installer).to receive(:write_spec).and_raise(IOError, 'before gemspec')
        end
        installer
      end

      expect { subject.send(:run_windows_replacement!, payload) }.to raise_error(IOError, /before gemspec/)

      expect(paths).to all(satisfy { |path| !File.exist?(path) })
      expect_original_runtime

      expect(Dir.glob(File.join(gem_home, '.lich-previous-runtime-*'))).to be_empty
      allow(Gem::Installer).to receive(:at).and_call_original
      subject.send(:run_windows_replacement!, payload)

      expect(installed_versions).to eq(['2.0.0'])
      spec = Gem::Specification.find_by_name(gem_name, '= 2.0.0')
      expect(paths).to contain_exactly(spec.full_gem_path, spec.loaded_from, spec.extension_dir)
      expect(File.read(File.join(spec.full_gem_path, 'lib', "#{gem_name}.rb"))).to eq(replacement_body)
      expect(subject).to have_received(:restart_lich).once
    end

    it 'unregisters a real late-failing install and restores the original without restarting' do
      fail_after_real_install

      expect { subject.send(:run_windows_replacement!, payload) }.to raise_error(IOError, /after real install/)

      expect_original_runtime
      expect(File).not_to exist(File.join(gem_home, 'gems', "#{gem_name}-2.0.0"))
      expect(File).to exist(File.join(gem_home, 'cache', "#{gem_name}-2.0.0.gem"))
      expect(Dir.glob(File.join(gem_home, '.lich-previous-runtime-*'))).to be_empty
    end

    it 'restores an orphan byte for byte after a real install fails' do
      orphan = File.join(gem_home, 'gems', "#{gem_name}-2.0.0", 'orphan.dll')
      FileUtils.mkdir_p(File.dirname(orphan))
      File.binwrite(orphan, "prior\x00content")
      fail_after_real_install

      expect { subject.send(:run_windows_replacement!, payload) }.to raise_error(IOError, /after real install/)

      expect(File.binread(orphan)).to eq("prior\x00content")
      expect(Dir.children(File.dirname(orphan))).to eq(['orphan.dll'])
      expect_original_runtime
    end

    it 'recovers on a separately initiated launch after a helper is killed before writing its gemspec' do
      same_version = build_recovery_gem('1.0.0', "FIXTURE_VERSION = 'reinstalled'\n")
      payload['packages'] = [{ 'name' => gem_name, 'version' => '1.0.0', 'filename' => File.basename(same_version),
                               'path' => same_version, 'sha256' => sha256(File.binread(same_version)) }]
      transaction = File.join(work_dir, 'transaction.json')
      File.write(transaction, JSON.generate(payload))
      helper = <<~RUBY
        require ARGV.shift
        Gem.use_paths(ARGV.shift)
        payload = JSON.parse(File.read(ARGV.shift))
        installer = lambda do |path, home|
          gem = Gem::Installer.at(path, install_dir: home, ignore_dependencies: true, wrappers: false, force: true)
          gem.define_singleton_method(:write_spec) do
            File.write(File.join(payload.fetch('work_dir'), 'installer-interruption'), 'before gemspec')
            Process.kill('KILL', Process.pid)
          end
          gem.install
        end
        recovery = Lich::DependencyRecovery.new(gem_home: Gem.dir, temp_dir: payload.fetch('temp_dir'), install_gem: installer)
        def recovery.wait_for_parent_exit(_pid); end
        def recovery.restart_lich(_restart); raise 'unexpected restart'; end
        recovery.send(:run_windows_replacement!, payload)
      RUBY
      environment = {
        'GEM_HOME' => gem_home, 'GEM_PATH' => gem_home, 'RUBYOPT' => nil, 'RUBYLIB' => nil,
        'BUNDLER_SETUP' => nil, 'RUBYGEMS_GEMDEPS' => nil
      }
      _, stderr, status = Open3.capture3(
        environment, RbConfig.ruby, '-e', helper,
        File.expand_path('../../lib/dependency_recovery.rb', __dir__), gem_home, transaction
      )

      # Windows can report exit 0 for KILL. Require evidence that write_spec
      # was reached, and report the child diagnostics if any state is wrong.
      diagnostics = "Helper status: #{status.inspect}\n#{stderr}"
      expect(File).to exist(File.join(work_dir, 'installer-interruption')), diagnostics
      expect(status.termsig).to eq(Signal.list.fetch('KILL')), diagnostics unless Gem.win_platform?
      expect(installed_versions).to be_empty, diagnostics
      expect(Dir).to exist(File.join(gem_home, 'gems', "#{gem_name}-1.0.0")), diagnostics
      expect(File).not_to exist(File.join(gem_home, 'specifications', "#{gem_name}-1.0.0.gemspec")), diagnostics

      subject.send(:run_windows_replacement!, payload)

      expect(installed_versions).to eq(['1.0.0'])
      expect(File.read(File.join(gem_home, 'gems', "#{gem_name}-1.0.0", 'lib', "#{gem_name}.rb")))
        .to eq("FIXTURE_VERSION = 'reinstalled'\n")
      expect(subject).to have_received(:restart_lich).once
    end

    context 'when repairing a direct sqlite3 unit' do
      let(:gem_name) { 'sqlite3' }

      it 'checks the exact accepted sqlite3 in a fresh process before relaunching' do
        subject.send(:run_windows_replacement!, payload)
        expect(installed_versions).to eq(['2.0.0'])
        expect(subject).to have_received(:restart_lich).once
      end

      context 'when the replacement cannot load' do
        let(:replacement_body) { "raise LoadError, 'fixture sqlite DLL unavailable'\n" }

        it 'restores the prior registration and stops instead of repeatedly restarting' do
          expect { subject.send(:run_windows_replacement!, payload) }
            .to raise_error(described_class::Error, /sqlite3 runtime could not load.*fixture sqlite DLL unavailable/m)
          expect_original_runtime
        end
      end
    end

    context 'when the bundle contains GTK' do
      let(:gem_name) { 'gtk3' }

      it 'checks the replacement in a fresh process before restarting Lich' do
        subject.send(:run_windows_replacement!, payload)

        expect(installed_versions).to eq(['2.0.0'])
        expect(subject).to have_received(:restart_lich).once
        expect(Dir.glob(File.join(gem_home, '.lich-previous-runtime-*'))).to be_empty
      end

      context 'with inherited dependency activation settings' do
        let(:replacement_body) do
          "raise 'inherited gem dependency file' if ENV['RUBYGEMS_GEMDEPS']\n"
        end

        around do |example|
          original_environment = ENV.to_h.slice('BUNDLER_SETUP', 'RUBYGEMS_GEMDEPS')
          startup = File.join(recovery_temp_dir, 'unrelated-startup.rb')
          File.write(startup, "raise 'inherited startup file was loaded'\n")
          ENV['BUNDLER_SETUP'] = startup
          ENV['RUBYGEMS_GEMDEPS'] = File.join(recovery_temp_dir, 'unrelated.Gemfile')
          example.run
        ensure
          %w[BUNDLER_SETUP RUBYGEMS_GEMDEPS].each { |name| ENV[name] = original_environment[name] }
        end

        it 'loads only the replacement runtime without inherited startup hooks' do
          subject.send(:run_windows_replacement!, payload)

          expect(installed_versions).to eq(['2.0.0'])
          expect(subject).to have_received(:restart_lich).once
        end
      end

      context 'when GTK cannot load' do
        let(:replacement_body) { "raise LoadError, 'fixture native DLL unavailable'\n" }

        it 'restores the prior bundle and aborts without restarting' do
          expect { subject.send(:run_windows_replacement!, payload) }
            .to raise_error(described_class::Error, /GTK runtime could not load.*fixture native DLL unavailable/m)

          expect_original_runtime
          expect(File).not_to exist(File.join(gem_home, 'gems', 'gtk3-2.0.0'))
        end
      end

      context 'when GTK load hangs' do
        let(:replacement_body) { "sleep 120\n" }

        it 'reaps the probe and restores the prior bundle without restarting' do
          stub_const('Lich::DependencyRecovery::NATIVE_LOAD_TIMEOUT_SECONDS', 0.1)
          probe_pid = nil
          allow(Process).to receive(:spawn).and_wrap_original do |spawn, *args, **options|
            probe_pid = spawn.call(*args, **options)
          end

          expect { subject.send(:run_windows_replacement!, payload) }
            .to raise_error(described_class::Error, /timed out checking/)

          expect_original_runtime
          expect { Process.waitpid(probe_pid, Process::WNOHANG) }.to raise_error(Errno::ECHILD)
        end
      end
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
  describe 'accepted policy and upgrade transactions' do
    let(:unit) { gem_unit(name: 'sqlite3', artifact_url: artifact_url, body: artifact_body) }
    let(:manifest) { manifest_for([unit], ruby_abi: ruby_abi, platform: platform) }
    let(:subject) { recovery(artifacts: { manifest_url => manifest, artifact_url => artifact_body }) }

    it 'validates all applicable units even when an invalid one is not requested' do
      invalid = gem_unit(name: 'other', artifact_url: artifact_url, body: artifact_body)
      invalid['packages'].first['sha256'] = 'invalid'
      data = manifest_for([unit, invalid], ruby_abi: ruby_abi, platform: platform)
      subject = recovery(artifacts: { manifest_url => data })
      expect(subject.policy_plan(['sqlite3']).error).to include('SHA-256')
      expect(installed).to be_empty
    end

    it 'rejects duplicate applicable targets rather than picking the first' do
      data = JSON.parse(manifest)
      data['targets'] << data['targets'].first.dup
      subject = recovery(artifacts: { manifest_url => JSON.generate(data) })
      expect(subject.policy_plan(['sqlite3']).error).to include('duplicate targets')
    end

    it 'rejects empty policy rather than reporting all dependencies satisfied' do
      subject = recovery(artifacts: { manifest_url => manifest_for([], ruby_abi: ruby_abi, platform: platform) })
      expect(subject.policy_plan(['sqlite3']).error).to include('no recovery units')
    end

    it 'reports an unavailable policy without making runtime changes' do
      subject = described_class.new(gem_home: gem_home, temp_dir: recovery_temp_dir, http_get: ->(_) { raise SocketError, 'offline' })
      expect(subject.policy_plan(['sqlite3']).error).to include('offline')
      expect(installed).to be_empty
    end

    it 'bounds the whole manifest fetch and parse operation' do
      expect(Timeout).to receive(:timeout).with(described_class::MANIFEST_TIMEOUT_SECONDS).and_raise(Timeout::Error)
      expect(subject.policy_plan(['sqlite3'])).not_to be_success
      expect(installed).to be_empty
    end

    it 'rejects oversized manifest bytes' do
      subject = recovery(artifacts: { manifest_url => 'x' * (described_class::MAX_MANIFEST_BYTES + 1) })
      expect(subject.policy_plan(['sqlite3']).error).to include('size limit')
    end

    it 'bounds the whole staging operation before starting a helper' do
      plan = subject.recovery_plan(['sqlite3'])
      expect(Timeout).to receive(:timeout).with(described_class::DOWNLOAD_TIMEOUT_SECONDS).and_raise(Timeout::Error)
      result = subject.recover(['sqlite3'], plan: plan, restart: true)
      expect(result).not_to be_success
      expect(installed).to be_empty
      expect(Dir.children(recovery_temp_dir)).to be_empty
    end

    it 'starts only one helper for multiple complete units, including pure repairs' do
      second = gem_unit(name: 'other', artifact_url: 'https://example.test/other.gem', body: 'other')
      data = manifest_for([unit, second], ruby_abi: ruby_abi, platform: platform)
      payloads = []
      subject = recovery(artifacts: { manifest_url => data, artifact_url => artifact_body, 'https://example.test/other.gem' => 'other' },
                         helper_launcher: ->(path) { payloads << JSON.parse(File.read(path)) })
      result = subject.recover(%w[sqlite3 other], force: true, restart: true, preserve_newer: true)
      expect(result).to be_success
      expect(result.restart_required).to be(true)
      expect(installed).to be_empty
      expect(payloads.length).to eq(1)
      expect(payloads.first.fetch('packages').map { |package| package.fetch('name') }).to eq(%w[sqlite3 other])
      expect(payloads.first.fetch('preserve_newer')).to be(true)
    end

    it 'does not launch a repair helper when the gem home is unwritable' do
      allow(File).to receive(:open).and_call_original
      expect(File).to receive(:open).with(File.join(gem_home, described_class::LOCK_FILENAME), anything, anything).and_raise(Errno::EACCES)
      expect(subject).not_to receive(:schedule_runtime_replacement)
      result = subject.recover(['sqlite3'], restart: true)
      expect(result.error).to include('Cannot write Ruby runtime gem directory')
      expect(installed).to be_empty
    end

    it 'preserves a newer installed package when backing up versions for a floor repair' do
      newer = Gem::Specification.new { |spec| spec.name = 'sqlite3'; spec.version = '9.0' }
      newer.loaded_from = File.join(gem_home, 'specifications', 'sqlite3-9.0.gemspec')
      FileUtils.mkdir_p(File.dirname(newer.loaded_from))
      File.write(newer.loaded_from, 'newer registration')
      allow(Gem::Specification).to receive(:find_all_by_name).with('sqlite3').and_return([newer])
      moved = []
      subject.send(:backup_existing_packages, unit.fetch('packages'), File.join(gem_home, 'backup'), moved, preserve_newer: true)
      expect(moved).to be_empty
      expect(File.read(newer.loaded_from)).to eq('newer registration')
    end
  end
end
