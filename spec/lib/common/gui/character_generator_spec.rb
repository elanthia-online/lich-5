# frozen_string_literal: true

require 'tmpdir'
require 'yaml'
require 'fileutils'
require_relative '../../../spec_helper'
require_relative '../../../login_spec_helper'

# Exercises the non-GTK launch path behind the Create Character dialog against a
# real entry.yaml. Frontend discovery and the game server are the only stubs.
RSpec.describe Lich::Common::GUI::CharacterGenerator do
  let(:data_dir) { Dir.mktmpdir }
  let(:button) { double('Create Character button') }
  let(:on_play) { ->(_launch_data, _login_context) {} }
  let(:messages) { [] }
  let(:msgbox) { ->(message) { messages << message } }
  let(:auth_gui) { Lich::Common::Authentication::GUI }

  before do
    File.write(File.join(data_dir, 'entry.yaml'), {
      'encryption_mode' => 'plaintext',
      'accounts'        => { 'MYACCOUNT' => { 'password' => 'secret', 'characters' => [] } }
    }.to_yaml)
    allow(Lich::Common::GUI::LoginTabUtils).to receive(:launchable_frontend?).and_return(true)
    allow(auth_gui).to receive(:authenticate_and_launch)
  end

  after { FileUtils.rm_rf(data_dir) }

  def launch(account: 'MYACCOUNT', game_code: 'DR', frontend: 'stormfront')
    described_class.launch(
      data_dir: data_dir, account: account, game_code: game_code, frontend: frontend,
      button: button, on_play: on_play, msgbox: msgbox
    )
  end

  it 'authenticates into the generator with a saved-entry login context' do
    launch

    expect(auth_gui).to have_received(:authenticate_and_launch).with(
      button: button,
      login_info: {
        user_id: 'MYACCOUNT', char_name: 'NEW', game_code: 'DR', game_name: 'DragonRealms',
        frontend: 'stormfront', custom_launch: nil, custom_launch_dir: nil,
        generator: true, saved_entry: true, password: 'secret'
      },
      on_success: on_play,
      on_error: kind_of(Proc)
    )
    expect(messages).to be_empty
  end

  it 'keeps Saga on the Lich handoff path rather than Saga-managed login' do
    allow(Lich::Common::SagaManagedLauncher).to receive(:launch)

    launch(frontend: 'saga')

    expect(Lich::Common::SagaManagedLauncher).not_to have_received(:launch)
    expect(auth_gui).to have_received(:authenticate_and_launch)
      .with(hash_including(login_info: hash_including(frontend: 'saga', generator: true)))
  end

  it 'stops before authenticating when no frontend is available' do
    launch(frontend: nil)

    expect(messages).to eq(['No supported frontend is available.'])
    expect(auth_gui).not_to have_received(:authenticate_and_launch)
  end

  it 'rechecks that the frontend is installed before authenticating' do
    allow(Lich::Common::GUI::LoginTabUtils).to receive(:launchable_frontend?)
      .with(hash_including(frontend: 'wrayth'), refresh: true).and_return(false)

    launch(frontend: 'wrayth')

    expect(messages.first).to start_with('Wrayth is not available on this computer.')
    expect(auth_gui).not_to have_received(:authenticate_and_launch)
  end

  it 'reports an account it cannot read a password for without authenticating' do
    launch(account: 'NOBODY')

    expect(messages).to eq(["Could not read the saved password for NOBODY: account 'NOBODY' not found"])
    expect(auth_gui).not_to have_received(:authenticate_and_launch)
  end

  it 'turns GENERATOR_NOT_AVAILABLE from authentication into a readable message' do
    allow(auth_gui).to receive(:authenticate_and_launch) do |on_error:, **|
      on_error.call('Error(GENERATOR_NOT_AVAILABLE)')
    end

    launch(game_code: 'DRF')

    expect(messages).to eq(["This account can't create a character on DragonRealms Fallen. " \
                            'It needs a subscription or trial for that game.'])
  end

  it 'passes other authentication errors through with context' do
    allow(auth_gui).to receive(:authenticate_and_launch) do |on_error:, **|
      on_error.call('Error(PASSWORD)')
    end

    launch

    expect(messages).to eq(['Could not start the character generator: Error(PASSWORD)'])
  end
end
