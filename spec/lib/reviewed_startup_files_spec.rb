# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require 'tmpdir'
require 'fileutils'
require_relative '../support/zip_builder'

# Ruby4Lich5 checks every supported lich-5 release by loading that release's
# startup policy from a pinned copy of only these files (plus lib/version.rb).
# Anything they load at require time must stay inside the set, or the
# Ruby4Lich5 promotion gate rejects every candidate with a LoadError.
RSpec.describe 'reviewed startup policy files' do
  reviewed = %w[
    lib/accepted_gem_policy.rb
    lib/dependency_recovery.rb
    lib/recovery_unit_policy.rb
    lib/runtime_gem_contract.rb
    lib/startup_policy_compatibility.rb
    lib/version.rb
  ].freeze
  root = File.expand_path('../..', __dir__)

  # Runs +program+ in a clean Ruby with ARGV[0] naming the copied
  # startup_policy_compatibility.rb, from a directory holding only the
  # reviewed files.
  # @return [Array(String, String, Process::Status)]
  # @yieldparam dir [String] the copy, to change before the program runs
  # @param parent [String, nil] a directory name to run the copy under, for
  #   paths with characters a pattern would have to escape
  def run_reviewed(reviewed, root, program, parent: nil)
    Dir.mktmpdir do |tmp|
      dir = parent ? File.join(tmp, parent) : tmp
      reviewed.each do |path|
        FileUtils.mkdir_p(File.join(dir, File.dirname(path)))
        FileUtils.cp(File.join(root, path), File.join(dir, path))
      end
      yield dir if block_given?
      environment = { 'RUBYOPT' => nil, 'RUBYLIB' => nil, 'BUNDLER_SETUP' => nil, 'RUBYGEMS_GEMDEPS' => nil }
      Open3.capture3(environment, RbConfig.ruby, '-e', program, File.join(dir, 'lib/startup_policy_compatibility.rb'), dir)
    end
  end

  it 'loads the startup policy and recovery from the reviewed files alone' do
    program = <<~'RUBY'
      require ARGV.fetch(0)
      p [defined?(Lich::StartupPolicyCompatibility), defined?(Lich::DependencyRecovery), defined?(Lich::AcceptedGemPolicy)]
    RUBY
    output, error, status = run_reviewed(reviewed, root, program)
    expect(status).to be_success, error
    expect(output.strip).to eq('["constant", "constant", "constant"]')
  end

  # Lich::Archive is loaded only when recovery extracts a bundle. Should it
  # ever be missing, the failure must name the missing file and stay a
  # recovery Error: a LoadError is not a StandardError, so it would escape
  # #recover's boot guard and GemCheck, and crash a windowless rubyw Lich.
  it 'reports a missing Lich::Archive as a recovery Error naming the file' do
    program = <<~'RUBY'
      require ARGV.fetch(0)
      begin
        Lich::DependencyRecovery.allocate.send(:extract_zip_file, File.join(ARGV.fetch(1), 'bundle.zip'), File.join(ARGV.fetch(1), 'packages'))
      rescue Exception => e # rubocop:disable Lint/RescueException
        puts e.class
        puts e.message
      end
    RUBY
    output, error, status = run_reviewed(reviewed, root, program)
    expect(status).to be_success, error
    raised, message = output.lines(chomp: true)
    expect(raised).to eq('Lich::DependencyRecovery::Error')
    expect(message).to start_with('Recovery cannot extract archives: lib/archive.rb is missing')
  end

  extract_program = <<~'RUBY'
    require ARGV.fetch(0)
    begin
      Lich::DependencyRecovery.allocate.send(:extract_zip_file, File.join(ARGV.fetch(1), 'bundle.zip'), File.join(ARGV.fetch(1), 'packages'))
      puts 'extracted'
      puts Dir.glob('**/*', base: File.join(ARGV.fetch(1), 'packages')).sort
    rescue Exception => e # rubocop:disable Lint/RescueException
      puts e.class
      puts e.message
    end
  RUBY

  # Ruby4Lich5's recovery smoke extracts a real bundle from its sealed copy,
  # which adds the archive reader to the reviewed files. Its
  # bin/seal_contract_source.rb picks the reader's files with this pattern;
  # keep the two in step.
  reader_pattern = %r{\Alib/(zip_archive\.rb|archive\.rb|archive/[A-Za-z0-9_]+\.rb)\z}
  tracked_reader = lambda do
    listed, = Open3.capture2('git', '-C', root, 'ls-files', '--', 'lib/zip_archive.rb', 'lib/archive.rb', 'lib/archive')
    listed.lines(chomp: true)
  end

  it 'keeps every archive reader file where the sealed copy picks it up' do
    files = tracked_reader.call
    expect(files).not_to be_empty
    expect(files.grep_v(reader_pattern)).to eq([])
  end

  it 'extracts a bundle from the reviewed files plus the archive reader alone' do
    reader = tracked_reader.call.grep(reader_pattern)
    output, error, status = run_reviewed(reviewed + reader, root, extract_program) do |dir|
      File.binwrite(File.join(dir, 'bundle.zip'), ZipBuilder.build([{ name: 'a.gem', data: 'gem' }, { name: 'dir/b.gem', data: 'other', method: :store }]))
    end
    expect(status).to be_success, error
    expect(output.lines(chomp: true)).to eq(%w[extracted a.gem dir dir/b.gem])
  end

  # A reader cut short on disk, for example by an interrupted update, raises
  # SyntaxError, which is no more a StandardError than LoadError is.
  it 'reports a truncated archive reader as a recovery Error naming the file' do
    reader = tracked_reader.call.grep(reader_pattern)
    output, error, status = run_reviewed(reviewed + reader, root, extract_program) do |dir|
      path = File.join(dir, 'lib/archive.rb')
      File.binwrite(path, File.binread(path, 3000))
    end
    expect(status).to be_success, error
    raised, message = output.lines(chomp: true)
    expect(raised).to eq('Lich::DependencyRecovery::Error')
    expect(message).to start_with('Recovery cannot extract archives: lib/archive.rb cannot be loaded (SyntaxError: ')
  end

  # Lich is often installed under a directory such as "Program Files (x86)",
  # whose characters a path pattern must escape.
  windows_parent = 'Lich (x86)+ [1]'

  # Cut mid-word, the reader raises NameError as it loads instead.
  %w[lib/archive.rb lib/archive/zip.rb lib/archive/tar_gz.rb].each do |cut|
    it "reports #{cut} cut mid-word as a recovery Error naming that file" do
      reader = tracked_reader.call.grep(reader_pattern)
      output, error, status = run_reviewed(reviewed + reader, root, extract_program, parent: windows_parent) do |dir|
        path = File.join(dir, cut)
        source = File.binread(path)
        File.binwrite(path, source.byteslice(0, source.index("\nmodule ") + 6))
      end
      expect(status).to be_success, error
      raised, message = output.lines(chomp: true)
      expect(raised).to eq('Lich::DependencyRecovery::Error')
      expect(message).to start_with("Recovery cannot extract archives: #{cut} cannot be loaded (NameError: ")
    end
  end

  # An interrupted copy can also leave a reader file empty, or cut at a line
  # boundary before its module is defined; that loads without error.
  {
    'lib/archive.rb'     => 'an empty archive facade',
    'lib/archive/zip.rb' => 'an empty ZIP reader'
  }.each do |emptied, label|
    it "reports #{label} as a recovery Error naming #{emptied}" do
      reader = tracked_reader.call.grep(reader_pattern)
      output, error, status = run_reviewed(reviewed + reader, root, extract_program) do |dir|
        File.binwrite(File.join(dir, emptied), '')
      end
      expect(status).to be_success, error
      raised, message = output.lines(chomp: true)
      expect(raised).to eq('Lich::DependencyRecovery::Error')
      expect(message).to eq("Recovery cannot extract archives: #{emptied} loaded but does not define the archive reader")
    end
  end

  # Cut just before it loads the formats, the facade defines Archive but
  # not Archive::Zip.
  it 'names the archive facade when it stops before loading the ZIP reader' do
    reader = tracked_reader.call.grep(reader_pattern)
    output, error, status = run_reviewed(reviewed + reader, root, extract_program) do |dir|
      path = File.join(dir, 'lib/archive.rb')
      source = File.binread(path)
      File.binwrite(path, source.byteslice(0, source.index("require_relative 'archive/zip'")))
    end
    expect(status).to be_success, error
    expect(output.lines(chomp: true).last).to eq('Recovery cannot extract archives: lib/archive.rb loaded but does not define the archive reader')
  end

  # An error from a gem the reader calls as it loads has the gem's file as
  # its first frame; the reader file is the one named.
  it 'names the reader file when it raises inside a gem as it loads' do
    reader = tracked_reader.call.grep(reader_pattern)
    output, error, status = run_reviewed(reviewed + reader, root, extract_program, parent: windows_parent) do |dir|
      path = File.join(dir, 'lib/archive/zip.rb')
      File.binwrite(path, File.binread(path).sub("require 'zlib'\n", "require 'zlib'\nFileUtils.mkdir_p(nil)\n"))
    end
    expect(status).to be_success, error
    raised, message = output.lines(chomp: true)
    expect(raised).to eq('Lich::DependencyRecovery::Error')
    expect(message).to start_with('Recovery cannot extract archives: lib/archive/zip.rb cannot be loaded (TypeError: ')
  end

  # The loader itself raises for an unknown encoding comment, so no frame is
  # in a reader file; the message carries its path.
  it 'names the reader file when the loader refuses it' do
    reader = tracked_reader.call.grep(reader_pattern)
    output, error, status = run_reviewed(reviewed + reader, root, extract_program, parent: windows_parent) do |dir|
      path = File.join(dir, 'lib/archive/zip.rb')
      File.binwrite(path, File.binread(path).sub('# frozen_string_literal: true', '# encoding: bogus'))
    end
    expect(status).to be_success, error
    raised, message = output.lines(chomp: true)
    expect(raised).to eq('Lich::DependencyRecovery::Error')
    expect(message).to start_with('Recovery cannot extract archives: lib/archive/zip.rb cannot be loaded (ArgumentError: ')
  end
end
