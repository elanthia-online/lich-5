# frozen_string_literal: true

require 'rspec'
require 'stringio'

module Lich; end

module Lich
  def self.log(_msg); end
end unless Lich.respond_to?(:log)

require_relative '../../../lib/common/front-end'

# main.rb runs at load time, so (as in fe_version_spec.rb) the handshake
# forward of the proxy's generic front-end branch is lifted out of the
# shipping source and evaluated in a harness. The specs run the real code.
LIB_MAIN_DIR = File.expand_path('../../../lib/main', __dir__) unless defined?(LIB_MAIN_DIR)

RSpec.describe 'proxied front-end handshake (main.rb)' do
  main_source = File.read(File.join(LIB_MAIN_DIR, 'main.rb'))
  forward_block = main_source[/^        unless \$offline_mode\n.*?^        end\n/m]
  raise 'could not extract the proxied handshake forward from main.rb' unless forward_block

  harness_class = Class.new do
    def initialize(argv_options, launcher_cmd)
      @argv_options = argv_options
      @launcher_cmd = launcher_cmd
    end

    define_method(:run_forward) do
      launcher_cmd = @launcher_cmd # read by the eval'd main.rb source
      eval(forward_block, binding, 'main.rb')
    end
  end

  # Login key, then each front end's handshake line, byte-for-byte from its source.
  let(:genie)     { "0123abcd\nFE:WRAYTH /VERSION:1.0.1.22 /P:WIN_UNKNOWN /XML\n" } # Genie4 Core/Game.cs
  let(:frostbite) { "<c>0123abcd\r\n<c>/FE:STORMFRONT /VERSION:1.0.1.26 /P:WIN_UNKNOWN /XML\r\n" } # Frostbite gui/tcpclient.cpp
  let(:warlock)   { "0123abcd\n/FE:WRAYTH /VERSION:1.0.1.28 /P:WIN_UNKNOWN /XML\n" } # Warlock3 WraythClient.kt
  let(:saga)      { "0123abcd\r\n/FE:WRAYTH /VERSION:saga-0.10.4 /P:SAGA /XML\r\n" } # saga-archive src/main/index.js
  let(:keep_setting) { false }

  around do |example|
    saved = { frontend: $frontend, client: $_CLIENT_, buffer: $_CLIENTBUFFER_, offline: $offline_mode }
    begin
      example.run
    ensure
      $frontend = saved[:frontend]
      $_CLIENT_ = saved[:client]
      $_CLIENTBUFFER_ = saved[:buffer]
      $offline_mode = saved[:offline]
    end
  end

  before do
    stub_const('Frontend', Lich::Common::Frontend)
    game = Module.new
    game.define_singleton_method(:sent) { @sent ||= [] }
    game.define_singleton_method(:_puts) { |str| sent << str }
    stub_const('Game', game)
    setting = keep_setting
    allow(Lich).to receive(:keep_fe_string) { setting }
    allow(Lich).to receive(:log)
    $_CLIENTBUFFER_ = []
    $offline_mode = false
  end

  def forward(bytes, frontend: 'genie', argv_options: {}, launcher_cmd: nil)
    $frontend = frontend
    $_CLIENT_ = StringIO.new(bytes)
    harness_class.new(argv_options, launcher_cmd).run_forward
  end

  define_method(:harness_class) { harness_class }

  it "sends Genie's key, then Lich's client string in place of Genie's" do
    forward(genie)
    expect(Game.sent).to eq(["0123abcd\n", "/FE:WRAYTH /VERSION:saga-0.10.4 /P:SAGA /XML\n"])
    expect($_CLIENTBUFFER_).to eq(["/FE:WRAYTH /VERSION:saga-0.10.4 /P:SAGA /XML\n"])
    expect($frontend).to eq('genie')
  end

  it 'covers Frostbite launched without --frostbite (frontend unknown)' do
    forward(frostbite, frontend: 'unknown')
    expect(Game.sent).to eq(["<c>0123abcd\r\n", "<c>/FE:WRAYTH /VERSION:saga-0.10.4 /P:SAGA /XML\r\n"])
  end

  it 'covers Warlock3 (frontend unknown)' do
    forward(warlock, frontend: nil)
    expect(Game.sent.last).to eq("/FE:WRAYTH /VERSION:saga-0.10.4 /P:SAGA /XML\n")
  end

  it 'puts --fe-version into the replacement' do
    forward(genie, argv_options: { fe_version: 'genie-4.5' })
    expect(Game.sent.last).to eq("/FE:WRAYTH /VERSION:genie-4.5 /P:SAGA /XML\n")
  end

  it "forwards Saga's own handshake as sent" do
    forward(saga, frontend: 'saga')
    expect(Game.sent).to eq(saga.lines)
  end

  it 'forwards the front end handshake with --keep-fe-string' do
    forward(genie, argv_options: { keep_fe_string: true })
    expect(Game.sent).to eq(genie.lines)
    expect($_CLIENTBUFFER_).to eq([genie.lines.last])
  end

  context 'with Lich.keep_fe_string set' do
    let(:keep_setting) { true }

    it 'forwards the front end handshake' do
      forward(frostbite, frontend: 'unknown')
      expect(Game.sent).to eq(frostbite.lines)
    end
  end

  it "leaves Mudlet's lines alone (Lich already sent its handshake)" do
    forward(genie, launcher_cmd: '/usr/bin/mudlet')
    expect(Game.sent).to eq(genie.lines)
  end

  it 'forwards a second line that is not a handshake unchanged' do
    forward("0123abcd\nSET_FRONTEND_PID 4242\r\n")
    expect(Game.sent).to eq(["0123abcd\n", "SET_FRONTEND_PID 4242\r\n"])
  end
end
