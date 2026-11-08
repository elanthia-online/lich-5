# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require_relative '../../../lib/common/front-end'
require_relative '../../../lib/common/frontend_locator'

RSpec.describe Lich::Common::FrontendLocator do
  let(:frontend) { Lich::Common::Frontend }

  def executable(path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#!/bin/sh\n")
    FileUtils.chmod(0o755, path)
    path
  end

  # Stubs Win32::Registry with hives mapping key => { value_name => data }.
  # Opening a missing key raises Registry::Error, as the real binding does.
  # Returns the [hive, key, access] tuples each open received.
  def stub_windows_registry(hives)
    opened = []
    error = Class.new(StandardError)
    registry = Module.new
    registry.const_set(:KEY_READ, 1)
    registry.const_set(:Error, error)
    hives.each do |hive_name, keys|
      hkey = Object.new
      hkey.define_singleton_method(:open) do |key, access, &block|
        opened << [hive_name, key, access]
        values = keys.fetch(key) { raise error, "missing #{key}" }
        block.call(values)
      end
      registry.const_set(hive_name, hkey)
    end
    win32 = Module.new
    win32.const_set(:Registry, registry)
    stub_const('Win32', win32)
    opened
  end

  def no_spotlight
    ->(_bundle_id) { [] }
  end

  def windows_locator
    locator = described_class.new(platform_key: :windows, environment: { 'PATH' => '' })
    allow(locator).to receive(:require).with('win32/registry').and_return(true)
    locator
  end

  def mac_application(applications, name:, bundle_id:, executable_name:)
    bundle = File.join(applications, "#{name}.app")
    executable_path = executable(File.join(bundle, 'Contents', 'MacOS', executable_name))
    plist = <<~PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <plist version="1.0"><dict>
      <key>CFBundleIdentifier</key><string>#{bundle_id}</string>
      </dict></plist>
    PLIST
    File.write(File.join(bundle, 'Contents', 'Info.plist'), plist)
    executable_path
  end

  it 'resolves an executable from PATH' do
    Dir.mktmpdir do |directory|
      wrayth = executable(File.join(directory, 'Wrayth.exe'))
      locator = described_class.new(
        platform_key: :linux,
        environment: { 'PATH' => directory }
      )

      expect(locator.resolve('stormfront')).to eq(
        described_class::Resolution.new(
          frontend_id: 'stormfront',
          executable_path: File.realpath(wrayth),
          source: :path
        )
      )
    end
  end

  it 'returns nil when a known frontend is unavailable' do
    locator = described_class.new(
      platform_key: :linux,
      environment: { 'PATH' => '' }
    )

    expect(locator.resolve('stormfront')).to be_nil
  end

  it 'finds Avalon in a renamed or versioned macOS application bundle' do
    Dir.mktmpdir do |applications|
      avalon = mac_application(
        applications,
        name: 'Avalon 4.4 custom',
        bundle_id: 'SimutronicsAvalon',
        executable_name: 'Avalon'
      )
      locator = described_class.new(
        platform_key: :darwin,
        environment: { 'PATH' => '' },
        application_roots: [applications],
        spotlight: no_spotlight
      )

      expect(locator.resolve('avalon')).to eq(
        described_class::Resolution.new(
          frontend_id: 'avalon',
          executable_path: File.realpath(avalon),
          source: :application
        )
      )
    end
  end

  it 'makes an installed Saga selectable on its supported macOS cold-start adapter' do
    Dir.mktmpdir do |applications|
      mac_application(
        applications,
        name: 'Saga',
        bundle_id: 'com.auchand.saga',
        executable_name: 'Saga'
      )
      locator = described_class.new(
        platform_key: :darwin,
        environment: { 'PATH' => '' },
        application_roots: [applications],
        spotlight: no_spotlight
      )

      expect(locator.selectable?('saga')).to be(true)
      expect(locator.launchable?('saga')).to be(true)
      expect(locator.available(gui_selectable: true).map(&:frontend_id)).to include('saga')
    end
  end

  it 'makes the conventional Linux Saga installation selectable' do
    saga = '/opt/Saga/saga'
    locator = described_class.new(
      platform_key: :linux,
      environment: { 'PATH' => '' }
    )
    allow(File).to receive(:file?).with(saga).and_return(true)
    allow(File).to receive(:executable?).with(saga).and_return(true)
    allow(File).to receive(:realpath).with(saga).and_return(saga)

    expect(locator.resolve('saga')).to eq(
      described_class::Resolution.new(
        frontend_id: 'saga',
        executable_path: saga,
        source: :conventional
      )
    )
    expect(locator.selectable?('saga')).to be(true)
    expect(locator.launchable?('saga')).to be(true)
  end

  it 'keeps Saga unavailable on an unsupported platform key' do
    locator = described_class.new(
      platform_key: :unsupported,
      environment: { 'PATH' => '' }
    )

    expect(locator.resolve('saga')).to be_nil
    expect(locator.selectable?('saga')).to be(false)
    expect(locator.launchable?('saga')).to be(false)
    expect(locator.available(gui_selectable: true).map(&:frontend_id)).not_to include('saga')
  end

  it 'separates native launch support from GUI presentation metadata' do
    Dir.mktmpdir do |directory|
      executable(File.join(directory, 'Wrayth.exe'))
      locator = described_class.new(
        platform_key: :windows,
        environment: { 'PATH' => directory }
      )

      expect(locator.launchable?('stormfront')).to be(true)
      expect(locator.launchable?('suks')).to be(true)
      expect(locator.launchable?('profanity')).to be(false)
    end
  end

  it 'raises for an unknown frontend identifier' do
    locator = described_class.new(platform_key: :linux, environment: { 'PATH' => '' })

    expect { locator.resolve('not-a-frontend') }
      .to raise_error(ArgumentError, 'unknown frontend: not-a-frontend')
  end

  it 'raises rather than falling back when an explicit override is invalid' do
    locator = described_class.new(platform_key: :linux, environment: { 'PATH' => '' })

    expect { locator.resolve('saga', override: '/missing/Saga') }
      .to raise_error(ArgumentError, 'frontend override is not executable: /missing/Saga')
  end

  it 'raises when an explicit override disappears during resolution' do
    Dir.mktmpdir do |directory|
      override = executable(File.join(directory, 'Saga'))
      locator = described_class.new(platform_key: :darwin, environment: { 'PATH' => '' })
      allow(File).to receive(:realpath).with(override).and_raise(Errno::ENOENT, override)

      expect { locator.resolve('saga', override: override) }
        .to raise_error(ArgumentError, "frontend override is not executable: #{override}")
    end
  end

  it 'gives an explicit override priority without changing the cached discovery result' do
    Dir.mktmpdir do |directory|
      discovered = executable(File.join(directory, 'installed', 'Wrayth.exe'))
      override = executable(File.join(directory, 'portable', 'Wrayth.exe'))
      locator = described_class.new(
        platform_key: :linux,
        environment: { 'PATH' => File.dirname(discovered) }
      )

      expect(locator.resolve('stormfront').executable_path).to eq(File.realpath(discovered))
      expect(locator.resolve('stormfront', override: override).source).to eq(:override)
      expect(locator.resolve('stormfront').executable_path).to eq(File.realpath(discovered))
    end
  end

  it 'logs handled filesystem discovery failures and reports unavailable' do
    messages = []
    locator = described_class.new(
      platform_key: :linux,
      environment: { 'PATH' => '/inaccessible' },
      logger: ->(message) { messages << message }
    )
    allow(File).to receive(:file?).and_raise(Errno::EACCES, 'permission denied')

    expect(locator.resolve('stormfront')).to be_nil
    expect(messages).not_to be_empty
    expect(messages.first).to include('frontend discovery failed')
  end

  it 'returns only installed GUI-selectable frontends' do
    Dir.mktmpdir do |directory|
      executable(File.join(directory, 'Wrayth.exe'))
      locator = described_class.new(
        platform_key: :linux,
        environment: { 'PATH' => directory }
      )

      expect(locator.available(gui_selectable: true).map(&:frontend_id)).to eq(['stormfront'])
    end
  end

  it 'does not mutate the frontend definition collection while filtering by platform' do
    definitions = frontend.definitions(gui_selectable: true).freeze
    locator = described_class.new(platform_key: :linux, environment: { 'PATH' => '' })
    allow(frontend).to receive(:definitions).with(gui_selectable: true).and_return(definitions)
    allow(locator).to receive(:resolve).and_return(nil)

    expect { locator.available(gui_selectable: true) }.not_to raise_error
    expect(definitions.map { |definition| definition[:id] })
      .to contain_exactly('stormfront', 'wizard', 'avalon', 'saga', 'profanity')
  end

  it 'refreshes cached unavailable results' do
    Dir.mktmpdir do |directory|
      locator = described_class.new(
        platform_key: :linux,
        environment: { 'PATH' => directory }
      )

      expect(locator.resolve('stormfront')).to be_nil
      executable(File.join(directory, 'Wrayth.exe'))
      expect(locator.resolve('stormfront')).to be_nil
      expect(locator.resolve('stormfront', refresh: true)).not_to be_nil
    end
  end

  it 'refreshes all cached results through available' do
    Dir.mktmpdir do |directory|
      locator = described_class.new(
        platform_key: :linux,
        environment: { 'PATH' => directory }
      )

      expect(locator.available(gui_selectable: true)).to be_empty
      executable(File.join(directory, 'Wrayth.exe'))
      expect(locator.available(gui_selectable: true)).to be_empty
      expect(locator.available(gui_selectable: true, refresh: true).map(&:frontend_id))
        .to eq(['stormfront'])
    end
  end

  it 'does not search the current directory for empty or relative PATH entries' do
    Dir.mktmpdir do |directory|
      executable(File.join(directory, 'Wrayth.exe'))
      locator = described_class.new(
        platform_key: :linux,
        environment: { 'PATH' => ":relative:" }
      )

      Dir.chdir(directory) do
        expect(locator.resolve('stormfront')).to be_nil
      end
    end
  end

  it 'drops conventional candidates containing unresolved environment variables' do
    locator = described_class.new(
      platform_key: :windows,
      environment: { 'PATH' => '' }
    )

    expect(locator.resolve('saga')).to be_nil
  end

  it 'expands Windows environment variables case-insensitively' do
    Dir.mktmpdir do |directory|
      saga = executable(File.join(directory, 'Programs', 'Saga', 'Saga.exe'))
      locator = described_class.new(
        platform_key: :windows,
        environment: { 'PATH' => '', 'localappdata' => directory }
      )

      expect(locator.resolve('saga').executable_path).to eq(File.realpath(saga))
      expect(locator.selectable?('saga')).to be(true)
    end
  end

  it 'expands the parenthesized PROGRAMFILES(X86) environment variable' do
    Dir.mktmpdir do |directory|
      saga = executable(File.join(directory, 'Saga', 'Saga.exe'))
      locator = described_class.new(
        platform_key: :windows,
        environment: { 'PATH' => '', 'programfiles(x86)' => directory }
      )

      expect(locator.resolve('saga').executable_path).to eq(File.realpath(saga))
    end
  end

  it 'rejects directories and non-executable files from PATH' do
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p(File.join(directory, 'Wrayth.exe'))
      File.write(File.join(directory, 'StormFront.exe'), 'not executable')
      locator = described_class.new(
        platform_key: :linux,
        environment: { 'PATH' => directory }
      )

      expect(locator.resolve('stormfront')).to be_nil
    end
  end

  it 'honors provider priority before PATH' do
    Dir.mktmpdir do |directory|
      registry = executable(File.join(directory, 'registry', 'Wrayth.exe'))
      application = executable(File.join(directory, 'application', 'Wrayth.exe'))
      conventional = executable(File.join(directory, 'conventional', 'Wrayth.exe'))
      executable(File.join(directory, 'path', 'Wrayth.exe'))
      locator = described_class.new(
        platform_key: :linux,
        environment: { 'PATH' => File.join(directory, 'path') }
      )
      allow(locator).to receive(:registry_candidates).and_return([registry])
      allow(locator).to receive(:application_candidates).and_return([application])
      allow(locator).to receive(:conventional_candidates).and_return([conventional])

      expect(locator.resolve('stormfront')).to eq(
        described_class::Resolution.new(
          frontend_id: 'stormfront',
          executable_path: File.realpath(registry),
          source: :registry
        )
      )
    end
  end

  it 'reads frontend directories from the Windows registry provider' do
    Dir.mktmpdir do |directory|
      wrayth = executable(File.join(directory, 'Wrayth.exe'))
      registry_key = Class.new do
        define_method(:initialize) { |path| @path = path }
        define_method(:[]) { |_name| @path }
      end
      hkey = Object.new
      hkey.define_singleton_method(:open) do |_key, _access, &block|
        block.call(registry_key.new(directory))
      end
      registry = Module.new
      registry.const_set(:KEY_READ, 1)
      registry.const_set(:Error, Class.new(StandardError))
      registry.const_set(:HKEY_LOCAL_MACHINE, hkey)
      win32 = Module.new
      win32.const_set(:Registry, registry)
      stub_const('Win32', win32)

      locator = described_class.new(platform_key: :windows, environment: { 'PATH' => '' })
      allow(locator).to receive(:require).with('win32/registry').and_return(true)

      expect(locator.resolve('stormfront')).to eq(
        described_class::Resolution.new(
          frontend_id: 'stormfront',
          executable_path: File.realpath(wrayth),
          source: :registry
        )
      )
    end
  end

  context 'when Saga is registered by its NSIS installer' do
    let(:saga_key) { 'Software\\3f78e0da-1d8f-570d-9cef-2ff34b0efe1a' }

    it 'resolves a per-user install from HKEY_CURRENT_USER' do
      Dir.mktmpdir do |directory|
        saga = executable(File.join(directory, 'Saga.exe'))
        opened = stub_windows_registry(
          HKEY_CURRENT_USER: { saga_key => { 'InstallLocation' => directory } },
          HKEY_LOCAL_MACHINE: {}
        )

        expect(windows_locator.resolve('saga')).to eq(
          described_class::Resolution.new(
            frontend_id: 'saga',
            executable_path: File.realpath(saga),
            source: :registry
          )
        )
        expect(opened.first).to eq([:HKEY_CURRENT_USER, saga_key, 1 | 0x0100])
      end
    end

    it 'resolves an elevated all-users install from HKEY_LOCAL_MACHINE' do
      Dir.mktmpdir do |directory|
        saga = executable(File.join(directory, 'Saga.exe'))
        stub_windows_registry(
          HKEY_CURRENT_USER: {},
          HKEY_LOCAL_MACHINE: { saga_key => { 'InstallLocation' => directory } }
        )

        expect(windows_locator.resolve('saga')&.executable_path).to eq(File.realpath(saga))
      end
    end

    it 'falls through a stale per-user entry to the all-users install' do
      Dir.mktmpdir do |directory|
        stale = File.join(directory, 'removed')
        machine = File.join(directory, 'machine')
        saga = executable(File.join(machine, 'Saga.exe'))
        stub_windows_registry(
          HKEY_CURRENT_USER: { saga_key => { 'InstallLocation' => stale } },
          HKEY_LOCAL_MACHINE: { saga_key => { 'InstallLocation' => machine } }
        )

        expect(windows_locator.resolve('saga')&.executable_path).to eq(File.realpath(saga))
      end
    end

    it 'prefers the per-user install when both are present' do
      Dir.mktmpdir do |directory|
        user = executable(File.join(directory, 'user', 'Saga.exe'))
        executable(File.join(directory, 'machine', 'Saga.exe'))
        stub_windows_registry(
          HKEY_CURRENT_USER: { saga_key => { 'InstallLocation' => File.dirname(user) } },
          HKEY_LOCAL_MACHINE: { saga_key => { 'InstallLocation' => File.join(directory, 'machine') } }
        )

        expect(windows_locator.resolve('saga')&.executable_path).to eq(File.realpath(user))
      end
    end

    it 'ignores a blank InstallLocation' do
      stub_windows_registry(
        HKEY_CURRENT_USER: { saga_key => { 'InstallLocation' => '' } },
        HKEY_LOCAL_MACHINE: {}
      )

      expect(windows_locator.resolve('saga')).to be_nil
    end

    it 'does not resolve Saga through the Wine registry on Linux' do
      wine = Module.new
      wine.const_set(:PREFIX, '/nonexistent-prefix')
      wine.define_singleton_method(:registry_gets) { |_key| raise 'Wine registry consulted for Saga' }
      locator = described_class.new(platform_key: :linux, environment: { 'PATH' => '' }, wine: wine)

      expect(locator.resolve('saga')).to be_nil
    end
  end

  it 'keeps reading Simutronics frontends from HKEY_LOCAL_MACHINE Directory values' do
    Dir.mktmpdir do |directory|
      wrayth = executable(File.join(directory, 'Wrayth.exe'))
      opened = stub_windows_registry(
        HKEY_LOCAL_MACHINE: { 'SOFTWARE\\Simutronics\\STORM32' => { 'Directory' => directory } }
      )

      expect(windows_locator.resolve('stormfront')&.executable_path).to eq(File.realpath(wrayth))
      expect(opened.first).to eq([:HKEY_LOCAL_MACHINE, 'SOFTWARE\\Simutronics\\STORM32', 1])
    end
  end

  context 'when Saga is installed as a Linux AppImage' do
    def appimage(directory, name, mtime: Time.now)
      path = executable(File.join(directory, name))
      File.utime(mtime, mtime, path)
      path
    end

    def linux_locator(home, extra = {})
      described_class.new(platform_key: :linux, environment: { 'PATH' => '', 'HOME' => home }.merge(extra))
    end

    def desktop_entry(home, name, body)
      path = File.join(home, '.local', 'share', 'applications', name)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, body)
      path
    end

    it 'resolves the highest-versioned AppImage in a usual directory' do
      Dir.mktmpdir do |home|
        appimage(File.join(home, 'Applications'), 'Saga-0.9.12-x86_64.AppImage')
        newest = appimage(File.join(home, 'Applications'), 'Saga-0.10.8-x86_64.AppImage', mtime: Time.now - 3600)

        expect(linux_locator(home).resolve('saga')).to eq(
          described_class::Resolution.new(
            frontend_id: 'saga',
            executable_path: File.realpath(newest),
            source: :appimage
          )
        )
      end
    end

    it 'skips a downloaded AppImage that was never made executable' do
      Dir.mktmpdir do |home|
        downloaded = File.join(home, 'Downloads', 'Saga-0.10.8-x86_64.AppImage')
        FileUtils.mkdir_p(File.dirname(downloaded))
        File.write(downloaded, 'AppImage')
        FileUtils.chmod(0o644, downloaded)

        expect(linux_locator(home).resolve('saga')).to be_nil
      end
    end

    it 'ignores a dangling symlink left beside the renamed AppImage' do
      Dir.mktmpdir do |home|
        directory = File.join(home, 'Applications')
        updated = appimage(directory, 'Saga-0.10.8-x86_64.AppImage')
        File.symlink(File.join(directory, 'Saga-0.10.7-x86_64.AppImage'), File.join(directory, 'Saga.AppImage'))

        expect(linux_locator(home).resolve('saga')&.executable_path).to eq(File.realpath(updated))
      end
    end

    it 'ignores differently cased names that may belong to SAGA GIS' do
      Dir.mktmpdir do |home|
        # Default macOS APFS is case-insensitive; the names would be one file.
        File.write(File.join(home, 'case-probe'), '')
        skip 'needs a case-sensitive filesystem' if File.exist?(File.join(home, 'CASE-PROBE'))
        appimage(File.join(home, '.local', 'bin'), 'SAGA-9.1.0-x86_64.AppImage')
        appimage(File.join(home, '.local', 'bin'), 'saga-9.1.0-x86_64.AppImage')

        expect(linux_locator(home).resolve('saga')).to be_nil
      end
    end

    it 'resolves a custom location from an integrator desktop entry' do
      Dir.mktmpdir do |home|
        custom = appimage(File.join(home, 'games', 'saga client'), 'saga.appimage')
        desktop_entry(home, 'appimagekit_0123-Saga.desktop', <<~DESKTOP)
          [Desktop Entry]
          Name=Saga
          Exec="#{custom}" --no-sandbox %U
          StartupWMClass=Saga
          [Desktop Action New]
          Exec=/elsewhere/Other.AppImage
        DESKTOP

        expect(linux_locator(home).resolve('saga')).to eq(
          described_class::Resolution.new(
            frontend_id: 'saga',
            executable_path: File.realpath(custom),
            source: :desktop_entry
          )
        )
      end
    end

    it 'finds the renamed AppImage beside a desktop entry left stale by an update' do
      Dir.mktmpdir do |home|
        directory = File.join(home, 'games')
        updated = appimage(directory, 'Saga-0.10.8-x86_64.AppImage')
        desktop_entry(home, 'saga.desktop', <<~DESKTOP)
          [Desktop Entry]
          Exec=#{File.join(directory, 'Saga-0.10.7-x86_64.AppImage')} %U
          StartupWMClass=Saga
        DESKTOP

        expect(linux_locator(home).resolve('saga')&.executable_path).to eq(File.realpath(updated))
      end
    end

    it 'honors XDG_DATA_HOME and ignores entries for other applications' do
      Dir.mktmpdir do |home|
        other = appimage(File.join(home, 'tools'), 'Other.AppImage')
        data_home = File.join(home, 'xdg')
        path = File.join(data_home, 'applications', 'other.desktop')
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, "[Desktop Entry]\nExec=#{other}\nStartupWMClass=Other\n")
        saga = appimage(File.join(home, 'opt'), 'Saga.AppImage')
        File.write(
          File.join(data_home, 'applications', 'saga.desktop'),
          "[Desktop Entry]\nExec=#{saga}\nStartupWMClass=Saga\n"
        )

        expect(linux_locator(home, 'XDG_DATA_HOME' => data_home).resolve('saga')&.executable_path)
          .to eq(File.realpath(saga))
      end
    end
  end

  context 'when Saga.app is outside the scanned macOS application roots' do
    def darwin_locator(applications, spotlight)
      described_class.new(
        platform_key: :darwin,
        environment: { 'PATH' => '' },
        application_roots: [applications],
        spotlight: spotlight
      )
    end

    it 'finds it through Spotlight and verifies the bundle identifier' do
      Dir.mktmpdir do |root|
        downloads = File.join(root, 'Downloads')
        saga = mac_application(downloads, name: 'Saga', bundle_id: 'com.auchand.saga', executable_name: 'Saga')
        impostor = File.join(root, 'Impostor.app')
        mac_application(root, name: 'Impostor', bundle_id: 'com.example.other', executable_name: 'Saga')
        queried = []
        spotlight = lambda do |bundle_id|
          queried << bundle_id
          [impostor, File.join(downloads, 'Saga.app'), '']
        end

        expect(darwin_locator(File.join(root, 'empty'), spotlight).resolve('saga')).to eq(
          described_class::Resolution.new(
            frontend_id: 'saga',
            executable_path: File.realpath(saga),
            source: :application
          )
        )
        expect(queried).to eq(['com.auchand.saga'])
      end
    end

    it 'ignores mounted disk images, the Trash, and translocated copies' do
      spotlight = lambda do |_bundle_id|
        ['/Volumes/Saga 0.10.8/Saga.app', '/Users/me/.Trash/Saga.app',
         '/private/var/folders/x/AppTranslocation/ABC/d/Saga.app']
      end
      Dir.mktmpdir do |applications|
        locator = darwin_locator(applications, spotlight)
        expect(locator).not_to receive(:mac_bundle_id)

        expect(locator.resolve('saga')).to be_nil
      end
    end

    it 'treats a Spotlight failure as not installed' do
      Dir.mktmpdir do |applications|
        spotlight = ->(_bundle_id) { raise Errno::ENOENT, '/usr/bin/mdfind' }

        expect(darwin_locator(applications, spotlight).resolve('saga')).to be_nil
      end
    end

    it 'does not query Spotlight when the application scan already found Saga' do
      Dir.mktmpdir do |applications|
        mac_application(applications, name: 'Saga', bundle_id: 'com.auchand.saga', executable_name: 'Saga')
        spotlight = ->(_bundle_id) { raise 'Spotlight consulted' }

        expect(darwin_locator(applications, spotlight).resolve('saga')).not_to be_nil
      end
    end

    it 'gives up on an mdfind that does not finish in time' do
      locator = darwin_locator('/nonexistent', nil)
      stub_const("#{described_class}::SPOTLIGHT_TIMEOUT", 0.2)
      sleeper = proc { |original, *_args, &block| original.call('sleep', '5', &block) }
      allow(Open3).to receive(:popen3).with('/usr/bin/mdfind', anything).and_wrap_original(&sleeper)

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect(locator.send(:spotlight_search, 'com.auchand.saga')).to eq([])
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 2
    end
  end

  it 'discovers a Wine frontend without requiring a Unix execute bit' do
    Dir.mktmpdir do |prefix|
      wrayth = File.join(prefix, 'drive_c', 'Simutronics', 'Wrayth.exe')
      FileUtils.mkdir_p(File.dirname(wrayth))
      File.write(wrayth, 'PE executable')
      FileUtils.chmod(0o644, wrayth)
      wine = Module.new
      wine.const_set(:PREFIX, prefix)
      wine.define_singleton_method(:registry_gets) do |key|
        key == 'HKEY_LOCAL_MACHINE\\SOFTWARE\\Simutronics\\STORM32\\Directory' ? 'C:\\Simutronics' : nil
      end
      stub_const('Wine', wine)
      locator = described_class.new(
        platform_key: :linux,
        environment: { 'PATH' => '' },
        wine: wine
      )

      expect(locator.resolve('stormfront')).to eq(
        described_class::Resolution.new(
          frontend_id: 'stormfront',
          executable_path: File.realpath(wrayth),
          source: :registry
        )
      )
    end
  end

  it 'accepts a Wine frontend override without requiring a Unix execute bit' do
    Dir.mktmpdir do |directory|
      wrayth = File.join(directory, 'Wrayth.exe')
      File.write(wrayth, 'PE executable')
      FileUtils.chmod(0o644, wrayth)
      locator = described_class.new(
        platform_key: :linux,
        environment: { 'PATH' => '' },
        wine: Module.new
      )

      expect(File.executable?(wrayth)).to be(false)
      expect(locator.resolve('stormfront', override: wrayth)).to eq(
        described_class::Resolution.new(
          frontend_id: 'stormfront',
          executable_path: File.realpath(wrayth),
          source: :override
        )
      )
    end
  end

  it 'does not consult ambient Wine when the injected provider is nil' do
    stub_const('Wine', Module.new)
    locator = described_class.new(
      platform_key: :linux,
      environment: { 'PATH' => '' },
      wine: nil
    )

    expect(locator.launchable?('stormfront')).to be(false)
  end

  it 'ignores a macOS application with a different bundle identifier' do
    Dir.mktmpdir do |applications|
      mac_application(
        applications,
        name: 'Unrelated Avalon',
        bundle_id: 'example.unrelated.avalon',
        executable_name: 'Avalon'
      )
      locator = described_class.new(
        platform_key: :darwin,
        environment: { 'PATH' => '' },
        application_roots: [applications],
        spotlight: no_spotlight
      )

      expect(locator.resolve('avalon')).to be_nil
    end
  end

  it 'falls back to plutil for a binary application property list' do
    Dir.mktmpdir do |applications|
      bundle = File.join(applications, 'Saga binary.app')
      saga = executable(File.join(bundle, 'Contents', 'MacOS', 'Saga'))
      plist = File.join(bundle, 'Contents', 'Info.plist')
      File.write(plist, "bplist00\x00\x01")
      status = double('process status', success?: true)
      allow(Open3).to receive(:capture3)
        .with('/usr/bin/plutil', '-extract', 'CFBundleIdentifier', 'raw', '--', plist)
        .and_return(["com.auchand.saga\n", '', status])
      locator = described_class.new(
        platform_key: :darwin,
        environment: { 'PATH' => '' },
        application_roots: [applications],
        spotlight: no_spotlight
      )

      expect(locator.resolve('saga').executable_path).to eq(File.realpath(saga))
    end
  end

  it 'indexes macOS application bundle identifiers once per discovery generation' do
    Dir.mktmpdir do |applications|
      mac_application(
        applications,
        name: 'Avalon',
        bundle_id: 'Avalon',
        executable_name: 'Avalon'
      )
      mac_application(
        applications,
        name: 'Saga',
        bundle_id: 'com.auchand.saga',
        executable_name: 'Saga'
      )
      locator = described_class.new(
        platform_key: :darwin,
        environment: { 'PATH' => '' },
        application_roots: [applications],
        spotlight: no_spotlight
      )
      expect(locator).to receive(:mac_bundle_id).twice.and_call_original

      expect(locator.resolve('avalon')).not_to be_nil
      expect(locator.resolve('saga')).not_to be_nil
      index = locator.send(:application_index)
      expect(index).to be_frozen
      expect(index.values).to all(be_frozen)
    end
  end

  it 'refreshes the macOS application index with the resolution cache' do
    Dir.mktmpdir do |applications|
      locator = described_class.new(
        platform_key: :darwin,
        environment: { 'PATH' => '' },
        application_roots: [applications],
        spotlight: no_spotlight
      )

      expect(locator.resolve('saga')).to be_nil
      mac_application(
        applications,
        name: 'Saga',
        bundle_id: 'com.auchand.saga',
        executable_name: 'Saga'
      )
      expect(locator.resolve('saga', refresh: true)).not_to be_nil
    end
  end

  it 'handles an executable disappearing before realpath resolution' do
    Dir.mktmpdir do |directory|
      messages = []
      wrayth = executable(File.join(directory, 'Wrayth.exe'))
      locator = described_class.new(
        platform_key: :linux,
        environment: { 'PATH' => directory },
        logger: ->(message) { messages << message }
      )
      allow(File).to receive(:realpath).with(wrayth).and_raise(Errno::ENOENT, wrayth)

      expect(locator.resolve('stormfront')).to be_nil
      expect(messages.join).to include('frontend discovery failed')
    end
  end

  it 'continues to a later candidate when realpath resolution races' do
    Dir.mktmpdir do |directory|
      first = executable(File.join(directory, 'Wrayth.exe'))
      second = executable(File.join(directory, 'StormFront.exe'))
      locator = described_class.new(
        platform_key: :linux,
        environment: { 'PATH' => directory }
      )
      allow(File).to receive(:realpath).and_call_original
      allow(File).to receive(:realpath).with(first).and_raise(Errno::ENOENT, first)

      expect(locator.resolve('stormfront').executable_path).to eq(File.realpath(second))
    end
  end

  it 'resolves Wrayth aliases to the canonical StormFront result' do
    Dir.mktmpdir do |directory|
      executable(File.join(directory, 'Wrayth.exe'))
      locator = described_class.new(
        platform_key: :linux,
        environment: { 'PATH' => directory }
      )

      expect(locator.resolve('wrayth').frontend_id).to eq('stormfront')
    end
  end

  it 'provides backward-compatible directory results for Lich.seek' do
    resolution = described_class::Resolution.new(
      frontend_id: 'stormfront',
      executable_path: '/frontends/Wrayth.exe',
      source: :path
    )
    allow(described_class).to receive(:resolve).with('stormfront').and_return(resolution)

    expect(described_class.compatibility_location('stormfront')).to eq('/frontends')
  end

  it 'preserves nil for an unknown Lich.seek frontend' do
    expect(described_class.compatibility_location('unknown')).to be_nil
  end
end
