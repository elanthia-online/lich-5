# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'
require 'tmpdir'

# Lich::Genie::LogFile: Remix Utility/Log.cs (R), the target of `#log`.
RSpec.describe Lich::Genie::LogFile do
  around { |example| Dir.mktmpdir('genie-log') { |dir| @dir = dir; example.run } }

  let(:now) { Time.new(2026, 1, 2, 15, 4, 5) }
  let(:nnbsp) { [0x202F].pack('U') }

  it 'LogText: <char><game>_<yyyy-MM-dd>.log, a header on a new file, the text as given after' do
    expect(described_class.log_text("one\r\n", character: 'Tester', instance: 'DR', dir: @dir, now: now)).to be(true)
    expect(described_class.log_text("two\r\n", character: 'Tester', instance: 'DR', dir: @dir, now: now)).to be(true)
    expect(File.binread(File.join(@dir, 'TesterDR_2026-01-02.log')).force_encoding('UTF-8'))
      .to eq("*** LOG CREATED AT 1/2/2026 3:04:05#{nnbsp}PM ***\r\n\r\none\r\ntwo\r\n")
  end

  it 'LogText writes nothing without a character name' do
    expect(described_class.log_text('x', character: '', instance: 'DR', dir: @dir, now: now)).to be(false)
    expect(Dir.children(@dir)).to eq([])
  end

  it 'LogLine appends a line to a file under the dir, or to a path holding a backslash' do
    described_class.log_line('a,b', file_name: 'automappertest.csv', dir: @dir)
    described_class.log_line('c', file_name: 'automappertest.csv', dir: @dir)
    expect(File.binread(File.join(@dir, 'automappertest.csv'))).to eq("a,b\r\nc\r\n")
    Dir.mkdir(File.join(@dir, 'sub'))
    target = File.join(@dir, 'sub', 'x.log').tr('/', '\\')
    expect(described_class.log_line('d', file_name: target, dir: '/nowhere')).to be(true)
    expect(File.binread(File.join(@dir, 'sub', 'x.log'))).to eq("d\r\n")
    expect(Dir.exist?('/nowhere')).to be(false) # a path of its own: the log dir is not touched
  end

  # StreamWriter does not create folders (Log.cs:36, 75 R); only the log dir
  # itself exists (Remix creates Logs at startup, FormMain.cs:2458 R).
  it 'creates the log dir but no other folder, and reports a failed write to on_error' do
    errors = []
    logs = File.join(@dir, 'Logs')
    expect(described_class.log_line('x', file_name: 'f.log', dir: logs)).to be(true)
    expect(described_class.log_line('y', file_name: 'deep/f.log', dir: logs, on_error: ->(*e) { errors << e })).to be(false)
    target = File.join(@dir, 'gone', 'x.log').tr('/', '\\')
    expect(described_class.log_line('z', file_name: target, dir: logs, on_error: ->(*e) { errors << e })).to be(false)
    expect(errors.map(&:first)).to eq(%w[LogLine LogLine])
    expect([Dir.exist?(File.join(logs, 'deep')), Dir.exist?(File.join(@dir, 'gone'))]).to eq([false, false])
    File.write(File.join(@dir, 'blocker'), '')
    expect(described_class.log_text('t', character: 'C', instance: 'DR', dir: File.join(@dir, 'blocker'), now: now,
                                         on_error: ->(*e) { errors << e })).to be(false)
    expect(errors.last.first).to eq('LogText')
  end

  it 'swallows a write failure and an on_error that raises' do
    File.write(File.join(@dir, 'blocker'), '')
    expect(described_class.log_line('x', file_name: 'f', dir: File.join(@dir, 'blocker'))).to be(false)
    expect(described_class.log_line('x', file_name: 'f', dir: File.join(@dir, 'blocker'), on_error: ->(*) { raise 'x' })).to be(false)
  end

  # The new-file test and the header write are one step under the lock.
  it 'writes the LOG CREATED header once when two threads start the file together' do
    # the first thread's new-file test waits (up to 0.5 s) for a second thread to make the same test:
    # without the lock both see no file and both write a header; with it the second never gets there
    arrived = Queue.new
    calls = 0
    allow(File).to receive(:exist?).and_wrap_original do |original, path|
      found = original.call(path)
      if path.to_s.end_with?('CDR_2026-01-02.log')
        (calls += 1) == 1 ? arrived.pop(timeout: 0.5) : arrived << :here
      end
      found
    end
    threads = Array.new(2) { |i| Thread.new { described_class.log_text("t#{i}\r\n", character: 'C', instance: 'DR', dir: @dir, now: now) } }
    threads.each(&:join)
    body = File.binread(File.join(@dir, 'CDR_2026-01-02.log'))
    expect(body.scan('*** LOG CREATED AT').size).to eq(1)
    expect(body.scan(/^t\d\r$/).size).to eq(2)
  end

  it 'formats DateTime.ToString() like en-US with ICU (midnight and noon included)' do
    expect(described_class.date_time(Time.new(2026, 12, 31, 0, 0, 9))).to eq("12/31/2026 12:00:09#{nnbsp}AM")
    expect(described_class.date_time(Time.new(2026, 7, 4, 12, 30, 0))).to eq("7/4/2026 12:30:00#{nnbsp}PM")
  end
end
