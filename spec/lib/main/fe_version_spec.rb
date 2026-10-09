# frozen_string_literal: true

require 'rspec'

module Lich; end

module Lich
  def self.log(_msg); end
end unless Lich.respond_to?(:log)

require_relative '../../../lib/common/front-end'

# argv_options.rb and main.rb auto-execute at load time, so (as in
# argv_options_spec.rb) the code under test is lifted out of the shipping
# source and evaluated in a lightweight harness. This keeps the specs bound
# to the real code rather than a copy of it.
LIB_MAIN_DIR = File.expand_path('../../../lib/main', __dir__) unless defined?(LIB_MAIN_DIR)

RSpec.describe '--fe-version' do
  around do |example|
    original_argv = ARGV.dup
    original_frontend = $frontend # the real --saga branch assigns it
    begin
      example.run
    ensure
      ARGV.replace(original_argv)
      $frontend = original_frontend
    end
  end

  describe 'OptionParser.execute' do
    parser = Module.new do
      source = File.read(File.join(LIB_MAIN_DIR, 'argv_options.rb'))
      body = source[/^(?<ind>[ \t]*)module OptionParser\n(?<body>.*?)^\k<ind>end$/m, :body]
      raise 'could not extract OptionParser from argv_options.rb' unless body

      module_eval(body)
    end

    def parse(*args)
      ARGV.replace(args)
      parser.execute
    end

    define_method(:parser) { parser }

    it 'stores a valid value' do
      opts = nil
      expect { opts = parse('--fe-version=saga-0.10.2') }.not_to output.to_stdout
      expect(opts[:fe_version]).to eq('saga-0.10.2')
    end

    it 'accepts every allowed character class and the 32-char maximum' do
      value = 'Aa0._+-' + ('x' * 25)
      expect(parse("--fe-version=#{value}")[:fe_version]).to eq(value)
    end

    it 'leaves fe_version nil when the flag is absent' do
      expect(parse('--saga', '--without-frontend')[:fe_version]).to be_nil
    end

    it 'coexists with --saga, --frontend=NAME, --without-frontend and --detachable-client' do
      opts = parse('--saga', '--frontend=genie', '--without-frontend',
                   '--detachable-client=8000', '--fe-version=saga-0.10.2')
      expect(opts[:fe_version]).to eq('saga-0.10.2')
      expect(opts[:frontend]).to eq('genie')
    end

    {
      'empty'             => '',
      'space'             => 'saga 0.10.2',
      'tab'               => "saga\t1",
      'LF'                => "saga-1\n/FE:EVIL",
      'CR'                => "saga-1\r",
      'CRLF'              => "saga-1\r\n",
      'slash'             => 'saga/1',
      'over 32 chars'     => 'x' * 33,
      'other punctuation' => 'saga;1',
    }.each do |label, value|
      it "rejects a value with #{label} and warns" do
        opts = nil
        expect { opts = parse("--fe-version=#{value}") }.to output(/warning: ignoring invalid --fe-version/).to_stdout
        expect(opts).not_to have_key(:fe_version)
      end
    end
  end

  describe '--without-frontend handshake (main.rb)' do
    main_source = File.read(File.join(LIB_MAIN_DIR, 'main.rb'))
    headless_block = main_source[/^  if ARGV\.include\?\('--without-frontend'\)\n    Thread\.new \{.*?\n    \}\n(?=  else\n)/m]
    raise 'could not extract the --without-frontend handshake from main.rb' unless headless_block

    harness_class = Class.new do
      attr_reader :sent

      def initialize(argv_options)
        @argv_options = argv_options
        @sent = []
      end

      def sleep(_seconds); end

      define_method(:run_handshake) do
        game_key = 'KEY' # read by the eval'd main.rb source
        eval("#{headless_block}  end", binding, 'main.rb').join
      end
    end

    before do
      stub_const('Frontend', Lich::Common::Frontend)
      game = Module.new
      game.define_singleton_method(:sent) { @sent ||= [] }
      game.define_singleton_method(:_puts) { |str| sent << str }
      stub_const('Game', game)
      $_CLIENTBUFFER_ = []
      ARGV.replace(['--without-frontend'])
    end

    def run(argv_options)
      harness_class.new(argv_options).run_handshake
    end

    define_method(:harness_class) { harness_class }

    # Frontend.client reads $frontend (restored by the around hook), the value
    # main.rb sets from resolve_headless_frontend before this block runs.
    it 'sends the version-substituted client string when --fe-version is set' do
      $frontend = 'wrayth'
      run(fe_version: 'genie-5.1')
      expected = '/FE:WRAYTH /VERSION:genie-5.1 /P:WIN_UNKNOWN /XML'
      expect(Game.sent).to eq(['KEY', expected, '<c>', '<c>'])
      expect($_CLIENTBUFFER_).to eq([expected, "<c>\r\n", "<c>\r\n"])
    end

    it 'sends the default client string byte-for-byte when --fe-version is absent' do
      $frontend = 'wrayth'
      run({})
      expected = '/FE:WRAYTH /VERSION:1.0.1.28 /P:WIN_UNKNOWN /XML'
      expect(Game.sent[1].bytes).to eq(expected.bytes)
      expect($_CLIENTBUFFER_.first.bytes).to eq(expected.bytes)
    end

    it 'identifies Saga as /P:SAGA with the --fe-version value' do
      $frontend = 'saga'
      run(fe_version: 'saga-0.10.2')
      expect(Game.sent[1]).to eq('/FE:WRAYTH /VERSION:saga-0.10.2 /P:SAGA /XML')
    end

    it 'identifies Saga as saga-unknown when --fe-version is absent' do
      $frontend = 'saga'
      run({})
      expect(Game.sent[1]).to eq('/FE:WRAYTH /VERSION:saga-unknown /P:SAGA /XML')
    end
  end

  describe 'other handshake sites (main.rb)' do
    main_source = File.read(File.join(LIB_MAIN_DIR, 'main.rb'))

    it 'uses the builder only at the --without-frontend send site' do
      expect(main_source.scan('Frontend.client_string').size).to eq(1)
    end

    it 'leaves the GSL, Frostbite and Mudlet sites sending CLIENT_STRING' do
      client_thread = main_source[/client_thread = Thread\.new \{.*?inv_off_proc/m]
      expect(client_thread.scan('Frontend.send_handshake(Frontend::CLIENT_STRING)').size).to eq(2)
      expect(client_thread).to match(/launcher_cmd\.to_s =~ \/mudlet\/.*?client_string = Frontend::CLIENT_STRING/m)
    end
  end
end
