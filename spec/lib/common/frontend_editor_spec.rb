# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/frontend_editor'

# The rules for editing frontend configuration, with no toolkit attached.
# GUI::FrontendManagerTab grew these around Gtk::Entry instances, so the WebUI
# launcher could not reach them without duplicating the validation.
RSpec.describe Lich::Common::FrontendEditor do
  let(:catalog) do
    Class.new do
      def self.built_in_frontends = %w[stormfront wizard]
      def self.registered_frontends = %w[stormfront wizard vellum]
      def self.display_name(id) = id == 'stormfront' ? 'Wrayth' : id.capitalize
      def self.capability_vocabulary = %i[xml dialogs]

      def self.definition_for(id)
        { capabilities: id == 'stormfront' ? %i[xml dialogs] : [] }
      end
    end
  end

  let(:locator) do
    resolution = Struct.new(:executable_path, :source)
    Class.new do
      define_singleton_method(:resolve) do |id|
        resolution.new('C:/games/Wrayth.exe', :detected) if id == 'stormfront'
      end
    end
  end

  let(:settings) do
    document = {
      'builtins' => { 'stormfront' => { 'executable' => 'C:/override/Wrayth.exe' } },
      'custom'   => {
        'vellum' => {
          'label' => 'Vellum', 'command' => 'C:/vellum/vellum-fe.exe',
          'directory' => 'C:/vellum', 'arguments' => ['--frontend', 'gui'],
          'capabilities' => ['xml']
        }
      }
    }
    Class.new do
      define_singleton_method(:current) { document }
    end
  end

  def rows
    described_class.rows(settings: settings, frontend: catalog, locator: locator)
  end

  describe '.rows' do
    it 'lists every registered frontend, built-ins first in catalog order' do
      expect(rows.map { |row| row[:id] }).to eq(%w[stormfront wizard vellum])
      expect(rows.map { |row| row[:type] }).to eq(['Built-in', 'Built-in', 'Custom'])
    end

    # Detection annotates a row; it never removes one. A custom frontend is
    # reachable only because the player gave it a command, so discovery can
    # never find it and it is always "Configured".
    it 'reports what is configured, detected and merely known about' do
      expect(rows.map { |row| row[:status] }).to eq(%w[Detected Unavailable Configured])
    end

    it 'shows the override in preference to what discovery found' do
      expect(rows.first[:launch]).to eq('C:/override/Wrayth.exe')
    end

    it 'shows arguments back in the shell quoting they were entered with' do
      expect(rows.last[:arguments]).to eq('--frontend gui')
    end
  end

  describe '.editor_fields' do
    it 'marks a built-in and offers what discovery found alongside the override' do
      fields = described_class.editor_fields('stormfront', settings: settings, frontend: catalog, locator: locator)

      expect(fields).to include(id: 'stormfront', label: 'Wrayth', built_in: true,
                                command: 'C:/override/Wrayth.exe',
                                detected_command: 'C:/games/Wrayth.exe')
    end

    # A built-in's protocol capabilities belong to the catalog, not the player.
    # They are shown so the editor says what the frontend speaks and disabled
    # so it cannot be claimed otherwise; reporting none made every built-in
    # look like it spoke nothing.
    it 'reports the capabilities the catalog declares for a built-in' do
      fields = described_class.editor_fields('stormfront', settings: settings, frontend: catalog, locator: locator)

      expect(fields[:capabilities]).to eq(%w[xml dialogs])
    end

    it 'returns a custom frontend whole' do
      fields = described_class.editor_fields('vellum', settings: settings, frontend: catalog, locator: locator)

      expect(fields).to include(id: 'vellum', label: 'Vellum', built_in: false,
                                command: 'C:/vellum/vellum-fe.exe', directory: 'C:/vellum',
                                arguments: '--frontend gui', capabilities: ['xml'])
    end
  end

  describe '.apply' do
    def apply(fields, creating:)
      described_class.apply(settings.current, fields, creating: creating, frontend: catalog)
    end

    it 'creates a custom frontend under a normalized id' do
      _builtins, custom, id = apply(
        { id: '  Vellum-Two  ', label: 'Vellum Two', command: 'C:/v/two.exe',
          directory: '', arguments: '--flag "two words"', capabilities: ['xml'] },
        creating: true
      )

      expect(id).to eq('vellum-two')
      expect(custom[id]).to eq('label' => 'Vellum Two', 'command' => 'C:/v/two.exe',
                               'arguments' => ['--flag', 'two words'], 'capabilities' => ['xml'])
    end

    it 'refuses an id another frontend already answers to' do
      expect { apply({ id: 'vellum', label: 'x', command: 'y', arguments: '' }, creating: true) }
        .to raise_error(ArgumentError, /already in use/)
    end

    it 'refuses an id the settings file could not hold' do
      expect { apply({ id: 'Has Spaces!', label: 'x', command: 'y', arguments: '' }, creating: true) }
        .to raise_error(ArgumentError, /1-64 lowercase/)
    end

    it 'requires a label and a command for a custom frontend' do
      expect { apply({ id: 'newfe', label: '', command: 'y', arguments: '' }, creating: true) }
        .to raise_error(ArgumentError, 'Label is required.')
      expect { apply({ id: 'newfe', label: 'x', command: '', arguments: '' }, creating: true) }
        .to raise_error(ArgumentError, 'Command is required.')
    end

    # A built-in keeps its identity; only the launch override is the player's.
    it 'persists only the override fields for a built-in' do
      builtins, = apply({ id: 'stormfront', command: 'C:/new/Wrayth.exe', arguments: '--a' }, creating: false)

      expect(builtins['stormfront']).to eq('executable' => 'C:/new/Wrayth.exe', 'arguments' => ['--a'])
    end

    # Otherwise frontends.yml accumulates empty entries that shadow the catalog.
    it 'drops a built-in entry once both override fields are cleared' do
      builtins, = apply({ id: 'stormfront', command: '  ', arguments: '' }, creating: false)

      expect(builtins).not_to have_key('stormfront')
    end

    it 'refuses to edit a custom frontend that has since been removed' do
      expect { apply({ id: 'ghost', label: 'x', command: 'y', arguments: '' }, creating: false) }
        .to raise_error(ArgumentError, /no longer exists/)
    end
  end

  describe '.remove' do
    it 'removes a custom frontend' do
      _builtins, custom = described_class.remove(settings.current, 'vellum', frontend: catalog)

      expect(custom).not_to have_key('vellum')
    end

    it 'refuses to remove a built-in' do
      expect { described_class.remove(settings.current, 'stormfront', frontend: catalog) }
        .to raise_error(ArgumentError, 'Built-in frontends cannot be deleted.')
    end
  end

  describe '.parse_arguments' do
    it 'splits on shell quoting rather than whitespace' do
      expect(described_class.parse_arguments('--flag "two words" -x')).to eq(['--flag', 'two words', '-x'])
    end

    it 'names unbalanced quoting as an argument problem' do
      expect { described_class.parse_arguments('--flag "unterminated') }
        .to raise_error(ArgumentError, /Additional arguments are invalid/)
    end

    it 'treats a blank field as no arguments' do
      expect(described_class.parse_arguments('   ')).to eq([])
    end
  end

  describe '.optional_scalar' do
    it 'refuses control characters, which the settings file cannot carry' do
      expect { described_class.optional_scalar('Label', "a\tb") }
        .to raise_error(ArgumentError, /control characters/)
    end

    it 'reads a blank field as absent rather than empty' do
      expect(described_class.optional_scalar('Working directory', '  ')).to be_nil
    end
  end
end
