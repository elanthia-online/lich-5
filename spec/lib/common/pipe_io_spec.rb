# frozen_string_literal: true

require_relative '../../spec_helper'
require 'stringio'
require 'common/pipe_io'

RSpec.describe Lich::Common::PipeIO do
  let(:input)  { StringIO.new("first line\nsecond line\n") }
  let(:output) { StringIO.new }
  let(:pipe)   { described_class.new(input: input, output: output) }

  describe 'initialization' do
    it 'enables sync on the output stream so pipe output is flushed' do
      output.sync = false # the constructor must be what turns sync on
      pipe # force construction (let is lazy)
      expect(output.sync).to be true
    end

    # Regression: without this, an internal_encoding configured anywhere in
    # the process (Encoding.default_internal, -E, etc.) would make Ruby's
    # IO layer itself transcode on #gets, which could corrupt or invalidate
    # a genuine Windows-1252 high byte before WireEncoding.decode ever sees
    # it -- the "raw bytes, no transcoding" contract was true only by
    # coincidence of how the process happened to be configured.
    it 'forces binary mode on the input stream so #gets never transcodes' do
      # StringIO doesn't expose #binmode?, so assert the call happens rather
      # than inspecting resulting state; the real-IO case below proves the
      # actual byte-preservation effect this is for.
      allow(input).to receive(:binmode).and_call_original
      pipe # force construction (let is lazy)
      expect(input).to have_received(:binmode)
    end

    it 'does not raise if the given input does not respond to #binmode' do
      minimal_input = double('minimal_input', gets: nil)
      expect { described_class.new(input: minimal_input, output: output) }.not_to raise_error
    end
  end

  describe '#gets' do
    it 'reads successive lines from the input stream' do
      expect(pipe.gets).to eq("first line\n")
      expect(pipe.gets).to eq("second line\n")
    end

    it 'returns nil once the input is exhausted' do
      pipe.gets
      pipe.gets
      expect(pipe.gets).to be_nil
    end

    it 'returns a raw Windows-1252 byte untouched and ASCII-8BIT-tagged even when the process has a default_internal encoding set' do
      # A real IO::pipe, not StringIO -- StringIO#gets never performs actual
      # encoding conversion the way a genuine IO does, so it can't
      # reproduce what this guards against.
      reader, writer = IO.pipe
      writer.write("caf\xE9\n".b) # rubocop:disable Custom/AsciiOnlySource
      writer.close
      pipe_over_io = described_class.new(input: reader, output: output)

      original_internal = Encoding.default_internal
      Encoding.default_internal = Encoding::UTF_8
      begin
        line = pipe_over_io.gets
      ensure
        Encoding.default_internal = original_internal
        reader.close
      end

      expect(line.encoding).to eq(Encoding::ASCII_8BIT)
      expect(line.bytes).to eq("caf\xE9\n".b.bytes) # rubocop:disable Custom/AsciiOnlySource
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
    it 'is not closed before EOF' do
      pipe.gets
      expect(pipe.closed?).to be false
    end

    it 'becomes closed once gets hits EOF' do
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
      expect(socket.alive?).to be true
      socket.gets # "first line\n"
      socket.gets # "second line\n"
      expect(socket.alive?).to be true
      socket.gets # EOF
      expect(socket.alive?).to be false
    end
  end
end
