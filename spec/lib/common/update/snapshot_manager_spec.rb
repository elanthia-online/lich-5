# frozen_string_literal: true

require_relative 'update_spec_helper'

# Every example runs on a real, throwaway filesystem: LIB_DIR comes from
# update_spec_helper, and LICH_DIR, SCRIPT_DIR and BACKUP_DIR are replaced
# here so nothing leaks between examples or into other update specs.
RSpec.describe Lich::Util::Update::SnapshotManager do
  let(:manager) { described_class.new }
  let(:lich_name) { File.basename($PROGRAM_NAME) }
  let(:root) { Dir.mktmpdir('snapshot-manager-spec') }
  let(:lich_dir) { File.join(root, 'lich') }
  let(:script_dir) { File.join(lich_dir, 'scripts') }
  let(:backup_dir) { File.join(lich_dir, 'backup') }

  before do
    FileUtils.mkdir_p([script_dir, backup_dir])
    stub_const('LICH_DIR', lich_dir)
    stub_const('SCRIPT_DIR', script_dir)
    stub_const('BACKUP_DIR', backup_dir)
  end

  after do
    # Restore permissions changed by the unreadable-file examples so the
    # tree can be removed.
    FileUtils.chmod_R('u+rwx', root) if File.exist?(root)
    FileUtils.remove_entry(root, true)
  end

  def write(path, content)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  # Lays down a live install of +version+: lich.rbw, lib/ and scripts/.
  def install(version, extra_lib: {})
    write(File.join(LICH_DIR, lich_name), "# lich #{version}\n")
    write(File.join(LIB_DIR, 'version.rb'), "LICH_VERSION = '#{version}'\n")
    write(File.join(LIB_DIR, 'common', 'util.rb'), "# util #{version}\n")
    extra_lib.each { |rel, content| write(File.join(LIB_DIR, rel), content) }
    write(File.join(SCRIPT_DIR, 'go2.lic'), "# go2 #{version}\n")
    write(File.join(SCRIPT_DIR, 'map.lic'), "# map #{version}\n")
    write(File.join(SCRIPT_DIR, 'mine.lic'), "# user script\n")
  end

  # Writes a snapshot directory by hand. +omit+ drops parts to model the
  # incomplete directories older Lich versions left behind.
  def make_snapshot(stamp, version, omit: [])
    dir = File.join(BACKUP_DIR, "L5-snapshot-#{stamp}")
    FileUtils.mkdir_p(dir)
    write(File.join(dir, lich_name), "# lich #{version}\n") unless omit.include?(:lich)
    write(File.join(dir, 'lib', 'version.rb'), "LICH_VERSION = '#{version}'\n") unless omit.include?(:version)
    write(File.join(dir, 'lib', 'common', 'util.rb'), "# util #{version}\n") unless omit.include?(:lib)
    unless omit.include?(:scripts)
      write(File.join(dir, 'scripts', 'go2.lic'), "# go2 #{version}\n")
      write(File.join(dir, 'scripts', 'map.lic'), "# map #{version}\n")
    end
    dir
  end

  def published
    Dir.glob(File.join(BACKUP_DIR, 'L5-snapshot-*'))
  end

  def staging
    Dir.glob(File.join(BACKUP_DIR, 'L5-staging-*'))
  end

  def revert_temp_dirs
    [LIB_DIR, SCRIPT_DIR, LICH_DIR].flat_map { |dir| Dir.glob(File.join(dir, '.lich5-revert-*')) }
  end

  # Relative path => content for every file under +dir+.
  def tree(dir)
    Dir.glob('**/*', File::FNM_DOTMATCH, base: dir).each_with_object({}) do |rel, acc|
      path = File.join(dir, rel)
      acc[rel] = File.binread(path) if File.file?(path)
    end
  end

  def live_state
    { lib: tree(LIB_DIR), scripts: tree(SCRIPT_DIR), lich: File.read(File.join(LICH_DIR, lich_name)) }
  end

  def skip_unless_permissions_enforced
    skip 'file permissions are not enforced for root' if Process.respond_to?(:uid) && Process.uid.zero?
    skip 'chmod 000 does not block reads on Windows' if Gem.win_platform?
  end

  def capture_responses
    messages = []
    allow(manager).to receive(:respond) { |msg = ''| messages << msg.to_s }
    messages
  end

  describe '#new_data_backup_dir' do
    it 'uses a prefix that #revert\'s snapshot glob cannot match' do
      data_backup_dir = manager.new_data_backup_dir

      expect(File.basename(data_backup_dir)).to start_with('L5-databackup-')
      expect(published).to be_empty
    end

    it 'never returns the same directory for two calls in the same second' do
      # Regression guard: a bare mkdir_p on a second-resolution timestamp
      # would let two calls within the same wall-clock second (e.g. two
      # multiboxed Lich processes autostarting after an update) collide on
      # the same directory and silently clobber each other's backup.
      expect(manager.new_data_backup_dir).not_to eq(manager.new_data_backup_dir)
    end
  end

  describe '#snapshot' do
    before { install('5.22.0') }

    it 'publishes a complete snapshot and leaves no staging directory' do
      dir = manager.snapshot

      expect(published).to eq([dir])
      expect(staging).to be_empty
      expect(File.read(File.join(dir, lich_name))).to eq("# lich 5.22.0\n")
      expect(File.read(File.join(dir, 'scripts', 'go2.lic'))).to eq("# go2 5.22.0\n")
      expect(File.exist?(File.join(dir, 'scripts', 'mine.lic'))).to be(false)
    end

    it 'puts LIB_DIR\'s contents in lib/ even when LIB_DIR is not named lib (--lib-dir)' do
      expect(File.basename(LIB_DIR)).not_to eq('lib')

      dir = manager.snapshot

      expect(tree(File.join(dir, 'lib'))).to eq(tree(LIB_DIR))
      expect(Dir.children(dir).sort).to eq([lich_name, 'lib', 'scripts'].sort)
    end

    it 'produces a snapshot that #revert accepts and restores' do
      dir = manager.snapshot
      before_update = live_state
      install('5.23.0', extra_lib: { 'new_in_5_23.rb' => "# new\n" })

      messages = capture_responses
      manager.revert

      expect(live_state).to eq(before_update)
      expect(messages.join("\n")).to include(dir).and include('reverted to Lich5 version 5.22.0')
    end

    it 'creates BACKUP_DIR when it does not exist yet' do
      FileUtils.remove_entry(BACKUP_DIR)

      dir = manager.snapshot

      expect(File.directory?(dir)).to be(true)
    end

    it 'never shows an L5-snapshot-* directory while the copy is still running' do
      seen_during_copy = nil
      allow(FileUtils).to receive(:cp_r).and_wrap_original do |original, *args, **kwargs|
        seen_during_copy = published
        original.call(*args, **kwargs)
      end

      manager.snapshot

      expect(seen_during_copy).to eq([])
    end

    it 'removes the staging directory and publishes nothing when a lib file cannot be read' do
      skip_unless_permissions_enforced
      write(File.join(LIB_DIR, 'zz_locked.rb'), "# locked\n")
      File.chmod(0o000, File.join(LIB_DIR, 'zz_locked.rb'))
      messages = capture_responses

      expect { manager.snapshot }.to raise_error(Errno::EACCES)

      expect(published).to be_empty
      expect(staging).to be_empty
      expect(messages.join("\n")).to include('No snapshot was saved')
    end

    it 'publishes nothing when the launcher is not in LICH_DIR (--home pointing elsewhere)' do
      File.delete(File.join(LICH_DIR, lich_name))

      expect { manager.snapshot }.to raise_error(Errno::ENOENT)

      expect(published).to be_empty
      expect(staging).to be_empty
    end

    it 'gives a second snapshot in the same second its own, later-sorting name' do
      allow(Time).to receive(:now).and_return(Time.new(2026, 10, 18, 12, 0, 0))

      first = manager.snapshot
      install('5.22.1')
      second = manager.snapshot

      expect(first).to end_with('L5-snapshot-2026-10-18-12-00-00')
      expect(second).to end_with('L5-snapshot-2026-10-18-12-00-00-01')
      expect(File.read(File.join(first, lich_name))).to eq("# lich 5.22.0\n")
      expect(published.max).to eq(second)
    end

    it 'leaves only an invisible staging directory when the process is killed mid-copy' do
      skip 'fork is not available on this platform' unless Process.respond_to?(:fork)
      older = make_snapshot('2026-01-01-00-00-00', '5.21.0')
      reader, writer = IO.pipe

      pid = fork do
        reader.close
        # Die the hard way (no ensure, no at_exit) after lib/ is copied but
        # before the core scripts are, like a client closed mid-update.
        allow(FileUtils).to receive(:cp).and_wrap_original do |original, src, dest, **kwargs|
          if src.end_with?('.lic')
            writer.puts('killing')
            writer.flush
            Process.kill('KILL', Process.pid)
          end
          original.call(src, dest, **kwargs)
        end
        manager.snapshot
        writer.puts('finished')
        exit!(0)
      end
      writer.close
      Process.wait(pid)
      child_said = reader.read
      reader.close

      expect(child_said).to eq("killing\n")
      expect($?.termsig).to eq(Signal.list['KILL'])
      expect(published).to eq([older])
      expect(staging.size).to eq(1)
      expect(File.exist?(File.join(staging.first, 'lib', 'version.rb'))).to be(true)
      expect(Dir.exist?(File.join(staging.first, 'scripts'))).to be(true)
      expect(Dir.children(File.join(staging.first, 'scripts'))).to be_empty

      messages = capture_responses
      manager.revert

      expect(File.read(File.join(LIB_DIR, 'version.rb'))).to eq("LICH_VERSION = '5.21.0'\n")
      expect(File.read(File.join(SCRIPT_DIR, 'go2.lic'))).to eq("# go2 5.21.0\n")
      expect(messages.join("\n")).to include('reverted to Lich5 version 5.21.0')
    end
  end

  describe '#revert' do
    before { install('5.22.0', extra_lib: { 'new_in_5_22.rb' => "# new\n" }) }

    it 'reports that there is nothing to restore when no snapshot exists' do
      before = live_state
      messages = capture_responses

      manager.revert

      expect(messages).to include('No prior Lich5 version found. Seek assistance.')
      expect(live_state).to eq(before)
    end

    it 'restores lib/, the snapshot\'s scripts and the launcher exactly' do
      dir = make_snapshot('2026-10-01-00-00-00', '5.21.0')
      write(File.join(dir, 'lib', 'nested', 'deep', 'file.rb'), "# deep\n")
      allow(Lich::Util::Update).to receive(:clear_branch_tracking)
      messages = capture_responses

      manager.revert

      expect(tree(LIB_DIR)).to eq(tree(File.join(dir, 'lib')))
      expect(File.read(File.join(SCRIPT_DIR, 'go2.lic'))).to eq("# go2 5.21.0\n")
      expect(File.read(File.join(SCRIPT_DIR, 'map.lic'))).to eq("# map 5.21.0\n")
      expect(File.read(File.join(SCRIPT_DIR, 'mine.lic'))).to eq("# user script\n")
      expect(File.read(File.join(LICH_DIR, lich_name))).to eq("# lich 5.21.0\n")
      expect(revert_temp_dirs).to be_empty
      expect(Lich::Util::Update).to have_received(:clear_branch_tracking)
      expect(messages).to include('Restoring Lich5 version 5.21.0 from:')
      expect(messages).to include('Lich5 has been reverted to Lich5 version 5.21.0')
    end

    it 'restores from the newest snapshot by name when every snapshot is complete' do
      make_snapshot('2026-09-01-00-00-00', '5.20.0')
      make_snapshot('2026-10-01-00-00-00', '5.21.0')

      manager.revert

      expect(File.read(File.join(LIB_DIR, 'version.rb'))).to eq("LICH_VERSION = '5.21.0'\n")
    end

    it 'keeps a core script the snapshot does not contain instead of deleting it' do
      make_snapshot('2026-10-01-00-00-00', '5.21.0')
      write(File.join(SCRIPT_DIR, 'jinx.lic'), "# jinx 5.22.0\n")

      manager.revert

      expect(File.read(File.join(SCRIPT_DIR, 'jinx.lic'))).to eq("# jinx 5.22.0\n")
    end

    it 'keeps the live launcher\'s permissions' do
      skip 'POSIX modes only' if Gem.win_platform?
      make_snapshot('2026-10-01-00-00-00', '5.21.0')
      File.chmod(0o755, File.join(LICH_DIR, lich_name))
      File.chmod(0o600, File.join(BACKUP_DIR, 'L5-snapshot-2026-10-01-00-00-00', lich_name))

      manager.revert

      expect(File.stat(File.join(LICH_DIR, lich_name)).mode & 0o777).to eq(0o755)
    end

    it 'ignores a newer plain file that matches the snapshot name pattern' do
      make_snapshot('2026-10-01-00-00-00', '5.21.0')
      write(File.join(BACKUP_DIR, 'L5-snapshot-2026-10-02-00-00-00.zip'), 'zip')

      manager.revert

      expect(File.read(File.join(LIB_DIR, 'version.rb'))).to eq("LICH_VERSION = '5.21.0'\n")
    end

    context 'when the newest snapshot is incomplete' do
      let!(:complete) { make_snapshot('2026-10-01-00-00-00', '5.21.0') }

      {
        'has no lib/version.rb' => [%i[version], 'lib/version.rb is missing'],
        'has no launcher'       => [%i[lich], "#{File.basename($PROGRAM_NAME)} is missing"],
        'has no scripts/'       => [%i[scripts], 'scripts/ is missing'],
        'is empty'              => [%i[lich version lib scripts], 'lib/version.rb is missing']
      }.each do |description, (omit, problem)|
        it "refuses, names it and changes nothing when it #{description}" do
          bad = make_snapshot('2026-10-17-00-00-00', '5.22.0', omit: omit)
          before = live_state
          messages = capture_responses

          manager.revert

          expect(live_state).to eq(before)
          expect(revert_temp_dirs).to be_empty
          expect(messages).to include('The newest snapshot is incomplete, so nothing was changed:')
          expect(messages).to include("    #{bad}")
          expect(messages.grep(/^  - /).join).to include(problem)
          expect(messages).to include('The next complete snapshot is Lich5 version 5.21.0:')
          expect(messages).to include("    #{complete}")
          expect(messages.join("\n")).not_to include('has been reverted')
        end
      end

      it 'refuses when lib/version.rb does not declare LICH_VERSION (a truncated copy)' do
        bad = make_snapshot('2026-10-17-00-00-00', '5.22.0')
        File.write(File.join(bad, 'lib', 'version.rb'), '')
        before = live_state
        messages = capture_responses

        manager.revert

        expect(live_state).to eq(before)
        expect(messages).to include('  - lib/version.rb does not declare LICH_VERSION')
      end

      it 'restores the older snapshot once the user moves the incomplete one aside' do
        bad = make_snapshot('2026-10-17-00-00-00', '5.22.0', omit: %i[scripts])
        manager.revert
        FileUtils.remove_entry(bad)

        manager.revert

        expect(File.read(File.join(LIB_DIR, 'version.rb'))).to eq("LICH_VERSION = '5.21.0'\n")
      end
    end

    it 'says no complete snapshot exists when the only one is incomplete' do
      make_snapshot('2026-10-17-00-00-00', '5.22.0', omit: %i[version scripts])
      before = live_state
      messages = capture_responses

      manager.revert

      expect(live_state).to eq(before)
      expect(messages).to include('No complete snapshot was found. Seek assistance.')
    end

    it 'leaves the install untouched when the snapshot cannot be fully copied' do
      skip_unless_permissions_enforced
      dir = make_snapshot('2026-10-01-00-00-00', '5.21.0')
      write(File.join(dir, 'lib', 'zz_locked.rb'), "# locked\n")
      File.chmod(0o000, File.join(dir, 'lib', 'zz_locked.rb'))
      before = live_state
      messages = capture_responses

      expect { manager.revert }.to raise_error(Errno::EACCES)

      expect(live_state).to eq(before)
      expect(revert_temp_dirs).to be_empty
      expect(messages).to include('Nothing was changed.')
    end

    it 'undoes every rename when one fails part way through the swap' do
      make_snapshot('2026-10-01-00-00-00', '5.21.0')
      before = live_state
      live_lich = File.join(LICH_DIR, lich_name)
      allow(File).to receive(:rename).and_wrap_original do |original, from, to|
        raise Errno::EACCES, to if to == live_lich && from.include?('.lich5-revert-new-')

        original.call(from, to)
      end
      messages = capture_responses

      expect { manager.revert }.to raise_error(Errno::EACCES)

      expect(live_state).to eq(before)
      expect(revert_temp_dirs).to be_empty
      expect(messages).to include('Every change was undone; your installation is as it was.')
    end

    it 'keeps and names the working directories when the undo also fails' do
      make_snapshot('2026-10-01-00-00-00', '5.21.0')
      live_version = File.join(LIB_DIR, 'version.rb')
      allow(File).to receive(:rename).and_wrap_original do |original, from, to|
        raise Errno::EACCES, to if to.end_with?('scripts/go2.lic') && from.include?('.lich5-revert-new-')
        raise Errno::EACCES, to if to == live_version && from.include?('.lich5-revert-old-')

        original.call(from, to)
      end
      messages = capture_responses

      expect { manager.revert }.to raise_error(Errno::EACCES)

      kept = revert_temp_dirs
      expect(kept).not_to be_empty
      old_lib = kept.find { |path| path.start_with?(LIB_DIR) && path.include?('-old-') }
      expect(File.read(File.join(old_lib, 'version.rb'))).to eq("LICH_VERSION = '5.22.0'\n")
      expect(messages).to include('Some changes could not be undone. Your previous files are kept in:')
      kept.each { |path| expect(messages).to include("    #{path}") }
    end
  end
end
