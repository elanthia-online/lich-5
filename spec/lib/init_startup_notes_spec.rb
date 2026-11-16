# frozen_string_literal: true

require 'rspec'
require 'open3'
require 'json'
require 'rbconfig'

RSpec.describe 'init.rb startup notes flush' do
  # GemCheck queues notes for a start that continues; init.rb writes them to
  # the Lich debug log once that log is open. This pulls the real block, from
  # the `$stderr.sync` line up to the DATA_DIR check, out of init.rb and runs
  # it in a child process with the real GemCheck and Lich.log recorded.
  # Nothing is copied: a layout change that breaks extraction fails the spec.
  let(:harness) do
    <<~'RUBY'
      require 'json'
      init_path, lib_dir = ARGV
      require File.join(lib_dir, 'gemcheck.rb')
      LICH_VERSION = '0.0.0-spec'
      module Lich
        LOGGED = []
        def self.log(message) = LOGGED << message
      end
      Lich::GemCheck.note("info: Lich5 GemCheck recommended update\n  queued by GemCheck")
      source = File.read(init_path)
      block = source[/^\$stderr\.sync = true\n.*?(?=^unless File\.exist\?\(DATA_DIR\))/m] ||
              abort("could not extract the startup log block from #{init_path}")
      Object.new.instance_eval { binding }.eval(block, init_path)
      puts JSON.generate(logged: Lich::LOGGED, left: Lich::GemCheck.startup_notes)
    RUBY
  end

  let(:result) do
    lib_dir = File.expand_path('../../lib', __dir__)
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, '-e', harness, File.join(lib_dir, 'init.rb'), lib_dir)
    expect(status.success?).to be(true), stderr
    JSON.parse(stdout.lines.last)
  end

  it 'writes a queued GemCheck note to the Lich log after the info: Ruby lines' do
    logged = result.fetch('logged')
    ruby_line = logged.index("info: Ruby #{RUBY_VERSION}")
    note_line = logged.index { |line| line.start_with?('info: Lich5 GemCheck recommended update') }
    expect(ruby_line).not_to be_nil
    expect(note_line).not_to be_nil
    expect(note_line).to be > ruby_line
    expect(logged[note_line]).to include('queued by GemCheck')
  end

  it 'flushes the queue so the note is written once' do
    expect(result.fetch('left')).to eq([])
    expect(result.fetch('logged').count { |line| line.include?('queued by GemCheck') }).to eq(1)
  end
end
