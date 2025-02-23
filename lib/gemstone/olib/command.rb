module Lich
  module Gemstone
    class Command
      class Error < Exception;end;
      # this is a shared lock across all scripts, preventing the common problems of race conditions with fput
      LOCK = Mutex.new

      def self.lock()
        LOCK.synchronize { yield }
      end

      def self.try_or_fail(seconds: 5, command: nil)
        fput(command)
        expiry = Time.now + seconds
        wait_until do yield or Time.now > expiry end
        Command::Error.new("#{command} failed in #{seconds} seconds") if Time.now > expiry
      end
    end
  end
end