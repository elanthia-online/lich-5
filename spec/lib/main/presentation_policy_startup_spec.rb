# frozen_string_literal: true

require_relative '../../spec_helper'
require 'open3'
require 'rbconfig'

RSpec.describe 'WebUI presentation policy at startup' do
  let(:root) { File.expand_path('../../..', __dir__) }
  let(:entrypoint) { File.read(File.expand_path('../../../lich.rbw', __dir__)) }

  it 'records the policy from resolved launch options before the main program starts' do
    parsed = entrypoint.index("require File.join(LIB_DIR, 'main', 'argv_options.rb')")
    policy = entrypoint.index('Lich::WebUI.configure_presentation(enabled: @argv_options[:gui] != false)')
    started = entrypoint.index("require File.join(LIB_DIR, 'main', 'main.rb')")
    expect([parsed, policy, started]).to all(be_a(Integer))
    expect(parsed).to be < policy
    expect(policy).to be < started
  end

  it 'records the policy before anything can activate the script scope, which fixes HAVE_GTK' do
    policy = entrypoint.index('Lich::WebUI.configure_presentation(')
    prefix = entrypoint[0...policy]
    expect(prefix).not_to match(/ScriptScope|TRUSTED_SCRIPT_BINDING|Scripting\.new|Script\.start|Script\.run/)
    lib = File.expand_path('../../../lib', __dir__)
    callers = Dir[File.join(lib, '**', '*.rb')].select { |path| File.read(path).match?(/ScriptScope\.activate!/) }
    expect(callers.map { |path| path.delete_prefix("#{lib}/") }).to eq(['common/script.rb'])
  end

  # The shipping pieces, lifted from their source files rather than restated here:
  # the ARGV normalization and option parser from lib/main/argv_options.rb, and the
  # policy statement from lich.rbw. HAVE_GTK is fixed at the script scope's first
  # activation, so every ARGV needs its own process.
  def have_gtk_for(*argv)
    source = <<~'RUBY'
      root = Dir.pwd
      lib = File.join(root, 'lib')
      require File.join(lib, 'webui')
      require File.join(lib, 'common', 'script')
      require File.join(lib, 'main', 'arg_normalization')
      parser = File.read(File.join(lib, 'main', 'argv_options.rb'))[/^      module OptionParser\n.*?^      end\n/m]
      statement = File.read(File.join(root, 'lich.rbw'))[/^Lich::WebUI\.configure_presentation\(.*\)$/]
      abort 'option parser not found in argv_options.rb' unless parser
      abort 'presentation policy statement not found in lich.rbw' unless statement
      eval("module Lich; module Main; module ArgvOptions\n#{parser}\nend; end; end", TOPLEVEL_BINDING, 'argv_options.rb')
      Lich::Main::ArgNormalization.normalize!(ARGV)
      @argv_options = Lich::Main::ArgvOptions::OptionParser.execute
      eval(statement, TOPLEVEL_BINDING, 'lich.rbw')
      values = [Lich::Common::TRUSTED_SCRIPT_BINDING.call, Lich::Common::Scripting.new.script].map { |scope| eval('HAVE_GTK', scope) }
      print values.uniq.inspect
    RUBY
    output, errors, status = Open3.capture3(RbConfig.ruby, '-e', source, '--', *argv, chdir: root)
    expect(status).to be_success, errors
    output
  end

  it 'gives scripts HAVE_GTK true for no presentation option and for --gui' do
    expect(have_gtk_for).to eq('[true]')
    expect(have_gtk_for('--gui')).to eq('[true]')
    expect(have_gtk_for('--reconnect', '--game=GS3')).to eq('[true]')
  end

  it 'gives scripts HAVE_GTK false for --no-gui and its legacy --no-gtk alias' do
    expect(have_gtk_for('--no-gui')).to eq('[false]')
    expect(have_gtk_for('--no-gtk')).to eq('[false]')
    expect(have_gtk_for('--NO-GUI')).to eq('[false]')
    expect(have_gtk_for('--reconnect', '--no-gtk', '--game=GS3')).to eq('[false]')
  end
end
