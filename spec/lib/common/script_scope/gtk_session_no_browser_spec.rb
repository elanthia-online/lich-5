# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'common/script_scope'

# --webui-no-browser in a game session: a script window is a URL the player
# opens where their browser is, told to them in the game window and the log,
# rather than a Chrome window on a display they cannot see.
RSpec.describe 'the GTK shim session under --webui-no-browser' do
  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('eloot') }
  let(:service) { Lich::WebUI::Service.new }
  let(:session) { gtk::Session.new(owner, service: service) }

  before do
    Lich::WebUI::Options.configure(open_browser: false)
    gtk::Session.browser_open = proc { |*| raise 'a browser must not be opened' }
  end

  after do
    gtk::Session.browser_open = nil
    Lich::WebUI::Options.reset!
    session.shutdown
    service.stop
  end

  it 'announces the launch URL instead of opening a browser' do
    page = service.registry.register(Lich::WebUI::Page.new(owner: owner, id: 'win', title: 'Loot Window') {})
    page.bind_runtime(service.runtime)
    messages = []
    allow(Lich::Messaging).to receive(:msg) { |type, message| messages << [type, message] } if defined?(Lich::Messaging)
    logged = []
    allow(Lich).to receive(:log) { |line| logged << line }

    expect(session.send(:open_browser, page)).to be(true)

    line = logged.find { |entry| entry.include?('Loot Window') }
    expect(line).to match(%r{open it at http://127\.0\.0\.1:#{service.server.port}/auth\?token=})
    expect(messages.first&.last).to include('open it at http://127.0.0.1:') if defined?(Lich::Messaging)
  end
end
