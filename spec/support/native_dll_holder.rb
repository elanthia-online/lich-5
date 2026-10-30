# frozen_string_literal: true

require 'fiddle/import'
abort 'native DLL holder is Windows-only' unless Gem.win_platform?

module NativeDirectoryHandle
  extend Fiddle::Importer
  dlload 'kernel32.dll'
  extern 'void* CreateFileW(void*, unsigned long, unsigned long, void*, unsigned long, unsigned long, void*)'
  extern 'int CloseHandle(void*)'
  extern 'unsigned long GetLastError()'
end

library = Fiddle.dlopen(ARGV.fetch(0))
handle = nil
begin
  directory = ARGV.fetch(1).encode('UTF-16LE').b + [0].pack('v')
  # A loaded image plus an explicit directory handle without FILE_SHARE_DELETE
  # makes the sharing violation deterministic, independent of loader sharing.
  handle = NativeDirectoryHandle.CreateFileW(directory, 0, 3, 0, 3, 0x02000000, 0)
  invalid = (1 << (Fiddle::SIZEOF_VOIDP * 8)) - 1
  abort "could not hold the native extension directory: Windows error #{NativeDirectoryHandle.GetLastError()}" if [-1, invalid].include?(handle.to_i)
  $stdout.sync = true
  puts 'native-library-held'
  $stdin.read(1)
ensure
  NativeDirectoryHandle.CloseHandle(handle) if handle && ![-1, invalid].include?(handle.to_i)
  library.close
end
