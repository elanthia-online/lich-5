# frozen_string_literal: true

require_relative 'update_spec_helper'

RSpec.describe Lich::Util::Update::FileWriter do
  let(:tmpdir) { Dir.mktmpdir('fw-test') }
  let(:content_lf) { "# test script\nputs 'hello'\n" }
  let(:content_modified) { "# test script v2\nputs 'hello world'\n" }

  after { FileUtils.remove_entry(tmpdir) }

  describe '.build_local_sha_map' do
    it 'computes git blob SHAs for files matching the pattern' do
      File.binwrite(File.join(tmpdir, 'foo.lic'), content_lf)
      File.binwrite(File.join(tmpdir, 'bar.lic'), content_modified)
      File.binwrite(File.join(tmpdir, 'skip.txt'), 'ignored')

      map = described_class.build_local_sha_map(tmpdir, '*.lic')

      expect(map.keys).to contain_exactly('foo.lic', 'bar.lic')
      expect(map['foo.lic']).to eq(git_blob_sha(content_lf))
      expect(map['bar.lic']).to eq(git_blob_sha(content_modified))
    end

    it 'returns empty hash for empty directory' do
      expect(described_class.build_local_sha_map(tmpdir)).to eq({})
    end

    it 'only includes files matching the glob pattern' do
      File.binwrite(File.join(tmpdir, 'script.lic'), "content")
      File.binwrite(File.join(tmpdir, 'data.yaml'), "data")
      File.binwrite(File.join(tmpdir, 'readme.md'), "readme")

      lic_map = described_class.build_local_sha_map(tmpdir, '*.lic')
      yaml_map = described_class.build_local_sha_map(tmpdir, '*.yaml')

      expect(lic_map.keys).to eq(['script.lic'])
      expect(yaml_map.keys).to eq(['data.yaml'])
    end
  end

  describe '.safe_write' do
    it 'writes content in binary mode preserving LF endings' do
      path = File.join(tmpdir, 'test.lic')
      described_class.safe_write(path, content_lf)

      expect(File.binread(path)).to eq(content_lf)
    end

    it 'creates .old backup and cleans up on success' do
      path = File.join(tmpdir, 'test.lic')
      File.binwrite(path, 'original')

      described_class.safe_write(path, content_lf)

      expect(File.binread(path)).to eq(content_lf)
      expect(File.exist?("#{path}.old")).to be false
      expect(File.exist?("#{path}.tmp")).to be false
    end

    it 'round-trips content with matching SHA' do
      path = File.join(tmpdir, 'roundtrip.lic')
      described_class.safe_write(path, content_lf)
      read_back = File.binread(path)

      expect(git_blob_sha(read_back)).to eq(git_blob_sha(content_lf))
    end

    it 'preserves original file when binwrite raises' do
      path = File.join(tmpdir, 'important.lic')
      original_content = "# original content\n"
      File.binwrite(path, original_content)

      allow(File).to receive(:binwrite).and_raise(Errno::ENOSPC.new("No space left on device"))

      expect { described_class.safe_write(path, "# new content\n") }.to raise_error(Errno::ENOSPC)

      expect(File.binread(path)).to eq(original_content)
      expect(File.exist?("#{path}.tmp")).to be false
      expect(File.exist?("#{path}.old")).to be false
    end

    it 'cleans up tmp file when writing a new file fails' do
      path = File.join(tmpdir, 'brand-new.lic')

      allow(File).to receive(:binwrite).and_raise(Errno::EACCES.new("Permission denied"))

      expect { described_class.safe_write(path, "# content\n") }.to raise_error(Errno::EACCES)

      expect(File.exist?(path)).to be false
      expect(File.exist?("#{path}.tmp")).to be false
      expect(File.exist?("#{path}.old")).to be false
    end
  end
end
