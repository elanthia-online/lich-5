# Lich5 carveout to better manage semver

LICH_VERSION = '5.18.0' # x-release-please-version
REQUIRED_RUBY = '2.6'
RECOMMENDED_RUBY = '3.2'

if Gem::Version.new(RUBY_VERSION) < Gem::Version.new(REQUIRED_RUBY)
  if (RUBY_PLATFORM =~ /mingw|win/) and (RUBY_PLATFORM !~ /darwin/i)
    require 'win32ole'
    shell = WIN32OLE.new('WScript.Shell')
    message = "!!ALERT!!\nYour version #{RUBY_VERSION} of Ruby is too old!\nUpgrade Ruby to version #{REQUIRED_RUBY} or newer!\nClick OK to launch browser to go to documentation now!"
    title = "Lich v#{LICH_VERSION}"
    type = 1 + 64  # OK/Cancel buttons + Information icon
    result = shell.Popup(message, 0, title, type)

    if result == 1 # OK button clicked
      shell.Run("https://github.com/elanthia-online/lich-5/wiki/Documentation-for-Installing-and-Upgrading-Lich")
    end
  else
    puts "!!ALERT!!"
    puts "Your version #{RUBY_VERSION} of Ruby is too old!"
    puts "Upgrade Ruby to version #{REQUIRED_RUBY} or newer!"
    puts "Go to https://github.com/elanthia-online/lich-5/wiki/Documentation-for-Installing-and-Upgrading-Lich for more info!"
  end
  exit
end
