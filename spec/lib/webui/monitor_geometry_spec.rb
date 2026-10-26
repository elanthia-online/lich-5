# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/webui'

RSpec.describe Lich::WebUI::MonitorGeometry do
  let(:left) { { x: -1280, y: -100, width: 1280, height: 800, primary: false, active: true } }
  let(:right) { { x: 0, y: 0, width: 1920, height: 1080, primary: true, active: false } }
  let(:snapshot) { { source: 'native', screens: [right, left] } }

  it 'selects active, primary and signed point rectangles and marks fallback explicitly' do
    expect(described_class.select(snapshot)).to include(x: -1280, y: -100, fallback: false)
    expect(described_class.select(snapshot, target: :primary)).to include(x: 0, width: 1920, fallback: false)
    expect(described_class.select(snapshot, target: :point, point: [-1, 0])).to include(x: -1280, fallback: false)
    expect(described_class.select(snapshot, target: :point, point: [0, 0])).to include(x: 0, fallback: false)
    expect(described_class.select(snapshot, target: :point, point: [5000, 0])).to include(x: -1280, fallback: true)
    expect(described_class.select(nil)).to eq(source: 'unavailable', fallback: true)
  end

  it 'rejects malformed and excessive snapshots and requests without inventing a screen' do
    [nil, {}, { source: 'native', screens: [left.merge(width: 0)] },
     { source: 'native', screens: [left] * 33 }, { source: 'native', screens: [left.merge(x: Float::INFINITY)] }].each do |bad|
      expect(described_class.select(bad)).to eq(source: 'unavailable', fallback: true)
    end
    expect { described_class.select(snapshot, target: :device) }.to raise_error(ArgumentError)
    expect { described_class.select(snapshot, target: :point, point: ['1', 2]) }.to raise_error(ArgumentError)
  end

  it 'normalizes macOS and Windows provider output and reports provider failures' do
    provider = described_class.new
    allow(OS).to receive(:mac?).and_return(true)
    allow(provider).to receive(:run).with([Lich::WebUI::NativeHost::EXECUTABLE, '--monitors']).and_return(JSON.generate(snapshot))
    expect(provider.snapshot).to eq(snapshot)
    allow(OS).to receive(:mac?).and_return(false)
    allow(OS).to receive(:windows?).and_return(true)
    allow(provider).to receive(:run).with(['powershell.exe', '-NoProfile', '-NonInteractive', '-Command', described_class::WINDOWS_QUERY]).and_return(JSON.generate(snapshot))
    expect(provider.snapshot).to eq(snapshot)
    allow(provider).to receive(:run).and_raise(Errno::ENOENT)
    expect(provider.snapshot).to eq(described_class::UNAVAILABLE)
  end

  it 'parses optional XRandR signed topology without pretending it identifies the active window' do
    provider = described_class.new
    allow(OS).to receive(:mac?).and_return(false)
    allow(OS).to receive(:windows?).and_return(false)
    allow(provider).to receive(:run).with(['xrandr', '--listactivemonitors']).and_return("Monitors: 2\n 0: +*DP-1 1920/500x1080/300+0+0 DP-1\n 1: +HDMI-1 1280/300x800/200-1280-100 HDMI-1\n")
    expect(provider.snapshot[:screens].last).to eq(left.merge(active: false))
    expect(described_class.select(provider.snapshot)).to include(fallback: true)
  end

  it 'isolates viewer observations by owner and clears them on retirement' do
    service = Lich::WebUI::Service.new
    first, second = Object.new, Object.new
    page = Lich::WebUI::Page.new(owner: first, id: 'a', title: 'A') { text 'hello' }
    service.registry.register(page)
    page.observe_monitors('viewer-a', snapshot)
    page.observe_monitors('viewer-b', { source: 'browser', screens: [right.merge(active: true, primary: false)] })
    expect(service.monitor_geometry(owner: first, viewer: 'viewer-a')).to include(x: -1280)
    expect(service.monitor_geometry(owner: first, viewer: 'viewer-b')).to include(x: 0, source: 'browser')
    expect(service.monitor_geometry(owner: second, viewer: 'viewer-a')).to include(source: 'unavailable')
    page.forget_monitors('viewer-a')
    expect(service.monitor_geometry(owner: first, viewer: 'viewer-a')).to include(source: 'unavailable')
  ensure
    service&.stop
  end
end
