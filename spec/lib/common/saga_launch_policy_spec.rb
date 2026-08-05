# frozen_string_literal: true

require_relative '../../../lib/common/saga_launch_policy'

RSpec.describe Lich::Common::SagaLaunchPolicy do
  describe '.custom_launch_conflict?' do
    it 'rejects only a nonblank Custom Launch combined with Saga' do
      expect(described_class.custom_launch_conflict?(frontend: 'saga', custom_launch: '/opt/Saga')).to be(true)
      expect(described_class.custom_launch_conflict?(frontend: 'stormfront', custom_launch: '/opt/client')).to be(false)
      expect(described_class.custom_launch_conflict?(frontend: 'saga', custom_launch: '   ')).to be(false)
      expect(described_class.custom_launch_conflict?(frontend: 'saga', custom_launch: :__unset)).to be(false)
    end
  end
end
