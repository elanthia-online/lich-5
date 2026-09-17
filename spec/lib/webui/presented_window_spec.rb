# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

# A script rendering its own page (the WebUI map) asked for keep-above and
# opacity through the presentation facility and got nothing: only the shim
# applied those to the real window, through the browser's Win32 handle.
# PresentedWindow is that path for any page.
RSpec.describe Lich::WebUI::PresentedWindow do
  let(:applied) { [] }
  let(:wishes) { { always_on_top: true, opacity: 0.5 } }
  let(:presentation) { -> { wishes } }

  before do
    allow(Lich::WebUI::WindowPresentation).to receive(:available?).and_return(true)
    allow(Lich::WebUI::WindowPresentation).to receive(:apply) { |hwnd, **options| applied << [hwnd, options]; true }
  end

  def opener_yielding(pid, opened: true)
    lambda do |_url, geometry:, on_start:|
      @geometry = geometry
      on_start.call(pid)
      opened
    end
  end

  it 'finds the browser window after the process starts and applies the presentation to it' do
    allow(Lich::WebUI::WindowPresentation).to receive(:discover).with(4242, title: nil).and_yield(77)

    window = described_class.open('http://127.0.0.1:1/', presentation: presentation,
                                                         geometry: { width: 400, height: 300 }, opener: opener_yielding(4242))

    expect(window).to be_presented
    expect(@geometry).to eq(width: 400, height: 300)
    expect(applied).to eq([[77, { always_on_top: true, opacity: 0.5, borderless: false }]])
  end

  it 're-applies the current wishes on apply, so a changed setting reaches the window' do
    allow(Lich::WebUI::WindowPresentation).to receive(:discover).and_yield(77)
    window = described_class.open('http://127.0.0.1:1/', presentation: presentation, opener: opener_yielding(1))
    wishes[:opacity] = 0.9
    wishes[:always_on_top] = false

    expect(window.apply).to be(true)
    expect(applied.last).to eq([77, { always_on_top: false, opacity: 0.9, borderless: false }])
  end

  it 'searches by the page title alongside the pid, for a page handed to an already-running browser' do
    allow(Lich::WebUI::WindowPresentation).to receive(:discover).with(1, title: 'Map: Nisugi').and_yield(31)

    window = described_class.open('http://127.0.0.1:1/', presentation: presentation, title: 'Map: Nisugi', opener: opener_yielding(1))

    expect(window).to be_presented
    expect(applied).to eq([[31, { always_on_top: true, opacity: 0.5, borderless: false }]])
  end

  it 'applies nothing when the pid owns no window, or the platform has no presentation, and is nil when no browser opened' do
    allow(Lich::WebUI::WindowPresentation).to receive(:discover).and_yield(nil)
    window = described_class.open('http://127.0.0.1:1/', presentation: presentation, opener: opener_yielding(1))
    expect(window).not_to be_presented
    expect(window.apply).to be(false)
    expect(applied).to be_empty

    allow(Lich::WebUI::WindowPresentation).to receive(:available?).and_return(false)
    expect(Lich::WebUI::WindowPresentation).not_to receive(:discover)
    described_class.open('http://127.0.0.1:1/', presentation: presentation, opener: opener_yielding(2))

    expect(described_class.open('http://127.0.0.1:1/', presentation: presentation, opener: opener_yielding(3, opened: false))).to be_nil
  end

  it 'is what Lich::WebUI.open returns when a presentation is given' do
    allow(Lich::WebUI::BrowserLauncher).to receive(:open) { |_url, on_start: nil, **| on_start&.call(9); true }
    allow(Lich::WebUI::WindowPresentation).to receive(:discover).and_yield(5)
    allow(Lich::WebUI).to receive(:launch_url).and_return('http://127.0.0.1:1/')

    plain = Lich::WebUI.open
    presented = Lich::WebUI.open(presentation: presentation)

    expect(plain).to be(true)
    expect(presented).to be_a(described_class)
    expect(presented).to be_presented
  end
end
