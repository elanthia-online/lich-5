# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../support/webui_fresh_process'
require 'webui/work_item'

RSpec.describe Lich::WebUI::WorkItem do
  include WebUIFreshProcess

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
  it 'reports cleanup failure separately without masking work failure or leaking error text' do
    messages = []
    item = described_class.new(cleanup: -> { raise IOError, 'private cleanup value' },
                               logger: ->(*entry) { messages << entry }) { raise ArgumentError, 'primary' }
    expect { item.call }.to raise_error(ArgumentError, 'primary')
    expect(messages).to eq([[:error, 'WebUI callback cleanup failed error=IOError']])
    item.cancel
    expect(messages.length).to eq(1)
  end

  it 'isolates cleanup and diagnostic failures after successful work' do
    item = described_class.new(cleanup: -> { raise IOError }, logger: ->(*) { raise IOError }) { :result }
    expect(item.call).to eq(:result)
    expect { item.cancel }.not_to raise_error
  end

  it 'preserves the primary error when cleanup raises a contained script exception' do
    messages = []
    item = described_class.new(cleanup: -> { raise ScriptError, 'private script text' },
                               logger: ->(*entry) { messages << entry }) { raise ArgumentError, 'primary' }
    expect { item.call }.to raise_error(ArgumentError, 'primary')
    expect(messages).to eq([[:error, 'WebUI callback cleanup failed error=ScriptError']])
  end

  it 'contains a raising cleanup when required alone in a fresh Ruby process' do
    code = <<~RUBY_CODE
      require 'webui/work_item'
      messages = []
      item = Lich::WebUI::WorkItem.new(cleanup: -> { raise IOError, 'synthetic' },
                                       logger: ->(*entry) { messages << entry }) { :result }
      abort "unexpected result" unless item.call == :result
      abort "not contained: \#{messages.inspect}" unless messages == [[:error, 'WebUI callback cleanup failed error=IOError']]
      puts 'ready'
    RUBY_CODE
    output, errors, status = run_ruby_with_deadline(code)
    expect_child_within_deadline(status, output, errors, 'fresh-process work item example')
    expect(status.success?).to be(true), errors
    expect(output).to eq("ready\n")
  end
end
