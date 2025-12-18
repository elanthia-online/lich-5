source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Windows 32-bit (legacy)
lock_platform "x86-mingw"             # 32-bit Windows with MinGW (Ruby 2.4-3.0)
lock_platform "x86-mingw-ucrt"        # 32-bit Windows with UCRT (Ruby 3.1+)

# Windows 64-bit
lock_platform "x64-mingw"             # 64-bit Windows with MinGW (Ruby 2.4-3.0)
lock_platform "x64-mingw-ucrt"        # 64-bit Windows with UCRT (Ruby 3.1+, recommended)

# macOS Intel 32-bit (legacy)
lock_platform "x86-darwin"            # Old 32-bit Intel Macs (pre-2010, rarely used)

# macOS Intel 64-bit
lock_platform "x86_64-darwin"         # 64-bit Intel Macs (2006-2020)

# macOS ARM64 (Apple Silicon)
lock_platform "arm64-darwin"          # Apple M1/M2/M3/M4 Macs

# Linux Intel/AMD 32-bit
lock_platform "x86-linux"             # Generic 32-bit x86 Linux
lock_platform "x86-linux-gnu"         # 32-bit x86 Linux with GNU libc
lock_platform "x86-linux-musl"        # 32-bit x86 Linux with musl libc (Alpine)

# Linux Intel/AMD 64-bit
lock_platform "x86_64-linux"          # Generic 64-bit x86_64 Linux
lock_platform "x86_64-linux-gnu"      # 64-bit x86_64 Linux with GNU libc (most common)
lock_platform "x86_64-linux-musl"     # 64-bit x86_64 Linux with musl libc (Alpine, Docker)

# Linux ARM 32-bit platforms
lock_platform "arm-linux"             # Generic 32-bit ARM Linux (older Raspberry Pi, embedded)
lock_platform "arm-linux-gnu"         # 32-bit ARM Linux with GNU libc
lock_platform "arm-linux-musl"        # 32-bit ARM Linux with musl libc (Alpine)

# Linux ARM64 platforms
lock_platform "aarch64-linux"         # Generic ARM64 Linux (e.g., AWS Graviton, Raspberry Pi 4/5)
lock_platform "aarch64-linux-gnu"     # ARM64 Linux with GNU libc (most standard Linux distros)
lock_platform "aarch64-linux-musl"    # ARM64 Linux with musl libc (Alpine Linux, containers)

group :development do
  gem "rspec"
  gem "rubocop"
end

group :vscode do
  gem "rbs"
  gem "prism"
  gem "sorbet-runtime"
  gem "ruby-lsp"
end

group :gtk do
  gem "gtk3", ">= 4.3"
end

group :profanity do
  gem "curses"
end

# External gems where versions matter
gem "concurrent-ruby", ">= 1.2"
gem "kramdown", ">= 2.5"
gem "redis", ">= 5.4"
gem "sequel", ">= 5.66"
gem "terminal-table", ">= 3.0"
gem "tzinfo", ">= 2.0"
gem "tzinfo-data", ">= 1.2025"

# Stdlib gems - version constraints often unnecessary
gem "ascii_charts", ">= 0.9"
gem "benchmark", ">= 0.4"
gem "digest", ">= 3.2"
gem "drb", ">= 2.2"
gem "ffi", ">= 1.17"
gem "fiddle", ">= 1.1"
gem "fileutils", ">= 1.7"
gem "json", ">= 2.9"
gem "logger", ">= 1.6"
gem "openssl", ">= 3.3"
gem "open-uri", ">= 0.5"
gem "os", ">= 1.1"
gem "ostruct", ">= 0.6"
gem "rake", ">= 13.2"
gem "resolv", ">= 0.6"
gem "rexml", ">= 3.4"
gem "set", ">= 1.1"
gem "tempfile", ">= 0.3"
gem "time", ">= 0.4"
gem "tmpdir", ">= 0.3"
gem "webrick", ">= 1.9"
gem "win32ole", ">= 1.9", platforms: :windows
gem "yaml", ">= 0.4"
gem "zlib", ">= 3.2"

if Gem.win_platform?
  gem "sqlite3", ">= 1.6", platforms: :windows, force_ruby_platform: true
else
  gem "sqlite3", ">= 1.6"
end
