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

  describe '.show_dialog' do
    let(:widget) { double('Gtk widget').as_null_object }
    let(:selector) { double('FrontendSelector', widget: widget, on_change: nil, selected_id: 'wizard') }
    let(:game_selection) { Lich::Common::GUI::GameSelection }

    before do
      stub_const('Gtk::Dialog', double(new: widget))
      stub_const('Gtk::Label', double(new: widget))
      stub_const('Gtk::Box', double(new: widget))
      stub_const('Gtk::ResponseType', Module.new.tap { |m| m.const_set(:OK, :ok); m.const_set(:CANCEL, :cancel) })
      allow(widget).to receive(:run).and_return(:cancel)
      allow(Lich::Common::GUI::Accessibility).to receive(:make_window_accessible)
      allow(Lich::Common::GUI::FrontendSelector).to receive(:new).and_return(selector)
      allow(game_selection).to receive(:create_game_selection_combo).and_return(widget)
      allow(game_selection).to receive(:get_selected_game_code).and_return('DR')
    end

    def write_characters(characters)
      File.write(File.join(data_dir, 'entry.yaml'), {
        'encryption_mode' => 'plaintext',
        'accounts'        => { 'MYACCOUNT' => { 'password' => 'secret', 'characters' => characters } }
      }.to_yaml)
    end

    def show_dialog
      described_class.show_dialog(parent: nil, data_dir: data_dir, account: 'MYACCOUNT',
                                  button: button, on_play: on_play, msgbox: msgbox)
    end

    it "preselects the game most of the account's characters are on" do
      write_characters([
                         { 'char_name' => 'Alpha', 'game_code' => 'DR', 'frontend' => 'wizard' },
                         { 'char_name' => 'Beta', 'game_code' => 'DR', 'frontend' => 'wizard' },
                         { 'char_name' => 'Gamma', 'game_code' => 'GS3', 'frontend' => 'wizard' }
                       ])

      show_dialog

      expect(game_selection).to have_received(:create_game_selection_combo).with('DR')
    end

    it 'leaves the game to the combo default when the account has no characters' do
      show_dialog

      expect(game_selection).to have_received(:create_game_selection_combo).with(nil)
    end

    it 'does not launch when the dialog is cancelled' do
      show_dialog

      expect(auth_gui).not_to have_received(:authenticate_and_launch)
    end

    it "preselects the account's usual frontend without re-running discovery" do
      write_characters([
                         { 'char_name' => 'Alpha', 'game_code' => 'DR', 'frontend' => 'genie' },
                         { 'char_name' => 'Beta', 'game_code' => 'DR', 'frontend' => 'genie' },
                         { 'char_name' => 'Gamma', 'game_code' => 'DR', 'frontend' => 'wizard' }
                       ])

      show_dialog

      expect(Lich::Common::GUI::FrontendSelector).to have_received(:new).with(selected_id: 'genie', refresh: false)
    end

    it 'launches with the game and frontend read from the dialog before it is destroyed' do
      destroyed = false
      allow(widget).to receive(:run).and_return(:ok)
      allow(widget).to receive(:destroy) { destroyed = true }
      allow(selector).to receive(:selected_id) { destroyed ? raise('frontend read after destroy') : 'wizard' }
      allow(game_selection).to receive(:get_selected_game_code) { destroyed ? raise('game read after destroy') : 'DRF' }
      allow(described_class).to receive(:launch)

      show_dialog

      expect(described_class).to have_received(:launch).with(
        data_dir: data_dir, account: 'MYACCOUNT', game_code: 'DRF', frontend: 'wizard',
        button: button, on_play: on_play, msgbox: msgbox
      )
    end

    it 'shows the Saga note only while Saga is the selected frontend' do
      saga_label = double('Saga note label').as_null_object
      label_class = double('Gtk::Label')
      allow(label_class).to receive(:new) { |text = nil| text == described_class::SAGA_NOTE ? saga_label : widget }
      stub_const('Gtk::Label', label_class)
      change_callback = nil
      current = 'wizard'
      allow(selector).to receive(:on_change) { |&block| change_callback = block }
      allow(selector).to receive(:selected_id) { current }
      visibility = []
      allow(saga_label).to receive(:visible=) { |value| visibility << value }
      allow(widget).to receive(:run) do
        current = 'saga'
        change_callback.call(selector)
        current = 'stormfront'
        change_callback.call(selector)
        :cancel
      end

      show_dialog

      expect(visibility).to eq([false, true, false])
    end
  end

  it 'passes other authentication errors through with context' do
    allow(auth_gui).to receive(:authenticate_and_launch) do |on_error:, **|
      on_error.call('Error(PASSWORD)')
    end

    launch

    expect(messages).to eq(['Could not start the character generator: Error(PASSWORD)'])
  end
end
