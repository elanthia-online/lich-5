# Lich5 carveout for init_db


#
# Report an error if Lich 4.4 data is found
#
if File.exists?("#{DATA_DIR}/lich.sav")
  Lich.log "error: Archaic Lich 4.4 configuration found: Please remove #{DATA_DIR}/lich.sav"
  Lich.msgbox "error: Archaic Lich 4.4 configuration found: Please remove #{DATA_DIR}/lich.sav"
  exit
end

if Gem::Version.new(RUBY_VERSION) < Gem::Version.new(REQUIRED_RUBY)
  if (RUBY_PLATFORM =~ /mingw|win/) and (RUBY_PLATFORM !~ /darwin/i)
    require 'fiddle'
    Fiddle::Function.new(DL.dlopen('user32.dll')['MessageBox'], [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT], Fiddle::TYPE_INT).call(0, 'Upgrade Ruby to version 2.6', "Lich v#{LICH_VERSION}", 16)
  else
    puts "Upgrade Ruby to version 2.6"
  end
  exit
end

begin
  # stupid workaround for Windows
  # seems to avoid a 10 second lag when starting lnet, without adding a 10 second lag at startup
  require 'openssl'
  OpenSSL::PKey::RSA.new(512)
rescue LoadError
  nil # not required for basic Lich; however, lnet and repository scripts will fail without openssl
rescue
  nil
end

# check for Linux | WINE (and maybe in future MacOS | WINE) first due to low population
# segment of code unmodified from Lich4 (Tillmen)
if arg = ARGV.find { |a| a =~ /^--wine=.+$/i }
  $wine_bin = arg.sub(/^--wine=/, '')
else
  begin
    $wine_bin = `which wine`.strip
  rescue
    $wine_bin = nil
  end
end
if arg = ARGV.find { |a| a =~ /^--wine-prefix=.+$/i }
  $wine_prefix = arg.sub(/^--wine-prefix=/, '')
elsif ENV['WINEPREFIX']
  $wine_prefix = ENV['WINEPREFIX']
elsif ENV['HOME']
  $wine_prefix = ENV['HOME'] + '/.wine'
else
  $wine_prefix = nil
end
if $wine_bin and File.exists?($wine_bin) and File.file?($wine_bin) and $wine_prefix and File.exists?($wine_prefix) and File.directory?($wine_prefix)
  module Wine
    BIN = $wine_bin
    PREFIX = $wine_prefix
    def Wine.registry_gets(key)
      hkey, subkey, thingie = /(HKEY_LOCAL_MACHINE|HKEY_CURRENT_USER)\\(.+)\\([^\\]*)/.match(key).captures # fixme: stupid highlights ]/
      if File.exist?(PREFIX + '/system.reg')
        if hkey == 'HKEY_LOCAL_MACHINE'
          subkey = "[#{subkey.gsub('\\', '\\\\\\')}]"
          if thingie.nil? or thingie.empty?
            thingie = '@'
          else
            thingie = "\"#{thingie}\""
          end
          lookin = result = false
          File.open(PREFIX + '/system.reg') { |f| f.readlines }.each { |line|
            if line[0...subkey.length] == subkey
              lookin = true
            elsif line =~ /^\[/
              lookin = false
            elsif lookin and line =~ /^#{thingie}="(.*)"$/i
              result = $1.split('\\"').join('"').split('\\\\').join('\\').sub(/\\0$/, '')
              break
            end
          }
          return result
        else
          return false
        end
      else
        return false
      end
    end

    def Wine.registry_puts(key, value)
      hkey, subkey, thingie = /(HKEY_LOCAL_MACHINE|HKEY_CURRENT_USER)\\(.+)\\([^\\]*)/.match(key).captures # fixme ]/
      if File.exists?(PREFIX)
        if thingie.nil? or thingie.empty?
          thingie = '@'
        else
          thingie = "\"#{thingie}\""
        end
        # gsub sucks for this..
        value = value.split('\\').join('\\\\')
        value = value.split('"').join('\"')
        begin
          regedit_data = "REGEDIT4\n\n[#{hkey}\\#{subkey}]\n#{thingie}=\"#{value}\"\n\n"
          filename = "#{TEMP_DIR}/wine-#{Time.now.to_i}.reg"
          File.open(filename, 'w') { |f| f.write(regedit_data) }
          system("#{BIN} regedit #{filename}")
          sleep 0.2
          File.delete(filename)
        rescue
          return false
        end
        return true
      end
    end
  end
end
#$wine_bin = nil
#$wine_prefix = nil
#end

# find the FE locations for Win and for Linux | WINE

if (RUBY_PLATFORM =~ /mingw|win/i) && (RUBY_PLATFORM !~ /darwin/i)
  require 'win32/registry'
  include Win32

  paths = ['SOFTWARE\\WOW6432Node\\Simutronics\\STORM32',
           'SOFTWARE\\WOW6432Node\\Simutronics\\WIZ32']

  def key_exists?(path)
    Registry.open(Registry::HKEY_LOCAL_MACHINE, path, ::Win32::Registry::KEY_READ)
    true
  rescue StandardError
    false
  end

  paths.each do |path|
    next unless key_exists?(path)

    Registry.open(Registry::HKEY_LOCAL_MACHINE, path).each_value do |_subkey, _type, data|
      dirloc = data
      if path =~ /WIZ32/
        $wiz_fe_loc = dirloc
      elsif path =~ /STORM32/
        $sf_fe_loc = dirloc
      else
        Lich.log("Hammer time, couldn't find me a SIMU FE on a Windows box")
      end
    end
  end
elsif defined?(Wine)
  paths = ['HKEY_LOCAL_MACHINE\\SOFTWARE\\WOW6432Node\\Simutronics\\STORM32\\Directory',
           'HKEY_LOCAL_MACHINE\\SOFTWARE\\WOW6432Node\\Simutronics\\WIZ32\\Directory']
## Needs improvement - iteration and such.  Quick slam test.
  $sf_fe_loc = Wine.registry_gets('HKEY_LOCAL_MACHINE\\SOFTWARE\\WOW6432Node\\Simutronics\\STORM32\\Directory') || ''
  $wiz_fe_loc_temp = Wine.registry_gets('HKEY_LOCAL_MACHINE\\Software\\Wow6432Node\\Simutronics\\WIZ32\\Directory')
  $sf_fe_loc_temp = Wine.registry_gets('HKEY_LOCAL_MACHINE\\Software\\Wow6432Node\\Simutronics\\STORM32\\Directory')

  if $wiz_fe_loc_temp
    $wiz_fe_loc = $wiz_fe_loc_temp.gsub('\\', '/').gsub('C:', Wine::PREFIX + '/drive_c')
  end
  if $sf_fe_loc_temp
    $sf_fe_loc = $sf_fe_loc_temp.gsub('\\', '/').gsub('C:', Wine::PREFIX + '/drive_c')
  end

  if !File.exist?($sf_fe_loc)
    $sf_fe_loc =~ /SIMU/ ? $sf_fe_loc = $sf_fe_loc.gsub("SIMU", "Simu") : $sf_fe_loc = $sf_fe_loc.gsub("Simu", "SIMU")
    Lich.log("Cannot find STORM equivalent FE to launch.") if !File.exist?($sf_fe_loc)
  end
end

## The following should be deprecated with the direct-frontend-launch-method
## TODO: remove as part of chore/Remove unnecessary Win32 calls
## Temporarily reinstatated for DR

if (RUBY_PLATFORM =~ /mingw|win/i) and (RUBY_PLATFORM !~ /darwin/i)
  #
  # Windows API made slightly less annoying
  #
  require 'fiddle'
  require 'fiddle/import'
  module Win32
    SIZEOF_CHAR = Fiddle::SIZEOF_CHAR
    SIZEOF_LONG = Fiddle::SIZEOF_LONG
    SEE_MASK_NOCLOSEPROCESS = 0x00000040
    MB_OK = 0x00000000
    MB_OKCANCEL = 0x00000001
    MB_YESNO = 0x00000004
    MB_ICONERROR = 0x00000010
    MB_ICONQUESTION = 0x00000020
    MB_ICONWARNING = 0x00000030
    IDIOK = 1
    IDICANCEL = 2
    IDIYES = 6
    IDINO = 7
    KEY_ALL_ACCESS = 0xF003F
    KEY_CREATE_SUB_KEY = 0x0004
    KEY_ENUMERATE_SUB_KEYS = 0x0008
    KEY_EXECUTE = 0x20019
    KEY_NOTIFY = 0x0010
    KEY_QUERY_VALUE = 0x0001
    KEY_READ = 0x20019
    KEY_SET_VALUE = 0x0002
    KEY_WOW64_32KEY = 0x0200
    KEY_WOW64_64KEY = 0x0100
    KEY_WRITE = 0x20006
    TokenElevation = 20
    TOKEN_QUERY = 8
    STILL_ACTIVE = 259
    SW_SHOWNORMAL = 1
    SW_SHOW = 5
    PROCESS_QUERY_INFORMATION = 1024
    PROCESS_VM_READ = 16
    HKEY_LOCAL_MACHINE = -2147483646
    REG_NONE = 0
    REG_SZ = 1
    REG_EXPAND_SZ = 2
    REG_BINARY = 3
    REG_DWORD = 4
    REG_DWORD_LITTLE_ENDIAN = 4
    REG_DWORD_BIG_ENDIAN = 5
    REG_LINK = 6
    REG_MULTI_SZ = 7
    REG_QWORD = 11
    REG_QWORD_LITTLE_ENDIAN = 11

    module Kernel32
      extend Fiddle::Importer
      dlload 'kernel32'
      extern 'int GetCurrentProcess()'
      extern 'int GetExitCodeProcess(int, int*)'
      extern 'int GetModuleFileName(int, void*, int)'
      extern 'int GetVersionEx(void*)'
      #         extern 'int OpenProcess(int, int, int)' # fixme
      extern 'int GetLastError()'
      extern 'int CreateProcess(void*, void*, void*, void*, int, int, void*, void*, void*, void*)'
    end
    def Win32.GetLastError
      return Kernel32.GetLastError()
    end

    def Win32.CreateProcess(args)
      if args[:lpCommandLine]
        lpCommandLine = args[:lpCommandLine].dup
      else
        lpCommandLine = nil
      end
      if args[:bInheritHandles] == false
        bInheritHandles = 0
      elsif args[:bInheritHandles] == true
        bInheritHandles = 1
      else
        bInheritHandles = args[:bInheritHandles].to_i
      end
      if args[:lpEnvironment].class == Array
        # fixme
      end
      lpStartupInfo = [68, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      lpStartupInfo_index = { :lpDesktop => 2, :lpTitle => 3, :dwX => 4, :dwY => 5, :dwXSize => 6, :dwYSize => 7, :dwXCountChars => 8, :dwYCountChars => 9, :dwFillAttribute => 10, :dwFlags => 11, :wShowWindow => 12, :hStdInput => 15, :hStdOutput => 16, :hStdError => 17 }
      for sym in [:lpDesktop, :lpTitle]
        if args[sym]
          args[sym] = "#{args[sym]}\0" unless args[sym][-1, 1] == "\0"
          lpStartupInfo[lpStartupInfo_index[sym]] = Fiddle::Pointer.to_ptr(args[sym]).to_i
        end
      end
      for sym in [:dwX, :dwY, :dwXSize, :dwYSize, :dwXCountChars, :dwYCountChars, :dwFillAttribute, :dwFlags, :wShowWindow, :hStdInput, :hStdOutput, :hStdError]
        if args[sym]
          lpStartupInfo[lpStartupInfo_index[sym]] = args[sym]
        end
      end
      lpStartupInfo = lpStartupInfo.pack('LLLLLLLLLLLLSSLLLL')
      lpProcessInformation = [0, 0, 0, 0,].pack('LLLL')
      r = Kernel32.CreateProcess(args[:lpApplicationName], lpCommandLine, args[:lpProcessAttributes], args[:lpThreadAttributes], bInheritHandles, args[:dwCreationFlags].to_i, args[:lpEnvironment], args[:lpCurrentDirectory], lpStartupInfo, lpProcessInformation)
      lpProcessInformation = lpProcessInformation.unpack('LLLL')
      return :return => (r > 0 ? true : false), :hProcess => lpProcessInformation[0], :hThread => lpProcessInformation[1], :dwProcessId => lpProcessInformation[2], :dwThreadId => lpProcessInformation[3]
    end

    #      Win32.CreateProcess(:lpApplicationName => 'Launcher.exe', :lpCommandLine => 'lich2323.sal', :lpCurrentDirectory => 'C:\\PROGRA~1\\SIMU')
    #      def Win32.OpenProcess(args={})
    #         return Kernel32.OpenProcess(args[:dwDesiredAccess].to_i, args[:bInheritHandle].to_i, args[:dwProcessId].to_i)
    #      end
    def Win32.GetCurrentProcess
      return Kernel32.GetCurrentProcess
    end

    def Win32.GetExitCodeProcess(args)
      lpExitCode = [0].pack('L')
      r = Kernel32.GetExitCodeProcess(args[:hProcess].to_i, lpExitCode)
      return :return => r, :lpExitCode => lpExitCode.unpack('L')[0]
    end

    def Win32.GetModuleFileName(args = {})
      args[:nSize] ||= 256
      buffer = "\0" * args[:nSize].to_i
      r = Kernel32.GetModuleFileName(args[:hModule].to_i, buffer, args[:nSize].to_i)
      return :return => r, :lpFilename => buffer.gsub("\0", '')
    end

    def Win32.GetVersionEx
      a = [156, 0, 0, 0, 0, ("\0" * 128), 0, 0, 0, 0, 0].pack('LLLLLa128SSSCC')
      r = Kernel32.GetVersionEx(a)
      a = a.unpack('LLLLLa128SSSCC')
      return :return => r, :dwOSVersionInfoSize => a[0], :dwMajorVersion => a[1], :dwMinorVersion => a[2], :dwBuildNumber => a[3], :dwPlatformId => a[4], :szCSDVersion => a[5].strip, :wServicePackMajor => a[6], :wServicePackMinor => a[7], :wSuiteMask => a[8], :wProductType => a[9]
    end

    module User32
      extend Fiddle::Importer
      dlload 'user32'
      extern 'int MessageBox(int, char*, char*, int)'
    end
    def Win32.MessageBox(args)
      args[:lpCaption] ||= "Lich v#{LICH_VERSION}"
      return User32.MessageBox(args[:hWnd].to_i, args[:lpText], args[:lpCaption], args[:uType].to_i)
    end

    module Advapi32
      extend Fiddle::Importer
      dlload 'advapi32'
      extern 'int GetTokenInformation(int, int, void*, int, void*)'
      extern 'int OpenProcessToken(int, int, void*)'
      extern 'int RegOpenKeyEx(int, char*, int, int, void*)'
      extern 'int RegQueryValueEx(int, char*, void*, void*, void*, void*)'
      extern 'int RegSetValueEx(int, char*, int, int, char*, int)'
      extern 'int RegDeleteValue(int, char*)'
      extern 'int RegCloseKey(int)'
    end
    def Win32.GetTokenInformation(args)
      if args[:TokenInformationClass] == TokenElevation
        token_information_length = SIZEOF_LONG
        token_information = [0].pack('L')
      else
        return nil
      end
      return_length = [0].pack('L')
      r = Advapi32.GetTokenInformation(args[:TokenHandle].to_i, args[:TokenInformationClass], token_information, token_information_length, return_length)
      if args[:TokenInformationClass] == TokenElevation
        return :return => r, :TokenIsElevated => token_information.unpack('L')[0]
      end
    end

    def Win32.OpenProcessToken(args)
      token_handle = [0].pack('L')
      r = Advapi32.OpenProcessToken(args[:ProcessHandle].to_i, args[:DesiredAccess].to_i, token_handle)
      return :return => r, :TokenHandle => token_handle.unpack('L')[0]
    end

    def Win32.RegOpenKeyEx(args)
      phkResult = [0].pack('L')
      r = Advapi32.RegOpenKeyEx(args[:hKey].to_i, args[:lpSubKey].to_s, 0, args[:samDesired].to_i, phkResult)
      return :return => r, :phkResult => phkResult.unpack('L')[0]
    end

    def Win32.RegQueryValueEx(args)
      args[:lpValueName] ||= 0
      lpcbData = [0].pack('L')
      r = Advapi32.RegQueryValueEx(args[:hKey].to_i, args[:lpValueName], 0, 0, 0, lpcbData)
      if r == 0
        lpcbData = lpcbData.unpack('L')[0]
        lpData = String.new.rjust(lpcbData, "\x00")
        lpcbData = [lpcbData].pack('L')
        lpType = [0].pack('L')
        r = Advapi32.RegQueryValueEx(args[:hKey].to_i, args[:lpValueName], 0, lpType, lpData, lpcbData)
        lpType = lpType.unpack('L')[0]
        lpcbData = lpcbData.unpack('L')[0]
        if [REG_EXPAND_SZ, REG_SZ, REG_LINK].include?(lpType)
          lpData.gsub!("\x00", '')
        elsif lpType == REG_MULTI_SZ
          lpData = lpData.gsub("\x00\x00", '').split("\x00")
        elsif lpType == REG_DWORD
          lpData = lpData.unpack('L')[0]
        elsif lpType == REG_QWORD
          lpData = lpData.unpack('Q')[0]
        elsif lpType == REG_BINARY
          # fixme
        elsif lpType == REG_DWORD_BIG_ENDIAN
          # fixme
        else
          # fixme
        end
        return :return => r, :lpType => lpType, :lpcbData => lpcbData, :lpData => lpData
      else
        return :return => r
      end
    end

    def Win32.RegSetValueEx(args)
      if [REG_EXPAND_SZ, REG_SZ, REG_LINK].include?(args[:dwType]) and (args[:lpData].class == String)
        lpData = args[:lpData].dup
        lpData.concat("\x00")
        cbData = lpData.length
      elsif (args[:dwType] == REG_MULTI_SZ) and (args[:lpData].class == Array)
        lpData = args[:lpData].join("\x00").concat("\x00\x00")
        cbData = lpData.length
      elsif (args[:dwType] == REG_DWORD) and (args[:lpData].class == Fixnum)
        lpData = [args[:lpData]].pack('L')
        cbData = 4
      elsif (args[:dwType] == REG_QWORD) and (args[:lpData].class == Fixnum or args[:lpData].class == Bignum)
        lpData = [args[:lpData]].pack('Q')
        cbData = 8
      elsif args[:dwType] == REG_BINARY
        # fixme
        return false
      elsif args[:dwType] == REG_DWORD_BIG_ENDIAN
        # fixme
        return false
      else
        # fixme
        return false
      end
      args[:lpValueName] ||= 0
      return Advapi32.RegSetValueEx(args[:hKey].to_i, args[:lpValueName], 0, args[:dwType], lpData, cbData)
    end

    def Win32.RegDeleteValue(args)
      args[:lpValueName] ||= 0
      return Advapi32.RegDeleteValue(args[:hKey].to_i, args[:lpValueName])
    end

    def Win32.RegCloseKey(args)
      return Advapi32.RegCloseKey(args[:hKey])
    end

    module Shell32
      extend Fiddle::Importer
      dlload 'shell32'
      extern 'int ShellExecuteEx(void*)'
      extern 'int ShellExecute(int, char*, char*, char*, char*, int)'
    end
    def Win32.ShellExecuteEx(args)
      #         struct = [ (SIZEOF_LONG * 15), 0, 0, 0, 0, 0, 0, SW_SHOWNORMAL, 0, 0, 0, 0, 0, 0, 0 ]
      struct = [(SIZEOF_LONG * 15), 0, 0, 0, 0, 0, 0, SW_SHOW, 0, 0, 0, 0, 0, 0, 0]
      struct_index = { :cbSize => 0, :fMask => 1, :hwnd => 2, :lpVerb => 3, :lpFile => 4, :lpParameters => 5, :lpDirectory => 6, :nShow => 7, :hInstApp => 8, :lpIDList => 9, :lpClass => 10, :hkeyClass => 11, :dwHotKey => 12, :hIcon => 13, :hMonitor => 13, :hProcess => 14 }
      for sym in [:lpVerb, :lpFile, :lpParameters, :lpDirectory, :lpIDList, :lpClass]
        if args[sym]
          args[sym] = "#{args[sym]}\0" unless args[sym][-1, 1] == "\0"
          struct[struct_index[sym]] = Fiddle::Pointer.to_ptr(args[sym]).to_i
        end
      end
      for sym in [:fMask, :hwnd, :nShow, :hkeyClass, :dwHotKey, :hIcon, :hMonitor, :hProcess]
        if args[sym]
          struct[struct_index[sym]] = args[sym]
        end
      end
      struct = struct.pack('LLLLLLLLLLLLLLL')
      r = Shell32.ShellExecuteEx(struct)
      struct = struct.unpack('LLLLLLLLLLLLLLL')
      return :return => r, :hProcess => struct[struct_index[:hProcess]], :hInstApp => struct[struct_index[:hInstApp]]
    end

    def Win32.ShellExecute(args)
      args[:lpOperation] ||= 0
      args[:lpParameters] ||= 0
      args[:lpDirectory] ||= 0
      args[:nShowCmd] ||= 1
      return Shell32.ShellExecute(args[:hwnd].to_i, args[:lpOperation], args[:lpFile], args[:lpParameters], args[:lpDirectory], args[:nShowCmd])
    end

    begin
      module Kernel32
        extern 'int EnumProcesses(void*, int, void*)'
      end
      def Win32.EnumProcesses(args = {})
        args[:cb] ||= 400
        pProcessIds = Array.new((args[:cb] / SIZEOF_LONG), 0).pack(''.rjust((args[:cb] / SIZEOF_LONG), 'L'))
        pBytesReturned = [0].pack('L')
        r = Kernel32.EnumProcesses(pProcessIds, args[:cb], pBytesReturned)
        pBytesReturned = pBytesReturned.unpack('L')[0]
        return :return => r, :pProcessIds => pProcessIds.unpack(''.rjust((args[:cb] / SIZEOF_LONG), 'L'))[0...(pBytesReturned / SIZEOF_LONG)], :pBytesReturned => pBytesReturned
      end
    rescue
      module Psapi
        extend Fiddle::Importer
        dlload 'psapi'
        extern 'int EnumProcesses(void*, int, void*)'
      end
      def Win32.EnumProcesses(args = {})
        args[:cb] ||= 400
        pProcessIds = Array.new((args[:cb] / SIZEOF_LONG), 0).pack(''.rjust((args[:cb] / SIZEOF_LONG), 'L'))
        pBytesReturned = [0].pack('L')
        r = Psapi.EnumProcesses(pProcessIds, args[:cb], pBytesReturned)
        pBytesReturned = pBytesReturned.unpack('L')[0]
        return :return => r, :pProcessIds => pProcessIds.unpack(''.rjust((args[:cb] / SIZEOF_LONG), 'L'))[0...(pBytesReturned / SIZEOF_LONG)], :pBytesReturned => pBytesReturned
      end
    end

    def Win32.isXP?
      return (Win32.GetVersionEx[:dwMajorVersion] < 6)
    end

    #      def Win32.isWin8?
    #         r = Win32.GetVersionEx
    #         return ((r[:dwMajorVersion] == 6) and (r[:dwMinorVersion] >= 2))
    #      end
    def Win32.admin?
      if Win32.isXP?
        return true
      else
        r = Win32.OpenProcessToken(:ProcessHandle => Win32.GetCurrentProcess, :DesiredAccess => TOKEN_QUERY)
        token_handle = r[:TokenHandle]
        r = Win32.GetTokenInformation(:TokenInformationClass => TokenElevation, :TokenHandle => token_handle)
        return (r[:TokenIsElevated] != 0)
      end
    end

    def Win32.AdminShellExecute(args)
      # open ruby/lich as admin and tell it to open something else
      if not caller.any? { |c| c =~ /eval|run/ }
        r = Win32.GetModuleFileName
        if r[:return] > 0
          if File.exists?(r[:lpFilename])
            Win32.ShellExecuteEx(:lpVerb => 'runas', :lpFile => r[:lpFilename], :lpParameters => "#{File.expand_path($PROGRAM_NAME)} shellexecute #{[Marshal.dump(args)].pack('m').gsub("\n", '')}")
          end
        end
      end
    end
  end
else
  if arg = ARGV.find { |a| a =~ /^--wine=.+$/i }
    $wine_bin = arg.sub(/^--wine=/, '')
  else
    begin
      $wine_bin = `which wine`.strip
    rescue
      $wine_bin = nil
    end
  end
  if arg = ARGV.find { |a| a =~ /^--wine-prefix=.+$/i }
    $wine_prefix = arg.sub(/^--wine-prefix=/, '')
  elsif ENV['WINEPREFIX']
    $wine_prefix = ENV['WINEPREFIX']
  elsif ENV['HOME']
    $wine_prefix = ENV['HOME'] + '/.wine'
  else
    $wine_prefix = nil
  end
  if $wine_bin and File.exists?($wine_bin) and File.file?($wine_bin) and $wine_prefix and File.exists?($wine_prefix) and File.directory?($wine_prefix)
    module Wine
      BIN = $wine_bin
      PREFIX = $wine_prefix
      def Wine.registry_gets(key)
        hkey, subkey, thingie = /(HKEY_LOCAL_MACHINE|HKEY_CURRENT_USER)\\(.+)\\([^\\]*)/.match(key).captures # fixme: stupid highlights ]/
        if File.exist?(PREFIX + '/system.reg')
          if hkey == 'HKEY_LOCAL_MACHINE'
            subkey = "[#{subkey.gsub('\\', '\\\\\\')}]"
            if thingie.nil? or thingie.empty?
              thingie = '@'
            else
              thingie = "\"#{thingie}\""
            end
            lookin = result = false
            File.open(PREFIX + '/system.reg') { |f| f.readlines }.each { |line|
              if line[0...subkey.length] == subkey
                lookin = true
              elsif line =~ /^\[/
                lookin = false
              elsif lookin and line =~ /^#{thingie}="(.*)"$/i
                result = $1.split('\\"').join('"').split('\\\\').join('\\').sub(/\\0$/, '')
                break
              end
            }
            return result
          else
            return false
          end
        else
          return false
        end
      end

      def Wine.registry_puts(key, value)
        hkey, subkey, thingie = /(HKEY_LOCAL_MACHINE|HKEY_CURRENT_USER)\\(.+)\\([^\\]*)/.match(key).captures # fixme ]/
        if File.exists?(PREFIX)
          if thingie.nil? or thingie.empty?
            thingie = '@'
          else
            thingie = "\"#{thingie}\""
          end
          # gsub sucks for this..
          value = value.split('\\').join('\\\\')
          value = value.split('"').join('\"')
          begin
            regedit_data = "REGEDIT4\n\n[#{hkey}\\#{subkey}]\n#{thingie}=\"#{value}\"\n\n"
            filename = "#{TEMP_DIR}/wine-#{Time.now.to_i}.reg"
            File.open(filename, 'w') { |f| f.write(regedit_data) }
            system("#{BIN} regedit #{filename}")
            sleep 0.2
            File.delete(filename)
          rescue
            return false
          end
          return true
        end
      end
    end
  end
  $wine_bin = nil
  $wine_prefix = nil
end

if ARGV[0] == 'shellexecute'
  args = Marshal.load(ARGV[1].unpack('m')[0])
  Win32.ShellExecute(:lpOperation => args[:op], :lpFile => args[:file], :lpDirectory => args[:dir], :lpParameters => args[:params])
  exit
end

## End of TODO

# Setup common variables needed for installing gems correctly on Win32 systems.
gem_file = nil
gem_default_parameters = "--source http://rubygems.org --no-document --platform ruby"
gem_verb = nil
if defined?(Win32)
  r = Win32.GetModuleFileName

  if r[:return] > 0
    ruby_bin_dir = File.dirname(r[:lpFilename])

    if File.exists?("#{ruby_bin_dir}\\gem.cmd")
      gem_file = "#{ruby_bin_dir}\\gem.cmd"
    elsif File.exists?("#{ruby_bin_dir}\\gem.bat")
      gem_file = "#{ruby_bin_dir}\\gem.bat"
    end
  end

  gem_verb = (Win32.isXP? ? 'open' : 'runas')
end

required_modules = [
  # :name -> The module to require/install
  # :version -> The version of the module to require/install
  # :reason ->  Displayed to the used. This should make sense in the sentence "Lich needs {:name} {:reason}, but it is not installed."
  # :condition -> Optional action which returns true/false if the module is required for this invocation
  # :postinstall -> Optiona; action to take if the module is sucessfully 'require'ed
  {
    :name => 'sqlite3',
    :version => '1.3.13',
    :reason => 'to save settings and data',
  },
  {
    :name => 'gtk3',
    :version => '4.0.3',
    :reason => 'to create windows',
    :condition => lambda { return
            # from line 656 - must be true
            (((RUBY_PLATFORM =~ /mingw|win/i) and (RUBY_PLATFORM !~ /darwin/i)) or ENV['DISPLAY'])
            and
            # Previously, GTK3 was considered optional under these conditions. The code would attempt to 'require' it,
            # then succeed (but not set HAVE_GTK = false) if the original 'require' failed.  (No attempt was made to
            # install it).
            ((ENV['RUN_BY_CRON'].nil? or ENV['RUN_BY_CRON'] == 'false') and ARGV.empty? or ARGV.any? { |arg| arg =~ /^--gui$/ } or not $stdout.isatty)
        }

    :postinstall => lambda { HAVE_GTK = true },
  }
]

required_modules.each{|required_module|
  begin
    if !required_module.key?(:condition) || required_module[:condition].call
      require required_module[:name]

      if required_module.key?(:postinstall)
        required_module[:postinstall].call
      end

    else
      required_module[:result] = "Not required."
    end

  rescue LoadError
    if defined?(Win32)
      result = Win32.MessageBox(:lpText => "Lich needs #{required_module[:name]} #{required_module[:reason]}, but it is not installed.\n\nWould you like to install #{required_module[:name]} now?", :lpCaption => "Lich v#{LICH_VERSION}", :uType => (Win32::MB_YESNO | Win32::MB_ICONQUESTION))

      if result == Win32::IDIYES
        if gem_file
          # fixme: using --source http://rubygems.org to avoid https because it has been failing to validate the certificate on Windows
          result = Win32.ShellExecuteEx(
            :fMask => Win32::SEE_MASK_NOCLOSEPROCESS,
            :lpVerb => gem_verb,
            :lpFile => gem_file,
            :lpParameters => "install #{required_module[:name]} --version #{required_module[:version]} #{gem_default_parameters}")

          if result[:return] > 0
            pid = result[:hProcess]
            # Use to indicate that the hProcess member receives the process handle. This handle is typically used to allow an application to find out when a process created with ShellExecuteEx terminates
            sleep 1 while Win32.GetExitCodeProcess(:hProcess => pid)[:lpExitCode] == Win32::STILL_ACTIVE
            result = Win32.MessageBox(
              :lpText => "Install finished.  Lich will restart now.",
              :lpCaption => "Lich v#{LICH_VERSION}",
              :uType => Win32::MB_OKCANCEL)

          else
            # ShellExecuteEx failed: this seems to happen with an access denied error even while elevated on some random systems
            # We don't wait for this process to exit so install may still be ongoing when we ask to restart lich? Or does lack
            # of :fMask => Win32::SEE_MASK_NOCLOSEPROCESS address that.
            result = Win32.ShellExecute(
                :lpOperation => gem_verb,
                :lpFile => gem_file,
                :lpParameters => "install #{required_module[:name]} --version #{required_module[:version]} #{gem_default_parameters}")

            if result <= 32
              Win32.MessageBox(:lpText => "error: failed to install #{required_module[:name]}.\n\nfailed command: Win32.ShellExecute(:lpOperation => #{gem_verb.inspect}, :lpFile => '#{gem_file}', :lpParameters => \"install sqlite3 --version 1.3.13 #{gem_default_parameters}'\")\n\nerror code: #{Win32.GetLastError}", :lpCaption => "Lich v#{LICH_VERSION}", :uType => (Win32::MB_OK | Win32::MB_ICONERROR))
              exit
            end

            result = Win32.MessageBox(:lpText => "When the installer is finished, click OK to restart Lich.", :lpCaption => "Lich v#{LICH_VERSION}", :uType => Win32::MB_OKCANCEL)
          end

          # Result is either the result of ShellExecute on the gem_file command or the result of
          # requesting that the used clicks OK to restart lich.
          if result == Win32::IDIOK
            if File.exists?("#{ruby_bin_dir}\\rubyw.exe")
              Win32.ShellExecute(:lpOperation => 'open', :lpFile => "#{ruby_bin_dir}\\rubyw.exe", :lpParameters => "\"#{File.expand_path($PROGRAM_NAME)}\"")
              exit
            else
              Win32.MessageBox(:lpText => "error: failed to find rubyw.exe; can't restart Lich for you", :lpCaption => "Lich v#{LICH_VERSION}", :uType => (Win32::MB_OK | Win32::MB_ICONERROR))
              required_module[:result] = "Failed to find rubyw.exe; can't restart Lich."
            end
          else
            # user doesn't want to restart Lich
            required_module[:result] = "Installed, but lich not restarted."
          end

        else
          Win32.MessageBox(:lpText => "error: Could not find gem.cmd or gem.bat in directory #{ruby_bin_dir}", :lpCaption => "Lich v#{LICH_VERSION}", :uType => (Win32::MB_OK | Win32::MB_ICONERROR))
          required_module[:result] = "Could not find gem.cmd or gem.bat in directory #{ruby_bin_dir}."
        end

      else
        # user doesn't want to install gem
        required_module[:result] = "User declined installation."
      end
    else
      # fixme: no module on Linux/Mac
      puts "The #{required_module[:name]} gem is not installed (or failed to load), you may need to: sudo gem install #{required_module[:name]}"
      required_module[:result] = "Install skipped. Not a Win32 platform."
    end
  end
}

unless File.exists?(LICH_DIR)
  begin
    Dir.mkdir(LICH_DIR)
  rescue
    message = "An error occured while attempting to create directory #{LICH_DIR}\n\n"
    if not File.exists?(LICH_DIR.sub(/[\\\/]$/, '').slice(/^.+[\\\/]/).chop)
      message.concat "This was likely because the parent directory (#{LICH_DIR.sub(/[\\\/]$/, '').slice(/^.+[\\\/]/).chop}) doesn't exist."
    elsif defined?(Win32) and (Win32.GetVersionEx[:dwMajorVersion] >= 6) and (dir !~ /^[A-z]\:\\(Users|Documents and Settings)/)
      message.concat "This was likely because Lich doesn't have permission to create files and folders here.  It is recommended to put Lich in your Documents folder."
    else
      message.concat $!
    end
    Lich.msgbox(:message => message, :icon => :error)
    exit
  end
end

Dir.chdir(LICH_DIR)

unless File.exists?(TEMP_DIR)
  begin
    Dir.mkdir(TEMP_DIR)
  rescue
    message = "An error occured while attempting to create directory #{TEMP_DIR}\n\n"
    if not File.exists?(TEMP_DIR.sub(/[\\\/]$/, '').slice(/^.+[\\\/]/).chop)
      message.concat "This was likely because the parent directory (#{TEMP_DIR.sub(/[\\\/]$/, '').slice(/^.+[\\\/]/).chop}) doesn't exist."
    elsif defined?(Win32) and (Win32.GetVersionEx[:dwMajorVersion] >= 6) and (dir !~ /^[A-z]\:\\(Users|Documents and Settings)/)
      message.concat "This was likely because Lich doesn't have permission to create files and folders here.  It is recommended to put Lich in your Documents folder."
    else
      message.concat $!
    end
    Lich.msgbox(:message => message, :icon => :error)
    exit
  end
end

begin
  debug_filename = "#{TEMP_DIR}/debug-#{Time.now.strftime("%Y-%m-%d-%H-%M-%S")}.log"
  $stderr = File.open(debug_filename, 'w')
rescue
  message = "An error occured while attempting to create file #{debug_filename}\n\n"
  if defined?(Win32) and (TEMP_DIR !~ /^[A-z]\:\\(Users|Documents and Settings)/) and not Win32.isXP?
    message.concat "This was likely because Lich doesn't have permission to create files and folders here.  It is recommended to put Lich in your Documents folder."
  else
    message.concat $!
  end
  Lich.msgbox(:message => message, :icon => :error)
  exit
end

$stderr.sync = true
Lich.log "info: Lich #{LICH_VERSION}"
Lich.log "info: Ruby #{RUBY_VERSION}"
Lich.log "info: #{RUBY_PLATFORM}"
# TODO: This is broken with the refactor. Consider how to fix.
required_modules.each{|required_module|
  if required_module.key?(:result)
    Lich.log "#{required_module[:name]} install result: #{required_module[:result]}"
  else
    Lich.log "#{required_module[:name]} install result not recorded."
  end
}

[DATA_DIR, SCRIPT_DIR, "#{SCRIPT_DIR}/custom", MAP_DIR, LOG_DIR, BACKUP_DIR].each{|required_directory|
  unless File.exists?(required_directory)
    begin
      Dir.mkdir(required_directory)
    rescue
      Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
      Lich.msgbox(:message => "An error occured while attempting to create directory #{required_directory}\n\n#{$!}", :icon => :error)
      exit
    end
  end
}

Lich.init_db

#
# only keep the last 20 debug files
#
if Dir.entries(TEMP_DIR).length > 20 # avoid NIL response
  Dir.entries(TEMP_DIR).find_all { |fn| fn =~ /^debug-\d+-\d+-\d+-\d+-\d+-\d+\.log$/ }.sort.reverse[20..-1].each { |oldfile|
    begin
      File.delete("#{TEMP_DIR}/#{oldfile}")
    rescue
      Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
    end
  }
end

if (RUBY_VERSION =~ /^2\.[012]\./)
  begin
    did_trusted_defaults = Lich.db.get_first_value("SELECT value FROM lich_settings WHERE name='did_trusted_defaults';")
  rescue SQLite3::BusyException
    sleep 0.1
    retry
  end
  if did_trusted_defaults.nil?
    Script.trust('repository')
    Script.trust('lnet')
    Script.trust('narost')
    begin
      Lich.db.execute("INSERT INTO lich_settings(name,value) VALUES('did_trusted_defaults', 'yes');")
    rescue SQLite3::BusyException
      sleep 0.1
      retry
    end
  end
end
