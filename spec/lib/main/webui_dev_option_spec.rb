# frozen_string_literal: true

require_relative '../../spec_helper'

RSpec.describe 'WebUI development entry' do
  it 'parses the explicit development switch without changing the GTK default' do
    source = File.read(File.join(LIB_DIR, 'main', 'argv_options.rb'))
    main = File.read(File.join(LIB_DIR, 'main', 'main.rb'))

    expect(source).to include("when /^--webui-dev$/i")
    webui_branch = main.index('elsif @argv_options[:webui_dev]')
    gtk_branch = main.index('elsif defined?(Gtk)')
    expect(webui_branch).to be_a(Integer)
    expect(gtk_branch).to be_a(Integer)
    expect(webui_branch).to be < gtk_branch
    expect(main).to include("require File.join(LIB_DIR, 'common', 'gui_login.rb')")
    expect(main).to include("@launch_data = webui_launcher.start.await_launch\n    next unless @launch_data")
  end

  it 'does not falsify GTK availability or introduce a shim dependency' do
    sources = [
      File.read(File.join(LIB_DIR, 'common', 'webui_launcher.rb')),
      File.read(File.join(LIB_DIR, 'main', 'main.rb')),
    ].join("\n")

    expect(sources).not_to match(/HAVE_GTK\s*=\s*false/)
    launcher = File.read(File.join(LIB_DIR, 'common', 'webui_launcher.rb'))
    expect(launcher).not_to include('script_scope/gtk')
    expect(launcher).not_to match(/\bGtk(?:::|\.)/)
  end

  it 'ends the Ruby startup path after a launcher-only browser close' do
    main = File.read(File.join(LIB_DIR, 'main', 'main.rb'))
    browser = File.read(File.join(LIB_DIR, 'webui', 'assets', 'app.js'))
    entrypoint = File.read(File.expand_path('../../../lich.rbw', __dir__))

    expect(browser).to include('window.addEventListener("pagehide", detachPages)')
    expect(browser).to include('type: "detach", page: page.address, generation: page.generation')
    expect(main).to include("@launch_data = webui_launcher.start.await_launch\n    next unless @launch_data")
    expect(entrypoint).to include('if defined?(Gtk) && !@argv_options[:webui_dev]')
    expect(entrypoint).to include("else\n  @main_thread.join\nend")
  end
end
