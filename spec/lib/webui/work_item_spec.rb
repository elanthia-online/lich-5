# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui/work_item'

RSpec.describe Lich::WebUI::WorkItem do
  it 'cleans canceled work once without invoking its callback' do
    called = []
    disposed = []
    item = described_class.new(cleanup: -> { disposed << true }) { called << true }
    2.times { item.cancel }
    item.call
    expect(called).to be_empty
    expect(disposed).to eq([true])
  end

  it 'cleans raising work once and preserves the callback exception' do
    disposed = []
    item = described_class.new(cleanup: -> { disposed << true }) { raise IOError, 'synthetic failure' }
    expect { item.call }.to raise_error(IOError, 'synthetic failure')
    item.cancel
    item.call
    expect(disposed).to eq([true])
  end

  it 'leaves resources with the running callback when cancellation races execution' do
    started = Queue.new
    release = Queue.new
    disposed = []
    item = described_class.new(cleanup: -> { disposed << true }) { started << true; release.pop }
    worker = Thread.new { item.call }
    started.pop
    item.cancel
    item.call
    expect(disposed).to be_empty
    release << true
    worker.join
    expect(disposed).to eq([true])
  ensure
    release << true
    worker&.join
  end
end
