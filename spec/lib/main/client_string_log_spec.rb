# frozen_string_literal: true

require 'rspec'
require 'stringio'

module Lich; end

module Lich
  def self.log(_msg); end
end unless Lich.respond_to?(:log)

LIB_DIR = File.expand_path('../../../lib', __dir__) unless defined?(LIB_DIR)
require_relative '../../../lib/common/front-end'
require File.join(LIB_DIR, 'common', 'markup.rb') # the Frostbite branch's fb_to_sf

# main.rb runs at load time, so (as in fe_version_spec.rb and
# proxy_handshake_spec.rb) each login path's handshake is lifted out of the
# shipping source and evaluated in a harness. The specs run the real code and
# check, for every path, what reaches Lich.log: the client string the front
# end sent (where there is one), the one Lich sent the game, and never the
# login key that precedes them.
LIB_MAIN_DIR = File.expand_path('../../../lib/main', __dir__) unless defined?(LIB_MAIN_DIR)

RSpec.describe 'client string logging on every login path (main.rb)' do
  main_source = File.read(File.join(LIB_MAIN_DIR, 'main.rb'))

  headless_block = main_source[/^  if ARGV\.include\?\('--without-frontend'\)\n    Thread\.new \{.*?\n    \}\n(?=  else\n)/m]
  raise 'could not extract the --without-frontend handshake from main.rb' unless headless_block

  # The offline, GSL (Wizard/Avalon) and Frostbite branches of client_thread,
  # closed off before the branch every other front end takes.
  gsl_frostbite_block = main_source[/^      if \$offline_mode\n.*?(?=^      else\n        if launcher_cmd)/m]
  raise 'could not extract the GSL and Frostbite handshakes from main.rb' unless gsl_frostbite_block

  # A recognisable fake login key: none of it may reach the log.
  key_line = "SECRETLOGINKEY0123456789abcdef42\r\n"

  mudlet_block = main_source[/^        if launcher_cmd\.to_s =~ \/mudlet\/\n.*?^        end\n/m]
  raise 'could not extract the Mudlet handshake from main.rb' unless mudlet_block

  forward_block = main_source[/^        unless \$offline_mode\n.*?^        end\n/m]
  raise 'could not extract the proxied handshake forward from main.rb' unless forward_block

  harness_class = Class.new do
    def initialize(argv_options, launcher_cmd)
      @argv_options = argv_options
      @launcher_cmd = launcher_cmd
    end

    def sleep(_seconds); end

    def fb_to_sf(line)
      Lich::Common::Markup.fb_to_sf(line)
    end

    define_method(:run_headless) do
      game_key = key_line.chomp # read by the eval'd main.rb source
      eval("#{headless_block}  end", binding, 'main.rb').join
      game_key
    end

    # Wrapped in a block, as in main.rb's client_thread, so the offline
    # branch's `next` is valid.
    define_method(:run_gsl_frostbite) do
      eval("proc {\n#{gsl_frostbite_block}      end\n}.call", binding, 'main.rb')
    end

    define_method(:run_mudlet) do
      launcher_cmd = @launcher_cmd # read by the eval'd main.rb source
      game_key = key_line.chomp # read by the eval'd main.rb source
      eval(mudlet_block, binding, 'main.rb')
      game_key
    end

    define_method(:run_forward) do
      launcher_cmd = @launcher_cmd # read by the eval'd main.rb source
      eval(forward_block, binding, 'main.rb')
    end
  end

  let(:key) { 'SECRETLOGINKEY' }
  let(:lich_string) { Lich::Common::Frontend::CLIENT_STRING }
  let(:logged) { [] }

  around do |example|
    saved = { frontend: $frontend, client: $_CLIENT_, buffer: $_CLIENTBUFFER_,
              offline: $offline_mode, prefix: $cmd_prefix, argv: ARGV.dup }
    begin
      example.run
    ensure
      $frontend = saved[:frontend]
      $_CLIENT_ = saved[:client]
      $_CLIENTBUFFER_ = saved[:buffer]
      $offline_mode = saved[:offline]
      $cmd_prefix = saved[:prefix]
      ARGV.replace(saved[:argv])
    end
  end

  before do
    stub_const('Frontend', Lich::Common::Frontend)
    game = Module.new
    game.define_singleton_method(:sent) { @sent ||= [] }
    game.define_singleton_method(:_puts) { |str| sent << str }
    stub_const('Game', game)
    allow(Lich::Common::Frontend).to receive(:sleep) # send_handshake's ready pauses
    allow(Lich).to receive(:keep_fe_string).and_return(false)
    allow(Lich).to receive(:log) { |msg| logged << msg }
    $_CLIENTBUFFER_ = []
    $offline_mode = false
    $cmd_prefix = '<c>'
  end

  def harness(argv_options: {}, launcher_cmd: nil)
    harness_class.new(argv_options, launcher_cmd)
  end

  def client(frontend, bytes)
    $frontend = frontend
    $_CLIENT_ = StringIO.new(bytes)
  end

  define_method(:harness_class) { harness_class }

  context 'with --without-frontend (headless and detachable)' do
    let(:run_path) do
      lambda do
        ARGV.replace(['--without-frontend'])
        $frontend = 'saga'
        harness(argv_options: { fe_version: 'saga-0.10.2' }).run_headless
      end
    end

    it 'logs the client string it sends; there is no front-end string' do
      run_path.call
      expect(logged).to eq(['info: client string sent to game: /FE:WRAYTH /VERSION:saga-0.10.2 /P:SAGA /XML'])
    end

    it 'sends the key to the game but never logs it' do
      run_path.call
      expect(Game.sent.first).to include(key)
      expect(logged.size).to eq(1)
      expect(logged.join("\n")).not_to include(key)
    end
  end

  # These branches discard whatever the front end sends, and the log echoes it.
  # The version lines are as captured live (see the replays below); Avalon
  # introduces itself as Wizard.
  {
    'Wizard'    => ['wizard', "/FE:WIZARD /VERSION:2.04 /P:WIN32\r\n", "GOOD\r\n"],
    'Avalon'    => ['avalon', "/FE:WIZARD /VERSION:2.02 /P:WIN32\r\n", "GOOD\r\n\r\n"],
    'Frostbite' => ['frostbite', "<c>/FE:STORMFRONT /VERSION:1.0.1.26 /P:WIN_UNKNOWN /XML\r\n", '']
  }.each do |name, (frontend, version_line, rest)|
    context "with #{name}" do
      it "logs #{name}'s version line and the client string Lich sends in its place" do
        client(frontend, "#{key_line}#{version_line}#{rest}")
        harness.run_gsl_frostbite
        expect(Game.sent[1]).to eq(lich_string)
        expect(logged).to eq([
                               "info: client string from front end: #{version_line.chomp}",
                               "info: client string sent to game: #{lich_string} (Lich's, in place of the front end's)"
                             ])
      end

      it 'sends the key to the game but never logs it' do
        client(frontend, "#{key_line}#{version_line}#{rest}")
        harness.run_gsl_frostbite
        expect(Game.sent.first).to include(key)
        expect(logged.size).to eq(2)
        expect(logged.join("\n")).not_to include(key)
      end
    end
  end

  it 'logs the front end string as (none) when the front end hangs up after the key' do
    client('wizard', key_line)
    harness.run_gsl_frostbite
    expect(logged.first).to eq('info: client string from front end: (none)')
  end

  it 'logs nothing in offline mode, where nothing is sent' do
    $offline_mode = true
    client('wizard', "#{key_line}/FE:WIZARD\r\n")
    harness.run_gsl_frostbite
    expect(logged).to be_empty
  end

  context 'with Mudlet' do
    it 'logs the client string it sends; Mudlet sends none' do
      $frontend = nil
      harness(launcher_cmd: '/usr/bin/mudlet').run_mudlet
      expect(Game.sent[1]).to eq(lich_string)
      expect(logged).to eq(["info: client string sent to game: #{lich_string}"])
    end

    it 'sends the key to the game but never logs it' do
      harness(launcher_cmd: '/usr/bin/mudlet').run_mudlet
      expect(Game.sent.first).to include(key)
      expect(logged.size).to eq(1)
      expect(logged.join("\n")).not_to include(key)
    end

    it "does not log Mudlet's own lines, which it forwards as-is" do
      client(nil, "#{key_line}/FE:MUDLET /XML\n")
      harness(launcher_cmd: '/usr/bin/mudlet').run_forward
      expect(logged).to be_empty
    end
  end

  context 'with every other front end (proxy_handshake)' do
    it "logs Genie's handshake and the client string Lich sends in its place" do
      client('genie', "#{key_line}FE:WRAYTH /VERSION:1.0.1.22 /P:WIN_UNKNOWN /XML\n")
      harness.run_forward
      expect(logged).to eq([
                             'info: client string from front end: FE:WRAYTH /VERSION:1.0.1.22 /P:WIN_UNKNOWN /XML',
                             "info: client string sent to game: #{lich_string} (Lich's, in place of the front end's)"
                           ])
    end

    it "logs Saga's own handshake as both sides" do
      client('saga', "#{key_line}/FE:WRAYTH /VERSION:saga-0.10.4 /P:SAGA /XML\r\n")
      harness.run_forward
      expect(logged.last).to eq("info: client string sent to game: /FE:WRAYTH /VERSION:saga-0.10.4 /P:SAGA /XML (the front end's own: it already asks for /P:SAGA)")
    end

    it 'sends the key to the game but never logs it' do
      client('genie', "#{key_line}FE:WRAYTH /VERSION:1.0.1.22 /P:WIN_UNKNOWN /XML\n")
      harness.run_forward
      expect(Game.sent.first).to include(key)
      expect(logged.size).to eq(2)
      expect(logged.join("\n")).not_to include(key)
    end

    it 'never logs a key that arrives where the handshake was expected' do
      client('genie', "0123abcd\n#{key_line}")
      harness.run_forward
      expect(Game.sent.last).to eq(key_line)
      expect(logged.size).to eq(2)
      expect(logged.join("\n")).not_to include(key)
    end
  end

  # Live session logs (spec/fixtures/client_string_log, character names
  # anonymised). Each capture's front-end line is replayed through its real
  # login path, as BINARY as a socket reads it; the log must echo it as the
  # live session did, and Lich must send what it sent then. The captures
  # predate the note on the Wizard, Avalon and Frostbite paths, so the note is checked
  # on its own: every captured front end got Lich's string.
  context 'replaying live session logs' do
    fixture_dir = File.expand_path('../../fixtures/client_string_log', __dir__)
    captured_lich_string = '/FE:WRAYTH /VERSION:saga-0.10.4 /P:SAGA /XML' # CLIENT_STRING when captured
    sent_line = /\Ainfo: client string sent to game: (?<string>.*?)(?: \((?<note>[^()]*)\))?\z/

    # fixture => [$frontend, login path, what the front end sends after its version line]
    # Warlock and Wrayth run as stormfront; no front end but Saga has its own
    # replacement string, so the id does not change what is sent.
    {
      'wizard_gs.log'    => ['wizard', :run_gsl_frostbite, "GOOD\r\n"],
      'avalon_gs.log'    => ['avalon', :run_gsl_frostbite, "GOOD\r\n\r\n"],
      'frostbite_dr.log' => ['frostbite', :run_gsl_frostbite, ''],
      'genie_dr.log'     => ['genie', :run_forward, ''],
      'warlock_dr.log'   => ['stormfront', :run_forward, ''],
      'wrayth_gs.log'    => ['stormfront', :run_forward, '']
    }.each do |fixture, (frontend, login_path, rest)|
      context "with #{fixture}" do
        captured = File.readlines(File.join(fixture_dir, fixture), chomp: true)
                       .map { |line| line.sub(/\A\d{4}-\d\d-\d\d \d\d:\d\d:\d\d: /, '') }
                       .grep(/\Ainfo: client string /)
        raise "#{fixture}: expected a from-front-end and a sent-to-game line, got #{captured.inspect}" unless captured.size == 2

        from_frontend = captured.first
        sent = sent_line.match(captured.last)

        before do
          client(frontend, "#{key_line}#{from_frontend.delete_prefix('info: client string from front end: ')}\r\n#{rest}".b)
          harness.send(login_path)
        end

        it 'logs the front end string in full, as the live session did' do
          expect(logged.first).to eq(from_frontend)
        end

        it 'sends the game the client string the live session sent, and logs it' do
          expected = sent[:string].sub(captured_lich_string, lich_string)
          expect(Game.sent[1].chomp).to eq(expected)
          expect(sent_line.match(logged.last)[:string]).to eq(expected)
        end

        it "notes that Lich's string replaced the front end's" do
          expect(sent_line.match(logged.last)[:note]).to eq("Lich's, in place of the front end's")
        end

        it 'sends the key to the game but never logs it' do
          expect(Game.sent.first).to include(key)
          expect(logged.join("\n")).not_to include(key)
        end
      end
    end
  end
end
