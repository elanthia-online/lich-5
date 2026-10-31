# frozen_string_literal: true

require_relative '../../spec_helper'
require 'tmpdir'
require 'webui/window_geometry_store'

RSpec.describe Lich::WebUI::WindowGeometryStore do
  def page(geometry)
    owner = Struct.new(:name).new('script')
    Struct.new(:owner, :id, :window_geometry).new(owner, 'main', geometry)
  end

  it 'gives concurrent saves from two stores distinct temporary files and leaves one complete geometry' do
    Dir.mktmpdir('webui-geometry') do |directory|
      first = { width: 640, height: 480, position: [10, 20] }
      second = { width: 800, height: 600, position: [30, 40] }
      stores = Array.new(2) { described_class.new(directory: directory, context: -> { 'gs:character' }) }
      arrived = Queue.new
      proceed = Queue.new
      stores.each do |store|
        allow(store).to receive(:read).and_wrap_original do |original, *args|
          result = original.call(*args)
          arrived << true
          proceed.pop
          result
        end
      end
      sources = Queue.new
      allow(File).to receive(:rename).and_wrap_original do |original, from, to|
        sources << from
        original.call(from, to)
      end

      workers = [[stores[0], first], [stores[1], second]].map do |store, geometry|
        Thread.new do
          Thread.current.report_on_exception = false
          store.save(page(geometry))
        end
      end
      2.times { arrived.pop }
      2.times { proceed << true }
      workers.each { |worker| expect { worker.value }.not_to raise_error }

      renamed = Array.new(sources.size) { sources.pop }
      expect(renamed.size).to eq(2)
      expect(renamed.uniq.size).to eq(2)
      expect(renamed.map { |path| File.dirname(path) }.uniq).to eq([directory])
      saved = Dir.children(directory)
      expect(saved.size).to eq(1)
      expect(saved.first).to end_with('.json')
      stored = JSON.parse(File.read(File.join(directory, saved.first)), symbolize_names: true)
      expect([first, second]).to include(stored)
    end
  end

  it 'removes its own temporary file when the write fails' do
    Dir.mktmpdir('webui-geometry') do |directory|
      store = described_class.new(directory: directory, context: -> { 'gs:character' })
      allow(File).to receive(:rename).and_raise(IOError, 'synthetic write failure')

      expect { store.save(page({ width: 1, height: 1, position: [0, 0] })) }.to raise_error(IOError)
      expect(Dir.children(directory)).to be_empty
    end
  end

  describe 'when the operating system refuses the rename' do
    let(:geometry) { { width: 640, height: 480, position: [10, 20] } }

    around do |example|
      Dir.mktmpdir('webui-geometry') do |directory|
        @directory = directory
        example.run
      end
    end

    before { stub_const("#{described_class}::RENAME_RETRY_DELAY", 0) }

    def store = described_class.new(directory: @directory, context: -> { 'gs:character' })

    it 'retries a transient refusal and saves the geometry' do
      refusals = 0
      allow(File).to receive(:rename).and_wrap_original do |original, from, to|
        refusals += 1
        raise Errno::EACCES if refusals <= 2

        original.call(from, to)
      end

      expect { store.save(page(geometry)) }.not_to raise_error
      expect(refusals).to eq(3)
      saved = Dir.children(@directory)
      expect(saved.size).to eq(1)
      expect(JSON.parse(File.read(File.join(@directory, saved.first)), symbolize_names: true)).to eq(geometry)
    end

    it 'gives up after a bounded number of attempts, logs, leaves no temporary file and does not raise' do
      attempts = 0
      allow(File).to receive(:rename) { attempts += 1; raise Errno::EACCES }
      logs = []
      allow(Lich).to receive(:log) { |message| logs << message }

      expect { store.save(page(geometry)) }.not_to raise_error
      expect(attempts).to eq(described_class::RENAME_ATTEMPTS)
      expect(logs.size).to eq(1)
      expect(logs.first).to include('not saved', 'Errno::EACCES')
      expect(Dir.children(@directory)).to be_empty
    end
  end
end
