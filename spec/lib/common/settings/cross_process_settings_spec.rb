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

  describe 'reads (a session sees what other sessions committed)' do
    it 'shows a GameSettings key another session wrote after this one loaded the row' do
      alpha = start('DR', 'Alpha', 'go2')
      beta = start('DR', 'Beta', 'go2')
      expect(alpha.call('get G target')).to be_nil # alpha has cached the row

      beta.call('set G target "bank"')

      expect(alpha.call('get G target')).to eq('bank')
    end

    it 'shows a changed value, not only a new key' do
      alpha = start('DR', 'Alpha', 'go2')
      beta = start('DR', 'Beta', 'go2')
      alpha.call('set G mode "slow"')
      expect(beta.call('get G mode')).to eq('slow')

      alpha.call('set G mode "fast"')

      expect(beta.call('get G mode')).to eq('fast')
    end

    it 'shows a DragonRealms session\'s Settings key to a GemStone session' do
      dr = start('DR', 'Alpha', 'autostart')
      gs = start('GSIV', 'Zed', 'autostart')
      expect(gs.call('get S scripts')).to be_nil

      dr.call('set S scripts ["lnet"]')

      expect(gs.call('get S scripts')).to eq(['lnet'])
    end

    it 'shows a CharSettings key written by the same character in another process' do
      first = start('DR', 'Alpha', 'kill-counter')
      second = start('DR', 'Alpha', 'kill-counter')
      expect(second.call('get C kills')).to be_nil

      first.call('set C kills 7')

      expect(second.call('get C kills')).to eq(7)
    end

    it 'shows InstanceSettings keys, character-scoped and game-scoped (root proxy)' do
      alpha = start('DR', 'Alpha', 'any-script')
      other = start('DR', 'Alpha', 'other-script')
      beta = start('DR', 'Beta', 'any-script')
      expect(other.call('get I note')).to be_nil
      expect(beta.call('get IG shared')).to be_nil

      alpha.call('set I note "hi"')
      alpha.call('set IG shared {"Alpha":1}')

      expect(other.call('get I note')).to eq('hi')
      expect(beta.call('get IG shared')).to eq('Alpha' => 1)
    end

    it 'keeps a game-scoped InstanceSettings key another character wrote when writing its own' do
      alpha = start('DR', 'Alpha', 'any-script')
      beta = start('DR', 'Beta', 'any-script')
      beta.call('get IG anything')
      alpha.call('set IG alpha {"bank":1}')

      beta.call('set IG beta {"bank":2}')

      expect(stored_row('core', 'DR')).to eq('alpha' => { 'bank' => 1 }, 'beta' => { 'bank' => 2 })
    end

    it 'keeps both entries of a read-modify-write of one key done in turn by two sessions' do
      alpha = start('DR', 'Alpha', 'go2')
      beta = start('DR', 'Beta', 'go2')
      alpha.call('get G anything')
      beta.call('get G anything')

      # targets = GameSettings['custom targets'] || {}; targets[name] = room; GameSettings['custom targets'] = targets
      alpha.call('set G custom_targets {"foo":"1"}')
      targets = beta.call('get G custom_targets') || {}
      beta.call("set G custom_targets #{JSON.generate(targets.merge('bar' => '2'))}")

      expect(stored_row('go2', 'DR')).to eq('custom_targets' => { 'foo' => '1', 'bar' => '2' })
    end

    it 'keeps both entries when two sessions in turn write into one nested hash' do
      first = start('DR', 'Alpha', 'go2')
      second = start('DR', 'Beta', 'go2')
      first.call('set G opts {"x":0}')
      second.call('get G opts')

      first.call('nset G opts n 1')
      second.call('nset G opts m 2')

      expect(stored_row('go2', 'DR')).to eq('opts' => { 'x' => 0, 'n' => 1, 'm' => 2 })
    end

    it 'saves a nested write into a hash another session created after this one loaded the row' do
      first = start('DR', 'Alpha', 'go2')
      second = start('DR', 'Beta', 'go2')
      second.call('get G anything')
      first.call('set G opts {"x":0}')

      second.call('nset G opts z 3')

      expect(stored_row('go2', 'DR')).to eq('opts' => { 'x' => 0, 'z' => 3 })
    end

    it 'keeps both elements when two sessions in turn push onto one array' do
      first = start('DR', 'Alpha', 'go2')
      second = start('DR', 'Beta', 'go2')
      first.call('set G arr []')
      second.call('get G arr')

      first.call('push G arr "k1"')
      second.call('push G arr "l1"')

      expect(stored_row('go2', 'DR')).to eq('arr' => %w[k1 l1])
    end

    it 'does not show a change another process rolled back' do
      alpha = start('DR', 'Alpha', 'go2')
      alpha.call('set G mode "slow"')

      db = SQLite3::Database.new(File.join(data_dir, 'lich.db3'))
      begin
        db.execute('BEGIN IMMEDIATE')
        db.execute('UPDATE script_auto_settings SET hash = ? WHERE script = ? AND scope = ?',
                   [SQLite3::Blob.new(Marshal.dump('mode' => 'rolled back')), 'go2', 'DR'])
        expect(alpha.call('get G mode')).to eq('slow') # the change is not committed yet
        db.execute('ROLLBACK')
      ensure
        db.close
      end

      expect(alpha.call('get G mode')).to eq('slow')
    end

    it 'answers from its cache at once, without waiting out the busy timeout, while another process holds the lock' do
      alpha = start('DR', 'Alpha', 'go2') # default busy timeout (5 s)
      alpha.call('set G mode "slow"')
      alpha.call('get G mode')

      db = SQLite3::Database.new(File.join(data_dir, 'lich.db3'))
      begin
        db.execute('BEGIN EXCLUSIVE') # blocks readers too
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        expect(alpha.call('get G mode')).to eq('slow')
        expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 2.5
        db.execute('UPDATE script_auto_settings SET hash = ? WHERE script = ? AND scope = ?',
                   [SQLite3::Blob.new(Marshal.dump('mode' => 'fast')), 'go2', 'DR'])
        db.execute('COMMIT')
      ensure
        db.close
      end

      expect(alpha.call('get G mode')).to eq('fast')
      expect(alpha.call('msgs').select { |kind, _| kind == 'error' }).to be_empty
    end
  end

  describe 'write lock' do
    def with_write_lock
      db = SQLite3::Database.new(File.join(data_dir, 'lich.db3'))
      db.execute('BEGIN IMMEDIATE')
      yield db
    ensure
      db&.close
    end

    def put_row(db, script, scope, hash)
      db.execute('INSERT OR REPLACE INTO script_auto_settings (script, scope, hash) VALUES (?, ?, ?)',
                 [script, scope, SQLite3::Blob.new(Marshal.dump(hash))])
    end

    it 'keeps a change another process committed while this write waited for the lock' do
      alpha = start('DR', 'Alpha', 'go2')
      alpha.call('get G anything')

      with_write_lock do |db|
        alpha.send_command('set G alpha_key "1"') # blocks on the lock
        sleep 0.3
        put_row(db, 'go2', 'DR', { 'committed_while_waiting' => 'yes' })
        db.execute('COMMIT')
      end

      expect(alpha.answer).to eq('ok')
      expect(stored_row('go2', 'DR')).to eq('committed_while_waiting' => 'yes', 'alpha_key' => '1')
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
