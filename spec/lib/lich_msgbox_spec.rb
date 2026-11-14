# frozen_string_literal: true

require 'rspec'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

RSpec.describe 'Lich.msgbox without a graphical toolkit' do
  it 'reports bootstrap errors on stderr without loading GTK' do
    source = <<~'SOURCE'
      LICH_VERSION = 'test'
      require ARGV[0]
      puts Lich.msgbox(message: 'Unavailable frontend').inspect
      abort 'GTK loaded' if defined?(Gtk)
    SOURCE
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby, '-e', source, File.expand_path('../../lib/lich.rb', __dir__)
    )

    expect(status.success?).to be(true), stderr
    expect(stdout.strip).to eq('nil')
    expect(stderr.strip).to eq('Unavailable frontend')
  end

  %w[open closed broken_pipe].each do |terminal|
    it "retains logged errors with #{terminal} terminal output and no game-client writes" do
      source = <<~'SOURCE'
        require 'stringio'
        LICH_VERSION = 'test'
        require ARGV[0]
        $stdout = StringIO.new
        if ARGV[2] == 'closed'
          STDOUT.close
        elsif ARGV[2] == 'broken_pipe'
          reader, writer = IO.pipe
          reader.close
          STDOUT.reopen(writer)
          writer.close
        end
        File.open(ARGV[1], 'w') do |log|
          $stderr = log
          result = Lich.msgbox(message: 'Unavailable frontend: synthetic detail')
          abort 'unexpected dialog response' unless result.nil?
          abort 'notice sent to game client' unless $stdout.string.empty?
          abort 'GTK loaded' if defined?(Gtk)
        end
        $stderr = STDERR
      SOURCE
      Dir.mktmpdir('lich-msgbox') do |directory|
        log_path = File.join(directory, 'debug.log')
        stdout, stderr, status = Open3.capture3(
          RbConfig.ruby, '-e', source, File.expand_path('../../lib/lich.rb', __dir__), log_path, terminal
        )

        expect(status.success?).to be(true), stderr
        expect(stderr).to be_empty
        expect(File.read(log_path)).to eq("Unavailable frontend: synthetic detail\n")
        if terminal == 'open'
          expect(stdout).to eq("Lich encountered an error. See the debug log: #{log_path}\n")
        else
          expect(stdout).to be_empty
        end
      end
    end
  end

  it 'reports a bare string on stderr without loading GTK' do
    source = <<~'SOURCE'
      LICH_VERSION = 'test'
      require ARGV[0]
      puts Lich.msgbox('Unavailable frontend').inspect
      abort 'GTK loaded' if defined?(Gtk)
    SOURCE
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby, '-e', source, File.expand_path('../../lib/lich.rb', __dir__)
    )
    expect(status.success?).to be(true), stderr
    expect(stdout.strip).to eq('nil')
    expect(stderr.strip).to eq('Unavailable frontend')
  end

  # Non-Windows errors reach a desktop launch through the GemCheck alert helpers.
  # The helper is a recording stub here: no real dialog is ever shown.
  describe 'with no terminal attached' do
    def run_msgbox(setup, call)
      source = <<~SOURCE
        LICH_VERSION = 'test'
        require ARGV[0]
        #{setup}
        puts "result=\#{#{call}.inspect}"
      SOURCE
      Open3.capture3(RbConfig.ruby, '-e', source, File.expand_path('../../lib/lich.rb', __dir__))
    end

    let(:recording_helper) do
      <<~'SETUP'
        module Lich; module GemCheck
          def self.show_notice(body, title:) = puts("notice title=#{title} body=#{body}")
        end; end
      SETUP
    end

    it 'shows an error through the helper and keeps the terminal message and result' do
      stdout, stderr, status = run_msgbox(recording_helper, "Lich.msgbox(message: 'Startup failed', icon: :error)")

      expect(status.success?).to be(true), stderr
      expect(stdout).to eq("notice title=Lich vtest body=Startup failed\nresult=nil\n")
      expect(stderr.strip).to eq('Startup failed')
    end

    it 'uses one Windows notification and retains fatal exit, log and cleanup on desktop launch' do
      setup = <<~'SETUP'
        require 'json'
        require File.expand_path('main/webui_startup', File.dirname(ARGV[0]))
        module Win32
          MB_OKCANCEL = 1
          MB_YESNO = 2
          MB_OK = 0
          MB_ICONERROR = 16
          MB_ICONQUESTION = 32
          MB_ICONWARNING = 48
          IDIOK = 1
          IDICANCEL = 2
          IDIYES = 6
          IDINO = 7
          def self.MessageBox(**) = ($dialogs += 1; IDIOK)
        end
        module Lich; module GemCheck
          def self.show_notice(*) = ($helper_notices += 1)
        end; end
        $dialogs = $helper_notices = 0
        STDOUT.define_singleton_method(:isatty) { false }
        STDERR.define_singleton_method(:isatty) { false }
        logs = []
        Lich.define_singleton_method(:log) { |message| logs << message }
        launcher = Object.new
        launcher.define_singleton_method(:start) do
          # The launcher's default recovery notifier uses this native message box.
          Lich.msgbox(message: 'host failed', icon: :warning)
          self
        end
        launcher.define_singleton_method(:await_launch) { nil }
        launcher.define_singleton_method(:failure) { 'host failed' }
        launcher.define_singleton_method(:close_at_exit) { @closed = true }
        begin
          Lich::Main::WebUIStartup.await(launcher)
        rescue SystemExit => error
          puts JSON.generate(dialogs: $dialogs, helpers: $helper_notices, exit: error.status,
                             logs: logs, closed: launcher.instance_variable_get(:@closed))
        end
      SETUP
      stdout, stderr, status = run_msgbox(setup, 'nil')

      expect(status.success?).to be(true), stderr
      expect(JSON.parse(stdout.lines.first)).to eq(
        'dialogs' => 1, 'helpers' => 0, 'exit' => 1,
        'logs' => ['error: host failed'], 'closed' => true
      )
    end

    it 'passes an explicit title to the helper' do
      stdout, = run_msgbox(recording_helper, "Lich.msgbox(message: 'Startup failed', title: 'Custom', icon: :error)")

      expect(stdout).to include('notice title=Custom body=Startup failed')
    end

    it 'does not call the helper for a message that is not an error' do
      stdout, stderr, status = run_msgbox(recording_helper, "Lich.msgbox(message: 'Heads up', icon: :warning)")

      expect(status.success?).to be(true), stderr
      expect(stdout).to eq("result=nil\n")
      expect(stderr.strip).to eq('Heads up')
    end

    it 'does not call the helper when stdout or stderr is a terminal' do
      %w[STDOUT STDERR].each do |stream|
        setup = "#{recording_helper}\n#{stream}.define_singleton_method(:isatty) { true }"
        stdout, stderr, status = run_msgbox(setup, "Lich.msgbox(message: 'Startup failed', icon: :error)")

        expect(status.success?).to be(true), stderr
        expect(stdout).to eq("result=nil\n")
        expect(stderr.strip).to eq('Startup failed')
      end
    end

    it 'falls back to the terminal and log output when no helper is loaded' do
      stdout, stderr, status = run_msgbox('', "Lich.msgbox(message: 'Startup failed', icon: :error)")

      expect(status.success?).to be(true), stderr
      expect(stdout).to eq("result=nil\n")
      expect(stderr.strip).to eq('Startup failed')
    end

    it 'falls back to the terminal and log output when the helper fails' do
      setup = 'module Lich; module GemCheck; def self.show_notice(*, **) = raise(IOError, "no display"); end; end'
      stdout, stderr, status = run_msgbox(setup, "Lich.msgbox(message: 'Startup failed', icon: :error)")

      expect(status.success?).to be(true), stderr
      expect(stdout).to eq("result=nil\n")
      expect(stderr.strip).to eq('Startup failed')
    end
  end
end
