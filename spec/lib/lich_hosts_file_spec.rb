# frozen_string_literal: true

require 'rspec'
require 'open3'
require 'rbconfig'

RSpec.describe 'Lich.find_hosts_file on Windows' do
  # Runs the real lib/lich.rb in a child process with a fake Win32 registry
  # and a File.exist? limited to the paths named in EXISTING, so the Windows
  # branch can be exercised on any host without leaking constants into the suite.
  let(:harness) do
    <<~'RUBY'
      module Win32
        HKEY_LOCAL_MACHINE = 0x80000002
        KEY_READ = 0x20019
        CLOSED = []
        def self.RegOpenKeyEx(**) = { return: 0, phkResult: 42 }
        def self.RegQueryValueEx(**)
          value = ENV['DATABASEPATH']
          value.nil? ? { return: 2 } : { return: 0, lpData: value.dup }
        end
        def self.RegCloseKey(hKey:) = CLOSED << hKey
      end
      EXISTING = ENV.fetch('EXISTING', '').split('|')
      File.singleton_class.prepend(Module.new { def exist?(path) = EXISTING.include?(path) })
      LICH_VERSION = 'test'
      require ARGV[0]
      puts Lich.find_hosts_file.inspect
      puts Win32::CLOSED.inspect
    RUBY
  end

  def find_hosts_file(database_path:, existing:, windir: 'C:\Windows', systemroot: nil)
    env = {
      'DATABASEPATH' => database_path,
      'EXISTING'     => existing.join('|'),
      'windir'       => windir,
      'SYSTEMROOT'   => systemroot
    }
    stdout, stderr, status = Open3.capture3(
      env, RbConfig.ruby, '-e', harness, File.expand_path('../../lib/lich.rb', __dir__)
    )
    expect(status.success?).to be(true), stderr
    stdout.lines.map(&:strip)
  end

  it 'expands %SystemRoot% in the registry DataBasePath' do
    hosts = 'C:\Windows\System32\drivers\etc\hosts'
    result, closed = find_hosts_file(database_path: '%SystemRoot%\System32\drivers\etc', existing: [hosts])
    expect(result).to eq(hosts.inspect)
    expect(closed).to eq('[42]')
  end

  it 'honours a relocated DataBasePath instead of the default location' do
    custom = 'C:\Windows\CustomHosts\hosts'
    default = 'C:\Windows\system32\drivers\etc\hosts'
    result, = find_hosts_file(database_path: '%SystemRoot%\CustomHosts', existing: [custom, default])
    expect(result).to eq(custom.inspect)
  end

  it 'expands the variable regardless of case' do
    hosts = 'C:\Windows\System32\drivers\etc\hosts'
    result, = find_hosts_file(database_path: '%systemroot%\System32\drivers\etc', existing: [hosts])
    expect(result).to eq(hosts.inspect)
  end

  it 'uses SYSTEMROOT when windir is unset' do
    hosts = 'E:\WINNT\System32\drivers\etc\hosts'
    result, = find_hosts_file(
      database_path: '%SystemRoot%\System32\drivers\etc', existing: [hosts], windir: nil, systemroot: 'E:\WINNT'
    )
    expect(result).to eq(hosts.inspect)
  end

  it 'uses a literal DataBasePath unchanged' do
    hosts = 'D:\hosts-dir\hosts'
    result, = find_hosts_file(database_path: 'D:\hosts-dir', existing: [hosts])
    expect(result).to eq(hosts.inspect)
  end

  it 'falls back to the windir default when the registry value is missing' do
    default = 'C:\Windows\system32\drivers\etc\hosts'
    result, closed = find_hosts_file(database_path: nil, existing: [default])
    expect(result).to eq(default.inspect)
    expect(closed).to eq('[42]')
  end

  it 'falls back to the windir default when the registry path has no hosts file' do
    default = 'C:\Windows\system32\drivers\etc\hosts'
    result, = find_hosts_file(database_path: '%SystemRoot%\Missing', existing: [default])
    expect(result).to eq(default.inspect)
  end

  it 'returns false when no candidate exists' do
    result, = find_hosts_file(database_path: '%SystemRoot%\System32\drivers\etc', existing: [])
    expect(result).to eq('false')
  end
end
