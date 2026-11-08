# frozen_string_literal: true

require_relative '../../spec_helper'
require 'stringio'
require 'timeout'
require 'common/pipe_io'

RSpec.describe Lich::Common::PipeIO do
  # PipeIO#gets waits on IO.select, which needs a real IO (StringIO raises
  # TypeError), so input comes from a pipe. The writer stays open unless an
  # example closes it, like a front end that is still connected.
  let(:pipe_ends) { IO.pipe }
  let(:input)  { pipe_ends.first }
  let(:writer) { pipe_ends.last }
  let(:output) { StringIO.new }
  let(:pipe)   { described_class.new(input: input, output: output) }

  after do
    pipe_ends.each { |io| io.close unless io.closed? }
  end

  # Runs #gets on a thread so an example can act while the reader is parked.
  def reader_thread
    Thread.new { pipe.gets }.tap do |thread|
      Timeout.timeout(5) { Thread.pass until thread.stop? }
    end
  end

  def value_within(thread, seconds = 5)
    raise "reader still blocked after #{seconds}s" unless thread.join(seconds)

    thread.value
  end

  describe 'initialization' do
    it 'enables sync on the output stream so pipe output is flushed' do
      output.sync = false # the constructor must be what turns sync on
      pipe # force construction (let is lazy)
      expect(output.sync).to be true
    end
  end

  describe '#gets' do
    it 'reads successive lines from the input stream' do
      writer.write("first line\nsecond line\n")
      expect(pipe.gets).to eq("first line\n")
      expect(pipe.gets).to eq("second line\n")
    end

    it 'returns nil once the input is exhausted' do
      writer.write("first line\n")
      writer.close
      expect(pipe.gets).to eq("first line\n")
      expect(pipe.gets).to be_nil
    end

    it 'passes its arguments through to the input' do
      writer.write("first line\n")
      expect(pipe.gets(5)).to eq('first')
      expect(pipe.gets).to eq(" line\n")
    end

    it 'serves a line already buffered by an earlier read without waiting for more input' do
      writer.write("first line\nsecond line\n") # one write: both lines land in one read
      expect(pipe.gets).to eq("first line\n")
      # Nothing more will arrive on the pipe, so this only returns at once
      # if the readiness wait sees Ruby's buffered data.
      expect(Timeout.timeout(0.5) { pipe.gets }).to eq("second line\n")
    end

    it 'returns a line that arrives while the reader is parked' do
      thread = reader_thread
      writer.write("late line\n")
      expect(value_within(thread)).to eq("late line\n")
    end

    it 'returns nil when the writer closes while the reader is parked' do
      thread = reader_thread
      writer.close
      expect(value_within(thread)).to be_nil
      expect(pipe.closed?).to be true
    end

    it 'waits for the newline when only part of a line has arrived' do
      writer.write('par')
      thread = Thread.new { pipe.gets }
      expect(thread.join(0.3)).to be_nil # still reading: no newline yet
      writer.write("tial\n")
      expect(value_within(thread)).to eq("partial\n")
    end

    it 'raises IOError when the input was closed underneath it, and does not report EOF' do
      input.close
      expect { pipe.gets }.to raise_error(IOError)
      expect(pipe.closed?).to be false
    end
  end

  describe '#gets readiness wait' do
    it 'waits for readability, bounded by READ_WAIT_SECONDS, before reading' do
      writer.write("first line\n")
      expect(IO).to receive(:select)
        .with([input], nil, nil, described_class::READ_WAIT_SECONDS).ordered.and_call_original
      expect(input).to receive(:gets).ordered.and_call_original
      expect(pipe.gets).to eq("first line\n")
    end

    it 'keeps waiting after a wait times out, and reads only once input is ready' do
      writer.write("first line\n")
      # Two timed-out waits (nil), then a real one.
      call = 0
      allow(IO).to receive(:select).and_wrap_original do |original, *args|
        call += 1
        call <= 2 ? nil : original.call(*args)
      end
      allow(input).to receive(:gets).and_call_original
      expect(pipe.gets).to eq("first line\n")
      expect(IO).to have_received(:select).with([input], nil, nil, described_class::READ_WAIT_SECONDS).exactly(3).times
      expect(input).to have_received(:gets).once
    end

    it 'has no read pending on the input while it is idle, across several wait timeouts' do
      stub_const("#{described_class}::READ_WAIT_SECONDS", 0.05)
      allow(input).to receive(:gets).and_call_original
      thread = Thread.new { pipe.gets }
      sleep 0.3 # several bounded waits time out
      expect(input).not_to have_received(:gets)
      writer.write("now\n")
      expect(value_within(thread)).to eq("now\n")
      expect(input).to have_received(:gets).once
    end

    it 'uses a positive, finite bound' do
      expect(described_class::READ_WAIT_SECONDS).to be_a(Numeric)
      expect(described_class::READ_WAIT_SECONDS).to be_between(0.01, 5)
    end
  end

  describe '#write and #puts' do
    it 'writes to the output stream' do
      pipe.write('downstream')
      expect(output.string).to eq('downstream')
    end

    it 'puts a line to the output stream' do
      pipe.puts('a line')
      expect(output.string).to eq("a line\n")
    end
  end

  describe '#closed? (EOF-based liveness)' do
    before { writer.write("first line\nsecond line\n") }

    it 'is not closed before EOF' do
      pipe.gets
      expect(pipe.closed?).to be false
    end

    it 'becomes closed once gets hits EOF' do
      writer.close
      pipe.gets
      pipe.gets
      expect(pipe.closed?).to be false
      pipe.gets # EOF -> nil
      expect(pipe.closed?).to be true
    end

    it 'reports closed after #close without touching the underlying streams' do
      pipe.close
      expect(pipe.closed?).to be true
      expect(input.closed?).to be false
      expect(output.closed?).to be false
    end
  end

  describe 'wrapped in SynchronizedSocket' do
    require 'common/class_exts/synchronizedsocket'

    let(:socket) { Lich::Common::SynchronizedSocket.new(pipe) }

    it 'is alive until the input stream hits EOF' do
      writer.write("first line\nsecond line\n")
      writer.close
      expect(socket.alive?).to be true
      socket.gets # "first line\n"
      socket.gets # "second line\n"
      expect(socket.alive?).to be true
      socket.gets # EOF
      expect(socket.alive?).to be false
    end
  end
end
