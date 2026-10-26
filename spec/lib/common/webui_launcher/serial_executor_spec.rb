# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'common/webui_launcher/serial_executor'
require 'timeout'

RSpec.describe Lich::Common::WebUILauncher::SerialExecutor do
  it 'cancels queued and refused work, while letting the running callback finish' do
    executor = described_class.new
    started = Queue.new
    release = Queue.new
    called = []
    disposed = []
    executor.post(cleanup: -> { disposed << :running }) { started << true; release.pop; called << :running }
    Timeout.timeout(2) { started.pop }
    executor.post(cleanup: -> { disposed << :queued }) { called << :queued }
    executor.stop(wait: false)
    expect(executor.post(cleanup: -> { disposed << :refused }) { called << :refused }).to be(false)
    expect(disposed).to contain_exactly(:queued, :refused)
    release << true
    executor.stop
    expect(called).to eq([:running])
    expect(disposed).to contain_exactly(:running, :queued, :refused)
  ensure
    release << true
    executor&.stop
  end

  it 'cleans a failing callback and continues processing subsequent work' do
    executor = described_class.new
    disposed = Queue.new
    delivered = Queue.new
    executor.post(cleanup: -> { disposed << true }) { raise IOError, 'synthetic-secret' }
    executor.post { delivered << true }
    expect(Timeout.timeout(2) { disposed.pop }).to be(true)
    expect(Timeout.timeout(2) { delivered.pop }).to be(true)
  ensure
    executor&.stop
  end
end
