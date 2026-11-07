# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'
require 'tmpdir'

RSpec.describe Lich::Genie::GlobalStore do
  describe 'in-memory (no file)' do
    subject(:store) { described_class.new(file: nil) }

    it 'stores, reads, and deletes values regardless of persist flag' do
      store.set('a', 1, persist: true)
      store.set('b', 2, persist: false)
      expect(store.get('a')).to eq('1')
      expect(store.get('b')).to eq('2')
      expect(store.key?('a')).to be(true)
      store.delete('a')
      expect(store.key?('a')).to be(false)
    end

    it 'has nowhere to save or load without a path' do
      store.set('a', '1')
      expect(store.save).to be(false)
      expect(store.load).to be(false)
      expect(store.get('a')).to eq('1')
    end

    it 're-setting a key replaces its persist flag both ways (Variables.Add)' do
      store.set('flip', '1', persist: true)
      store.set('flip', '2', persist: false)
      store.set('flop', '1', persist: false)
      store.set('flop', '2', persist: true)
      expect(store.persistent?('flip')).to be(false)
      expect(store.persistent?('flop')).to be(true)
    end
  end

  describe 'file-backed' do
    around { |example| Dir.mktmpdir { |dir| @dir = dir; example.run } }

    def path = File.join(@dir, 'Config', 'variables.cfg')

    it 'reads variables.cfg once at construction; loaded keys are persistent' do
      Lich::Genie::ConfigFile.write_lines(path, ['#var {mode} {hunt}', '#var {target} {a large kobold}'])
      store = described_class.new(file: path)
      expect(store.get('target')).to eq('a large kobold')
      expect(store.persistent?('mode')).to be(true)
    end

    it 'never writes on set/delete; only #save does' do
      store = described_class.new(file: path)
      store.set('mode', 'hunt', persist: true)
      store.delete('mode')
      store.set('kept', 'x', persist: true)
      expect(File.exist?(path)).to be(false)

      expect(store.save).to be(true)
      expect(File.binread(path)).to eq("#var {kept} {x}\r\n")
    end

    it 'saves bSaveToFile keys only: #tvar/#svar (persist:false) and Remix-reserved names are left out' do
      store = described_class.new(file: path)
      store.set('mode', 'hunt', persist: true)
      store.set('scratch', 'temp', persist: false)
      store.set('health', '55', persist: true)            # Remix-reserved
      store.set('CastTimeRemaining', '3', persist: true)  # NOT reserved: keys are case-sensitive
      store.save
      expect(File.binread(path)).to eq("#var {CastTimeRemaining} {3}\r\n#var {mode} {hunt}\r\n")
      expect(store.get('health')).to eq('55') # still readable this session
    end

    it 'never loads a Remix-reserved name from the file (an old write-through file shadowing live state)' do
      Lich::Genie::ConfigFile.write_lines(path, ['#var {invisible} {0}', '#var {roomname} {Old}', '#var {inside} {1}'])
      store = described_class.new(file: path)
      expect(store.key?('invisible')).to be(false)
      expect(store.key?('roomname')).to be(false)
      expect(store.get('inside')).to eq('1') # not Remix-reserved (a user var in the tester's file)
    end

    it 'does not see another process saving the same file until an explicit load' do
      store = described_class.new(file: path)
      store.set('shared', 'first')
      Lich::Genie::ConfigFile.write_lines(path, ['#var {shared} {second}', '#var {extra} {new}'])
      File.utime(Time.now + 5, Time.now + 5, path)
      expect(store.get('shared')).to eq('first')
      expect(store.key?('extra')).to be(false)

      expect(store.load).to be(true)
      expect([store.get('shared'), store.get('extra')]).to eq(%w[second new])
    end

    it 'load merges: keys missing from the file stay (Variables.Load does not clear)' do
      store = described_class.new(file: path)
      store.set('mine', '1')
      store.set('temp', '2', persist: false)
      Lich::Genie::ConfigFile.write_lines(path, ['#var {disk} {d}'])
      store.load
      expect(store.keys).to contain_exactly('mine', 'temp', 'disk')
    end

    it 'load(clear_first: true) drops persistent keys first and keeps temp keys (#load vars)' do
      store = described_class.new(file: path)
      store.set('mine', '1')
      store.set('temp', '2', persist: false)
      Lich::Genie::ConfigFile.write_lines(path, ['#var {disk} {d}'])
      store.load(clear_first: true)
      expect(store.keys).to contain_exactly('temp', 'disk')
    end

    it 'clear_user keeps #tvar/#svar keys (Variables.ClearUser)' do
      store = described_class.new(file: path)
      store.set('a', '1')
      store.set('t', '2', persist: false)
      store.clear_user
      expect(store.keys).to eq(['t'])
    end

    it 'load(path) remembers the path for later saves, even when the file does not exist' do
      store = described_class.new(file: path)
      other = File.join(@dir, 'Profiles', 'x', 'variables.cfg')
      expect(store.load(other)).to be(false)
      expect(store.file).to eq(other)
      store.set('k', 'v')
      store.save
      expect(File.binread(other)).to eq("#var {k} {v}\r\n")
      expect(File.exist?(path)).to be(false)
    end

    it 'save(path) writes elsewhere without changing the default path' do
      store = described_class.new(file: path)
      store.set('k', 'v')
      elsewhere = File.join(@dir, 'copy.cfg')
      expect(store.save(elsewhere)).to be(true)
      expect(store.file).to eq(path)
    end

    it 'keeps every value in memory and returns false when the write fails' do
      store = described_class.new(file: File.join(@dir, 'blocker', 'variables.cfg'))
      File.write(File.join(@dir, 'blocker'), 'a file where the directory should be')
      store.set('charges', '34')
      expect(store.save).to be(false)
      expect(store.get('charges')).to eq('34')
    end

    it 'leaves the previous file intact when a save fails mid-write' do
      store = described_class.new(file: path)
      store.set('a', '1')
      store.save
      store.set('a', '2')
      allow(File).to receive(:rename).and_raise(Errno::EACCES)
      allow(File).to receive(:binwrite).and_call_original
      allow(File).to receive(:binwrite).with(path, anything).and_raise(Errno::EACCES)
      allow(Lich::Genie::ConfigFile).to receive(:sleep)
      expect(store.save).to be(false)
      expect(File.binread(path)).to eq("#var {a} {1}\r\n")
      expect(Dir.children(File.dirname(path))).to eq(['variables.cfg']) # temp file cleaned up
    end

    # Variables.Load is catch (Exception) -> false (Globals.cs:757-762 R): an unreadable
    # file (EACCES, a Windows lock held by AV/an indexer) must never raise out of the
    # engine -- the glue builds this store at engine start.
    context 'when variables.cfg cannot be read' do
      before do
        Lich::Genie::ConfigFile.write_lines(path, ['#var {disk} {1}'])
        allow(File).to receive(:binread).and_call_original
        allow(File).to receive(:binread).with(path).and_raise(Errno::EACCES, path)
      end

      it 'constructs empty without raising, and keeps the path as the save target' do
        store = described_class.new(file: path)
        expect(store.keys).to eq([])
        expect(store.file).to eq(path)
      end

      it 'load (#var load) returns false and keeps every key' do
        store = described_class.new(file: nil)
        store.set('mine', '2')
        expect(store.load(path)).to be(false)
        expect(store.get('mine')).to eq('2')
      end

      it 'load(clear_first: true) (#load vars) returns false after ClearUser emptied the persistent keys' do
        store = described_class.new(file: nil)
        store.set('mine', '2')
        store.set('temp', '3', persist: false)
        expect(store.load(path, clear_first: true)).to be(false)
        expect([store.get('mine'), store.get('temp')]).to eq([nil, '3'])
      end
    end

    it 'save returns false instead of raising on a non-I/O error (Save is catch (Exception), Globals.cs:818-822 R)' do
      store = described_class.new(file: path)
      store.set('good', '1')
      allow(Lich::Genie::VariableFile).to receive(:save).and_raise(TypeError, 'boom')
      expect(store.save).to be(false)
      expect(store.get('good')).to eq('1')
      expect(File.exist?(path)).to be(false)
    end

    # Remix strings are never invalid (StreamReader decodes bad bytes to U+FFFD), so its
    # Save writes every row (Globals.cs:794-803 R). One bad key must not cost the rest.
    it 'save writes every row when one key is UTF-8-tagged with invalid bytes (key written as U+FFFD)' do
      store = described_class.new(file: path)
      store.set("bad#{[0xFF].pack('C')}".dup.force_encoding(Encoding::UTF_8), '1')
      store.set('good', '2')
      store.set('aaa', '3')
      expect(store.save).to be(true)
      rows = File.binread(path).force_encoding(Encoding::UTF_8).split("\r\n")
      expect(rows).to eq(['#var {aaa} {3}', "#var {bad#{[0xFFFD].pack('U')}} {1}", '#var {good} {2}'])
    end

    it 'stops loading at a row ParseArgs rejects, keeping the rows before it (Remix Load catch)' do
      Lich::Genie::ConfigFile.write_lines(path, ['#var {x} {1}', "#var {'} {1}", '#var {y} {1}'])
      store = described_class.new(file: path)
      expect(store.keys).to eq(['x'])
      expect(store.load).to be(false)
    end

    it 'round-trips a file it saved byte for byte' do
      store = described_class.new(file: path)
      { 'zeta' => '1', 'Alpha' => '2', 'alpha' => '3', '.pvp' => 'moza 0', 'pw(sling' => '0',
        'brace' => 'x {y} z', 'empty' => '', 'ExpTracker.REXP_Usable' => '1' }.each { |k, v| store.set(k, v) }
      store.save
      first = File.binread(path)
      described_class.new(file: path).save
      expect(File.binread(path)).to eq(first)
      expect(first.lines.map { |l| l[/\{(.*?)\}/, 1] })
        .to eq(['.pvp', 'alpha', 'Alpha', 'brace', 'empty', 'ExpTracker.REXP_Usable', 'pw(sling', 'zeta'])
    end

    # One store is shared by script threads AND the trigger thread. Saves and loads
    # race plain sets here; nothing may raise, no key may be lost, and every file
    # snapshot on disk must be a complete, parseable save.
    it 'stays consistent under concurrent sets, saves and loads (thread safety)' do
      store = described_class.new(file: path)
      store.set('backpack', 'sling bag')
      store.save
      errors = []
      threads = Array.new(2) do |w|
        Thread.new do
          200.times { |i| store.set("k#{w}_#{i % 7}", (w * 1000 + i).to_s, persist: i.even?) }
        rescue StandardError => e
          errors << e
        end
      end
      threads << Thread.new do
        50.times { store.save }
      rescue StandardError => e
        errors << e
      end
      threads << Thread.new do
        50.times do
          store.load
          errors << 'backpack lost' unless store.get('backpack') == 'sling bag'
        end
      rescue StandardError => e
        errors << e
      end
      threads.each(&:join)

      expect(errors).to be_empty
      store.save
      reread = described_class.new(file: path)
      expect(reread.get('backpack')).to eq('sling bag')
      expect(File.binread(path)).to eq(Lich::Genie::VariableFile.dump(Lich::Genie::VariableFile.load(path)))
    end

    # A contended Windows rename can keep VariableFile.save retrying for ~0.5 s; the
    # trigger thread's `#var` must not wait for it (Remix's Add does not take the lock
    # Save holds). The snapshot is taken under the lock, the write happens outside it.
    it 'does not block get/set while a save is still writing, and saves the snapshot taken first' do
      store = described_class.new(file: path)
      store.set('before', '1')
      entered = Queue.new
      release = Queue.new
      written = nil
      allow(Lich::Genie::VariableFile).to receive(:save) do |_target, rows|
        entered << true
        release.pop
        written = rows
      end
      saver = Thread.new { store.save }
      begin
        entered.pop
        setter = Thread.new do
          store.set('during', '2')
          store.get('before')
        end
        expect(setter.join(2)).not_to be_nil
        expect(setter.value).to eq('1')
      ensure
        release << true
      end
      expect(saver.value).to be(true)
      expect(written).to eq('before' => '1')
      expect(store.get('during')).to eq('2')
    end

    it 'serializes concurrent saves so an older snapshot never lands after a newer one' do
      store = described_class.new(file: path)
      store.set('v', '1')
      order = Queue.new
      entered = Queue.new
      release = Queue.new
      allow(Lich::Genie::VariableFile).to receive(:save) do |_target, rows|
        entered << rows['v']
        release.pop if rows['v'] == '1'
        order << rows['v']
      end
      first = Thread.new { store.save }
      begin
        expect(entered.pop).to eq('1')
        setter = Thread.new { store.set('v', '2') }
        expect(setter.join(2)).not_to be_nil
        second = Thread.new { store.save }
        sleep 0.05
        expect(entered.size).to eq(0) # the second save waits for the first write
      ensure
        release << true
      end
      [first, second].compact.each { |t| t.join(2) }
      expect(Array.new(order.size) { order.pop }).to eq(%w[1 2])
    end

    # Regression guard (globals once reset to their literal text mid-combat). `#load vars` =
    # ClearUser + Load in ONE critical section: the file read between them is a GVL switch
    # point, so without the lock another thread
    # (a script, the trigger thread) sees a persistent key vanish, and a concurrent save
    # snapshots the half-loaded store. Fails when GlobalStore's mutex is removed.
    it 'never exposes the ClearUser/Load gap to readers or to a concurrent save' do
      store = described_class.new(file: path)
      store.set('backpack', 'sling bag')
      300.times { |i| store.set("k#{i}", i.to_s) }
      store.save
      snapshot = File.join(@dir, 'snapshot.cfg')
      gaps = Queue.new
      stop = false
      reader = Thread.new do
        gaps << 'reader saw backpack nil' if store.get('backpack').nil? until stop
      end
      saver = Thread.new do
        until stop
          store.save(snapshot)
          gaps << 'save snapshot missing backpack' unless File.binread(snapshot).include?('#var {backpack} {sling bag}')
        end
      end
      100.times { store.load(clear_first: true) }
      stop = true
      [reader, saver].each(&:join)

      expect(gaps.size).to eq(0), "observed: #{Array.new(gaps.size) { gaps.pop }.uniq}"
      expect(store.get('backpack')).to eq('sling bag')
    end
  end

  # Each write takes a WriteClock stamp so a later game update can win over it.
  describe 'write stamps' do
    let(:clock) { Lich::Genie::WriteClock.new }
    subject(:store) { described_class.new(write_clock: clock) }

    it 'stamps set, re-stamps an overwrite and forgets on delete / clear_user' do
      store.set('a', 1)
      first = store.stamp('a')
      store.set('a', 2, persist: false)
      expect(store.stamp('a')).to be > first
      store.delete('a')
      expect(store.stamp('a')).to be_nil
      store.set('b', 1)
      store.clear_user
      expect(store.stamp('b')).to be_nil
    end

    it 'stamps the rows a load merges in' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'variables.cfg')
        File.write(path, "#var {x} {1}\r\n")
        store.load(path)
        expect(store.stamp('x')).to be_a(Integer)
      end
    end

    it 'shares one increasing clock between stores (and game states)' do
      other = described_class.new(write_clock: clock)
      store.set('a', 1)
      other.set('a', 1)
      expect(other.stamp('a')).to be > store.stamp('a')
    end
  end

  # The VariableType the listing groups by (ListVariables, Command.cs:3002-3079 R).
  describe '#kind' do
    it 'tells SaveToFile, temporary and server keys apart; a later set re-types the key' do
      store = described_class.new(file: nil)
      store.set('a', '1')
      store.set('b', '2', persist: false)
      store.set('c', '3', persist: false, server: true)
      expect(%w[a b c none].map { |k| store.kind(k) }).to eq([:save, :temporary, :server, nil])
      store.set('c', '4')
      expect(store.kind('c')).to eq(:save)
      store.delete('a')
      expect(store.kind('a')).to be_nil
    end
  end
end
