# frozen_string_literal: true

# Cross-process Settings writes, through the real DatabaseAdapter.
#
# Every Lich session is its own OS process with its own settings cache, and
# all sessions of one install share DATA_DIR/lich.db3. Each example starts real
# worker processes (spec/support/settings_session_worker.rb) on one throwaway
# database and drives them one command at a time, so the interleaving is exact.
#
# NOTE: This spec intentionally does NOT require spec_helper. The code under
# test runs in the child processes; this process only drives them and reads
# the shared database file.

require 'rspec'
require 'json'
require 'rbconfig'
require 'tmpdir'
require 'fileutils'
require 'sqlite3'

RSpec.describe 'Settings writes across Lich processes' do
  worker_path = File.expand_path('../../../support/settings_session_worker.rb', __dir__)

  # One running Lich session.
  session_class = Class.new do
    attr_reader :label

    def initialize(worker_path, data_dir, game, char, script, env = {})
      @label = "#{char}/#{script}"
      @stderr = File.join(data_dir, "worker-#{char}-#{script}-#{object_id}.err")
      @io = IO.popen(env, [RbConfig.ruby, worker_path, data_dir, game, char, script], 'r+', err: @stderr)
    end

    # Sends one command without waiting for its answer.
    def send_command(line)
      @io.puts(line)
    end

    # Waits for the answer to the oldest unanswered command.
    def answer(timeout = 30)
      ready = IO.select([@io], nil, nil, timeout)
      raise "#{@label}: no answer within #{timeout}s; stderr: #{File.read(@stderr)}" unless ready

      line = @io.gets
      raise "#{@label}: worker exited; stderr: #{File.read(@stderr)}" if line.nil?

      result = JSON.parse(line).first
      raise "#{@label}: #{result['error']}" if result.is_a?(Hash) && result.key?('error') && result.size == 1

      result
    end

    # Whether an answer is waiting to be read.
    def answered?
      !IO.select([@io], nil, nil, 0).nil?
    end

    def call(line)
      send_command(line)
      answer
    end

    def close
      @io.close_write
      @io.close
    rescue IOError
      nil
    end
  end

  let(:data_dir) { Dir.mktmpdir('settings-cross-process-spec') }
  let(:sessions) { [] }

  define_method(:start) do |game, char, script, env = {}|
    session_class.new(worker_path, data_dir, game, char, script, env).tap { |s| sessions << s }
  end

  # The row as another process would read it, straight from the file.
  def stored_row(script, scope)
    db = SQLite3::Database.new(File.join(data_dir, 'lich.db3'))
    blob = db.get_first_value('SELECT hash FROM script_auto_settings WHERE script = ? AND scope = ?', [script, scope])
    blob ? Marshal.load(blob) : nil
  ensure
    db&.close
  end

  after do
    sessions.each(&:close)
    FileUtils.remove_entry(data_dir) if Dir.exist?(data_dir)
  end

  describe 'GameSettings (one row per game, shared by every character running the script)' do
    it 'keeps a key written by one session when another session writes a different key' do
      alpha = start('DR', 'Alpha', 'go2')
      beta = start('DR', 'Beta', 'go2')
      alpha.call('get G anything') # both sessions have loaded the row
      beta.call('get G anything')

      alpha.call('set G alpha_key "1"')
      beta.call('set G beta_key "2"')

      expect(stored_row('go2', 'DR')).to eq('alpha_key' => '1', 'beta_key' => '2')
    end

    it 'never erases keys written since a long-running session first loaded the row' do
      alpha = start('DR', 'Alpha', 'go2')
      alpha.call('get G anything')
      start('DR', 'Beta', 'go2').call('set G beta_key "2"')
      start('DR', 'Gamma', 'go2').call('set G gamma_key "3"')

      alpha.call('set G alpha_key "4"')

      expect(stored_row('go2', 'DR')).to eq('beta_key' => '2', 'gamma_key' => '3', 'alpha_key' => '4')
    end

    it 'lets the last writer win on the same key without touching other keys' do
      alpha = start('DR', 'Alpha', 'go2')
      beta = start('DR', 'Beta', 'go2')
      alpha.call('set G shared "from alpha"')
      alpha.call('set G alpha_only true')
      beta.call('set G shared "from beta"')

      expect(stored_row('go2', 'DR')).to eq('shared' => 'from beta', 'alpha_only' => true)
    end

    it 'shows the writer the other sessions\' keys once it has written' do
      alpha = start('DR', 'Alpha', 'go2')
      beta = start('DR', 'Beta', 'go2')
      beta.call('get G anything')
      alpha.call('set G alpha_key "1"')

      beta.call('set G beta_key "2"')

      expect(beta.call('get G alpha_key')).to eq('1')
    end

    it 'stores false, nil and container values as given' do
      alpha = start('DR', 'Alpha', 'go2')
      beta = start('DR', 'Beta', 'go2')
      beta.call('get G anything')
      alpha.call('set G keep "me"')

      beta.call('set G off false')
      beta.call('set G gone null')
      beta.call('set G targets {"bank":"1234"}')

      row = stored_row('go2', 'DR')
      expect(row).to eq('keep' => 'me', 'off' => false, 'gone' => nil, 'targets' => { 'bank' => '1234' })
      expect(row).to have_key('gone')
    end

    it 'keeps every key when several sessions write at the same time' do
      writers = %w[Alpha Beta Gamma].map { |char| start('DR', char, 'go2') }
      writers.each { |w| w.call('get G anything') }

      writers.each { |w| w.send_command("burst G #{w.label.split('/').first} 25") }
      writers.each { |w| expect(w.answer(60)).to eq('ok') }

      row = stored_row('go2', 'DR')
      expected = %w[Alpha Beta Gamma].flat_map { |char| (0...25).map { |i| ["#{char}_#{i}", i] } }.to_h
      expect(row).to eq(expected)
    end
  end

  describe 'Settings (one row shared by every character of every game)' do
    it 'keeps a DragonRealms session\'s key when a GemStone session writes' do
      dr = start('DR', 'Alpha', 'autostart')
      gs = start('GSIV', 'Zed', 'autostart')
      dr.call('get S anything')
      gs.call('get S anything')

      dr.call('set S dr_key "1"')
      gs.call('set S gs_key "2"')

      expect(stored_row('autostart', ':')).to eq('dr_key' => '1', 'gs_key' => '2')
    end
  end

  describe 'CharSettings (one row per character)' do
    it 'keeps both keys when the same character runs in two processes' do
      first = start('DR', 'Alpha', 'kill-counter')
      second = start('DR', 'Alpha', 'kill-counter')
      first.call('get C anything')
      second.call('get C anything')

      first.call('set C first_key 1')
      second.call('set C second_key 2')

      expect(stored_row('kill-counter', 'DR:Alpha')).to eq('first_key' => 1, 'second_key' => 2)
    end

    it 'leaves other characters\' rows alone' do
      start('DR', 'Alpha', 'kill-counter').call('set C mine 1')
      start('DR', 'Beta', 'kill-counter').call('set C mine 2')

      expect(stored_row('kill-counter', 'DR:Alpha')).to eq('mine' => 1)
      expect(stored_row('kill-counter', 'DR:Beta')).to eq('mine' => 2)
    end
  end

  describe 'InstanceSettings (core script, character scope)' do
    it 'keeps both keys when the same character runs in two processes' do
      first = start('DR', 'Alpha', 'any-script')
      second = start('DR', 'Alpha', 'other-script')
      first.call('get I anything')
      second.call('get I anything')

      first.call('set I first_key 1')
      second.call('set I second_key 2')

      expect(stored_row('core', 'DR:Alpha')).to eq('first_key' => 1, 'second_key' => 2)
    end
  end

  describe 'several threads of one session (several scripts in one process)' do
    it 'keeps every key and reports no error while another thread writes lich.db3' do
      alpha = start('DR', 'Alpha', 'go2', 'LICH_SPEC_BUSY_TIMEOUT_MS' => '1000')

      alpha.send_command('threads G t 4 150 200')
      expect(alpha.answer(240)).to eq('ok')

      row = stored_row('go2', 'DR')
      expected = (0...4).flat_map { |t| (0...150).map { |i| ["t_#{t}_#{i}", i] } }.to_h
      expect(row.reject { |k, _| k == 't_filler' }).to eq(expected)
      expect(row['t_filler'].size).to eq(200)
      expect(alpha.call('msgs').select { |kind, _| kind == 'error' }).to be_empty
    end
  end

  describe 'several sessions with several threads each' do
    it 'keeps every key and reports no error while each session also writes lich.db3' do
      writers = %w[Alpha Beta Gamma].map { |char| start('DR', char, 'go2') }

      writers.each { |w| w.send_command("threads G #{w.label.split('/').first} 2 60 50") }
      writers.each { |w| expect(w.answer(120)).to eq('ok') }

      row = stored_row('go2', 'DR')
      expected = %w[Alpha Beta Gamma].flat_map { |char| (0...2).flat_map { |t| (0...60).map { |i| ["#{char}_#{t}_#{i}", i] } } }.to_h
      expect(row.reject { |k, _| k.end_with?('_filler') }).to eq(expected)
      writers.each { |w| expect(w.call('msgs').select { |kind, _| kind == 'error' }).to be_empty }
    end
  end

  describe 'write lock' do
    def with_write_lock
      db = SQLite3::Database.new(File.join(data_dir, 'lich.db3'))
      # The worker's busy wait briefly takes a shared lock on each retry; give
      # this connection's COMMIT a busy timeout so it does not fail on one.
      db.busy_timeout = 5000
      db.execute('BEGIN IMMEDIATE')
      yield db
    ensure
      db&.close
    end

    def put_row(db, script, scope, hash)
      db.execute('INSERT OR REPLACE INTO script_auto_settings (script, scope, hash) VALUES (?, ?, ?)',
                 [script, scope, SQLite3::Blob.new(Marshal.dump(hash))])
    end

    [
      ['a row that does not exist yet (insert)', 'get G anything', {}],
      ['a stored row (conditional update)', 'set G before "1"', { 'before' => '1' }],
    ].each do |label, setup, committed_base|
      it "keeps a change another process committed while this write waited for the lock, on #{label}" do
        store_log = File.join(data_dir, 'store.log')
        alpha = start('DR', 'Alpha', 'go2', 'LICH_SPEC_STORE_LOG' => store_log)
        alpha.call(setup)
        File.delete(store_log) if File.exist?(store_log)

        with_write_lock do |db|
          alpha.send_command('set G alpha_key "1"')
          # Commit only once the write has read the row and is trying to store
          # it, which it cannot do while this lock is held.
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3
          sleep 0.01 until File.exist?(store_log) || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          expect(File.exist?(store_log)).to be(true), 'the write never reached its store'
          expect(alpha.answered?).to be(false)
          put_row(db, 'go2', 'DR', committed_base.merge('committed_while_waiting' => 'yes'))
          db.execute('COMMIT')
        end

        expect(alpha.answer).to eq('ok')
        expect(stored_row('go2', 'DR')).to eq(committed_base.merge('committed_while_waiting' => 'yes', 'alpha_key' => '1'))
        # The first store found the row changed, so it read the row again.
        expect(File.readlines(store_log).size).to eq(2)
      end
    end

    it 'reports a write that cannot get the lock and does not pretend it was saved' do
      alpha = start('DR', 'Alpha', 'go2', 'LICH_SPEC_BUSY_TIMEOUT_MS' => '200')
      alpha.call('set G before "1"')

      with_write_lock do |db|
        expect(alpha.call('set G during "2"')).to eq('ok')
        db.execute('ROLLBACK')
      end

      expect(stored_row('go2', 'DR')).to eq('before' => '1')
      expect(alpha.call('get G during')).to be_nil
      expect(alpha.call('msgs')).to include(['error', a_string_including('error while saving settings')])
    end

    it 'keeps answering reads from its cache after a failed write while the database is still locked' do
      alpha = start('DR', 'Alpha', 'go2', 'LICH_SPEC_BUSY_TIMEOUT_MS' => '200')
      alpha.call('set G before "1"')

      db = SQLite3::Database.new(File.join(data_dir, 'lich.db3'))
      begin
        db.execute('BEGIN EXCLUSIVE') # blocks readers too
        expect(alpha.call('set G during "2"')).to eq('ok')
        expect(alpha.call('get G before')).to eq('1')
        expect(alpha.call('get G during')).to be_nil
        db.execute('ROLLBACK')
      ensure
        db.close
      end

      expect(alpha.call('msgs')).to include(['error', a_string_including('error while saving settings')])
    end
  end
end
