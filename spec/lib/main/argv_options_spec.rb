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

RSpec.describe 'Lich::Main::ArgvOptions::SideEffects.handle_sentinel' do
  source_path = File.expand_path('../../../lib/main/argv_options.rb', __dir__)

  harness_class = Class.new do
    source = File.read(source_path)
    method_body = source[/^(?<ind>[ \t]*)def self\.handle_sentinel\(argv_options\).*?^\k<ind>end$/m]
    raise 'could not extract handle_sentinel from argv_options.rb' unless method_body

    module_eval(method_body.sub('def self.handle_sentinel', 'def handle_sentinel'))
  end

  let(:harness) { harness_class.new }
  let(:frontend) { Module.new { singleton_class.send(:attr_accessor, :sentinel_requested) } }

  before { stub_const('Lich::Common::Frontend', frontend) }

  it 'requests the origin sentinel when --sentinel was parsed' do
    harness.handle_sentinel({ sentinel: true })

    expect(frontend.sentinel_requested).to be true
  end

  it 'leaves the sentinel alone without the flag' do
    harness.handle_sentinel({})

    expect(frontend.sentinel_requested).to be_nil
  end

  it 'parses --sentinel into the option the side effect reads' do
    expect(File.read(source_path)).to match(/^[ \t]*when \/\^--sentinel\$\/i\r?\n[ \t]*@argv_options\[:sentinel\] = true/)
  end
end

require_relative '../../../lib/common/client_capabilities'

# announce logs as well as printing; run alone, this file has no Lich.log.
module Lich
  def self.log(_msg); end
end unless Lich.respond_to?(:log)

RSpec.describe 'Lich::Main::ArgvOptions --frontend-caps' do
  source_path = File.expand_path('../../../lib/main/argv_options.rb', __dir__)
  source = File.read(source_path)

  harness_class = Class.new do
    %w[handle_frontend_caps announce].each do |name|
      method_body = source[/^(?<ind>[ \t]*)def self\.#{name}\(.*?^\k<ind>end$/m]
      raise "could not extract #{name} from argv_options.rb" unless method_body

      module_eval(method_body.sub("def self.#{name}", "def #{name}"))
    end
  end

  parser = Module.new do
    body = source[/^(?<ind>[ \t]*)module OptionParser\n(?<body>.*?)^\k<ind>end$/m, :body]
    raise 'could not extract OptionParser from argv_options.rb' unless body

    module_eval(body)
  end

  let(:harness) { harness_class.new }
  let(:capabilities) { Lich::Common::ClientCapabilities }

  around do |example|
    saved = [ARGV.dup, capabilities.launch_capabilities, $frontend]
    begin
      example.run
    ensure
      ARGV.replace(saved[0])
      capabilities.launch_capabilities = saved[1]
      $frontend = saved[2]
    end
  end

  before { allow(Lich).to receive(:log) }

  it 'parses the flag into the option the side effect reads' do
    ARGV.replace(['--frontend-caps=game_links,double_bold'])
    expect(parser.execute[:frontend_caps]).to eq('game_links,double_bold')
  end

  it 'parses an empty list too' do
    ARGV.replace(['--frontend-caps='])
    expect(parser.execute[:frontend_caps]).to eq('')
  end

  it 'sets the launch set every undeclared client gets' do
    harness.handle_frontend_caps({ frontend_caps: 'double_bold,room_element' })
    expect(capabilities.launch_capabilities).to eq(%i[room_element double_bold])
  end

  it 'sets the empty set for an empty list' do
    harness.handle_frontend_caps({ frontend_caps: '' })
    expect(capabilities.launch_capabilities).to eq([])
  end

  it 'warns about names it does not know and keeps the rest' do
    expect { harness.handle_frontend_caps({ frontend_caps: 'game_links,sparkles' }) }
      .to output(/warning: --frontend-caps: ignoring unknown capabilities: sparkles/).to_stdout
    expect(capabilities.launch_capabilities).to eq([:game_links])
  end

  it 'leaves the catalog default in place without the flag' do
    capabilities.launch_capabilities = nil
    harness.handle_frontend_caps({})
    expect(capabilities.launch_capabilities).to be_nil
  end
end
