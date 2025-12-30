require 'fiddle'
require 'rbconfig'

module Lich
  module Util
    # Memory management module that provides automatic and manual memory release functionality
    # for Ruby applications. Supports Linux, macOS, and Windows platforms.
    #
    # This module uses a singleton pattern to manage a background thread that periodically
    # releases memory back to the operating system after running Ruby's garbage collector.
    #
    # @example Basic usage
    #   MemoryReleaser.start
    #   # ... application runs ...
    #   MemoryReleaser.stop
    #
    # @example With custom interval and verbose logging
    #   MemoryReleaser.start(interval: 600, verbose: true)
    #
    # @example Manual memory release
    #   MemoryReleaser.release
    #
    # @example Check status
    #   status = MemoryReleaser.status
    #   puts "Running: #{status[:running]}"
    #   puts "Platform: #{status[:platform]}"
    #
    # @example Run benchmark
    #   MemoryReleaser.benchmark
    #
    module MemoryReleaser
      # Persistent command queue and launcher thread created at module load time.
      # This launcher thread exists at the main engine level and survives script termination,
      # which is critical for Windows/Lich compatibility where script-spawned threads are
      # killed when the script exits.
      @command_queue = Queue.new
      @launcher_thread = Thread.new do
        Thread.current.abort_on_exception = false
        Thread.current.name = "MemoryReleaser-Launcher"

        loop do
          begin
            command = @command_queue.pop
            break if command[:action] == :shutdown

            case command[:action]
            when :start_worker
              # Kill any existing worker
              if @worker_thread&.alive?
                @worker_thread.kill rescue nil
              end

              # Create new worker thread from launcher context
              @worker_thread = Thread.new do
                Thread.current.abort_on_exception = false
                Thread.current.name = "MemoryReleaser-Worker"

                interval = command[:interval]
                verbose = command[:verbose]
                manager = command[:manager]

                respond "[MemoryReleaser] Memory releaser started (interval: #{interval}s)" if verbose

                loop do
                  break unless manager.enabled

                  # Sleep in small chunks to be more responsive
                  elapsed = 0
                  while elapsed < interval && manager.enabled
                    sleep(1)
                    elapsed += 1
                  end

                  break unless manager.enabled

                  begin
                    manager.release
                  rescue => e
                    respond "[MemoryReleaser] Error: #{e.message}"
                    respond e.backtrace.first(5).join("\n") if verbose
                  end
                end

                respond "[MemoryReleaser] Memory releaser stopped" if verbose
              end

            when :stop_worker
              if @worker_thread&.alive?
                @worker_thread.kill rescue nil
              end
              @worker_thread = nil
            end
          rescue => e
            respond "[MemoryReleaser] Launcher error: #{e.message}"
          end
        end
      end

      # Core manager class that handles memory release operations and background thread management
      class Manager
        # @return [Boolean] whether the memory releaser is enabled
        attr_accessor :enabled

        # @return [Integer] interval in seconds between automatic memory releases
        attr_accessor :interval

        # @return [Boolean] whether to output verbose logging
        attr_accessor :verbose

        # Initialize a new Manager instance
        #
        # @return [Manager] a new manager instance
        def initialize
          @enabled = true
          @interval = 900 # 15 minutes default
          @verbose = false
        end

        # Perform a complete memory release cycle
        #
        # This runs Ruby's garbage collector with full mark and immediate sweep,
        # attempts to compact the heap if available, and then releases memory
        # back to the operating system using platform-specific methods.
        #
        # @return [void]
        def release
          run_gc
          release_to_os
          log "Memory release completed"
        end

        # Start the background memory release thread
        #
        # Stops any existing thread before starting a new one. The thread will
        # sleep for the specified interval between memory release cycles.
        #
        # This method uses a persistent launcher thread pattern to ensure threads
        # survive script termination in environments like Lich where script-spawned
        # threads are killed when the script exits. The launcher thread is created
        # at module load time and persists at the main engine level.
        #
        # @param interval [Integer] time in seconds between memory releases (default: 900)
        # @param verbose [Boolean] whether to enable verbose logging (default: false)
        # @return [Thread, nil] the background thread, or nil if failed to start
        #
        # @example Start with default settings (15 minutes, silent)
        #   MemoryReleaser.start
        #
        # @example Start with custom interval and verbose output
        #   MemoryReleaser.start(interval: 600, verbose: true)
        def start(interval: 900, verbose: false)
          stop if running?

          @interval = interval
          @verbose = verbose
          @enabled = true

          # Send command to persistent launcher thread
          MemoryReleaser.instance_variable_get(:@command_queue) << {
            action: :start_worker,
            interval: interval,
            verbose: verbose,
            manager: self
          }

          # Wait for worker to start
          timeout = 0
          until running?
            sleep 0.1
            timeout += 1
            if timeout > 50
              respond "[MemoryReleaser] ERROR: Worker thread failed to start"
              return nil
            end
          end

          MemoryReleaser.instance_variable_get(:@worker_thread)
        end

        # Stop the background memory release thread
        #
        # Sends a stop command to the launcher thread which will kill the worker
        # thread. This is a graceful shutdown that respects the launcher thread
        # architecture.
        #
        # @return [void]
        def stop
          @enabled = false

          MemoryReleaser.instance_variable_get(:@command_queue) << {
            action: :stop_worker
          }

          sleep 0.2
          log "Memory releaser stopped"
        end

        # Check if the background thread is currently running
        #
        # @return [Boolean] true if the background thread is alive, false otherwise
        def running?
          worker = MemoryReleaser.instance_variable_get(:@worker_thread)
          worker&.alive? || false
        end

        # Get the current status of the memory releaser
        #
        # @return [Hash] status information
        # @option return [Boolean] :running whether the background thread is running
        # @option return [Boolean] :enabled whether the memory releaser is enabled
        # @option return [Integer] :interval the current interval in seconds
        # @option return [Boolean] :verbose whether verbose logging is enabled
        # @option return [String] :platform the current platform/OS
        #
        # @example
        #   status = MemoryReleaser.status
        #   puts "Running: #{status[:running]}"
        #   puts "Interval: #{status[:interval]} seconds"
        #   puts "Platform: #{status[:platform]}"
        def status
          {
            running: running?,
            enabled: @enabled,
            interval: @interval,
            verbose: @verbose,
            platform: RbConfig::CONFIG['host_os']
          }
        end

        # Run a memory release benchmark showing before/after statistics
        #
        # This method displays detailed memory statistics before and after a
        # memory release operation, including the changes in heap slots, pages,
        # malloc usage, and process RSS.
        #
        # @return [void]
        #
        # @example
        #   MemoryReleaser.benchmark
        #   # => ============================================================
        #   # => Memory Usage Before Release:
        #   # => ============================================================
        #   # =>   Ruby Heap Live Slots:           123456
        #   # =>   ...
        def benchmark
          respond "=" * 60
          respond "Memory Usage Before Release:"
          respond "=" * 60
          before = print_memory_stats

          respond "\nReleasing memory..."
          release

          respond "\n" + "=" * 60
          respond "Memory Usage After Release:"
          respond "=" * 60
          after = print_memory_stats

          respond "\n" + "=" * 60
          respond "Change:"
          respond "=" * 60
          print_memory_diff(before, after)
        end

        private

        # Log a message if verbose mode is enabled
        #
        # @param message [String] the message to log
        # @return [void]
        # @api private
        def log(message)
          respond "[MemoryReleaser] #{message}" if @verbose
        end

        # Run Ruby's garbage collector
        #
        # Performs a full mark and immediate sweep, and attempts to compact
        # the heap if the Ruby version supports it.
        #
        # @return [void]
        # @api private
        def run_gc
          GC.start(full_mark: true, immediate_sweep: true)
          GC.compact if GC.respond_to?(:compact)
        end

        # Release memory back to the operating system
        #
        # Uses platform-specific methods to release memory:
        # - Linux: malloc_trim
        # - macOS: malloc_zone_pressure_relief
        # - Windows: EmptyWorkingSet or _heapmin
        #
        # @return [void]
        # @raise [StandardError] if memory release fails (caught and logged)
        # @api private
        def release_to_os
          case RbConfig::CONFIG['host_os']
          when /linux/
            malloc_trim_linux
          when /darwin|mac os/
            malloc_zone_pressure_relief_macos
          when /mswin|mingw|cygwin/
            heapmin_windows
          end
        rescue => e
          respond "Memory release to OS failed: #{e.message}"
        end

        # Release memory on Linux using malloc_trim
        #
        # Calls the glibc malloc_trim function to release free memory from the
        # top of the heap back to the operating system.
        #
        # @return [void]
        # @api private
        def malloc_trim_linux
          libc = Fiddle.dlopen(nil)
          malloc_trim = Fiddle::Function.new(
            libc['malloc_trim'],
            [Fiddle::TYPE_INT],
            Fiddle::TYPE_INT
          )
          malloc_trim.call(0)
          log "malloc_trim completed"
        end

        # Release memory on macOS using malloc_zone_pressure_relief
        #
        # Calls the macOS malloc_zone_pressure_relief function to release
        # memory pressure from the default malloc zone.
        #
        # @return [void]
        # @api private
        def malloc_zone_pressure_relief_macos
          libc = Fiddle.dlopen('/usr/lib/libSystem.B.dylib')
          func = Fiddle::Function.new(
            libc['malloc_zone_pressure_relief'],
            [Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T],
            Fiddle::TYPE_VOID
          )
          func.call(nil, 0)
          log "malloc_zone_pressure_relief completed"
        end

        # Release memory on Windows using EmptyWorkingSet or _heapmin
        #
        # Attempts to use Windows EmptyWorkingSet API first, which removes as many
        # pages as possible from the working set. Falls back to _heapmin if that fails.
        #
        # @return [Boolean, nil] true if successful, nil if all methods fail
        # @api private
        def heapmin_windows
          # Try EmptyWorkingSet first (from your original code)
          begin
            k32 = Fiddle.dlopen('kernel32')
            psapi = Fiddle.dlopen('psapi')
            get_proc = Fiddle::Function.new(
              k32['GetCurrentProcess'],
              [],
              Fiddle::TYPE_VOIDP
            )
            empty = Fiddle::Function.new(
              psapi['EmptyWorkingSet'],
              [Fiddle::TYPE_VOIDP],
              Fiddle::TYPE_INT
            )
            empty.call(get_proc.call)
            log "EmptyWorkingSet completed"
            return
          rescue => e
            log "EmptyWorkingSet failed, trying _heapmin: #{e.message}"
          end

          # Fallback to _heapmin
          crt_libs = if RUBY_PLATFORM =~ /ucrt/
                       ['ucrtbase', 'msvcrt']
                     elsif RUBY_PLATFORM =~ /mingw/
                       ['msvcrt', 'ucrtbase']
                     else
                       ['ucrtbase', 'msvcrt']
                     end

          crt_libs.each do |lib_name|
            begin
              crt = Fiddle.dlopen(lib_name)
              heapmin = Fiddle::Function.new(
                crt['_heapmin'],
                [],
                Fiddle::TYPE_INT
              )
              heapmin.call
              log "_heapmin completed with #{lib_name}"
              return true
            rescue Fiddle::DLError
              next
            end
          end

          respond "Could not find compatible method for Windows memory release"
          nil
        end

        # Print current memory statistics
        #
        # Displays Ruby heap information and process memory usage.
        #
        # @return [Hash] memory statistics
        # @option return [Integer] :heap_live_slots number of live object slots
        # @option return [Integer] :heap_free_slots number of free object slots
        # @option return [Integer] :heap_total_slots total object slots
        # @option return [Integer] :heap_allocated_pages number of allocated heap pages
        # @option return [Integer] :malloc_increase_bytes bytes allocated via malloc
        # @option return [Float, nil] :rss_mb process RSS in megabytes
        # @api private
        def print_memory_stats
          stat = GC.stat

          stats = {
            heap_live_slots: stat[:heap_live_slots],
            heap_free_slots: stat[:heap_free_slots],
            heap_total_slots: stat[:heap_live_slots] + stat[:heap_free_slots],
            heap_allocated_pages: stat[:heap_allocated_pages],
            malloc_increase_bytes: stat[:malloc_increase_bytes],
            rss_mb: get_process_memory
          }

          respond "  Ruby Heap Live Slots:    #{stats[:heap_live_slots].to_s.rjust(12)}"
          respond "  Ruby Heap Free Slots:    #{stats[:heap_free_slots].to_s.rjust(12)}"
          respond "  Ruby Heap Total Slots:   #{stats[:heap_total_slots].to_s.rjust(12)}"
          respond "  Ruby Heap Pages:         #{stats[:heap_allocated_pages].to_s.rjust(12)}"
          respond "  Malloc Increase (bytes): #{stats[:malloc_increase_bytes].to_s.rjust(12)}"
          respond "  Process RSS (MB):        #{sprintf('%.2f', stats[:rss_mb]).rjust(12)}" if stats[:rss_mb]

          stats
        end

        # Print the difference between two memory statistics snapshots
        #
        # @param before [Hash] memory statistics before release
        # @param after [Hash] memory statistics after release
        # @return [void]
        # @api private
        def print_memory_diff(before, after)
          diff_slots = after[:heap_total_slots] - before[:heap_total_slots]
          diff_pages = after[:heap_allocated_pages] - before[:heap_allocated_pages]
          diff_malloc = after[:malloc_increase_bytes] - before[:malloc_increase_bytes]
          diff_rss = after[:rss_mb] ? after[:rss_mb] - before[:rss_mb] : nil

          respond "  Heap Slots:              #{format_diff(diff_slots)}"
          respond "  Heap Pages:              #{format_diff(diff_pages)}"
          respond "  Malloc Increase (bytes): #{format_diff(diff_malloc)}"
          respond "  Process RSS (MB):        #{sprintf('%+.2f', diff_rss).rjust(12)}" if diff_rss
        end

        # Format a difference value with sign
        #
        # @param value [Integer] the difference value
        # @return [String] formatted string with sign
        # @api private
        def format_diff(value)
          formatted = value.to_s.rjust(12)
          value < 0 ? formatted : "+#{formatted}"
        end

        # Get current process memory usage in megabytes
        #
        # Uses platform-specific methods to retrieve the process's resident set size (RSS).
        #
        # @return [Float, nil] memory usage in MB, or nil if unable to determine
        # @api private
        def get_process_memory
          case RbConfig::CONFIG['host_os']
          when /linux/
            File.read('/proc/self/status').match(/VmRSS:\s+(\d+)/)[1].to_f / 1024.0
          when /darwin|mac os/
            `ps -o rss= -p #{Process.pid}`.to_f / 1024.0
          when /mswin|mingw|cygwin/
            get_process_memory_windows
          end
        rescue
          nil
        end

        # Get process memory on Windows with multiple fallback methods
        #
        # Tries three methods in order:
        # 1. GetProcessMemoryInfo (PSAPI) - fastest, no console window
        # 2. WMI via WIN32OLE - slower, no console window
        # 3. PowerShell with hidden window - slowest, hidden console
        #
        # @return [Float, nil] memory usage in MB, or nil if all methods fail
        # @api private
        def get_process_memory_windows
          # Method 1: Try GetProcessMemoryInfo via PSAPI (most reliable, no console)
          begin
            return get_memory_via_psapi
          rescue => e
            log "GetProcessMemoryInfo failed: #{e.message}" if @verbose
          end

          # Method 2: Try WMI via WIN32OLE (no console, but slower)
          begin
            return get_memory_via_wmi
          rescue => e
            log "WMI failed: #{e.message}" if @verbose
          end

          # Method 3: PowerShell with hidden window (last resort)
          begin
            return get_memory_via_powershell
          rescue => e
            log "PowerShell failed: #{e.message}" if @verbose
          end

          nil
        end

        # Get process memory via Windows PSAPI
        #
        # Uses GetProcessMemoryInfo from psapi.dll to directly query the
        # PROCESS_MEMORY_COUNTERS structure. This is the fastest method
        # and doesn't spawn any console windows.
        #
        # @return [Float, nil] memory usage in MB, or nil on failure
        # @api private
        def get_memory_via_psapi
          # Use Windows PSAPI directly via Fiddle (no console window)
          k32 = Fiddle.dlopen('kernel32')
          psapi = Fiddle.dlopen('psapi')

          # Get current process handle
          get_current_process = Fiddle::Function.new(
            k32['GetCurrentProcess'],
            [],
            Fiddle::TYPE_VOIDP
          )

          # Detect if we're running 64-bit Ruby
          is_64bit = ['a'].pack('P').size == 8

          # PROCESS_MEMORY_COUNTERS structure size
          # 32-bit: 40 bytes, 64-bit: 72 bytes
          pmc_size = is_64bit ? 72 : 40
          pmc = Fiddle::Pointer.malloc(pmc_size)
          pmc[0, 4] = [pmc_size].pack('L') # cb member (always 4 bytes)

          # GetProcessMemoryInfo function
          get_memory_info = Fiddle::Function.new(
            psapi['GetProcessMemoryInfo'],
            [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT],
            Fiddle::TYPE_INT
          )

          result = get_memory_info.call(get_current_process.call, pmc, pmc_size)

          if result != 0
            # WorkingSetSize offset: 12 bytes (32-bit) or 16 bytes (64-bit)
            offset = is_64bit ? 16 : 12
            pack_format = is_64bit ? 'Q' : 'L' # Q for 64-bit, L for 32-bit
            size = is_64bit ? 8 : 4

            working_set = pmc[offset, size].unpack(pack_format)[0]
            return working_set / (1024.0 * 1024.0) # Convert bytes to MB
          end

          nil
        end

        # Get process memory via WMI (Windows Management Instrumentation)
        #
        # Uses WIN32OLE to query WMI for the process's working set size.
        # Slower than PSAPI but doesn't require Fiddle's low-level memory operations.
        #
        # @return [Float, nil] memory usage in MB, or nil on failure
        # @api private
        def get_memory_via_wmi
          # Use WMI - no console window but requires win32ole
          require 'win32ole'

          wmi = WIN32OLE.connect("winmgmts://")
          processes = wmi.ExecQuery("SELECT WorkingSetSize FROM Win32_Process WHERE ProcessId = #{Process.pid}")

          processes.each do |process|
            return process.WorkingSetSize / (1024.0 * 1024.0) if process.WorkingSetSize
          end

          nil
        end

        # Get process memory via PowerShell
        #
        # Uses PowerShell with a hidden window to query process memory.
        # This is the slowest method but most compatible as a last resort.
        #
        # @return [Float, nil] memory usage in MB, or nil on failure
        # @api private
        def get_memory_via_powershell
          # Use PowerShell with hidden window as last resort
          script = "(Get-Process -Id #{Process.pid}).WorkingSet64"

          # Use PowerShell with WindowStyle Hidden to prevent console window
          output = `powershell.exe -WindowStyle Hidden -NoProfile -Command "#{script}" 2>NUL`

          if output && !output.empty?
            return output.strip.to_f / (1024.0 * 1024.0)
          end

          nil
        end
      end

      # Class-level singleton instance
      @instance = nil

      class << self
        # Get or create the singleton Manager instance
        #
        # @return [Manager] the singleton manager instance
        def instance
          @instance ||= Manager.new
        end

        # Start the background memory release thread
        #
        # @param interval [Integer] time in seconds between memory releases (default: 900)
        # @param verbose [Boolean] whether to enable verbose logging (default: false)
        # @return [Thread, nil] the background thread, or nil if failed to start
        # @see Manager#start
        def start(interval: 900, verbose: false)
          instance.start(interval: interval, verbose: verbose)
        end

        # Stop the background memory release thread
        #
        # @return [void]
        # @see Manager#stop
        def stop
          instance.stop
        end

        # Perform a manual memory release
        #
        # @return [void]
        # @see Manager#release
        def release
          instance.release
        end

        # Check if the background thread is running
        #
        # @return [Boolean] true if running, false otherwise
        # @see Manager#running?
        def running?
          instance.running?
        end

        # Get the current status
        #
        # @return [Hash] status information
        # @see Manager#status
        def status
          instance.status
        end

        # Run a memory release benchmark
        #
        # @return [void]
        # @see Manager#benchmark
        def benchmark
          instance.benchmark
        end

        # Reset the singleton instance
        #
        # Stops the current instance if running and clears the singleton.
        # Useful for testing or when you need to recreate the instance.
        #
        # @return [void]
        def reset!
          @instance&.stop
          @instance = nil
        end
      end
    end
  end
end

# Usage examples:
#
# Start background thread (15 minutes, silent):
#   MemoryReleaser.start
#
# Start with custom interval and verbose output:
#   MemoryReleaser.start(interval: 600, verbose: true)
#
# Manual release:
#   MemoryReleaser.release
#
# Check status:
#   MemoryReleaser.status
#
# Stop background thread:
#   MemoryReleaser.stop
#
# Check if running:
#   MemoryReleaser.running?
#
# Run benchmark:
#   MemoryReleaser.benchmark
#
# For Lich5 integration:
#   MemoryReleaser.start(interval: 900, verbose: true)
#   before_dying { MemoryReleaser.stop }
