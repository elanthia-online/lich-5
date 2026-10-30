# frozen_string_literal: true

require_relative '../../spec_helper'
require 'stringio'
require_relative '../../../lib/main/webui_startup'

RSpec.describe Lich::Main::WebUIStartup do
  # Records the calls startup makes; await_launch blocks until released.
  let(:launcher_class) do
    Class.new do
      attr_reader :calls
      attr_accessor :failure

      def initialize(result: nil, failure: nil, start_error: nil, block: false)
        @result = result
        @failure = failure
        @start_error = start_error
        @release = block ? Queue.new : nil
        @waiting = Queue.new
        @calls = []
      end

      def start
        @calls << :start
        raise @start_error if @start_error

        self
      end

      def await_launch
        @calls << :await_launch
        @waiting << true
        @release&.pop
        @result
      end

      def wait_until_waiting = @waiting.pop(timeout: 2)

      def close_at_exit
        @calls << :close_at_exit
      end
    end
  end

  before do
    allow(Lich).to receive(:log)
  end

  it 'returns launch data after a selection and still runs the bounded teardown' do
    launcher = launcher_class.new(result: ['GAMECODE=GS3'])

    expect(described_class.await(launcher)).to eq(['GAMECODE=GS3'])
    expect(launcher.calls).to eq(%i[start await_launch close_at_exit])
    expect(Lich).not_to have_received(:log)
  end

  it 'treats closing a connected launcher without a selection as a cancellation' do
    launcher = launcher_class.new

    expect(described_class.await(launcher)).to be_nil
    expect(launcher.calls.last).to eq(:close_at_exit)
    expect(Lich).not_to have_received(:log)
  end

  it 'reports a launcher failure and exits with status 1' do
    failure = 'The WebUI launcher window closed before connecting. Check the debug log and retry.'
    launcher = launcher_class.new(failure: failure)

    expect { described_class.await(launcher) }.to raise_error(SystemExit) { |exit| expect(exit.status).to eq(1) }
    expect(Lich).to have_received(:log).with("error: #{failure}")
    expect(launcher.calls.last).to eq(:close_at_exit)
  end

  it 'reports a host-start failure that raised, and exits with status 1' do
    launcher = launcher_class.new(failure: 'ERROR: host failed. The WebUI launcher has stopped.',
                                  start_error: RuntimeError.new('host failed'))

    expect { described_class.await(launcher) }.to raise_error(SystemExit) { |exit| expect(exit.status).to eq(1) }
    expect(Lich).to have_received(:log).with('error: ERROR: host failed. The WebUI launcher has stopped.')
    expect(launcher.calls).to eq(%i[start close_at_exit])
  end

  it 'names only the error class when a start error left no recorded failure' do
    launcher = launcher_class.new(start_error: RuntimeError.new('secret detail'))

    expect { described_class.await(launcher) }.to raise_error(SystemExit) { |exit| expect(exit.status).to eq(1) }
    expect(Lich).to have_received(:log).with('error: WebUI launcher failed to start: RuntimeError')
  end

  it 'writes the fatal report to the terminal when stderr is the debug log' do
    launcher = launcher_class.new(failure: 'host exited')
    debug_log = StringIO.new
    terminal = StringIO.new
    original = $stderr
    stub_const('STDERR', terminal)
    $stderr = debug_log

    expect { described_class.await(launcher) }.to raise_error(SystemExit)
    expect(terminal.string).to eq("error: host exited\n")
  ensure
    $stderr = original
  end

  it 'tears the launcher down when the startup wait is killed, as on signal exit' do
    launcher = launcher_class.new(block: true)
    waiter = Thread.new { described_class.await(launcher) }
    expect(launcher.wait_until_waiting).to be(true)

    waiter.kill
    expect(waiter.join(2)).to equal(waiter)
    expect(launcher.calls).to eq(%i[start await_launch close_at_exit])
  end
end
