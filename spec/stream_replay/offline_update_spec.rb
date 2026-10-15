# frozen_string_literal: true

require_relative '../spec_helper'
require 'tempfile'
require_relative '../support/stream_replay/offline_update'
require_relative '../support/stream_replay/fixture'
require_relative '../support/stream_replay/driver'

# The replay child's offline stubs match lib/ by name. These pin the self-check
# that turns a rename in lib/ into a refused replay instead of a silent
# network call. Uses stand-in modules: offline_preload.rb itself is never
# loaded here (its TracePoint would patch this process's Lich::Util::Update).
RSpec.describe StreamReplay do
  def update_module(*names)
    Module.new do
      names.each { |n| define_singleton_method(n) { |*| :real } }
    end
  end

  def lich_module(with_core: true)
    Module.new do
      define_singleton_method(:core_updated_with_lich_version) { '0.0.1' } if with_core
    end
  end

  def stubbed(mod, stub)
    mod.singleton_class.prepend(stub)
    mod
  end

  let(:update) { stubbed(update_module(:update_core_data_and_scripts, :sync_all_repos), described_class::OfflineUpdate) }
  let(:lich) { stubbed(lich_module, described_class::CurrentCore) }

  describe '.offline_problems' do
    it 'reports nothing when every stub is prepended over a real method' do
      expect(described_class.offline_problems(update, lich)).to eq([])
    end

    it 'leaves the stubbed entry points as no-ops' do
      expect(update.sync_all_repos).to be_nil
      expect(update.update_core_data_and_scripts('1.0')).to be_nil
    end

    it 'reports a lib/ method that was renamed, so its no-op shadows nothing' do
      renamed = stubbed(update_module(:update_core_data_and_scripts, :sync_all_repos_v2), described_class::OfflineUpdate)
      expect(described_class.offline_problems(renamed, lich))
        .to eq(['Lich::Util::Update.sync_all_repos does not exist, so its no-op stubs nothing'])
    end

    it 'reports a module the preload never prepended' do
      expect(described_class.offline_problems(update_module(:update_core_data_and_scripts, :sync_all_repos), lich))
        .to eq(['Lich::Util::Update was never prepended with StreamReplay::OfflineUpdate'])
    end

    it 'reports a missing Lich::Util::Update' do
      expect(described_class.offline_problems(nil, lich)).to eq(['Lich::Util::Update is not defined'])
    end

    it 'reports Lich when core_updated_with_lich_version was renamed (the preload skips the prepend)' do
      expect(described_class.offline_problems(update, lich_module(with_core: false)))
        .to eq(['Lich was never prepended with StreamReplay::CurrentCore'])
    end
  end

  describe StreamReplay::Driver do
    let(:driver) { described_class.new(StreamReplay::Fixture.new('x.xml', "### stream-replay:body-below ###\n")) }
    let(:marker) { Tempfile.new(['ready', '.jsonl']) }

    after { marker.close! }

    def write_marker(hash)
      marker.write("#{JSON.generate(hash)}\n")
      marker.flush
    end

    it 'accepts a ready marker with no offline problems' do
      write_marker('ready' => true, 'offline_problems' => [])
      expect { driver.send(:verify_offline!, marker.path) }.not_to raise_error
    end

    it 'refuses to replay when the child reports an offline problem' do
      write_marker('ready' => true, 'offline_problems' => ['Lich::Util::Update.sync_all_repos does not exist, so its no-op stubs nothing'])
      expect { driver.send(:verify_offline!, marker.path) }.to raise_error(RuntimeError, /not offline.*sync_all_repos/)
    end

    it 'refuses to replay when the ready marker carries no self-check (old probe)' do
      write_marker('ready' => true)
      expect { driver.send(:verify_offline!, marker.path) }.to raise_error(RuntimeError, /no offline_problems/)
    end
  end
end
