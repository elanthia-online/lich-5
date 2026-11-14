# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'tmpdir'
require_relative '../../../login_spec_helper'

# The macOS keychain store and read. The examples that run the real security
# tool use a throwaway keychain file and a probe service name, never the
# user's keychain or the real master-password item.
RSpec.describe Lich::Common::GUI::MasterPasswordManager, :real_keychain do
  # rubocop:disable Custom/AsciiOnlySource -- Non-ASCII password fixture, written as escapes; the tool reports such values in hexadecimal.
  non_ascii = "p\u00E4ssw\u00F6rd \u65E5\u672C"
  # rubocop:enable Custom/AsciiOnlySource

  let(:non_ascii) { non_ascii }
  let(:probe_service) { 'lich5.spec.keychain-probe' }
  let(:succeeded) { instance_double(Process::Status, success?: true, exitstatus: 0) }
  let(:failed) { instance_double(Process::Status, success?: false, exitstatus: 45) }

  before do
    stub_const("#{described_class}::KEYCHAIN_SERVICE", probe_service)
    allow(described_class).to receive(:keychain_available?).and_return(true)
    allow(OS).to receive(:mac?).and_return(true)
    allow(OS).to receive(:linux?).and_return(false)
    allow(OS).to receive(:windows?).and_return(false)
    allow(Lich).to receive(:log)
  end

  describe 'storing, with the security tool stubbed' do
    before do
      allow(described_class).to receive(:system).and_raise('the store must not run a shell command')
      allow(Open3).to receive(:capture3).and_return(['', '', succeeded])
    end

    it 'sends the command on standard input, so no argument carries the password' do
      expect(described_class.store_master_password('correct horse 12')).to be(true)

      expect(Open3).to have_received(:capture3).once.with(
        '/usr/bin/security', '-i',
        stdin_data: "add-generic-password -U -s #{probe_service} -a lich5 -X 636f727265637420686f727365203132\n"
      )
    end

    it 'encodes every byte of the password, so nothing in it can end or extend the command' do
      expect(described_class.store_master_password(%(a "b" \\c\n-s other #{non_ascii}))).to be(true)

      expect(Open3).to have_received(:capture3) do |*_arguments, stdin_data:|
        expect(stdin_data).to match(/\Aadd-generic-password -U -s #{Regexp.escape(probe_service)} -a lich5 -X \h+\n\z/)
        expect(stdin_data.count("\n")).to eq(1)
      end
    end

    it 'reports failure when the tool does' do
      allow(Open3).to receive(:capture3).and_return(['', 'synthetic diagnostic', failed])

      expect(described_class.store_master_password('correct horse 12')).to be(false)
    end

    it 'refuses an empty password without running the tool' do
      expect(described_class.store_master_password('')).to be(false)
      expect(Open3).not_to have_received(:capture3)
    end
  end

  describe 'reading, with the security tool stubbed' do
    def tool_reports(password_line, status: succeeded)
      allow(Open3).to receive(:capture3)
        .with('/usr/bin/security', 'find-generic-password', '-s', probe_service, '-g')
        .and_return(["keychain: \"synthetic\"\n", password_line, status])
    end

    it 'returns a plainly reported password as stored, edge spaces included' do
      tool_reports(%(password: "  lead and trail  "\n))

      expect(described_class.retrieve_master_password).to eq('  lead and trail  ')
    end

    it 'decodes a password the tool reports in hexadecimal' do
      tool_reports(%(password: 0x70C3A4737377C3B6726420E697A5E69CAC  "p\\303\\244ssw\\303\\266rd \\346\\227\\245\\346\\234\\254"\n))

      password = described_class.retrieve_master_password
      expect(password).to eq(non_ascii)
      expect(password.encoding).to eq(Encoding::UTF_8)
    end

    it 'returns a password that only looks like hexadecimal unchanged' do
      tool_reports(%(password: "70c3a4737377"\n))

      expect(described_class.retrieve_master_password).to eq('70c3a4737377')
    end

    it 'keeps quotation marks inside a plainly reported password' do
      tool_reports(%(password: "say "hi" twice"\n))

      expect(described_class.retrieve_master_password).to eq('say "hi" twice')
    end

    it 'returns nil when the tool reports no password line, an empty one, or fails' do
      tool_reports('')
      expect(described_class.retrieve_master_password).to be_nil

      tool_reports(%(password: ""\n))
      expect(described_class.retrieve_master_password).to be_nil

      tool_reports(%(password: "leftover"\n), status: failed)
      expect(described_class.retrieve_master_password).to be_nil
    end

    it 'returns the same decoded password from a strict read' do
      tool_reports(%(password: 0x7461620968657265  "tab\there"\n))

      expect(described_class.retrieve_master_password(strict: true)).to eq("tab\there")
    end
  end

  describe 'against the real security tool and a throwaway keychain', if: RUBY_PLATFORM.include?('darwin') do
    let(:keychain_dir) { Dir.mktmpdir('lich-keychain-spec') }
    let(:keychain) { File.join(keychain_dir, 'probe.keychain-db') }

    before do
      skip 'the security tool is not installed' unless File.executable?('/usr/bin/security')

      _out, error, status = Open3.capture3('/usr/bin/security', 'create-keychain', '-p', 'spec-only', keychain)
      raise "could not create the throwaway keychain: #{error}" unless status.success?

      allow(described_class).to receive(:macos_keychain_target).and_return([keychain])
    end

    after do
      Open3.capture3('/usr/bin/security', 'delete-keychain', keychain)
      FileUtils.rm_rf(keychain_dir)
    end

    {
      'plain text'                   => 'correct horse 12',
      'leading and trailing spaces'  => '  lead and trail  ',
      'non-ASCII characters'         => non_ascii,
      'text that looks hexadecimal'  => '70c3a4737377c3b6',
      'text that looks like a 0x id' => '0x41424344',
      'quotation marks'              => %(say "hi" and 'bye'),
      'a backslash'                  => 'back\\slash\\303',
      'shell characters'             => '$(id); `id` | & > *',
      'a tab'                        => "tab\there"
    }.each do |description, password|
      it "reads back #{description} exactly as stored" do
        expect(described_class.store_master_password(password)).to be(true)

        expect(described_class.retrieve_master_password).to eq(password)
        expect(described_class.retrieve_master_password(strict: true)).to eq(password)
      end
    end

    it 'replaces a stored password in place' do
      expect(described_class.store_master_password('first password')).to be(true)
      expect(described_class.store_master_password("second #{non_ascii}")).to be(true)

      expect(described_class.retrieve_master_password).to eq("second #{non_ascii}")
    end

    it 'reports absence as nil, strictly and otherwise, when nothing is stored' do
      expect(described_class.retrieve_master_password).to be_nil
      expect(described_class.retrieve_master_password(strict: true)).to be_nil
    end

    it 'validates a non-ASCII password read back from the keychain against its own test' do
      validation_test = described_class.create_validation_test(non_ascii)
      described_class.store_master_password(non_ascii)

      expect(described_class.validate_master_password(described_class.retrieve_master_password, validation_test)).to be(true)
    end
  end
end
