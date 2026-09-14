# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/windows_command_line'
require_relative '../../../lib/common/frontend_launcher'
require_relative '../../../lib/common/process_launcher'
require 'json'

RSpec.describe Lich::Common::WindowsCommandLine do
  it 'preserves quoted executable paths, Windows backslashes, empty arguments and spaces' do
    expect(described_class.split('"C:\\Program Files\\Client\\client.exe" "" "  profile  " C:\\data\\')).to eq(
      ['C:\\Program Files\\Client\\client.exe', '', '  profile  ', 'C:\\data\\']
    )
  end

  it 'handles the documented CRT backslash and quote rules' do
    expect(described_class.split('client a\\\\\\b d"e f"g h')).to eq(['client', 'a\\\\\\b', 'de fg', 'h'])
    expect(described_class.split('client a' + '\\' + '"b c d')).to eq(['client', 'a"b', 'c', 'd'])
    expect(described_class.split('client "a""b"')).to eq(['client', 'a"b'])
    expect(described_class.split('client "C:\\space dir\\\\"')).to eq(['client', 'C:\\space dir\\'])
  end

  it 'rejects unclosed quoting and implicit shell operators' do
    ['client "unfinished', 'client && other', 'client | other', 'client > file', ''].each do |command|
      expect { described_class.split(command) }.to raise_error(ArgumentError)
    end
    expect(described_class.split('"C:\\A & B\\client.exe" "a&b"')).to eq(['C:\\A & B\\client.exe', 'a&b'])
  end

  it 'round-trips additional arguments to a real child without interpreting shell syntax' do
    arguments = ['', '  spaces  ', 'C:\\path with spaces\\', 'say "hello"', '%PATH%', '!PATH!', 'a&b|c>file', '--key=%key%']
    definition = { metadata: { additional_arguments: arguments } }
    launcher = Lich::Common::FrontendLauncher
    argv = launcher.with_additional_arguments('client --fixed', definition, platform_key: :windows)
    expect(argv).to eq(['client', '--fixed', *arguments])
    rendered = launcher.render_connection(argv, host: 'localhost', port: 8000, key: 'test-key')
    reader, writer = IO.pipe
    begin
      pid = Lich::Common::ProcessLauncher.call({}, [RbConfig.ruby, '-rjson', '-e', 'STDOUT.write(JSON.generate(ARGV))', '--', *rendered.drop(1)],
                                               spawner: proc { |*values| Process.spawn(*values, out: writer) })
      writer.close
      actual = JSON.parse(reader.read)
      Process.wait(pid)
      expect(actual).to eq(['--fixed', *arguments[0...-1], '--key=test-key'])
    ensure
      reader.close
      writer.close unless writer.closed?
    end
  end

  it 'preserves empty positional arguments in the POSIX template path too' do
    definition = { metadata: { additional_arguments: ['', '  spaces  '] } }
    command = Lich::Common::FrontendLauncher.with_additional_arguments('client', definition, platform_key: :linux)
    expect(Shellwords.split(command)).to eq(['client', '', '  spaces  '])
  end
end
