# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

RSpec.describe Lich::WebUI::BrowserLauncher do
  %w[darwin mingw linux].each do |platform|
    it "keeps launch credentials off #{platform} process arguments" do
      allow(File).to receive(:executable?).and_return(true)
      url = 'http://127.0.0.1:1234/auth?token=synthetic-launch-secret&to=%2F'
      arguments = nil
      result = described_class.open(url, platform: platform,
                                    browser_path: platform == 'darwin' ? nil : '/test/browser',
                                    spawn: ->(*argv, **_options) { arguments = argv; 42 },
                                    on_exit: proc {}, waitpid: ->(*) {}, thread_factory: ->(&work) { work.call })
      expect(result).to be(true)
      expect(arguments.join(' ')).not_to include('synthetic-launch-secret')
    end
  end

  it 'selects the native macOS helper through OS.mac? and monitors it without a Chrome profile' do
    allow(OS).to receive(:mac?).and_return(true)
    allow(File).to receive(:executable?).with(Lich::WebUI::NativeHost::EXECUTABLE).and_return(true)
    calls = []
    contents = []
    started = []
    exited = []
    result = described_class.open('http://127.0.0.1:1234/', geometry: { width: 500, height: 350 },
                                  spawn: ->(*argv, **_options) { calls << argv; contents << File.read(argv[1]); 42 },
                                  on_start: ->(pid) { started << pid }, on_exit: -> { exited << true },
                                  waitpid: ->(pid, _flags) { pid }, thread_factory: ->(&work) { work.call })
    expect(result).to be(true)
    expect(calls.first).to match([Lich::WebUI::NativeHost::EXECUTABLE, a_string_ending_with('/launch.url'), '{"width":500,"height":350}'])
    expect(contents).to eq(['http://127.0.0.1:1234/'])
    expect(File.exist?(File.dirname(calls.first[1]))).to be(false)
    expect(started).to eq([42])
    expect(exited).to eq([true])
  end

  it 'reports a missing native helper without silently opening Chrome' do
    allow(OS).to receive(:mac?).and_return(true)
    allow(File).to receive(:executable?).with(Lich::WebUI::NativeHost::EXECUTABLE).and_return(false)
    expect(described_class).not_to receive(:app_browser_path)
    expect { described_class.command_for('http://127.0.0.1:1234/') }.to raise_error(Lich::WebUI::Error, /helper is missing/)
  end

  it 'uses ordinary platform discovery off macOS without needing the native helper' do
    allow(OS).to receive(:mac?).and_return(false)
    allow(OS).to receive(:windows?).and_return(false)
    allow(OS).to receive(:host_os).and_return('linux')
    allow(described_class).to receive(:app_browser_path).with(platform: 'linux').and_return('/usr/bin/google-chrome')
    expect(Lich::WebUI::NativeHost).not_to receive(:command_for)
    expect(described_class.command_for('http://127.0.0.1/')).to eq(
      ['/usr/bin/google-chrome', '--new-window', '--app=http://127.0.0.1/']
    )
  end

  it 'isolates and reaps a browser even without an exit callback' do
    calls = []
    launch_file = nil
    spawn = lambda do |*arguments, **options|
      calls << [arguments, options]
      launch_file = URI::DEFAULT_PARSER.unescape(URI(arguments.last.delete_prefix('--app=')).path).sub(%r{\A/(?=[A-Za-z]:/)}, '')
      expect(File.read(launch_file)).to include('token=x&amp;to=%2F')
      unless OS.windows?
        expect(File.stat(launch_file).mode & 0o777).to eq(0o600)
        expect(File.stat(File.dirname(launch_file)).mode & 0o777).to eq(0o700)
      end
      42
    end
    waited = []

    expect(described_class.open('http://127.0.0.1:1234/auth?token=x&to=%2F', spawn: spawn,
                                waitpid: ->(pid, _flags) { waited << pid }, thread_factory: ->(&work) { work.call },
                                platform: 'darwin', browser_path: '/Applications/Google Chrome')).to be(true)
    expect(calls.first.first).to include('/Applications/Google Chrome', '--new-window', a_string_starting_with('--user-data-dir='))
    expect(calls.first.last).to eq(out: File::NULL, err: File::NULL)
    expect(waited).to eq([42])
    expect(File.exist?(File.dirname(launch_file))).to be(false)
  end

  it 'owns and monitors an isolated app process when an exit callback is supplied' do
    calls = []
    waited = []
    started = []
    exited = []
    profile = nil
    spawn = lambda do |*arguments, **options|
      calls << [arguments, options]
      profile = arguments.find { |argument| argument.start_with?('--user-data-dir=') }.split('=', 2).last
      73
    end

    expect(described_class.open(
             'http://127.0.0.1:1234/', spawn: spawn,
             platform: 'darwin', browser_path: '/Applications/Google Chrome', on_exit: -> { exited << true },
             on_start: ->(pid) { started << pid }, waitpid: ->(pid, flags) { waited << [pid, flags]; pid },
             thread_factory: ->(&work) { work.call }
           )).to be(true)
    expect(calls.first.first).to include(
      "--user-data-dir=#{profile}", '--no-first-run', '--no-default-browser-check'
    )
    expect(started).to eq([73])
    expect(waited).to eq([[73, 0]])
    expect(exited).to eq([true])
    expect(File.exist?(profile)).to be(false)
  end

  it 'still reports exit and removes its profile when the child was already reaped' do
    exited = []
    profile = nil
    spawn = lambda do |*arguments, **_options|
      profile = arguments.find { |argument| argument.start_with?('--user-data-dir=') }.split('=', 2).last
      74
    end

    expect(described_class.open(
             'http://127.0.0.1:1234/', spawn: spawn, platform: 'darwin',
             browser_path: '/Applications/Google Chrome', on_exit: -> { exited << true },
             waitpid: ->(*) { raise Errno::ECHILD }, thread_factory: ->(&work) { work.call }
           )).to be(true)
    expect(exited).to eq([true])
    expect(File.exist?(profile)).to be(false)
  end

  it 'discovers Google Chrome without considering Chromium or a generic browser opener' do
    executable = lambda do |path|
      path == '/usr/bin/google-chrome-stable'
    end

    expect(described_class.google_chrome_path(platform: 'linux', executable: executable))
      .to eq('/usr/bin/google-chrome-stable')
    expect(described_class.chrome_candidates(platform: 'linux'))
      .not_to include('/usr/bin/chromium', '/usr/bin/xdg-open')
  end

  it 'builds the conventional Windows Google Chrome candidates' do
    environment = {
      'PROGRAMFILES'      => 'C:/Program Files',
      'PROGRAMFILES(X86)' => 'C:/Program Files (x86)',
      'LOCALAPPDATA'      => 'C:/Users/example/AppData/Local',
    }

    expect(described_class.chrome_candidates(platform: 'mingw', environment: environment)).to eq([
                                                                                                   'C:/Program Files/Google/Chrome/Application/chrome.exe',
                                                                                                   'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
                                                                                                   'C:/Users/example/AppData/Local/Google/Chrome/Application/chrome.exe',
                                                                                                 ])
  end

  it 'passes saved size and position to the app window without a shell' do
    command = described_class.command_for(
      'http://127.0.0.1/', platform: 'darwin', browser_path: '/Applications/Google Chrome',
      geometry: { width: 960, height: 720, position: [-120, 48] }
    )

    expect(command).to eq([
                            '/Applications/Google Chrome', '--new-window', '--window-size=960,720',
                            '--window-position=-120,48', '--app=http://127.0.0.1/'
                          ])
  end

  it 'passes a default size when no prior position exists' do
    expect(described_class.geometry_arguments(width: 840, height: 680, position: nil))
      .to eq(['--window-size=840,680'])
  end

  it 'prefers Google Chrome and falls back to Microsoft Edge on Windows' do
    environment = {
      'PROGRAMFILES'      => 'C:/Program Files',
      'PROGRAMFILES(X86)' => 'C:/Program Files (x86)',
      'LOCALAPPDATA'      => 'C:/Users/example/AppData/Local',
    }
    edge = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'

    expect(described_class.app_browser_path(platform: 'mingw', environment: environment,
                                            executable: ->(path) { path == edge })).to eq(edge)

    chrome = 'C:/Users/example/AppData/Local/Google/Chrome/Application/chrome.exe'
    available = [edge, chrome]
    expect(described_class.app_browser_path(platform: 'mingw', environment: environment,
                                            executable: ->(path) { available.include?(path) })).to eq(chrome)
  end

  it 'does not consider Microsoft Edge outside Windows' do
    expect(described_class.app_browser_path(platform: 'darwin', executable: ->(*) { false })).to be_nil
    expect(described_class.chrome_candidates(platform: 'darwin')).not_to include(/Microsoft Edge/)
  end

  it 'raises when Google Chrome is not installed' do
    allow(described_class).to receive(:app_browser_path).with(platform: 'linux').and_return(nil)

    expect do
      described_class.command_for('http://127.0.0.1/', platform: 'linux')
    end.to raise_error(Lich::WebUI::Error, /Google Chrome is required/)
  end

  it 'opens Windows app windows with Chrome or Edge and an isolated profile' do
    allow(described_class).to receive(:app_browser_path).with(platform: 'mingw').and_return('C:/Edge/msedge.exe')
    calls = []
    described_class.open('http://127.0.0.1/', platform: 'mingw',
                         spawn: ->(*argv, **_options) { calls << argv; 42 }, on_exit: proc {},
                         waitpid: ->(*) {}, thread_factory: ->(&work) { work.call })
    expect(calls.first.first).to eq('C:/Edge/msedge.exe')
    expect(calls.first).to include(a_string_starting_with('--user-data-dir='))
    expect(calls.first.last).to start_with('--app=file:///')
  end

  it 'reports failure without exposing or executing the URL through a shell' do
    directory = nil
    messages = []
    allow(Lich).to receive(:log) { |message| messages << message }
    spawn = lambda do |*argv, **_options|
      directory = argv.find { |value| value.start_with?('--user-data-dir=') }.split('=', 2).last
      raise Errno::ENOENT, 'synthetic-private-error'
    end
    expect(described_class.open('http://127.0.0.1/', spawn: spawn, platform: 'darwin',
                                browser_path: '/Applications/Google Chrome')).to be(false)
    expect(File.exist?(directory)).to be(false)
    expect(messages.join).not_to include('synthetic-private-error')
  end

  it 'encodes special characters in the private bootstrap path' do
    Dir.mktmpdir('launch space-#-') do |directory|
      target = described_class.launch_file('http://127.0.0.1/', directory, native: nil)
      expect(URI(target).fragment).to be_nil
      path = URI::DEFAULT_PARSER.unescape(URI(target).path).sub(%r{\A/(?=[A-Za-z]:/)}, '')
      expect(File.read(path)).to include('url=http://127.0.0.1/')
    end
  end
end
