# frozen_string_literal: true

# DRBanking with several Lich sessions on one install.
#
# Every session here is a separate OS process (spec/support/drbanking_session_worker.rb)
# running the real Settings stack and DRBanking against one shared on-disk
# SQLite file, the way several characters logged in at once share lich.db3.

require 'json'
require 'rbconfig'
require 'tmpdir'
require 'fileutils'
require_relative '../../../support/settings_db'

RSpec.describe 'DRBanking across Lich sessions' do
  let(:lich_root) { File.expand_path('../../../..', __dir__) }
  let(:worker) { File.join(lich_root, 'spec/support/drbanking_session_worker.rb') }
  let(:reply_timeout) { 30 }
  let(:data_dir) { Dir.mktmpdir('drbanking-sessions-') }
  let(:sessions) { {} }

  before { SettingsSpecDB.prepare(data_dir) }

  after do
    # Closing a popen pipe ends the session (EOF on stdin) and reaps it.
    sessions.each_value { |s| s[:io].close unless s[:io].closed? }
    FileUtils.remove_entry(data_dir, true)
  end

  # Starts (or restarts) a session process for a character.
  def start(name, game: 'DR')
    stop(name) if sessions[name]
    err = File.join(data_dir, "#{name}.err")
    io = IO.popen([RbConfig.ruby, worker, lich_root, data_dir, game, name], 'r+', err: err)
    sessions[name] = { io: io, err: err }
  end

  def stop(name)
    sessions.delete(name)[:io].close
  end

  def send_command(name, command)
    sessions[name][:io].puts(command)
  end

  def read_reply(name)
    s = sessions[name]
    ready = IO.select([s[:io]], nil, nil, reply_timeout)
    raise "#{name}: no reply in #{reply_timeout}s. stderr: #{File.read(s[:err])}" unless ready

    line = s[:io].gets
    raise "#{name}: session exited. stderr: #{File.read(s[:err])}" unless line

    reply = JSON.parse(line)
    raise "#{name}: #{reply['error']}" if reply.key?('error')

    reply['value']
  end

  def ask(name, command)
    send_command(name, command)
    read_reply(name)
  end

  def banking_rows
    SettingsSpecDB.rows(data_dir)
  end

  describe 'balances written by different characters' do
    it "keeps every character's balance when sessions write in turn" do
      start('Alpha')
      start('Beta')
      ask('Alpha', 'update Crossings 100')
      ask('Beta', 'update Crossings 200')
      ask('Alpha', 'update Riverhaven 50')

      start('Gamma')
      expect(ask('Gamma', 'all')).to eq(
        'Alpha' => { 'Crossings' => 100, 'Riverhaven' => 50 },
        'Beta'  => { 'Crossings' => 200 }
      )
    end

    it 'keeps a character added after another session loaded' do
      start('Alpha')
      start('Beta')
      ask('Alpha', 'all')
      ask('Beta', 'update Shard 999')
      ask('Alpha', 'update Crossings 1')

      expect(ask('Beta', 'mine')).to eq('Shard' => 999)
      expect(ask('Alpha', 'all').keys).to contain_exactly('Alpha', 'Beta')
    end

    it 'builds a deposit on the balance this character recorded, not a reverted one' do
      start('Alpha')
      start('Beta')
      ask('Beta', 'all')
      ask('Alpha', 'update Crossings 1000')
      ask('Beta', 'update Shard 5')

      start('Alpha') # relaunch
      ask('Alpha', 'parse The clerk slides a small metal box across the counter into which you drop 5 gold Kronars')
      expect(ask('Alpha', 'mine')).to eq('Crossings' => 6000)
    end
  end

  describe ';banks all' do
    it "shows another session's later writes" do
      start('Alpha')
      start('Beta')
      expect(ask('Alpha', 'all')).to eq({})
      ask('Beta', 'update Crossings 200')

      expect(ask('Alpha', 'all')).to eq('Beta' => { 'Crossings' => 200 })
      expect(ask('Alpha', 'total_all')).to eq(200)
    end

    it "shows another session's later writes after reload!" do
      start('Alpha')
      start('Beta')
      ask('Alpha', 'all')
      ask('Beta', 'update Crossings 200')

      expect(ask('Alpha', 'reload')).to eq('Beta' => { 'Crossings' => 200 })
    end
  end

  describe 'resets' do
    it "keeps a character's reset when another session writes afterwards" do
      start('Alpha')
      start('Beta')
      ask('Alpha', 'update Crossings 100')
      ask('Beta', 'update Crossings 200')
      ask('Alpha', 'reset')
      ask('Beta', 'update Shard 7')

      expect(ask('Alpha', 'mine')).to eq({})
      expect(ask('Alpha', 'all')).to eq('Beta' => { 'Crossings' => 200, 'Shard' => 7 })
    end

    it "keeps reset all when a live session writes afterwards" do
      start('Alpha')
      start('Beta')
      ask('Alpha', 'update Crossings 100')
      ask('Beta', 'update Crossings 200')
      ask('Alpha', 'reset_all')
      ask('Beta', 'update Shard 7')

      expect(ask('Alpha', 'all')).to eq('Beta' => { 'Shard' => 7 })
    end
  end

  describe 'many sessions writing at once' do
    it 'loses no update' do
      names = %w[Alpha Beta Gamma Delta]
      names.each { |n| start(n) }
      names.each { |n| ask(n, 'all') } # every session has loaded before anyone writes
      towns = %w[Crossings Riverhaven Shard Hibarnhvidar Ratha]

      # Every session sends all its writes without waiting, so the processes
      # really overlap; then every reply is collected.
      names.each_with_index do |n, i|
        towns.each_with_index { |t, j| send_command(n, "update #{t} #{(i * 100) + j}") }
      end
      names.each { |n| towns.size.times { read_reply(n) } }

      expected = names.each_with_index.to_h do |n, i|
        [n, towns.each_with_index.to_h { |t, j| [t, (i * 100) + j] }]
      end
      start('Observer')
      expect(ask('Observer', 'all')).to eq(expected)
    end
  end

  describe 'moving the old shared row into per-character rows' do
    let(:legacy) do
      {
        'Alpha' => { 'Crossings' => 100 },
        'Beta'  => { 'Shard' => 7 },
        'Gamma' => { 'Riverhaven' => 3, 'Crossings' => 4 }
      }
    end

    before do
      SettingsSpecDB.write(data_dir, 'core', 'DR', { 'banking' => legacy, 'other' => 'kept' })
    end

    it 'moves every character on first use and keeps the rest of the old row' do
      start('Alpha')
      expect(ask('Alpha', 'all')).to eq(legacy)

      rows = banking_rows
      expect(rows[%w[core DR]]).to eq('other' => 'kept')
      expect(rows[['core.banking', 'DR:Alpha']]).to eq('Crossings' => 100)
      expect(rows[['core.banking', 'DR:Beta']]).to eq('Shard' => 7)
      expect(rows[['core.banking', 'DR:Gamma']]).to eq('Riverhaven' => 3, 'Crossings' => 4)
    end

    it 'gives the same result when several sessions start at once' do
      names = %w[Alpha Beta Gamma Delta]
      names.each { |n| start(n) }
      names.each { |n| send_command(n, 'all') }
      replies = names.to_h { |n| [n, read_reply(n)] }

      expect(replies.values).to all(eq(legacy))
      names.each { |n| expect(ask(n, 'messages').grep(/could not/)).to be_empty }
      expect(banking_rows.keys.count { |script, _scope| script == 'core.banking' }).to eq(3)
      expect(banking_rows[%w[core DR]]).to eq('other' => 'kept')
    end

    it "never overwrites a character's newer row when the old row comes back" do
      start('Alpha')
      ask('Alpha', 'update Crossings 555')
      ask('Alpha', 'reset') # Alpha has a row, now empty

      start('Beta')
      ask('Beta', 'update Shard 8')

      # A session still running an older Lich writes its stale copy back.
      stale = legacy.merge('Delta' => { 'Ratha' => 9 })
      SettingsSpecDB.write(data_dir, 'core', 'DR', { 'banking' => stale })

      expect(ask('Alpha', 'all')).to eq(
        'Beta'  => { 'Shard' => 8 },
        'Gamma' => { 'Riverhaven' => 3, 'Crossings' => 4 },
        'Delta' => { 'Ratha' => 9 }
      )
      expect(ask('Alpha', 'mine')).to eq({})
      expect(banking_rows[%w[core DR]]).to eq({})
    end

    it 'migrates on a write too, before writing' do
      start('Gamma')
      ask('Gamma', 'update Crossings 40')

      expect(banking_rows[['core.banking', 'DR:Gamma']]).to eq('Riverhaven' => 3, 'Crossings' => 40)
      expect(banking_rows[['core.banking', 'DR:Alpha']]).to eq('Crossings' => 100)
    end

    it 'leaves another game instance alone' do
      SettingsSpecDB.write(data_dir, 'core', 'DRF', { 'banking' => { 'Zed' => { 'Crossings' => 1 } } })
      start('Alpha')
      expect(ask('Alpha', 'all').keys).to contain_exactly('Alpha', 'Beta', 'Gamma')
      expect(banking_rows[%w[core DRF]]).to eq('banking' => { 'Zed' => { 'Crossings' => 1 } })

      start('Zed', game: 'DRF')
      expect(ask('Zed', 'all')).to eq('Zed' => { 'Crossings' => 1 })
    end
  end
end
