# frozen_string_literal: true

require_relative '../../spec_helper'
require 'sqlite3'
require 'digest'

# Load Vars once, killing its 5-minute autosave thread so it cannot fire mid-suite.
unless defined?(Lich::Common::Vars)
  threads = Thread.list
  require_relative '../../../lib/common/vars'
  (Thread.list - threads).each { |t| t.kill.join }
end

RSpec.describe Lich::Common::Vars do
  let(:db) { SQLite3::Database.new(':memory:') }
  let(:scope) { "#{XMLData.game}:#{XMLData.name}" }

  def stored
    blob = db.get_first_value('SELECT hash FROM uservars WHERE scope=?', [scope])
    blob && Marshal.load(blob)
  end

  before do
    db.execute('CREATE TABLE uservars(scope TEXT PRIMARY KEY, hash BLOB)')
    allow(Lich).to receive(:db).and_return(db)
    allow(Lich).to receive(:db_mutex).and_return(Mutex.new)
    described_class.class_variable_set(:@@vars, {})
    described_class.class_variable_set(:@@md5, nil)
    described_class.class_variable_set(:@@load_state, described_class::LoadState::LOADED)
  end

  after { db.close }

  describe '.save' do
    it 'keeps changes dirty after a failed write so the next save persists them' do
      described_class['key'] = 'new'
      calls = 0
      allow(db).to receive(:execute).and_wrap_original do |orig, *args|
        calls += 1
        raise SQLite3::FullException, 'database or disk is full' if calls == 1

        orig.call(*args)
      end

      expect { described_class.save }.to raise_error(SQLite3::FullException)
      expect(stored).to be_nil

      described_class.save
      expect(stored).to eq('key' => 'new')
    end

    it 'retries a busy database and writes once' do
      described_class['key'] = 'new'
      calls = 0
      allow(db).to receive(:execute).and_wrap_original do |orig, *args|
        calls += 1
        raise SQLite3::BusyException, 'database is locked' if calls == 1

        orig.call(*args)
      end

      described_class.save
      expect(stored).to eq('key' => 'new')
      expect(calls).to eq(2)

      described_class.save
      expect(calls).to eq(2)
    end
  end
end
