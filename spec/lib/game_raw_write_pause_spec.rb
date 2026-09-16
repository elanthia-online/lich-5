# frozen_string_literal: true

require_relative '../spec_helper'
require 'common/limitedarray'
require 'common/sharedbuffer'
require 'common/gameobj'
require 'common/inventory'
require 'games'

RSpec.describe Lich::GameBase::Game, 'raw writes from paused scripts' do
  let(:script_class) { Lich::Common::Script }
  let(:inventory) { Lich::Common::Inventory }
  let(:socket) { double('game socket', puts: nil) }
  let(:interrupted) { Lich::Common::ScriptExecutionGuard::Interrupted }
  let(:owner) do
    script_class.allocate.tap do |script|
      script.instance_variable_set(:@paused, true)
      script.instance_variable_set(:@ignore_pause, false)
      script.instance_variable_set(:@name, 'paused-owner')
      script.instance_variable_set(:@silent, true)
    end
  end

  before(:context) do
    require_relative '../../lib/common/script'
  end

  after(:context) do
    %i[SubScript ExecScript WizardScript Script Scripting TRUSTED_SCRIPT_BINDING].each do |name|
      Lich::Common.send(:remove_const, name) if Lich::Common.const_defined?(name, false)
    end
    $LOADED_FEATURES.delete_if { |path| path.end_with?('/lib/common/script.rb') }
  end

  before do
    stub_const('Lich::GameBase::Script', script_class)
    stub_const('Lich::Common::Game', described_class)
    @old_socket = described_class.instance_variable_get(:@socket)
    @old_mutex = described_class.instance_variable_get(:@mutex)
    described_class.instance_variable_set(:@socket, socket)
    described_class.instance_variable_set(:@mutex, Mutex.new)
    allow(described_class).to receive(:respond)
    allow(Lich).to receive(:log)
    inventory.reset!
  end

  after do
    Array(@workers).each { |thread| thread.kill; thread.join }
    inventory.reset!
    described_class.instance_variable_set(:@socket, @old_socket)
    described_class.instance_variable_set(:@mutex, @old_mutex)
  end

  def worker(script = owner, &block)
    @workers ||= []
    Thread.new do
      Thread.current.thread_variable_set(script_class::CLEANUP_SCRIPT_THREAD_KEY, script)
      block.call
    end.tap { |thread| @workers << thread }
  end

  it 'lets a paused inventory refresh finish and release the shared refresh mutex' do
    entered = Queue.new
    allow(described_class).to receive(:_puts).and_wrap_original do |method, command|
      expect(inventory.instance_variable_get(:@refresh_mutex).owned?).to be(true)
      entered << true
      method.call(command)
    end
    allow(socket).to receive(:puts) do |command|
      id = command.split.last
      inventory.observe("<inventoryManager id='#{id}' room='1'></inventoryManager>")
    end

    first = worker { inventory.refresh(timeout: 0.1) }
    expect(entered.pop(timeout: 1)).to be(true)
    second = worker(nil) { inventory.refresh(timeout: 0.1) }

    expect(first.join(1)).to equal(first)
    expect(second.join(1)).to equal(second)
    expect(first.value).to be_a(Lich::Common::Inventory::Snapshot)
    expect(second.value).to be_a(Lich::Common::Inventory::Snapshot)
    expect(socket).to have_received(:puts).twice
    expect(owner.paused?).to be(true)
  end

  it 'keeps ordinary Game.puts blocked until its script is unpaused' do
    entered = Queue.new
    allow(owner).to receive(:wait_while_paused!).and_wrap_original do |method|
      entered << true
      method.call
    end
    sender = worker { described_class.puts('look') }
    expect(entered.pop(timeout: 1)).to be(true)
    expect(sender.join(0.05)).to be_nil
    expect(socket).not_to have_received(:puts)

    owner.paused = false
    expect(sender.join(1)).to equal(sender)
    sender.value
    expect(socket).to have_received(:puts).once
  end

  it 'checks a paused raw writer found through its running thread group' do
    group = ThreadGroup.new
    owner.instance_variable_set(:@thread_group, group)
    allow(script_class).to receive(:__running_snapshot).and_return([owner])
    commands = []
    sender = worker(nil) do
      group.add(Thread.current)
      owner.with_execution_guard(->(command) { commands << command; true }) do
        described_class._puts('raw command')
      end
    end

    expect(sender.join(1)).to equal(sender)
    sender.value
    expect(commands.compact).to eq(['raw command'])
    expect(socket).to have_received(:puts).with('raw command').once
    expect(owner.paused?).to be(true)
  end

  it 'rejects a cancelled paused raw writer before transport' do
    sender = worker do
      expect do
        owner.with_execution_guard(->(_command) { true }) do |guard|
          guard.cancel!(:cancelled)
          described_class._puts('cancelled command')
        end
      end.to raise_error(interrupted) { |error| expect(error.reason).to eq(:cancelled) }
    end

    expect(sender.join(1)).to equal(sender)
    sender.value
    expect(socket).not_to have_received(:puts)
    expect(owner.execution_guard_active?).to be(false)
  end

  it 'allows guard observations but rejects recursive sends from a paused raw writer' do
    observations = []
    policy = lambda do |command|
      if command
        observations << script_class.current
        described_class._puts('recursive command')
      end
      true
    end
    sender = worker do
      expect do
        owner.with_execution_guard(policy) { described_class._puts('outer command') }
      end.to raise_error(interrupted) { |error| expect(error.reason).to eq(:reentrant_command) }
    end

    expect(sender.join(1)).to equal(sender)
    sender.value
    expect(observations).to eq([owner])
    expect(socket).not_to have_received(:puts)
  end
end
