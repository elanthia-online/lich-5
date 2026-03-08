require_relative '../../login_spec_helper'
require_relative '../../../lib/common/session_launcher'

# Contract-first spec for the persistent launcher service.
# This file intentionally defines expected interface and error-handling behavior
# before implementation to support spec-first development.
RSpec.describe Lich::Common::SessionLauncher do
  let(:launch_data) { ['KEY=test', 'GAME=STORM', 'GAMECODE=DR'] }

  # Ensures the service is wired into the namespace expected by gui_login.
  it 'defines a SessionLauncher constant' do
    expect(defined?(Lich::Common::SessionLauncher)).to eq('constant')
  end

  # Base success contract: launcher accepts prepared launch_data and
  # returns a structured hash with at least an :ok key.
  it 'supports launching a session from prepared launch data' do
    expect(described_class).to respond_to(:launch)
    allow(described_class).to receive(:spawn_process).and_return(1234)
    allow(described_class).to receive(:cleanup_sal_file_async)

    result = described_class.launch(launch_data)
    expect(result).to be_a(Hash)
    expect(result).to include(:ok)
    expect(result[:ok]).to be true
    expect(result[:pid]).to eq(1234)
  end

  # Base failure contract: launcher failures are surfaced as structured
  # non-raising responses to support GUI-side user messaging.
  it 'returns structured error details when launch fails' do
    expect(described_class).to respond_to(:launch)
    allow(described_class).to receive(:cleanup_sal_file_async)

    result = described_class.launch([])
    expect(result[:ok]).to be false
    expect(result).to include(:error)
  end

  # Safety contract: no background retry loop.
  # Retry behavior must remain explicit user intent from the launcher UI.
  it 'does not auto-retry a failed launch' do
    expect(described_class).to respond_to(:launch)
    expect(described_class).not_to respond_to(:auto_retry)
  end
end
