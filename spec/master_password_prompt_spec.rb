# frozen_string_literal: true

require 'rspec'
require_relative 'login_spec_helper'
require_relative '../lib/common/gui/master_password_prompt'
require_relative '../lib/common/gui/master_password_manager'

# Stub GTK components for CI/CD environments without GTK tools
module Gtk
  class MessageDialog
    def initialize(*args, **kwargs); end

    def secondary_text=(text); end

    def run
      ResponseType::YES
    end

    def destroy; end
  end

  class ResponseType
    YES = 0
    NO = 1
  end

  def self.queue
    yield
  end
end

# Stub Lich.log for tests
module Lich
  def self.log(message)
    # Stub logger - no-op for tests
  end
end

RSpec.describe Lich::Common::GUI::MasterPasswordPrompt do
  before do
    # Default stub: allow weak passwords (return true)
    # Tests with .with() matchers will override with specific return values
    allow(described_class).to receive(:show_warning_dialog).and_return(true)
  end

  describe '.show_create_master_password_dialog' do
    context 'when user enters valid strong password' do
      it 'returns the password' do
        allow(Lich::Common::GUI::MasterPasswordPromptUI).to receive(:show_dialog)
          .and_return('StrongPassword123!')

        result = described_class.show_create_master_password_dialog

        expect(result).to eq('StrongPassword123!')
      end
    end

    context 'when user cancels dialog' do
      it 'returns nil' do
        allow(Lich::Common::GUI::MasterPasswordPromptUI).to receive(:show_dialog)
          .and_return(nil)

        result = described_class.show_create_master_password_dialog

        expect(result).to be_nil
      end
    end

    context 'when password is less than 8 characters' do
      it 'shows weak password warning' do
        allow(Lich::Common::GUI::MasterPasswordPromptUI).to receive(:show_dialog)
          .and_return('short', 'StrongPassword123!')

        allow(described_class).to receive(:show_warning_dialog)
          .with('Short Password', /shorter than 8 characters/)
          .and_return(false)

        described_class.show_create_master_password_dialog

        expect(described_class).to have_received(:show_warning_dialog)
      end

      it 'prompts again if user rejects weak password' do
        weak_password = 'short'
        strong_password = 'StrongPassword123!'

        allow(Lich::Common::GUI::MasterPasswordPromptUI).to receive(:show_dialog)
          .and_return(weak_password, strong_password)

        allow(described_class).to receive(:show_warning_dialog)
          .and_return(false)

        described_class.show_create_master_password_dialog

        expect(Lich::Common::GUI::MasterPasswordPromptUI).to have_received(:show_dialog).at_least(:twice)
      end

      it 'accepts weak password if user confirms' do
        allow(Lich::Common::GUI::MasterPasswordPromptUI).to receive(:show_dialog)
          .and_return('short')

        allow(described_class).to receive(:show_warning_dialog)
          .and_return(true)

        result = described_class.show_create_master_password_dialog

        expect(result).to eq('short')
      end
    end

    context 'when password is 8 or more characters' do
      it 'does not show weak password warning' do
        allow(Lich::Common::GUI::MasterPasswordPromptUI).to receive(:show_dialog)
          .and_return('ValidPassword123')

        expect(described_class).not_to receive(:show_warning_dialog)

        result = described_class.show_create_master_password_dialog

        expect(result).to eq('ValidPassword123')
      end
    end

    context 'when password is exactly 8 characters' do
      it 'passes validation without warning' do
        allow(Lich::Common::GUI::MasterPasswordPromptUI).to receive(:show_dialog)
          .and_return('Pass1234')

        expect(described_class).not_to receive(:show_warning_dialog)

        result = described_class.show_create_master_password_dialog

        expect(result).to eq('Pass1234')
      end
    end

    context 'with edge cases' do
      it 'handles empty string' do
        allow(Lich::Common::GUI::MasterPasswordPromptUI).to receive(:show_dialog)
          .and_return('')

        result = described_class.show_create_master_password_dialog

        expect(result).to eq('')
      end

      it 'handles password with special characters' do
        password = "P@ss!#%^&*()-_=+[]{}';:\"<>?,./\\"
        allow(Lich::Common::GUI::MasterPasswordPromptUI).to receive(:show_dialog)
          .and_return(password)

        result = described_class.show_create_master_password_dialog

        expect(result).to eq(password)
      end

      it 'handles unicode characters' do
        password = 'Пароль密码🔐12345'
        allow(Lich::Common::GUI::MasterPasswordPromptUI).to receive(:show_dialog)
          .and_return(password)

        result = described_class.show_create_master_password_dialog

        expect(result).to eq(password)
      end

      it 'handles very long password' do
        password = 'A' * 1000
        allow(Lich::Common::GUI::MasterPasswordPromptUI).to receive(:show_dialog)
          .and_return(password)

        result = described_class.show_create_master_password_dialog

        expect(result).to eq(password)
      end
    end

    context 'logging' do
      it 'logs when password is validated' do
        allow(Lich::Common::GUI::MasterPasswordPromptUI).to receive(:show_dialog)
          .and_return('ValidPassword123')

        expect(Lich).to receive(:log)
          .with(/Master password strength validated/)

        described_class.show_create_master_password_dialog
      end

      it 'logs when user overrides weak password' do
        allow(Lich::Common::GUI::MasterPasswordPromptUI).to receive(:show_dialog)
          .and_return('short')
        allow(described_class).to receive(:show_warning_dialog)
          .and_return(true)

        expect(Lich).to receive(:log)
          .with(/user override/)

        described_class.show_create_master_password_dialog
      end
    end
  end

  describe '.validate_master_password' do
    let(:master_password) { 'TestPassword123' }
    let(:validation_test) { 'validation_test_hash' }

    context 'with valid parameters' do
      it 'calls MasterPasswordManager.validate_master_password' do
        expect(Lich::Common::GUI::MasterPasswordManager).to receive(:validate_master_password)
          .with(master_password, validation_test)
          .and_return(true)

        result = described_class.validate_master_password(master_password, validation_test)

        expect(result).to be true
      end
    end

    context 'when master_password is nil' do
      it 'returns false' do
        result = described_class.validate_master_password(nil, validation_test)

        expect(result).to be false
      end
    end

    context 'when validation_test is nil' do
      it 'returns false' do
        result = described_class.validate_master_password(master_password, nil)

        expect(result).to be false
      end
    end

    context 'when both are nil' do
      it 'returns false' do
        result = described_class.validate_master_password(nil, nil)

        expect(result).to be false
      end
    end

    context 'when password matches validation test' do
      it 'returns true' do
        expect(Lich::Common::GUI::MasterPasswordManager).to receive(:validate_master_password)
          .and_return(true)

        result = described_class.validate_master_password(master_password, validation_test)

        expect(result).to be true
      end
    end

    context 'when password does not match validation test' do
      it 'returns false' do
        expect(Lich::Common::GUI::MasterPasswordManager).to receive(:validate_master_password)
          .and_return(false)

        result = described_class.validate_master_password(master_password, validation_test)

        expect(result).to be false
      end
    end
  end

  describe '.show_enter_master_password_dialog' do
    context 'when user enters valid password' do
      it 'returns hash with password and continue_session' do
        allow(Lich::Common::GUI::MasterPasswordPromptUI).to receive(:show_recovery_dialog)
          .and_return({ password: 'RecoveredPassword123', continue_session: true })

        result = described_class.show_enter_master_password_dialog

        expect(result).to eq({ password: 'RecoveredPassword123', continue_session: true })
      end
    end

    context 'when user cancels dialog' do
      it 'returns nil' do
        allow(Lich::Common::GUI::MasterPasswordPromptUI).to receive(:show_recovery_dialog)
          .and_return(nil)

        result = described_class.show_enter_master_password_dialog

        expect(result).to be_nil
      end
    end

    context 'logging' do
      it 'logs when password is entered for recovery' do
        allow(Lich::Common::GUI::MasterPasswordPromptUI).to receive(:show_recovery_dialog)
          .and_return({ password: 'RecoveredPassword123', continue_session: true })

        expect(Lich).to receive(:log)
          .with(/Master password entered and validated for recovery/)

        described_class.show_enter_master_password_dialog
      end
    end
  end

  # GTK-dependent tests skipped in CI/CD environments without GTK tools
  # describe '.show_warning_dialog (private)' do
  #   Gtk::MessageDialog tests removed for CI/CD compatibility
  # end
end
