# frozen_string_literal: true

require 'rspec'
require 'tmpdir'

# lib/main/argv_options.rb pulls a heavy require chain and auto-executes
# ArgvOptions.process_argv at load time, so it cannot be required in isolation.
# To exercise SideEffects.handle_hosts_dir without booting the whole ARGV
# pipeline, lift the real method body out of the source file and eval it into a
# lightweight harness. Extracting from source (rather than duplicating the
# logic here) keeps this spec bound to the shipping code and guards drift.
RSpec.describe 'Lich::Main::ArgvOptions::SideEffects.handle_hosts_dir' do
  source_path = File.expand_path('../../../lib/main/argv_options.rb', __dir__)

  harness_class = Class.new do
    source = File.read(source_path)
    method_body = source[/^(?<ind>[ \t]*)def self\.handle_hosts_dir\(argv_options\).*?^\k<ind>end$/m]
    raise 'could not extract handle_hosts_dir from argv_options.rb' unless method_body

    # Rebind as an instance method on the harness (drop the `self.`).
    module_eval(method_body.sub('def self.handle_hosts_dir', 'def handle_hosts_dir'))
  end

  let(:harness) { harness_class.new }
  let(:argv_options) { {} }

  around do |example|
    original_argv = ARGV.dup
    begin
      example.run
    ensure
      ARGV.replace(original_argv)
    end
  end

  def set_argv(*args)
    ARGV.replace(args)
  end

  it 'parses the equals form and records a normalized directory' do
    Dir.mktmpdir do |dir|
      set_argv("--hosts-dir=#{dir}")

      harness.handle_hosts_dir(argv_options)

      expect(argv_options[:hosts_dir]).to eq("#{dir}/")
      expect(ARGV).not_to include("--hosts-dir=#{dir}")
    end
  end

  it 'does not append a second trailing slash when one is already present' do
    Dir.mktmpdir do |dir|
      set_argv("--hosts-dir=#{dir}/")

      harness.handle_hosts_dir(argv_options)

      expect(argv_options[:hosts_dir]).to eq("#{dir}/")
    end
  end

  it 'warns and records nothing when the directory does not exist' do
    missing = File.join(Dir.tmpdir, "lich-missing-hosts-#{Process.pid}")
    set_argv("--hosts-dir=#{missing}")

    expect { harness.handle_hosts_dir(argv_options) }
      .to output(/does not exist: #{Regexp.escape(missing)}/).to_stdout

    expect(argv_options).not_to have_key(:hosts_dir)
    expect(ARGV).not_to include("--hosts-dir=#{missing}")
  end

  it 'ignores the legacy space-separated form (regression guard for the equals switch)' do
    Dir.mktmpdir do |dir|
      set_argv('--hosts-dir', dir)

      harness.handle_hosts_dir(argv_options)

      expect(argv_options).not_to have_key(:hosts_dir)
      # Neither token matches the equals form, so ARGV is left untouched.
      expect(ARGV).to eq(['--hosts-dir', dir])
    end
  end
end
