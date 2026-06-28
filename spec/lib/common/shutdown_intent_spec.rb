# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/shutdown_intent'

RSpec.describe Lich::Common::ShutdownIntent do
  describe '.user_exit_command?' do
    it 'accepts explicit frontend exit commands' do
      expect(described_class.user_exit_command?('exit')).to be true
      expect(described_class.user_exit_command?('quit')).to be true
      expect(described_class.user_exit_command?('<c>exit')).to be true
      expect(described_class.user_exit_command?("  <c>QUIT  \r\n")).to be true
    end

    it 'rejects lich commands and non-exit input' do
      expect(described_class.user_exit_command?(';exit')).to be false
      expect(described_class.user_exit_command?('exit now')).to be false
      expect(described_class.user_exit_command?('[script]><c>exit')).to be false
      expect(described_class.user_exit_command?(nil)).to be false
    end
  end
end
