source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

group :development do
  gem "rspec"
  gem 'rubocop'
end

gem "ascii_charts", ">= 0.9"
gem "benchmark", ">= 0.4"
gem "concurrent-ruby", ">= 1.2"
gem "digest", ">= 3.2"
gem "drb", ">= 2.2"
gem "ffi", ">= 1.17"
gem "fiddle", ">= 1.1"
gem "fileutils", ">= 1.7"
gem "gtk3", ">= 4.3", platforms: [:windows, :mingw, :mswin, :x64_mingw]
gem "json", ">= 2.9"
gem "logger", ">= 1.6"
gem "openssl", ">= 3.3"
gem "open-uri", ">= 0.5"
gem "os", ">= 1.1"
gem "ostruct", ">= 0.6"
gem "rake", ">= 13.2"
gem "redis", ">= 5.4"
gem "resolv", ">= 0.6"
gem "rexml", ">= 3.4"
gem "sequel", ">= 5.66"
gem "set", ">= 1.1"
gem "tempfile", ">= 0.3"
gem "terminal-table", ">= 3.0"
gem "time", ">= 0.4"
gem "tmpdir", ">= 0.3"
gem "tzinfo", ">= 2.0"
gem "tzinfo-data", ">= 1.2025"
gem "webrick", ">= 1.9"
gem "win32ole", ">= 1.9", platforms: [:windows, :mingw, :mswin, :x64_mingw]
gem "yaml", ">= 0.4"
gem "zlib", ">= 3.2"

if Gem.win_platform?
  gem "sqlite3", ">= 1.6", platforms: [:windows, :mingw, :mswin, :x64_mingw], force_ruby_platform: true
else
  gem "sqlite3", ">= 1.6"
end
