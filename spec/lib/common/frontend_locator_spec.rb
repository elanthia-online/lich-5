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
        platform: 'x86_64-linux',
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
      platform: 'x86_64-linux',
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
        platform: 'arm64-darwin',
        environment: { 'PATH' => '' },
        application_roots: [applications]
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

  it 'makes an installed Saga selectable on its preliminary macOS adapter' do
    Dir.mktmpdir do |applications|
      mac_application(
        applications,
        name: 'Saga',
        bundle_id: 'com.auchand.saga',
        executable_name: 'Saga'
      )
      locator = described_class.new(
        platform: 'arm64-darwin',
        environment: { 'PATH' => '' },
        application_roots: [applications]
      )

      expect(locator.selectable?('saga')).to be(true)
      expect(locator.launchable?('saga')).to be(true)
      expect(locator.available(gui_selectable: true).map(&:frontend_id)).to include('saga')
    end
  end

  it 'separates native launch support from GUI presentation metadata' do
    Dir.mktmpdir do |directory|
      executable(File.join(directory, 'Wrayth.exe'))
      locator = described_class.new(
        platform: 'x64-mingw32',
        environment: { 'PATH' => directory }
      )

      expect(locator.launchable?('stormfront')).to be(true)
      expect(locator.launchable?('suks')).to be(true)
      expect(locator.launchable?('profanity')).to be(false)
    end
  end

  it 'raises for an unknown frontend identifier' do
    locator = described_class.new(platform: 'x86_64-linux', environment: { 'PATH' => '' })

    expect { locator.resolve('not-a-frontend') }
      .to raise_error(ArgumentError, 'unknown frontend: not-a-frontend')
  end

  it 'raises rather than falling back when an explicit override is invalid' do
    locator = described_class.new(platform: 'x86_64-linux', environment: { 'PATH' => '' })

    expect { locator.resolve('saga', override: '/missing/Saga') }
      .to raise_error(ArgumentError, 'frontend override is not executable: /missing/Saga')
  end

  it 'raises when an explicit override disappears during resolution' do
    Dir.mktmpdir do |directory|
      override = executable(File.join(directory, 'Saga'))
      locator = described_class.new(platform: 'arm64-darwin', environment: { 'PATH' => '' })
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
        platform: 'x86_64-linux',
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
      platform: 'x86_64-linux',
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
        platform: 'x86_64-linux',
        environment: { 'PATH' => directory }
      )

      expect(locator.available(gui_selectable: true).map(&:frontend_id)).to eq(['stormfront'])
    end
  end

  it 'refreshes cached unavailable results' do
    Dir.mktmpdir do |directory|
      locator = described_class.new(
        platform: 'x86_64-linux',
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
        platform: 'x86_64-linux',
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
        platform: 'x86_64-linux',
        environment: { 'PATH' => ":relative:" }
      )

      Dir.chdir(directory) do
        expect(locator.resolve('stormfront')).to be_nil
      end
    end
  end

  it 'drops conventional candidates containing unresolved environment variables' do
    locator = described_class.new(
      platform: 'x64-mingw32',
      environment: { 'PATH' => '' }
    )

    expect(locator.resolve('saga')).to be_nil
  end

  it 'expands Windows environment variables case-insensitively' do
    Dir.mktmpdir do |directory|
      saga = executable(File.join(directory, 'Programs', 'Saga', 'Saga.exe'))
      locator = described_class.new(
        platform: 'x64-mingw32',
        environment: { 'PATH' => '', 'localappdata' => directory }
      )

      expect(locator.resolve('saga').executable_path).to eq(File.realpath(saga))
      expect(locator.selectable?('saga')).to be(true)
    end
  end

  it 'rejects directories and non-executable files from PATH' do
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p(File.join(directory, 'Wrayth.exe'))
      File.write(File.join(directory, 'StormFront.exe'), 'not executable')
      locator = described_class.new(
        platform: 'x86_64-linux',
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
        platform: 'x86_64-linux',
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

      locator = described_class.new(platform: 'x64-mingw32', environment: { 'PATH' => '' })
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

  it 'converts Wine registry directories before executable discovery' do
    Dir.mktmpdir do |prefix|
      wrayth = executable(File.join(prefix, 'drive_c', 'Simutronics', 'Wrayth.exe'))
      wine = Module.new
      wine.const_set(:PREFIX, prefix)
      wine.define_singleton_method(:registry_gets) do |key|
        key.include?('STORM32') ? 'C:\\Simutronics' : nil
      end
      stub_const('Wine', wine)
      locator = described_class.new(
        platform: 'x86_64-linux',
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

  it 'does not consult ambient Wine when the injected provider is nil' do
    stub_const('Wine', Module.new)
    locator = described_class.new(
      platform: 'x86_64-linux',
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
        platform: 'arm64-darwin',
        environment: { 'PATH' => '' },
        application_roots: [applications]
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
        platform: 'arm64-darwin',
        environment: { 'PATH' => '' },
        application_roots: [applications]
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
        platform: 'arm64-darwin',
        environment: { 'PATH' => '' },
        application_roots: [applications]
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
        platform: 'arm64-darwin',
        environment: { 'PATH' => '' },
        application_roots: [applications]
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
        platform: 'x86_64-linux',
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
        platform: 'x86_64-linux',
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
        platform: 'x86_64-linux',
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
end
