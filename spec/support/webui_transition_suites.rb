# frozen_string_literal: true

require 'rbconfig'
require 'fileutils'

# Test-only transition isolation: the script shim installs a process-wide loader
# guard, while legacy GTK specs load the old GTK hardening file and GUI stubs.
# Retirement: P22 removes native GTK code/tests and global GUI stubs. In that same
# package, delete this runner, restore the ordinary full-suite workflow command,
# and require the combined suite to pass before the cutover is accepted.
module WebUITransitionSuites
  # Assigns every discovered example file to exactly one process family.
  # @param paths [Array<String>] repository-relative RSpec file paths
  # @return [Hash{Symbol => Array<String>}] disjoint, exhaustive groups
  def self.partition(paths)
    paths.group_by do |path|
      if path.start_with?('spec/lib/common/script_scope_') ||
         %w[spec/lib/webui/browser_integration_spec.rb spec/lib/webui/tab_remapping_spec.rb].include?(path)
        :compatibility
      elsif path.start_with?('spec/lib/common/webui_launcher')
        :launcher
      elsif path.start_with?('spec/lib/webui/')
        :native
      else
        :legacy
      end
    end
  end

  # Runs each nonempty family in a fresh parallel_tests parent process.
  # @param seed [String] numeric RSpec seed
  # @return [Boolean] true only when every discovered group succeeds
  def self.run(seed)
    raise ArgumentError, 'numeric seed required' unless seed.match?(/\A[0-9]+\z/)

    paths = Dir['spec/**/*_spec.rb'].sort
    raise 'no specs discovered' if paths.empty?

    groups = partition(paths)
    flattened = groups.values.flatten
    unless flattened.sort == paths && flattened.uniq.length == paths.length
      raise 'transition partition omitted or duplicated a spec'
    end

    runtime_log = 'tmp/parallel_runtime_rspec.log'
    history = read_runtime_log(runtime_log)
    results = groups.map do |name, files|
      puts "RSpec #{name}: #{files.length} files; seed #{seed}"
      begin
        system(RbConfig.ruby, '-S', 'parallel_rspec', '-n', '4',
               '--serialize-stdout', '--verbose-rerun-command',
               '-o', "--seed #{seed}", *files)
      ensure
        # RuntimeLogger replaces the log for each process family. Retain the
        # other families so the next invocation can use all recorded timings.
        history.merge!(read_runtime_log(runtime_log))
        FileUtils.mkdir_p(File.dirname(runtime_log))
        File.write(runtime_log, history.sort.map { |path, time| "#{path}:#{time}\n" }.join)
      end
    end
    results.all?
  end

  # Preserve runtime rows by spec path, updating only measurements just written.
  # @param path [String] parallel_tests runtime log path
  # @return [Hash{String => String}] recorded per-file runtimes
  def self.read_runtime_log(path)
    return {} unless File.file?(path)

    File.readlines(path, chomp: true).each_with_object({}) do |line, rows|
      file, separator, time = line.rpartition(':')
      rows[file] = time unless separator.empty?
    end
  end
end

if $PROGRAM_NAME == __FILE__
  Dir.chdir(File.expand_path('../..', __dir__)) do
    exit(WebUITransitionSuites.run(ARGV.fetch(0)) ? 0 : 1)
  end
end
