# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/upstream_gate'

RSpec.describe Lich::Common::UpstreamGate do
  let(:prompt) { %(<prompt time="1">&gt;</prompt>\r\n) }

  subject(:gate) { described_class.new(expiry: expiry) }

  let(:expiry) { 30 }
  let(:sent) { Queue.new }

  after { gate.stop }

  def primed_gate
    gate.observe(prompt)
    gate
  end

  # Non-waiting submit, as from the client or a game thread.
  def send_async(cmd)
    gate.submit(cmd, wait: false) { sent << cmd; true }
  end

  def drain
    out = []
    out << sent.pop until sent.empty?
    out
  end

  # Wait for the gate thread to release whatever it is going to.
  def settle
    sleep 0.05
  end

  describe '.exempt?' do
    it 'exempts underscore, blank and raw XML lines' do
      %w[_injury\ 2 <c>_flag\ X\ 0 <c> <db><settings/>].each do |cmd|
        expect(described_class.exempt?(cmd)).to be(true), cmd
      end
      expect(described_class.exempt?('')).to be(true)
    end

    it 'counts ordinary commands, including <c>-prefixed ones' do
      expect(described_class.exempt?('<c>bank account')).to be(false)
      expect(described_class.exempt?('north')).to be(false)
    end
  end

  it 'passes everything straight through before the first prompt' do
    5.times { |i| send_async("login#{i}") }
    expect(drain).to eq(%w[login0 login1 login2 login3 login4])
  end

  it 'holds commands beyond the window and releases one per prompt, in order' do
    primed_gate
    %w[n e s w up].each { |c| send_async(c) }
    settle
    expect(drain).to eq(%w[n e])

    gate.observe(prompt)
    settle
    expect(drain).to eq(%w[s])

    2.times { gate.observe(prompt) }
    settle
    expect(drain).to eq(%w[w up])
  end

  it 'lets exempt commands through without counting them, in queue order' do
    primed_gate
    ['n', 'e', 's', '_injury 2', 'w'].each { |c| send_async(c) }
    settle
    expect(drain).to eq(%w[n e])

    gate.observe(prompt)
    settle
    expect(drain).to eq(['s', '_injury 2'])

    gate.observe(prompt)
    settle
    expect(drain).to eq(%w[w])
  end

  it 'sizes the window from the server typeahead refusal, capped at 4' do
    primed_gate
    gate.observe("Sorry, you may only type ahead 2 commands.\r\n")
    expect(gate.window).to eq(3)
    gate.observe("Sorry, you may only type ahead 9 commands.\r\n")
    expect(gate.window).to eq(4)
    gate.observe("Sorry, you may only type ahead 1 command.\r\n")
    expect(gate.window).to eq(2)
  end

  context 'with a short expiry' do
    let(:expiry) { 0.1 }

    it 'releases a command whose predecessor never drew a prompt' do
      primed_gate
      %w[a b c].each { |c| send_async(c) }
      settle
      expect(drain).to eq(%w[a b])
      sleep 0.2
      expect(drain).to eq(%w[c])
    end
  end

  it 'blocks a waiting caller until its own command is written' do
    primed_gate
    2.times { |i| send_async("x#{i}") }
    returned = Queue.new
    t = Thread.new { returned << gate.submit('look', wait: true) { sent << :look; true } }
    settle
    expect(returned).to be_empty

    gate.observe(prompt)
    t.join(1)
    expect(returned.pop).to be(true)
    expect(drain).to eq(%w[x0 x1] + [:look])
  end

  it 'writes a waiting caller on its own thread' do
    primed_gate
    2.times { |i| send_async("x#{i}") }
    writer_thread = nil
    t = Thread.new { gate.submit('look', wait: true) { writer_thread = Thread.current; true } }
    settle
    gate.observe(prompt)
    t.join(1)
    expect(writer_thread).to eq(t)
  end

  it 'never parks the queue when a waiting caller is killed' do
    primed_gate
    2.times { |i| send_async("x#{i}") }
    t = Thread.new { gate.submit('doomed', wait: true) { sent << :doomed; true } }
    settle
    t.kill
    t.join(1)
    send_async('after')
    gate.observe(prompt)
    settle
    expect(drain).to eq(%w[x0 x1 after])
  end

  it 'releases the slot and re-raises when a waiting writer raises' do
    primed_gate
    expect { gate.submit('bad', wait: true) { raise ArgumentError, 'guard' } }.to raise_error(ArgumentError)
    %w[a b].each { |c| send_async(c) }
    settle
    expect(drain).to eq(%w[a b])
  end

  it 'releases waiting callers when stopped' do
    primed_gate
    2.times { |i| send_async("x#{i}") }
    t = Thread.new { gate.submit('look', wait: true) { :written } }
    settle
    gate.stop
    expect(t.join(1)&.value).to eq(:written)
  end
end
