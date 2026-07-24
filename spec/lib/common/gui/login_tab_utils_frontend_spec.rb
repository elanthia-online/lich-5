# frozen_string_literal: true

require 'rspec'
require_relative '../../../../lib/common/front-end'
require_relative '../../../../lib/common/frontend_locator'
require_relative '../../../../lib/common/gui/login_tab_utils'

RSpec.describe Lich::Common::GUI::LoginTabUtils do
  let(:button) do
    Class.new do
      attr_accessor :sensitive, :tooltip_text
      attr_reader :handler

      def signal_connect(_signal, &handler)
        @handler = handler
      end
    end.new
  end

  before do
    event_type = Module.new
    event_type.const_set(:BUTTON_RELEASE, :button_release)
    gdk = Module.new
    gdk.const_set(:EventType, event_type)
    stub_const('Gdk', gdk)
  end

  describe '.custom_launch?' do
    it 'accepts only nonblank commands' do
      expect([nil, '', '   '].map { |value| described_class.custom_launch?(value) })
        .to all(be(false))
      expect(described_class.custom_launch?(' /usr/bin/client ')).to be(true)
    end
  end

  describe '.launchable_frontend?' do
    it 'allows a nonblank custom launch without discovery' do
      expect(Lich::Common::FrontendLocator).not_to receive(:launchable?)

      expect(
        described_class.launchable_frontend?(
          {
            frontend: 'stormfront',
            custom_launch: '/usr/bin/client'
          }
        )
      ).to be(true)
    end

    it 'treats a blank custom launch as a native launch' do
      expect(Lich::Common::FrontendLocator)
        .to receive(:launchable?).with('stormfront', refresh: false).and_return(false)

      expect(
        described_class.launchable_frontend?(
          {
            frontend: 'stormfront',
            custom_launch: '   '
          }
        )
      ).to be(false)
    end

    it 'uses platform-aware native launch availability for Saga' do
      expect(Lich::Common::FrontendLocator)
        .to receive(:launchable?).with('saga', refresh: false).and_return(false)

      expect(
        described_class.launchable_frontend?(
          {
            frontend: 'saga',
            custom_launch: nil
          }
        )
      ).to be(false)
    end

    it 'returns false for an unknown saved frontend' do
      expect(
        described_class.launchable_frontend?(
          {
            frontend: 'unknown',
            custom_launch: nil
          }
        )
      ).to be(false)
    end
  end

  describe '.setup_play_button_handler' do
    let(:login_info) do
      {
        frontend: 'stormfront',
        custom_launch: nil,
        user_id: 'TESTACCOUNT',
        char_name: 'Tsetem',
        game_code: 'GS3',
        password: 'not-forwarded'
      }
    end
    let(:event) { Struct.new(:event_type, :button).new(:button_release, 1) }

    it 'keeps an initially unavailable entry actionable and revalidates on click' do
      allow(described_class).to receive(:launchable_frontend?).and_return(false, true)
      allow(Lich::Common::Authentication::GUI).to receive(:authenticate_and_launch)

      described_class.setup_play_button_handler(button, login_info, proc {})
      expect(button.tooltip_text).to include('not available')

      button.handler.call(button, event)

      expect(Lich::Common::Authentication::GUI).to have_received(:authenticate_and_launch)
      expect(button.tooltip_text).to be_nil
    end

    it 'marks an unavailable click handled without authenticating' do
      allow(described_class).to receive(:launchable_frontend?).and_return(true, false)
      allow(Lich).to receive(:msgbox)
      allow(Lich::Common::Authentication::GUI).to receive(:authenticate_and_launch)

      described_class.setup_play_button_handler(button, login_info, proc {})
      result = button.handler.call(button, event)

      expect(result).to be(true)
      expect(Lich).to have_received(:msgbox).with(
        message: 'Wrayth is no longer available.',
        icon: :error
      )
      expect(Lich::Common::Authentication::GUI).not_to have_received(:authenticate_and_launch)
    end

    it 'routes a native Saga entry through Saga-managed Via-Lich login without Lich authentication' do
      login_info[:frontend] = 'saga'
      allow(described_class).to receive(:launchable_frontend?).and_return(true)
      allow(Lich::Common::SagaManagedLauncher).to receive(:launch).and_return(ok: true, pid: 12_345)
      allow(Lich::Common::Authentication::GUI).to receive(:authenticate_and_launch)
      allow(Lich::Common::Authentication::GUI).to receive(:schedule_button_reenable)
      callback = proc {}
      allow(callback).to receive(:call).and_call_original

      described_class.setup_play_button_handler(button, login_info, callback)
      button.handler.call(button, event)

      expect(Lich::Common::SagaManagedLauncher).to have_received(:launch).with(
        account: 'TESTACCOUNT',
        character: 'Tsetem',
        game_code: 'GS3'
      )
      expect(callback).to have_received(:call).with(
        nil,
        hash_including(
          managed_launch_completed: true,
          managed_launch_pid: 12_345
        )
      )
      expect(Lich::Common::Authentication::GUI).to have_received(:schedule_button_reenable).with(button)
      expect(Lich::Common::Authentication::GUI).not_to have_received(:authenticate_and_launch)
    end

    it 'reports a Saga-managed launch failure without Lich authentication' do
      login_info[:frontend] = 'saga'
      allow(described_class).to receive(:launchable_frontend?).and_return(true)
      allow(Lich::Common::SagaManagedLauncher).to receive(:launch)
        .and_return(ok: false, error: 'Saga was not found')
      allow(Lich::Common::Authentication::GUI).to receive(:authenticate_and_launch)
      allow(Lich::Common::Authentication::GUI).to receive(:schedule_button_reenable)
      allow(Lich).to receive(:msgbox)

      described_class.setup_play_button_handler(button, login_info, proc {})
      button.handler.call(button, event)

      expect(Lich).to have_received(:msgbox).with(
        message: 'Failed to launch Saga: Saga was not found',
        icon: :error
      )
      expect(Lich::Common::Authentication::GUI).not_to have_received(:authenticate_and_launch)
      expect(Lich::Common::Authentication::GUI).not_to have_received(:schedule_button_reenable)
      expect(button.sensitive).to be true
    end

    it 'preserves Lich authentication for an explicit Saga Custom Launch' do
      login_info[:frontend] = 'saga'
      login_info[:custom_launch] = '/Applications/Saga.app/Contents/MacOS/Saga'
      allow(described_class).to receive(:launchable_frontend?).and_return(true)
      allow(Lich::Common::SagaManagedLauncher).to receive(:launch)
      allow(Lich::Common::Authentication::GUI).to receive(:authenticate_and_launch)

      callback = proc {}
      described_class.setup_play_button_handler(button, login_info, callback)
      button.handler.call(button, event)

      expect(Lich::Common::SagaManagedLauncher).not_to have_received(:launch)
      expect(Lich::Common::Authentication::GUI).to have_received(:authenticate_and_launch).with(
        button: button,
        login_info: login_info,
        on_success: callback
      )
    end
  end
end
