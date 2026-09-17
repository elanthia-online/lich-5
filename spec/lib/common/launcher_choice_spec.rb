# frozen_string_literal: true

require_relative '../../spec_helper'
require 'sqlite3'
require 'tmpdir'
require_relative '../../../lib/common/launcher_choice'

RSpec.describe Lich::LauncherChoice do
  after { Lich.reset_launcher! }

  describe '.flag' do
    it 'reads --webui, --gtk and the --webui-dev alias, case-insensitively, last one winning' do
      expect(described_class.flag(['--webui'])).to eq(:webui)
      expect(described_class.flag(['--GTK'])).to eq(:gtk)
      expect(described_class.flag(['--webui-dev'])).to eq(:webui)
      expect(described_class.flag(['--webui', '--login', 'Tsetem', '--gtk'])).to eq(:gtk)
      expect(described_class.flag(['--login', 'Tsetem'])).to be_nil
      expect(described_class.flag([])).to be_nil
    end
  end

  describe '.resolve' do
    it 'takes the flag over the setting over the default, in that order' do
      expect(described_class.resolve(argv: ['--gtk'], setting: -> { :webui }, default: :webui)).to eq(:gtk)
      expect(described_class.resolve(argv: [], setting: -> { :webui }, default: :gtk)).to eq(:webui)
      expect(described_class.resolve(argv: [], setting: -> {}, default: :gtk)).to eq(:gtk)
    end

    it 'defaults to DEFAULT, which is the one constant a release flips' do
      expect(described_class.resolve(argv: [], setting: -> {})).to eq(described_class::DEFAULT)
      expect(described_class::CHOICES).to include(described_class::DEFAULT)
    end

    # The 5.x default: the WebUI launcher. GTK stays reachable behind --gtk
    # or the persisted setting until Lich 6 deletes it. Flipping this line
    # back is the whole rollback.
    it 'launches the WebUI when nothing says otherwise' do
      expect(described_class::DEFAULT).to eq(:webui)
      expect(described_class.resolve(argv: ['--login', 'Tsetem'], setting: -> {})).to eq(:webui)
      expect(described_class.resolve(argv: ['--gtk'], setting: -> {})).to eq(:gtk)
    end
  end

  describe 'the persisted setting' do
    let(:db) do
      SQLite3::Database.new(':memory:').tap do |database|
        database.execute('CREATE TABLE lich_settings (name TEXT NOT NULL, value TEXT, PRIMARY KEY(name));')
      end
    end

    before do
      @dir = Dir.mktmpdir('launcher-choice-')
      stub_const('DATA_DIR', @dir)
      allow(Lich).to receive(:db).and_return(db)
    end

    after { FileUtils.remove_entry(@dir) if @dir }

    it 'round-trips through lich_settings and clears on nil or nonsense' do
      expect(described_class.setting).to be_nil

      described_class.setting = :webui
      expect(described_class.setting).to eq(:webui)
      expect(db.get_first_value("SELECT value FROM lich_settings WHERE name='launcher';")).to eq('webui')

      described_class.setting = 'GTK '
      expect(described_class.setting).to eq(:gtk)

      described_class.setting = 'qt'
      expect(described_class.setting).to be_nil
      expect(db.get_first_value("SELECT count(*) FROM lich_settings WHERE name='launcher';")).to eq(0)
    end

    it 'answers the launcher UI in toolkit-free terms' do
      expect(described_class.native_next?).to be(false)
      described_class.native_next = true
      expect(described_class.setting).to eq(:gtk)
      expect(described_class.native_next?).to be(true)
      described_class.native_next = false
      expect(described_class.setting).to eq(:webui)
    end

    it 'is "no setting" rather than an error before the data directory or the table exists' do
      stub_const('DATA_DIR', File.join(DATA_DIR, 'not-yet'))
      expect(described_class.setting).to be_nil

      stub_const('DATA_DIR', Dir.tmpdir)
      db.execute('DROP TABLE lich_settings;')
      expect(described_class.setting).to be_nil
    end

    it 'feeds Lich.launcher, which resolves once and can be reset' do
      described_class.setting = :webui
      allow(described_class).to receive(:resolve).and_call_original
      original_argv = ARGV.dup
      ARGV.replace([])

      expect(Lich.launcher).to eq(:webui)
      expect(Lich.launcher).to eq(:webui)
      expect(described_class).to have_received(:resolve).once

      described_class.setting = :gtk
      expect(Lich.launcher).to eq(:webui)
      Lich.reset_launcher!
      expect(Lich.launcher).to eq(:gtk)
    ensure
      ARGV.replace(original_argv) if original_argv
    end
  end
end
