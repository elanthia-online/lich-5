# frozen_string_literal: true

require 'rspec'
require_relative '../../../lib/common/front-end'
require_relative '../../../lib/common/frontend_locator'
require_relative '../../../lib/common/frontend_launcher'

RSpec.describe Lich::Common::FrontendLauncher do
  let(:locator) { double('frontend locator') }

  it 'returns the shell-free macOS Saga 0.8.5 cold-start handoff' do
    plan = described_class.spawn_plan(
      'saga',
      host: '127.0.0.1',
      port: 12_345,
      key: 'secret',
      platform_key: :darwin
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

  it 'uses the resolved Saga executable for the Windows cold-start handoff' do
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
      platform_key: :windows,
      locator: locator
    )

    expect(plan.argv).to eq(['C:/Users/Test/AppData/Local/Programs/Saga/Saga.exe'])
    expect(plan.environment['SAGA_LICH_KEY']).to eq('secret')
  end

  it 'uses the resolved Saga executable for the Linux cold-start handoff' do
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
      platform_key: :linux,
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

  it 'appends configured arguments to structured built-in launch plans' do
    definition = Lich::Common::Frontend.definition_for('saga')
    allow(Lich::Common::Frontend).to receive(:definition_for).with('saga').and_return(
      definition.merge(metadata: definition[:metadata].merge(additional_arguments: ['--profile', 'Test profile']))
    )

    plan = described_class.spawn_plan(
      'saga',
      host: '127.0.0.1',
      port: 12_345,
      key: 'secret',
      platform_key: :darwin
    )

    expect(plan.argv).to eq(['/usr/bin/open', '-n', '-b', 'com.auchand.saga', '--args', '--profile', 'Test profile'])
  end

  it 'honors a configured macOS Saga application executable' do
    definition = Lich::Common::Frontend.definition_for('saga')
    allow(Lich::Common::Frontend).to receive(:definition_for).with('saga').and_return(
      definition.merge(
        metadata: definition[:metadata].merge(
          configured_executable: '/Applications/Saga Preview.app/Contents/MacOS/Saga',
          additional_arguments: ['--profile', 'Test profile']
        )
      )
    )
    resolution = Lich::Common::FrontendLocator::Resolution.new(
      frontend_id: 'saga',
      executable_path: '/Applications/Saga Preview.app/Contents/MacOS/Saga',
      source: :configured
    )
    allow(locator).to receive(:resolve).with('saga', refresh: false).and_return(resolution)

    plan = described_class.spawn_plan(
      'saga',
      host: '127.0.0.1',
      port: 12_345,
      key: 'secret',
      platform_key: :darwin,
      locator: locator,
      refresh: false
    )

    expect(plan.argv).to eq(
      ['/usr/bin/open', '-n', '-a', '/Applications/Saga Preview.app', '--args', '--profile', 'Test profile']
    )
  end

  it 'honors a configured standalone macOS Saga executable for managed login' do
    definition = Lich::Common::Frontend.definition_for('saga')
    allow(Lich::Common::Frontend).to receive(:definition_for).with('saga').and_return(
      definition.merge(
        metadata: definition[:metadata].merge(
          configured_executable: '/Users/test/bin/saga-preview',
          additional_arguments: ['--profile', 'Tsetem']
        )
      )
    )
    resolution = Lich::Common::FrontendLocator::Resolution.new(
      frontend_id: 'saga',
      executable_path: '/Users/test/bin/saga-preview',
      source: :configured
    )
    allow(locator).to receive(:resolve).with('saga', refresh: true).and_return(resolution)

    plan = described_class.saga_managed_login_plan(
      account: 'TESTACCOUNT',
      character: 'Tsetem',
      game_code: 'GS3',
      platform_key: :darwin,
      locator: locator
    )

    expect(plan.argv).to eq(['/Users/test/bin/saga-preview', '--profile', 'Tsetem'])
  end

  it 'builds a keyless macOS Saga-managed Via-Lich login plan' do
    plan = described_class.saga_managed_login_plan(
      account: 'TESTACCOUNT',
      character: 'Tsetem',
      game_code: 'gs3',
      platform_key: :darwin
    )

    expect(plan.argv).to eq(['/usr/bin/open', '-n', '-b', 'com.auchand.saga'])
    expect(plan.environment).to eq(
      'SAGA_AUTO_LOGIN'         => 'Tsetem@GS3',
      'SAGA_AUTO_LOGIN_ACCOUNT' => 'TESTACCOUNT',
      'SAGA_AUTO_LOGIN_MODE'    => 'lich'
    )
    expect(plan.environment.keys).not_to include(
      'SAGA_LICH_MODE',
      'SAGA_LICH_HOST',
      'SAGA_LICH_PORT',
      'SAGA_LICH_KEY'
    )
  end

  it 'uses the discovered Saga executable for managed Windows login' do
    resolution = Lich::Common::FrontendLocator::Resolution.new(
      frontend_id: 'saga',
      executable_path: 'C:/Users/Test/AppData/Local/Programs/Saga/Saga.exe',
      source: :conventional
    )
    allow(locator).to receive(:resolve).with('saga', refresh: false).and_return(resolution)

    plan = described_class.saga_managed_login_plan(
      account: 'TESTACCOUNT',
      character: 'Tsetem',
      game_code: 'GS3',
      platform_key: :windows,
      locator: locator,
      refresh: false
    )

    expect(plan.argv).to eq(['C:/Users/Test/AppData/Local/Programs/Saga/Saga.exe'])
    expect(locator).to have_received(:resolve).with('saga', refresh: false)
  end

  it 'rejects blank Saga-managed login identifiers' do
    {
      account: ['', 'Tsetem', 'GS3'],
      character: ['TESTACCOUNT', ' ', 'GS3'],
      game_code: ['TESTACCOUNT', 'Tsetem', nil]
    }.each do |field, (account, character, game_code)|
      expect {
        described_class.saga_managed_login_plan(
          account: account,
          character: character,
          game_code: game_code
        )
      }.to raise_error(ArgumentError, "#{field} must not be empty")
    end
  end

  it 'rejects a Saga definition without the environment launcher adapter' do
    definition = Lich::Common::Frontend.definition_for('saga')
    allow(Lich::Common::Frontend).to receive(:definition_for).with('saga').and_return(
      definition.merge(metadata: definition[:metadata].merge(launcher_adapter: :command))
    )

    expect {
      described_class.saga_managed_login_plan(
        account: 'TESTACCOUNT',
        character: 'Tsetem',
        game_code: 'GS3'
      )
    }.to raise_error(described_class::UnsupportedError, 'no environment launcher for saga')
  end

  it 'reports a missing Windows Saga executable' do
    allow(locator).to receive(:resolve).with('saga', refresh: true).and_return(nil)

    expect {
      described_class.spawn_plan(
        'saga',
        host: '127.0.0.1',
        port: 12_345,
        key: 'secret',
        platform_key: :windows,
        locator: locator
      )
    }.to raise_error(described_class::UnavailableError, 'Saga was not found')
  end

  it 'rejects blank Saga connection inputs' do
    {
      host: ['', 12_345, 'secret'],
      port: ['127.0.0.1', '', 'secret'],
      key: ['127.0.0.1', 12_345, '']
    }.each do |field, (host, port, key)|
      expect {
        described_class.spawn_plan('saga', host: host, port: port, key: key)
      }.to raise_error(ArgumentError, "#{field} must not be empty")
    end
  end

  it 'rejects environment adapters from the command-only entry point' do
    expect { described_class.command('saga') }
      .to raise_error(described_class::UnsupportedError, 'saga requires a structured spawn plan')
  end

  it 'reports frontends without a launcher adapter' do
    expect { described_class.command('profanity') }
      .to raise_error(described_class::UnsupportedError, 'no launcher adapter for profanity')
  end

  it 'rejects Avalon launch commands outside macOS' do
    expect { described_class.command('avalon', platform_key: :linux) }
      .to raise_error(described_class::UnsupportedError, 'no linux launcher for avalon')
  end

  it 'targets the discovered Avalon bundle rather than a hard-coded bundle id' do
    resolution = Lich::Common::FrontendLocator::Resolution.new(
      frontend_id: 'avalon',
      executable_path: '/Applications/Avalon 4.4.app/Contents/MacOS/Avalon',
      source: :application
    )
    allow(locator).to receive(:resolve).with('avalon', refresh: true).and_return(resolution)

    expect(
      described_class.command('avalon', platform_key: :darwin, locator: locator)
    ).to eq('/usr/bin/open -n -a /Applications/Avalon\\ 4.4.app "%1"')
  end

  it 'passes configured Avalon arguments through open to the application' do
    definition = Lich::Common::Frontend.definition_for('avalon')
    allow(Lich::Common::Frontend).to receive(:definition_for).with('avalon').and_return(
      definition.merge(metadata: definition[:metadata].merge(additional_arguments: ['--profile', 'Test profile']))
    )
    resolution = Lich::Common::FrontendLocator::Resolution.new(
      frontend_id: 'avalon',
      executable_path: '/Applications/Avalon.app/Contents/MacOS/Avalon',
      source: :application
    )
    allow(locator).to receive(:resolve).with('avalon', refresh: true).and_return(resolution)

    expect(
      described_class.command('avalon', platform_key: :darwin, locator: locator)
    ).to eq('/usr/bin/open -n -a /Applications/Avalon.app "%1" --args --profile Test\\ profile')
  end

  it 'reports a missing Avalon executable' do
    allow(locator).to receive(:resolve).with('avalon', refresh: true).and_return(nil)

    expect {
      described_class.command('avalon', platform_key: :darwin, locator: locator)
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
      described_class.command('avalon', platform_key: :darwin, locator: locator)
    }.to raise_error(
      described_class::UnavailableError,
      'Avalon executable is not inside an application bundle'
    )
  end

  it 'delegates legacy frontend commands to the Simutronics launcher' do
    command = described_class.command(
      'stormfront',
      platform_key: :windows,
      simu_launcher: -> { 'launcher.exe "%1"' }
    )

    expect(command).to eq('launcher.exe "%1"')
  end

  it 'keeps Windows configured arguments separate from the executable template' do
    definition = Lich::Common::Frontend.definition_for('stormfront')
    allow(Lich::Common::Frontend).to receive(:definition_for).with('stormfront').and_return(
      definition.merge(metadata: definition[:metadata].merge(additional_arguments: ['--profile', 'Test profile']))
    )

    command = described_class.command(
      'stormfront',
      platform_key: :windows,
      simu_launcher: -> { 'launcher.exe "%1"' }
    )

    expect(command).to eq(['launcher.exe', '%1', '--profile', 'Test profile'])
  end

  it 'builds configured custom commands while retaining connection placeholders' do
    allow(Lich::Common::Frontend).to receive(:definition_for).with('vellum').and_return(
      id: 'vellum',
      capabilities: [:xml],
      metadata: {
        launcher_adapter: :custom,
        launch_command: '/opt/Vellum FE/vellum --port=%port% --key=%key%',
        additional_arguments: ['--profile', 'Test profile']
      }
    )

    expect(described_class.command('vellum')).to eq(
      '/opt/Vellum FE/vellum --port=%port% --key=%key% --profile Test\\ profile'
    )
  end

  it 'keeps process-local frontend identity out of native session data' do
    launch_data = [
      'KEY=secret',
      'FRONTEND=vellum',
      'GAME=STORM'
    ]

    expect(described_class.native_session_data(launch_data)).to eq(
      ['KEY=secret', 'GAME=STORM']
    )
    expect(launch_data).to include('FRONTEND=vellum')
  end

  it 'renders every connection placeholder in a configured command' do
    command = 'frontend --host=%host% --port=%port% --again=%port% --key=%key%'

    expect(
      described_class.render_connection(command, host: '127.0.0.1', port: 12_345, key: 'secret')
    ).to eq('frontend --host=127.0.0.1 --port=12345 --again=12345 --key=secret')
  end

  it 'does not confuse literal sentinel-like text with a connection placeholder' do
    definition = {
      id: 'literal',
      metadata: {
        launcher_adapter: :custom,
        additional_arguments: ['LICH_FRONTEND_KEY_PLACEHOLDER', '--key=%key%']
      }
    }

    expect(described_class.with_additional_arguments('frontend', definition)).to eq(
      'frontend LICH_FRONTEND_KEY_PLACEHOLDER --key=%key%'
    )
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
