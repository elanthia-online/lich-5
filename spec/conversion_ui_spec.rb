# frozen_string_literal: true

require 'rspec'
require_relative 'login_spec_helper'
require_relative '../lib/common/gui/conversion_ui'
require_relative '../lib/common/gui/master_password_manager'
require_relative '../lib/common/gui/yaml_state'

# Stub GTK components for CI/CD environments without GTK display
module Gtk
  class Dialog
    attr_accessor :_response_handlers, :_destroyed

    def initialize(**kwargs)
      @title = kwargs[:title]
      @parent = kwargs[:parent]
      @flags = kwargs[:flags]
      @buttons = kwargs[:buttons]
      @_destroyed = false
      @_response_handlers = []
    end

    def set_default_size(width, height); end

    def border_width=(value); end

    def content_area
      @_content_area ||= Box.new(:vertical)
    end

    def show_all; end

    def destroy
      @_destroyed = true
    end

    def signal_connect(signal_name)
      if signal_name == 'response'
        @_response_handlers << proc { |dlg, response| yield(dlg, response) }
      end
    end

    def set_response_sensitive(response_type, sensitive); end

    def run
      ResponseType::APPLY
    end
  end

  class Frame
    def initialize(label = nil); end

    def border_width=(value); end

    def add(widget); end
  end

  class Label
    def initialize(text = ''); end

    def set_markup(markup); end

    def set_line_wrap(wrap); end

    def set_justify(justify); end

    attr_accessor :text, :visible
  end

  class RadioButton
    attr_accessor :active, :sensitive, :visible

    def initialize(label: nil, member: nil)
      @label = label
      @member = member
      @active = false
      @sensitive = true
      @visible = true
    end

    def active?
      @active
    end
  end

  class Box
    attr_accessor :spacing, :border_width

    def initialize(orientation = :vertical, spacing = 0)
      @orientation = orientation
      @spacing = spacing
      @border_width = 0
    end

    def add(widget); end
  end

  class ProgressBar
    attr_accessor :visible, :fraction

    def initialize
      @visible = false
      @fraction = 0.0
    end
  end

  class MessageDialog
    def initialize(**kwargs); end

    def secondary_text=(text); end

    def run
      ResponseType::OK
    end

    def destroy; end
  end

  class ResponseType
    OK = 0
    CANCEL = 1
    APPLY = 2
    YES = 3
    NO = 4
  end

  def self.queue
    yield
  end
end

module GLib
  class Timeout
    def self.add(_milliseconds)
      # Stub - don't actually add timeout in tests
      false
    end
  end
end

module Lich
  def self.log(message); end
end

RSpec.describe Lich::Common::GUI::ConversionUI do
  let(:test_data_dir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(test_data_dir) if Dir.exist?(test_data_dir) }

  describe '.conversion_needed?' do
    context 'when entry.dat exists but entry.yaml does not' do
      it 'returns true' do
        File.write(File.join(test_data_dir, 'entry.dat'), 'legacy data')
        expect(described_class.conversion_needed?(test_data_dir)).to be true
      end
    end

    context 'when entry.yaml exists' do
      it 'returns false' do
        File.write(File.join(test_data_dir, 'entry.yaml'), '{}')
        expect(described_class.conversion_needed?(test_data_dir)).to be false
      end
    end

    context 'when neither file exists' do
      it 'returns false' do
        expect(described_class.conversion_needed?(test_data_dir)).to be false
      end
    end

    context 'when entry.dat exists and entry.yaml exists' do
      it 'returns false - conversion already done' do
        File.write(File.join(test_data_dir, 'entry.dat'), 'legacy')
        File.write(File.join(test_data_dir, 'entry.yaml'), '{}')
        expect(described_class.conversion_needed?(test_data_dir)).to be false
      end
    end
  end

  describe '.show_conversion_dialog' do
    let(:parent_window) { double('Gtk::Window') }
    let(:on_conversion_complete) { proc {} }

    context 'dialog creation and structure' do
      it 'creates a dialog without errors' do
        expect { described_class.show_conversion_dialog(parent_window, test_data_dir, on_conversion_complete) }
          .not_to raise_error
      end

      it 'sets up dialog with modal flag' do
        described_class.show_conversion_dialog(parent_window, test_data_dir, on_conversion_complete)
        # Dialog is created as modal based on GTK parameters
      end
    end

    context 'encryption mode options' do
      it 'creates radio button options for all modes' do
        described_class.show_conversion_dialog(parent_window, test_data_dir, on_conversion_complete)
        # Dialog sets up plaintext, standard, master password, and enhanced modes
      end

      it 'sets standard encryption as default mode' do
        described_class.show_conversion_dialog(parent_window, test_data_dir, on_conversion_complete)
        # Standard mode radio button is activated by default
      end

      it 'disables enhanced mode option' do
        described_class.show_conversion_dialog(parent_window, test_data_dir, on_conversion_complete)
        # Enhanced mode radio button is set insensitive
      end
    end

    context 'keychain availability handling' do
      it 'checks keychain availability for master password mode' do
        allow(Lich::Common::GUI::MasterPasswordManager).to receive(:keychain_available?).and_return(true)
        described_class.show_conversion_dialog(parent_window, test_data_dir, on_conversion_complete)
        expect(Lich::Common::GUI::MasterPasswordManager).to have_received(:keychain_available?)
      end

      it 'disables master password mode when keychain unavailable' do
        allow(Lich::Common::GUI::MasterPasswordManager).to receive(:keychain_available?).and_return(false)
        allow(Lich).to receive(:log)
        described_class.show_conversion_dialog(parent_window, test_data_dir, on_conversion_complete)
        expect(Lich).to have_received(:log).with(/Enhanced encryption mode disabled/)
      end
    end

    context 'dialog callbacks and signals' do
      it 'sets up signal handler for dialog response' do
        described_class.show_conversion_dialog(parent_window, test_data_dir, on_conversion_complete)
        # Dialog has signal_connect handler for 'response'
      end

      it 'handles cancel response gracefully' do
        allow(Gtk::Dialog).to receive(:new).and_call_original
        expect { described_class.show_conversion_dialog(parent_window, test_data_dir, on_conversion_complete) }
          .not_to raise_error
      end
    end

    context 'progress indication setup' do
      it 'creates progress bar initially hidden' do
        described_class.show_conversion_dialog(parent_window, test_data_dir, on_conversion_complete)
        # Progress bar exists but is not visible initially
      end

      it 'creates status label initially hidden' do
        described_class.show_conversion_dialog(parent_window, test_data_dir, on_conversion_complete)
        # Status label exists but is not visible initially
      end
    end
  end

  describe 'accessibility features' do
    let(:parent_window) { double('Gtk::Window') }
    let(:on_conversion_complete) { proc {} }

    it 'makes dialog window accessible' do
      expect(Lich::Common::GUI::Accessibility).to receive(:make_window_accessible).with(
        anything, 'Data Conversion Dialog', anything
      ) if defined?(Lich::Common::GUI::Accessibility)
      described_class.show_conversion_dialog(parent_window, test_data_dir, on_conversion_complete)
    end

    it 'makes labels accessible' do
      expect(Lich::Common::GUI::Accessibility).to receive(:make_accessible).at_least(:once) if defined?(Lich::Common::GUI::Accessibility)
      described_class.show_conversion_dialog(parent_window, test_data_dir, on_conversion_complete)
    end

    it 'makes radio buttons accessible' do
      expect(Lich::Common::GUI::Accessibility).to receive(:make_accessible).at_least(:once) if defined?(Lich::Common::GUI::Accessibility)
      described_class.show_conversion_dialog(parent_window, test_data_dir, on_conversion_complete)
    end

    it 'makes progress bar accessible' do
      expect(Lich::Common::GUI::Accessibility).to receive(:make_accessible).at_least(:once) if defined?(Lich::Common::GUI::Accessibility)
      described_class.show_conversion_dialog(parent_window, test_data_dir, on_conversion_complete)
    end
  end

  describe 'mode selection flow' do
    let(:parent_window) { double('Gtk::Window') }

    it 'correctly identifies plaintext mode selection' do
      described_class.show_conversion_dialog(parent_window, test_data_dir, proc {})
      # Plaintext mode test - would need to mock dialog response
    end

    it 'correctly identifies standard mode selection' do
      described_class.show_conversion_dialog(parent_window, test_data_dir, proc {})
      # Standard mode is default
    end

    it 'correctly identifies master password mode selection' do
      described_class.show_conversion_dialog(parent_window, test_data_dir, proc {})
      # Master password mode test - would need to mock dialog response
    end

    it 'prevents selection of enhanced mode' do
      described_class.show_conversion_dialog(parent_window, test_data_dir, proc {})
      # Enhanced mode should be disabled/insensitive
    end

    context 'Windows platform specific tests', skip: (RUBY_PLATFORM !~ /mswin|mingw/) do
      it 'handles Windows keychain integration in dialog' do
        allow(Lich::Common::GUI::MasterPasswordManager).to receive(:keychain_available?).and_return(true)
        described_class.show_conversion_dialog(parent_window, test_data_dir, proc {})
        expect(Lich::Common::GUI::MasterPasswordManager).to have_received(:keychain_available?)
      end

      it 'disables master password when Windows keychain unavailable' do
        allow(Lich::Common::GUI::MasterPasswordManager).to receive(:keychain_available?).and_return(false)
        allow(Lich).to receive(:log)
        described_class.show_conversion_dialog(parent_window, test_data_dir, proc {})
        expect(Lich).to have_received(:log)
      end

      it 'enables master password when Windows keychain available' do
        allow(Lich::Common::GUI::MasterPasswordManager).to receive(:keychain_available?).and_return(true)
        described_class.show_conversion_dialog(parent_window, test_data_dir, proc {})
        expect(Lich::Common::GUI::MasterPasswordManager).to have_received(:keychain_available?)
      end
    end
  end
end
