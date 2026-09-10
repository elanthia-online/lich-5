# frozen_string_literal: true

require_relative '../spec_helper'
require 'ostruct'
require 'common/sharedbuffer'
require 'games'

module GameExecutionGuardSpec
  class Rejected < StandardError; end

  class GuardedScript
    attr_accessor :handler, :active
    attr_reader :commands

    def initialize(&handler)
      @handler = handler
      @commands = []
      @checking = false
      @active = true
    end

    def check_execution_guard!(command: nil)
      raise Rejected, 'recursive execution guard' if @checking

      @checking = true
      @commands << command
      @handler&.call(command)
    ensure
      @checking = false
    end

    def file_name = nil
    def name = 'guarded'
    def silent = false
    def execution_guard_active? = @active
  end
end

RSpec.describe Lich::GameBase::Game, 'script execution guard on game writes' do
  let(:socket) { double('game socket', puts: nil) }
  let(:guarded) { GameExecutionGuardSpec::GuardedScript.new }
  let(:mutex) { Mutex.new }

  before do
    @old_socket = described_class.instance_variable_get(:@socket)
    @old_mutex = described_class.instance_variable_get(:@mutex)
    @old_prefix = $cmd_prefix
    described_class.instance_variable_set(:@socket, socket)
    described_class.instance_variable_set(:@mutex, mutex)
    Script.current = guarded
    $cmd_prefix = '<c>'
    allow(described_class).to receive(:respond)
    allow(Lich).to receive(:log)
  end

  after do
    described_class.instance_variable_set(:@socket, @old_socket)
    described_class.instance_variable_set(:@mutex, @old_mutex)
    $cmd_prefix = @old_prefix
  end

  it 'checks one immutable wire command once for puts, including its prefix' do
    described_class.puts('attack #17')
    expect(guarded.commands).to eq(['<c>attack #17'])
    expect(guarded.commands.first).to be_frozen
    expect(socket).to have_received(:puts).with('<c>attack #17').once
    expect($_CLIENTBUFFER_.last).to include('attack #17')
  end

  it 'resolves the pause-aware script once in puts and once at the write seam' do
    expect(Script).to receive(:current).twice.and_return(guarded)
    described_class.puts('attack #17')
  end

  it 'guards raw _puts without adding or stripping a prefix' do
    described_class._puts('raw command')
    expect(guarded.commands).to eq(['raw command'])
    expect(socket).to have_received(:puts).with('raw command')
  end

  it 'sends the guarded copy even if the caller changes the original command' do
    command = +'attack #17'
    guarded.handler = ->(_wire_command) { command.replace('attack #18') }
    described_class._puts(command)
    expect(socket).to have_received(:puts).with('attack #17')
    expect(guarded.commands).to eq(['attack #17'])
  end

  it 'rejects before transport, command echo and last-command recording' do
    guarded.handler = ->(_command) { raise GameExecutionGuardSpec::Rejected, 'held' }
    expect { described_class.puts('attack #17') }.to raise_error(GameExecutionGuardSpec::Rejected, 'held')
    expect(socket).not_to have_received(:puts)
    expect(described_class).not_to have_received(:respond)
    expect($_CLIENTBUFFER_).to be_empty
    expect($_LASTUPSTREAM_).to be_nil
  end

  it 'does not mistake a guard IOError for a recoverable socket error' do
    guarded.handler = ->(_command) { raise IOError, 'guard observation failed' }
    expect { described_class.puts('attack #17') }.to raise_error(IOError, 'guard observation failed')
    expect(socket).not_to have_received(:puts)
    expect(described_class).not_to have_received(:respond)
    expect($_CLIENTBUFFER_).to be_empty
  end

  it 'charges retries separately and never double charges puts to _puts delegation' do
    guarded.handler = ->(_command) { raise GameExecutionGuardSpec::Rejected, 'limit' if guarded.commands.size > 1 }
    described_class.puts('attack #17')
    expect { described_class.puts('attack #17') }.to raise_error(GameExecutionGuardSpec::Rejected, 'limit')
    expect(guarded.commands.size).to eq(2)
    expect(socket).to have_received(:puts).once
  end

  it 'preserves raw core and legacy script writes without an execution guard method' do
    Script.current = nil
    described_class._puts('core write')
    Script.current = OpenStruct.new(name: 'legacy', file_name: nil, silent: false)
    described_class.puts('legacy write')
    expect(socket).to have_received(:puts).with('core write')
    expect(socket).to have_received(:puts).with('<c>legacy write')
    expect(guarded.commands).to be_empty
  end

  it 'preserves unguarded object identity and pre-write echo ordering' do
    guarded.active = false
    command = +'raw command'
    allow(socket).to receive(:puts) do |value|
      expect(value).to equal(command)
      expect(value).not_to be_frozen
    end
    described_class._puts(command)
    expect(guarded.commands).to be_empty

    allow(socket).to receive(:puts) do |_value|
      expect($_CLIENTBUFFER_.last).to include('ordinary command')
      expect(described_class).to have_received(:respond).with(/ordinary command/)
    end
    described_class.puts('ordinary command')
  end

  it 'reevaluates guard activation after acquiring the mutex' do
    guarded.active = false
    allow(mutex).to receive(:synchronize).and_wrap_original do |original, &block|
      original.call do
        guarded.active = true
        block.call
      end
    end
    described_class._puts('late guarded command')
    expect(guarded.commands).to eq(['late guarded command'])
  end

  it 'checks the current script independently for every outgoing write' do
    other = GameExecutionGuardSpec::GuardedScript.new
    described_class._puts('first')
    Script.current = other
    described_class._puts('second')
    expect(guarded.commands).to eq(['first'])
    expect(other.commands).to eq(['second'])
  end

  it 'checks while holding the write mutex, immediately before the socket call' do
    events = []
    guarded.handler = lambda do |command|
      expect(mutex.owned?).to eq(true)
      events << [:check, command]
    end
    allow(socket).to receive(:puts) { |command| events << [:write, command] }
    described_class._puts('attack #17')
    expect(events).to eq([[:check, 'attack #17'], [:write, 'attack #17']])
  end

  it 'resolves pause-aware Script.current outside the shared socket lock' do
    allow(Script).to receive(:current) do
      expect(mutex.owned?).to be(false)
      guarded
    end
    described_class._puts('attack #17')
    expect(socket).to have_received(:puts).with('attack #17')
  end

  it 'rejects callback reentry without a socket write or recursive mutex failure' do
    guarded.handler = ->(_command) { described_class._puts('nested command') }
    expect { described_class._puts('outer command') }.to raise_error(GameExecutionGuardSpec::Rejected, /recursive/)
    expect(socket).not_to have_received(:puts)
  end

  it 'serializes each guard check with its corresponding socket write' do
    events = []
    scripts = 2.times.map do
      GameExecutionGuardSpec::GuardedScript.new { |command| events << [:check, command] }
    end
    allow(Script).to receive(:current) { Thread.current[:game_execution_guard_spec_script] }
    allow(socket).to receive(:puts) { |command| events << [:write, command] }
    threads = scripts.each_with_index.map do |script, index|
      Thread.new do
        Thread.current[:game_execution_guard_spec_script] = script
        described_class._puts("command #{index}")
      end
    end
    threads.each(&:value)
    expect(events.each_slice(2).to_a).to contain_exactly(
      [[:check, 'command 0'], [:write, 'command 0']],
      [[:check, 'command 1'], [:write, 'command 1']]
    )
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
  end
end
