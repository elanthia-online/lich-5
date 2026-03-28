# frozen_string_literal: true

require 'rspec'

# Load login_spec_helper FIRST - it sets up Lich::Util, Gtk, and other mocks
require_relative '../../../login_spec_helper'

# Ensure FatalAuthError and GUI module are available for specs
module Lich
  module Common
    module Authentication
      class FatalAuthError < StandardError; end unless defined?(FatalAuthError)

      # Stub GUI module so report_connect_error can delegate to show_error_dialog
      module GUI
        def self.show_error_dialog(_button, _message); end
      end unless defined?(GUI)
    end
  end
end

# Stub Gtk classes used by ManualLoginTab that login_spec_helper doesn't provide
module Gtk
  class Entry
    attr_accessor :visibility

    def initialize; end

    def text; ''; end

    def sensitive=(_val); end

    def signal_connect(_signal); end
  end

  class ListStore
    def initialize(*_args); end

    def set_sort_column_id(*_args); end

    def append
      MockIter.new
    end

    def clear; end
  end

  class TreeView
    def initialize(_model = nil); end

    def height_request=(_val); end

    def append_column(_col); end

    def signal_connect(_signal); end

    def selection; nil; end
  end

  class TreeViewColumn
    def initialize(*_args); end

    def resizable=(_val); end
  end

  class CellRendererText
    def initialize; end
  end

  class ScrolledWindow
    def initialize; end

    def set_policy(*_args); end

    def add(_widget); end
  end

  class Table
    def initialize(*_args); end

    def attach(*_args); end
  end

  class RadioButton
    def initialize(**_opts); end

    def signal_connect(_signal); end

    def active?; false; end
  end

  class CheckButton
    def initialize(_label = nil); end

    def set_tooltip_text(_text); end

    def signal_connect(_signal); end

    def active?; false; end

    def visible=(_val); end
  end

  module AttachOptions
    EXPAND = 1
    FILL = 2
  end

  class StyleProvider
    PRIORITY_USER = 800
  end

  module Settings
    def self.default
      @default ||= Struct.new(:gtk_application_prefer_dark_theme).new(false)
    end
  end

  class CssProvider
    def load_from_data(_data); end
  end
end unless defined?(Gtk::Entry)

module Gdk
  module Keyval
    KEY_Return = 0xff0d
  end
end unless defined?(Gdk::Keyval)

# Minimal mock for Gtk iter
class MockIter
  def []=(key, value)
    @data ||= {}
    @data[key] = value
  end

  def [](key)
    @data ||= {}
    @data[key]
  end
end

# Stub production dependencies that ManualLoginTab requires at load time
module Lich
  module Common
    module GUI
      module Components
        def self.create_button(**_opts)
          button = double('Gtk::Button')
          allow(button).to receive(:sensitive=)
          allow(button).to receive(:signal_connect)
          allow(button).to receive(:style_context).and_return(
            double('StyleContext', add_provider: nil, remove_provider: nil)
          )
          button
        end

        def self.create_button_box(_buttons, **_opts)
          double('Gtk::Box')
        end
      end

      module LoginTabUtils
        def self.create_button_css_provider
          double('CssProvider')
        end

        def self.create_custom_launch_entry
          entry = double('ComboBoxEntry')
          allow(entry).to receive(:visible=)
          allow(entry).to receive(:child).and_return(double('Entry', text: ''))
          entry
        end

        def self.create_custom_launch_dir
          entry = double('ComboBoxEntry')
          allow(entry).to receive(:visible=)
          allow(entry).to receive(:child).and_return(double('Entry', text: ''))
          entry
        end
      end

      module ThemeUtils
        def self.light_theme_background
          double('RGBA')
        end

        def self.darkmode_background
          double('RGBA')
        end
      end

      class FavoritesManager; end
    end
  end
end unless defined?(Lich::Common::GUI::Components)

require_relative '../../../../lib/common/gui/parameter_objects'
require_relative '../../../../lib/common/gui/manual_login_tab'

RSpec.describe Lich::Common::GUI::ManualLoginTab do
  # Shared test doubles for login form UI controls
  let(:connect_button) { double('Gtk::Button') }
  let(:disconnect_button) { double('Gtk::Button') }
  let(:user_id_entry) { double('Gtk::Entry') }
  let(:pass_entry) { double('Gtk::Entry') }
  let(:callbacks) { Lich::Common::GUI::CallbackParams.new }

  before do
    allow(connect_button).to receive(:sensitive=)
    allow(disconnect_button).to receive(:sensitive=)
    allow(user_id_entry).to receive(:sensitive=)
    allow(pass_entry).to receive(:sensitive=)
  end

  describe '#report_connect_error' do
    subject(:tab) do
      # Build with minimal valid arguments; create_tab_content is called in initialize
      # but we only need to test the private helper, so we allocate and set callbacks directly
      instance = described_class.allocate
      instance.instance_variable_set(:@callbacks, callbacks)
      instance
    end

    before do
      allow(Lich::Common::Authentication::GUI).to receive(:show_error_dialog)
    end

    it 'delegates to Authentication::GUI.show_error_dialog with connect_button and message' do
      expect(Lich::Common::Authentication::GUI).to receive(:show_error_dialog)
        .with(connect_button, 'bad password')

      tab.send(:report_connect_error, 'bad password', connect_button, disconnect_button, user_id_entry, pass_entry)
    end

    it 're-enables the connect button' do
      expect(connect_button).to receive(:sensitive=).with(true)

      tab.send(:report_connect_error, 'error', connect_button, disconnect_button, user_id_entry, pass_entry)
    end

    it 'disables the disconnect button' do
      expect(disconnect_button).to receive(:sensitive=).with(false)

      tab.send(:report_connect_error, 'error', connect_button, disconnect_button, user_id_entry, pass_entry)
    end

    it 're-enables the user ID entry' do
      expect(user_id_entry).to receive(:sensitive=).with(true)

      tab.send(:report_connect_error, 'error', connect_button, disconnect_button, user_id_entry, pass_entry)
    end

    it 're-enables the password entry' do
      expect(pass_entry).to receive(:sensitive=).with(true)

      tab.send(:report_connect_error, 'error', connect_button, disconnect_button, user_id_entry, pass_entry)
    end

    it 'resets form state before showing the error dialog' do
      expect(connect_button).to receive(:sensitive=).with(true).ordered
      expect(disconnect_button).to receive(:sensitive=).with(false).ordered
      expect(user_id_entry).to receive(:sensitive=).with(true).ordered
      expect(pass_entry).to receive(:sensitive=).with(true).ordered
      expect(Lich::Common::Authentication::GUI).to receive(:show_error_dialog).ordered

      tab.send(:report_connect_error, 'error', connect_button, disconnect_button, user_id_entry, pass_entry)
    end

    context 'when show_error_dialog raises an exception' do
      before do
        allow(Lich::Common::Authentication::GUI).to receive(:show_error_dialog)
          .and_raise(RuntimeError, 'dialog failed')
      end

      it 'still resets form state before the exception propagates' do
        expect(connect_button).to receive(:sensitive=).with(true)
        expect(disconnect_button).to receive(:sensitive=).with(false)
        expect(user_id_entry).to receive(:sensitive=).with(true)
        expect(pass_entry).to receive(:sensitive=).with(true)

        expect {
          tab.send(:report_connect_error, 'error', connect_button, disconnect_button, user_id_entry, pass_entry)
        }.to raise_error(RuntimeError, 'dialog failed')
      end
    end

    context 'when message contains special characters' do
      it 'passes the raw message through without sanitization' do
        msg = "REJECT\n<script>alert('xss')</script>"
        expect(Lich::Common::Authentication::GUI).to receive(:show_error_dialog)
          .with(connect_button, msg)

        tab.send(:report_connect_error, msg, connect_button, disconnect_button, user_id_entry, pass_entry)
      end
    end

    context 'when message is empty' do
      it 'still shows the error dialog' do
        expect(Lich::Common::Authentication::GUI).to receive(:show_error_dialog)
          .with(connect_button, '')

        tab.send(:report_connect_error, '', connect_button, disconnect_button, user_id_entry, pass_entry)
      end
    end
  end

  describe '#setup_connect_button_handler' do
    subject(:tab) do
      instance = described_class.allocate
      instance.instance_variable_set(:@callbacks, callbacks)
      instance
    end

    let(:liststore) { Gtk::ListStore.new(String, String, String, String) }
    let(:mock_user_id_entry) do
      entry = Gtk::Entry.new
      allow(entry).to receive(:text).and_return('TESTUSER')
      allow(entry).to receive(:sensitive=)
      entry
    end
    let(:mock_pass_entry) do
      entry = Gtk::Entry.new
      allow(entry).to receive(:text).and_return('badpassword')
      allow(entry).to receive(:sensitive=)
      entry
    end
    let(:mock_connect_button) do
      button = double('Gtk::Button')
      allow(button).to receive(:sensitive=)
      # Capture the clicked handler
      allow(button).to receive(:signal_connect).with('clicked') { |&block| @clicked_handler = block }
      button
    end
    let(:mock_disconnect_button) do
      button = double('Gtk::Button')
      allow(button).to receive(:sensitive=)
      button
    end

    before do
      allow(Lich::Common::Authentication::GUI).to receive(:show_error_dialog)
      tab.send(:setup_connect_button_handler, mock_connect_button, mock_disconnect_button, mock_user_id_entry, mock_pass_entry, liststore)
    end

    context 'when authentication raises FatalAuthError (wrong password)' do
      before do
        allow(Lich::Common::Authentication).to receive(:authenticate)
          .and_raise(Lich::Common::Authentication::FatalAuthError, 'Invalid password')
      end

      it 'catches the error and resets the form' do
        expect(mock_connect_button).to receive(:sensitive=).with(true)
        expect(mock_user_id_entry).to receive(:sensitive=).with(true)
        expect(mock_pass_entry).to receive(:sensitive=).with(true)

        @clicked_handler.call
      end

      it 'shows the error dialog with the exception message' do
        expect(Lich::Common::Authentication::GUI).to receive(:show_error_dialog)
          .with(mock_connect_button, 'Invalid password')

        @clicked_handler.call
      end

      it 'clears the liststore' do
        expect(liststore).to receive(:clear)

        @clicked_handler.call
      end
    end

    context 'when authentication raises StandardError (network failure)' do
      before do
        allow(Lich::Common::Authentication).to receive(:authenticate)
          .and_raise(StandardError, 'Connection reset by peer')
      end

      it 'catches the error and resets the form' do
        expect(mock_connect_button).to receive(:sensitive=).with(true)
        expect(mock_user_id_entry).to receive(:sensitive=).with(true)
        expect(mock_pass_entry).to receive(:sensitive=).with(true)

        @clicked_handler.call
      end

      it 'shows the error dialog with the exception message' do
        expect(Lich::Common::Authentication::GUI).to receive(:show_error_dialog)
          .with(mock_connect_button, 'Connection reset by peer')

        @clicked_handler.call
      end
    end

    context 'when authentication succeeds with character list' do
      let(:characters) do
        [
          { game_code: 'GS3', game_name: 'GemStone IV', char_code: 'GS3001', char_name: 'Testchar' }
        ]
      end

      before do
        allow(Lich::Common::Authentication).to receive(:authenticate).and_return(characters)
      end

      it 'does not show the error dialog' do
        expect(Lich::Common::Authentication::GUI).not_to receive(:show_error_dialog)

        @clicked_handler.call
      end

      it 'enables the disconnect button' do
        expect(mock_disconnect_button).to receive(:sensitive=).with(true)

        @clicked_handler.call
      end
    end

    context 'when authentication returns error string (legacy error format)' do
      before do
        allow(Lich::Common::Authentication).to receive(:authenticate).and_return('error: unknown')
      end

      it 'shows the error dialog with the user-friendly message' do
        expect(Lich::Common::Authentication::GUI).to receive(:show_error_dialog)
          .with(mock_connect_button, a_string_including('Something went wrong'))

        @clicked_handler.call
      end

      it 'includes the server response in the error message' do
        expect(Lich::Common::Authentication::GUI).to receive(:show_error_dialog)
          .with(mock_connect_button, a_string_including('error: unknown'))

        @clicked_handler.call
      end

      it 'resets the form to editable state' do
        expect(mock_connect_button).to receive(:sensitive=).with(true)
        expect(mock_user_id_entry).to receive(:sensitive=).with(true)
        expect(mock_pass_entry).to receive(:sensitive=).with(true)

        @clicked_handler.call
      end
    end
  end
end
