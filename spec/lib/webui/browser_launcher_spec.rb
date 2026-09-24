# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

RSpec.describe Lich::WebUI::BrowserLauncher do
  it 'opens macOS URLs in a new Google Chrome app window without invoking a shell' do
    calls = []
    spawn = lambda do |*arguments, **options|
      calls << [arguments, options]
      42
    end
    detached = []

    expect(described_class.open('http://127.0.0.1:1234/auth?token=x', spawn: spawn,
                                                                      detach: ->(pid) { detached << pid },
                                                                      platform: 'darwin',
                                                                      browser_path: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')).to be(true)
    expect(calls).to eq([[['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
                           '--new-window', '--app=http://127.0.0.1:1234/auth?token=x'],
                          { out: File::NULL, err: File::NULL }]])
    expect(detached).to eq([42])
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
             'http://127.0.0.1:1234/', spawn: spawn, detach: ->(*) { raise 'must not detach' },
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

  it 'raises a Windows-specific error when neither Chrome nor Edge is installed' do
    allow(described_class).to receive(:app_browser_path).with(platform: 'mingw').and_return(nil)

    expect do
      described_class.command_for('http://127.0.0.1/', platform: 'mingw')
    end.to raise_error(Lich::WebUI::Error, /Google Chrome or Microsoft Edge is required/)
  end

  it 'reports failure without exposing or executing the URL through a shell' do
    expect(described_class.open('http://127.0.0.1/', spawn: ->(*) { raise Errno::ENOENT },
                                                     detach: ->(*) {}, platform: 'darwin',
                                                     browser_path: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')).to be(false)
  end
end
