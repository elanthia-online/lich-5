# frozen_string_literal: true

require 'rspec'
require 'webui'
require 'timeout'

RSpec.describe 'owned WebUI shutdown' do
  before do
    allow(Lich::WebUI::WindowPresentation).to receive(:available?).and_return(false)
  end

  [true, false].each do |windows|
    it "uses #{windows ? 'KILL' : 'TERM'} only for its owned PID" do
      allow(OS).to receive(:windows?).and_return(windows)
      calls = []
      window = Lich::WebUI::BrowserWindow.new(
        on_close: proc {}, terminate: ->(*args) { calls << args },
        opener: ->(_url, **callbacks) { callbacks[:on_start].call(123); true }
      )
      window.open('unused')
      2.times { window.close }
      expect(calls).to eq([[windows ? 'KILL' : 'TERM', 123]])
    end
  end

  def host(failures:)
    spawned = 0
    calls = []
    service = Lich::WebUI::Service.new(
      logger: proc { |*| },
      browser_open: ->(_url, **callbacks) { spawned += 1; callbacks[:on_start].call(spawned); true },
      browser_terminate: lambda { |signal, pid|
        calls << [signal, pid]
        raise Errno::EINVAL if failures.include?(pid)
      }
    )
    service.start
    pages = 2.times.map do |index|
      page = service.registry.register(Lich::WebUI::Page.new(owner: Object.new, id: "p#{index}", title: 'Test') {})
      page.bind_runtime(service.runtime)
      service.refresh(page)
      service.open(page)
      page
    end
    [service, pages, calls]
  end

  it 'does not spawn a window whose closure preceded open' do
    opener = double('opener')
    expect(opener).not_to receive(:call)
    window = Lich::WebUI::BrowserWindow.new(on_close: proc {}, opener: opener)
    expect(window.close).to be(true)
    expect(window.open('unused')).to be(false)
  end

  [:page, :reset].each do |closure|
    it "retains a failed late PID after #{closure} closes during startup" do
      allow(OS).to receive(:windows?).and_return(true)
      entered, release = Queue.new, Queue.new
      failing = true
      monitored = false
      calls = []
      service = Lich::WebUI::Service.new(
        logger: proc { |*| },
        browser_open: lambda { |_url, **callbacks|
          Thread.current.report_on_exception = false
          entered << true
          release.pop
          callbacks[:on_start].call(123)
          monitored = true
          true
        },
        browser_terminate: lambda { |signal, pid|
          expect(monitored).to be(true), 'termination must not prevent installation of the exit monitor'
          calls << [signal, pid]
          raise Errno::EPERM if failing
        }
      )
      service.start
      page = service.registry.register(Lich::WebUI::Page.new(owner: Object.new, id: 'late', title: 'Late') {})
      page.bind_runtime(service.runtime)
      service.refresh(page)
      Lich::WebUI.service = service
      opening = Thread.new do
        service.open(page)
      rescue Errno::EPERM
        :termination_failed
      end
      Timeout.timeout(2) { entered.pop }
      closure == :page ? service.runtime.close_page(page) : Lich::WebUI.reset!
      expect(service.pending_windows?).to be(true)
      release << true
      expect(Timeout.timeout(2) { opening.value }).to eq(:termination_failed)
      expect(service.window_host(page)).not_to be_nil
      expect(calls).to all(eq(['KILL', 123]))
      before_retry = calls.size
      failing = false
      Lich::WebUI.reset!
      expect(calls.size).to eq(before_retry + 1)
      expect(service.pending_windows?).to be(false)
    ensure
      release << true if release
      opening&.join(2)
      failing = false
      service&.stop
      Lich::WebUI.reset!
    end
  end

  it 'retains failed page termination, finishes page disposal, and retries at stop' do
    failures = [1]
    service, pages, calls = host(failures: failures)
    service.runtime.close_page(pages.first)
    expect(service.registry.pages).not_to include(pages.first)
    expect(service.window_host(pages.first)).not_to be_nil
    service.stop
    expect(calls.map(&:last)).to eq([1, 1, 2])
    expect(service.server).not_to be_running
    expect(service.pending_windows?).to be(true)
    failures.clear
    service.stop
    expect(calls.map(&:last)).to eq([1, 1, 2, 1])
    expect(service.pending_windows?).to be(false)
  ensure
    failures&.clear
    service&.stop
  end

  it 'continues owner teardown after one termination fails' do
    failures = [1]
    service, pages, calls = host(failures: failures)
    pages.each { |page| service.terminate_owner(page.owner) }
    expect(service.registry.pages).to be_empty
    expect(calls.map(&:last)).to eq([1, 2])
    expect(service.window_host(pages.first)).not_to be_nil
  ensure
    failures&.clear
    service&.stop
  end

  it 'retries failed windows across reset without constructing a replacement service' do
    failures = [1]
    service, _, calls = host(failures: failures)
    Lich::WebUI.service = service
    Lich::WebUI.reset!
    expect(service.pending_windows?).to be(true)
    failures.clear
    expect(Lich::WebUI::Service).not_to receive(:new)
    2.times { Lich::WebUI.reset! }
    expect(calls.map(&:last)).to eq([1, 2, 1])
    expect(service.pending_windows?).to be(false)
  ensure
    failures&.clear
    Lich::WebUI.reset!
  end

  it 'shuts the runtime down even when listener shutdown raises' do
    service = Lich::WebUI::Service.new
    allow(service.server).to receive(:stop).and_raise(IOError)
    expect(service.runtime).to receive(:shutdown)
    expect { service.stop }.to raise_error(IOError)
  end
end
