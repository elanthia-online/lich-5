# frozen_string_literal: true

require 'stringio'
require 'tmpdir'
require 'yaml'
require 'fileutils'
require_relative '../../../support/data_dir'
require_relative '../../../login_spec_helper'
require_relative '../../../../lib/common/cli/cli_encryption_mode_change'

# --password-stdin for --change-encryption-mode: the one master password a
# change needs is read from stdin, and nothing is prompted for.
RSpec.describe Lich::Common::CLI::EncryptionModeChange do
  let(:temp_dir) { Dir.mktmpdir }
  let(:yaml_file) { File.join(temp_dir, 'entry.yaml') }
  let(:entry_store) { Lich::Common::Authentication::EntryStore }
  let(:manager) { Lich::Common::GUI::MasterPasswordManager }
  let(:cli_password) { Lich::Common::Authentication::CLIPassword }
  # Stands in for a terminal: getpass returns one line without its ending.
  let(:terminal) do
    Class.new do
      def initialize(*lines) = @lines = lines
      def tty? = true
      def getpass(_prompt = nil) = @lines.shift
    end
  end

  around do |example|
    original_stdin = $stdin
    example.run
  ensure
    $stdin = original_stdin
  end

  before do
    allow(entry_store).to receive(:yaml_file_path).and_return(yaml_file)
    allow(entry_store).to receive(:change_encryption_mode).and_return(true)
    allow(cli_password).to receive(:prompt_for_master_password).and_raise('must not prompt with --password-stdin')
    allow(cli_password).to receive(:get_master_password_from_keychain_or_prompt).and_raise('must not prompt with --password-stdin')
    allow($stdout).to receive(:puts)
    allow($stdout).to receive(:print)
  end

  after { FileUtils.rm_rf(temp_dir) }

  def write_entries(mode, existing: nil)
    data = { 'encryption_mode' => mode, 'accounts' => { 'DOUG' => { 'password' => 'synthetic' } } }
    data['master_password_validation_test'] = manager.create_validation_test(existing) if existing
    File.write(yaml_file, YAML.dump(data))
  end

  describe '.change_mode entering enhanced with password_stdin' do
    before { write_entries('plaintext') }

    it 'uses the piped line as the new master password' do
      $stdin = StringIO.new("piped-master-pass\r\n")

      expect(described_class.change_mode(:enhanced, password_stdin: true)).to eq(0)
      expect(entry_store).to have_received(:change_encryption_mode).with(anything, :enhanced, 'piped-master-pass')
    end

    it 'prints no prompt for a piped line' do
      $stdin = StringIO.new("piped-master-pass\n")

      expect(described_class.change_mode(:enhanced, password_stdin: true)).to eq(0)
      expect($stdout).not_to have_received(:print).with('Enter new master password: ')
    end

    it 'shows which password it is waiting for when stdin is a terminal' do
      $stdin = terminal.new('typed-master-pass')

      expect(described_class.change_mode(:enhanced, password_stdin: true)).to eq(0)
      expect($stdout).to have_received(:print).with('Enter new master password: ')
      expect(entry_store).to have_received(:change_encryption_mode).with(anything, :enhanced, 'typed-master-pass')
    end

    it 'applies the shared new-password rule to the piped line, writing nothing' do
      $stdin = StringIO.new(" padded-secret\n")

      expect(described_class.change_mode(:enhanced, password_stdin: true)).to eq(1)
      expect(entry_store).not_to have_received(:change_encryption_mode)
      expect($stdout).to have_received(:puts).with('error: New master password cannot begin or end with whitespace.')
    end

    it 'returns 1 at end-of-input, writing nothing' do
      $stdin = StringIO.new('')

      expect(described_class.change_mode(:enhanced, password_stdin: true)).to eq(1)
      expect(entry_store).not_to have_received(:change_encryption_mode)
      expect($stdout).to have_received(:puts).with('error: Unable to read password from STDIN / terminal')
    end
  end

  describe '.change_mode leaving enhanced with password_stdin' do
    before { write_entries('enhanced', existing: ' padded secret ') }

    it 'validates the piped line as the current master password, edge spaces intact' do
      $stdin = StringIO.new(" padded secret \n")

      expect(described_class.change_mode(:standard, password_stdin: true)).to eq(0)
      expect(entry_store).to have_received(:change_encryption_mode).with(anything, :standard, nil)
    end

    it 'returns 1 for a piped line that is not the current master password' do
      $stdin = StringIO.new("padded secret\n")

      expect(described_class.change_mode(:standard, password_stdin: true)).to eq(1)
      expect(entry_store).not_to have_received(:change_encryption_mode)
    end

    it 'reads the plaintext confirmation from the line after the password' do
      $stdin = StringIO.new(" padded secret \nyes\n")

      expect(described_class.change_mode(:plaintext, password_stdin: true)).to eq(0)
      expect(entry_store).to have_received(:change_encryption_mode).with(anything, :plaintext, nil)
    end

    it 'asks for the current master password by name when stdin is a terminal' do
      tty = terminal.new(' padded secret ')
      tty.define_singleton_method(:gets) { "yes\n" }
      $stdin = tty

      expect(described_class.change_mode(:plaintext, password_stdin: true)).to eq(0)
      expect($stdout).to have_received(:print).with('Enter master password: ')
    end
  end

  describe '.change_mode between modes that need no master password' do
    before { write_entries('plaintext') }

    it 'reads nothing from stdin for the password' do
      $stdin = StringIO.new("unrelated\n")

      expect(described_class.change_mode(:standard, password_stdin: true)).to eq(0)
      expect($stdin.pos).to eq(0)
      expect(entry_store).to have_received(:change_encryption_mode).with(anything, :standard, nil)
    end
  end
end
