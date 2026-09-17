# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/frontend_choices'

# Which frontends a player may pick, and what is known about each. Both
# launchers need the same answer; only one of them can build a dropdown.
RSpec.describe Lich::Common::FrontendChoices do
  # A catalog holding one built-in that discovery can find, one it cannot,
  # and a custom frontend the player configured with a launch command.
  let(:catalog) do
    Class.new do
      def self.platform_key = :mingw

      def self.canonical_name(id)
        id.to_s == 'wrayth' ? 'stormfront' : id.to_s
      end

      def self.definitions(gui_selectable: nil)
        raise 'expected gui_selectable' unless gui_selectable

        [
          { id: 'saga', metadata: { display_name: 'Saga' } },
          { id: 'stormfront', metadata: { display_name: 'Wrayth' } },
          { id: 'wizard', metadata: { display_name: 'Wizard' } },
          { id: 'vellum',
            metadata: { display_name: 'Vellum', launcher_adapter: :custom,
                        launch_command: 'C:/vellum/vellum-fe.exe --frontend gui' } },
          { id: 'mac_only', metadata: { display_name: 'MacOnly', gui_platforms: [:darwin] } },
        ]
      end
    end
  end

  let(:locator) do
    resolution = Struct.new(:frontend_id)
    Class.new do
      define_singleton_method(:available) do |gui_selectable:, refresh:|
        raise 'expected gui_selectable' unless gui_selectable
        raise 'expected a refresh flag' unless [true, false].include?(refresh)

        [resolution.new('stormfront'), resolution.new('saga')]
      end
    end
  end

  def choices
    described_class.all(refresh: false, locator: locator, frontend: catalog)
  end

  it 'pins the historical GUI default first and keeps catalog order after it' do
    expect(choices.map(&:id)).to eq(%w[stormfront saga wizard vellum])
  end

  it 'drops a frontend this platform cannot run' do
    expect(choices.map(&:id)).not_to include('mac_only')
  end

  it 'marks what discovery actually found as detected' do
    detected = choices.select { |choice| choice.state == :detected }

    expect(detected.map(&:id)).to contain_exactly('stormfront', 'saga')
    expect(detected.first.label).to eq('Wrayth (detected)')
  end

  # The bug this module exists for. A custom frontend has no registry entry,
  # no macOS bundle id and no conventional path, so FrontendLocator#available
  # can never return one -- it is only ever reachable because the player gave
  # it a launch command. A launcher that lists discovery results alone can
  # therefore never offer it, however carefully it was configured.
  it 'offers a configured custom frontend that discovery cannot possibly find' do
    vellum = choices.find { |choice| choice.id == 'vellum' }

    expect(vellum).not_to be_nil
    expect(vellum.state).to eq(:configured)
    expect(vellum.label).to eq('Vellum (configured)')
    expect(vellum).to be_available
  end

  it 'still offers a frontend nothing could find, saying so' do
    wizard = choices.find { |choice| choice.id == 'wizard' }

    expect(wizard.state).to eq(:unavailable)
    expect(wizard.label).to eq('Wizard (unavailable)')
    expect(wizard).not_to be_available
  end

  # Discovery annotates a choice; it never removes one. A locator that cannot
  # run at all leaves every frontend selectable rather than emptying the list
  # and stranding the player with nothing to pick.
  it 'keeps every choice when discovery itself fails' do
    broken = Class.new do
      def self.available(gui_selectable:, refresh:)
        raise IOError, "discovery exploded #{gui_selectable} #{refresh}"
      end
    end

    result = described_class.all(refresh: false, locator: broken, frontend: catalog)

    expect(result.map(&:id)).to eq(%w[stormfront saga wizard vellum])
    expect(result.find { |choice| choice.id == 'vellum' }.state).to eq(:configured)
  end

  describe '.selectable?' do
    it 'resolves an alias to the frontend it names' do
      expect(described_class.selectable?('wrayth', refresh: false, locator: locator, frontend: catalog)).to be(true)
    end

    it 'refuses a frontend nobody has heard of, and a blank one' do
      expect(described_class.selectable?('nonsense', refresh: false, locator: locator, frontend: catalog)).to be(false)
      expect(described_class.selectable?('', refresh: false, locator: locator, frontend: catalog)).to be(false)
    end
  end

  describe '.options' do
    it 'renders as plain hashes a contract can carry' do
      option = described_class.options(refresh: false, locator: locator, frontend: catalog).first

      expect(option).to eq(id: 'stormfront', label: 'Wrayth (detected)',
                           state: 'detected', display_name: 'Wrayth')
    end
  end
end
