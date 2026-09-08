# frozen_string_literal: true

require_relative '../../../spec_helper'
require_relative '../../../login_spec_helper'

RSpec.describe Lich::Common::GUI::AccountManagerUI do
  describe 'changing a saved frontend' do
    let(:manager) { described_class.new('/saved') }
    let(:row) { ['TEST', 'Tester', 'GemStone IV', 'Wrayth', 'GS3', '', nil, 'stormfront'] }
    it 'does not allow editing an account header' do
      expect(Lich::Common::GUI::AccountManager).not_to receive(:update_launch_settings)
      manager.send(:commit_saved_launch, ['TEST'], frontend: 'profanity')
    end

    it 'saves the exact selected row and refreshes other launcher tabs' do
      expect(Lich::Common::GUI::AccountManager).to receive(:update_launch_settings)
        .with('/saved', 'TEST', 'Tester', 'GS3', old_frontend: 'stormfront',
              custom_launch: nil, frontend: 'profanity').and_return(true)
      expect(manager).to receive(:refresh_accounts_display)
      expect(manager).to receive(:notify_data_changed)
        .with(:character_updated, { account: 'TEST', character: 'Tester', game_code: 'GS3' })
      manager.send(:commit_saved_launch, row, frontend: 'profanity')
    end
  end

  it 'reads dropdown selections through their model, not an unbound GTK TreeIter' do
    manager = described_class.new('/saved')
    cell = double('combo renderer')
    column = double('column', resizable: nil, set_cell_data_func: nil)
    options = double('options')
    selected = double('GTK signal TreeIter without a Ruby model')
    row = ['TEST', 'Tester', 'GemStone IV', 'Wrayth', 'GS3', '', nil, 'stormfront']
    store = double('saved entries')
    view = double('view', append_column: nil)
    stub_const('Gtk::CellRendererCombo', Class.new)
    stub_const('Gtk::TreeViewColumn', Class.new)
    allow(Gtk::CellRendererCombo).to receive(:new).and_return(cell)
    allow(Gtk::TreeViewColumn).to receive(:new).and_return(column)
    %i[model= text_column= has_entry=].each { |setter| allow(cell).to receive(setter) }
    allow(column).to receive(:resizable=)
    callbacks = {}
    allow(cell).to receive(:signal_connect) { |signal, &block| callbacks[signal] = block }
    expect(options).to receive(:get_value).with(selected, 0).twice.and_return('profanity')
    expect(selected).not_to receive(:[])
    expect(store).to receive(:get_iter).with('0:0').twice.and_return(row)
    allow(manager).to receive(:commit_saved_launch)

    manager.send(:add_launch_choice_column, view, store, 'Frontend', 3, options, :frontend)
    callbacks.fetch('changed').call(cell, '0:0', selected)
    expect(manager).not_to have_received(:commit_saved_launch)
    callbacks.fetch('editing-canceled').call(cell)
    callbacks.fetch('edited').call(cell, '0:0', 'Profanity (external client)')
    expect(manager).not_to have_received(:commit_saved_launch)
    callbacks.fetch('changed').call(cell, '0:0', selected)
    callbacks.fetch('edited').call(cell, '0:0', 'Profanity (external client)')
    expect(manager).to have_received(:commit_saved_launch).with(row, { frontend: 'profanity' })
  end

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
