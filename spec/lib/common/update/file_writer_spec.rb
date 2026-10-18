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

    it 'leaves no temporary or backup file behind on success' do
      path = File.join(tmpdir, 'test.lic')
      File.binwrite(path, 'original')

      described_class.safe_write(path, content_lf)

      expect(File.binread(path)).to eq(content_lf)
      expect(Dir.children(tmpdir)).to eq(['test.lic'])
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
      expect(Dir.children(tmpdir)).to eq(['important.lic'])
    end

    it 'cleans up tmp file when writing a new file fails' do
      path = File.join(tmpdir, 'brand-new.lic')

      allow(File).to receive(:binwrite).and_raise(Errno::EACCES.new("Permission denied"))

      expect { described_class.safe_write(path, "# content\n") }.to raise_error(Errno::EACCES)

      expect(Dir.children(tmpdir)).to be_empty
    end

    context 'while the new content is being staged' do
      let(:path) { File.join(tmpdir, 'buff.lic') }
      let(:original_content) { "# buff v1\n" }

      before do
        File.binwrite(path, original_content)
        File.binwrite(File.join(tmpdir, 'buff-watcher.lic'), "# watcher\n")
      end

      # Runs safe_write and captures directory state from inside the staging
      # write, i.e. after safe_write started and before it finished.
      def observe_during_staging(new_content)
        seen = {}
        allow(File).to receive(:binwrite).and_wrap_original do |original, tmp, data|
          seen[:children] = Dir.children(tmpdir).sort
          seen[:live] = File.exist?(path) ? File.binread(path) : :missing
          seen[:tmp] = tmp
          original.call(tmp, data)
        end
        described_class.safe_write(path, new_content)
        seen
      end

      it 'keeps the live file in place with its old content' do
        seen = observe_during_staging(content_modified)

        expect(seen[:live]).to eq(original_content)
        expect(File.binread(path)).to eq(content_modified)
      end

      it 'keeps the exact script name listed, so a start cannot fall back to a prefix sibling' do
        seen = observe_during_staging(content_modified)

        expect(seen[:children]).to include('buff.lic', 'buff-watcher.lic')
        expect(seen[:children].grep(/\.old\z/)).to be_empty
      end

      it 'stages into a same-directory name that no script or SHA glob matches' do
        seen = observe_during_staging(content_modified)
        staged = File.basename(seen[:tmp])

        expect(File.dirname(seen[:tmp])).to eq(tmpdir)
        expect(staged).to start_with('buff.lic.')
        expect(staged).to end_with('.tmp')
        expect(staged).not_to match(/\.(lic|rb|cmd|wiz)(\.(gz|Z))?\z/i)
        expect(File.fnmatch('*.lic', staged)).to be false
        expect(File.fnmatch('*.yaml', staged)).to be false
        expect(File.fnmatch('*.xml', staged)).to be false
      end
    end

    it 'preserves the original file and removes the staged file when the rename fails' do
      path = File.join(tmpdir, 'locked.lic')
      File.binwrite(path, "# original\n")
      allow(File).to receive(:rename).and_raise(Errno::EACCES.new('Permission denied'))

      expect { described_class.safe_write(path, "# new\n") }.to raise_error(Errno::EACCES)

      expect(File.binread(path)).to eq("# original\n")
      expect(Dir.children(tmpdir)).to eq(['locked.lic'])
    end

    it 'raises the write error, not a cleanup error, when the staged file cannot be removed' do
      path = File.join(tmpdir, 'stuck.lic')
      File.binwrite(path, "# original\n")
      allow(File).to receive(:rename).and_raise(Errno::EACCES.new('Permission denied'))
      allow(File).to receive(:delete).and_raise(Errno::EBUSY.new('in use'))

      expect { described_class.safe_write(path, "# new\n") }.to raise_error(Errno::EACCES)
      expect(File.binread(path)).to eq("# original\n")
    end

    it 'removes .old and .tmp files left by older versions after a successful write' do
      path = File.join(tmpdir, 'legacy.lic')
      File.binwrite("#{path}.old", "# left by an interrupted update\n")
      File.binwrite("#{path}.tmp", "# partial\n")

      described_class.safe_write(path, content_lf)

      expect(File.binread(path)).to eq(content_lf)
      expect(Dir.children(tmpdir)).to eq(['legacy.lic'])
    end

    it 'leaves other files with similar names alone' do
      path = File.join(tmpdir, 'legacy.lic')
      others = ['legacy.lic.bak', 'legacy-other.lic.old', 'legacy.old']
      others.each { |name| File.binwrite(File.join(tmpdir, name), 'keep') }

      described_class.safe_write(path, content_lf)

      expect(Dir.children(tmpdir)).to contain_exactly('legacy.lic', *others)
    end

    it 'does not remove a directory that happens to carry a leftover name' do
      path = File.join(tmpdir, 'odd.lic')
      Dir.mkdir("#{path}.old")

      described_class.safe_write(path, content_lf)

      expect(File.directory?("#{path}.old")).to be true
    end

    it 'reports success even when a leftover from an older version cannot be removed' do
      path = File.join(tmpdir, 'keeper.lic')
      old_path = "#{path}.old"
      File.binwrite(path, "# original\n")
      File.binwrite(old_path, "# stale\n")
      allow(File).to receive(:delete).and_call_original
      allow(File).to receive(:delete).with(old_path).and_raise(Errno::EACCES.new('Permission denied'))

      expect { described_class.safe_write(path, "# updated\n") }.not_to raise_error
      expect(File.binread(path)).to eq("# updated\n")
    end

    it 'removes the staged file when the writing thread is killed mid-write' do
      path = File.join(tmpdir, 'buff.lic')
      File.binwrite(path, "# v1\n")
      staging = Queue.new
      allow(File).to receive(:binwrite).and_wrap_original do |original, tmp, data|
        original.call(tmp, data[0, 3])
        staging << tmp
        sleep
      end

      writer = Thread.new { described_class.safe_write(path, "# v2\n") }
      staged = staging.pop
      expect(File.exist?(staged)).to be true
      writer.kill
      writer.join

      expect(File.binread(path)).to eq("# v1\n")
      expect(Dir.children(tmpdir)).to eq(['buff.lic'])
    end

    context 'with staging files left by a hard-killed writer' do
      let(:path) { File.join(tmpdir, 'buff.lic') }
      let(:old_time) { Time.now - described_class::STALE_STAGING_AGE - 60 }

      def leave(name, age: old_time)
        file = File.join(tmpdir, name)
        File.binwrite(file, '# partial')
        File.utime(age, age, file)
        file
      end

      before { File.binwrite(path, "# v1\n") }

      it 'removes stale staging files of the same name after a successful write' do
        leave('buff.lic.4242.16.tmp')
        leave('buff.lic.4243.8.tmp')

        described_class.safe_write(path, "# v2\n")

        expect(Dir.children(tmpdir)).to eq(['buff.lic'])
      end

      it 'keeps a recent staging file, which may belong to a writer still running' do
        leave('buff.lic.4242.16.tmp', age: Time.now - 60)

        described_class.safe_write(path, "# v2\n")

        expect(Dir.children(tmpdir)).to contain_exactly('buff.lic', 'buff.lic.4242.16.tmp')
      end

      it 'keeps stale files that only look similar or belong to another script' do
        others = ['buff-watcher.lic.4242.16.tmp', 'buff.lic.abc.16.tmp', 'buff.lic.4242.tmp',
                  'buff.lic.4242.16.tmp.bak', 'xbuff.lic.4242.16.tmp']
        others.each { |name| leave(name) }

        described_class.safe_write(path, "# v2\n")

        expect(Dir.children(tmpdir)).to contain_exactly('buff.lic', *others)
      end

      it 'matches the file name literally, not as a pattern' do
        plus = File.join(tmpdir, 'a+b.lic')
        leave('a+b.lic.1.2.tmp')
        leave('aab.lic.1.2.tmp')

        described_class.safe_write(plus, "# v2\n")

        expect(Dir.children(tmpdir)).to contain_exactly('buff.lic', 'a+b.lic', 'aab.lic.1.2.tmp')
      end

      it 'leaves stale staging files alone when the write fails' do
        leave('buff.lic.4242.16.tmp')
        allow(File).to receive(:rename).and_raise(Errno::EACCES.new('Permission denied'))

        expect { described_class.safe_write(path, "# v2\n") }.to raise_error(Errno::EACCES)

        expect(Dir.children(tmpdir)).to contain_exactly('buff.lic', 'buff.lic.4242.16.tmp')
        expect(File.binread(path)).to eq("# v1\n")
      end

      it 'reports success even when the directory cannot be listed for the sweep' do
        leave('buff.lic.4242.16.tmp')
        allow(Dir).to receive(:each_child).and_raise(Errno::EACCES.new('Permission denied'))

        expect { described_class.safe_write(path, "# v2\n") }.not_to raise_error
        expect(File.binread(path)).to eq("# v2\n")
      end

      it 'reports success even when a stale staging file cannot be removed' do
        stale = leave('buff.lic.4242.16.tmp')
        allow(File).to receive(:delete).and_call_original
        allow(File).to receive(:delete).with(stale).and_raise(Errno::EBUSY.new('in use'))

        expect { described_class.safe_write(path, "# v2\n") }.not_to raise_error
        expect(File.binread(path)).to eq("# v2\n")
      end
    end

    it 'lets a second writer finish inside the first one without either failing' do
      path = File.join(tmpdir, 'shared.lic')
      File.binwrite(path, "# original\n")
      second_error = nil
      calls = 0
      allow(File).to receive(:binwrite).and_wrap_original do |original, *args|
        calls += 1
        original.call(*args)
        next unless calls == 1

        Thread.new do
          described_class.safe_write(path, "# second\n")
        rescue StandardError => e
          second_error = e
        end.join
      end

      expect { described_class.safe_write(path, "# first\n") }.not_to raise_error
      expect(second_error).to be_nil
      expect(File.binread(path)).to eq("# first\n")
      expect(Dir.children(tmpdir)).to eq(['shared.lic'])
    end
  end
end
