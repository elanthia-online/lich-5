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

  it 'loads the startup policy and recovery from the reviewed files alone' do
    Dir.mktmpdir do |dir|
      reviewed.each do |path|
        FileUtils.mkdir_p(File.join(dir, File.dirname(path)))
        FileUtils.cp(File.join(root, path), File.join(dir, path))
      end
      program = <<~'RUBY'
        require ARGV.fetch(0)
        p [defined?(Lich::StartupPolicyCompatibility), defined?(Lich::DependencyRecovery), defined?(Lich::AcceptedGemPolicy)]
      RUBY
      environment = { 'RUBYOPT' => nil, 'RUBYLIB' => nil, 'BUNDLER_SETUP' => nil, 'RUBYGEMS_GEMDEPS' => nil }
      output, error, status = Open3.capture3(environment, RbConfig.ruby, '-e', program, File.join(dir, 'lib/startup_policy_compatibility.rb'))
      expect(status).to be_success, error
      expect(output.strip).to eq('["constant", "constant", "constant"]')
    end
  end
end
