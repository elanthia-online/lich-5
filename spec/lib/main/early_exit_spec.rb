# frozen_string_literal: true

require 'rspec'

require_relative '../../../lib/main/early_exit'

RSpec.describe Lich::Main::EarlyExit do
  before { stub_const('LICH_VERSION', '5.20.1') }

  describe '.requested?' do
    it 'recognizes every help and version spelling' do
      ['-h', '--help', '--help=login', '-v', '--version'].each do |flag|
        expect(described_class.requested?([flag])).to be(true), "expected #{flag} to be recognized"
      end
    end

    it 'ignores arguments that start a session' do
      expect(described_class.requested?(['--login', 'Someone', '--no-gtk'])).to be(false)
    end

    it 'ignores an empty argument list' do
      expect(described_class.requested?([])).to be(false)
    end

    # PR #1439 removed the inference of a headless launch from DISPLAY, TTY,
    # and cron state. This allow-list must never bring it back.
    it 'decides from the arguments alone, not from the environment' do
      original = ENV['DISPLAY']
      [nil, ':0'].each do |display|
        ENV['DISPLAY'] = display
        expect(described_class.requested?(['--help'])).to be(true)
        expect(described_class.requested?(['--login', 'Someone'])).to be(false)
      end
    ensure
      ENV['DISPLAY'] = original
    end
  end

  describe '.dispatch!' do
    it 'prints the overview and exits for --help' do
      expect { described_class.dispatch!(['--help']) }
        .to output(/Lich 5/).to_stdout
        .and raise_error(SystemExit)
    end

    it 'prints the requested topic for --help=login' do
      expect { described_class.dispatch!(['--help=login']) }
        .to output(/Lich Help: login/).to_stdout
        .and raise_error(SystemExit)
    end

    it 'prints the requested topic for a separated help argument' do
      expect { described_class.dispatch!(['--help', 'advanced']) }
        .to output(/Lich Help: advanced/).to_stdout
        .and raise_error(SystemExit)
    end

    it 'prints the version and exits for --version' do
      expect { described_class.dispatch!(['--version']) }
        .to output(/The Lich, version 5\.20\.1/).to_stdout
        .and raise_error(SystemExit)
    end

    it 'handles the first selected command when several are present' do
      expect { described_class.dispatch!(['--version', '--help']) }
        .to output(/The Lich, version 5\.20\.1/).to_stdout
        .and raise_error(SystemExit)
    end

    it 'returns without output when no early-exit command is present' do
      expect { described_class.dispatch!(['--login', 'Someone']) }.not_to output.to_stdout
    end

    it 'does not exit when no early-exit command is present' do
      expect { described_class.dispatch!(['--login', 'Someone']) }.not_to raise_error
    end
  end

  describe 'load isolation' do
    # The module runs before GemCheck and before lib/init.rb requires GTK, so
    # it must not reach the heavy CLI require chain or any optional gem.
    it 'loads without gtk3, sqlite3, or the ARGV pipeline' do
      source = File.read(File.expand_path('../../../lib/main/early_exit.rb', __dir__))

      expect(source).not_to match(/require.*gtk3/)
      expect(source).not_to match(/require.*sqlite3/)
      expect(source).not_to match(/require.*argv_options/)
      expect(source).not_to match(/require.*cli_orchestration/)
    end
  end

  describe 'lich.rbw boot ordering' do
    # The whole point of this module is where it runs. Guard the order so a
    # later edit to lich.rbw cannot silently reintroduce elanthia-online/lich-5#1545.
    let(:boot) { File.read(File.expand_path('../../../lich.rbw', __dir__)) }

    def index_of(pattern)
      match = boot.index(pattern)
      raise "lich.rbw no longer contains #{pattern.inspect}" if match.nil?

      match
    end

    it 'dispatches early-exit commands before the gem check' do
      expect(index_of('Lich::Main::EarlyExit.dispatch!')).to be < index_of('Lich::GemCheck.verify!')
    end

    it 'dispatches early-exit commands before init.rb requires GTK' do
      expect(index_of('Lich::Main::EarlyExit.dispatch!')).to be < index_of("require File.join(LIB_DIR, 'init.rb')")
    end
  end
end
