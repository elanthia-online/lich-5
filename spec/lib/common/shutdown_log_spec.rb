# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/shutdown_log'

RSpec.describe Lich::Common::ShutdownLog do
  before do
    described_class.flush_user_exit_summary!
    allow(Lich).to receive(:log)
  end

  after do
    described_class.flush_user_exit_summary!
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

  it 'summarizes clean user exits instead of emitting buffered routine info' do
    described_class.begin_user_exit_summary!
    described_class.info('shutdown requested reason=user_exit source=primary_frontend')
    described_class.info('orderly user shutdown finished')

    result = described_class.complete_user_exit_summary('user-initiated shutdown completed cleanly')

    expect(result).to be true
    expect(Lich).to have_received(:log).with('info: user-initiated shutdown completed cleanly')
    expect(Lich).not_to have_received(:log).with('info: shutdown requested reason=user_exit source=primary_frontend')
    expect(Lich).not_to have_received(:log).with('info: orderly user shutdown finished')
  end

  it 'does not emit a clean user-exit summary when summary mode was not started' do
    result = described_class.complete_user_exit_summary('user-initiated shutdown completed cleanly')

    expect(result).to be false
    expect(Lich).not_to have_received(:log).with('info: user-initiated shutdown completed cleanly')
  end

  it 'flushes buffered routine info before warning when clean summary is disqualified' do
    described_class.begin_user_exit_summary!
    described_class.info('shutdown requested reason=user_exit source=primary_frontend')
    described_class.warning('shutdown step Vars.save exceeded threshold')

    result = described_class.complete_user_exit_summary('user-initiated shutdown completed cleanly')

    expect(result).to be false
    expect(Lich).to have_received(:log).with('info: shutdown requested reason=user_exit source=primary_frontend').ordered
    expect(Lich).to have_received(:log).with('warning: shutdown step Vars.save exceeded threshold').ordered
    expect(Lich).not_to have_received(:log).with('info: user-initiated shutdown completed cleanly')
  end

  it 'flushes buffered routine info on request' do
    described_class.begin_user_exit_summary!
    described_class.info('shutdown requested reason=user_exit source=primary_frontend')

    described_class.flush_user_exit_summary!

    expect(Lich).to have_received(:log).with('info: shutdown requested reason=user_exit source=primary_frontend')
  end
end
