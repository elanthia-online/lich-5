# frozen_string_literal: true

require_relative '../../spec_helper'
require 'zlib'

# Specs for the Lich version-gating helpers on Lich::Common::Script:
#   - Script.required_lich_version  (parses the "required: Lich >= X" header)
#   - Script.lich_version_satisfied? (compares against LICH_VERSION)
#   - Script.require_lich_version!   (warn + stop the script when too old)
# plus characterization of the refactored Script.version, which now shares the
# private __find_script_file / __extract_header_comments helpers, and a
# regression for custom/<subdir>/ script resolution (the resolver is shared
# with Script.start, which supports subdirectories).
#
# The real lib/common/script.rb is loaded once (like script_kill_metrics_spec)
# and its constants are removed afterwards so other specs see the spec_helper
# stub. A small virtual filesystem is stubbed per-example so no real scripts
# are touched: scripts can be registered at SCRIPT_DIR root, the custom/ root,
# or a custom/<subdir>/.
RSpec.describe 'Lich::Common::Script Lich version gating' do
  let(:script_class) { Lich::Common::Script }
  let(:root) { '/fake/scripts' }
  let(:custom_base) { '/fake/scripts/custom' }

  before(:context) do
    require_relative '../../../lib/common/script'
  end

  after(:context) do
    %i[ExecScript WizardScript Script Scripting TRUSTED_SCRIPT_BINDING].each do |const_name|
      Lich::Common.send(:remove_const, const_name) if Lich::Common.const_defined?(const_name, false)
    end
    $LOADED_FEATURES.delete_if { |path| path.end_with?('/lib/common/script.rb') }
  end

  before do
    stub_const('SCRIPT_DIR', root)
    @root_files = []          # filenames directly under SCRIPT_DIR
    @custom_files = []        # filenames directly under custom/
    @subdir_files = Hash.new { |h, k| h[k] = [] } # subdir name => filenames
    @contents = {} # normalized absolute path => source text

    allow(File).to receive(:directory?).with(custom_base).and_return(true)
    allow(Dir).to receive(:glob).with("#{custom_base}/*/") do
      @subdir_files.keys.map { |name| "#{custom_base}/#{name}/" }
    end
    allow(Dir).to receive(:children) do |dir|
      if dir == custom_base
        @custom_files
      elsif dir == root
        @root_files
      elsif dir.start_with?("#{custom_base}/")
        @subdir_files[dir.sub("#{custom_base}/", '')]
      else
        []
      end
    end
    # Look up by normalized path so the string-interpolated "SCRIPT_DIR/file"
    # (which can produce a double slash) and a real absolute file_name resolve
    # to the same registered content.
    allow(File).to receive(:read) { |path| @contents.fetch(path.gsub(%r{/+}, '/')) }
  end

  # Registers a fake script. subdir: nil => SCRIPT_DIR root; :custom => custom/
  # root; any other string => custom/<subdir>/.
  def add_script(name, source, subdir: nil)
    case subdir
    when nil
      @root_files << "#{name}.lic"
      @contents["#{root}/#{name}.lic"] = source
    when :custom
      @custom_files << "#{name}.lic"
      @contents["#{custom_base}/#{name}.lic"] = source
    else
      @subdir_files[subdir.to_s] << "#{name}.lic"
      @contents["#{custom_base}/#{subdir}/#{name}.lic"] = source
    end
  end
  alias_method :stub_script, :add_script

  def header(*lines)
    (["=begin"] + lines + ["=end", "", "echo 'body'"]).join("\n")
  end

  # A fake running script whose file_name points at the given absolute path.
  def running_script(name, file_name)
    instance_double(script_class, name: name, file_name: file_name)
  end

  describe '.required_lich_version' do
    it 'parses a "required: Lich >= X.Y.Z" line from a =begin/=end header' do
      add_script('demo', header('  author: someone', '  required: Lich >= 5.15.0', '  version: 1.2.3'))

      expect(script_class.required_lich_version('demo')).to eq('5.15.0')
    end

    it 'parses the requirement from leading "#" comments when there is no =begin block' do
      add_script('hashdemo', "# required: Lich >= 5.9.0\n# version: 0.1\necho 'go'\n")

      expect(script_class.required_lich_version('hashdemo')).to eq('5.9.0')
    end

    it 'is case-insensitive on the "Lich" token and tolerant of extra spacing' do
      add_script('spaced', header("required:\tlich   >=    5.12.2"))

      expect(script_class.required_lich_version('spaced')).to eq('5.12.2')
    end

    it 'treats a bare ">" the same as a minimum floor' do
      add_script('gtonly', header('required: Lich > 5.0.1'))

      expect(script_class.required_lich_version('gtonly')).to eq('5.0.1')
    end

    it 'reads a no-operator "required: Lich X.Y.Z" declaration' do
      add_script('noop', header('required: Lich 4.3.12'))

      expect(script_class.required_lich_version('noop')).to eq('4.3.12')
    end

    it 'captures only the dotted-numeric run, dropping a stray suffix (5.0x -> 5.0)' do
      add_script('typo', header('required: Lich > 5.0x'))

      expect(script_class.required_lich_version('typo')).to eq('5.0')
    end

    it 'stops the version at a trailing dependency list (Lich 4.3.12, Olib)' do
      add_script('deps', header('required: Lich 4.3.12, Olib'))

      expect(script_class.required_lich_version('deps')).to eq('4.3.12')
    end

    it 'accepts a two-segment version (5.0)' do
      add_script('twoseg', header('required: Lich >= 5.0'))

      expect(script_class.required_lich_version('twoseg')).to eq('5.0')
    end

    it 'resolves a script in the custom/ root by name (one /custom/ prefix, no doubling)' do
      add_script('customroot', header('required: Lich >= 5.13.0'), subdir: :custom)

      expect(script_class.required_lich_version('customroot')).to eq('5.13.0')
    end

    it 'resolves a script living under custom/<subdir>/ by name' do
      add_script('subgated', header('required: Lich >= 5.17.1'), subdir: 'mypack')

      expect(script_class.required_lich_version('subgated')).to eq('5.17.1')
    end

    it 'does not double the /custom/ prefix when listing the custom root' do
      # Guards the test harness itself: real Dir.children yields bare child
      # names, and production prepends "/custom/". If the stub regressed to
      # returning pre-prefixed names, resolution would look for /custom/custom/.
      add_script('barecheck', header('required: Lich >= 5.0.0'), subdir: :custom)

      expect(Dir.children(custom_base)).to eq(['barecheck.lic'])
      expect(script_class.required_lich_version('barecheck')).to eq('5.0.0')
    end

    it 'returns nil when the script declares no requirement' do
      add_script('plain', header('author: nobody', 'version: 9.9.9'))

      expect(script_class.required_lich_version('plain')).to be_nil
    end

    it 'returns nil when the script file cannot be found' do
      expect(script_class.required_lich_version('does-not-exist')).to be_nil
    end

    it 'reads a gzip-compressed script header (gz-aware), not crashing on binary bytes' do
      dir = Dir.mktmpdir
      path = File.join(dir, 'gzscript.lic.gz')
      Zlib::GzipWriter.open(path) { |f| f.write(header('required: Lich >= 5.16.0')) }
      allow(script_class).to receive(:current).and_return(running_script('gzscript', path))

      expect(script_class.required_lich_version).to eq('5.16.0')
    ensure
      FileUtils.rm_rf(dir) if dir
    end

    it 'fails soft (no requirement) on a corrupt .gz rather than raising' do
      dir = Dir.mktmpdir
      path = File.join(dir, 'corrupt.lic.gz')
      # Gzip magic bytes then garbage (built from ASCII-only source).
      File.binwrite(path, [0x1f, 0x8b, 0x08].pack('C*') + ' not a valid gzip stream')
      allow(script_class).to receive(:current).and_return(running_script('corrupt', path))

      expect { script_class.required_lich_version }.not_to raise_error
      expect(script_class.required_lich_version).to be_nil
    ensure
      FileUtils.rm_rf(dir) if dir
    end

    it 'fails soft when a non-gz file holds invalid byte sequences (ArgumentError guard)' do
      path = "#{root}/binary.lic"
      # Invalid UTF-8 bytes, constructed from ASCII-only source via pack.
      @contents[path] = [0xff, 0xfe, 0x80, 0x81].pack('C*').force_encoding('UTF-8')
      allow(script_class).to receive(:current).and_return(running_script('binary', path))

      expect { script_class.required_lich_version }.not_to raise_error
      expect(script_class.required_lich_version).to be_nil
    end

    it 'fails soft (returns nil, no raise) when the file is transiently unreadable' do
      path = "#{root}/flaky.lic"
      @root_files << 'flaky.lic'
      allow(File).to receive(:read).with(path).and_raise(Errno::EACCES)

      expect { script_class.required_lich_version('flaky') }.not_to raise_error
      expect(script_class.required_lich_version('flaky')).to be_nil
    end

    it 'returns nil (without touching disk) when no current script is running' do
      allow(script_class).to receive(:current).and_return(nil)

      expect(script_class.required_lich_version).to be_nil
    end

    it 'reads the running script\'s own file directly when no name is given' do
      path = "#{custom_base}/mypack/runningsub.lic"
      @contents[path] = header('required: Lich >= 5.18.0')
      allow(script_class).to receive(:current).and_return(running_script('runningsub', path))

      expect(script_class.required_lich_version).to eq('5.18.0')
    end
  end

  describe '.lich_version_satisfied?' do
    it 'is true when LICH_VERSION exceeds the minimum' do
      stub_const('LICH_VERSION', '5.18.0')
      expect(script_class.lich_version_satisfied?('5.15.0')).to be true
    end

    it 'is true when LICH_VERSION exactly equals the minimum (boundary)' do
      stub_const('LICH_VERSION', '5.15.0')
      expect(script_class.lich_version_satisfied?('5.15.0')).to be true
    end

    it 'is false when LICH_VERSION is below the minimum' do
      stub_const('LICH_VERSION', '5.14.9')
      expect(script_class.lich_version_satisfied?('5.15.0')).to be false
    end

    it 'compares numerically, not lexically (5.9.0 < 5.10.0)' do
      stub_const('LICH_VERSION', '5.9.0')
      expect(script_class.lich_version_satisfied?('5.10.0')).to be false
    end

    it 'passes when no minimum is given or declared' do
      stub_const('LICH_VERSION', '5.0.0')
      expect(script_class.lich_version_satisfied?(nil)).to be true
      expect(script_class.lich_version_satisfied?('')).to be true
    end

    it 'treats an unparseable minimum as "no requirement" rather than raising' do
      stub_const('LICH_VERSION', '5.0.0')
      expect { script_class.lich_version_satisfied?('not-a-version') }.not_to raise_error
      expect(script_class.lich_version_satisfied?('not-a-version')).to be true
    end

    it 'reads the calling script\'s declared requirement by default' do
      stub_const('LICH_VERSION', '5.10.0')
      path = "#{root}/gated.lic"
      @contents[path] = header('required: Lich >= 5.15.0')
      allow(script_class).to receive(:current).and_return(running_script('gated', path))

      expect(script_class.lich_version_satisfied?).to be false
    end
  end

  describe '.require_lich_version!' do
    before { Lich::Messaging.clear_messages! if Lich::Messaging.respond_to?(:clear_messages!) }

    it 'returns true and emits nothing when the version is satisfied' do
      stub_const('LICH_VERSION', '5.18.0')
      allow(script_class).to receive(:current).and_return(nil)

      expect(script_class.require_lich_version!('5.15.0')).to be true
    end

    it 'returns false, warns, and exits the script when too old' do
      stub_const('LICH_VERSION', '5.10.0')
      current = running_script('oldgate', "#{root}/oldgate.lic")
      allow(script_class).to receive(:current).and_return(current)
      expect(current).to receive(:exit)

      expect(script_class.require_lich_version!('5.15.0')).to be false
    end

    it 'enforces a custom/<subdir>/ script\'s own declared floor (regression: no fail-open bypass)' do
      stub_const('LICH_VERSION', '5.10.0')
      path = "#{custom_base}/mypack/subguard.lic"
      @contents[path] = header('required: Lich >= 5.18.0')
      current = running_script('subguard', path)
      allow(script_class).to receive(:current).and_return(current)
      expect(current).to receive(:exit)

      # No explicit minimum: the floor must come from the running script's
      # own header, read via its file_name (not its lossy basename).
      expect(script_class.require_lich_version!).to be false
    end

    it 'includes the script name, required version, running version, and update link in the notice' do
      stub_const('LICH_VERSION', '5.10.0')
      current = running_script('oldgate', "#{root}/oldgate.lic")
      allow(script_class).to receive(:current).and_return(current)
      allow(current).to receive(:exit)

      emitted = []
      allow(Lich::Messaging).to receive(:msg) { |_type, text| emitted << text }

      script_class.require_lich_version!('5.15.0')

      joined = emitted.join("\n")
      expect(joined).to include('oldgate')
      expect(joined).to include('5.15.0+')
      expect(joined).to include('5.10.0')
      expect(joined).to include('gswiki.play.net')
    end

    it 'does not raise when there is no current script to exit' do
      stub_const('LICH_VERSION', '5.10.0')
      allow(script_class).to receive(:current).and_return(nil)
      allow(Lich::Messaging).to receive(:msg)

      expect { script_class.require_lich_version!('5.15.0') }.not_to raise_error
    end

    it 'stays non-fatal when the running script\'s header is unreadable (no raise, no exit)' do
      stub_const('LICH_VERSION', '5.10.0')
      path = "#{root}/flaky.lic"
      allow(File).to receive(:read).with(path).and_raise(Errno::EACCES)
      current = running_script('flaky', path)
      allow(script_class).to receive(:current).and_return(current)
      expect(current).not_to receive(:exit)

      # No explicit minimum: the floor would come from the unreadable header.
      # A read error must be treated as "no requirement" -> the guard passes.
      expect(script_class.require_lich_version!).to be true
    end
  end

  # Characterization of the refactored Script.version: behavior must be
  # unchanged by the extraction of the shared private helpers.
  describe '.version (characterization)' do
    it 'returns the parsed version as a Gem::Version when no requirement is passed' do
      add_script('verdemo', header('version: 2.9.4'))

      expect(script_class.version('verdemo')).to eq(Gem::Version.new('2.9.4'))
    end

    it 'strips a trailing parenthetical note from the version' do
      add_script('vernote', header('version: 1.0.0 (beta)'))

      expect(script_class.version('vernote')).to eq(Gem::Version.new('1.0.0'))
    end

    it 'defaults to 0.0.0 when no version header is present' do
      add_script('vermissing', header('author: nobody'))

      expect(script_class.version('vermissing')).to eq(Gem::Version.new('0.0.0'))
    end

    it 'returns true when the script version is older than the required version' do
      add_script('verold', header('version: 1.0.0'))

      expect(script_class.version('verold', '2.0.0')).to be true
    end

    it 'returns false when the script version meets the required version' do
      add_script('vernew', header('version: 2.0.0'))

      expect(script_class.version('vernew', '2.0.0')).to be false
    end

    it 'reports a missing script and returns nil' do
      allow(script_class).to receive(:respond)
      expect(script_class.version('ghost')).to be_nil
    end
  end
end
