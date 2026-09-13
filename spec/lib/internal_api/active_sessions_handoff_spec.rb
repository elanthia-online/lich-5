# frozen_string_literal: true

require 'json'
require 'rbconfig'
require_relative '../../spec_helper'

RSpec.describe 'Native ActiveSessions process handoff' do
  # Test deadlines bound orchestration failures, not a production availability
  # SLA. No child boots Lich/game state, and every PID comes from Process.spawn.
  let(:child_deadline) { 5 }
  let(:handoff_child_path) { File.expand_path('../../support/coordination_handoff_child.rb', __dir__) }

  before do
    @handoff_dir = Dir.mktmpdir('active-sessions-handoff')
    @children = []
  end

  after do
    @children.each do |child|
      child[:input].close unless child[:input].closed?
    end
    @children.each do |child|
      reap_child(child, force: true) unless child[:status]
      child[:output].close unless child[:output].closed?
      expect(child[:status]).to be_a(Process::Status)
    end
    FileUtils.remove_entry(@handoff_dir)
  end

  def start_child
    child_input, parent_input = IO.pipe
    parent_output, child_output = IO.pipe
    child = { input: parent_input, output: parent_output, log: File.join(@handoff_dir, "child-#{@children.length}.log") }
    child[:pid] = Process.spawn(RbConfig.ruby, handoff_child_path, @handoff_dir,
                                in: child_input, out: child_output, err: child[:log], close_others: true)
    @children << child
    child_input.close
    child_output.close
    expect(receive(child, 'ready')['pid']).to eq(child[:pid])
    child
  end

  def send_command(child, command)
    child[:input].puts(command)
    child[:input].flush
  end

  def receive(child, event)
    unless IO.select([child[:output]], nil, nil, child_deadline)
      raise "child #{child[:pid]} timed out waiting for #{event}: #{File.read(child[:log])}"
    end
    line = child[:output].gets
    raise "child #{child[:pid]} exited waiting for #{event}: #{File.read(child[:log])}" unless line

    payload = JSON.parse(line)
    expect(payload.fetch('event')).to eq(event)
    payload
  end

  def command(child, request, event = request)
    send_command(child, request)
    receive(child, event)
  end

  def reap_child(child, force: false)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + child_deadline
    loop do
      result = Process.waitpid2(child[:pid], Process::WNOHANG)
      return child[:status] = result.last if result

      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.01
    end
    raise "child #{child[:pid]} failed to exit" unless force

    Process.kill('KILL', child[:pid])
    child[:status] = Process.waitpid2(child[:pid]).last
  end

  def kill_child(child)
    Process.kill('KILL', child[:pid])
    expect(reap_child(child).termsig).to eq(Signal.list.fetch('KILL'))
  end

  def discovery
    JSON.parse(File.read(File.join(@handoff_dir, 'lich-active-sessions.json')))
  end

  def expect_available(reader, owner)
    sample = command(reader, 'sample')
    expect(sample['snapshot']).not_to have_key('error')
    expect(sample.dig('snapshot', 'source')).to eq('ActiveSessionsAPI')
    expect(sample.dig('observation', 'record', 'owner_pid')).to eq(owner[:pid])
    expect(sample['elapsed']).to be < child_deadline
    sample
  end

  def expect_unavailable(reader)
    sample = command(reader, 'sample')
    expect(sample.dig('snapshot', 'error')).to be_a(String)
    expect(sample.dig('snapshot', 'sessions')).to eq([])
    expect(sample['owns_lock']).to be(false)
    expect(sample['owns_server']).to be(false)
    expect(sample['elapsed']).to be < child_deadline
    sample
  end

  it 'recovers a killed published owner with two contenders and a concurrent discovery reader' do
    owner, first, second, reader = Array.new(4) { start_child }
    expect(command(owner, 'ensure', 'ensured')['available']).to be(true)
    original = discovery
    command(reader, 'watch', 'watching')
    expect_available(reader, owner) # Cache original endpoint credentials in this reader.
    kill_child(owner)
    expect_unavailable(reader)
    expect(discovery).to eq(original)

    [first, second].each { |child| command(child, 'arm_publication', 'armed') }
    [first, second].each { |child| send_command(child, 'ensure') }
    # The native flock selects which contender reaches real File.rename.
    ready = IO.select([first[:output], second[:output]], nil, nil, child_deadline)
    expect(ready).not_to be_nil
    initial = ready.first.first == first[:output] ? first : second
    event = JSON.parse(initial[:output].gets)
    winner, loser = event['event'] == 'publication_pending' ? [initial, ([first, second] - [initial]).first] : [([first, second] - [initial]).first, initial]
    if initial == winner
      expect(receive(loser, 'ensured')['available']).to be(false)
    else
      expect(event['event']).to eq('ensured')
      expect(event['available']).to be(false)
      receive(winner, 'publication_pending')
    end
    expect(command(loser, 'state').values_at('owns_lock', 'owns_server')).to eq([false, false])
    expect_unavailable(reader)
    expect(discovery).to eq(original)
    send_command(winner, 'release')
    expect(receive(winner, 'ensured')['available']).to be(true)
    expect(command(loser, 'ensure', 'ensured')['available']).to be(true)
    expect(command(winner, 'state').values_at('owns_lock', 'owns_server')).to eq([true, true])
    expect(command(loser, 'state').values_at('owns_lock', 'owns_server')).to eq([false, false])
    expect_available(reader, winner)
    expect(discovery['auth_token']).not_to eq(original['auth_token'])
    command(loser, 'stop', 'stopped')
    expect_available(reader, winner)
    observation = command(reader, 'observations')
    expect(observation['reads']).to be_positive
    expect(observation['malformed']).to eq(0)
    expect(observation['owners'] - [owner[:pid], winner[:pid]]).to eq([])
  end

  [false, true].each do |stale_record|
    it "recovers death immediately before publication with #{stale_record ? 'a stale complete' : 'no'} discovery record" do
      reader = start_child
      original = nil
      if stale_record
        previous = start_child
        expect(command(previous, 'ensure', 'ensured')['available']).to be(true)
        original = discovery
        kill_child(previous)
      end
      doomed, successor = Array.new(2) { start_child }
      command(reader, 'watch', 'watching')
      command(doomed, 'arm_publication', 'armed')
      send_command(doomed, 'ensure')
      receive(doomed, 'publication_pending')
      temp_path = File.join(@handoff_dir, "lich-active-sessions.json.#{doomed[:pid]}.tmp")
      expect(JSON.parse(File.read(temp_path))['owner_pid']).to eq(doomed[:pid])
      sample = expect_unavailable(reader)
      expect(sample['observation']).to eq(stale_record ? { 'record' => original, 'malformed' => false } : { 'missing' => true })
      expect(command(successor, 'ensure', 'ensured')['available']).to be(false)
      kill_child(doomed)
      expect_unavailable(reader)
      expect(command(successor, 'ensure', 'ensured')['available']).to be(true)
      expect_available(reader, successor)
      expect(command(reader, 'observations')['malformed']).to eq(0)
      # SIGKILL cannot run the publisher's ensure; the orphan is ignored.
      expect(File.exist?(temp_path)).to be(true)
    end
  end

  it 'does not let retiring-owner cleanup unlink a successor publication' do
    owner, successor, reader = Array.new(3) { start_child }
    expect(command(owner, 'ensure', 'ensured')['available']).to be(true)
    command(owner, 'arm_cleanup', 'armed')
    send_command(owner, 'stop')
    receive(owner, 'cleanup_pending')
    # A safe implementation may retain the native flock throughout cleanup;
    # otherwise a published successor must survive the retiring owner's unlink.
    replaced_while_cleanup_pending = command(successor, 'ensure', 'ensured')['available']
    expect_available(reader, successor) if replaced_while_cleanup_pending
    send_command(owner, 'release')
    receive(owner, 'stopped')
    unless replaced_while_cleanup_pending
      expect(command(successor, 'ensure', 'ensured')['available']).to be(true)
    end
    expect_available(reader, successor)
  end
end
