# frozen_string_literal: true

require 'rspec'
require_relative '../../../lib/common/front-end'
require_relative '../../../lib/common/frontend_locator'
require_relative '../../../lib/common/frontend_launcher'

RSpec.describe Lich::Common::FrontendLauncher do
  let(:locator) { double('frontend locator') }

  it 'returns a shell-free preliminary macOS Saga environment handoff' do
    plan = described_class.spawn_plan(
      'saga',
      host: '127.0.0.1',
      port: 12_345,
      key: 'secret',
      platform: 'arm64-darwin'
    )

    expect(plan.argv).to eq(['/usr/bin/open', '-n', '-b', 'com.auchand.saga'])
    expect(plan.environment).to eq(
      'SAGA_LICH_MODE' => '1',
      'SAGA_LICH_HOST' => '127.0.0.1',
      'SAGA_LICH_PORT' => '12345',
      'SAGA_LICH_KEY'  => 'secret'
    )
    expect(plan).to be_frozen
    expect(plan.environment).to be_frozen
    expect(plan.argv).to be_frozen
  end

  it 'uses the resolved Saga executable for the temporary Windows handoff' do
    resolution = Lich::Common::FrontendLocator::Resolution.new(
      frontend_id: 'saga',
      executable_path: 'C:/Users/Test/AppData/Local/Programs/Saga/Saga.exe',
      source: :conventional
    )
    allow(locator).to receive(:resolve).with('saga', refresh: true).and_return(resolution)

    plan = described_class.spawn_plan(
      'saga',
      host: '127.0.0.1',
      port: 12_345,
      key: 'secret',
      platform: 'x64-mingw32',
      locator: locator
    )

    expect(plan.argv).to eq(['C:/Users/Test/AppData/Local/Programs/Saga/Saga.exe'])
    expect(plan.environment['SAGA_LICH_KEY']).to eq('secret')
  end

  it 'uses the resolved Saga executable for the temporary Linux handoff' do
    resolution = Lich::Common::FrontendLocator::Resolution.new(
      frontend_id: 'saga',
      executable_path: '/opt/Saga/saga',
      source: :conventional
    )
    allow(locator).to receive(:resolve).with('saga', refresh: false).and_return(resolution)

    plan = described_class.spawn_plan(
      'saga',
      host: '127.0.0.1',
      port: 12_345,
      key: 'secret',
      platform: 'x86_64-linux',
      locator: locator,
      refresh: false
    )

    expect(plan.argv).to eq(['/opt/Saga/saga'])
    expect(locator).to have_received(:resolve).with('saga', refresh: false)
    expect(plan.environment).to include(
      'SAGA_LICH_MODE' => '1',
      'SAGA_LICH_HOST' => '127.0.0.1',
      'SAGA_LICH_PORT' => '12345',
      'SAGA_LICH_KEY'  => 'secret'
    )
  end

  it 'reports a missing Windows Saga executable' do
    allow(locator).to receive(:resolve).with('saga', refresh: true).and_return(nil)

    expect {
      described_class.spawn_plan(
        'saga',
        host: '127.0.0.1',
        port: 12_345,
        key: 'secret',
        platform: 'x64-mingw32',
        locator: locator
      )
    }.to raise_error(described_class::UnavailableError, 'Saga was not found')
  end

  it 'rejects blank Saga connection inputs' do
    expect {
      described_class.spawn_plan('saga', host: '', port: 12_345, key: 'secret')
    }.to raise_error(ArgumentError, 'host must not be empty')
  end

  it 'targets the discovered Avalon bundle rather than a hard-coded bundle id' do
    resolution = Lich::Common::FrontendLocator::Resolution.new(
      frontend_id: 'avalon',
      executable_path: '/Applications/Avalon 4.4.app/Contents/MacOS/Avalon',
      source: :application
    )
    allow(locator).to receive(:resolve).with('avalon', refresh: true).and_return(resolution)

    expect(
      described_class.command('avalon', platform: 'arm64-darwin', locator: locator)
    ).to eq('/usr/bin/open -n -a /Applications/Avalon\\ 4.4.app "%1"')
  end

  it 'reports a missing Avalon executable' do
    allow(locator).to receive(:resolve).with('avalon', refresh: true).and_return(nil)

    expect {
      described_class.command('avalon', platform: 'arm64-darwin', locator: locator)
    }.to raise_error(described_class::UnavailableError, 'Avalon was not found')
  end

  it 'rejects an Avalon executable outside an application bundle' do
    resolution = Lich::Common::FrontendLocator::Resolution.new(
      frontend_id: 'avalon',
      executable_path: '/usr/local/bin/Avalon',
      source: :override
    )
    allow(locator).to receive(:resolve).with('avalon', refresh: true).and_return(resolution)

    expect {
      described_class.command('avalon', platform: 'arm64-darwin', locator: locator)
    }.to raise_error(
      described_class::UnavailableError,
      'Avalon executable is not inside an application bundle'
    )
  end

  it 'delegates legacy frontend commands to the Simutronics launcher' do
    command = described_class.command(
      'stormfront',
      platform: 'x64-mingw32',
      simu_launcher: -> { 'launcher.exe "%1"' }
    )

    expect(command).to eq('launcher.exe "%1"')
  end

  it 'reports an unavailable Simutronics launcher' do
    expect {
      described_class.command('wizard', simu_launcher: -> {})
    }.to raise_error(described_class::UnavailableError, 'Simutronics launcher was not found')
  end

  it 'fails fast for an unknown frontend' do
    expect { described_class.command('unknown') }
      .to raise_error(ArgumentError, 'unknown frontend: unknown')
  end
end
