# Lich Carveout
# SynchronizedSocket class moved 2024-06-13

class SynchronizedSocket
  def initialize(o)
    @delegate = o
    @mutex = Mutex.new
    # self # removed by robocop, needs broad testing
  end

  def puts(*args, &block)
    @mutex.synchronize {
      @delegate.puts(*args, &block)
    }
  end

  def puts_if(*args)
    @mutex.synchronize {
      if yield
        @delegate.puts(*args)
        return true
      else
        return false
      end
    }
  end

  def write(*args, &block)
    @mutex.synchronize {
      @delegate.write(*args, &block)
    }
  end

  def method_missing(method, *args, &block)
    @delegate.__send__ method, *args, &block
  end
end
