# frozen_string_literal: true

require_relative '../../../login_spec_helper'
require_relative '../../../../lib/common/gui/favorites_manager'

RSpec.describe Lich::Common::GUI::FavoritesManager do
  describe '.validate_and_cleanup_favorites' do
    it 'removes only an orphaned favorite with the exact Custom Launch identity' do
      plain_entry = {
        user_id: 'TESTACCOUNT',
        char_name: 'Tsetem',
        game_code: 'GS3',
        frontend: 'stormfront',
        custom_launch: nil
      }
      custom_favorite = plain_entry.merge(
        custom_launch: '/opt/warlock',
        favorite: true
      )

      allow(Lich::Common::Authentication::EntryStore)
        .to receive(:load_saved_entries).with('/saved', false).and_return([plain_entry])
      allow(described_class).to receive(:get_all_favorites).with('/saved').and_return([custom_favorite])
      allow(described_class).to receive(:remove_favorite).and_return(true)

      result = described_class.validate_and_cleanup_favorites('/saved')

      expect(result).to include(valid: true, cleaned: 1, remaining: 0)
      expect(described_class).to have_received(:remove_favorite).with(
        '/saved',
        'TESTACCOUNT',
        'Tsetem',
        'GS3',
        'stormfront',
        '/opt/warlock'
      )
    end
  end
end
