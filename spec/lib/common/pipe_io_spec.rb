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
      expect(output.sync).to be true
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
