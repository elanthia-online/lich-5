# frozen_string_literal: true

require_relative '../../spec_helper'
require 'json'
require 'rbconfig'
require 'timeout'

# Native Windows behaviour of PipeIO in --pipe mode (issue #2288). Each example
# runs spec/support/pipe_io_spawn_child.rb with its stdin on a synchronous
# anonymous pipe (CreatePipe), the kind a front end hands Lich. A Ruby IO.pipe
# would not do: Ruby creates overlapped pipes, and with those the stall this
# guards against never happens.
RSpec.describe 'Lich::Common::PipeIO on a Windows front-end pipe', if: Gem.win_platform? do
  let(:child_script) { File.expand_path('../../support/pipe_io_spawn_child.rb', __dir__) }
  # How long the parent waits for the child's spawn before it sends a line to
  # unblock a stalled one. Comfortably above a normal spawn (well under 0.5 s).
  let(:stall_release_seconds) { 3 }

  before(:all) do
    require 'fiddle'
    kernel32 = Fiddle.dlopen('kernel32')
    @create_pipe = Fiddle::Function.new(
      kernel32['CreatePipe'],
      [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT],
      Fiddle::TYPE_INT
    )
    @open_osfhandle = Fiddle::Function.new(
      Fiddle.dlopen('ucrtbase.dll')['_open_osfhandle'],
      [Fiddle::TYPE_INTPTR_T, Fiddle::TYPE_INT],
      Fiddle::TYPE_INT
    )
  end

  # Returns [read_io, write_io] over a CreatePipe pipe (synchronous handles).
  def front_end_pipe
    read_handle = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP, Fiddle::RUBY_FREE)
    write_handle = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP, Fiddle::RUBY_FREE)
    raise 'CreatePipe failed' if @create_pipe.call(read_handle, write_handle, nil, 0).zero?

    o_rdonly = 0x0000
    o_wronly = 0x0001
    o_binary = 0x8000
    [[read_handle, o_rdonly, 'rb'], [write_handle, o_wronly, 'wb']].map do |pointer, flags, mode|
      handle = pointer[0, Fiddle::SIZEOF_VOIDP].unpack1('J')
      fd = @open_osfhandle.call(handle, flags | o_binary)
      raise '_open_osfhandle failed' if fd.negative?

      IO.for_fd(fd, mode)
    end
  end

  # Starts the child on a front-end pipe and yields [stdin_writer, next_event].
  def with_child(mode)
    child_stdin, front_end = front_end_pipe
    events, child_stdout = IO.pipe
    pid = Process.spawn(RbConfig.ruby, child_script, mode, in: child_stdin, out: child_stdout)
    child_stdin.close
    child_stdout.close
    next_event = lambda do |seconds|
      line = Timeout.timeout(seconds) { events.gets }
      line && JSON.parse(line)
    rescue Timeout::Error
      nil
    end
    yield front_end, next_event
  ensure
    front_end&.close unless front_end&.closed?
    events&.close
    if pid
      begin
        Process.kill('KILL', pid)
      rescue Errno::ESRCH, Errno::EINVAL
        nil
      end
      begin
        Process.wait(pid)
      rescue Errno::ECHILD
        nil
      end
    end
  end

  # The child's spawn report. If it hasn't come by stall_release_seconds the
  # spawn is stalled behind the parked reader; a line releases it.
  def spawned_event(front_end, next_event)
    event = next_event.call(stall_release_seconds)
    return [event, false] if event

    front_end.write("release\n")
    front_end.flush
    [next_event.call(10), true]
  end

  it 'lets a child process start while the reader waits for input' do
    with_child('spawn') do |front_end, next_event|
      spawned, released = spawned_event(front_end, next_event)
      expect(spawned).to include('event' => 'spawned')
      expect(released).to be(false), "spawn took #{spawned['seconds']}s and only finished after a front-end line"
      expect(spawned['seconds']).to be < 1.5

      front_end.write("look\n")
      front_end.close
      done = next_event.call(10)
      expect(done).to include('event' => 'done', 'finished' => true, 'lines' => ["look\n", nil])
    end
  end

  it 'still receives input and EOF after an Open3 call swaps the stdin handle' do
    with_child('open3') do |front_end, next_event|
      spawned, released = spawned_event(front_end, next_event)
      expect(spawned).to include('event' => 'spawned')
      expect(released).to be(false), 'Open3 only finished after a front-end line'

      front_end.write("first\n")
      front_end.flush
      sleep 0.2
      front_end.write("second\n")
      front_end.close
      done = next_event.call(10)
      expect(done).to include('event' => 'done')
      expect(done['lines']).to eq(["first\n", "second\n", nil])
      expect(done['finished']).to be(true)
    end
  end
end
