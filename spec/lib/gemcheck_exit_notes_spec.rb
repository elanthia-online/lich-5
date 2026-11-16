# frozen_string_literal: true

require 'rspec'
require 'open3'
require 'rbconfig'
require 'tmpdir'

RSpec.describe 'GemCheck notes on a start that stops before init.rb flushes them' do
  # Runs the real exit hook in a child process: GemCheck queues a note, the
  # hook is registered as lich.rbw registers it, and the process then ends
  # the way a start can end between GemCheck and init.rb's flush.
  let(:harness) do
    <<~'RUBY'
      lib_dir, temp_dir, ending = ARGV
      TEMP_DIR = temp_dir
      require File.join(lib_dir, 'gemcheck.rb')
      Lich::GemCheck.define_singleton_method(:required_dependencies) { |_groups| [] }
      Lich::GemCheck.keep_unflushed_notes_at_exit([:default])
      Lich::GemCheck.keep_unflushed_notes_at_exit([:default])
      Lich::GemCheck.note("info: Lich5 GemCheck recommended update\n  queued by GemCheck")
      case ending
      when 'raise' then raise LoadError, 'cannot load such file -- ox'
      when 'exit' then exit
      when 'flushed'
        Lich::GemCheck.flush_startup_notes { |_message| nil }
        exit
      end
    RUBY
  end

  def run_start(ending)
    Dir.mktmpdir('lich-exit-notes') do |dir|
      Open3.capture3(RbConfig.ruby, '-e', harness, File.expand_path('../../lib', __dir__), dir, ending)
      log = File.join(dir, 'lich5-missing-gems.log')
      return File.exist?(log) ? File.read(log) : nil
    end
  end

  it 'writes the queued note and the exception when an uncaught error ends the start' do
    log = run_start('raise')
    expect(log).to include('Lich5 GemCheck start stopped before the Lich log opened')
    expect(log).to include("  Noted earlier in this start:\n    info: Lich5 GemCheck recommended update\n      queued by GemCheck")
    expect(log).to include('Class:   LoadError', 'cannot load such file -- ox')
    expect(log.scan('queued by GemCheck').length).to eq(1)
  end

  it 'writes the queued note without an error entry when the start exits early' do
    log = run_start('exit')
    expect(log).to include('queued by GemCheck')
    expect(log).not_to include('Underlying error')
  end

  it 'writes nothing once init.rb has flushed the notes' do
    expect(run_start('flushed')).to be_nil
  end

  it 'is registered by lich.rbw right after the startup gem check' do
    source = File.read(File.expand_path('../../lich.rbw', __dir__))
    verify = source.index('Lich::GemCheck.verify!(')
    hook = source.index('Lich::GemCheck.keep_unflushed_notes_at_exit')
    expect(verify).not_to be_nil
    expect(hook).not_to be_nil
    expect(source[verify...hook]).not_to match(/^require /)
  end
end
