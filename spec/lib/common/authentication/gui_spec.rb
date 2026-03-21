# frozen_string_literal: true

require 'rspec'

# Load login_spec_helper FIRST - it sets up Lich::Util and other mocks
require_relative '../../../login_spec_helper'

# Add MessageDialog to Gtk module (login_spec_helper defines Gtk but not MessageDialog)
module Gtk
  class MessageDialog
    def initialize(**_opts); end

    def secondary_text=(_text); end

    def run; end

    def destroy; end
  end
end unless defined?(Gtk::MessageDialog)

# Add GLib::Timeout for debounce scheduling in GUI auth tests.
module GLib
  class Timeout
    def self.add(_milliseconds, &_block); end
  end
end unless defined?(GLib::Timeout)

# Extend Authentication mocks with additional methods needed for GUI tests
module Lich
  module Common
    module Authentication
      class FatalAuthError < StandardError; end unless defined?(FatalAuthError)

      module LaunchData
        def self.prepare(*_args)
          ['KEY=test123', 'GAME=GS3']
        end
      end unless defined?(LaunchData)
    end
  end
end

require_relative '../../../../lib/common/authentication/gui'

RSpec.describe Lich::Common::Authentication::GUI do
  let(:mock_button) do
    button = double('Gtk::Button')
    allow(button).to receive(:sensitive=)
    allow(button).to receive(:toplevel).and_return(nil)
    button
  end

  let(:login_info) do
    {
      user_id: 'testuser',
      password: 'testpass',
      char_name: 'TestChar',
      game_code: 'GS3',
      frontend: 'stormfront',
      custom_launch: nil,
      custom_launch_dir: nil
    }
  end

  describe '.authenticate_and_launch' do
    let(:auth_data) { { 'key' => 'abc123', 'gamecode' => 'GS3' } }
    let(:launch_data) { ['KEY=abc123', 'GAME=GS3'] }

    before do
      allow(Lich::Common::Authentication).to receive(:authenticate).and_return(auth_data)
      allow(Lich::Common::Authentication::LaunchData).to receive(:prepare).and_return(launch_data)
      allow(GLib::Timeout).to receive(:add)
    end

    it 'disables the button before authentication' do
      expect(mock_button).to receive(:sensitive=).with(false)

      described_class.authenticate_and_launch(
        button: mock_button,
        login_info: login_info,
        on_success: ->(_data) {}
      )
    end

    it 'calls authenticate with correct parameters' do
      expect(Lich::Common::Authentication).to receive(:authenticate).with(
        account: 'testuser',
        password: 'testpass',
        character: 'TestChar',
        game_code: 'GS3'
      ).and_return(auth_data)

      described_class.authenticate_and_launch(
        button: mock_button,
        login_info: login_info,
        on_success: ->(_data) {}
      )
    end

    it 'calls LaunchData.prepare with auth data and frontend' do
      expect(Lich::Common::Authentication::LaunchData).to receive(:prepare).with(
        auth_data,
        'stormfront',
        nil,
        nil
      ).and_return(launch_data)

      described_class.authenticate_and_launch(
        button: mock_button,
        login_info: login_info,
        on_success: ->(_data) {}
      )
    end

    it 'calls on_success callback with launch data' do
      callback_data = nil
      on_success = ->(data) { callback_data = data }

      described_class.authenticate_and_launch(
        button: mock_button,
        login_info: login_info,
        on_success: on_success
      )

      expect(callback_data).to eq(launch_data)
    end

    it 'handles nil on_success callback gracefully (no-op)' do
      # This should not raise an error - the safe navigation operator handles nil
      expect {
        described_class.authenticate_and_launch(
          button: mock_button,
          login_info: login_info,
          on_success: nil
        )
      }.not_to raise_error
    end

    it 'schedules button restore with a 2000ms debounce after successful launch' do
      expect(GLib::Timeout).to receive(:add).with(2000)

      described_class.authenticate_and_launch(
        button: mock_button,
        login_info: login_info,
        on_success: ->(_data) {}
      )
    end

    it 're-enables button when debounce timer callback executes' do
      timeout_block = nil
      allow(GLib::Timeout).to receive(:add) { |_ms, &block| timeout_block = block }

      described_class.authenticate_and_launch(
        button: mock_button,
        login_info: login_info,
        on_success: ->(_data) {}
      )

      expect(mock_button).to receive(:sensitive=).with(true)
      expect(timeout_block.call).to be(false)
    end

    context 'when authentication fails with FatalAuthError' do
      before do
        allow(Lich::Common::Authentication).to receive(:authenticate)
          .and_raise(Lich::Common::Authentication::FatalAuthError, 'REJECT')
      end

      it 're-enables the button' do
        expect(mock_button).to receive(:sensitive=).with(false)
        expect(mock_button).to receive(:sensitive=).with(true)
        expect(GLib::Timeout).not_to receive(:add)

        described_class.authenticate_and_launch(
          button: mock_button,
          login_info: login_info,
          on_success: ->(_data) {}
        )
      end

      it 'calls on_error callback if provided' do
        error_message = nil
        on_error = ->(msg) { error_message = msg }

        described_class.authenticate_and_launch(
          button: mock_button,
          login_info: login_info,
          on_success: ->(_data) {},
          on_error: on_error
        )

        expect(error_message).to eq('REJECT')
      end
    end

    context 'when authentication fails with StandardError' do
      before do
        allow(Lich::Common::Authentication).to receive(:authenticate)
          .and_raise(StandardError, 'Connection failed')
      end

      it 're-enables the button' do
        expect(mock_button).to receive(:sensitive=).with(false)
        expect(mock_button).to receive(:sensitive=).with(true)
        expect(GLib::Timeout).not_to receive(:add)

        described_class.authenticate_and_launch(
          button: mock_button,
          login_info: login_info,
          on_success: ->(_data) {}
        )
      end
    end
  end

  describe '.handle_auth_error' do
    it 're-enables the button' do
      expect(mock_button).to receive(:sensitive=).with(true)

      described_class.handle_auth_error(mock_button, StandardError.new('test'), nil)
    end

    it 'calls on_error callback if provided' do
      error_message = nil
      on_error = ->(msg) { error_message = msg }

      described_class.handle_auth_error(mock_button, StandardError.new('test error'), on_error)

      expect(error_message).to eq('test error')
    end

    it 'shows error dialog if no on_error callback' do
      expect(described_class).to receive(:show_error_dialog).with(mock_button, 'test error')

      described_class.handle_auth_error(mock_button, StandardError.new('test error'), nil)
    end
  end

  describe '.show_error_dialog' do
    it 'creates and shows a message dialog' do
      mock_dialog = instance_double(Gtk::MessageDialog)
      expect(Gtk::MessageDialog).to receive(:new).and_return(mock_dialog)
      expect(mock_dialog).to receive(:secondary_text=).with('Test error message')
      expect(mock_dialog).to receive(:run)
      expect(mock_dialog).to receive(:destroy)

      described_class.show_error_dialog(mock_button, 'Test error message')
    end
  end
end
