# frozen_string_literal: true

require 'timeout'
require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# Lich::Genie::TriggerWorker: the glue's stand-in for Remix's trigger-Channel consumer
# (FormMain.cs:138-151, 343, 6592-6597 R) -- one thread, jobs in FIFO order.
RSpec.describe Lich::Genie::TriggerWorker do
  let(:reports) { Thread::Queue.new }
  let(:worker) { described_class.new(report: ->(e) { reports << e }) }

  after { worker.instance_variable_get(:@thread)&.kill }

  def settle(target = worker)
    Timeout.timeout(5) { Thread.pass until target.idle? }
  end

  it 'runs the posted jobs in order, one at a time, on one thread that is not the poster' do
    seen = []
    threads = []
    gate = Thread::Queue.new
    worker.post { gate.pop } # the first job holds the others back
    5.times do |i|
      worker.post do
        seen << i
        threads << Thread.current
      end
    end
    expect(seen).to eq([])
    gate << :go
    settle
    expect(seen).to eq([0, 1, 2, 3, 4])
    expect(threads.uniq.length).to eq(1)
    expect(threads.first).not_to equal(Thread.current)
    expect(threads.first.name).to eq(described_class::THREAD_NAME)
  end

  it 'marks its thread as an engine host thread (a launch there waits for the first run)' do
    flags = Thread::Queue.new
    worker.post { flags << [Thread.current[described_class::HOST_THREAD_KEY], worker.on_worker?] }
    expect(Timeout.timeout(5) { flags.pop }).to eq([true, true])
    expect([Thread.current[described_class::HOST_THREAD_KEY], worker.on_worker?]).to eq([nil, false])
  end

  it 'reports a job that raises -- a ScriptError or a stack overflow too -- and runs the next one' do
    done = []
    worker.post { raise ArgumentError, 'bad body' }
    worker.post { raise NotImplementedError, 'script error' }
    worker.post { raise SystemStackError, 'deep' }
    worker.post { done << :next }
    settle
    expect(Array.new(3) { reports.pop.message }).to eq(['bad body', 'script error', 'deep'])
    expect(done).to eq([:next])
  end

  it 'survives a report that raises' do
    loud = described_class.new(report: ->(_e) { raise 'report broke' })
    done = []
    loud.post { raise 'job broke' }
    loud.post { done << :next }
    settle(loud)
    expect(done).to eq([:next])
  ensure
    loud&.instance_variable_get(:@thread)&.kill
  end

  it 'replaces a dead thread on the next post, keeping the jobs queued meanwhile' do
    worker.post { nil }
    settle
    first = worker.instance_variable_get(:@thread)
    first.kill
    first.join
    expect(worker.alive?).to be(false)
    done = []
    worker.post { done << :after }
    settle
    expect([done, worker.alive?]).to eq([[:after], true])
    expect(worker.instance_variable_get(:@thread)).not_to equal(first)
  end

  it 'leaves the starter\'s ThreadGroup (Lich kills a script\'s group with the script)' do
    group = ThreadGroup.new
    starter = Thread.new do
      Thread.stop
      worker.post { nil }
    end
    Timeout.timeout(5) { Thread.pass until starter.stop? }
    group.add(starter)
    starter.run
    starter.join
    settle
    expect(worker.instance_variable_get(:@thread).group).to eq(ThreadGroup::Default)
  end

  it 'refuses a post with no job' do
    expect { worker.post }.to raise_error(ArgumentError)
  end
end
