# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/shutdown_log'

RSpec.describe Lich::Common::ShutdownLog do
  before do
    allow(Lich).to receive(:log)
  end

  it 'formats always-on info, warning, and error messages' do
    described_class.info('shutdown requested')
    described_class.warning('timeout threshold exceeded')
    described_class.error('unexpected shutdown failure')

    expect(Lich).to have_received(:log).with('info: shutdown requested')
    expect(Lich).to have_received(:log).with('warning: timeout threshold exceeded')
    expect(Lich).to have_received(:log).with('error: unexpected shutdown failure')
  end

  it 'suppresses diagnostic messages by default' do
    described_class.debug('step finished in 0.001s')

    expect(Lich).not_to have_received(:log)
  end

  it 'logs diagnostic messages when --debug is active' do
    allow(ARGV).to receive(:include?).with('--debug').and_return(true)

    described_class.debug('step finished in 0.001s')

    expect(Lich).to have_received(:log).with('debug: step finished in 0.001s')
  end
end
