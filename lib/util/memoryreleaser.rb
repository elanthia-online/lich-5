require 'fiddle'
require 'rbconfig'

module Lich
module Util
module MemoryReleaser
  class Manager
    attr_accessor :enabled, :interval, :verbose
    
    def initialize
      @enabled = true
      @interval = 900  # 15 minutes default
      @verbose = false
      @thread = nil
    end
    
    # Main release method
    def release
      run_gc
      release_to_os
      log "Memory release completed"
    end
    
    # Start background thread
    def start(interval: 900, verbose: false)
      stop if running?
      
      @interval = interval
      @verbose = verbose
      @enabled = true
      
      @thread = Thread.new do
        log "Memory releaser started (interval: #{@interval}s)"
        
        loop do
          break unless @enabled
          
          sleep(@interval)
          break unless @enabled
          
          begin
            release
          rescue => e
            warn "Memory releaser error: #{e.message}"
            warn e.backtrace.first(5).join("\n") if @verbose
          end
        end
        
        log "Memory releaser stopped"
      end
      
      @thread
    end
    
    # Stop background thread
    def stop
      @enabled = false
      
      if @thread&.alive?
        @thread.join(5)  # Wait up to 5 seconds
        @thread.kill if @thread.alive?  # Force kill if still running
      end
      
      @thread = nil
      log "Memory releaser stopped"
    end
    
    # Check if running
    def running?
      @thread&.alive? || false
    end
    
    # Get current status
    def status
      {
        running: running?,
        enabled: @enabled,
        interval: @interval,
        verbose: @verbose,
        platform: RbConfig::CONFIG['host_os']
      }
    end
    
    # Show benchmark with before/after stats
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
    
    def log(message)
      respond "[MemoryReleaser] #{message}" if @verbose
    end
    
    def run_gc
      GC.start(full_mark: true, immediate_sweep: true)
      GC.compact if GC.respond_to?(:compact)
    end
    
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
          return
        rescue Fiddle::DLError
          next
        end
      end

      respond "Could not find compatible method for Windows memory release"
    end
    
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
    
    def format_diff(value)
      formatted = value.to_s.rjust(12)
      value < 0 ? formatted : "+#{formatted}"
    end
    
    def get_process_memory
      case RbConfig::CONFIG['host_os']
      when /linux/
        File.read('/proc/self/status').match(/VmRSS:\s+(\d+)/)[1].to_f / 1024.0
      when /darwin|mac os/
        `ps -o rss= -p #{Process.pid}`.to_f / 1024.0
      when /mswin|mingw|cygwin/
        get_process_memory_windows
      end
    rescue => e
      nil
    end
    
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
      pmc[0, 4] = [pmc_size].pack('L')  # cb member (always 4 bytes)
      
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
        pack_format = is_64bit ? 'Q' : 'L'  # Q for 64-bit, L for 32-bit
        size = is_64bit ? 8 : 4
        
        working_set = pmc[offset, size].unpack(pack_format)[0]
        return working_set / (1024.0 * 1024.0)  # Convert bytes to MB
      end
      
      nil
    end
    
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
    # Get or create singleton instance
    def instance
      @instance ||= Manager.new
    end
    
    # Delegate methods to singleton instance
    def start(interval: 900, verbose: false)
      instance.start(interval: interval, verbose: verbose)
    end
    
    def stop
      instance.stop
    end
    
    def release
      instance.release
    end
    
    def running?
      instance.running?
    end
    
    def status
      instance.status
    end
    
    def benchmark
      instance.benchmark
    end
    
    # Reset singleton (useful for testing)
    def reset!
      @instance&.stop
      @instance = nil
    end
  end
  start unless running?
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
