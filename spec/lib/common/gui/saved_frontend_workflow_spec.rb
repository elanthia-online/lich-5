# frozen_string_literal: true

require 'tmpdir'
require_relative '../../../login_spec_helper'

RSpec.describe 'Saved frontend cross-tab persistence' do
  manual_class = Lich::Common::GUI::ManualLoginTab
  manager_class = Lich::Common::GUI::AccountManagerUI

  [true, false].each do |notify|
    it "preserves frontend changes on a later manual save (notification: #{notify})" do
      Dir.mktmpdir('lich-cross-tab') do |directory|
        stub_const('DATA_DIR', directory)
        store = Lich::Common::Authentication::EntryStore
        account = Lich::Common::GUI::AccountManager
        original = { char_name: 'Tester', game_code: 'GS3', game_name: 'GemStone IV',
                     user_id: 'TEST', password: 'synthetic', frontend: 'stormfront',
                     custom_launch: nil, custom_launch_dir: nil, encryption_mode: :plaintext }
        expect(store.save_entries(directory, [original])).to be true
        stale = store.load_saved_entries(directory, false)
        tab = manual_class.allocate
        { entry_data: stale, data_dir: directory, autosort_state: false,
          callbacks: Lich::Common::GUI::CallbackParams.new,
          make_quick_option: double(active?: true), make_favorite_option: double(active?: false) }.each { |name, value| tab.instance_variable_set("@#{name}", value) }

        manager = manager_class.new(directory)
        gui = Object.new.extend(Lich::Common)
        gui.instance_variable_set(:@tab_communicator, Lich::Common::GUI::TabCommunicator.new)
        gui.instance_variable_set(:@account_manager_ui, manager)
        gui.instance_variable_set(:@manual_login_tab, tab)
        gui.instance_variable_set(:@autosort_state, false)
        gui.send(:setup_cross_tab_communication)

        expect(account.update_launch_settings(directory, 'TEST', 'Tester', 'GS3',
                                              old_frontend: 'stormfront', custom_launch: nil,
                                              frontend: 'wizard')).to be true
        manager.send(:notify_data_changed, :character_updated, { character: 'Tester' }) if notify

        button = double('play button', sensitive: nil)
        allow(button).to receive(:sensitive=)
        click = nil
        allow(button).to receive(:signal_connect).with('clicked') { |&block| click = block }
        allow(Lich::Common::Authentication).to receive(:authenticate).and_return({})
        allow(Lich::Common::Authentication::LaunchData).to receive(:prepare).and_return(['GAME=STORM'])
        tab.send(:setup_play_button_handler, button,
                 double(selection: double(selected: ['GS3', 'GemStone IV', 'GS3002', 'Second'])),
                 double(text: 'TEST'), double(text: 'synthetic'),
                 double(selected_id: 'stormfront', custom?: false, launchable?: true), double(active?: false))
        click.call

        entries = store.load_saved_entries(directory, false)
        expect(entries.map { |entry| entry[:char_name] }).to contain_exactly('Tester', 'Second')
        expect(entries.find { |entry| entry[:char_name] == 'Tester' })
          .to include(frontend: 'wizard',
                      password: 'synthetic')
      end
    end
  end
end
