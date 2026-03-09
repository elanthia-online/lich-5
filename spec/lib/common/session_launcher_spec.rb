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
end
