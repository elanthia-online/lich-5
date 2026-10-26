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
end
