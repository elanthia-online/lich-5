# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

require_relative '../../spec_helper'
require_relative '../../../lib/internal_api/active_sessions'

RSpec.describe Lich::InternalAPI::ActiveSessions do
  let(:temp_dir) { Dir.mktmpdir('active-sessions-spec') }

  before do
    stub_const('TEMP_DIR', temp_dir)
    described_class.instance_variable_set(:@registry, nil)
    described_class.instance_variable_set(:@server, nil)
    described_class.instance_variable_set(:@mutex, Mutex.new)
    allow(described_class).to receive(:enabled?).and_return(true)
  end

  after do
    described_class.stop_service!
    FileUtils.rm_rf(temp_dir)
  end

  it 'starts a tokenized owner and writes discovery metadata' do
    fake_server = instance_double(
      Lich::InternalAPI::ActiveSessions::Server,
      start: true,
      stop: nil
    )
    allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new).and_return(fake_server)
    allow_any_instance_of(Lich::InternalAPI::ActiveSessions::Client).to receive(:ping).and_return(false, true)

    expect(described_class.ensure_service!).to be(true)

    discovery = JSON.parse(File.read(File.join(temp_dir, 'lich-active-sessions.json')), symbolize_names: true)
    expect(discovery[:owner_pid]).to eq(Process.pid)
    expect(discovery[:auth_token]).to be_a(String)
    expect(discovery[:auth_token]).not_to be_empty
  end

  it 'reuses an existing healthy owner instead of creating a new server' do
    File.write(
      File.join(temp_dir, 'lich-active-sessions.json'),
      JSON.dump(owner_pid: 123, auth_token: 'shared-token', updated_at: Time.now.to_i)
    )

    allow_any_instance_of(Lich::InternalAPI::ActiveSessions::Client).to receive(:ping).and_return(true)
    expect(Lich::InternalAPI::ActiveSessions::Server).not_to receive(:new)

    expect(described_class.ensure_service!).to be(true)
  end
end
