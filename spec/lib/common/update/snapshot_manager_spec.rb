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
    # Other spec files define a top-level respond with a different
    # signature (one requires an argument), and which one is loaded
    # depends on how the suite is split, so never rely on the global one.
    allow(manager).to receive(:respond)
    # Rename retries on Windows wait between attempts; never really sleep.
    allow(manager).to receive(:sleep)
  end

  after do
    # Restore permissions changed by the unreadable-file examples so the
    # tree can be removed. Symlinks are skipped: chmod follows them, and a
    # dangling one would raise.
    unlock_tree(root) if File.exist?(root)
    FileUtils.remove_entry(root, true)
  end

  # Gives the owner full access to +path+ and, for a directory, everything
  # under it, fixing each directory before listing it.
  def unlock_tree(path)
    return if File.symlink?(path)

    File.chmod(0o700, path)
    Dir.children(path).each { |name| unlock_tree(File.join(path, name)) } if File.directory?(path)
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

  def symlinks_supported?
    probe = File.join(root, 'symlink-probe')
    File.symlink(root, probe)
    File.delete(probe)
    true
  rescue NotImplementedError, SystemCallError
    false
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

    it 'treats EACCES as a collision when another snapshot took the name first (Windows)' do
      allow(Time).to receive(:now).and_return(Time.new(2026, 10, 18, 12, 0, 0))
      base = File.join(BACKUP_DIR, 'L5-snapshot-2026-10-18-12-00-00')
      allow(File).to receive(:rename).and_wrap_original do |original, from, to|
        if to == base
          # Another instance publishes between the existence check and the
          # rename; Windows then reports EACCES, not EEXIST.
          FileUtils.mkdir_p(File.join(base, 'lib'))
          raise Errno::EACCES, to
        end
        original.call(from, to)
      end

      dir = manager.snapshot

      expect(dir).to eq("#{base}-01")
      expect(File.read(File.join(dir, lich_name))).to eq("# lich 5.22.0\n")
      expect(staging).to be_empty
    end

    it 're-raises an EACCES from publishing when nothing took the name' do
      allow(File).to receive(:rename).and_raise(Errno::EACCES)
      messages = capture_responses

      expect { manager.snapshot }.to raise_error(Errno::EACCES)

      expect(published).to be_empty
      expect(staging).to be_empty
      expect(messages.join("\n")).to include('No snapshot was saved')
    end

    it 'leaves out working directories a failed revert kept in LIB_DIR' do
      write(File.join(LIB_DIR, '.lich5-revert-old-abc123', 'version.rb'), "LICH_VERSION = '5.21.0'\n")
      write(File.join(LIB_DIR, '.lich5-revert-new-def456', 'common', 'util.rb'), "# util 5.20.0\n")
      write(File.join(LIB_DIR, '.hidden_user_file'), "keep\n")

      dir = manager.snapshot

      expect(Dir.children(File.join(dir, 'lib')).grep(/\A\.lich5-revert-/)).to be_empty
      expect(tree(File.join(dir, 'lib'))).to eq(tree(LIB_DIR).reject { |rel, _| rel.start_with?('.lich5-revert-') })
      expect(File.read(File.join(dir, 'lib', '.hidden_user_file'))).to eq("keep\n")
    end

    context 'when LIB_DIR contains symlinks (a developer linking lib/<x> into a checkout)' do
      let(:outside) { File.join(root, 'outside') }

      before do
        skip 'symlinks are not available on this platform' unless symlinks_supported?
        write(File.join(outside, 'big.rb'), "# outside\n")
      end

      it 'still publishes a snapshot when a link in LIB_DIR is dangling' do
        File.symlink(File.join(root, 'missing.rb'), File.join(LIB_DIR, 'dangling.rb'))

        dir = manager.snapshot

        expect(published).to eq([dir])
        expect(staging).to be_empty
        expect(File.readlink(File.join(dir, 'lib', 'dangling.rb'))).to eq(File.join(root, 'missing.rb'))
      end

      it 'keeps a linked directory as a link instead of copying its tree' do
        File.symlink(outside, File.join(LIB_DIR, 'linkdir'))

        dir = manager.snapshot

        expect(File.symlink?(File.join(dir, 'lib', 'linkdir'))).to be(true)
        expect(File.readlink(File.join(dir, 'lib', 'linkdir'))).to eq(outside)
      end

      it 'restores the links on revert' do
        File.symlink(outside, File.join(LIB_DIR, 'linkdir'))
        File.symlink(File.join(root, 'missing.rb'), File.join(LIB_DIR, 'dangling.rb'))
        manager.snapshot
        FileUtils.rm_f([File.join(LIB_DIR, 'linkdir'), File.join(LIB_DIR, 'dangling.rb')])
        install('5.23.0')

        manager.revert

        expect(File.read(File.join(LIB_DIR, 'version.rb'))).to eq("LICH_VERSION = '5.22.0'\n")
        expect(File.readlink(File.join(LIB_DIR, 'linkdir'))).to eq(outside)
        expect(File.readlink(File.join(LIB_DIR, 'dangling.rb'))).to eq(File.join(root, 'missing.rb'))
      end
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

    it 'leaves a working directory an earlier failed revert kept for recovery in place' do
      make_snapshot('2026-10-01-00-00-00', '5.21.0')
      kept = File.join(LIB_DIR, '.lich5-revert-old-abc123')
      write(File.join(kept, 'version.rb'), "LICH_VERSION = '5.22.0'\n")

      manager.revert

      expect(File.read(File.join(LIB_DIR, 'version.rb'))).to eq("LICH_VERSION = '5.21.0'\n")
      expect(File.read(File.join(kept, 'version.rb'))).to eq("LICH_VERSION = '5.22.0'\n")
      expect(revert_temp_dirs).to eq([kept])
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

    context 'when several incomplete snapshots are stacked above a complete one' do
      # Older Lich versions left one empty L5-snapshot-* directory per failed
      # snapshot attempt, e.g. a --home without lich.rbw failing every time.
      let!(:complete) { make_snapshot('2026-10-01-00-00-00', '5.21.0') }
      let!(:stacked) do
        %w[10 11 12].map do |day|
          make_snapshot("2026-10-#{day}-00-00-00", '5.22.0', omit: %i[lich version lib scripts])
        end
      end

      it 'names every one of them and changes nothing' do
        before = live_state
        messages = capture_responses

        manager.revert

        expect(live_state).to eq(before)
        expect(revert_temp_dirs).to be_empty
        expect(messages).to include('The 3 newest snapshots are incomplete, so nothing was changed:')
        stacked.each { |dir| expect(messages).to include("    #{dir}") }
        expect(messages).to include('They were most likely left by snapshots that were interrupted.')
        expect(messages).to include('The next complete snapshot is Lich5 version 5.21.0:')
        expect(messages).to include("    #{complete}")
        expect(messages).to include('To revert to it, move or delete all 3 incomplete directories above,')
        expect(messages.join("\n")).not_to include('has been reverted')
      end

      it 'restores the complete snapshot after the user removes every listed directory' do
        messages = capture_responses
        manager.revert
        listed = messages.grep(/\A    /).map(&:strip) - [complete]
        listed.each { |dir| FileUtils.remove_entry(dir) }

        manager.revert

        expect(listed).to match_array(stacked)
        expect(File.read(File.join(LIB_DIR, 'version.rb'))).to eq("LICH_VERSION = '5.21.0'\n")
      end

      it 'does not list an incomplete snapshot older than the complete one' do
        older = make_snapshot('2026-09-01-00-00-00', '5.20.0', omit: %i[scripts])
        messages = capture_responses

        manager.revert

        expect(messages).not_to include("    #{older}")
      end
    end

    context 'when an older Lich saved the snapshot with --lib-dir (files under its own name)' do
      let(:legacy_name) { File.basename(LIB_DIR) }

      # Older versions ran mkdir_p(<snap>/lib) then cp_r(LIB_DIR, <snap>),
      # so the files land in <snap>/<LIB_DIR name>/ and lib/ stays empty.
      def make_legacy_snapshot(stamp, version, omit: [], empty_lib: true)
        dir = make_snapshot(stamp, version, omit: %i[version lib] + omit)
        FileUtils.mkdir_p(File.join(dir, 'lib')) if empty_lib
        write(File.join(dir, legacy_name, 'version.rb'), "LICH_VERSION = '#{version}'\n")
        write(File.join(dir, legacy_name, 'common', 'util.rb'), "# util #{version}\n")
        dir
      end

      it 'refuses it and says to rename the directory instead of blaming an interruption' do
        expect(legacy_name).not_to eq('lib')
        dir = make_legacy_snapshot('2026-10-17-00-00-00', '5.21.0')
        before = live_state
        messages = capture_responses

        manager.revert

        expect(live_state).to eq(before)
        expect(messages).to include("    #{dir}")
        expect(messages).to include('  - lib/version.rb is missing')
        expect(messages).to include("  - an older Lich saved this --lib-dir snapshot's files in #{legacy_name}/; " \
                                    "to use it, delete the empty lib/ in it, then rename #{legacy_name}/ to lib/")
        expect(messages.grep(/interrupted/)).to be_empty
      end

      it 'restores it once the steps in the hint are followed literally' do
        dir = make_legacy_snapshot('2026-10-17-00-00-00', '5.21.0')
        Dir.rmdir(File.join(dir, 'lib')) # "delete the empty lib/"; raises if it is not empty
        File.rename(File.join(dir, legacy_name), File.join(dir, 'lib'))

        manager.revert

        expect(File.read(File.join(LIB_DIR, 'version.rb'))).to eq("LICH_VERSION = '5.21.0'\n")
        expect(File.read(File.join(LIB_DIR, 'common', 'util.rb'))).to eq("# util 5.21.0\n")
      end

      it 'only says to rename when the snapshot has no lib/ at all, and that alone makes it restorable' do
        dir = make_legacy_snapshot('2026-10-17-00-00-00', '5.21.0', empty_lib: false)
        messages = capture_responses

        manager.revert

        expect(messages).to include("  - an older Lich saved this --lib-dir snapshot's files in #{legacy_name}/; " \
                                    "to use it, rename #{legacy_name}/ to lib/")
        expect(messages.grep(/delete the empty/)).to be_empty

        File.rename(File.join(dir, legacy_name), File.join(dir, 'lib'))
        manager.revert

        expect(File.read(File.join(LIB_DIR, 'version.rb'))).to eq("LICH_VERSION = '5.21.0'\n")
      end

      {
        'scripts/ is missing' => :scripts,
        'lich.rbw is missing' => :lich
      }.each do |problem, part|
        it "gives no rename hint and blames an interruption when #{problem} too" do
          dir = make_legacy_snapshot('2026-10-17-00-00-00', '5.21.0', omit: [part])
          before = live_state
          messages = capture_responses

          manager.revert

          expect(live_state).to eq(before)
          expect(messages).to include("    #{dir}", "  - #{problem.sub('lich.rbw', lich_name)}")
          expect(messages.grep(/rename/)).to be_empty
          expect(messages).to include('It was most likely left by a snapshot that was interrupted.')
        end
      end

      it 'gives no rename hint when lib/ in the snapshot is not empty' do
        dir = make_legacy_snapshot('2026-10-17-00-00-00', '5.21.0')
        write(File.join(dir, 'lib', 'common', 'util.rb'), "# util 5.21.0\n")
        messages = capture_responses

        manager.revert

        expect(messages).to include("    #{dir}", '  - lib/version.rb is missing')
        expect(messages.grep(/rename/)).to be_empty
        expect(messages).to include('It was most likely left by a snapshot that was interrupted.')
      end

      it 'still blames an interruption for the other directories when both kinds are listed' do
        legacy = make_legacy_snapshot('2026-10-16-00-00-00', '5.21.0')
        broken = make_snapshot('2026-10-17-00-00-00', '5.22.0', omit: %i[scripts])
        messages = capture_responses

        manager.revert

        expect(messages).to include('The 2 newest snapshots are incomplete, so nothing was changed:')
        expect(messages).to include("    #{legacy}", "    #{broken}")
        expect(messages).to include('The ones without a rename hint were most likely left by snapshots that were interrupted.')
      end

      it 'gives no rename hint when LIB_DIR is named lib' do
        dir = make_snapshot('2026-10-17-00-00-00', '5.21.0', omit: %i[version])
        write(File.join(dir, 'other', 'version.rb'), "LICH_VERSION = '5.21.0'\n")
        stub_const('LIB_DIR', File.join(root, 'live', 'lib'))
        install('5.22.0')
        messages = capture_responses

        manager.revert

        expect(messages.grep(/rename/)).to be_empty
        expect(messages).to include('It was most likely left by a snapshot that was interrupted.')
      end
    end

    it 'names every incomplete snapshot when none is complete' do
      first = make_snapshot('2026-10-16-00-00-00', '5.22.0', omit: %i[scripts])
      second = make_snapshot('2026-10-17-00-00-00', '5.22.0', omit: %i[lich])
      messages = capture_responses

      manager.revert

      expect(messages).to include('The 2 newest snapshots are incomplete, so nothing was changed:')
      expect(messages.index("    #{second}")).to be < messages.index("    #{first}")
      expect(messages).to include('No complete snapshot was found. Seek assistance.')
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

    context 'when another revert on the same installation is running' do
      let(:lock_path) { File.join(BACKUP_DIR, described_class::REVERT_LOCK_NAME) }
      let(:refusal) { 'Another revert is already running on this installation. Nothing was changed.' }

      before { make_snapshot('2026-10-01-00-00-00', '5.21.0') }

      # Takes the revert lock through a separate open file, as another
      # process would. flock locks belong to the open file, so this
      # conflicts with the manager's own open even within one process.
      def hold_lock
        File.open(lock_path, File::RDWR | File::CREAT, 0o644) do |lock|
          expect(lock.flock(File::LOCK_EX | File::LOCK_NB)).to be_truthy
          yield
        end
      end

      def lock_free?
        File.open(lock_path, File::RDWR | File::CREAT, 0o644) { |lock| lock.flock(File::LOCK_EX | File::LOCK_NB) ? true : false }
      end

      it 'changes nothing and says so while the lock is held' do
        before = live_state
        messages = capture_responses

        hold_lock { manager.revert }

        expect(live_state).to eq(before)
        expect(revert_temp_dirs).to be_empty
        expect(messages).to include(refusal)
        expect(messages).not_to include('Restoring Lich5 version 5.21.0 from:')
      end

      it 'refuses while a revert in another process is part way through swapping files' do
        skip 'needs fork' unless Process.respond_to?(:fork)
        paused_r, paused_w = IO.pipe
        resume_r, resume_w = IO.pipe
        result_r, result_w = IO.pipe
        pid = fork do
          [paused_r, resume_w, result_r].each(&:close)
          first = described_class.new
          first.define_singleton_method(:respond) { |*| nil }
          move = first.method(:move_entry)
          paused = false
          # Stops after the first rename of the swap, with the live lib/
          # half moved out, until the parent says to go on.
          first.define_singleton_method(:move_entry) do |from, to, journal|
            move.call(from, to, journal)
            next if paused

            paused = true
            paused_w.write('p')
            paused_w.flush
            resume_r.read(1)
          end
          status = begin
            first.revert
            'ok'
          rescue StandardError => e
            "#{e.class}: #{e.message}"
          end
          result_w.write(status)
          result_w.close
          exit!(0)
        end
        [paused_w, resume_r, result_w].each(&:close)
        begin
          expect(paused_r.wait_readable(30)).to be_truthy
          expect(paused_r.read(1)).to eq('p')
          messages = capture_responses

          manager.revert

          expect(messages).to include(refusal)
          resume_w.write('g')
          resume_w.close
          expect(result_r.read).to eq('ok')
        ensure
          resume_w.close unless resume_w.closed?
          Process.wait(pid)
        end

        expect(tree(LIB_DIR)).to eq(tree(File.join(BACKUP_DIR, 'L5-snapshot-2026-10-01-00-00-00', 'lib')))
        expect(File.read(File.join(LICH_DIR, lich_name))).to eq("# lich 5.21.0\n")
        expect(revert_temp_dirs).to be_empty
      end

      it 'releases the lock when it finishes and when it fails' do
        manager.revert
        expect(lock_free?).to be(true)

        install('5.22.0')
        allow(File).to receive(:rename).and_wrap_original do |original, from, to|
          raise Errno::EACCES, to if to == File.join(LICH_DIR, lich_name) && from.include?('.lich5-revert-new-')

          original.call(from, to)
        end
        expect { manager.revert }.to raise_error(Errno::EACCES)
        expect(lock_free?).to be(true)
      end

      it 'creates BACKUP_DIR for the lock and still reports when there is no snapshot' do
        FileUtils.rm_rf(BACKUP_DIR)
        messages = capture_responses

        manager.revert

        expect(messages).to include('No prior Lich5 version found. Seek assistance.')
        expect(File.file?(lock_path)).to be(true)
      end

      it 'runs without the lock when the filesystem does not support flock' do
        allow(File).to receive(:open).and_wrap_original do |original, *args, **kwargs, &block|
          file = original.call(*args, **kwargs)
          allow(file).to receive(:flock).and_raise(Errno::ENOLCK) if args.first == lock_path
          next file unless block

          begin
            block.call(file)
          ensure
            file.close
          end
        end
        messages = capture_responses

        manager.revert

        expect(File.read(File.join(LIB_DIR, 'version.rb'))).to eq("LICH_VERSION = '5.21.0'\n")
        expect(messages.grep(/continuing without the lock/)).not_to be_empty
      end

      it 'runs without the lock when the lock file cannot be created' do
        skip_unless_permissions_enforced
        File.chmod(0o555, BACKUP_DIR)
        messages = capture_responses

        manager.revert

        expect(File.read(File.join(LIB_DIR, 'version.rb'))).to eq("LICH_VERSION = '5.21.0'\n")
        expect(messages.grep(/Could not create the revert lock file/)).not_to be_empty
        expect(File.exist?(lock_path)).to be(false)
      end
    end
  end

  context 'when Windows briefly refuses a rename (a scanner holding a file open)' do
    let(:delays) { described_class::RENAME_RETRY_DELAYS }
    let(:stamp) { Time.new(2026, 10, 18, 12, 0, 0) }
    let(:base) { File.join(BACKUP_DIR, 'L5-snapshot-2026-10-18-12-00-00') }

    before do
      install('5.22.0')
      allow(Gem).to receive(:win_platform?).and_return(true)
      allow(Time).to receive(:now).and_return(stamp)
    end

    # Makes File.rename raise +error+ for the first +times+ calls the block
    # matches (all of them when +times+ is nil) and returns the matching
    # calls as [from, to] pairs.
    def refuse_renames(times: nil, error: Errno::EACCES)
      matched = []
      allow(File).to receive(:rename).and_wrap_original do |original, from, to|
        if yield(from, to)
          matched << [from, to]
          raise error, to if times.nil? || matched.size <= times
        end
        original.call(from, to)
      end
      matched
    end

    it 'publishes the snapshot once the staging rename is allowed, waiting between attempts' do
      calls = refuse_renames(times: 2) { |from, to| to == base && from.include?('L5-staging-') }
      messages = capture_responses

      dir = manager.snapshot

      expect(dir).to eq(base)
      expect(calls.size).to eq(3)
      expect(File.read(File.join(dir, lich_name))).to eq("# lich 5.22.0\n")
      expect(File.read(File.join(dir, 'lib', 'version.rb'))).to eq("LICH_VERSION = '5.22.0'\n")
      expect(staging).to be_empty
      expect(manager).to have_received(:sleep).with(delays[0]).ordered
      expect(manager).to have_received(:sleep).with(delays[1]).ordered
      expect(manager).to have_received(:sleep).twice
      expect(messages.grep(/Snapshot failed/)).to be_empty
    end

    [Errno::EPERM, Errno::EBUSY].each do |error|
      it "retries a staging rename refused with #{error.name.split('::').last}" do
        refuse_renames(times: 1, error: error) { |from, _to| from.include?('L5-staging-') }

        expect(manager.snapshot).to eq(base)
        expect(staging).to be_empty
      end
    end

    it 'gives up after the last retry, publishes nothing and removes the staging directory' do
      calls = refuse_renames { |from, to| to == base && from.include?('L5-staging-') }
      messages = capture_responses

      expect { manager.snapshot }.to raise_error(Errno::EACCES)

      expect(calls.size).to eq(delays.size + 1)
      delays.each { |delay| expect(manager).to have_received(:sleep).with(delay).ordered }
      expect(manager).to have_received(:sleep).exactly(delays.size).times
      expect(published).to be_empty
      expect(staging).to be_empty
      expect(messages).to include('No snapshot was saved and nothing was changed.')
    end

    it 'does not wait when the name was taken; it moves on to the next name' do
      refuse_renames do |_from, to|
        next false unless to == base

        FileUtils.mkdir_p(File.join(base, 'lib'))
        true
      end

      expect(manager.snapshot).to eq("#{base}-01")
      expect(manager).not_to have_received(:sleep)
      expect(staging).to be_empty
    end

    it 'does not retry errors other than the transient ones' do
      calls = refuse_renames(error: Errno::ENOENT) { |from, _to| from.include?('L5-staging-') }

      expect { manager.snapshot }.to raise_error(Errno::ENOENT)

      expect(calls.size).to eq(1)
      expect(manager).not_to have_received(:sleep)
    end

    it 'does not retry on other platforms, where the refusal does not clear on its own' do
      allow(Gem).to receive(:win_platform?).and_return(false)
      calls = refuse_renames(times: 1) { |from, _to| from.include?('L5-staging-') }

      expect { manager.snapshot }.to raise_error(Errno::EACCES)

      expect(calls.size).to eq(1)
      expect(manager).not_to have_received(:sleep)
      expect(published).to be_empty
    end

    context 'during a revert' do
      let(:live_lich) { File.join(LICH_DIR, lich_name) }
      let(:live_version) { File.join(LIB_DIR, 'version.rb') }

      before { make_snapshot('2026-10-01-00-00-00', '5.21.0') }

      it 'completes the swap when one rename is refused at first' do
        calls = refuse_renames(times: 1) { |from, to| to == live_lich && from.include?('.lich5-revert-new-') }
        messages = capture_responses

        manager.revert

        expect(calls.size).to eq(2)
        expect(tree(LIB_DIR)).to eq(tree(File.join(BACKUP_DIR, 'L5-snapshot-2026-10-01-00-00-00', 'lib')))
        expect(File.read(live_lich)).to eq("# lich 5.21.0\n")
        expect(File.read(File.join(SCRIPT_DIR, 'go2.lic'))).to eq("# go2 5.21.0\n")
        expect(revert_temp_dirs).to be_empty
        expect(messages).to include('Lich5 has been reverted to Lich5 version 5.21.0')
      end

      it 'retries the undo too, so a briefly refused undo still restores everything' do
        before = live_state
        swap_calls = []
        undo_calls = []
        allow(File).to receive(:rename).and_wrap_original do |original, from, to|
          if to == live_lich && from.include?('.lich5-revert-new-')
            swap_calls << [from, to]
            raise Errno::EACCES, to
          end
          if to == live_version && from.include?('.lich5-revert-old-')
            undo_calls << [from, to]
            raise Errno::EACCES, to if undo_calls.size == 1
          end
          original.call(from, to)
        end
        messages = capture_responses

        expect { manager.revert }.to raise_error(Errno::EACCES)

        expect(swap_calls.size).to eq(delays.size + 1)
        expect(undo_calls.size).to eq(2)
        expect(live_state).to eq(before)
        expect(revert_temp_dirs).to be_empty
        expect(messages).to include('Every change was undone; your installation is as it was.')
      end
    end
  end
end
