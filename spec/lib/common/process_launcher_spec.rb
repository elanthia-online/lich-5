# frozen_string_literal: true

require 'fileutils'
require 'rbconfig'
require 'tmpdir'

require_relative '../../../lib/common/process_launcher'

RSpec.describe Lich::Common::ProcessLauncher do
  let(:spawner) { double('process spawner') }

  it 'uses the executable tuple for a one-element argv' do
    executable = '/Program Files (x86)/Saga/Saga.exe'
    allow(spawner).to receive(:call)
      .with({ 'MODE' => 'lich' }, [executable, 'Saga.exe'])
      .and_return(12_345)

    expect(
      described_class.call({ 'MODE' => 'lich' }, [executable], spawner: spawner)
    ).to eq(12_345)
  end

  it 'passes a multi-element argv without shell interpretation' do
    allow(spawner).to receive(:call)
      .with({}, '/usr/bin/open', '-n', '-b', 'com.auchand.saga')
      .and_return(12_345)

    expect(
      described_class.call({}, ['/usr/bin/open', '-n', '-b', 'com.auchand.saga'], spawner: spawner)
    ).to eq(12_345)
  end

  it 'preserves an empty positional argument' do
    allow(spawner).to receive(:call)
      .with({}, '/bin/client', '')
      .and_return(12_345)

    expect(
      described_class.call({}, ['/bin/client', ''], spawner: spawner)
    ).to eq(12_345)
  end

  it 'runs a real one-element executable whose path contains spaces and parentheses' do
    skip 'POSIX executable fixture' if Gem.win_platform?

    Dir.mktmpdir do |directory|
      executable = File.join(directory, 'Program Files (x86)', 'Saga', 'saga')
      marker = File.join(directory, 'launched')
      FileUtils.mkdir_p(File.dirname(executable))
      File.write(
        executable,
        "#!#{RbConfig.ruby}\nFile.write(ENV.fetch('LICH_PROCESS_LAUNCHER_MARKER'), 'ok')\n"
      )
      File.chmod(0o755, executable)

      pid = described_class.call(
        { 'LICH_PROCESS_LAUNCHER_MARKER' => marker },
        [executable]
      )
      _waited_pid, status = Process.wait2(pid)

      expect(status).to be_success
      expect(File.read(marker)).to eq('ok')
    end
  end

  it 'rejects invalid launch data before spawning' do
    expect(spawner).not_to receive(:call)

    expect { described_class.call(nil, ['/bin/client'], spawner: spawner) }
      .to raise_error(ArgumentError, 'environment must be a Hash')
    expect { described_class.call({}, [], spawner: spawner) }
      .to raise_error(ArgumentError, 'argv must contain a non-empty String executable followed by String arguments')
    expect { described_class.call({}, ['', '--flag'], spawner: spawner) }
      .to raise_error(ArgumentError, 'argv must contain a non-empty String executable followed by String arguments')
    expect { described_class.call({}, ['/bin/client', nil], spawner: spawner) }
      .to raise_error(ArgumentError, 'argv must contain a non-empty String executable followed by String arguments')
  end
end
