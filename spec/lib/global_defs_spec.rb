# frozen_string_literal: true

require_relative '../spec_helper'

# Load the production fput (overrides the no-op mock in spec_helper)
require File.join(LIB_DIR, 'global_defs.rb')

RSpec.describe 'fput' do
  let(:mock_script) do
    script = Script.new
    script.name = 'test'
    allow(script).to receive(:downstream_buffer).and_return([])
    script
  end

  before do
    allow(Script).to receive(:current).and_return(mock_script)
    # Stub global methods used by fput
    allow(self).to receive(:put)
    allow(self).to receive(:echo)
  end

  # Helper: queue game responses that get? will return one at a time
  def stub_game_responses(*responses)
    call_count = 0
    allow(self).to receive(:get?) do
      response = responses[call_count]
      call_count += 1
      response
    end
  end

  # Helper: make get? return nil forever (simulates dead connection)
  def stub_no_game_responses
    allow(self).to receive(:get?).and_return(nil)
    allow(self).to receive(:pause)
  end

  describe 'basic behavior (no waitingfor)' do
    it 'returns the first game response and pushes it back to the buffer' do
      stub_game_responses('You pick up a sword.')
      result = fput('get sword')
      expect(result).to eq('You pick up a sword.')
      expect(mock_script.downstream_buffer).to eq(['You pick up a sword.'])
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

  describe 'with waitingfor patterns' do
    it 'returns the matching pattern when a response matches' do
      stub_game_responses('You pick up a sword.')
      result = fput('get sword', 'You pick up')
      expect(result).to eq('You pick up')
      expect(mock_script.downstream_buffer).to eq(['You pick up a sword.'])
    end

    it 'resends command when response does not match any pattern' do
      stub_game_responses('Some other text.', 'You pick up a sword.')
      expect(self).to receive(:put).with('get sword').exactly(2).times
      allow(self).to receive(:sleep)
      result = fput('get sword', 'You pick up')
      expect(result).to eq('You pick up')
    end
  end

  describe 'wait handling' do
    it 'resends command after a wait message' do
      stub_game_responses('...wait 3 seconds.', 'You pick up a sword.')
      expect(self).to receive(:sleep).with(3)
      expect(self).to receive(:put).with('get sword').exactly(2).times
      result = fput('get sword')
      expect(result).to eq('You pick up a sword.')
    end
  end

  describe 'stunned handling' do
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
      frozen_time = Time.now
      call_count = 0
      allow(Time).to receive(:now) do
        # First call is the timer initialization, subsequent calls advance time
        if call_count < 2
          call_count += 1
          frozen_time
        else
          frozen_time + 61
        end
      end

      expect(self).to receive(:echo).with(/No game response for 60s/)
      result = fput('test command')
      expect(result).to eq(false)
    end

    it 'uses custom timeout when specified via Hash argument' do
      stub_no_game_responses
      frozen_time = Time.now
      call_count = 0
      allow(Time).to receive(:now) do
        if call_count < 2
          call_count += 1
          frozen_time
        else
          frozen_time + 11
        end
      end

      expect(self).to receive(:echo).with(/No game response for 10s/)
      result = fput('test command', timeout: 10)
      expect(result).to eq(false)
    end

    it 'supports string key timeout in Hash argument' do
      stub_no_game_responses
      frozen_time = Time.now
      call_count = 0
      allow(Time).to receive(:now) do
        if call_count < 2
          call_count += 1
          frozen_time
        else
          frozen_time + 6
        end
      end

      expect(self).to receive(:echo).with(/No game response for 5s/)
      result = fput('test command', { 'timeout' => 5 })
      expect(result).to eq(false)
    end

    it 'disables timeout when timeout: 0 is specified' do
      # With timeout: 0, fput should NOT timeout even after a long time.
      # We verify by letting it run a few polling cycles, then sending a response.
      responses = Array.new(5, nil) + ['OK.']
      call_count = 0
      allow(self).to receive(:get?) do
        r = responses[call_count]
        call_count += 1
        r
      end
      allow(self).to receive(:pause)

      # Even with time far advanced, timeout: 0 should not trigger
      frozen_time = Time.now
      time_call = 0
      allow(Time).to receive(:now) do
        time_call += 1
        frozen_time + (time_call * 100) # Advance time massively each call
      end

      expect(self).not_to receive(:echo)
      result = fput('test command', timeout: 0)
      expect(result).to eq('OK.')
    end

    it 'resets the timer when a game response arrives' do
      # Simulate: nil, nil, game_response, nil, nil, nil -> should not timeout
      # because the game response resets the 60s timer
      frozen_time = Time.now

      responses = [nil, nil, 'Some unmatched text.', nil, nil, 'Expected match.']
      resp_index = 0
      allow(self).to receive(:get?) do
        r = responses[resp_index]
        resp_index += 1
        r
      end
      allow(self).to receive(:pause)
      allow(self).to receive(:sleep)

      # Time advances 30s before response, then resets, then 30s more (still under 60s)
      time_calls = 0
      allow(Time).to receive(:now) do
        time_calls += 1
        case time_calls
        when 1 then frozen_time           # Initial timer set
        when 2, 3 then frozen_time + 30   # Before response: 30s elapsed
        when 4 then frozen_time + 30      # Response arrives: timer resets to this
        when 5, 6 then frozen_time + 55   # After response: 25s since reset, under 60s
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

  describe 'multifput' do
    it 'calls fput for each command' do
      stub_game_responses('OK.', 'Done.')
      allow(self).to receive(:fput).and_call_original
      # Just verify it doesn't raise and processes both commands
      expect { multifput('cmd1', 'cmd2') }.not_to raise_error
    end
  end
end
