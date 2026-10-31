# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'tmpdir'
require 'common/webui_launcher/window_geometry_store'

RSpec.describe Lich::Common::WebUILauncher::WindowGeometryStore do
  it 'migrates valid GTK geometry and then prefers WebUI geometry' do
    Dir.mktmpdir do |data_dir|
      File.write(File.join(data_dir, 'login_gui_settings.yml'), YAML.dump(
                                                                  width: 900, height: 700, position: [120, 80]
                                                                ))
      store = described_class.new(data_dir: data_dir)

      expect(store.load).to eq(width: 900, height: 700, position: [120, 80])
      expect(store.save('width' => 1000, 'height' => 760, 'position' => [-200, 40]))
        .to eq(width: 1000, height: 760, position: [-200, 40])
      expect(store.load).to eq(width: 1000, height: 760, position: [-200, 40])
      # Windows has no POSIX file modes: it reports 0o644 whatever the creator requested.
      expect(File.stat(File.join(data_dir, described_class::FILE_NAME)).mode & 0o777).to eq(0o600) unless OS.windows?
    end
  end

  it 'replaces the geometry file atomically and leaves no temporary file' do
    Dir.mktmpdir do |data_dir|
      store = described_class.new(data_dir: data_dir)
      path = File.join(data_dir, described_class::FILE_NAME)
      File.write(path, YAML.dump(width: 900, height: 700, position: nil))
      allow(File).to receive(:rename).and_call_original

      expect(store.save(width: 1000, height: 760, position: nil)).to eq(width: 1000, height: 760, position: nil)
      expect(File).to have_received(:rename).with(a_string_starting_with(data_dir), path)
      expect(Dir.children(data_dir)).to eq([described_class::FILE_NAME])
      # Windows has no POSIX file modes: it reports 0o644 whatever the creator requested.
      expect(File.stat(path).mode & 0o777).to eq(0o600) unless OS.windows?
      expect(store.load).to eq(width: 1000, height: 760, position: nil)
    end
  end

  describe 'when the operating system refuses the rename' do
    around do |example|
      Dir.mktmpdir('webui-launcher-geometry') do |directory|
        @data_dir = directory
        example.run
      end
    end

    before { stub_const("#{described_class}::RENAME_RETRY_DELAY", 0) }

    def store = described_class.new(data_dir: @data_dir)

    it 'retries a transient refusal and saves the geometry' do
      refusals = 0
      allow(File).to receive(:rename).and_wrap_original do |original, from, to|
        refusals += 1
        raise Errno::EACCES if refusals <= 2

        original.call(from, to)
      end

      expect(store.save(width: 1000, height: 760, position: nil)).to eq(width: 1000, height: 760, position: nil)
      expect(refusals).to eq(3)
      expect(Dir.children(@data_dir)).to eq([described_class::FILE_NAME])
      expect(store.load).to eq(width: 1000, height: 760, position: nil)
    end

    it 'gives up after a bounded number of attempts, logs, leaves no temporary file and does not raise' do
      attempts = 0
      allow(File).to receive(:rename) { attempts += 1; raise Errno::EACCES }
      logs = []
      allow(Lich).to receive(:log) { |message| logs << message }

      expect(store.save(width: 1000, height: 760, position: nil)).to be(false)
      expect(attempts).to eq(described_class::RENAME_ATTEMPTS)
      expect(logs.size).to eq(1)
      expect(logs.first).to include('not saved', 'Errno::EACCES')
      expect(Dir.children(@data_dir)).to be_empty
    end

    it 'does not retry a failure that is not a system-call refusal' do
      attempts = 0
      allow(File).to receive(:rename) { attempts += 1; raise IOError, 'synthetic write failure' }

      expect(store.save(width: 1000, height: 760, position: nil)).to be(false)
      expect(attempts).to eq(1)
      expect(Dir.children(@data_dir)).to be_empty
    end
  end

  it 'rejects malformed and unbounded geometry' do
    store = described_class.new(data_dir: Dir.tmpdir)

    expect(store.validate(width: 900, height: 700, position: nil))
      .to eq(width: 900, height: 700, position: nil)
    expect(store.validate(width: 200, height: 700, position: [0, 0])).to be_nil
    expect(store.validate(width: 900, height: 700, position: [100_000, 0])).to be_nil
    expect(store.validate(width: '900', height: 700, position: [0, 0])).to be_nil
  end
end
