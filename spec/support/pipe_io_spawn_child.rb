# frozen_string_literal: true

# Standalone child for spec/lib/common/pipe_io_windows_spec.rb: no game boot.
# Its stdin is a synchronous anonymous pipe owned by the spec, like a front end
# running Lich in --pipe mode. A PipeIO reader parks on stdin, then the main
# thread starts a child process the way MODE says and reports how long that took.
# Protocol: one JSON object per line on stdout.
require 'json'
require 'open3'
require 'stringio'
require_relative '../../lib/common/pipe_io'

MODE = ARGV.fetch(0)

def emit(event, fields = {})
  STDOUT.puts(JSON.dump(fields.merge(event: event)))
  STDOUT.flush
end

def monotonic
  Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

pipe = Lich::Common::PipeIO.new(input: STDIN, output: StringIO.new)
lines = []
reader = Thread.new do
  loop do
    line = pipe.gets
    lines << line
    break if line.nil?
  end
end
Thread.pass until reader.stop?
sleep 0.3 # well inside the idle wait

started = monotonic
case MODE
when 'spawn' then Process.wait(Process.spawn('cmd', '/c', 'exit 0'))
when 'open3' then Open3.capture3('cmd', '/c', 'echo child')
else raise ArgumentError, "unknown mode #{MODE}"
end
emit(:spawned, seconds: monotonic - started)

reader.join(10)
emit(:done, lines: lines, finished: !reader.alive?)
# A reader still blocked in a native read would hold up a normal exit.
exit!(0)
