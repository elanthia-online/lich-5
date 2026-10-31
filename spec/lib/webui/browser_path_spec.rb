# frozen_string_literal: true

require_relative '../../spec_helper'
require 'tmpdir'
require 'webui/browser_launcher'

# A user-set browser path (for example Chromium) is accepted and launched with an
# isolated profile; a path that cannot run fails at open time with a message that
# names the setting. File tests only, so the examples hold on Windows as well.
RSpec.describe Lich::WebUI::BrowserLauncher, 'configured browser path' do
  let(:url) { "http://127.0.0.1:4567/auth?token=#{'f' * 64}&to=%2F" }
  let(:directory) { Dir.mktmpdir('webui-browser-path') }
  let(:logs) { [] }
  let(:failures) { [] }
  let(:chromium) do
    File.join(directory, 'chromium.exe').tap do |path|
      File.write(path, '')
      File.chmod(0o755, path)
    end
  end

  before { allow(Lich).to receive(:log) { |message| logs << message } }

  after { FileUtils.remove_entry(directory) if File.directory?(directory) }

  def open_with(**options)
    described_class.open(url, on_failure: ->(message) { failures << message },
                              thread_factory: ->(&work) { work.call }, waitpid: ->(_pid, _flags) {}, **options)
  end

  it 'launches a configured Chromium with an isolated profile and removes the profile after exit' do
    argv = nil
    profile = nil
    spawn = lambda do |*arguments, **_options|
      argv = arguments
      profile = arguments.find { |argument| argument.start_with?('--user-data-dir=') }.delete_prefix('--user-data-dir=')
      expect(File.directory?(profile)).to be(true)
      4242
    end

    expect(open_with(browser_path: chromium, platform: 'x86_64-linux', spawn: spawn)).to be(true)
    expect(argv.first).to eq(chromium)
    expect(argv).to include('--new-window', '--no-first-run', '--no-default-browser-check')
    expect(argv.last).to start_with('--app=file://')
    expect(File.exist?(profile)).to be(false)
    expect(failures).to be_empty
  end

  it 'refuses a browser path that does not exist, naming the setting, without spawning' do
    missing = File.join(directory, 'absent', 'chromium')
    expect(Dir).not_to receive(:mktmpdir)

    expect(open_with(browser_path: missing, platform: 'x86_64-linux', spawn: ->(*) { raise 'must not spawn' })).to be(false)
    expect(failures.size).to eq(1)
    expect(failures.first).to include('unable to open WebUI window', "'#{missing}' does not exist", 'Browser path', 'Settings')
    expect(failures.first).not_to include('ENOENT', 'Errno')
  end

  it 'refuses a browser path that is not an executable file, naming the setting' do
    plain = File.join(directory, 'notes.txt')
    File.write(plain, '')
    File.chmod(0o644, plain)

    [plain, directory].each do |path|
      failures.clear
      expect(open_with(browser_path: path, platform: 'x86_64-linux', spawn: ->(*) { raise 'must not spawn' })).to be(false)
      expect(failures.first).to include("'#{path}' is not an executable file", 'Browser path', 'Settings')
    end
  end

  it 'applies the same check to the legacy chrome_path alias' do
    missing = File.join(directory, 'absent')

    expect(open_with(chrome_path: missing, platform: 'x86_64-linux', spawn: ->(*) { raise 'must not spawn' })).to be(false)
    expect(failures.first).to include("'#{missing}' does not exist")
  end

  it 'does not echo control characters from the configured path' do
    expect(open_with(browser_path: "/nope/chro\nmium", platform: 'x86_64-linux', spawn: ->(*) {})).to be(false)
    expect(failures.first).to include("'/nope/chro?mium'")
    expect(failures.first).not_to include("\n")
  end

  it 'names the setting when automatic discovery finds no browser' do
    allow(File).to receive(:executable?).and_return(false)

    expect(open_with(platform: 'x86_64-linux', spawn: ->(*) { raise 'must not spawn' })).to be(false)
    expect(failures.first).to include('Google Chrome is required', 'Browser path', 'Settings')
  end

  it 'leaves automatic discovery unchanged when no path is set' do
    detected = '/usr/bin/google-chrome'
    allow(File).to receive(:executable?).and_call_original
    allow(File).to receive(:executable?).with(detected).and_return(true)
    argv = nil

    expect(open_with(platform: 'x86_64-linux', spawn: ->(*arguments, **) { (argv = arguments) && 7 })).to be(true)
    expect(argv.first).to eq(detected)
  end
end
