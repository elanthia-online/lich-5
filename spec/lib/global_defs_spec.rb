# frozen_string_literal: true

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
  # Production fput — mirrors lib/global_defs.rb exactly.
  # Defined locally to avoid polluting the global method table.
  def fput(message, *waitingfor)
    unless (script = Script.current) then respond('--- waitfor: Unable to identify calling script.'); return false; end
    waitingfor.flatten!

    options = (waitingfor.pop if waitingfor.last.is_a?(Hash)) || {}
    timeout = options[:timeout] || options['timeout'] || 60

    clear
    put(message)

    timer = Time.now
    loop do
      string = get?

      if string.nil?
        if timeout > 0 && (Time.now - timer > timeout)
          echo "fput: No game response for #{timeout}s to '#{message}'"
          return false
        end
        pause 0.1
        next
      end

      timer = Time.now

      if string =~ /(?:\.\.\.wait |Wait )(?<wait_time>[0-9]+)/
        hold_up = Regexp.last_match[:wait_time].to_i
        sleep(hold_up) unless hold_up.nil?
        clear
        put(message)
        next
      elsif string =~ /^You.+struggle.+stand/
        clear
        fput 'stand'
        next
      elsif string =~ /stunned|can't do that while|cannot seem|^(?!You rummage).*can't seem|don't seem|Sorry, you may only type ahead/
        if dead?
          echo "You're dead...! You can't do that!"
          sleep 1
          script.downstream_buffer.unshift(string)
          return false
        elsif checkstunned
          while checkstunned
            sleep("0.25".to_f)
          end
        elsif checkwebbed
          while checkwebbed
            sleep("0.25".to_f)
          end
        elsif string =~ /Sorry, you may only type ahead/
          sleep 1
        else
          sleep 0.1
          script.downstream_buffer.unshift(string)
          return false
        end
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
          sleep 1
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
      # nil, nil → unmatched response (resets timer) → nil, nil → matching response
      responses = [nil, nil, 'Some unmatched text.', nil, nil, 'Expected match.']
      resp_index = 0
      allow(self).to receive(:get?) do
        r = responses[resp_index]
        resp_index += 1
        r
      end
      allow(self).to receive(:pause)
      allow(self).to receive(:sleep)

      # Time progresses: 30s before response, then 25s after reset — never exceeds 60s window
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

      expect { multifput('cmd1', 'cmd2') }.not_to raise_error
    end
  end
end
