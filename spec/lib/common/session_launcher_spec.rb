require_relative '../../login_spec_helper'
require_relative '../../../lib/common/session_launcher'

# Contract-first spec for persistent launcher child-process spawning.
# Validates CLI-style argv handoff and detached process behavior.
RSpec.describe Lich::Common::SessionLauncher do
  let(:launch_data) do
    [
      'KEY=test',
      'GAME=STORM',
      'GAMECODE=GST',
      'CUSTOMLAUNCH=/path/to/custom'
    ]
  end

  before(:each) do
    allow(Lich::Common::Authentication::LoginHelpers).to receive(:format_launch_flag).and_return('--GST')
    allow(RbConfig).to receive(:ruby).and_return('/usr/bin/ruby')
    # Keep legacy spawn assertions stable unless explicitly testing optional passthrough.
    allow(described_class).to receive(:optional_spawn_flags).and_return([])
    allow(Process).to receive(:detach)
    allow(described_class).to receive(:spawn).and_return(1234)
  end

  it 'defines a SessionLauncher constant' do
    expect(defined?(Lich::Common::SessionLauncher)).to eq('constant')
  end

  it 'launches a detached child session with CLI args from launch_context' do
    result = described_class.launch(
      launch_data,
      launch_context: {
        char_name: 'Tsetem',
        game_code: 'GST',
        frontend: 'avalon',
        custom_launch: '/path/to/custom'
      }
    )

    expect(result).to eq({ ok: true, pid: 1234 })
    expect(described_class).to have_received(:spawn).with(
      '/usr/bin/ruby',
      File.expand_path($PROGRAM_NAME),
      '--login', 'Tsetem',
      '--GST',
      '--frontend=avalon',
      '--custom-launch=/path/to/custom',
      hash_including(chdir: anything)
    )
    expect(Process).to have_received(:detach).with(1234)
  end

  it 'falls back to launch_data values when launch_context is not provided' do
    launch_data_with_name = launch_data + ['CHARACTER=Tsetem']

    result = described_class.launch(launch_data_with_name)

    expect(result).to eq({ ok: true, pid: 1234 })
    expect(described_class).to have_received(:spawn).with(
      '/usr/bin/ruby',
      File.expand_path($PROGRAM_NAME),
      '--login', 'Tsetem',
      '--GST',
      '--frontend=stormfront',
      '--custom-launch=/path/to/custom',
      hash_including(chdir: anything)
    )
  end

  it 'maps Saga launch data back to the Saga CLI selector' do
    saga_launch_data = launch_data.reject { |line| line.start_with?('GAME=') }
    saga_launch_data.concat(['CHARACTER=Tsetem', 'GAME=SAGA'])

    described_class.launch(saga_launch_data)

    expect(described_class).to have_received(:spawn).with(
      '/usr/bin/ruby',
      File.expand_path($PROGRAM_NAME),
      '--login', 'Tsetem',
      '--GST',
      '--frontend=saga',
      '--custom-launch=/path/to/custom',
      hash_including(chdir: anything)
    )
  end

  it 'returns structured error when character is missing' do
    result = described_class.launch(launch_data)
    expect(result[:ok]).to be false
    expect(result[:error]).to include('missing character')
  end

  it 'prefers the stable frontend identity carried in launch data over legacy GAME mapping' do
    described_class.launch(launch_data + ['CHARACTER=Tsetem', 'FRONTEND=vellum'])

    expect(described_class).to have_received(:spawn).with(
      '/usr/bin/ruby',
      File.expand_path($PROGRAM_NAME),
      '--login', 'Tsetem',
      '--GST',
      '--frontend=vellum',
      '--custom-launch=/path/to/custom',
      hash_including(chdir: anything)
    )
  end

  it 'does not reuse a registry-derived custom command as a saved-entry filter' do
    described_class.launch(
      launch_data + ['CHARACTER=Tsetem', 'FRONTEND=vellum'],
      launch_context: { frontend: 'vellum', custom_launch: nil }
    )

    expect(described_class).to have_received(:spawn).with(
      '/usr/bin/ruby',
      File.expand_path($PROGRAM_NAME),
      '--login', 'Tsetem',
      '--GST',
      '--frontend=vellum',
      hash_including(chdir: anything)
    )
  end

  it 'falls back to legacy GAME mapping when stable frontend identity is blank' do
    described_class.launch(launch_data + ['CHARACTER=Tsetem', 'FRONTEND='])

    expect(described_class).to have_received(:spawn).with(
      '/usr/bin/ruby',
      File.expand_path($PROGRAM_NAME),
      '--login', 'Tsetem',
      '--GST',
      '--frontend=stormfront',
      '--custom-launch=/path/to/custom',
      hash_including(chdir: anything)
    )
  end

  it 'returns structured error details when launch_data is invalid' do
    result = described_class.launch([])
    expect(result).to eq({ ok: false, error: 'launch_data must be a non-empty Array' })
  end

  it 'uses rubyw on Windows' do
    allow(Lich::Common::Frontend).to receive(:platform_key).and_return(:windows)
    allow(RbConfig).to receive(:ruby).and_return('C:/Ruby/bin/ruby.exe')
    allow(File).to receive(:file?).with('C:/Ruby/bin/rubyw.exe').and_return(true)

    expect(described_class.send(:ruby_binary)).to eq('C:/Ruby/bin/rubyw.exe')
  end

  it 'delegates Ruby selection to the shared resolver' do
    allow(Lich::Common::RubyExecutable).to receive(:resolve).and_return('/opt/ruby/bin/ruby')

    expect(described_class.send(:ruby_binary)).to eq('/opt/ruby/bin/ruby')
    expect(Lich::Common::RubyExecutable).to have_received(:resolve)
  end

  it 'forwards optional dark mode and directory flags only when defined' do
    allow(described_class).to receive(:optional_spawn_flags).and_call_original
    allow(Lich).to receive(:track_dark_mode).and_return(true)
    stub_const('LICH_DIR', '/tmp/lich-home')

    result = described_class.launch(
      launch_data + ['CHARACTER=Tsetem'],
      launch_context: {
        frontend: 'stormfront'
      }
    )

    expect(result).to eq({ ok: true, pid: 1234 })
    expect(described_class).to have_received(:spawn).with(
      '/usr/bin/ruby',
      File.expand_path($PROGRAM_NAME),
      '--login', 'Tsetem',
      '--GST',
      '--frontend=stormfront',
      '--custom-launch=/path/to/custom',
      '--dark-mode=true',
      hash_including(chdir: '/tmp/lich-home')
    )
  end

  it 'forwards explicit non-default directory overrides' do
    allow(described_class).to receive(:optional_spawn_flags).and_call_original
    allow(Lich).to receive(:track_dark_mode).and_return(nil)
    stub_const('LICH_DIR', '/tmp/lich-home')
    stub_const('DATA_DIR', '/tmp/lich-home/data')
    stub_const('SCRIPT_DIR', '/tmp/lich-home/scripts')

    described_class.launch(
      launch_data + ['CHARACTER=Tsetem'],
      launch_context: {
        frontend: 'stormfront',
        data_dir: '/tmp/alt-data',
        script_dir: '/tmp/lich-home/scripts'
      }
    )

    expect(described_class).to have_received(:spawn).with(
      '/usr/bin/ruby',
      File.expand_path($PROGRAM_NAME),
      '--login', 'Tsetem',
      '--GST',
      '--frontend=stormfront',
      '--custom-launch=/path/to/custom',
      '--data=/tmp/alt-data',
      hash_including(chdir: '/tmp/lich-home')
    )
  end

  it 'uses per-launch home_dir for chdir when provided in launch_context' do
    launch_data_with_name = launch_data + ['CHARACTER=Tsetem']

    described_class.launch(
      launch_data_with_name,
      launch_context: {
        home_dir: '/tmp/override-home'
      }
    )

    expect(described_class).to have_received(:spawn).with(
      '/usr/bin/ruby',
      File.expand_path($PROGRAM_NAME),
      '--login', 'Tsetem',
      '--GST',
      '--frontend=stormfront',
      '--custom-launch=/path/to/custom',
      hash_including(chdir: '/tmp/override-home')
    )
  end
end
