# frozen_string_literal: true

require 'fiddle/import'

module NativeDirectoryHandle
  extend Fiddle::Importer

  FILE_LIST_DIRECTORY = 1
  FILE_SHARE_READ_WRITE = 3
  DELETE_ACCESS = 0x00010000
  OPEN_EXISTING = 3
  FILE_FLAG_BACKUP_SEMANTICS = 0x02000000
  ERROR_SHARING_VIOLATION = 32

  def self.invalid?(handle)
    [-1, (1 << (Fiddle::SIZEOF_VOIDP * 8)) - 1].include?(handle.to_i)
  end

  def self.hold(directory, api: self)
    encoded = directory.encode('UTF-16LE').b + [0].pack('v')
    # Zero desired access is metadata-only and need not participate in sharing
    # checks. Request directory-list access while withholding FILE_SHARE_DELETE.
    handle = api.CreateFileW(encoded, FILE_LIST_DIRECTORY, FILE_SHARE_READ_WRITE, 0, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, 0)
    raise "could not hold the native extension directory: Windows error #{api.GetLastError()}" if invalid?(handle)

    begin
      # Prove the hold denies deletion before telling the parent it is ready.
      probe = api.CreateFileW(encoded, DELETE_ACCESS, 7, 0, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, 0)
      unless invalid?(probe)
        api.CloseHandle(probe)
        raise 'native extension directory hold did not block delete access'
      end
      error = api.GetLastError()
      raise "unexpected delete-access probe failure: Windows error #{error}" unless error == ERROR_SHARING_VIOLATION

      yield
    ensure
      api.CloseHandle(handle)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  abort 'native DLL holder is Windows-only' unless Gem.win_platform?

  NativeDirectoryHandle.dlload 'kernel32.dll'
  NativeDirectoryHandle.extern 'void* CreateFileW(void*, unsigned long, unsigned long, void*, unsigned long, unsigned long, void*)'
  NativeDirectoryHandle.extern 'int CloseHandle(void*)'
  NativeDirectoryHandle.extern 'unsigned long GetLastError()'

  library = Fiddle.dlopen(ARGV.fetch(0))
  begin
    NativeDirectoryHandle.hold(ARGV.fetch(1)) do
      $stdout.sync = true
      puts 'native-library-held'
      $stdin.read(1)
    end
  ensure
    library.close
  end
end
