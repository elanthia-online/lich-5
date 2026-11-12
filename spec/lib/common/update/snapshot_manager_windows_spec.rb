# frozen_string_literal: true

require_relative 'update_spec_helper'

# Native Windows behaviour behind SnapshotManager#rename_with_retry: a file
# held open inside a directory, without delete sharing, blocks renaming the
# directory, and Ruby reports that refusal as EXDEV ("Improper link") when
# the new name does not exist yet. Players saw exactly that from
# ;lich5-update while a scanner held a freshly copied snapshot file.
RSpec.describe Lich::Util::Update::SnapshotManager, 'renames on native Windows' do
  let(:manager) { described_class.new }
  let(:root) { Dir.mktmpdir('snapshot-manager-windows-spec') }
  let(:staging_dir) { File.join(root, 'L5-staging-spec') }
  let(:held_file) { File.join(staging_dir, 'lib', 'version.rb') }
  let(:target) { File.join(root, 'L5-snapshot-spec') }

  # Opens files the way a scanner does: read access, sharing read and write
  # but not delete.
  let(:kernel32) do
    Module.new do
      extend Fiddle::Importer
      dlload 'kernel32.dll'
      extern 'void* CreateFileW(void*, unsigned long, unsigned long, void*, unsigned long, unsigned long, void*)'
      extern 'int CloseHandle(void*)'
    end
  end

  let(:generic_read) { 0x8000_0000 }
  let(:file_share_read_write) { 3 }
  let(:open_existing) { 3 }

  before do
    skip 'requires native Windows file sharing rules' unless Gem.win_platform?
    require 'fiddle/import'
    FileUtils.mkdir_p(File.dirname(held_file))
    File.write(held_file, "LICH_VERSION = '5.24.0'\n")
    allow(manager).to receive(:respond)
  end

  after do
    FileUtils.remove_entry(root, true) if File.exist?(root)
  end

  def hold(path)
    encoded = path.encode('UTF-16LE').b + [0].pack('v')
    handle = kernel32.CreateFileW(encoded, generic_read, file_share_read_write, 0, open_existing, 0, 0)
    error = Fiddle.win32_last_error
    invalid = [-1, (1 << (Fiddle::SIZEOF_VOIDP * 8)) - 1].include?(handle.to_i)
    raise "could not hold #{path}: Windows error #{error}" if invalid

    handle
  end

  it 'gets EXDEV from File.rename while a file inside the directory is held (the reported failure)' do
    handle = hold(held_file)
    begin
      expect { File.rename(staging_dir, target) }.to raise_error(Errno::EXDEV)
      expect(File.exist?(target)).to be(false)
    ensure
      kernel32.CloseHandle(handle)
    end
  end

  it 'renames the directory once the holder lets go during the retries' do
    handle = hold(held_file)
    releaser = Thread.new do
      sleep 0.5
      kernel32.CloseHandle(handle)
    end

    manager.send(:rename_with_retry, staging_dir, target)

    expect(File.read(File.join(target, 'lib', 'version.rb'))).to eq("LICH_VERSION = '5.24.0'\n")
    expect(File.exist?(staging_dir)).to be(false)
    expect(manager).to have_received(:respond).with(/retrying/).once
  ensure
    releaser&.join
  end
end
