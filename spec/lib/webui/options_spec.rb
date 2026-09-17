# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

# Remote play: a player whose browser is not on the machine running Lich
# forwards the loopback port and opens the launch URL there. Two settings
# make that workable, a port known ahead of time and the URL surfaced
# instead of a window; the server itself stays on loopback.
RSpec.describe Lich::WebUI::Options do
  after { described_class.reset! }

  it 'defaults to an ephemeral port and a browser window on this machine' do
    expect(described_class.port).to eq(0)
    expect(described_class.open_browser?).to be(true)
  end

  it 'takes a fixed port and a no-browser choice, and leaves the rest alone' do
    described_class.configure(port: 4321)
    expect(described_class.port).to eq(4321)
    expect(described_class.open_browser?).to be(true)

    described_class.configure(open_browser: false)
    expect(described_class.port).to eq(4321)
    expect(described_class.open_browser?).to be(false)

    # nil means "not given", which is how main.rb passes an absent flag.
    described_class.configure(port: nil, open_browser: nil)
    expect(described_class.port).to eq(4321)
    expect(described_class.open_browser?).to be(false)
  end

  it 'is what the process-wide service binds with, and what Lich::WebUI answers for' do
    Lich::WebUI.reset!
    Lich::WebUI.configure(port: 0, open_browser: false)
    server = TCPServer.new('127.0.0.1', 0)
    port = server.addr[1]
    server.close
    Lich::WebUI.configure(port: port)

    service = Lich::WebUI.service
    service.start
    expect(service.server.host).to eq('127.0.0.1')
    expect(service.server.port).to eq(port)
    expect(Lich::WebUI.open_browser?).to be(false)
  ensure
    Lich::WebUI.reset!
  end
end
