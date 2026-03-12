# frozen_string_literal: true

require 'rbconfig'

# Resolve a wine executable from PATH without shelling out.
#
# This avoids OS-specific shell behavior (`which`, backticks, cmd.exe) and keeps
# startup detection consistent across Linux/macOS/Windows Ruby runtimes.
#
# @return [String, nil] absolute path to a runnable wine binary, or nil
def find_wine_binary
  exe_ext = RbConfig::CONFIG['EXEEXT'].to_s
  extensions = exe_ext.empty? ? [''] : [exe_ext, '']

  ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).each do |dir|
    next if dir.nil? || dir.empty?

    extensions.each do |ext|
      candidate = File.join(dir, "wine#{ext}")
      return candidate if File.file?(candidate) && File.executable?(candidate)
    end
  end

  nil
end

# check for Linux | WINE (and maybe in future MacOS | WINE) first due to low population
if (arg = ARGV.find { |a| a =~ /^--wine=.+$/i })
  $wine_bin = arg.sub(/^--wine=/, '')
elsif ARGV.find { |a| a =~ /^--no-wine$/i } || ARGV.include?('--without-frontend')
  $wine_bin = nil
else
  $wine_bin = find_wine_binary
end

unless $wine_bin.nil?
  if (arg = ARGV.find { |a| a =~ /^--wine-prefix=.+$/i })
    $wine_prefix = arg.sub(/^--wine-prefix=/, '')
  elsif ENV['WINEPREFIX']
    $wine_prefix = ENV['WINEPREFIX']
  elsif ENV['HOME']
    $wine_prefix = ENV['HOME'] + '/.wine'
  else
    $wine_prefix = nil
  end

  if $wine_bin and File.exist?($wine_bin) and File.file?($wine_bin) and $wine_prefix and File.exist?($wine_prefix) and File.directory?($wine_prefix)
    module Wine
      BIN = $wine_bin
      PREFIX = $wine_prefix

      # Reads a value from Wine's `system.reg` for `HKEY_LOCAL_MACHINE` keys.
      #
      # @param key [String] registry path, e.g. `HKEY_LOCAL_MACHINE\Software\Foo\Bar`
      # @return [String, false] value string when found, false otherwise
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

      # Writes a registry value through `regedit` using a temporary `.reg` file.
      #
      # @param key [String] registry path, e.g. `HKEY_LOCAL_MACHINE\Software\Foo\Bar`
      # @param value [String] value to persist
      # @return [Boolean, false] true on attempted write path, false on failures
      def Wine.registry_puts(key, value)
        hkey, subkey, thingie = /(HKEY_LOCAL_MACHINE|HKEY_CURRENT_USER)\\(.+)\\([^\\]*)/.match(key).captures # fixme ]/
        if File.exist?(PREFIX)
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
end
