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

  # Restore Vars' class state so a later spec that loads vars.rb doesn't inherit it.
  around do |example|
    saved = %i[@@vars @@md5 @@load_state @@autosave_error].to_h { |v| [v, described_class.class_variable_get(v)] }
    example.run
  ensure
    saved.each { |v, val| described_class.class_variable_set(v, val) }
  end

  before do
    db.execute('CREATE TABLE uservars(scope TEXT PRIMARY KEY, hash BLOB)')
    allow(Lich).to receive(:db).and_return(db)
    allow(Lich).to receive(:db_mutex).and_return(Mutex.new)
    described_class.class_variable_set(:@@vars, {})
    described_class.class_variable_set(:@@md5, nil)
    described_class.class_variable_set(:@@load_state, described_class::LoadState::LOADED)
    described_class.class_variable_set(:@@autosave_error, nil)
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

    it 'raises on every save while a value cannot be marshaled, and persists once it is removed' do
      described_class['key'] = 'v'
      described_class['p'] = proc {}

      2.times { expect { described_class.save }.to raise_error(TypeError) }
      expect(stored).to be_nil

      described_class['p'] = nil
      described_class.save
      expect(stored).to eq('key' => 'v')
    end
  end

  describe '.save with a concurrent change' do
    it 'checksums the state it writes, so a later revert is still saved' do
      described_class['k'] = 'A'
      described_class.save
      described_class['k'] = 'B'
      # Another thread sets 'C' after save starts but before the state is serialized.
      changed = false
      allow(Marshal).to receive(:dump).and_wrap_original do |orig, obj|
        unless changed
          changed = true
          described_class['k'] = 'C'
        end
        orig.call(obj)
      end
      described_class.save
      expect(stored).to eq('k' => 'C')

      described_class['k'] = 'B'
      described_class.save
      expect(stored).to eq('k' => 'B')
    end
  end

  describe 'autosave' do
    let(:autosave) { described_class.class_variable_get(:@@autosave) }

    it 'retries a failing save every pass but shows the same error once' do
      allow(described_class).to receive(:respond)
      described_class['key'] = 'v'
      described_class['p'] = proc {}

      3.times { autosave.call }
      expect(described_class).to have_received(:respond).once

      described_class['p'] = nil
      autosave.call
      expect(stored).to eq('key' => 'v')

      # after a successful save, a new failure is shown again
      described_class['p'] = proc {}
      autosave.call
      expect(described_class).to have_received(:respond).twice
    end
  end
end
