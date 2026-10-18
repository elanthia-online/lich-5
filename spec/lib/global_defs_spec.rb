# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require_relative '../spec_helper'

# NOTE: We intentionally do NOT `require 'global_defs.rb'` here.
# Loading the entire file redefines global methods (respond, get, put, etc.)
# with production implementations that depend on game infrastructure
# (Script.new_script_output, $_CLIENT_, etc.), which breaks every test
# that runs after this file in the randomized suite.
#
# Instead, GlobalDefsSpecSource.define reads the methods under test out of
# lib/global_defs.rb and class_evals each one into its example group, so
# the examples run the shipped code, the definitions stay scoped to that
# group, and calls inside them resolve stubs via normal method lookup.
module GlobalDefsSpecSource
  PATH = File.expand_path('../../lib/global_defs.rb', __dir__)

  # Defines each named top-level method of lib/global_defs.rb on target.
  # Raises when a definition or its column-0 `end` is missing, so a
  # reformat of the production file fails loudly instead of testing nothing.
  def self.define(target, *names)
    lines = File.readlines(PATH)
    names.each do |name|
      first = def_index(lines, name)
      offset = lines[(first + 1)..].index { |line| line.match?(/^end\s*$/) }
      raise "global_defs.rb: def #{name} terminator missing" unless offset

      target.class_eval(lines[first..(first + offset + 1)].join, PATH, first + 1)
    end
  end

  # The 1-based line of a method's def in lib/global_defs.rb.
  def self.line_of(name)
    def_index(File.readlines(PATH), name) + 1
  end

  # Ruby keeps the last of two top-level defs, so a second one would leave
  # these examples testing the definition that does not ship.
  def self.def_index(lines, name)
    found = lines.each_index.select { |i| lines[i].match?(/^def #{Regexp.escape(name)}(?:\(|\s|$)/) }
    raise "global_defs.rb: def #{name} missing" if found.empty?
    raise "global_defs.rb: def #{name} defined #{found.size} times" if found.size > 1

    found.first
  end
  private_class_method :def_index
end

RSpec.describe '#fput' do
  GlobalDefsSpecSource.define(self, 'fput', 'multifput')

  it 'runs the fput and multifput defined in lib/global_defs.rb' do
    %w[fput multifput].each do |name|
      expect(method(name).source_location).to eq([GlobalDefsSpecSource::PATH, GlobalDefsSpecSource.line_of(name)])
    end
  end

  it 'fails loudly when a method cannot be found in lib/global_defs.rb' do
    expect { GlobalDefsSpecSource.define(Class.new, 'no_such_global') }
      .to raise_error(RuntimeError, /def no_such_global missing/)
  end

  it 'fails loudly on a duplicate, prefix-only or unterminated def' do
    allow(File).to receive(:readlines).and_call_original
    allow(File).to receive(:readlines).with(GlobalDefsSpecSource::PATH)
                                      .and_return(["def twice\n", "end\n", "def twice\n", "end\n",
                                                   "def fputs_like(x)\n", "end\n", "def open_ended\n", "  1\n"])

    expect { GlobalDefsSpecSource.define(Class.new, 'twice') }.to raise_error(RuntimeError, /def twice defined 2 times/)
    expect { GlobalDefsSpecSource.define(Class.new, 'fputs') }.to raise_error(RuntimeError, /def fputs missing/)
    expect { GlobalDefsSpecSource.define(Class.new, 'open_ended') }.to raise_error(RuntimeError, /terminator missing/)
  end

  let(:downstream_buffer) { [] }
  let(:mock_script) do
    script = Script.new
    script.name = 'test'
    allow(script).to receive(:downstream_buffer).and_return(downstream_buffer)
    script
  end

  before do
    allow(Script).to receive(:current).and_return(mock_script)
    # Production sleeps through Script.execution_sleep (it checks the
    # script's execution guard); with no guard installed it is a plain
    # sleep. Route it to self.sleep so examples can stub and count it.
    allow(Script).to receive(:execution_sleep) { |seconds| sleep(seconds) }
    allow(self).to receive(:put)
    allow(self).to receive(:echo)
  end

  # Stub get? to return responses in order, then nil when exhausted
  def stub_game_responses(*responses)
    call_count = 0
    allow(self).to receive(:get?) do
      response = responses[call_count]
      call_count += 1
      response
    end
  end

  # Stub get? to always return nil and stub pause to avoid real waits.
  # A timeout regression would spin fput forever on a frozen clock, so
  # past `limit` empty reads the stub raises and the example fails.
  def stub_no_game_responses(limit: 1_000)
    reads = 0
    allow(self).to receive(:get?) do
      reads += 1
      raise "fput still polling after #{limit} empty reads" if reads > limit

      nil
    end
    allow(self).to receive(:pause)
  end

  # Stub Time.now to simulate elapsed time.
  # initial_calls_count calls return frozen_time, then all subsequent return frozen_time + elapsed.
  def stub_elapsed_time(elapsed_seconds, initial_calls: 2)
    frozen_time = Time.now
    call_count = 0
    allow(Time).to receive(:now) do
      call_count += 1
      call_count <= initial_calls ? frozen_time : frozen_time + elapsed_seconds
    end
  end

  describe 'basic behavior' do
    it 'returns the first game response and pushes it back to the buffer' do
      stub_game_responses('You pick up a sword.')

      result = fput('get sword')

      expect(result).to eq('You pick up a sword.')
      expect(downstream_buffer).to eq(['You pick up a sword.'])
    end

    it 'sends the command via put' do
      stub_game_responses('OK.')
      expect(self).to receive(:put).with('get sword')

      fput('get sword')
    end

    it 'calls clear before sending the command' do
      stub_game_responses('OK.')
      expect(self).to receive(:clear).ordered
      expect(self).to receive(:put).with('test').ordered

      fput('test')
    end
  end

  context 'with waitingfor patterns' do
    it 'returns the matching pattern when a response matches' do
      stub_game_responses('You pick up a sword.')

      result = fput('get sword', 'You pick up')

      expect(result).to eq('You pick up')
      expect(downstream_buffer).to eq(['You pick up a sword.'])
    end

    it 'resends command when response does not match any pattern' do
      stub_game_responses('Some other text.', 'You pick up a sword.')
      expect(self).to receive(:put).with('get sword').exactly(2).times
      allow(self).to receive(:sleep)

      result = fput('get sword', 'You pick up')

      expect(result).to eq('You pick up')
    end
  end

  context 'when game sends a wait message' do
    it 'sleeps for the specified duration and resends command' do
      stub_game_responses('...wait 3 seconds.', 'You pick up a sword.')
      expect(self).to receive(:sleep).with(3)
      expect(self).to receive(:put).with('get sword').exactly(2).times

      result = fput('get sword')

      expect(result).to eq('You pick up a sword.')
    end
  end

  context 'when character is stunned or dead' do
    it 'returns false when dead' do
      stub_game_responses("can't do that while dead")
      allow(self).to receive(:dead?).and_return(true)
      allow(self).to receive(:checkstunned).and_return(false)
      allow(self).to receive(:checkwebbed).and_return(false)
      allow(self).to receive(:sleep)

      result = fput('attack')

      expect(result).to eq(false)
    end

    it 'says why, pushes the refusal back and does not resend when dead' do
      stub_game_responses("can't do that while dead")
      allow(self).to receive(:dead?).and_return(true)
      allow(self).to receive(:sleep)
      expect(self).to receive(:echo).with("You're dead...! You can't do that!")
      expect(self).to receive(:put).with('attack').once

      expect(fput('attack', failures: :symbol)).to eq(:dead)
      expect(downstream_buffer).to eq(["can't do that while dead"])
    end

    context 'when a refusal arrives while stunned or webbed' do
      before do
        allow(self).to receive(:dead?).and_return(false)
        allow(self).to receive(:checkstunned).and_return(false)
        allow(self).to receive(:checkwebbed).and_return(false)
        allow(self).to receive(:sleep)
      end

      it 'waits the stun out in quarter seconds, then resends' do
        stub_game_responses('You are still stunned.', 'You pick up a sword.')
        # the branch check, then the wait loop: stunned, stunned, recovered
        stun = [true, true, true, false]
        allow(self).to receive(:checkstunned) { stun.shift }
        expect(self).to receive(:sleep).with(0.25).twice
        expect(self).to receive(:put).with('get sword').twice

        expect(fput('get sword')).to eq('You pick up a sword.')
        expect(stun).to be_empty
        expect(downstream_buffer).to eq(['You pick up a sword.'])
      end

      it 'waits a web out in quarter seconds, then resends' do
        # the branch keys on checkwebbed, not on the refusal wording
        stub_game_responses("You can't do that while engaged!", 'You pick up a sword.')
        web = [true, true, false]
        allow(self).to receive(:checkwebbed) { web.shift }
        expect(self).to receive(:sleep).with(0.25).once
        expect(self).to receive(:put).with('get sword').twice

        expect(fput('get sword')).to eq('You pick up a sword.')
        expect(web).to be_empty
      end

      it 'treats a stun message as a refusal when the stun has already passed' do
        stub_game_responses('You are still stunned.', 'You pick up a sword.')
        expect(self).to receive(:put).with('get sword').once

        expect(fput('get sword', failures: :symbol)).to eq(:refused)
        expect(downstream_buffer).to eq(['You are still stunned.'])
      end

      it 'counts a stun resend against max_resends' do
        stub_game_responses('You are still stunned.', 'You are still stunned.', 'You pick up a sword.')
        stun = [true, false, true, false]
        allow(self).to receive(:checkstunned) { stun.shift }
        expect(self).to receive(:put).with('get sword').twice

        expect(fput('get sword', max_resends: 1, failures: :symbol)).to eq(:too_many_resends)
        expect(downstream_buffer).to eq(['You are still stunned.'])
      end

      it 'ends a stun that does not pass on the interrupt' do
        stub_game_responses('You are still stunned.', 'You pick up a sword.')
        stun_reads = 0
        allow(self).to receive(:checkstunned) { (stun_reads += 1) > 50 ? raise('stun wait never interrupted') : true }
        checks = 0
        interrupt = -> { (checks += 1) > 3 }
        expect(self).to receive(:sleep).with(0.25).exactly(3).times
        expect(self).to receive(:put).with('get sword').once

        expect(fput('get sword', interrupt: interrupt, failures: :symbol)).to eq(:interrupted)
      end

      it 'ends a web that does not pass on the interrupt' do
        stub_game_responses("You can't do that while engaged!", 'You pick up a sword.')
        web_reads = 0
        allow(self).to receive(:checkwebbed) { (web_reads += 1) > 50 ? raise('web wait never interrupted') : true }
        checks = 0
        interrupt = -> { (checks += 1) > 3 }
        expect(self).to receive(:sleep).with(0.25).exactly(3).times
        expect(self).to receive(:put).with('get sword').once

        expect(fput('get sword', interrupt: interrupt, failures: :symbol)).to eq(:interrupted)
      end
    end

    it 'waits a second on the type-ahead limit, then resends' do
      allow(self).to receive(:dead?).and_return(false)
      allow(self).to receive(:checkstunned).and_return(false)
      allow(self).to receive(:checkwebbed).and_return(false)
      stub_game_responses('Sorry, you may only type ahead 1 command.', 'You pick up a sword.')
      expect(self).to receive(:sleep).with(1).once
      expect(self).to receive(:put).with('get sword').twice

      expect(fput('get sword')).to eq('You pick up a sword.')
    end
  end

  describe 'bounded sends (max_resends:, interrupt:, resend_transient:, failures:)' do
    before do
      allow(self).to receive(:sleep)
      allow(self).to receive(:pause)
      allow(self).to receive(:dead?).and_return(false)
      allow(self).to receive(:checkstunned).and_return(false)
      allow(self).to receive(:checkwebbed).and_return(false)
    end

    it 'gives up after max_resends roundtime refusals' do
      stub_game_responses('...wait 2 seconds.', '...wait 2 seconds.', '...wait 2 seconds.', 'OK.')
      expect(self).to receive(:put).with('get sword').exactly(3).times

      expect(fput('get sword', max_resends: 2)).to eq(false)
    end

    it 'names the failure with failures: :symbol' do
      stub_game_responses('...wait 2 seconds.', '...wait 2 seconds.', 'OK.')
      expect(fput('get sword', max_resends: 1, failures: :symbol)).to eq(:too_many_resends)

      stub_game_responses("You can't seem to do that.")
      expect(fput('get sword', failures: :symbol)).to eq(:refused)

      stub_game_responses("can't do that while dead")
      allow(self).to receive(:dead?).and_return(true)
      expect(fput('attack', failures: :symbol)).to eq(:dead)
    end

    it 'still returns false for every failure by default' do
      stub_game_responses("You can't seem to do that.")
      expect(fput('get sword')).to eq(false)
      expect(downstream_buffer).to eq(["You can't seem to do that."])
    end

    it 'resends a transient refusal under the cap with resend_transient:' do
      stub_game_responses("You can't seem to do that.", "You can't seem to do that.", 'You pick up a sword.')
      expect(self).to receive(:put).with('get sword').exactly(3).times

      expect(fput('get sword', resend_transient: true, max_resends: 5)).to eq('You pick up a sword.')
    end

    it 'stops on the interrupt during a roundtime wait, in slices' do
      stub_game_responses('...wait 3 seconds.', 'OK.')
      calls = 0
      interrupt = -> { (calls += 1) >= 2 }
      expect(self).to receive(:put).with('get sword').once

      expect(fput('get sword', interrupt: interrupt, failures: :symbol)).to eq(:interrupted)
    end

    it 'stops on the interrupt while waiting for any response' do
      stub_no_game_responses
      expect(fput('get sword', interrupt: -> { true }, failures: :symbol)).to eq(:interrupted)
    end

    it 'sleeps the whole wait at once when there is no interrupt' do
      stub_game_responses('...wait 3 seconds.', 'OK.')
      expect(self).to receive(:sleep).with(3)

      expect(fput('get sword', max_resends: 5)).to eq('OK.')
    end

    it 'counts a waitingfor miss as a resend' do
      stub_game_responses('no', 'no', 'no', 'You pick up a sword.')
      expect(fput('get sword', 'You pick up', max_resends: 1, failures: :symbol)).to eq(:too_many_resends)
    end

    it 'stands in the same frame and resends the message once up' do
      stub_game_responses('You struggle to stand.', 'You stand back up.', 'You pick up a sword.')
      expect(self).to receive(:put).with('get sword').ordered
      expect(self).to receive(:put).with('stand').ordered
      expect(self).to receive(:put).with('get sword').ordered

      expect(fput('get sword')).to eq('You pick up a sword.')
    end

    it 'caps a persistent struggle to stand' do
      reads = 0
      allow(self).to receive(:get?) { (reads += 1) > 50 ? raise('struggle never capped') : 'You struggle to stand.' }
      expect(self).to receive(:put).with('stand').exactly(3).times

      expect(fput('get sword', max_resends: 3, failures: :symbol)).to eq(:too_many_resends)
    end

    it 'honors the interrupt on a persistent struggle to stand' do
      reads = 0
      allow(self).to receive(:get?) { (reads += 1) > 50 ? raise('struggle never interrupted') : 'You struggle to stand.' }

      expect(fput('get sword', interrupt: -> { true }, failures: :symbol)).to eq(:interrupted)
      expect(fput('get sword', interrupt: -> { true })).to eq(false)
    end

    it 'honors the interrupt during the type-ahead and transient waits' do
      stub_game_responses('Sorry, you may only type ahead 1 command.', 'OK.')
      expect(fput('get sword', interrupt: -> { true }, failures: :symbol)).to eq(:interrupted)

      stub_game_responses("You can't seem to do that.", 'OK.')
      expect(fput('get sword', resend_transient: true, interrupt: -> { true }, failures: :symbol)).to eq(:interrupted)
    end

    it 'surfaces the last refusal when resend_transient gives up' do
      stub_game_responses("You can't seem to do that.", "You can't seem to do that.", 'OK.')

      expect(fput('get sword', resend_transient: true, max_resends: 1, failures: :symbol)).to eq(:too_many_resends)
      expect(downstream_buffer).to eq(["You can't seem to do that."])
    end

    it 'rejects an interrupt that cannot be called' do
      expect { fput('get sword', interrupt: true) }.to raise_error(ArgumentError, /interrupt/)
    end
  end

  describe 'timeout behavior' do
    it 'times out after default 60 seconds with no game response' do
      stub_no_game_responses
      stub_elapsed_time(61)

      expect(self).to receive(:echo).with(/No game response for 60s/)

      result = fput('test command')

      expect(result).to eq(false)
    end

    it 'gives up only once more than the timeout has passed' do
      stub_no_game_responses
      start = Time.now
      # the timer start, a poll at exactly 60s (not over), a poll past it
      clock = [start, start + 60, start + 60.5]
      allow(Time).to receive(:now) { clock.size > 1 ? clock.shift : clock.first }
      expect(self).to receive(:pause).with(0.1).once
      expect(self).to receive(:echo).with("fput: No game response for 60s to 'look'")

      expect(fput('look', failures: :symbol)).to eq(:no_response)
    end

    it 'uses custom timeout when specified via Hash argument' do
      stub_no_game_responses
      stub_elapsed_time(11)

      expect(self).to receive(:echo).with(/No game response for 10s/)

      result = fput('test command', timeout: 10)

      expect(result).to eq(false)
    end

    it 'supports string key timeout in Hash argument' do
      stub_no_game_responses
      stub_elapsed_time(6)

      expect(self).to receive(:echo).with(/No game response for 5s/)

      result = fput('test command', { 'timeout' => 5 })

      expect(result).to eq(false)
    end

    it 'does not timeout when timeout: 0 is specified' do
      responses = Array.new(5, nil) + ['OK.']
      call_count = 0
      allow(self).to receive(:get?) do
        r = responses[call_count]
        call_count += 1
        r
      end
      allow(self).to receive(:pause)
      stub_elapsed_time(10_000)

      expect(self).not_to receive(:echo)

      result = fput('test command', timeout: 0)

      expect(result).to eq('OK.')
    end

    it 'resets the timer on any game response' do
      # nil, nil -> unmatched response (resets timer) -> nil, nil -> matching response
      responses = [nil, nil, 'Some unmatched text.', nil, nil, 'Expected match.']
      resp_index = 0
      allow(self).to receive(:get?) do
        r = responses[resp_index]
        resp_index += 1
        r
      end
      allow(self).to receive(:pause)
      allow(self).to receive(:sleep)

      # Time progresses: 30s before response, then 25s after reset - never exceeds 60s window
      frozen_time = Time.now
      time_calls = 0
      allow(Time).to receive(:now) do
        time_calls += 1
        case time_calls
        when 1      then frozen_time        # initial timer
        when 2, 3   then frozen_time + 30   # 30s elapsed before response
        when 4      then frozen_time + 30   # response arrives, timer resets
        when 5, 6   then frozen_time + 85   # 55s since reset, 85s since send
        else frozen_time + 85
        end
      end

      result = fput('test', 'Expected match')

      expect(result).to eq('Expected match')
    end

    it 'preserves waitingfor patterns when timeout Hash is provided' do
      stub_game_responses('You pick up a sword.')

      result = fput('get sword', 'You pick up', timeout: 30)

      expect(result).to eq('You pick up')
    end
  end

  describe '#multifput' do
    it 'calls fput for each command in sequence' do
      stub_game_responses('OK.', 'Done.')
      expect(self).to receive(:fput).with('cmd1').and_call_original.ordered
      expect(self).to receive(:fput).with('cmd2').and_call_original.ordered

      multifput('cmd1', 'cmd2')
    end
  end
end

require 'common/arg_parser'

RSpec.describe '#parse_args / #display_args bridge' do
  def parse_args(defn, flex_args = false)
    Lich::Common::ArgParser.new.parse_args(defn, flex_args)
  end

  def display_args(defn)
    Lich::Common::ArgParser.new.display_args(defn)
  end

  let(:parser) { instance_double(Lich::Common::ArgParser) }

  before do
    allow(Lich::Common::ArgParser).to receive(:new).and_return(parser)
  end

  describe '#parse_args' do
    it 'delegates to Lich::Common::ArgParser#parse_args' do
      defs = [[:some_defs]]
      expect(parser).to receive(:parse_args).with(defs, false)

      parse_args(defs)
    end

    it 'forwards the flex_args parameter' do
      defs = [[:some_defs]]
      expect(parser).to receive(:parse_args).with(defs, true)

      parse_args(defs, true)
    end
  end

  describe '#display_args' do
    it 'delegates to Lich::Common::ArgParser#display_args' do
      defs = [[:some_defs]]
      expect(parser).to receive(:display_args).with(defs)

      display_args(defs)
    end
  end
end

RSpec.describe 'global_defs.rb sentinel constants' do
  let(:source) { File.read(File.join(LIB_DIR, 'global_defs.rb')) }

  describe 'CORE_AUTOSTART sentinel' do
    it 'defines CORE_AUTOSTART in Lich::Common' do
      expect(source).to match(/^\s+CORE_AUTOSTART\s*=\s*true\b/)
    end

    it 'is inside the Lich::Common module block' do
      lich_common_block = source[/module Lich\s+module Common.*?end\s+end/m]
      expect(lich_common_block).not_to be_nil
      expect(lich_common_block).to include('CORE_AUTOSTART')
    end
  end

  describe 'all sentinel constants' do
    it 'defines CORE_GET_SETTINGS' do
      expect(source).to match(/CORE_GET_SETTINGS\s*=\s*true/)
    end

    it 'defines CORE_SCRIPT_LOADER' do
      expect(source).to match(/CORE_SCRIPT_LOADER\s*=\s*true/)
    end

    it 'defines CORE_PARSE_ARGS' do
      expect(source).to match(/CORE_PARSE_ARGS\s*=\s*true/)
    end

    it 'defines all sentinels in the same module block' do
      lich_common_block = source[/module Lich\s+module Common.*?end\s+end/m]
      expect(lich_common_block).not_to be_nil, 'Could not extract module Lich::Common block from source'
      expect(lich_common_block).to include('CORE_GET_SETTINGS')
      expect(lich_common_block).to include('CORE_SCRIPT_LOADER')
      expect(lich_common_block).to include('CORE_PARSE_ARGS')
      expect(lich_common_block).to include('CORE_AUTOSTART')
    end
  end
end

RSpec.describe 'global_defs.rb built-in script commands' do
  def run_global_defs_probe(probe)
    root = File.expand_path('../..', __dir__)
    source = <<~RUBY
      require './spec/spec_helper'
      require 'common/detachable_client_registry'
      require './lib/global_defs'

      $lich_char_regex = /;/
      $clean_lich_char = ';'
      Object.const_set(:LICH_VERSION, 'test') unless Object.const_defined?(:LICH_VERSION)
      Lich.const_set(:MAX_DEBUG_LOGS_DEFAULT, 10) unless Lich.const_defined?(:MAX_DEBUG_LOGS_DEFAULT)
      XMLData.define_singleton_method(:game) { '' }
      UpstreamHook.define_singleton_method(:run) { |line| line }
      Object.send(:define_method, :respond) { |message = nil| puts("RESPOND:\#{message}") }
      Object.send(:define_method, :new_upstream) { |_line| nil }

      #{probe}
    RUBY
    Open3.capture3(RbConfig.ruby, "-I#{File.join(root, 'lib')}", '-e', source, :chdir => root)
  end

  it 'routes kd through forced script teardown' do
    stdout, stderr, status = run_global_defs_probe(<<~'RUBY')
      Script.define_singleton_method(:kill_all) do |force: false, context: :runtime|
        puts "KILL_ALL force=#{force} context=#{context}"
        1
      end
      do_client(';kd')
    RUBY

    expect(stderr).to be_empty
    expect(status).to be_success
    expect(stdout).to include('KILL_ALL force=true context=runtime')
  end

  it 'documents kd in built-in help' do
    stdout, stderr, status = run_global_defs_probe("do_client(';help')")

    expect(stderr).to be_empty
    expect(status).to be_success
    expect(stdout).to include('RESPOND:   ;kd')
    expect(stdout).to include('including protected and hidden scripts')
  end

  it 'uses the atomic Script#clear operation' do
    stdout, stderr, status = run_global_defs_probe(<<~'RUBY')
      script = Object.new
      script.define_singleton_method(:clear) do
        puts 'SCRIPT_CLEAR'
        %w[one two]
      end
      Script.define_singleton_method(:current) { script }
      puts "RESULT=#{clear.inspect}"
    RUBY

    expect(stderr).to be_empty
    expect(status).to be_success
    expect(stdout).to include('SCRIPT_CLEAR')
    expect(stdout).to include('RESULT=["one", "two"]')
  end
end

RSpec.describe '#detachable_client_frontend?' do
  # Subprocess for the same reason as the specs above: loading global_defs.rb
  # in-process redefines global methods. Returns the predicate for saga and
  # genie under the given ARGV and resolved Frontend.client.
  def frontend_flags(argv, client)
    root = File.expand_path('../..', __dir__)
    source = <<~RUBY
      require './spec/spec_helper'
      require 'common/detachable_client_registry'
      require './lib/global_defs'

      ARGV.replace(#{argv.inspect})
      Frontend.define_singleton_method(:client) { #{client.inspect} }
      puts "SAGA=\#{detachable_client_frontend?('saga')} GENIE=\#{detachable_client_frontend?('genie')}"
    RUBY
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-I#{File.join(root, 'lib')}", '-e', source, :chdir => root)
    expect(stderr).to be_empty
    expect(status).to be_success
    stdout[/^SAGA=.*$/]
  end

  it 'matches the literal --saga and --genie flags, case-insensitively' do
    expect(frontend_flags(%w[--SAGA --detachable-client=8000], 'wrayth')).to eq('SAGA=true GENIE=false')
    expect(frontend_flags(%w[--genie --detachable-client=8000], 'wrayth')).to eq('SAGA=false GENIE=true')
  end

  it 'matches the frontend resolved from --frontend= in --without-frontend mode' do
    expect(frontend_flags(%w[--frontend=saga --without-frontend --detachable-client=8000], 'saga')).to eq('SAGA=true GENIE=false')
    expect(frontend_flags(%w[--frontend=genie --without-frontend --detachable-client=8000], 'genie')).to eq('SAGA=false GENIE=true')
  end

  it 'ignores the resolved frontend outside --without-frontend mode' do
    # There the detachable client is a second frontend, not the one Frontend.client names.
    expect(frontend_flags(%w[--detachable-client=8000], 'saga')).to eq('SAGA=false GENIE=false')
  end

  it 'is false for other headless frontends' do
    expect(frontend_flags(%w[--without-frontend --detachable-client=8000], 'profanity')).to eq('SAGA=false GENIE=false')
  end
end

RSpec.describe '#handle_detachable_client' do
  # Runs the real handler in a subprocess (see above for why) so a spec fails if
  # it stops routing through detachable_client_frontend?. The two senders are
  # replaced with recorders, and the client disconnects at once so the read
  # loop ends straight away.
  def sends_on_attach(argv, client)
    root = File.expand_path('../..', __dir__)
    source = <<~RUBY
      require './spec/spec_helper'
      require 'common/detachable_client_registry'
      require './lib/global_defs'
      require 'common/shutdown_log'

      ARGV.replace(#{argv.inspect})
      Frontend.define_singleton_method(:client) { #{client.inspect} }
      $sent = Queue.new
      Object.send(:define_method, :detachable_client_send_init) { |_client| $sent << :init }
      Object.send(:define_method, :detachable_client_send_player_id) { |_client| $sent << :player_id }

      client = Object.new
      client.define_singleton_method(:gets) { nil }
      client.define_singleton_method(:close) { nil }
      before = Thread.list
      handle_detachable_client(client)
      (Thread.list - before).each { |thread| thread.join(5) }
      sent = []
      sent << $sent.pop until $sent.empty?
      puts "SENT=\#{sent.sort.inspect}"
    RUBY
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-I#{File.join(root, 'lib')}", '-e', source, :chdir => root)
    expect(stderr).to be_empty
    expect(status).to be_success
    stdout[/^SENT=(.*)$/, 1]
  end

  headless = %w[--without-frontend --detachable-client=8000]

  it 'sends Saga only the playerID re-emit for --frontend=saga in headless mode' do
    expect(sends_on_attach(['--frontend=saga', *headless], 'saga')).to eq('[:player_id]')
  end

  it 'sends Genie nothing for --frontend=genie in headless mode' do
    expect(sends_on_attach(['--frontend=genie', *headless], 'genie')).to eq('[]')
  end

  it 'sends the literal --saga flag only the playerID re-emit, as before' do
    expect(sends_on_attach(['--saga', *headless], 'saga')).to eq('[:player_id]')
  end

  it 'sends other headless frontends the init push' do
    expect(sends_on_attach(headless, 'profanity')).to eq('[:init]')
  end
end

# A client may send SET_FRONTEND_CAPS at any time to name the rich-stream
# rewrites it handles itself (docs/frontend-capability-declaration.md). The
# real handler runs in a subprocess, as above; the client's lines are scripted
# and every line that reaches dispatch is recorded.
RSpec.describe '#handle_detachable_client with SET_FRONTEND_CAPS' do
  def run_handler(lines)
    root = File.expand_path('../..', __dir__)
    source = <<~RUBY
      require './spec/spec_helper'
      require 'common/detachable_client_registry'
      require 'common/class_exts/synchronizedsocket'
      require 'common/client_capabilities'
      require './lib/global_defs'
      require 'common/shutdown_log'

      ARGV.replace(%w[--without-frontend --detachable-client=8000])
      Frontend.define_singleton_method(:client) { 'genie' }
      Object.send(:define_method, :detachable_client_send_init) { |_client| nil }
      Object.send(:define_method, :detachable_client_send_player_id) { |_client| nil }
      $dispatched = []
      Object.send(:define_method, :dispatch_client_input) { |line| $dispatched << line }
      module Lich
        module Main
          module UserExitDispatch
            def self.dispatch_detachable_client(*) = false
          end
        end
      end
      $cmd_prefix = '<c>'

      raw = Object.new
      lines = #{lines.inspect}
      raw.define_singleton_method(:gets) { lines.shift }
      raw.define_singleton_method(:closed?) { false }
      raw.define_singleton_method(:close) { nil }
      client = Lich::Common::SynchronizedSocket.new(raw, role: :detachable)
      before = Thread.list
      handle_detachable_client(client)
      (Thread.list - before).each { |thread| thread.join(5) }
      puts "DISPATCHED=\#{$dispatched.inspect}"
      puts "DECLARED=\#{client.declared_capabilities.inspect}"
    RUBY
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-I#{File.join(root, 'lib')}", '-e', source, :chdir => root)
    # Bundler's notes about gems built for another Ruby are not errors.
    expect(stderr.lines.reject { |line| line.include?('Bundler::StubSpecification') }.join).to be_empty
    expect(status).to be_success
    [stdout[/^DISPATCHED=(.*)$/, 1], stdout[/^DECLARED=(.*)$/, 1]]
  end

  it 'records the declaration on that client and never sends it to the game' do
    dispatched, declared = run_handler(["SET_FRONTEND_CAPS room_element game_links double_bold\n", "look\n"])
    expect(dispatched).to eq('["<c>look\\n"]')
    expect(declared).to eq('[:room_element, :game_links, :double_bold]')
  end

  it 'takes a later declaration over an earlier one' do
    dispatched, declared = run_handler(["SET_FRONTEND_CAPS game_links\n", "look\n", "SET_FRONTEND_CAPS\n"])
    expect(dispatched).to eq('["<c>look\\n"]')
    expect(declared).to eq('[]')
  end

  it 'leaves a client that never declares undeclared' do
    dispatched, declared = run_handler(["look\n"])
    expect(dispatched).to eq('["<c>look\\n"]')
    expect(declared).to eq('nil')
  end
end

RSpec.describe '#detachable_client_send_init' do
  # Only the shared part lives in global_defs.rb: waiting until the running
  # game's module reports the login feed is ready, then sending its push. What
  # ready? checks and what the push contains are covered per game in
  # spec/lib/gemstone/detachable_client_init_spec.rb and
  # spec/lib/dragonrealms/detachable_client_init_spec.rb.
  #
  # Runs in a subprocess for the same reason as the built-in script command
  # specs above: loading global_defs.rb in-process redefines global methods.
  # sleep is replaced with a counter so the wait loop runs instantly. A
  # stand-in DetachableClientInit replaces the game module; the *_after_sleeps
  # options say after how many sleeps it becomes defined or ready (0 means from
  # the start, nil means never).
  def run_send_init(module_after_sleeps: 0, ready_after_sleeps: 0)
    root = File.expand_path('../..', __dir__)
    source = <<~RUBY
      require './spec/spec_helper'
      require 'common/detachable_client_registry'
      require './lib/global_defs'

      Object.const_set(:LICH_VERSION, 'test') unless Object.const_defined?(:LICH_VERSION)
      Lich.define_singleton_method(:log) { |message| puts "LOG:\#{message}" }

      $stand_in_ready = false
      stand_in = Module.new do
        def self.ready? = $stand_in_ready
        def self.init_string = '<init/>'
      end
      module_after_sleeps = #{module_after_sleeps.inspect}
      ready_after_sleeps = #{ready_after_sleeps.inspect}
      Object.const_set(:DetachableClientInit, stand_in) if module_after_sleeps == 0
      $stand_in_ready = true if ready_after_sleeps == 0

      sleeps = 0
      Object.send(:define_method, :sleep) do |_seconds|
        sleeps += 1
        Object.const_set(:DetachableClientInit, stand_in) if sleeps == module_after_sleeps
        $stand_in_ready = true if sleeps == ready_after_sleeps
      end

      client = Object.new
      client.define_singleton_method(:puts_main_stream) { |line| puts "SENT:\#{line}" }
      detachable_client_send_init(client)
      puts "SLEEPS=\#{sleeps}"
    RUBY
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-I#{File.join(root, 'lib')}", '-e', source, :chdir => root)
    expect(stderr).to be_empty
    expect(status).to be_success
    {
      :sent   => stdout[/^SENT:(.*)$/, 1],
      :log    => stdout[/^LOG:(.*)$/, 1],
      :sleeps => stdout[/^SLEEPS=(\d+)$/, 1].to_i,
    }
  end

  it 'sends the running game module push without waiting when it is already ready' do
    result = run_send_init

    expect(result[:sleeps]).to eq(0)
    expect(result[:sent]).to eq('<init/>')
  end

  describe 'waiting for the login feed' do
    it 'stops waiting as soon as the game module reports ready' do
      result = run_send_init(:ready_after_sleeps => 3)

      expect(result[:sleeps]).to eq(3)
      expect(result[:sent]).to eq('<init/>')
    end

    it 'keeps waiting until the game module has been loaded' do
      result = run_send_init(:module_after_sleeps => 4)

      expect(result[:sleeps]).to eq(4)
      expect(result[:sent]).to eq('<init/>')
    end

    it 'still sends the push after giving up on a feed that never becomes ready' do
      result = run_send_init(:ready_after_sleeps => nil)

      expect(result[:sleeps]).to eq(100)
      expect(result[:sent]).to eq('<init/>')
    end
  end

  it 'skips the push and logs when the game modules were never loaded' do
    result = run_send_init(:module_after_sleeps => nil)

    expect(result[:sleeps]).to eq(100)
    expect(result[:sent]).to be_nil
    expect(result[:log]).to include('game modules not loaded')
  end
end

# waitrt? / waitcastrt? - loaded from lib/global_defs.rb as above. Two
# contracts: with no options the legacy call (one sleep, then whether
# roundtime REMAINS), unchanged for every existing caller; with an
# interrupt or a cap the bounded call (poll in slices, whether there WAS
# roundtime to wait out).
RSpec.describe '#waitrt?' do
  GlobalDefsSpecSource.define(self, 'waitrt?')

  before do
    allow(Script).to receive(:execution_sleep) { |seconds| sleep(seconds) }
  end

  it 'runs the waitrt? defined in lib/global_defs.rb' do
    expect(method(:waitrt?).source_location).to eq([GlobalDefsSpecSource::PATH, GlobalDefsSpecSource.line_of('waitrt?')])
  end

  it 'legacy: sleeps once and reports whether roundtime remains' do
    allow(self).to receive(:checkrt).and_return(0.0)
    expect(waitrt?).to be(false)
    left = [8.0, 0.0]
    allow(self).to receive(:checkrt) { left.first }
    allow(self).to receive(:sleep) { left.shift }
    expect(waitrt?).to be(false) # slept the 8 out, nothing remains
    expect(left).to eq([0.0])
  end

  it 'legacy: roundtime that outlasts the one sleep reads as still present' do
    allow(self).to receive(:checkrt).and_return(8.0)
    sleeps = []
    allow(self).to receive(:sleep) { |n| sleeps << n }
    expect(waitrt?).to be(true)
    expect(sleeps).to eq([8.0]) # one sleep, no polling
  end

  it 'bounded: waits a roundtime out in slices and reports there was one' do
    left = [0.25, 0.15, 0.05, 0.0]
    sleeps = []
    allow(self).to receive(:checkrt) { left.first }
    allow(self).to receive(:sleep) do |n|
      sleeps << n
      left.shift
    end
    expect(waitrt?(cap: 60)).to be(true)
    expect(left).to eq([0.0])
    # tenth-second slices, the last one cut to the roundtime left
    expect(sleeps).to eq([0.1, 0.1, 0.05])
    allow(self).to receive(:checkrt).and_return(0.0)
    expect(waitrt?(cap: 60)).to be(false)
  end

  it 'ends early on the interrupt' do
    allow(self).to receive(:checkrt).and_return(5.0)
    calls = 0
    allow(self).to receive(:sleep) { raise "still waiting after #{calls} sleeps" if (calls += 1) > 100 }
    expect(waitrt?(interrupt: -> { calls >= 2 })).to be(true)
    expect(calls).to eq(2)
  end

  it 'ends at the cap' do
    allow(self).to receive(:checkrt).and_return(5.0)
    now = Time.now
    ticks = 0
    allow(Time).to receive(:now) { now + ticks }
    allow(self).to receive(:sleep) { raise "still waiting after #{ticks} sleeps" if (ticks += 1) > 100 }
    expect(waitrt?(cap: 3)).to be(true)
    expect(ticks).to eq(3)
  end
end

RSpec.describe '#waitcastrt?' do
  GlobalDefsSpecSource.define(self, 'waitcastrt?')

  before do
    allow(Script).to receive(:execution_sleep) { |seconds| sleep(seconds) }
  end

  it 'runs the waitcastrt? defined in lib/global_defs.rb' do
    expect(method(:waitcastrt?).source_location).to eq([GlobalDefsSpecSource::PATH, GlobalDefsSpecSource.line_of('waitcastrt?')])
  end

  it 'legacy: one sleep of the whole cast roundtime, true when there was one' do
    allow(self).to receive(:checkcastrt).and_return(3.0)
    sleeps = []
    allow(self).to receive(:sleep) { |n| sleeps << n }
    expect(waitcastrt?).to be(true)
    expect(sleeps).to eq([3.0])
    allow(self).to receive(:checkcastrt).and_return(0)
    expect(waitcastrt?).to be(false)
  end

  it 'bounded: ends early on the interrupt' do
    allow(self).to receive(:checkcastrt).and_return(3.0)
    calls = 0
    allow(self).to receive(:sleep) { raise "still waiting after #{calls} sleeps" if (calls += 1) > 100 }
    expect(waitcastrt?(interrupt: -> { calls >= 1 })).to be(true)
    expect(calls).to eq(1)
  end

  it 'bounded: waits in tenth-second slices and ends at the cap' do
    allow(self).to receive(:checkcastrt).and_return(3.0)
    now = Time.now
    ticks = 0
    allow(Time).to receive(:now) { now + ticks }
    sleeps = []
    allow(self).to receive(:sleep) do |n|
      sleeps << n
      raise "still waiting after #{ticks} sleeps" if (ticks += 1) > 100
    end
    expect(waitcastrt?(cap: 3)).to be(true)
    expect(sleeps).to eq([0.1, 0.1, 0.1])
  end

  it 'reads a nil cast roundtime as none, in both contracts' do
    allow(self).to receive(:checkcastrt).and_return(nil)
    expect(self).not_to receive(:sleep)
    expect(waitcastrt?).to be(false)
    expect(waitcastrt?(cap: 5)).to be(false)
  end
end
