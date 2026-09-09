# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'yaml'

module Lich
  def self.log(_message); end
end

require_relative '../../../lib/common/front-end'
require_relative '../../../lib/common/frontend_settings'
require_relative '../../../lib/common/frontend_locator'

RSpec.describe Lich::Common::FrontendSettings do
  let(:data_dir) { Dir.mktmpdir('lich-frontend-settings') }
  let(:settings_file) { File.join(data_dir, 'frontends.yml') }

  it 'preserves literal whitespace and empty positional arguments through disk reload' do
    arguments = ['--title', '', '  keep me  ', '--next']
    described_class.replace!(data_dir: data_dir,
                             builtins: { 'stormfront' => { 'arguments' => arguments } }, custom: {})
    described_class.load!(data_dir: data_dir)
    expect(described_class.settings_for('stormfront')['arguments']).to eq(arguments)
  end

  it 'rejects invalid argument lists without replacing the file or active configuration' do
    original = described_class.replace!(data_dir: data_dir,
                                        builtins: { 'stormfront' => { 'arguments' => ['--valid'] } }, custom: {})
    before = File.binread(settings_file)
    invalid_lists = [false, '--not-an-array', ['--title', 12, '--next'], ["bad\nargument"],
                     ["bad\0argument"], ['x' * (described_class::MAX_SCALAR_BYTES + 1)],
                     Array.new(described_class::MAX_ARGUMENTS + 1, '--extra')]
    invalid_lists.each do |arguments|
      expect do
        described_class.replace!(data_dir: data_dir,
                                 builtins: { 'stormfront' => { 'arguments' => arguments } }, custom: {})
      end.to raise_error(ArgumentError)
      expect(File.binread(settings_file)).to eq(before)
      expect(described_class.current).to eq(original)
    end
  end

  it 'retains the last usable catalog when a hand-edited argument list is invalid' do
    original = described_class.replace!(data_dir: data_dir,
                                        builtins: { 'stormfront' => { 'arguments' => ['--valid'] } }, custom: {})
    invalid = { 'version' => 1, 'custom' => {
      'test-client' => { 'label' => 'Test', 'command' => '/opt/test', 'arguments' => ['--title', false, '--next'] }
    } }
    File.write(settings_file, YAML.dump(invalid))
    before = File.binread(settings_file)
    expect(described_class.load!(data_dir: data_dir)).to eq(original)
    expect(File.binread(settings_file)).to eq(before)
  end

  after do
    described_class.replace!(data_dir: data_dir, builtins: {}, custom: {})
    FileUtils.rm_rf(data_dir)
  end

  it 'round-trips built-in overrides and custom frontend definitions separately from login entries' do
    configuration = described_class.replace!(
      data_dir: data_dir,
      builtins: {
        'stormfront' => {
          'executable' => '/opt/wrayth/Wrayth.exe',
          'arguments'  => ['--wine-prefix', '/games/lich']
        }
      },
      custom: {
        'vellum' => {
          'label'        => 'VellumFE',
          'command'      => '/opt/vellum/vellum-fe',
          'directory'    => '/opt/vellum',
          'arguments'    => ['--profile', 'Tsetem'],
          'capabilities' => %w[xml streams room_window]
        }
      }
    )

    expect(configuration).to eq(
      'version'  => 1,
      'builtins' => {
        'stormfront' => {
          'executable' => '/opt/wrayth/Wrayth.exe',
          'arguments'  => ['--wine-prefix', '/games/lich']
        }
      },
      'custom'   => {
        'vellum' => {
          'label'        => 'VellumFE',
          'command'      => '/opt/vellum/vellum-fe',
          'directory'    => '/opt/vellum',
          'arguments'    => ['--profile', 'Tsetem'],
          'capabilities' => %w[xml streams room_window]
        }
      }
    )
    expect(YAML.safe_load_file(settings_file)).to eq(configuration)
    expect(File).not_to exist(File.join(data_dir, 'entry.yaml'))

    expect(described_class.load!(data_dir: data_dir)).to eq(configuration)
    expect(described_class.settings_for('wrayth')).to eq(
      'executable' => '/opt/wrayth/Wrayth.exe',
      'arguments'  => ['--wine-prefix', '/games/lich']
    )

    wrayth = Lich::Common::Frontend.definition_for('stormfront')
    expect(wrayth.dig(:metadata, :configured_executable)).to eq('/opt/wrayth/Wrayth.exe')
    expect(wrayth.dig(:metadata, :additional_arguments)).to eq(['--wine-prefix', '/games/lich'])
    expect(wrayth[:capabilities]).to include(:xml, :room_window)

    vellum = Lich::Common::Frontend.definition_for('vellum')
    expect(vellum.dig(:metadata, :display_name)).to eq('VellumFE')
    expect(vellum.dig(:metadata, :launch_command)).to eq('/opt/vellum/vellum-fe')
    expect(vellum.dig(:metadata, :launch_directory)).to eq('/opt/vellum')
    expect(vellum.dig(:metadata, :additional_arguments)).to eq(['--profile', 'Tsetem'])
    expect(vellum[:capabilities]).to contain_exactly(:xml, :streams, :room_window)
  end

  it 'drops malformed and unauthorized fields while keeping valid definitions usable' do
    File.write(
      settings_file,
      {
        'version'  => 1,
        'builtins' => {
          'Wrayth'      => {
            'executable'   => " /games/Wrayth.exe \n",
            'arguments'    => ['--safe', ''],
            'capabilities' => ['gsl'],
            'label'        => 'Not authoritative'
          },
          'not_builtin' => { 'executable' => '/tmp/nope' }
        },
        'custom'   => {
          'stormfront'      => {
            'label'        => 'Cannot replace a built-in',
            'command'      => '/tmp/not-allowed',
            'capabilities' => ['gsl']
          },
          'not a stable id' => {
            'label'   => 'Invalid',
            'command' => '/tmp/invalid'
          },
          'missing-command' => { 'label' => 'Invalid' },
          'good_custom'     => {
            'label'        => ' Good Frontend ',
            'command'      => ' /opt/good/frontend ',
            'directory'    => 7,
            'arguments'    => ['--one'],
            'capabilities' => ['XML', 'unknown', 'streams', 5]
          }
        }
      }.to_yaml
    )

    configuration = described_class.load!(data_dir: data_dir)

    expect(configuration).to eq(
      'version'  => 1,
      'builtins' => {
        'stormfront' => {
          'executable' => '/games/Wrayth.exe',
          'arguments'  => ['--safe', '']
        }
      },
      'custom'   => {
        'good_custom' => {
          'label'        => 'Good Frontend',
          'command'      => '/opt/good/frontend',
          'arguments'    => ['--one'],
          'capabilities' => %w[xml streams]
        }
      }
    )
    expect(Lich::Common::Frontend.definition_for('stormfront')[:capabilities]).not_to include(:gsl)
    expect(Lich::Common::Frontend.definition_for('good_custom')[:capabilities]).to contain_exactly(:xml, :streams)
    expect { Lich::Common::Frontend.definition_for('not a stable id') }.to raise_error(ArgumentError)
  end

  it 'removes deleted custom definitions and built-in overrides when configuration reloads' do
    described_class.replace!(
      data_dir: data_dir,
      builtins: { 'wizard' => { 'arguments' => ['--first'] } },
      custom: {
        'temporary' => {
          'label'        => 'Temporary',
          'command'      => '/tmp/temporary',
          'capabilities' => ['xml']
        }
      }
    )

    expect(Lich::Common::Frontend.definition_for('temporary')).not_to be_nil
    expect(Lich::Common::Frontend.definition_for('wizard').dig(:metadata, :additional_arguments)).to eq(['--first'])

    File.write(settings_file, { 'version' => 1, 'builtins' => {}, 'custom' => {} }.to_yaml)
    described_class.load!(data_dir: data_dir)

    expect { Lich::Common::Frontend.definition_for('temporary') }
      .to raise_error(ArgumentError, 'unknown frontend: temporary')
    expect(Lich::Common::Frontend.definition_for('wizard').dig(:metadata, :additional_arguments)).to be_nil
  end

  it 'does not apply or overwrite an unsupported future schema version' do
    future_document = {
      'version'      => 2,
      'future_field' => { 'must' => 'survive' },
      'custom'       => {
        'future_frontend' => {
          'label'   => 'Future Frontend',
          'command' => '/future/frontend'
        }
      }
    }
    File.write(settings_file, future_document.to_yaml)

    expect(Lich).to receive(:log).with(/frontends\.yml uses unsupported schema version 2/).at_least(:once)
    expect(described_class.load!(data_dir: data_dir)).to eq(
      'version'  => 1,
      'builtins' => {},
      'custom'   => {}
    )
    expect { Lich::Common::Frontend.definition_for('future_frontend') }.to raise_error(ArgumentError)

    expect do
      described_class.replace!(data_dir: data_dir, builtins: {}, custom: {})
    end.to raise_error(described_class::UnsupportedVersionError, /refusing to overwrite/)
    expect(YAML.safe_load_file(settings_file)).to eq(future_document)

    File.write(settings_file, { 'version' => 1, 'builtins' => {}, 'custom' => {} }.to_yaml)
    expect { described_class.replace!(data_dir: data_dir, builtins: {}, custom: {}) }.not_to raise_error
  end

  it 'keeps legacy capability constants stable while live queries include custom frontends' do
    legacy_xml_frontends = Lich::Common::Frontend::XML_FRONTENDS.dup

    described_class.replace!(
      data_dir: data_dir,
      builtins: {},
      custom: {
        'vellum_live' => {
          'label'        => 'Vellum Live',
          'command'      => '/opt/vellum-live',
          'capabilities' => ['xml']
        }
      }
    )

    expect(Lich::Common::Frontend.supports_xml?('vellum_live')).to be(true)
    expect(Lich::Common::Frontend.frontends_with_capability(:xml)).to include('vellum_live')
    expect(Lich::Common::Frontend::XML_FRONTENDS).to eq(legacy_xml_frontends)
    expect(Lich::Common::Frontend::XML_FRONTENDS).not_to include('vellum_live')
  end

  it 'restores authoritative built-in aliases on every configuration replacement' do
    Lich::Common::Frontend.register('stormfront', metadata: { aliases: ['rogue_wrayth_alias'] })
    expect(Lich::Common::Frontend.canonical_name('rogue_wrayth_alias')).to eq('stormfront')

    described_class.replace!(data_dir: data_dir, builtins: {}, custom: {})

    expect(Lich::Common::Frontend.canonical_name('wrayth')).to eq('stormfront')
    expect(Lich::Common::Frontend.canonical_name('rogue_wrayth_alias')).to eq('rogue_wrayth_alias')
    expect(Lich::Common::Frontend.registered_frontends).not_to include('rogue_wrayth_alias')
  end

  it 'drops custom registry and alias collisions without merging or deleting their owners' do
    frontend = Lich::Common::Frontend
    registry = frontend.instance_variable_get(:@registry)
    aliases = frontend.instance_variable_get(:@aliases)
    definitions = frontend.instance_variable_get(:@definitions)

    begin
      described_class.replace!(
        data_dir: data_dir,
        builtins: {},
        custom: {
          'preserved_custom' => {
            'label'        => 'Preserved Custom',
            'command'      => '/opt/preserved',
            'capabilities' => ['xml']
          }
        }
      )
      frontend.register(
        'runtime_frontend',
        capabilities: [:gsl],
        metadata: { display_name: 'Runtime Frontend', aliases: ['runtime_alias'] }
      )
      File.write(
        settings_file,
        {
          'version' => 1,
          'custom'  => {
            'preserved_custom' => {
              'label'        => 'Preserved Custom Reloaded',
              'command'      => '/opt/preserved-reloaded',
              'capabilities' => ['streams']
            },
            'runtime_frontend' => {
              'label'        => 'Collision',
              'command'      => '/opt/collision',
              'capabilities' => ['xml']
            },
            'runtime_alias'    => {
              'label'   => 'Alias Collision',
              'command' => '/opt/alias-collision'
            },
            'wrayth'           => {
              'label'   => 'Built-in Alias Collision',
              'command' => '/opt/wrayth-collision'
            }
          }
        }.to_yaml
      )

      configuration = described_class.load!(data_dir: data_dir)

      expect(configuration.fetch('custom').keys).to eq(['preserved_custom'])
      expect(frontend.definition_for('preserved_custom')[:capabilities]).to eq([:streams])
      expect(frontend.definition_for('runtime_frontend')[:capabilities]).to eq([:gsl])
      expect(frontend.definition_for('runtime_frontend').dig(:metadata, :display_name)).to eq('Runtime Frontend')
      expect(frontend.canonical_name('runtime_alias')).to eq('runtime_frontend')

      described_class.replace!(data_dir: data_dir, builtins: {}, custom: {})
      expect(frontend.definition_for('runtime_frontend')[:capabilities]).to eq([:gsl])
      expect(frontend.canonical_name('runtime_alias')).to eq('runtime_frontend')
    ensure
      registry.delete('runtime_frontend')
      aliases.delete('runtime_alias')
      definitions.delete('runtime_frontend')
    end
  end

  it 'rejects runtime registrations that would merge with a settings-owned identifier' do
    described_class.replace!(
      data_dir: data_dir,
      builtins: {},
      custom: {
        'settings_owned' => {
          'label'   => 'Settings Owned',
          'command' => '/opt/settings-owned'
        }
      }
    )

    expect do
      Lich::Common::Frontend.register('settings_owned', capabilities: [:gsl])
    end.to raise_error(ArgumentError, /managed by user settings/)
    expect do
      Lich::Common::Frontend.register('runtime_owner', metadata: { aliases: ['settings_owned'] })
    end.to raise_error(ArgumentError, /managed by user settings/)
    expect(Lich::Common::Frontend.definition_for('settings_owned')[:capabilities]).to be_empty
    expect(Lich::Common::Frontend.registered_frontends).not_to include('runtime_owner')
  end

  it 'rolls back the catalog when a replacement fails after mutation begins' do
    described_class.replace!(
      data_dir: data_dir,
      builtins: {},
      custom: {
        'preserved_custom' => {
          'label'   => 'Preserved Custom',
          'command' => '/opt/preserved'
        }
      }
    )
    original_stormfront = Lich::Common::Frontend.definition_for('stormfront')
    original_custom = Lich::Common::Frontend.definition_for('preserved_custom')

    expect do
      Lich::Common::Frontend.replace_user_configuration!(
        built_in_overrides: { 'stormfront' => { executable: '/opt/replaced' } },
        custom_definitions: { 'broken' => { label: 'Broken' } }
      )
    end.to raise_error(KeyError)

    expect(Lich::Common::Frontend.definition_for('stormfront')).to eq(original_stormfront)
    expect(Lich::Common::Frontend.definition_for('preserved_custom')).to eq(original_custom)
    expect(Lich::Common::Frontend.registered_frontends).not_to include('broken')
  end

  it 'keeps readers from observing a replacement in progress' do
    entered_replacement = Queue.new
    release_replacement = Queue.new
    reader_started = Queue.new
    reader_result = Queue.new
    writer_errors = Queue.new
    custom_definitions = {
      'threaded_custom' => {
        label: 'Threaded Custom',
        command: '/opt/threaded',
        arguments: [],
        capabilities: []
      }
    }
    custom_definitions.define_singleton_method(:each) do |&block|
      entered_replacement << true
      release_replacement.pop
      super(&block)
    end

    writer = Thread.new do
      Lich::Common::Frontend.replace_user_configuration!(
        built_in_overrides: {},
        custom_definitions: custom_definitions
      )
    rescue StandardError => error
      writer_errors << error
    end
    entered_replacement.pop
    reader = Thread.new do
      reader_started << true
      reader_result << Lich::Common::Frontend.registered_frontends
    end
    reader_started.pop
    100.times do
      break if reader.status == 'sleep'

      Thread.pass
    end

    expect(reader_result).to be_empty
    expect(reader.status).to eq('sleep')

    release_replacement << true
    writer.join
    reader.join

    expect(writer_errors).to be_empty
    expect(reader_result.pop).to include('threaded_custom')
  ensure
    release_replacement << true if writer&.alive?
    writer&.join
    reader&.join
  end

  it 'prefers a configured executable before automatic discovery' do
    executable = File.join(data_dir, 'custom-wrayth')
    File.write(executable, '#!/bin/sh')
    File.chmod(0o755, executable)
    described_class.replace!(
      data_dir: data_dir,
      builtins: { 'stormfront' => { 'executable' => executable } },
      custom: {}
    )
    locator = Lich::Common::FrontendLocator.new(
      platform_key: :linux,
      environment: { 'PATH' => '' },
      wine: nil
    )

    resolution = locator.resolve('stormfront')

    expect(resolution.executable_path).to eq(File.realpath(executable))
    expect(resolution.source).to eq(:configured)
  end

  it 'falls back to discovery when a configured executable has gone missing' do
    executable_directory = File.join(data_dir, 'bin')
    FileUtils.mkdir_p(executable_directory)
    discovered_executable = File.join(executable_directory, 'Wrayth.exe')
    File.write(discovered_executable, '#!/bin/sh')
    File.chmod(0o755, discovered_executable)
    described_class.replace!(
      data_dir: data_dir,
      builtins: { 'stormfront' => { 'executable' => File.join(data_dir, 'missing') } },
      custom: {}
    )
    locator = Lich::Common::FrontendLocator.new(
      platform_key: :linux,
      environment: { 'PATH' => executable_directory },
      wine: nil
    )

    resolution = locator.resolve('stormfront')

    expect(resolution.executable_path).to eq(File.realpath(discovered_executable))
    expect(resolution.source).to eq(:path)
  end

  it 'treats a missing or non-hash file as an empty configuration' do
    expect(described_class.load!(data_dir: data_dir)).to eq(
      'version'  => 1,
      'builtins' => {},
      'custom'   => {}
    )

    File.write(settings_file, ['not', 'a', 'mapping'].to_yaml)
    expect(described_class.load!(data_dir: data_dir)).to eq(
      'version'  => 1,
      'builtins' => {},
      'custom'   => {}
    )
  end
end
