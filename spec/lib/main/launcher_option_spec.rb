# frozen_string_literal: true

require_relative '../../spec_helper'

# lib/main/argv_options.rb auto-executes ArgvOptions.process_argv at load
# time, so it cannot be required in isolation. As spec/lib/main/argv_options_spec.rb
# does, lift OptionParser.execute out of the source and eval it into a harness
# so the switches are exercised through the real parser rather than by grepping
# for their `when` lines.
RSpec.describe 'the launcher switches' do
  source_path = File.join(LIB_DIR, 'main', 'argv_options.rb')

  parser_class = Class.new do
    source = File.read(source_path)
    method_body = source[/^(?<ind>[ \t]*)def self\.execute$.*?^\k<ind>end$/m]
    raise 'could not extract OptionParser.execute from argv_options.rb' unless method_body

    module_eval(method_body.sub('def self.execute', 'def execute'))
  end

  around do |example|
    original_argv = ARGV.dup
    begin
      example.run
    ensure
      ARGV.replace(original_argv)
    end
  end

  it 'recognises --webui, its --webui-dev alias, and --gtk without touching the GTK switches' do
    { '--webui' => :webui, '--webui-dev' => :webui, '--gtk' => :gtk }.each do |switch, choice|
      ARGV.replace([switch])

      options = parser_class.new.execute

      expect(options[:launcher]).to eq(choice), "#{switch} should set launcher to #{choice}"
      expect(options).not_to have_key(:gui)
      expect(options).not_to have_key(:webui_dev)
    end
  end

  it 'leaves argv_options without a launcher when no switch is given' do
    ARGV.replace(['--gui'])

    expect(parser_class.new.execute).not_to have_key(:launcher)
  end

  it 'reads the one resolved choice at every site instead of re-deriving a flag' do
    # main.rb and lich.rbw run their startup sequences at load time, so the
    # branch order cannot be exercised behaviourally here; the source is the
    # observable fact. What matters is that no site inspects ARGV or a
    # webui_dev option of its own: they all ask Lich.launcher.
    main = File.read(File.join(LIB_DIR, 'main', 'main.rb'))
    init = File.read(File.join(LIB_DIR, 'init.rb'))
    entrypoint = File.read(File.expand_path('../../../lich.rbw', __dir__))

    webui_branch = main.index('elsif Lich.launcher == :webui')
    gtk_branch = main.index('elsif defined?(Gtk)')
    expect(webui_branch).to be_a(Integer)
    expect(gtk_branch).to be_a(Integer)
    expect(webui_branch).to be < gtk_branch
    expect(main).to include("require File.join(LIB_DIR, 'common', 'gui_login.rb')")
    expect(main).to include('if Lich.launcher == :webui').twice
    expect(init).to include("require File.join(LIB_DIR, 'common', 'launcher_choice.rb')")
    expect(init).to include('elsif Lich.launcher == :webui')
    expect(entrypoint).to include('if defined?(Gtk) && Lich.launcher == :gtk')
    expect([main, init, entrypoint].join).not_to include('webui_dev')
  end

  it 'loads gtk3 only when the launcher is GTK' do
    init = File.read(File.join(LIB_DIR, 'init.rb'))
    gtk_require = init.index("require 'gtk3'")
    webui_branch = init.index('elsif Lich.launcher == :webui')

    expect(webui_branch).to be < gtk_require
    expect(init).to match(/elsif Lich\.launcher == :webui\n\s+HAVE_GTK = false/)
  end

  it 'does not falsify GTK availability from the launcher or introduce a shim dependency' do
    launcher = File.read(File.join(LIB_DIR, 'common', 'webui_launcher.rb'))
    main = File.read(File.join(LIB_DIR, 'main', 'main.rb'))

    expect([launcher, main].join("\n")).not_to match(/HAVE_GTK\s*=\s*false/)
    expect(launcher).not_to include('script_scope/gtk')
    expect(launcher).not_to match(/\bGtk(?:::|\.)/)
  end

  it 'ends the Ruby startup path after a launcher-only browser close' do
    main = File.read(File.join(LIB_DIR, 'main', 'main.rb'))
    browser = File.read(File.join(LIB_DIR, 'webui', 'assets', 'app.js'))
    entrypoint = File.read(File.expand_path('../../../lich.rbw', __dir__))

    expect(browser).to include('window.addEventListener("pagehide", detachPages)')
    expect(browser).to include('type: "detach", page: page.address, generation: page.generation')
    # Comment lines may sit between the two statements.
    expect(main).to match(/@launch_data = webui_launcher\.start\.await_launch\n(?:[ \t]*#.*\n)*[ \t]*next unless @launch_data/)
    expect(entrypoint).to include("else\n  @main_thread.join\nend")
  end
end
