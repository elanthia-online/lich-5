# frozen_string_literal: true

require 'rspec'
require_relative '../../../lib/common/ruby_executable'

RSpec.describe Lich::Common::RubyExecutable do
  it 'uses an installed rubyw.exe on Windows' do
    allow(File).to receive(:file?).with('C:/Ruby/bin/rubyw.exe').and_return(true)

    expect(
      described_class.resolve(
        platform_key: :windows,
        configured_ruby: 'C:/Ruby/bin/ruby.exe'
      )
    ).to eq('C:/Ruby/bin/rubyw.exe')
  end

  it 'falls back to the configured Ruby when rubyw.exe is unavailable' do
    allow(File).to receive(:file?).with('C:/Ruby/bin/rubyw.exe').and_return(false)

    expect(
      described_class.resolve(
        platform_key: :windows,
        configured_ruby: 'C:/Ruby/bin/ruby.exe'
      )
    ).to eq('C:/Ruby/bin/ruby.exe')
  end

  it 'falls back when checking rubyw.exe raises a filesystem error' do
    allow(File).to receive(:file?).with('C:/Ruby/bin/rubyw.exe').and_raise(Errno::EACCES)

    expect(
      described_class.resolve(
        platform_key: :windows,
        configured_ruby: 'C:/Ruby/bin/ruby.exe'
      )
    ).to eq('C:/Ruby/bin/ruby.exe')
  end

  it 'returns the configured Ruby unchanged outside Windows' do
    configured_ruby = '/Users/test/.rbenv/versions/4.0.5/bin/ruby'

    expect(
      described_class.resolve(
        platform_key: :darwin,
        configured_ruby: configured_ruby
      )
    ).to eq(configured_ruby)
  end

  it 'returns a Windows Ruby executable unchanged when its suffix is not replaceable' do
    configured_ruby = 'C:/Ruby/bin/ruby34.exe'

    expect(
      described_class.resolve(
        platform_key: :windows,
        configured_ruby: configured_ruby
      )
    ).to eq(configured_ruby)
  end

  it 'rejects a blank configured Ruby executable' do
    expect { described_class.resolve(configured_ruby: '') }
      .to raise_error(ArgumentError, 'configured Ruby executable must not be empty')
  end
end
