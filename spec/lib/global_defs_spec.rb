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
# Instead, we define fput/multifput directly in the describe block so they
# are scoped to this example group and resolve stubs via normal method lookup.

RSpec.describe '#fput' do
  # Production fput - mirrors lib/global_defs.rb exactly.
  # Defined locally to avoid polluting the global method table.
  def fput(message, *waitingfor)
    unless (script = Script.current) then respond('--- waitfor: Unable to identify calling script.'); return false; end
    waitingfor.flatten!

    # Options via a trailing Hash argument: fput('cmd', 'pattern', timeout: 30)
    #   timeout:          seconds with no game response before giving up (60;
    #                     0 disables, the original behavior)
    #   max_resends:      how many times a refusal ("...wait 3", "struggle to
    #                     stand", stunned) may trigger a resend before giving
    #                     up (nil, the original: unbounded)
    #   interrupt:        a callable checked on every wait; true ends the
    #                     send at once (nil: never)
    #   resend_transient: on a transient refusal that is not a stun or a
    #                     web (a "can't seem", "don't seem"), resend after a
    #                     quarter second instead of giving up (false, the
    #                     original; bigshot's bs_put resends)
    #   failures:         :false (the original: every failure returns false)
    #                     or :symbol - :no_response, :too_many_resends,
    #                     :interrupted, :dead, :refused - so a caller can
    #                     tell them apart
    options = (waitingfor.pop if waitingfor.last.is_a?(Hash)) || {}
    option = ->(key) { options[key] || options[key.to_s] }
    timeout = option.call(:timeout) || 60
    max_resends = option.call(:max_resends)
    interrupt = option.call(:interrupt)
    resend_transient = option.call(:resend_transient) ? true : false
    symbols = option.call(:failures) == :symbol
    fail_with = ->(reason) { symbols ? reason : false }
    interrupted = -> { interrupt && interrupt.call ? true : false }
    # With an interrupt, sleep in slices so it lands within a tenth of a
    # second; without one, the plain sleep of before. True when interrupted.
    wait = lambda do |seconds|
      if interrupt.nil?
        sleep(seconds)
        return false
      end
      slices = (seconds / 0.1).ceil
      slices.times do
        return true if interrupted.call

        sleep(0.1)
      end
      false
    end
    resends = 0
    # a refusal that asks for a resend: false when the cap allows it
    over_cap = lambda do
      resends += 1
      !max_resends.nil? && resends > max_resends
    end

    clear
    put(message)

    timer = Time.now
    loop do
      string = get?

      if string.nil?
        return fail_with.call(:interrupted) if interrupted.call

        if timeout > 0 && (Time.now - timer > timeout)
          echo "fput: No game response for #{timeout}s to '#{message}'"
          return fail_with.call(:no_response)
        end
        pause 0.1
        next
      end

      timer = Time.now # Reset timeout on any game response

      if string =~ /(?:\.\.\.wait |Wait )(?<wait_time>[0-9]+)/
        return fail_with.call(:too_many_resends) if over_cap.call

        hold_up = Regexp.last_match[:wait_time].to_i
        return fail_with.call(:interrupted) if wait.call(hold_up)

        clear
        put(message)
        next
      elsif string =~ /^You.+struggle.+stand/
        return fail_with.call(:too_many_resends) if over_cap.call

        clear
        stood = fput('stand', options)
        return stood if symbols && stood.is_a?(Symbol)

        next
      elsif string =~ /stunned|can't do that while|cannot seem|^(?!You rummage).*can't seem|don't seem|Sorry, you may only type ahead/
        if dead?
          echo "You're dead...! You can't do that!"
          sleep 1
          script.downstream_buffer.unshift(string)
          return fail_with.call(:dead)
        elsif checkstunned
          while checkstunned
            return fail_with.call(:interrupted) if interrupted.call

            sleep("0.25".to_f)
          end
        elsif checkwebbed
          while checkwebbed
            return fail_with.call(:interrupted) if interrupted.call

            sleep("0.25".to_f)
          end
        elsif string =~ /Sorry, you may only type ahead/
          sleep 1
        elsif resend_transient
          sleep 0.25
        else
          sleep 0.1
          script.downstream_buffer.unshift(string)
          return fail_with.call(:refused)
        end
        return fail_with.call(:too_many_resends) if over_cap.call

        clear
        put(message)
        next
      else
        if waitingfor.empty?
          script.downstream_buffer.unshift(string)
          return string
        else
          if (foundit = waitingfor.find { |val| string =~ /#{val}/i })
            script.downstream_buffer.unshift(string)
            return foundit
          end
          return fail_with.call(:too_many_resends) if over_cap.call
          return fail_with.call(:interrupted) if wait.call(1)

          clear
          put(message)
          next
        end
      end
    end
  end

  def multifput(*cmds)
    cmds.flatten.compact.each { |cmd| fput(cmd) }
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

  # Stub get? to always return nil and stub pause to avoid real waits
  def stub_no_game_responses
    allow(self).to receive(:get?).and_return(nil)
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
  end

  describe 'timeout behavior' do
    it 'times out after default 60 seconds with no game response' do
      stub_no_game_responses
      stub_elapsed_time(61)

      expect(self).to receive(:echo).with(/No game response for 60s/)

      result = fput('test command')

      expect(result).to eq(false)
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
        when 5, 6   then frozen_time + 55   # 25s since reset (under 60s)
        else frozen_time + 55
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

# waitrt? / waitcastrt? with an interrupt and a cap - mirrored from
# lib/global_defs.rb for the reason given at the top of this file.
RSpec.describe '#waitrt?' do
  def waitrt?(interrupt: nil, cap: nil)
    had_rt = checkrt > 0.0
    stop_at = cap ? Time.now + cap : nil
    while checkrt > 0.0
      return had_rt if interrupt && interrupt.call
      return had_rt if stop_at && Time.now >= stop_at

      sleep([checkrt, 0.1].min)
    end
    had_rt
  end

  it 'returns false with no roundtime and true after waiting one out' do
    allow(self).to receive(:checkrt).and_return(0.0)
    expect(waitrt?).to be(false)
    left = [0.25, 0.15, 0.05, 0.0]
    allow(self).to receive(:checkrt) { left.first }
    allow(self).to receive(:sleep) { left.shift }
    expect(waitrt?).to be(true)
    expect(left).to eq([0.0])
  end

  it 'ends early on the interrupt' do
    allow(self).to receive(:checkrt).and_return(5.0)
    calls = 0
    allow(self).to receive(:sleep) { calls += 1 }
    expect(waitrt?(interrupt: -> { calls >= 2 })).to be(true)
    expect(calls).to eq(2)
  end

  it 'ends at the cap' do
    allow(self).to receive(:checkrt).and_return(5.0)
    now = Time.now
    ticks = 0
    allow(Time).to receive(:now) { now + ticks }
    allow(self).to receive(:sleep) { ticks += 1 }
    expect(waitrt?(cap: 3)).to be(true)
    expect(ticks).to eq(3)
  end
end
