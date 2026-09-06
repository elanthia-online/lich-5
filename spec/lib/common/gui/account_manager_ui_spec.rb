# frozen_string_literal: true

require_relative '../../../spec_helper'
require_relative '../../../login_spec_helper'

RSpec.describe Lich::Common::GUI::AccountManagerUI do
  let(:row_class) do
    Class.new do
      attr_reader :parent, :values

      def initialize(parent)
        @parent = parent
        @values = {}
      end

      def [](column)
        @values[column]
      end

      def []=(column, value)
        @values[column] = value
      end
    end
  end

  let(:store_class) do
    row_type = row_class
    Class.new do
      attr_reader :rows

      define_method(:initialize) do
        @rows = []
      end

      define_method(:clear) do
        @rows.clear
      end

      define_method(:append) do |parent|
        row = row_type.new(parent)
        @rows << row
        row
      end
    end
  end

  it 'stores the frontend identifier separately from its presentation label' do
    characters = [
      {
        char_name: 'Tsetem',
        game_name: 'GemStone IV',
        game_code: 'GS3',
        frontend: 'velvet-web',
        custom_launch: nil
      },
      {
        char_name: 'Pickasso',
        game_name: 'GemStone IV',
        game_code: 'GS3',
        frontend: 'velvet-web',
        custom_launch: '/opt/velvet --connect'
      }
    ]
    allow(Lich::Common::GUI::AccountManager).to receive(:get_all_accounts)
      .with('/saved').and_return('TESTACCOUNT' => characters)
    allow(Lich::Common::GUI::FavoritesManager).to receive(:is_favorite?).and_return(false)
    allow(Lich::Common::Frontend).to receive(:display_name)
      .with('velvet-web').and_return('Velvet Web')

    store = store_class.new
    described_class.new('/saved').send(:populate_accounts_view, store)
    calvix_row, rabki_row = store.rows.drop(1)

    expect(calvix_row[3]).to eq('Velvet Web')
    expect(rabki_row[3]).to eq('Custom')
    expect(calvix_row[described_class::FRONTEND_ID_COLUMN]).to eq('velvet-web')
    expect(rabki_row[described_class::FRONTEND_ID_COLUMN]).to eq('velvet-web')
  end
end
