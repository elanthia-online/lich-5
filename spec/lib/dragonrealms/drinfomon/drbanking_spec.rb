# frozen_string_literal: true

require_relative '../../../spec_helper'
require_relative '../../../support/lich_sqlite'
require_relative '../../../support/settings_db'

require_relative '../../../../lib/common/settings/database_adapter'
require_relative '../../../../lib/dragonrealms/drinfomon/drvariables'
require_relative '../../../../lib/dragonrealms/drinfomon/drbanking'

# Note: XMLData and Lich::Messaging are provided by spec_helper.rb
# We use Lich::Messaging.messages/clear_messages! for test assertions

RSpec.describe Lich::DragonRealms::DRBanking do
  let(:described_module) { Lich::DragonRealms::DRBanking }

  # Each example gets its own on-disk settings database, reached through a real
  # DatabaseAdapter (the one Settings.db_adapter returns in Lich).
  let(:data_dir) { Dir.mktmpdir('drbanking-spec-') }
  let(:adapter) { Lich::Common::DatabaseAdapter.new(data_dir, :script_auto_settings) }

  # Helper to extract message strings from Lich::Messaging (provided by spec_helper)
  def message_strings
    Lich::Messaging.messages.map { |m| m.is_a?(Hash) ? m[:message] : m.to_s }
  end

  def rows
    SettingsSpecDB.rows(data_dir)
  end

  def seed_legacy(banking, extra = {})
    SettingsSpecDB.write(data_dir, 'core', 'DR', extra.merge('banking' => banking))
  end

  def seed_row(name, towns, game: 'DR')
    SettingsSpecDB.write(data_dir, 'core.banking', "#{game}:#{name}", towns)
  end

  # A damaged Marshal blob that makes Marshal.load raise RegexpError, not one
  # of the TypeError/ArgumentError a truncated blob gives.
  def seed_regexp_error_row(script, scope)
    blob = ['04082f15ec56363a59ce5b937ad9c27ee5baa09dcadc946f2c450c9dc421cec32573a634d6e7bd'].pack('H*')
    expect { Marshal.load(blob) }.to raise_error(RegexpError)
    SettingsSpecDB.write_raw(data_dir, script, scope, blob)
  end

  before(:each) do
    Lich::Messaging.clear_messages!

    # XMLData is reset by spec_helper's before(:each) via reset_xml_data!
    # Just set room_title which isn't reset by default
    XMLData.room_title = ''

    allow(XMLData).to receive(:game).and_return('DR')
    SettingsSpecDB.prepare(data_dir)
    allow(described_module).to receive(:adapter).and_return(adapter)
  end

  after(:each) do
    adapter.instance_variable_get(:@db)&.disconnect
    FileUtils.remove_entry(data_dir, true)
  end

  describe 'Pattern constants' do
    describe 'DEPOSIT_PORTION' do
      let(:pattern) { described_module::Pattern::DEPOSIT_PORTION }

      it 'matches deposit with platinum Kronars' do
        line = 'The clerk slides a small metal box across the counter into which you drop 5 platinum Kronars'
        match = pattern.match(line)
        expect(match).not_to be_nil
        expect(match[:amount]).to eq('5')
        expect(match[:denomination]).to eq('platinum')
        expect(match[:currency]).to eq('Kronars')
      end

      it 'matches deposit with gold Lirums' do
        line = 'The clerk slides a small metal box across the counter into which you drop 10 gold Lirums'
        match = pattern.match(line)
        expect(match).not_to be_nil
        expect(match[:amount]).to eq('10')
        expect(match[:denomination]).to eq('gold')
        expect(match[:currency]).to eq('Lirums')
      end

      it 'matches deposit with copper Dokoras' do
        line = 'The clerk slides a small metal box across the counter into which you drop 100 copper Dokoras'
        match = pattern.match(line)
        expect(match).not_to be_nil
        expect(match[:amount]).to eq('100')
        expect(match[:denomination]).to eq('copper')
        expect(match[:currency]).to eq('Dokoras')
      end

      it 'does not match unrelated text' do
        line = 'You pick up a bag of coins.'
        expect(pattern.match(line)).to be_nil
      end
    end

    describe 'DEPOSIT_ALL_TELLER' do
      let(:pattern) { described_module::Pattern::DEPOSIT_ALL_TELLER }

      it 'matches deposit all Kronars' do
        line = 'The clerk slides a small metal box across the counter into which you drop all your Kronars.  She counts them carefully and records the deposit in her ledger'
        expect(pattern.match(line)).not_to be_nil
        expect(pattern.match(line)[:currency]).to eq('Kronars')
      end

      it 'matches deposit all Lirums' do
        line = 'The clerk slides a small metal box across the counter into which you drop all your Lirums.  She counts them carefully and records the deposit in her ledger'
        expect(pattern.match(line)).not_to be_nil
        expect(pattern.match(line)[:currency]).to eq('Lirums')
      end

      it 'matches deposit all Dokoras' do
        line = 'The clerk slides a small metal box across the counter into which you drop all your Dokoras.  She counts them carefully and records the deposit in her ledger'
        expect(pattern.match(line)).not_to be_nil
        expect(pattern.match(line)[:currency]).to eq('Dokoras')
      end
    end

    describe 'DEPOSIT_ALL_JAR' do
      let(:pattern) { described_module::Pattern::DEPOSIT_ALL_JAR }

      it 'matches jar bank deposit' do
        line = 'You cross through the old balance on the label and update it to reflect your new balance'
        expect(pattern.match(line)).not_to be_nil
      end
    end

    describe 'WITHDRAW_PORTION' do
      let(:pattern) { described_module::Pattern::WITHDRAW_PORTION }

      it 'matches clerk withdraw' do
        line = 'The clerk counts out 5 gold Kronars and hands them over, making a notation in her ledger'
        match = pattern.match(line)
        expect(match).not_to be_nil
        expect(match[:amount]).to eq('5')
        expect(match[:denomination]).to eq('gold')
        expect(match[:currency]).to eq('Kronars')
      end

      it 'matches jar withdraw' do
        line = 'You count out 10 silver Dokoras and quickly pocket them, updating the notation on your jar'
        match = pattern.match(line)
        expect(match).not_to be_nil
        expect(match[:amount]).to eq('10')
        expect(match[:denomination]).to eq('silver')
        expect(match[:currency]).to eq('Dokoras')
      end
    end

    describe 'WITHDRAW_ALL' do
      let(:pattern) { described_module::Pattern::WITHDRAW_ALL }

      it 'matches clerk withdraw all' do
        line = 'The clerk counts out all your Kronars and hands them over'
        expect(pattern.match(line)).not_to be_nil
        expect(pattern.match(line)[:currency]).to eq('Kronars')
      end

      it 'matches jar withdraw all' do
        line = 'You count out all of your Dokoras and quickly pocket them'
        expect(pattern.match(line)).not_to be_nil
        expect(pattern.match(line)[:currency]).to eq('Dokoras')
      end
    end

    describe 'BALANCE_CHECK' do
      let(:pattern) { described_module::Pattern::BALANCE_CHECK }

      it 'matches "it looks like" balance check' do
        line = 'it looks like your current balance is 5 platinum Kronars'
        match = pattern.match(line)
        expect(match).not_to be_nil
        expect(match[:balance]).to eq('5 platinum')
        expect(match[:currency]).to eq('Kronars')
      end

      it 'matches "Here we are" balance check' do
        line = '"Here we are. Your current balance is 10 gold, 5 silver Lirums'
        match = pattern.match(line)
        expect(match).not_to be_nil
        expect(match[:currency]).to eq('Lirums')
      end

      it 'matches "As expected" balance check' do
        line = 'As expected, there are 100 copper Dokoras'
        match = pattern.match(line)
        expect(match).not_to be_nil
        expect(match[:balance]).to eq('100 copper')
        expect(match[:currency]).to eq('Dokoras')
      end
    end

    describe 'NO_ACCOUNT' do
      let(:pattern) { described_module::Pattern::NO_ACCOUNT }

      it 'matches no account at teller bank' do
        line = 'you do not seem to have an account with us'
        expect(pattern.match(line)).not_to be_nil
      end

      it 'matches no account at jar bank' do
        line = 'you should find a new deposit jar for your financial needs'
        expect(pattern.match(line)).not_to be_nil
      end
    end
  end

  describe 'DENOMINATION_VALUES constant' do
    it 'DENOMINATION_VALUES hash is frozen to prevent modification' do
      expect(described_module::DENOMINATION_VALUES).to be_frozen
    end

    it 'has correct values for platinum' do
      expect(described_module::DENOMINATION_VALUES['platinum']).to eq(10_000)
    end

    it 'has correct values for gold' do
      expect(described_module::DENOMINATION_VALUES['gold']).to eq(1_000)
    end

    it 'has correct values for silver' do
      expect(described_module::DENOMINATION_VALUES['silver']).to eq(100)
    end

    it 'has correct values for bronze' do
      expect(described_module::DENOMINATION_VALUES['bronze']).to eq(10)
    end

    it 'has correct values for copper' do
      expect(described_module::DENOMINATION_VALUES['copper']).to eq(1)
    end
  end

  describe 'CURRENCY_BANKS constant' do
    it 'CURRENCY_BANKS hash is frozen to prevent modification' do
      expect(described_module::CURRENCY_BANKS).to be_frozen
    end

    it 'maps Kronars to KRONAR_BANKS' do
      expect(described_module::CURRENCY_BANKS['Kronars']).to eq(Lich::DragonRealms::KRONAR_BANKS)
    end

    it 'maps Lirums to LIRUM_BANKS' do
      expect(described_module::CURRENCY_BANKS['Lirums']).to eq(Lich::DragonRealms::LIRUM_BANKS)
    end

    it 'maps Dokoras to DOKORA_BANKS' do
      expect(described_module::CURRENCY_BANKS['Dokoras']).to eq(Lich::DragonRealms::DOKORA_BANKS)
    end
  end

  describe '.all_accounts' do
    it 'returns empty hash when no data' do
      expect(described_module.all_accounts).to eq({})
    end

    it 'returns all character accounts' do
      seed_row('CharA', { 'Crossings' => 10_000 })
      seed_row('CharB', { 'Shard' => 20_000 })
      accounts = described_module.all_accounts
      expect(accounts['CharA']).to eq({ 'Crossings' => 10_000 })
      expect(accounts['CharB']).to eq({ 'Shard' => 20_000 })
    end

    it 'reads the database on every call' do
      expect(described_module.all_accounts).to eq({})
      seed_row('CharB', { 'Shard' => 1 })
      expect(described_module.all_accounts).to eq('CharB' => { 'Shard' => 1 })
    end

    it 'returns a copy: changing it changes nothing stored' do
      seed_row('CharA', { 'Crossings' => 10 })
      described_module.all_accounts['CharA']['Crossings'] = 99
      described_module.all_accounts['CharZ'] = { 'Shard' => 1 }
      expect(described_module.all_accounts).to eq('CharA' => { 'Crossings' => 10 })
    end

    it 'leaves out characters whose data was cleared' do
      seed_row('CharA', {})
      seed_row('CharB', { 'Shard' => 0 })
      expect(described_module.all_accounts).to eq('CharB' => { 'Shard' => 0 })
    end

    it 'shows only rows of the current game instance' do
      seed_row('CharA', { 'Crossings' => 1 })
      seed_row('CharF', { 'Crossings' => 2 }, game: 'DRF')
      expect(described_module.all_accounts.keys).to eq(['CharA'])

      allow(XMLData).to receive(:game).and_return('DRF')
      expect(described_module.all_accounts).to eq('CharF' => { 'Crossings' => 2 })
    end

    it 'skips a row it cannot read and still shows the others' do
      SettingsSpecDB.write_raw(data_dir, 'core.banking', 'DR:Broken', 'not a marshal dump')
      seed_row('CharA', { 'Crossings' => 1 })
      expect(described_module.all_accounts).to eq('CharA' => { 'Crossings' => 1 })
    end

    it 'returns {} when the game is not known yet' do
      seed_row('CharA', { 'Crossings' => 1 })
      allow(XMLData).to receive(:game).and_return(nil)
      expect(described_module.all_accounts).to eq({})
    end

    it 'reports a database error and returns {}' do
      allow(adapter).to receive(:get_settings_by_scope_prefix).and_raise(Sequel::DatabaseError, 'database is locked')
      expect(described_module.all_accounts).to eq({})
      expect(message_strings.last).to include('could not read bank data', 'database is locked')
    end
  end

  describe 'moving the old shared row' do
    it 'moves each character into its own row and removes only the banking key' do
      seed_legacy({ 'CharA' => { 'Crossings' => 10_000 }, 'CharB' => { 'Shard' => 20_000 } }, 'other' => 1)
      expect(described_module.all_accounts).to eq('CharA' => { 'Crossings' => 10_000 }, 'CharB' => { 'Shard' => 20_000 })
      expect(rows).to eq(
        %w[core DR]                  => { 'other' => 1 },
        ['core.banking', 'DR:CharA'] => { 'Crossings' => 10_000 },
        ['core.banking', 'DR:CharB'] => { 'Shard' => 20_000 }
      )
    end

    it 'does nothing the second time' do
      seed_legacy({ 'CharA' => { 'Crossings' => 1 } })
      described_module.all_accounts
      before = rows
      expect(adapter).not_to receive(:transaction)
      described_module.all_accounts
      expect(rows).to eq(before)
    end

    it 'keeps an existing row over the old entry for the same character' do
      seed_row('CharA', { 'Shard' => 5 })
      seed_legacy({ 'CharA' => { 'Crossings' => 1 }, 'CharB' => { 'Crossings' => 2 } })
      expect(described_module.all_accounts).to eq('CharA' => { 'Shard' => 5 }, 'CharB' => { 'Crossings' => 2 })
    end

    it 'drops malformed entries and keeps the well-formed parts' do
      seed_legacy({
        'CharA' => { 'Crossings' => 10, 'Shard' => 'lots', 5 => 3, 'Ratha' => 2.9 },
        'CharB' => 'not a hash',
        ''      => { 'Crossings' => 1 },
        ' '     => { 'Crossings' => 1 },
        :symbol => { 'Crossings' => 1 },
        'CharC' => nil
      })
      expect(described_module.all_accounts).to eq('CharA' => { 'Crossings' => 10, 'Ratha' => 2 })
      expect(rows.keys).to contain_exactly(%w[core DR], ['core.banking', 'DR:CharA'])
      expect(rows[%w[core DR]]).to eq({})
    end

    it 'removes a banking key that holds no hash' do
      seed_legacy(nil)
      expect(described_module.all_accounts).to eq({})
      expect(rows[%w[core DR]]).to eq({})
    end

    it 'ignores an unreadable old row instead of blocking reads and writes' do
      XMLData.name = 'CharA'
      SettingsSpecDB.write_raw(data_dir, 'core', 'DR', 'not a marshal dump')
      seed_row('CharB', { 'Shard' => 2 })

      described_module.update_balance('Crossings', 7)
      expect(described_module.all_accounts).to eq('CharA' => { 'Crossings' => 7 }, 'CharB' => { 'Shard' => 2 })
      expect(message_strings.grep(/could not/)).to be_empty
    end

    it 'ignores an old row whose load raises an unusual error, for every operation' do
      XMLData.name = 'CharA'
      seed_regexp_error_row('core', 'DR')
      seed_row('CharB', { 'Shard' => 2 })

      expect(described_module.all_accounts).to eq('CharB' => { 'Shard' => 2 })
      described_module.update_balance('Crossings', 7)
      expect(described_module.my_accounts).to eq('Crossings' => 7)
      described_module.reset_character!
      expect(described_module.my_accounts).to eq({})
      described_module.reset_all!
      expect(message_strings.grep(/could not/)).to be_empty
      expect(message_strings.last).to include('Cleared all bank data')
      expect(rows[['core.banking', 'DR:CharB']]).to eq({})
    end

    it 'drops old amounts that are not finite numbers instead of failing on them' do
      XMLData.name = 'CharA'
      seed_legacy({
        'CharA' => { 'Crossings' => Float::INFINITY, 'Shard' => 3, 'Ratha' => Float::NAN, 'Riverhaven' => 2.9 },
        'CharB' => { 'Crossings' => Rational(1, 3), 'Shard' => 4 }
      })

      expect(described_module.all_accounts).to eq('CharA' => { 'Shard' => 3, 'Riverhaven' => 2 }, 'CharB' => { 'Shard' => 4 })
      described_module.update_balance('Crossings', 7)
      expect(described_module.my_accounts).to eq('Crossings' => 7, 'Shard' => 3, 'Riverhaven' => 2)
      expect(message_strings.grep(/could not/)).to be_empty
    end

    it 'drops an old entry whose name is not valid text instead of failing on it' do
      seed_legacy({ ([0xFF].pack('C') + 'Bad ').force_encoding('UTF-8') => { 'Crossings' => 1 }, 'CharB' => { 'Shard' => 2 } })

      expect(described_module.all_accounts).to eq('CharB' => { 'Shard' => 2 })
      expect(message_strings.grep(/could not/)).to be_empty
      expect(rows[%w[core DR]]).to eq({})
    end

    it 'still shows the old entries, read-only, when the move fails' do
      seed_legacy({ 'CharA' => { 'Crossings' => 1 } })
      seed_row('CharB', { 'Shard' => 2 })
      allow(adapter).to receive(:transaction).and_raise(Sequel::DatabaseError, 'database is locked')

      expect(described_module.all_accounts).to eq('CharA' => { 'Crossings' => 1 }, 'CharB' => { 'Shard' => 2 })
      expect(message_strings.last).to include('could not move old bank data', 'database is locked')
      expect(rows[%w[core DR]]).to eq('banking' => { 'CharA' => { 'Crossings' => 1 } })
    end

    it "doesn't show an old entry over an existing row it can't load when the move fails" do
      SettingsSpecDB.write_raw(data_dir, 'core.banking', 'DR:CharA', 'garbage')
      seed_legacy({ 'CharA' => { 'Crossings' => 1 }, 'CharB' => { 'Shard' => 2 } })
      allow(Lich).to receive(:log)
      allow(adapter).to receive(:transaction).and_raise(Sequel::DatabaseError, 'database is locked')

      # The move would keep CharA's row, so the old entry isn't shown for it.
      expect(described_module.all_accounts).to eq('CharB' => { 'Shard' => 2 })
    end

    it 'moves the data before a write, in the same transaction' do
      XMLData.name = 'CharA'
      seed_legacy({ 'CharA' => { 'Crossings' => 1, 'Shard' => 2 } })
      described_module.update_balance('Crossings', 7)
      expect(rows[['core.banking', 'DR:CharA']]).to eq('Crossings' => 7, 'Shard' => 2)
      expect(rows[%w[core DR]]).to eq({})
    end

    # The database itself refuses one character's row (no stubbed adapter), so
    # these hold only if every write in the move raises and rolls it all back.
    it "keeps the old row and every character when one character's row can't be written" do
      seed_legacy({ 'CharA' => { 'Crossings' => 1 }, 'CharB' => { 'Shard' => 2 } })
      SettingsSpecDB.fail_writes_to(data_dir, 'DR:CharB')

      expect(described_module.all_accounts).to eq('CharA' => { 'Crossings' => 1 }, 'CharB' => { 'Shard' => 2 })
      expect(rows).to eq(%w[core DR] => { 'banking' => { 'CharA' => { 'Crossings' => 1 }, 'CharB' => { 'Shard' => 2 } } })
      expect(message_strings.last).to include('could not move old bank data', 'simulated write failure')
    end

    it "keeps the old row untouched when a write's move fails" do
      XMLData.name = 'CharA'
      seed_legacy({ 'CharA' => { 'Crossings' => 1 }, 'CharB' => { 'Shard' => 2 } })
      SettingsSpecDB.fail_writes_to(data_dir, 'DR:CharB')

      described_module.update_balance('Crossings', 7)
      expect(rows).to eq(%w[core DR] => { 'banking' => { 'CharA' => { 'Crossings' => 1 }, 'CharB' => { 'Shard' => 2 } } })
      expect(message_strings.last).to include('could not save the Crossings balance', 'simulated write failure')
      expect(message_strings.grep(/Updated Crossings/)).to be_empty
    end

    it "keeps the old row untouched when the character's own write fails" do
      XMLData.name = 'CharA'
      seed_legacy({ 'CharA' => { 'Crossings' => 1 } })
      SettingsSpecDB.fail_writes_to(data_dir, 'DR:CharA')

      described_module.update_balance('Crossings', 7)
      expect(rows).to eq(%w[core DR] => { 'banking' => { 'CharA' => { 'Crossings' => 1 } } })
      expect(message_strings.last).to include('could not save the Crossings balance', 'simulated write failure')
    end

    it "keeps an existing row it can't load instead of filling it from the old entry" do
      SettingsSpecDB.write_raw(data_dir, 'core.banking', 'DR:CharA', 'garbage')
      seed_legacy({ 'CharA' => { 'Crossings' => 1 }, 'CharB' => { 'Shard' => 2 } })

      expect(described_module.all_accounts).to eq('CharB' => { 'Shard' => 2 })
      expect(rows[['core.banking', 'DR:CharA']]).to eq(:unreadable)
      expect(rows[%w[core DR]]).to eq({})
    end
  end

  describe 'reading a row' do
    it 'treats a row whose load raises an unusual error as empty, and logs it' do
      seed_regexp_error_row('core.banking', 'DR:CharA')
      logged = []
      allow(Lich).to receive(:log) { |line| logged << line }

      XMLData.name = 'CharA'
      described_module.update_balance('Crossings', 7)

      expect(described_module.my_accounts).to eq('Crossings' => 7)
      expect(logged.join).to include('unreadable settings row core.banking/DR:CharA', 'RegexpError')
      expect(message_strings.grep(/could not/)).to be_empty
    end

    it 'does not overwrite a row when reading it hits a database error' do
      XMLData.name = 'CharA'
      seed_row('CharA', { 'Crossings' => 1, 'Shard' => 2 })
      allow(adapter).to receive(:get_settings).and_call_original
      allow(adapter).to receive(:get_settings).with('core.banking', 'DR:CharA')
                                              .and_raise(Sequel::DatabaseError, 'disk I/O error')

      described_module.update_balance('Crossings', 7)

      expect(rows[['core.banking', 'DR:CharA']]).to eq('Crossings' => 1, 'Shard' => 2)
      expect(message_strings.last).to include('could not save the Crossings balance', 'disk I/O error')
    end
  end

  # Logging writes to $stderr, which lets other threads run. Inside a write
  # transaction that would let a write through a connection on SQLite's C
  # busy timeout (GVL held) stall the whole process, so row problems are
  # logged once the transaction has ended.
  describe 'logging a row problem' do
    # Records each logged line, and whether the settings write lock was held
    # when it was logged (another connection can't take it without waiting).
    def record_logs
      calls = []
      @lock_held_while_logging = []
      allow(Lich).to receive(:log) do |line|
        calls << line
        @lock_held_while_logging << write_lock_held?
      end
      calls
    end

    def write_lock_held?
      probe = SQLite3::Database.new(SettingsSpecDB.path(data_dir))
      probe.busy_timeout(0)
      probe.execute('BEGIN IMMEDIATE')
      probe.execute('ROLLBACK')
      false
    rescue SQLite3::BusyException
      true
    ensure
      probe&.close
    end

    def seed_unreadable_legacy
      SettingsSpecDB.write_raw(data_dir, 'core', 'DR', 'garbage')
    end

    before { XMLData.name = 'CharA' }

    {
      'a balance update'    => ->(m) { m.update_balance('Crossings', 7) },
      'a deposit'           => ->(m) { m.parse('The clerk slides a small metal box across the counter into which you drop 5 gold Kronars') },
      'a character reset'   => ->(m) { m.reset_character! },
      'a reset of all rows' => ->(m) { m.reset_all! },
      'a read of every row' => ->(m) { m.all_accounts },
      'a read of own row'   => ->(m) { m.my_accounts }
    }.each do |what, operation|
      it "logs an unreadable old shared row and still completes #{what}" do
        XMLData.room_title = '[[Provincial Bank, Teller]]'
        seed_row('CharA', { 'Crossings' => 1 })
        seed_unreadable_legacy
        calls = record_logs

        operation.call(described_module)

        expect(calls.grep(%r{unreadable settings row core/DR})).not_to be_empty
        expect(@lock_held_while_logging).to all(be(false))
        expect(message_strings.grep(/could not/)).to be_empty
      end
    end

    it "logs the character's own unreadable row, then overwrites it" do
      SettingsSpecDB.write_raw(data_dir, 'core.banking', 'DR:CharA', 'garbage')
      calls = record_logs

      described_module.update_balance('Crossings', 7)

      expect(calls.join).to include('unreadable settings row core.banking/DR:CharA')
      expect(@lock_held_while_logging).to all(be(false))
      expect(rows[['core.banking', 'DR:CharA']]).to eq('Crossings' => 7)
    end

    it 'logs a row that holds something other than a Hash' do
      SettingsSpecDB.write_raw(data_dir, 'core.banking', 'DR:CharA', Marshal.dump([1, 2]))
      calls = record_logs

      described_module.update_balance('Crossings', 7)

      expect(calls.join).to include('core.banking/DR:CharA holding a Array')
      expect(@lock_held_while_logging).to all(be(false))
    end

    it "logs the character's own unreadable row after a deposit's transaction" do
      XMLData.room_title = '[[Provincial Bank, Teller]]'
      SettingsSpecDB.write_raw(data_dir, 'core.banking', 'DR:CharA', 'garbage')
      calls = record_logs

      described_module.parse('The clerk slides a small metal box across the counter into which you drop 5 gold Kronars')

      expect(calls.join).to include('unreadable settings row core.banking/DR:CharA')
      expect(@lock_held_while_logging).to all(be(false))
    end

    it 'logs the line once when the transaction then fails' do
      SettingsSpecDB.write_raw(data_dir, 'core.banking', 'DR:CharA', 'garbage')
      SettingsSpecDB.fail_writes_to(data_dir, 'DR:CharA')
      calls = record_logs

      described_module.update_balance('Crossings', 7)

      expect(calls.count { |c| c.include?('unreadable settings row core.banking/DR:CharA') }).to eq(1)
      expect(@lock_held_while_logging).to all(be(false))
      expect(message_strings.last).to include('could not save the Crossings balance', 'simulated write failure')
    end
  end

  # While DRBanking holds the write lock, other threads of the same process
  # keep running (Ruby preempts threads, and IO lets them run). A settings
  # write from one of them has to wait for the lock without stopping the lock
  # holder, or both stall until the busy timeout and that write fails.
  describe "another thread's settings write while the write lock is held" do
    let(:other) { Lich::Common::DatabaseAdapter.new(data_dir, :script_auto_settings) }

    before { XMLData.name = 'CharA' }
    after { other.instance_variable_get(:@db)&.disconnect }

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    # Runs operation in a thread; once it signals that it holds the lock,
    # saves another script's settings from this thread.
    # @return [Array(Boolean, Float)] what save_settings returned, seconds taken
    def save_while_locked(locked, &operation)
      writer = Thread.new(&operation)
      locked.pop
      started = monotonic
      saved = other.save_settings('otherscript', { 'n' => 1 }, 'DR:CharA')
      elapsed = monotonic - started
      writer.join
      [saved, elapsed]
    end

    it 'goes through promptly while DRBanking runs Ruby code inside its transaction' do
      seed_row('CharA', { 'Crossings' => 1 })
      locked = Queue.new
      allow(adapter).to receive(:save_settings!).and_wrap_original do |original, *args|
        locked << true
        # Plain Ruby work, no IO: the thread can only be preempted.
        spin_until = monotonic + 0.3
        nil while monotonic < spin_until
        original.call(*args)
      end

      saved, elapsed = save_while_locked(locked) { described_module.update_balance('Crossings', 7) }

      expect(saved).to be(true)
      expect(elapsed).to be < 2
      expect(rows[['core.banking', 'DR:CharA']]).to eq('Crossings' => 7)
      expect(rows[['otherscript', 'DR:CharA']]).to eq('n' => 1)
      expect(message_strings.grep(/could not/)).to be_empty
    end

    # A connection on SQLite's C busy timeout (what Lich.db falls back to
    # when sqlite3 has no busy_handler API) waits with the GVL held, so
    # nothing DRBanking does while it holds the lock may let such a write
    # start: logging is held back until after the commit.
    it 'lets a write through a raw SQLite handle go through when a row problem is logged' do
      seed_row('CharA', { 'Crossings' => 1 })
      SettingsSpecDB.write_raw(data_dir, 'core', 'DR', 'garbage')
      raw = Lich.open_sqlite_db(SettingsSpecDB.path(data_dir))
      raw.busy_timeout(1000) # replaces the Ruby busy handler with a 1s C busy timeout
      logging = Queue.new
      # Like $stderr.puts, the log call lets other threads run for a moment.
      allow(Lich).to receive(:log) do
        logging << true
        sleep 0.3
      end

      banking = Thread.new { described_module.update_balance('Crossings', 7) }
      logging.pop
      started = monotonic
      error = nil
      begin
        raw.execute("INSERT INTO script_auto_settings (script, scope, hash) VALUES ('rawscript', 'DR:CharA', x'00')")
      rescue SQLite3::BusyException => e
        error = e
      end
      elapsed = monotonic - started
      banking.join
      raw.close

      expect(error).to be_nil
      expect(elapsed).to be < 0.5
      expect(rows[['core.banking', 'DR:CharA']]).to eq('Crossings' => 7)
    end

    # The connection Lich.db opens (Lich.open_sqlite_db) waits for the lock in
    # Ruby, so a write through it that starts inside DRBanking's transaction
    # waits for the commit instead of stalling the lock holder.
    it 'lets a write through a Lich.db-style handle start inside the transaction and go through on commit' do
      seed_row('CharA', { 'Crossings' => 1 })
      shared = Lich.open_sqlite_db(SettingsSpecDB.path(data_dir))
      locked = Queue.new
      allow(adapter).to receive(:save_settings!).and_wrap_original do |original, *args|
        locked << true
        # Plain Ruby work, no IO: the thread can only be preempted.
        spin_until = monotonic + 0.3
        nil while monotonic < spin_until
        original.call(*args)
      end

      banking = Thread.new { described_module.update_balance('Crossings', 7) }
      locked.pop
      started = monotonic
      error = nil
      begin
        shared.execute("INSERT INTO script_auto_settings (script, scope, hash) VALUES ('rawscript', 'DR:CharA', x'00')")
      rescue SQLite3::BusyException => e
        error = e
      end
      elapsed = monotonic - started
      banking.join
      shared.close

      expect(error).to be_nil
      expect(elapsed).to be < 2
      expect(rows[['core.banking', 'DR:CharA']]).to eq('Crossings' => 7)
      expect(message_strings.grep(/could not/)).to be_empty
    end

    it 'waits for the migration transaction, then both are kept' do
      seed_legacy({ 'CharA' => { 'Crossings' => 1 }, 'CharB' => { 'Shard' => 2 } })
      locked = Queue.new
      allow(adapter).to receive(:scopes_by_prefix).and_wrap_original do |original, *args|
        locked << true
        spin_until = monotonic + 0.3
        nil while monotonic < spin_until
        original.call(*args)
      end

      saved, elapsed = save_while_locked(locked) { described_module.all_accounts }

      expect(saved).to be(true)
      expect(elapsed).to be < 2
      expect(rows[['core.banking', 'DR:CharB']]).to eq('Shard' => 2)
      expect(rows[%w[core DR]]).to eq({})
      expect(rows[['otherscript', 'DR:CharA']]).to eq('n' => 1)
    end
  end

  describe '.my_accounts' do
    it 'returns empty hash for new character' do
      expect(described_module.my_accounts).to eq({})
    end

    it 'returns current characters accounts' do
      XMLData.name = 'CharA'
      seed_row('CharA', { 'Crossings' => 10_000, 'Shard' => 5_000 })
      seed_row('OtherChar', { 'Riverhaven' => 20_000 })
      expect(described_module.my_accounts).to eq('Crossings' => 10_000, 'Shard' => 5_000)
    end

    it "does not match another character whose name starts with this one's" do
      XMLData.name = 'Char'
      seed_row('CharA', { 'Crossings' => 1 })
      expect(described_module.my_accounts).to eq({})
    end

    it 'returns {} before the character name is known' do
      XMLData.name = nil
      seed_row('', { 'Crossings' => 1 })
      expect(described_module.my_accounts).to eq({})
    end

    it "reads only this character's row, not every character's" do
      XMLData.name = 'CharA'
      seed_row('CharA', { 'Crossings' => 10 })
      seed_row('CharB', { 'Shard' => 2 })
      allow(adapter).to receive(:get_settings_by_scope_prefix).and_call_original

      expect(described_module.my_accounts).to eq('Crossings' => 10)
      expect(described_module.total_wealth).to eq(10)
      described_module.display_banks

      expect(adapter).not_to have_received(:get_settings_by_scope_prefix)
    end

    it 'returns {} when the game is not known yet' do
      XMLData.name = 'CharA'
      seed_row('CharA', { 'Crossings' => 1 })
      allow(XMLData).to receive(:game).and_return(nil)
      expect(described_module.my_accounts).to eq({})
    end

    it 'moves the old shared row before reading' do
      XMLData.name = 'CharA'
      seed_legacy({ 'CharA' => { 'Crossings' => 1 }, 'CharB' => { 'Shard' => 2 } })

      expect(described_module.my_accounts).to eq('Crossings' => 1)
      expect(rows[['core.banking', 'DR:CharB']]).to eq('Shard' => 2)
      expect(rows[%w[core DR]]).to eq({})
    end

    it 'reports a database error and returns {}' do
      XMLData.name = 'CharA'
      allow(adapter).to receive(:get_settings).and_raise(Sequel::DatabaseError, 'database is locked')
      expect(described_module.my_accounts).to eq({})
      expect(message_strings.last).to include('could not read bank data', 'database is locked')
    end

    # my_accounts reads one row, all_accounts reads them all; they must agree.
    describe 'agreeing with all_accounts' do
      own_rows = {
        'no row'                 => nil,
        'a row'                  => ->(spec) { spec.seed_row('CharA', { 'Crossings' => 3 }) },
        'a cleared row'          => ->(spec) { spec.seed_row('CharA', {}) },
        'an unreadable row'      => ->(spec) { SettingsSpecDB.write_raw(spec.data_dir, 'core.banking', 'DR:CharA', 'garbage') },
        'a row holding an Array' => ->(spec) { SettingsSpecDB.write_raw(spec.data_dir, 'core.banking', 'DR:CharA', Marshal.dump([1])) }
      }
      legacies = {
        'no old row'                      => nil,
        'an old entry for this character' => { 'CharA' => { 'Shard' => 9 }, 'CharB' => { 'Ratha' => 4 } },
        'an old entry for another only'   => { 'CharB' => { 'Ratha' => 4 } }
      }

      own_rows.each do |own_desc, seed_own|
        legacies.each do |legacy_desc, legacy|
          [false, true].each do |move_fails|
            next if move_fails && legacy.nil?

            it "with #{own_desc}, #{legacy_desc}#{move_fails ? ', and a failing move' : ''}" do
              XMLData.name = 'CharA'
              seed_own&.call(self)
              seed_row('CharB', { 'Shard' => 1 }) unless legacy
              seed_legacy(legacy) if legacy
              allow(Lich).to receive(:log)
              if move_fails
                allow(adapter).to receive(:transaction).and_raise(Sequel::DatabaseError, 'database is locked')
              end

              mine = described_module.my_accounts
              everyone = described_module.all_accounts

              expect(mine).to eq(everyone['CharA'] || {})
            end
          end
        end
      end
    end
  end

  describe '.update_balance' do
    it 'updates balance for current character' do
      XMLData.name = 'TestChar'
      described_module.update_balance('Crossings', 15_000)
      expect(described_module.my_accounts['Crossings']).to eq(15_000)
    end

    it 'converts string amounts to integer' do
      described_module.update_balance('Crossings', '20000')
      expect(described_module.my_accounts['Crossings']).to eq(20_000)
    end

    it 'overwrites existing balance' do
      described_module.update_balance('Crossings', 10_000)
      described_module.update_balance('Crossings', 25_000)
      expect(described_module.my_accounts['Crossings']).to eq(25_000)
    end

    it 'logs a message confirming the balance update for the town' do
      described_module.update_balance('Crossings', 10_000)
      expect(message_strings.last).to include('Updated Crossings balance')
    end

    it "persists to this character's own row only" do
      XMLData.name = 'CharA'
      described_module.update_balance('Crossings', 10_000)
      expect(rows).to eq(['core.banking', 'DR:CharA'] => { 'Crossings' => 10_000 })
    end

    it "keeps the row's other towns" do
      XMLData.name = 'CharA'
      seed_row('CharA', { 'Shard' => 5 })
      described_module.update_balance('Crossings', 10_000)
      expect(rows[['core.banking', 'DR:CharA']]).to eq('Shard' => 5, 'Crossings' => 10_000)
    end

    it 'writes nothing and says so before the character name is known' do
      XMLData.name = ''
      described_module.update_balance('Crossings', 10_000)
      expect(rows).to eq({})
      expect(message_strings.last).to include("Can't save the Crossings balance before the character is known")
    end

    it "starts again from an empty row when this character's row can't be loaded" do
      XMLData.name = 'CharA'
      SettingsSpecDB.write_raw(data_dir, 'core.banking', 'DR:CharA', 'garbage')
      logged = []
      allow(Lich).to receive(:log) { |msg| logged << msg }

      described_module.update_balance('Crossings', 7)
      expect(rows[['core.banking', 'DR:CharA']]).to eq('Crossings' => 7)
      expect(message_strings.last).to include('Updated Crossings balance')
      expect(logged.join).to include('unreadable settings row core.banking/DR:CharA')
    end

    it "starts again from an empty row when this character's row holds no Hash" do
      XMLData.name = 'CharA'
      SettingsSpecDB.write(data_dir, 'core.banking', 'DR:CharA', [1, 2])

      described_module.update_balance('Crossings', 7)
      expect(rows[['core.banking', 'DR:CharA']]).to eq('Crossings' => 7)
    end

    it 'claims no update and keeps the row when the database refuses the write' do
      XMLData.name = 'CharA'
      seed_row('CharA', { 'Crossings' => 1 })
      SettingsSpecDB.fail_writes_to(data_dir, 'DR:CharA')

      described_module.update_balance('Crossings', 10_000)
      expect(rows).to eq(['core.banking', 'DR:CharA'] => { 'Crossings' => 1 })
      expect(message_strings.last).to include('could not save the Crossings balance', 'simulated write failure')
      expect(message_strings.grep(/Updated Crossings/)).to be_empty
    end

    it 'reports a database error instead of raising, and claims no update' do
      allow(adapter).to receive(:transaction).and_raise(Sequel::DatabaseError, 'database is locked')
      expect { described_module.update_balance('Crossings', 10_000) }.not_to raise_error
      expect(message_strings.last).to include('could not save the Crossings balance')
      expect(message_strings.grep(/Updated Crossings/)).to be_empty
    end
  end

  describe '.clear_balance' do
    it 'sets balance to zero' do
      described_module.update_balance('Crossings', 10_000)
      described_module.clear_balance('Crossings')
      expect(described_module.my_accounts['Crossings']).to eq(0)
    end
  end

  describe '.total_wealth' do
    it 'returns 0 when no accounts' do
      expect(described_module.total_wealth).to eq(0)
    end

    it 'sums all bank balances for current character' do
      XMLData.name = 'TestChar'
      described_module.update_balance('Crossings', 10_000)
      described_module.update_balance('Shard', 5_000)
      described_module.update_balance('Riverhaven', 3_000)
      expect(described_module.total_wealth).to eq(18_000)
    end
  end

  describe '.total_wealth_all' do
    it 'returns 0 when no accounts' do
      expect(described_module.total_wealth_all).to eq(0)
    end

    it 'sums all bank balances across all characters' do
      XMLData.name = 'CharA'
      described_module.update_balance('Crossings', 10_000)
      XMLData.name = 'CharB'
      described_module.update_balance('Shard', 5_000)
      described_module.update_balance('Riverhaven', 3_000)
      expect(described_module.total_wealth_all).to eq(18_000)
    end
  end

  describe '.to_copper' do
    it 'converts platinum correctly' do
      expect(described_module.to_copper(5, 'platinum')).to eq(50_000)
    end

    it 'converts gold correctly' do
      expect(described_module.to_copper(10, 'gold')).to eq(10_000)
    end

    it 'converts silver correctly' do
      expect(described_module.to_copper(100, 'silver')).to eq(10_000)
    end

    it 'converts bronze correctly' do
      expect(described_module.to_copper(50, 'bronze')).to eq(500)
    end

    it 'converts copper correctly' do
      expect(described_module.to_copper(1000, 'copper')).to eq(1_000)
    end

    it 'handles string amounts' do
      expect(described_module.to_copper('5', 'platinum')).to eq(50_000)
    end

    it 'handles mixed case denomination' do
      expect(described_module.to_copper(5, 'PLATINUM')).to eq(50_000)
    end

    it 'defaults to 1 for unknown denomination' do
      expect(described_module.to_copper(100, 'unknown')).to eq(100)
    end
  end

  describe '.parse_balance_string' do
    it 'returns 0 when given nil input instead of raising an error' do
      expect(described_module.parse_balance_string(nil)).to eq(0)
    end

    it 'returns 0 for empty string' do
      expect(described_module.parse_balance_string('')).to eq(0)
    end

    it 'parses single denomination' do
      expect(described_module.parse_balance_string('5 platinum')).to eq(50_000)
    end

    it 'parses multiple denominations' do
      expect(described_module.parse_balance_string('5 platinum, 3 gold, 2 silver')).to eq(53_200)
    end

    it 'handles extra whitespace' do
      expect(described_module.parse_balance_string('5  platinum,  3  gold')).to eq(53_000)
    end
  end

  describe '.format_currency' do
    it 'returns "none" for 0' do
      expect(described_module.format_currency(0)).to eq('none')
    end

    it 'returns "none" for negative amounts' do
      expect(described_module.format_currency(-100)).to eq('none')
    end

    it 'formats single denomination' do
      expect(described_module.format_currency(50_000)).to eq('5 platinum')
    end

    it 'formats multiple denominations' do
      expect(described_module.format_currency(53_210)).to eq('5 platinum, 3 gold, 2 silver, 1 bronze')
    end

    it 'handles string input' do
      expect(described_module.format_currency('50000')).to eq('5 platinum')
    end

    it 'omits zero-value denominations' do
      # 10,001 copper = 1 platinum (10,000) + 1 copper
      expect(described_module.format_currency(10_001)).to eq('1 platinum, 1 copper')
    end
  end

  describe '.current_bank_town' do
    it 'returns nil when not in a bank' do
      XMLData.room_title = '[Some Random Room]'
      expect(described_module.current_bank_town).to be_nil
    end

    it 'returns nil when room_title is nil' do
      XMLData.room_title = nil
      expect(described_module.current_bank_town).to be_nil
    end

    it 'returns nil when room_title is empty' do
      XMLData.room_title = ''
      expect(described_module.current_bank_town).to be_nil
    end

    it 'returns town when in Crossings bank' do
      XMLData.room_title = '[[Provincial Bank, Teller]]'
      expect(described_module.current_bank_town).to eq('Crossings')
    end

    it 'returns town when in Shard bank' do
      XMLData.room_title = "[[First Bank of Ilithi, Teller's Windows]]"
      expect(described_module.current_bank_town).to eq('Shard')
    end

    it 'returns town when in Riverhaven bank' do
      XMLData.room_title = '[[Bank of Riverhaven, Teller]]'
      expect(described_module.current_bank_town).to eq('Riverhaven')
    end
  end

  describe '.parse' do
    context 'when not in a bank' do
      before { XMLData.room_title = '[Some Random Room]' }

      it 'does nothing for bank messages' do
        expect {
          described_module.parse('The clerk counts out 5 gold Kronars and hands them over, making a notation in her ledger')
        }.not_to(change { described_module.my_accounts })
      end
    end

    context 'when in a bank' do
      before { XMLData.room_title = '[[Provincial Bank, Teller]]' } # Crossings bank

      it 'does not raise an error when parse receives nil input while in a bank' do
        expect { described_module.parse(nil) }.not_to raise_error
      end

      it 'handles non-string input' do
        expect { described_module.parse(123) }.not_to raise_error
      end

      describe 'deposit portion' do
        it 'adds deposit to current balance' do
          described_module.update_balance('Crossings', 10_000)
          described_module.parse('The clerk slides a small metal box across the counter into which you drop 5 gold Kronars')
          expect(described_module.my_accounts['Crossings']).to eq(15_000)
        end

        it 'does not update balance when no prior balance exists' do
          described_module.parse('The clerk slides a small metal box across the counter into which you drop 5 platinum Kronars')
          expect(described_module.my_accounts['Crossings']).to be_nil
        end

        it 'logs message to check BALANCE when no prior balance exists' do
          described_module.parse('The clerk slides a small metal box across the counter into which you drop 5 platinum Kronars')
          expect(message_strings.last).to include('No prior balance recorded')
          expect(message_strings.last).to include('check BALANCE')
        end

        it "treats a row it can't load as no prior balance and leaves it for BALANCE or reset" do
          SettingsSpecDB.write_raw(data_dir, 'core.banking', "DR:#{XMLData.name}", 'garbage')
          described_module.parse('The clerk slides a small metal box across the counter into which you drop 5 platinum Kronars')
          expect(message_strings.last).to include('No prior balance recorded')
          expect(message_strings.grep(/could not/)).to be_empty
          expect(rows[['core.banking', "DR:#{XMLData.name}"]]).to eq(:unreadable)
        end
      end

      describe 'deposit all' do
        it 'logs deposit all for teller bank' do
          described_module.parse('The clerk slides a small metal box across the counter into which you drop all your Kronars.  She counts them carefully and records the deposit in her ledger')
          expect(message_strings.last).to include('Deposited all money')
        end

        it 'logs deposit all for jar bank' do
          described_module.parse('You cross through the old balance on the label and update it to reflect your new balance')
          expect(message_strings.last).to include('Deposited all money')
        end
      end

      describe 'withdraw portion' do
        it 'subtracts withdrawal from balance' do
          described_module.update_balance('Crossings', 10_000)
          described_module.parse('The clerk counts out 5 gold Kronars and hands them over, making a notation in her ledger')
          expect(described_module.my_accounts['Crossings']).to eq(5_000)
        end

        it 'does not go below zero' do
          described_module.update_balance('Crossings', 1_000)
          described_module.parse('The clerk counts out 5 gold Kronars and hands them over, making a notation in her ledger')
          expect(described_module.my_accounts['Crossings']).to eq(0)
        end

        it 'does not update balance when no prior balance exists' do
          described_module.parse('The clerk counts out 5 gold Kronars and hands them over, making a notation in her ledger')
          expect(described_module.my_accounts['Crossings']).to be_nil
        end

        it 'logs message to check BALANCE when no prior balance exists' do
          described_module.parse('The clerk counts out 5 gold Kronars and hands them over, making a notation in her ledger')
          expect(message_strings.last).to include('No prior balance recorded')
          expect(message_strings.last).to include('check BALANCE')
        end
      end

      describe 'withdraw all' do
        it 'sets balance to zero' do
          described_module.update_balance('Crossings', 10_000)
          described_module.parse('The clerk counts out all your Kronars and hands them over')
          expect(described_module.my_accounts['Crossings']).to eq(0)
        end

        it 'logs the withdrawal' do
          described_module.update_balance('Crossings', 10_000)
          described_module.parse('The clerk counts out all your Kronars and hands them over')
          expect(message_strings.last).to include('Withdrew all money')
        end
      end

      describe 'balance check' do
        it 'updates balance from "it looks like" message' do
          described_module.parse('it looks like your current balance is 5 platinum, 3 gold Kronars')
          expect(described_module.my_accounts['Crossings']).to eq(53_000)
        end

        it 'updates balance from "As expected" message' do
          described_module.parse('As expected, there are 100 copper Kronars')
          expect(described_module.my_accounts['Crossings']).to eq(100)
        end
      end

      describe 'no account' do
        it 'clears balance for teller bank message' do
          described_module.update_balance('Crossings', 10_000)
          described_module.parse('you do not seem to have an account with us')
          expect(described_module.my_accounts['Crossings']).to eq(0)
        end

        it 'clears balance for jar bank message' do
          described_module.update_balance('Crossings', 10_000)
          described_module.parse('you should find a new deposit jar for your financial needs')
          expect(described_module.my_accounts['Crossings']).to eq(0)
        end

        it 'logs no account message' do
          described_module.parse('you do not seem to have an account with us')
          expect(message_strings.last).to include('No account')
        end
      end
    end
  end

  describe '.display_banks' do
    it 'displays message when no accounts' do
      described_module.display_banks
      expect(message_strings.last).to include('No bank account info recorded')
    end

    it 'displays account balances' do
      described_module.update_balance('Crossings', 10_000)
      described_module.update_balance('Riverhaven', 5_000)
      described_module.display_banks
      # Should display header and balances
      expect(message_strings.any? { |m| m.include?('Your bank balances') }).to be true
    end

    it 'reports a failed read once, without also saying nothing is recorded' do
      XMLData.name = 'CharA'
      seed_row('CharA', { 'Crossings' => 10 })
      allow(adapter).to receive(:get_settings).and_call_original
      allow(adapter).to receive(:get_settings).with('core.banking', 'DR:CharA')
                                              .and_raise(Sequel::DatabaseError, 'database is locked')

      described_module.display_banks

      expect(message_strings).to eq(['DRBanking: could not read bank data: Sequel::DatabaseError: database is locked'])
    end

    it 'computes the grand total from the same read as the balances' do
      XMLData.name = 'CharA'
      seed_row('CharA', { 'Crossings' => 10_000, 'Riverhaven' => 5_000 })
      calls = 0
      allow(adapter).to receive(:get_settings).and_wrap_original do |original, *args|
        if args == ['core.banking', 'DR:CharA']
          calls += 1
          raise Sequel::DatabaseError, 'database is locked' if calls > 1
        end

        original.call(*args)
      end

      described_module.display_banks

      expect(calls).to eq(1)
      expect(message_strings.last).to include('Grand Total:', '1 platinum, 5 gold')
      expect(message_strings.grep(/could not/)).to be_empty
    end
  end

  describe '.display_banks_all' do
    it 'displays message when no accounts' do
      described_module.display_banks_all
      expect(message_strings.last).to include('No bank account info recorded for any character')
    end

    it 'displays all character balances' do
      XMLData.name = 'CharA'
      described_module.update_balance('Crossings', 10_000)
      XMLData.name = 'CharB'
      described_module.update_balance('Shard', 5_000)
      described_module.display_banks_all
      expect(message_strings.any? { |m| m.include?('Bank balances for all characters') }).to be true
    end

    it 'reports a failed read once, without also saying nothing is recorded' do
      seed_row('CharA', { 'Crossings' => 10 })
      allow(adapter).to receive(:get_settings_by_scope_prefix).and_raise(Sequel::DatabaseError, 'database is locked')

      described_module.display_banks_all

      expect(message_strings).to eq(['DRBanking: could not read bank data: Sequel::DatabaseError: database is locked'])
    end
  end

  describe '.reload!' do
    it 'returns a fresh read of every account' do
      XMLData.name = 'CharA'
      described_module.update_balance('Crossings', 10_000)
      seed_row('CharB', { 'Shard' => 3 })
      expect(described_module.reload!).to eq('CharA' => { 'Crossings' => 10_000 }, 'CharB' => { 'Shard' => 3 })
    end
  end

  describe '.reset_character!' do
    it 'clears current characters data' do
      XMLData.name = 'TestChar'
      described_module.update_balance('Crossings', 10_000)
      described_module.reset_character!
      expect(described_module.my_accounts).to eq({})
    end

    it 'preserves other characters data' do
      current_char = XMLData.name
      seed_legacy({ 'OtherChar' => { 'Crossings' => 10_000 }, current_char => { 'Shard' => 5_000 } })
      expect(described_module.all_accounts.keys).to include('OtherChar', current_char)

      described_module.reset_character!

      expect(described_module.all_accounts).to eq('OtherChar' => { 'Crossings' => 10_000 })
    end

    it 'keeps an empty row, so old data for this character cannot come back' do
      current_char = XMLData.name
      described_module.update_balance('Crossings', 1)
      described_module.reset_character!
      seed_legacy({ current_char => { 'Crossings' => 1 } })

      expect(described_module.my_accounts).to eq({})
      expect(rows[['core.banking', "DR:#{current_char}"]]).to eq({})
    end

    it "clears a row that can't be loaded, so later writes work again" do
      XMLData.name = 'CharA'
      SettingsSpecDB.write_raw(data_dir, 'core.banking', 'DR:CharA', 'garbage')

      described_module.reset_character!
      expect(rows[['core.banking', 'DR:CharA']]).to eq({})
      expect(message_strings.last).to include('Cleared bank data for CharA')

      described_module.update_balance('Crossings', 7)
      expect(described_module.my_accounts).to eq('Crossings' => 7)
    end

    it 'clears a row whose load raises an unusual error, without reading it' do
      XMLData.name = 'CharA'
      seed_regexp_error_row('core.banking', 'DR:CharA')
      seed_row('CharB', { 'Shard' => 2 })
      allow(adapter).to receive(:get_settings).and_call_original

      described_module.reset_character!

      expect(adapter).not_to have_received(:get_settings).with('core.banking', 'DR:CharA')
      expect(rows[['core.banking', 'DR:CharA']]).to eq({})
      expect(rows[['core.banking', 'DR:CharB']]).to eq('Shard' => 2)
      expect(message_strings.last).to include('Cleared bank data for CharA')
    end

    it 'does not claim success when the database refuses the write' do
      XMLData.name = 'CharA'
      SettingsSpecDB.fail_writes_to(data_dir, 'DR:CharA')
      described_module.reset_character!
      expect(message_strings.grep(/Cleared bank data/)).to be_empty
      expect(message_strings.last).to include('could not clear your bank data', 'simulated write failure')
    end

    it 'does not claim success when the write fails' do
      allow(adapter).to receive(:transaction).and_raise(Sequel::DatabaseError, 'database is locked')
      described_module.reset_character!
      expect(message_strings.grep(/Cleared bank data/)).to be_empty
      expect(message_strings.last).to include('could not clear your bank data')
    end

    it 'logs a message confirming the character bank data was cleared' do
      described_module.reset_character!
      expect(message_strings.last).to include('Cleared bank data')
    end
  end

  describe '.reset_all!' do
    it 'clears all character data' do
      XMLData.name = 'CharA'
      described_module.update_balance('Crossings', 10_000)
      XMLData.name = 'CharB'
      described_module.update_balance('Shard', 5_000)
      described_module.reset_all!
      expect(described_module.all_accounts).to eq({})
    end

    it 'logs a message confirming all character bank data was cleared' do
      described_module.reset_all!
      expect(message_strings.last).to include('Cleared all bank data')
    end

    it 'clears rows and old data of this game instance only' do
      seed_row('CharA', { 'Crossings' => 1 })
      seed_row('CharF', { 'Crossings' => 2 }, game: 'DRF')
      seed_legacy({ 'CharB' => { 'Shard' => 3 } })
      described_module.reset_all!

      expect(rows).to eq(
        %w[core DR]                   => {},
        ['core.banking', 'DR:CharA']  => {},
        ['core.banking', 'DR:CharB']  => {},
        ['core.banking', 'DRF:CharF'] => { 'Crossings' => 2 }
      )
    end

    it "clears rows that can't be loaded, without reading them" do
      SettingsSpecDB.write_raw(data_dir, 'core.banking', 'DR:CharA', 'garbage')
      seed_row('CharB', { 'Shard' => 3 })
      described_module.reset_all!

      expect(rows).to eq(['core.banking', 'DR:CharA'] => {}, ['core.banking', 'DR:CharB'] => {})
      expect(message_strings.last).to include('Cleared all bank data')
    end

    it 'keeps every row and claims nothing when one row cannot be cleared' do
      seed_row('CharA', { 'Crossings' => 1 })
      seed_row('CharB', { 'Shard' => 3 })
      SettingsSpecDB.fail_writes_to(data_dir, 'DR:CharB')
      described_module.reset_all!

      expect(rows).to eq(['core.banking', 'DR:CharA'] => { 'Crossings' => 1 }, ['core.banking', 'DR:CharB'] => { 'Shard' => 3 })
      expect(message_strings.grep(/Cleared all/)).to be_empty
      expect(message_strings.last).to include('could not clear all bank data', 'simulated write failure')
    end

    it 'does not claim success when the write fails' do
      allow(adapter).to receive(:transaction).and_raise(Sequel::DatabaseError, 'database is locked')
      described_module.reset_all!
      expect(message_strings.grep(/Cleared all/)).to be_empty
      expect(message_strings.last).to include('could not clear all bank data')
    end

    it 'refuses before the game is known' do
      allow(XMLData).to receive(:game).and_return('')
      described_module.reset_all!
      expect(message_strings.last).to include("Can't clear bank data before the game is known")
    end

    it 'resets total_wealth_all to 0' do
      XMLData.name = 'CharA'
      described_module.update_balance('Crossings', 10_000)
      described_module.reset_all!
      expect(described_module.total_wealth_all).to eq(0)
    end
  end
end
