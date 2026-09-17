# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require 'tmpdir'
require 'fileutils'
require_relative '../../spec_helper'
require_relative '../../../script/ci/check_core_gtk_boundary'

# The core/GTK boundary check is a warning while lib/common/gui/ still
# exists: it reports which core files still name the GTK runtime and exits
# 0. The allowlist below is exactly the set this layer still permits; a new
# file naming Gtk/Gdk/GLib (or requiring lib/common/gui) fails this spec.
RSpec.describe 'script/ci/check_core_gtk_boundary.rb' do
  let(:repo_root) { File.expand_path('../../..', __dir__) }
  let(:script) { File.join(repo_root, 'script/ci/check_core_gtk_boundary.rb') }

  # Every core file outside lib/common/gui/ that still names GTK.
  # lib/common/authentication/*, lib/common/cli/*, lib/common/webui_launcher/*,
  # lib/util/memoryreleaser.rb and lib/gemstone/combat/async_processor.rb are
  # deliberately absent: that is what this layer moved.
  let(:allowed_gtk_naming_core_files) do
    %w[
      lib/common/authentication/gui.rb
      lib/common/frontend.rb
      lib/common/gtk.rb
      lib/common/gui_login.rb
      lib/common/launcher_choice.rb
      lib/gemcheck.rb
      lib/init.rb
      lib/lich.rb
      lib/main/argv_options.rb
      lib/main/main.rb
      lib/main/startup_theme.rb
      lib/util/gtk_compaction.rb
      lich.rbw
    ]
  end

  it 'names exactly the core files this layer still permits to reach GTK' do
    expect(LichCoreGtkBoundary.files(repo_root)).to eq(allowed_gtk_naming_core_files)
  end

  it 'reports no GTK naming from the moved authentication, CLI and catalog files' do
    files = LichCoreGtkBoundary.files(repo_root)

    expect(files.grep(%r{^lib/common/authentication/(?!gui\.rb)})).to be_empty
    expect(files.grep(%r{^lib/common/cli/})).to be_empty
    expect(files.grep(%r{^lib/common/webui_launcher})).to be_empty
    expect(files).not_to include('lib/util/memoryreleaser.rb', 'lib/gemstone/combat/async_processor.rb')
  end

  it 'warns and exits 0 while lib/common/gui/ still exists' do
    output, status = Open3.capture2e(RbConfig.ruby, script, repo_root)

    expect(status).to be_success
    expect(output).to start_with('warning: GTK runtime idiom outside')
    expect(output).to include('lib/common/gtk.rb (')
  end

  context 'in a tree without the GTK launcher' do
    around do |example|
      Dir.mktmpdir('core-gtk-boundary') do |dir|
        @root = dir
        example.run
      end
    end

    it 'fails on a GTK constant in core' do
      FileUtils.mkdir_p(File.join(@root, 'lib'))
      File.write(File.join(@root, 'lib', 'violation.rb'), 'G' + "tk.main\n")

      output, status = Open3.capture2e(RbConfig.ruby, script, @root)

      expect(status).not_to be_success
      expect(output).to include('error:')
      expect(output).to include('lib/violation.rb (1)')
    end

    it 'fails on a require of the GTK launcher directory' do
      FileUtils.mkdir_p(File.join(@root, 'lib'))
      File.write(File.join(@root, 'lib', 'violation.rb'), "require_relative 'common/g" + "ui/state'\n")

      _output, status = Open3.capture2e(RbConfig.ruby, script, @root)

      expect(status).not_to be_success
    end

    it 'ignores GTK named only in comments' do
      FileUtils.mkdir_p(File.join(@root, 'lib'))
      File.write(File.join(@root, 'lib', 'clean.rb'), "# G" + "tk is not loaded here\nmodule Clean; end\n")

      output, status = Open3.capture2e(RbConfig.ruby, script, @root)

      expect(status).to be_success
      expect(output).to include('core names no GTK runtime idiom')
    end

    it 'permits GTK inside the script-scope shim directory' do
      directory = File.join(@root, 'lib', 'common', 'script_scope', 'gtk')
      FileUtils.mkdir_p(directory)
      File.write(File.join(directory, 'allowed.rb'), 'G' + "tk.main\n")

      _output, status = Open3.capture2e(RbConfig.ruby, script, @root)

      expect(status).to be_success
    end

    it 'fails with --strict even while lib/common/gui/ exists' do
      FileUtils.mkdir_p(File.join(@root, 'lib', 'common', 'gui'))
      File.write(File.join(@root, 'lib', 'violation.rb'), 'G' + "tk.main\n")

      _lenient, lenient_status = Open3.capture2e(RbConfig.ruby, script, @root)
      _strict, strict_status = Open3.capture2e(RbConfig.ruby, script, '--strict', @root)

      expect(lenient_status).to be_success
      expect(strict_status).not_to be_success
    end
  end
end
