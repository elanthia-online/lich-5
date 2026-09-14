# frozen_string_literal: true

require_relative '../../../login_spec_helper'

RSpec.describe Lich::Common::GUI::GameSelection do
  let(:combo_class) do
    Class.new do
      attr_accessor :active
      attr_reader :items

      def initialize
        @items = []
      end

      def append_text(text)
        @items << text
      end

      def active_text
        @items[@active]
      end

      def remove_text(index)
        return false if @items.empty?

        @items.delete_at(index)
        true
      end
    end
  end

  before do
    stub_const('Gtk::ComboBoxText', combo_class)
    allow(Lich::Common::GUI::Accessibility).to receive(:make_combo_accessible)
  end

  it 'derives the complete GUI mapping from the canonical valid game codes' do
    expect(described_class::GAME_MAPPING).to eq(
      'GS3' => 'GemStone IV',
      'GST' => 'GemStone IV Prime Test',
      'GSF' => 'GemStone IV Shattered',
      'DR'  => 'DragonRealms',
      'DRX' => 'DragonRealms Platinum',
      'DRT' => 'DragonRealms Prime Test',
      'DRF' => 'DragonRealms Fallen'
    )
    expect(described_class::GAME_MAPPING.keys)
      .to eq(Lich::Common::Authentication::LoginHelpers::VALID_GAME_CODES)
  end

  it 'selects a canonical game code' do
    combo = described_class.create_game_selection_combo('GST')

    expect(combo.items).to eq(described_class::GAME_MAPPING.values)
    expect(combo.active_text).to eq('GemStone IV Prime Test')
  end

  it 'rejects a retired selection through the canonical validator' do
    expect(Lich::Common::Authentication::LoginHelpers)
      .to receive(:valid_game_code?).with('GSX').and_call_original

    combo = described_class.create_game_selection_combo('GSX')

    expect(combo.active_text).to eq('GemStone IV')
  end

  it 'validates the selected display value before returning its game code' do
    combo = combo_class.new
    combo.append_text('GemStone IV Shattered')
    combo.active = 0

    expect(described_class.get_selected_game_code(combo)).to eq('GSF')
    combo.items[0] = 'GemStone IV Platinum'
    expect(described_class.get_selected_game_code(combo)).to eq('GS3')
  end

  it 'returns names only for canonically valid game codes' do
    expect(described_class.get_game_name('DRF')).to eq('DragonRealms Fallen')
    expect(described_class.get_game_name('GSX')).to eq('Unknown')
  end

  it 'revalidates the current selection when refreshing a combo' do
    combo = combo_class.new
    combo.append_text('stale')

    described_class.update_game_selection_combo(combo, 'GSX')

    expect(combo.items).to eq(described_class::GAME_MAPPING.values)
    expect(combo.active_text).to eq('GemStone IV')
  end
end
