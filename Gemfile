=begin
When building Gemfile.lock file, please add additional platforms to the file via the following command:

bundle lock \
  --add-platform aarch64-linux \
  --add-platform aarch64-linux-gnu \
  --add-platform aarch64-linux-musl \
  --add-platform arm-linux \
  --add-platform arm-linux-gnu \
  --add-platform arm-linux-musl \
  --add-platform arm64-darwin \
  --add-platform x64-mingw \
  --add-platform x64-mingw-ucrt \
  --add-platform x86-darwin \
  --add-platform x86-linux \
  --add-platform x86-linux-gnu \
  --add-platform x86-linux-musl \
  --add-platform x86-mingw \
  --add-platform x86-mingw-ucrt \
  --add-platform x86_64-darwin \
  --add-platform x86_64-linux \
  --add-platform x86_64-linux-gnu \
  --add-platform x86_64-linux-musl

This ensures that the lock file can be used by all platforms that are able to support it.
=end

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

group :development do
  gem "rspec"
  gem "rubocop"
end

gem "ascii_charts", ">= 0.9.1"

gem "base64", ">= 0.1.0"

gem "concurrent-ruby", ">= 1.2"

gem "ffi", ">= 1.17"

gem "logger", ">= 1.6.4"

gem "os", ">= 1.1"
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
