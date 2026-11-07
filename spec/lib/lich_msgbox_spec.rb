# frozen_string_literal: true

require 'rspec'
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

  # Non-Windows errors reach a desktop launch through the GemCheck alert helpers
  # (1853:RC4@S7). The helper is a recording stub here: no real dialog is ever shown.
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
