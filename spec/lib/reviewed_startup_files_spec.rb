# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require 'tmpdir'
require 'fileutils'

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
  def run_reviewed(reviewed, root, program)
    Dir.mktmpdir do |dir|
      reviewed.each do |path|
        FileUtils.mkdir_p(File.join(dir, File.dirname(path)))
        FileUtils.cp(File.join(root, path), File.join(dir, path))
      end
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
end
