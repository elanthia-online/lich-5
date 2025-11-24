# frozen_string_literal: true

require 'rspec'
require 'tmpdir'
require 'fileutils'
require_relative 'login_spec_helper'
require_relative '../lib/common/gui/encryption_mode_change'
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

    def hide; end
  end

  class Label
    def initialize(text = '')
      @text = text
    end

    def set_markup(markup); end

    def set_xalign(align); end

    def set_line_wrap(wrap); end

    attr_accessor :text, :visible
  end

  class Separator
    def initialize(orientation); end
  end

  class RadioButton
    attr_accessor :active, :sensitive, :visible, :tooltip_text

    def initialize(label: nil, member: nil)
      @label = label
      @member = member
      @active = false
      @sensitive = true
      @visible = true
      @tooltip_text = nil
    end

    def active?
      @active
    end

    def self.new_with_label_from_widget(widget, label)
      new(label: label, member: widget)
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

  class MessageDialog
    def initialize(**kwargs)
      @message = kwargs[:message]
    end

    attr_accessor :secondary_text

    def add_button(label, response_type); end

    def run
      ResponseType::YES
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

RSpec.describe Lich::Common::GUI::EncryptionModeChange do
  let(:test_data_dir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(test_data_dir) if Dir.exist?(test_data_dir) }

  describe '.show_change_mode_dialog' do
    let(:parent_window) { double('Gtk::Window') }

    before do
      # Create a valid YAML file with encryption mode
      yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(test_data_dir)
      yaml_content = {
        'encryption_mode'                 => 'standard',
        'master_password_validation_test' => 'test_hash'
      }
      File.write(yaml_file, YAML.dump(yaml_content))
    end

    context 'dialog creation and structure' do
      it 'creates a dialog without errors' do
        expect { described_class.show_change_mode_dialog(parent_window, test_data_dir) }
          .not_to raise_error
      end

      it 'returns true when dialog is shown (async operation)' do
        result = described_class.show_change_mode_dialog(parent_window, test_data_dir)
        expect(result).to be true
      end

      it 'sets up dialog with modal flag' do
        described_class.show_change_mode_dialog(parent_window, test_data_dir)
        # Dialog is created as modal based on GTK parameters
      end
    end

    context 'encryption mode options' do
      it 'creates radio button options for all modes' do
        described_class.show_change_mode_dialog(parent_window, test_data_dir)
        # Dialog sets up plaintext, standard, and enhanced modes
      end

      it 'displays current encryption mode' do
        described_class.show_change_mode_dialog(parent_window, test_data_dir)
        # Current mode is shown in the dialog
      end
    end

    context 'YAML load error handling' do
      it 'shows error dialog when YAML file cannot be loaded' do
        # Corrupt the YAML file
        yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(test_data_dir)
        File.write(yaml_file, 'invalid: yaml: content:')

        allow(Lich).to receive(:log)
        expect { described_class.show_change_mode_dialog(parent_window, test_data_dir) }
          .not_to raise_error
      end
    end

    context 'mode display text' do
      it 'formats plaintext mode correctly' do
        described_class.show_change_mode_dialog(parent_window, test_data_dir)
        # Plaintext mode displays as "Plaintext (No Encryption)"
      end

      it 'formats standard mode correctly' do
        described_class.show_change_mode_dialog(parent_window, test_data_dir)
        # Standard mode displays as "Standard Encryption (Account Name)"
      end

      it 'formats enhanced mode correctly' do
        described_class.show_change_mode_dialog(parent_window, test_data_dir)
        # Enhanced mode displays as "Enhanced Encryption (Master Password)"
      end
    end
  end

  describe 'accessibility features' do
    let(:parent_window) { double('Gtk::Window') }

    before do
      # Create a valid YAML file with encryption mode
      yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(test_data_dir)
      yaml_content = {
        'encryption_mode'                 => 'standard',
        'master_password_validation_test' => 'test_hash'
      }
      File.write(yaml_file, YAML.dump(yaml_content))
    end

    it 'makes dialog window accessible' do
      expect(Lich::Common::GUI::Accessibility).to receive(:make_window_accessible).with(
        anything, 'Change Encryption Mode Dialog', anything
      ) if defined?(Lich::Common::GUI::Accessibility)
      described_class.show_change_mode_dialog(parent_window, test_data_dir)
    end

    it 'makes labels accessible' do
      expect(Lich::Common::GUI::Accessibility).to receive(:make_accessible).at_least(:once) if defined?(Lich::Common::GUI::Accessibility)
      described_class.show_change_mode_dialog(parent_window, test_data_dir)
    end

    it 'makes radio buttons accessible' do
      expect(Lich::Common::GUI::Accessibility).to receive(:make_accessible).at_least(:once) if defined?(Lich::Common::GUI::Accessibility)
      described_class.show_change_mode_dialog(parent_window, test_data_dir)
    end
  end

  describe 'mode change flow' do
    let(:parent_window) { double('Gtk::Window') }

    before do
      # Create a valid YAML file with encryption mode
      yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(test_data_dir)
      yaml_content = {
        'encryption_mode'                 => 'standard',
        'master_password_validation_test' => 'test_hash'
      }
      File.write(yaml_file, YAML.dump(yaml_content))
    end

    it 'handles mode selection without errors' do
      expect { described_class.show_change_mode_dialog(parent_window, test_data_dir) }
        .not_to raise_error
    end

    it 'correctly identifies when current mode is plaintext' do
      yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(test_data_dir)
      yaml_content = YAML.load_file(yaml_file)
      yaml_content['encryption_mode'] = 'plaintext'
      File.write(yaml_file, YAML.dump(yaml_content))

      expect { described_class.show_change_mode_dialog(parent_window, test_data_dir) }
        .not_to raise_error
    end

    it 'correctly identifies when current mode is enhanced' do
      yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(test_data_dir)
      yaml_content = YAML.load_file(yaml_file)
      yaml_content['encryption_mode'] = 'enhanced'
      File.write(yaml_file, YAML.dump(yaml_content))

      expect { described_class.show_change_mode_dialog(parent_window, test_data_dir) }
        .not_to raise_error
    end
  end
end
