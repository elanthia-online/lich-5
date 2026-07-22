# frozen_string_literal: true

require 'rspec'
require_relative '../../../../lib/common/front-end'
require_relative '../../../../lib/common/frontend_locator'
require_relative '../../../../lib/common/gui/login_tab_utils'

RSpec.describe Lich::Common::GUI::LoginTabUtils do
  let(:button) do
    Class.new do
      attr_accessor :tooltip_text
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
    let(:login_info) { { frontend: 'stormfront', custom_launch: nil } }
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
  end
end
