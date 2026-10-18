# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'sqlite3'
require 'sequel'
require 'rbconfig'

require_relative '../../../support/lich_sqlite'
require_relative '../../../support/settings_db'

require_relative '../../../../lib/common/settings/database_adapter'

RSpec.describe Lich::Common::DatabaseAdapter do
  let(:tmp_dir) { Dir.mktmpdir('settings-db-adapter-spec') }

  after do
    db = @adapter&.instance_variable_get(:@db)
    db&.disconnect
    FileUtils.remove_entry(tmp_dir) if Dir.exist?(tmp_dir)
  end

  it 'opens settings storage with the core sqlite lock-wait handling' do
    @adapter = described_class.new(tmp_dir, :script_auto_settings)
    db = @adapter.instance_variable_get(:@db)

    expect(db.synchronize { |conn| conn }).to be_a(Lich::SQLiteBusyWait::Connection)
  end

  context 'with the production table' do
    before do
      SettingsSpecDB.prepare(tmp_dir)
      @adapter = described_class.new(tmp_dir, :script_auto_settings)
    end

    describe '#get_settings_by_scope_prefix' do
      it 'returns every row of the script whose scope starts with the prefix' do
        SettingsSpecDB.write(tmp_dir, 'core.banking', 'DR:Alpha', { 'a' => 1 })
        SettingsSpecDB.write(tmp_dir, 'core.banking', 'DR:Beta', { 'b' => 2 })
        SettingsSpecDB.write(tmp_dir, 'core.banking', 'DRF:Gamma', { 'c' => 3 })
        SettingsSpecDB.write(tmp_dir, 'core.banking', 'DR', { 'd' => 4 })
        SettingsSpecDB.write(tmp_dir, 'core', 'DR:Alpha', { 'e' => 5 })

        expect(@adapter.get_settings_by_scope_prefix('core.banking', 'DR:')).to eq(
          'DR:Alpha' => { 'a' => 1 }, 'DR:Beta' => { 'b' => 2 }
        )
      end

      it 'matches the prefix literally, not as a LIKE pattern' do
        SettingsSpecDB.write(tmp_dir, 's', 'D%:x', { 'a' => 1 })
        SettingsSpecDB.write(tmp_dir, 's', 'DR:x', { 'b' => 2 })
        SettingsSpecDB.write(tmp_dir, 's', 'D_:y', { 'c' => 3 })

        expect(@adapter.get_settings_by_scope_prefix('s', 'D%')).to eq('D%:x' => { 'a' => 1 })
        expect(@adapter.get_settings_by_scope_prefix('s', 'D_')).to eq('D_:y' => { 'c' => 3 })
      end

      it 'is case-sensitive' do
        SettingsSpecDB.write(tmp_dir, 's', 'dr:x', { 'a' => 1 })
        expect(@adapter.get_settings_by_scope_prefix('s', 'DR:')).to eq({})
      end

      it 'skips and logs a row it cannot load' do
        SettingsSpecDB.write_raw(tmp_dir, 's', 'DR:bad', 'garbage')
        SettingsSpecDB.write(tmp_dir, 's', 'DR:good', { 'a' => 1 })
        logged = []
        allow(Lich).to receive(:log) { |msg| logged << msg }

        expect(@adapter.get_settings_by_scope_prefix('s', 'DR:')).to eq('DR:good' => { 'a' => 1 })
        expect(logged.join).to include('scope=DR:bad')
      end

      it 'reads changes made through another connection' do
        expect(@adapter.get_settings_by_scope_prefix('s', '')).to eq({})
        SettingsSpecDB.write(tmp_dir, 's', 'x', { 'a' => 1 })
        expect(@adapter.get_settings_by_scope_prefix('s', '')).to eq('x' => { 'a' => 1 })
      end
    end

    describe '#update_settings!' do
      it 'yields {} for a missing row and writes what the block returns' do
        yielded = nil
        @adapter.update_settings!('s', 'x') { |h| yielded = h; h.merge('a' => 1) }
        expect(yielded).to eq({})
        expect(SettingsSpecDB.rows(tmp_dir)).to eq(%w[s x] => { 'a' => 1 })
      end

      it 'yields the stored row read fresh' do
        SettingsSpecDB.write(tmp_dir, 's', 'x', { 'a' => 1 })
        @adapter.update_settings!('s', 'x') { |h| h.merge('b' => 2) }
        expect(SettingsSpecDB.rows(tmp_dir)).to eq(%w[s x] => { 'a' => 1, 'b' => 2 })
      end

      it 'leaves the row alone and creates none when the block returns nil' do
        SettingsSpecDB.write(tmp_dir, 's', 'x', { 'a' => 1 })
        expect(@adapter.update_settings!('s', 'x') { |h| h['a'] = 2; nil }).to be_nil
        expect(@adapter.update_settings!('s', 'y') { nil }).to be_nil
        expect(SettingsSpecDB.rows(tmp_dir)).to eq(%w[s x] => { 'a' => 1 })
      end

      it 'raises and writes nothing when the block returns something else' do
        expect { @adapter.update_settings!('s', 'x') { [1] } }.to raise_error(TypeError, /Hash or nil, got Array/)
        expect(SettingsSpecDB.rows(tmp_dir)).to eq({})
      end

      it 'raises when the value cannot be serialized' do
        expect { @adapter.update_settings!('s', 'x') { { 'p' => proc {} } } }.to raise_error(TypeError)
        expect(SettingsSpecDB.rows(tmp_dir)).to eq({})
      end

      it "raises without yielding when the stored row can't be loaded" do
        SettingsSpecDB.write_raw(tmp_dir, 's', 'x', 'garbage')
        yielded = false
        expect { @adapter.update_settings!('s', 'x') { yielded = true; {} } }.to raise_error(TypeError)
        expect(yielded).to be(false)
        expect(SettingsSpecDB.rows(tmp_dir)).to eq(%w[s x] => :unreadable)
      end

      it 'raises, instead of reporting and returning nil, when the database refuses the write' do
        SettingsSpecDB.fail_writes_to(tmp_dir, 'x')
        expect { @adapter.update_settings!('s', 'x') { { 'a' => 1 } } }
          .to raise_error(Sequel::DatabaseError, /simulated write failure/)
        expect(SettingsSpecDB.rows(tmp_dir)).to eq({})
      end
    end

    describe '#save_settings!' do
      it 'writes the row without reading it, so it replaces a row that cannot be loaded' do
        SettingsSpecDB.write_raw(tmp_dir, 's', 'x', 'garbage')
        expect(@adapter.save_settings!('s', { 'a' => 1 }, 'x')).to eq('a' => 1)
        expect(SettingsSpecDB.rows(tmp_dir)).to eq(%w[s x] => { 'a' => 1 })
      end

      it 'raises and writes nothing for a non-Hash or unserializable value' do
        expect { @adapter.save_settings!('s', [1], 'x') }.to raise_error(TypeError, /must be a Hash, got Array/)
        expect { @adapter.save_settings!('s', { 'p' => proc {} }, 'x') }.to raise_error(TypeError)
        expect(SettingsSpecDB.rows(tmp_dir)).to eq({})
      end

      it 'raises when the database refuses the write' do
        SettingsSpecDB.fail_writes_to(tmp_dir, 'x')
        expect { @adapter.save_settings!('s', { 'a' => 1 }, 'x') }
          .to raise_error(Sequel::DatabaseError, /simulated write failure/)
        expect(SettingsSpecDB.rows(tmp_dir)).to eq({})
      end
    end

    describe '#scopes_by_prefix' do
      it "lists matching scopes literally, including rows that can't be loaded" do
        SettingsSpecDB.write(tmp_dir, 's', 'DR:a', { 'a' => 1 })
        SettingsSpecDB.write_raw(tmp_dir, 's', 'DR:bad', 'garbage')
        SettingsSpecDB.write(tmp_dir, 's', 'DRF:c', { 'c' => 1 })
        SettingsSpecDB.write(tmp_dir, 's', 'D%:d', { 'd' => 1 })
        SettingsSpecDB.write(tmp_dir, 'other', 'DR:e', { 'e' => 1 })

        expect(@adapter.scopes_by_prefix('s', 'DR:')).to contain_exactly('DR:a', 'DR:bad')
        expect(@adapter.scopes_by_prefix('s', 'D%')).to eq(['D%:d'])
        expect(@adapter.scopes_by_prefix('s', 'dr:')).to eq([])
      end
    end

    describe '#transaction' do
      it 'keeps nothing written inside it when the block raises' do
        expect {
          @adapter.transaction do
            @adapter.update_settings!('s', 'x') { { 'a' => 1 } }
            @adapter.update_settings!('s', 'y') { { 'b' => 2 } }
            raise 'boom'
          end
        }.to raise_error(RuntimeError, 'boom')
        expect(SettingsSpecDB.rows(tmp_dir)).to eq({})
      end

      it 'takes the write lock before the first read' do
        @adapter.transaction do
          other = Sequel.sqlite(SettingsSpecDB.path(tmp_dir), timeout: 0)
          begin
            expect { other.run('BEGIN IMMEDIATE') }.to raise_error(Sequel::DatabaseError, /locked|busy/i)
          ensure
            other.disconnect
          end
        end
      end

      it 'serializes read-modify-writes from separate processes' do
        workers = 4
        increments = 25
        script = <<~RUBY
          require #{File.expand_path('../../../support/lich_sqlite', __dir__).inspect}
          require #{File.expand_path('../../../../lib/common/settings/database_adapter', __dir__).inspect}
          module Lich; def self.log(*) = nil; end
          adapter = Lich::Common::DatabaseAdapter.new(ARGV[0], :script_auto_settings)
          #{increments}.times do
            adapter.update_settings!('s', 'counter') { |h| h.merge('n' => h.fetch('n', 0) + 1) }
          end
        RUBY
        pids = Array.new(workers) { Process.spawn(RbConfig.ruby, '-e', script, tmp_dir) }
        statuses = pids.map { |pid| Process.wait2(pid).last }

        expect(statuses).to all(be_success)
        expect(SettingsSpecDB.rows(tmp_dir)[%w[s counter]]).to eq('n' => workers * increments)
      end
    end
  end
end
