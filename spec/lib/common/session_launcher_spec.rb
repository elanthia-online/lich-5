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
    allow(described_class).to receive(:windows?).and_return(false)
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
      '--avalon',
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
      '--stormfront',
      '--custom-launch=/path/to/custom',
      hash_including(chdir: anything)
    )
  end

  it 'returns structured error when character is missing' do
    result = described_class.launch(launch_data)
    expect(result[:ok]).to be false
    expect(result[:error]).to include('missing character')
  end

  it 'returns structured error details when launch_data is invalid' do
    result = described_class.launch([])
    expect(result).to eq({ ok: false, error: 'launch_data must be a non-empty Array' })
  end

  it 'uses rubyw on Windows' do
    allow(described_class).to receive(:windows?).and_return(true)
    allow(RbConfig).to receive(:ruby).and_return('C:/Ruby/bin/ruby.exe')

    expect(described_class.send(:ruby_binary)).to eq('C:/Ruby/bin/rubyw.exe')
  end

  it 'forwards optional dark mode and directory flags only when defined' do
    allow(described_class).to receive(:optional_spawn_flags).and_call_original
    allow(Lich).to receive(:track_dark_mode).and_return(true)
    stub_const('LICH_DIR', '/tmp/lich-home')
    stub_const('DATA_DIR', '/tmp/lich-data')
    stub_const('SCRIPT_DIR', '/tmp/lich-scripts')

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
      '--stormfront',
      '--custom-launch=/path/to/custom',
      '--dark-mode=true',
      '--home=/tmp/lich-home',
      '--data=/tmp/lich-data',
      '--scripts=/tmp/lich-scripts',
      "--lib=#{LIB_DIR}",
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
      '--stormfront',
      '--custom-launch=/path/to/custom',
      hash_including(chdir: '/tmp/override-home')
    )
  end
end
