# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/util/memoryreleaser'

RSpec.describe Lich::Util::MemoryReleaser do
  let(:memory_releaser) { described_class }
  let(:manager_class) { described_class::Manager }

  before do
    described_class.instance_variable_set(:@instance, nil)

    stub_const('Lich::Common::DB_Store', Module.new)
    allow(Lich::Common::DB_Store).to receive(:read).and_return({})
    allow(Lich::Common::DB_Store).to receive(:save).and_return(true)

    XMLData.game = 'DR'
    XMLData.name = 'SpecChar'
  end

  describe 'manager settings lifecycle' do
    it 'loads defaults merged with stored settings' do
      allow(Lich::Common::DB_Store).to receive(:read).and_return({ interval: 120, verbose: true, auto_start: true })

      manager = manager_class.new

      expect(manager.settings[:interval]).to eq(120)
      expect(manager.settings[:verbose]).to be(true)
      expect(manager.settings[:auto_start]).to be(true)
      expect(manager.enabled).to be(true)
    end

    it 'falls back to defaults when loading settings fails' do
      allow(Lich::Common::DB_Store).to receive(:read).and_raise(StandardError, 'db unavailable')

      manager = manager_class.new
      allow(manager).to receive(:respond)

      settings = manager.load_settings

      expect(settings).to eq(described_class::DEFAULT_SETTINGS)
      expect(manager.interval).to eq(described_class::DEFAULT_SETTINGS[:interval])
      expect(manager.verbose).to eq(described_class::DEFAULT_SETTINGS[:verbose])
    end

    it 'saves settings with per-character scope' do
      manager = manager_class.new
      manager.interval = 333
      manager.verbose = true
      manager.settings[:interval] = 333
      manager.settings[:verbose] = true

      expect(Lich::Common::DB_Store).to receive(:save).with('DR:SpecChar', 'lich_memory_releaser', manager.settings)

      manager.save_settings
    end

    it 'returns current settings when save fails' do
      manager = manager_class.new
      allow(manager).to receive(:respond)
      allow(Lich::Common::DB_Store).to receive(:save).and_raise(StandardError, 'save failed')

      expect(manager.save_settings).to eq(manager.settings)
      expect(manager).to have_received(:respond).with(/Error saving settings/)
    end
  end

  describe 'manager controls' do
    it 'auto_start! enables setting, saves, and starts' do
      manager = manager_class.new
      allow(manager).to receive(:start).and_return(:worker)

      expect(manager.auto_start!).to eq(:worker)
      expect(manager.settings[:auto_start]).to be(true)
    end

    it 'auto_disable! disables setting and stops when running' do
      manager = manager_class.new
      allow(manager).to receive(:running?).and_return(true)
      allow(manager).to receive(:stop)

      manager.auto_disable!

      expect(manager.settings[:auto_start]).to be(false)
      expect(manager).to have_received(:stop)
    end

    it 'interval! enforces minimum 60 seconds' do
      manager = manager_class.new
      allow(manager).to receive(:running?).and_return(false)

      expect(manager.interval!(10)).to eq(60)
      expect(manager.interval).to eq(60)
    end

    it 'interval! restarts when already running' do
      manager = manager_class.new
      allow(manager).to receive(:running?).and_return(true)
      allow(manager).to receive(:start)

      manager.interval!(600)

      expect(manager).to have_received(:start)
    end

    it 'verbose! updates and persists setting' do
      manager = manager_class.new

      expect(manager.verbose!(true)).to be(true)
      expect(manager.verbose).to be(true)
      expect(manager.settings[:verbose]).to be(true)
    end
  end

  describe 'release flow' do
    it 'release runs gc and os release steps' do
      manager = manager_class.new
      allow(manager).to receive(:run_gc)
      allow(manager).to receive(:release_to_os)

      manager.release

      expect(manager).to have_received(:run_gc)
      expect(manager).to have_received(:release_to_os)
    end

    it 'run_gc calls full mark + immediate sweep and compacts when supported' do
      manager = manager_class.new
      allow(GC).to receive(:start)
      allow(GC).to receive(:compact)
      allow(GC).to receive(:respond_to?).and_call_original
      allow(GC).to receive(:respond_to?).with(:compact).and_return(true)

      manager.send(:run_gc)

      expect(GC).to have_received(:start).with(full_mark: true, immediate_sweep: true)
      expect(GC).to have_received(:compact)
    end

    it 'release_to_os dispatches linux path' do
      manager = manager_class.new
      allow(manager).to receive(:malloc_trim_linux)
      allow(RbConfig::CONFIG).to receive(:[]).and_call_original
      allow(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return('linux')

      manager.send(:release_to_os)

      expect(manager).to have_received(:malloc_trim_linux)
    end

    it 'release_to_os dispatches mac path' do
      manager = manager_class.new
      allow(manager).to receive(:malloc_zone_pressure_relief_macos)
      allow(RbConfig::CONFIG).to receive(:[]).and_call_original
      allow(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return('darwin')

      manager.send(:release_to_os)

      expect(manager).to have_received(:malloc_zone_pressure_relief_macos)
    end

    it 'release_to_os dispatches windows path' do
      manager = manager_class.new
      allow(manager).to receive(:heapmin_windows)
      allow(RbConfig::CONFIG).to receive(:[]).and_call_original
      allow(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return('mingw')

      manager.send(:release_to_os)

      expect(manager).to have_received(:heapmin_windows)
    end

    it 'release_to_os rescues and reports failures' do
      manager = manager_class.new
      allow(manager).to receive(:malloc_trim_linux).and_raise(StandardError, 'boom')
      allow(manager).to receive(:respond)
      allow(RbConfig::CONFIG).to receive(:[]).and_call_original
      allow(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return('linux')

      manager.send(:release_to_os)

      expect(manager).to have_received(:respond).with(/Memory release to OS failed: boom/)
    end
  end

  describe 'start/stop/status behavior' do
    it 'start enqueues worker command and returns worker thread' do
      manager = manager_class.new
      queue = []
      worker = instance_double(Thread, alive?: true)

      allow(described_class).to receive(:command_queue).and_return(queue)
      allow(described_class).to receive(:worker_thread).and_return(worker)
      allow(manager).to receive(:running?).and_return(false, true)

      result = manager.start(interval: 180, verbose: true)

      expect(result).to eq(worker)
      expect(queue.size).to eq(1)
      expect(queue.first[:action]).to eq(:start_worker)
      expect(queue.first[:interval]).to eq(180)
      expect(queue.first[:verbose]).to be(true)
      expect(queue.first[:manager]).to eq(manager)
    end

    it 'start returns nil when worker fails to start before timeout' do
      manager = manager_class.new
      queue = []

      allow(described_class).to receive(:command_queue).and_return(queue)
      allow(manager).to receive(:running?).and_return(false)
      allow(manager).to receive(:sleep)
      allow(manager).to receive(:respond)

      expect(manager.start(interval: 180, verbose: false)).to be_nil
      expect(manager).to have_received(:respond).with(/ERROR: Worker thread failed to start/)
    end

    it 'stop disables manager and enqueues stop command' do
      manager = manager_class.new
      queue = []

      allow(described_class).to receive(:command_queue).and_return(queue)
      allow(manager).to receive(:sleep)

      manager.stop

      expect(manager.enabled).to be(false)
      expect(queue.last).to eq({ action: :stop_worker })
    end

    it 'running? uses worker thread liveness' do
      manager = manager_class.new
      allow(described_class).to receive(:worker_thread).and_return(instance_double(Thread, alive?: true))
      expect(manager.running?).to be(true)

      allow(described_class).to receive(:worker_thread).and_return(nil)
      expect(manager.running?).to be(false)
    end

    it 'status returns expected keys and values' do
      manager = manager_class.new
      allow(manager).to receive(:running?).and_return(true)
      allow(RbConfig::CONFIG).to receive(:[]).and_call_original
      allow(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return('linux')

      status = manager.status

      expect(status.keys).to contain_exactly(:running, :enabled, :auto_start, :interval, :verbose, :platform)
      expect(status[:running]).to be(true)
      expect(status[:platform]).to eq('linux')
    end
  end

  describe 'memory stats helpers' do
    it 'format_diff adds plus sign for non-negative values' do
      manager = manager_class.new

      expect(manager.send(:format_diff, 10)).to start_with('+')
      expect(manager.send(:format_diff, 0)).to start_with('+')
      expect(manager.send(:format_diff, -5)).to include('-5')
    end

    it 'print_memory_diff emits formatted output lines' do
      manager = manager_class.new
      allow(manager).to receive(:respond)

      before_stats = { heap_total_slots: 100, heap_allocated_pages: 10, malloc_increase_bytes: 1000, rss_mb: 50.0 }
      after_stats = { heap_total_slots: 90, heap_allocated_pages: 9, malloc_increase_bytes: 500, rss_mb: 45.0 }

      manager.send(:print_memory_diff, before_stats, after_stats)

      expect(manager).to have_received(:respond).with(/Heap Slots/)
      expect(manager).to have_received(:respond).with(/Heap Pages/)
      expect(manager).to have_received(:respond).with(/Malloc Increase/)
      expect(manager).to have_received(:respond).with(/Process RSS/)
    end

    it 'benchmark prints sections and triggers release' do
      manager = manager_class.new
      allow(manager).to receive(:respond)
      allow(manager).to receive(:release)
      allow(manager).to receive(:print_memory_stats).and_return(
        { heap_total_slots: 100, heap_allocated_pages: 10, malloc_increase_bytes: 1000, rss_mb: 50.0 },
        { heap_total_slots: 90, heap_allocated_pages: 9, malloc_increase_bytes: 500, rss_mb: 45.0 }
      )

      manager.benchmark

      expect(manager).to have_received(:release)
      expect(manager).to have_received(:respond).with(/Memory Usage Before Release/)
      expect(manager).to have_received(:respond).with(/Memory Usage After Release/)
      expect(manager).to have_received(:respond).with(/Change:/)
    end
  end

  describe 'process memory retrieval' do
    it 'parses linux VmRSS from /proc/self/status' do
      manager = manager_class.new
      allow(RbConfig::CONFIG).to receive(:[]).and_call_original
      allow(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return('linux')
      allow(File).to receive(:read).with('/proc/self/status').and_return("Name:\truby\nVmRSS:\t 20480 kB\n")

      expect(manager.send(:get_process_memory)).to eq(20.0)
    end

    it 'routes windows memory retrieval through windows helper' do
      manager = manager_class.new
      allow(RbConfig::CONFIG).to receive(:[]).and_call_original
      allow(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return('mingw')
      allow(manager).to receive(:get_process_memory_windows).and_return(123.4)

      expect(manager.send(:get_process_memory)).to eq(123.4)
    end

    it 'returns nil when memory read raises error' do
      manager = manager_class.new
      allow(RbConfig::CONFIG).to receive(:[]).and_call_original
      allow(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return('linux')
      allow(File).to receive(:read).and_raise(StandardError, 'read failed')

      expect(manager.send(:get_process_memory)).to be_nil
    end

    it 'windows helper falls back psapi -> wmi -> powershell -> nil' do
      manager = manager_class.new
      allow(manager).to receive(:get_memory_via_psapi).and_raise(StandardError, 'no psapi')
      allow(manager).to receive(:get_memory_via_wmi).and_raise(StandardError, 'no wmi')
      allow(manager).to receive(:get_memory_via_powershell).and_return(77.7)

      expect(manager.send(:get_process_memory_windows)).to eq(77.7)

      allow(manager).to receive(:get_memory_via_psapi).and_raise(StandardError, 'no psapi')
      allow(manager).to receive(:get_memory_via_wmi).and_raise(StandardError, 'no wmi')
      allow(manager).to receive(:get_memory_via_powershell).and_raise(StandardError, 'no ps')

      expect(manager.send(:get_process_memory_windows)).to be_nil
    end
  end

  describe 'singleton facade' do
    it 'memoizes the singleton manager instance' do
      manager = instance_double(manager_class, settings: { auto_start: false })
      allow(manager_class).to receive(:new).and_return(manager)

      expect(described_class.instance).to eq(manager)
      expect(described_class.instance).to eq(manager)
      expect(manager_class).to have_received(:new).once
    end

    it 'auto-starts when settings request auto_start' do
      manager = instance_double(manager_class, settings: { auto_start: true })
      allow(manager).to receive(:start)
      allow(manager_class).to receive(:new).and_return(manager)

      described_class.instance

      expect(manager).to have_received(:start)
    end

    it 'delegates facade methods to instance' do
      manager = instance_double(manager_class)
      allow(described_class).to receive(:instance).and_return(manager)

      allow(manager).to receive(:start).and_return(:thread)
      allow(manager).to receive(:stop)
      allow(manager).to receive(:auto_start!).and_return(:thread)
      allow(manager).to receive(:auto_disable!)
      allow(manager).to receive(:interval!).with(123).and_return(123)
      allow(manager).to receive(:verbose!).with(true).and_return(true)
      allow(manager).to receive(:release)
      allow(manager).to receive(:running?).and_return(false)
      allow(manager).to receive(:status).and_return({ running: false })
      allow(manager).to receive(:benchmark)

      expect(described_class.start(interval: 123, verbose: true)).to eq(:thread)
      described_class.stop
      expect(described_class.auto_start!).to eq(:thread)
      described_class.auto_disable!
      expect(described_class.interval!(123)).to eq(123)
      expect(described_class.verbose!(true)).to be(true)
      described_class.release
      expect(described_class.running?).to be(false)
      expect(described_class.status).to eq({ running: false })
      described_class.benchmark
    end

    it 'reset! stops existing instance and clears singleton' do
      manager = instance_double(manager_class)
      allow(manager).to receive(:stop)
      described_class.instance_variable_set(:@instance, manager)

      described_class.reset!

      expect(manager).to have_received(:stop)
      expect(described_class.instance_variable_get(:@instance)).to be_nil
    end
  end
end
