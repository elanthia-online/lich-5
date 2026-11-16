# frozen_string_literal: true

require_relative '../../spec_helper'
require 'timeout'
require 'webui/browser_window'

# A close requested while another thread is still starting the window (for
# example process-exit cleanup) must terminate the process once the start
# completes, not only report that a retry is needed.
RSpec.describe Lich::WebUI::BrowserWindow do
  let(:closes) { [] }
  let(:terminated) { [] }
  let(:entered) { Queue.new }
  let(:release) { Queue.new }
  let(:signal) { OS.windows? ? 'KILL' : 'TERM' }

  before do
    allow(Lich::WebUI::WindowPresentation).to receive(:available?).and_return(false)
  end

  def window(&opener)
    described_class.new(on_close: -> { closes << true }, opener: opener,
                        terminate: ->(*args) { terminated << args })
  end

  # Starts open on its own thread and returns once the opener is running.
  def start_opening(host_window)
    opening = Thread.new { host_window.open('unused') }
    Timeout.timeout(2) { entered.pop }
    opening
  end

  def wait_until_blocked(thread)
    Timeout.timeout(2) { sleep 0.005 until thread.status == 'sleep' }
  end

  it 'terminates the started process before a close requested mid-start returns' do
    host_window = window do |_url, on_start:, **|
      entered << true
      release.pop
      on_start.call(123)
      true
    end
    opening = start_opening(host_window)

    closing = Thread.new { [host_window.close, terminated.dup] }
    wait_until_blocked(closing)
    release << true

    expect(Timeout.timeout(2) { closing.value }).to eq([true, [[signal, 123]]])
    expect(Timeout.timeout(2) { opening.value }).to be(true)
    expect(terminated).to eq([[signal, 123]])
    expect(closes).to be_empty
  ensure
    release << true
    opening&.join(2)
    closing&.join(2)
  end

  it 'settles a close requested mid-start when the start then fails, without an unsolicited notice' do
    host_window = window do |*, **|
      entered << true
      release.pop
      false
    end
    opening = start_opening(host_window)

    closing = Thread.new { host_window.close }
    wait_until_blocked(closing)
    release << true

    expect(Timeout.timeout(2) { closing.value }).to be(true)
    expect(Timeout.timeout(2) { opening.value }).to be(false)
    expect(host_window).to be_closed
    expect(closes).to be_empty
    expect(terminated).to be_empty
  ensure
    release << true
    opening&.join(2)
    closing&.join(2)
  end

  it 'leaves the close pending past the settle bound and terminates when the start completes' do
    stub_const("#{described_class}::START_SETTLE_SECONDS", 0.05)
    host_window = window do |_url, on_start:, **|
      entered << true
      release.pop
      on_start.call(456)
      true
    end
    opening = start_opening(host_window)

    expect(Timeout.timeout(2) { host_window.close }).to be(false)
    expect(terminated).to be_empty
    release << true

    expect(Timeout.timeout(2) { opening.value }).to be(true)
    expect(terminated).to eq([[signal, 456]])
  ensure
    release << true
    opening&.join(2)
  end

  it 'does not wait when the opener itself requests closure' do
    stub_const("#{described_class}::START_SETTLE_SECONDS", 30)
    host_window = nil
    host_window = window do |_url, on_start:, **|
      on_start.call(789)
      host_window.close
      true
    end

    expect(Timeout.timeout(2) { host_window.open('unused') }).to be(true)
    expect(terminated).to eq([[signal, 789]])
  end
end
