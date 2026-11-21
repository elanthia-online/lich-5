# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'optparse'
require 'tmpdir'
require_relative '../../lib/common/script'

module Lich
  # Copies the default scripts from elanthia-online/scripts into a release
  # package, choosing for each one the newest version on the branch that the
  # Lich being packaged can run.
  #
  # A script may declare a minimum Lich version in its header
  # ("required: Lich >= X.Y.Z"). Each script's history on the branch is walked
  # newest first and the first version whose floor the release meets is
  # bundled, so a script with no floor comes from the branch tip. The walk
  # follows first parents only: it visits the versions the branch itself has
  # held, not intermediate commits of a merged branch.
  #
  # The floor is read and compared by Script.required_lich_version_in and
  # Script.lich_version_satisfied?, the calls the login script sync makes, so a
  # bundled script is one that sync would also accept.
  #
  # Nothing is written, and the run fails, when a script is missing at the
  # branch tip or no version of it runs on the release.
  module DefaultScriptBundle
    class Error < StandardError; end

    DEFAULT_REPO = 'https://github.com/elanthia-online/scripts.git'
    DEFAULT_BRANCH = 'master'
    DEFAULT_SCRIPTS = %w[
      alias.lic autostart.lic ewaggle.lic go2.lic jinx.lic lich5-update.lic
      log.lic map.lic repository.lic vars.lic version.lic
    ].freeze
    # Directory inside the scripts repository that holds the scripts.
    SOURCE_DIR = 'scripts'

    Pick = Struct.new(:name, :commit, :floor, :content, :skipped)

    # The release being built is the version recorded in the packaged tree.
    # The file is read as text, not loaded: loading it runs its Ruby-version
    # check, which exits the process on an older interpreter.
    def self.release_version(lich_root)
      path = File.join(lich_root, 'lib', 'version.rb')
      raise Error, "#{path} not found; cannot tell which Lich version is being packaged" unless File.file?(path)
      version = File.binread(path)[/^LICH_VERSION = '([^']+)'/, 1]
      raise Error, "#{path} does not declare a usable LICH_VERSION" unless version && Gem::Version.correct?(version)
      version
    end

    def self.git(*args, git_dir: nil)
      command = ['git']
      command.push('--git-dir', git_dir) if git_dir
      output, error, status = Open3.capture3({ 'GIT_TERMINAL_PROMPT' => '0' }, *command, *args, binmode: true)
      raise Error, "git #{args.join(' ')} failed: #{error.strip}" unless status.success?
      output
    end

    # Full history of the one branch, no working tree. A shallow clone would
    # hide the older versions the walk may need.
    def self.clone(repo, branch, git_dir)
      git('clone', '--quiet', '--bare', '--single-branch', '--no-tags', '--branch', branch, repo, git_dir)
      git('rev-parse', '--verify', "refs/heads/#{branch}^{commit}", git_dir: git_dir).strip
    end

    # The blob id of path at commit, or nil when the commit has no such file.
    def self.blob_at(git_dir, commit, path)
      entry = git('ls-tree', commit, '--', path, git_dir: git_dir)
      entry[/\A\d+ blob ([0-9a-f]+)\t/, 1]
    end

    def self.pick(git_dir, tip, name)
      path = "#{SOURCE_DIR}/#{name}"
      raise Error, "#{name}: #{path} is missing at the branch tip (#{tip})" unless blob_at(git_dir, tip, path)

      skipped = []
      git('rev-list', '--first-parent', tip, '--', path, git_dir: git_dir).split.each do |commit|
        blob = blob_at(git_dir, commit, path)
        next unless blob # a commit that removed the file
        content = git('cat-file', 'blob', blob, git_dir: git_dir)
        floor = Lich::Common::Script.required_lich_version_in(content)
        return Pick.new(name, commit, floor, content, skipped) if Lich::Common::Script.lich_version_satisfied?(floor)
        skipped << floor
      end
      raise Error, "#{name}: no history found for #{path}" if skipped.empty?
      lowest = skipped.min_by { |floor| Gem::Version.new(floor) }
      raise Error, "#{name}: none of the #{skipped.size} version(s) on the branch runs on Lich #{LICH_VERSION} " \
                   "(lowest floor: Lich >= #{lowest})"
    end

    def self.describe(pick)
      line = "#{pick.name}: commit #{pick.commit}, floor #{pick.floor ? "Lich >= #{pick.floor}" : 'none'}"
      return line if pick.skipped.empty?
      "#{line} (held back: branch tip needs Lich >= #{pick.skipped.first}, #{pick.skipped.size} newer version(s) skipped)"
    end

    def self.parse(argv)
      options = { lich_root: '.', repo: DEFAULT_REPO, branch: DEFAULT_BRANCH }
      parser = OptionParser.new do |opts|
        opts.banner = 'Usage: bundle_default_scripts.rb --dest DIR [options] [SCRIPT.lic ...]'
        opts.on('--dest DIR', 'Directory the chosen scripts are written to') { |value| options[:dest] = value }
        opts.on('--lich-root DIR', 'Lich tree being packaged; its lib/version.rb names the release (default: .)') { |value| options[:lich_root] = value }
        opts.on('--repo URL', "Scripts repository to read (default: #{DEFAULT_REPO})") { |value| options[:repo] = value }
        opts.on('--branch NAME', "Branch whose history is walked (default: #{DEFAULT_BRANCH})") { |value| options[:branch] = value }
      end
      names = parser.parse(argv)
      raise Error, '--dest is required (see --help)' unless options[:dest]
      options.merge(names: names.empty? ? DEFAULT_SCRIPTS : names)
    rescue OptionParser::ParseError => e
      raise Error, "#{e.message} (see --help)"
    end

    def self.run(argv)
      options = parse(argv)
      # Script.lich_version_satisfied? compares against this constant.
      Object.const_set(:LICH_VERSION, release_version(options[:lich_root]))

      Dir.mktmpdir('default-scripts') do |tmp|
        git_dir = File.join(tmp, 'scripts.git')
        tip = clone(options[:repo], options[:branch], git_dir)
        puts "Bundling default scripts for Lich #{LICH_VERSION} from #{options[:repo]} (#{options[:branch]} at #{tip})"

        failures = []
        picks = options[:names].filter_map do |name|
          pick(git_dir, tip, name)
        rescue Error => e
          failures << e.message
          nil
        end
        raise Error, failures.join("\n") unless failures.empty?

        FileUtils.mkdir_p(options[:dest])
        picks.each do |pick|
          File.binwrite(File.join(options[:dest], pick.name), pick.content)
          puts "  #{describe(pick)}"
        end
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  $stdout.sync = true
  begin
    Lich::DefaultScriptBundle.run(ARGV)
  rescue Lich::DefaultScriptBundle::Error => e
    e.message.each_line { |line| warn "::error::#{line.chomp}" }
    exit 1
  end
end
