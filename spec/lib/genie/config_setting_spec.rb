# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'
require 'tmpdir'

# Lich::Genie::ConfigSetting: Remix Config.SetSetting's runtime contract (Lists/Config.cs:569-1490 R).
# Messages and exceptions pinned by genieflow (flow t214_config_echoes).
RSpec.describe Lich::Genie::ConfigSetting do
  let(:no_file) { ->(_path) { false } }
  let(:dirs) { [] }
  let(:directory) { ->(path) { dirs << path; "Diretory Found: /x/#{path}" } }

  def set(key, value = '', file_exists: no_file)
    described_class.set(key, value, file_exists: file_exists, directory: directory)
  end

  it 'returns Set <lower-cased key>: <value> + the reminder for every recognized key, value as given' do
    expect(set('LichPath', 'C:\\Ruby4Lich5\\Lich5\\lich.rbw')).to eq(['Set lichpath: C:\\Ruby4Lich5\\Lich5\\lich.rbw',
                                                                      "Don't forget to #save config"])
    expect(set('usertimeout', '5.6')).to eq(['Set usertimeout: 5.6', "Don't forget to #save config"])
    expect(set('scriptchar')).to eq(['Set scriptchar: ', "Don't forget to #save config"])
    %w[triggeroninput prompt monstercountignorelist connectstring cmdpath alwaysontop weblinksafety maxrowbuffer]
      .each { |key| expect(set(key, 'zz').first).to eq("Set #{key}: zz") }
  end

  it 'returns nothing for an empty key' do
    expect(set('', 'x')).to eq([])
  end

  it 'raises "Config <key> was not recognized." (lower-cased) for an unknown key' do
    expect { set('BoGus', '1') }.to raise_error(Lich::Genie::Error, 'Config bogus was not recognized.')
  end

  it 'converts maxgosubdepth/historysize/historyminlength with VB ToInteger (3.5 is fine, abc is not)' do
    expect(set('maxgosubdepth', '3.5').first).to eq('Set maxgosubdepth: 3.5')
    expect { set('historysize', 'abc') }.to raise_error(Lich::Genie::Error, "Conversion from string \"abc\" to type 'Integer' is not valid.")
    expect(set('historyminlength', '').first).to eq('Set historyminlength: ') # empty: no conversion
  end

  it 'converts the timeouts through StringToDouble (never a format error; overflow is one)' do
    expect(set('scripttimeout', 'abc').first).to eq('Set scripttimeout: abc') # -1
    expect(set('servertimeout', '1e3').first).to eq('Set servertimeout: 1e3')
    expect { set('usertimeout', '1e300') }.to raise_error(Lich::Genie::Error, 'Arithmetic operation resulted in an overflow.')
  end

  it 'parses lichport/lichstartpause/automapperalpha with Convert.ToInt32, clamping the alpha in the message' do
    expect { set('lichport', 'x') }.to raise_error(Lich::Genie::Error, "The input string 'x' was not in a correct format.")
    expect { set('lichstartpause', '1.5') }.to raise_error(Lich::Genie::Error, "The input string '1.5' was not in a correct format.")
    expect { set('lichport', '99999999999') }.to raise_error(Lich::Genie::Error, 'Value was either too large or too small for an Int32.')
    expect(set('lichport', ' -12 ').first).to eq('Set lichport:  -12 ')
    expect(set('automapperalpha', '300').first).to eq('Set automapperalpha: 255')
    expect(set('automapperalpha', '-4').first).to eq('Set automapperalpha: 0')
  end

  it 'requires an existing file for editor (bShowException)' do
    expect { set('editor', 'notepad.exe') }.to raise_error(Lich::Genie::Error, 'Directory does not exist: notepad.exe')
    expect(set('editor', '/bin/sh', file_exists: ->(p) { p == '/bin/sh' }).first).to eq('Set editor: /bin/sh')
  end

  it 'puts ValidateDirectory\'s message first for every directory key' do
    %w[artdir scriptdir mapdir sounddir plugindir configdir logdir].each do |key|
      expect(set(key, 'd')).to eq(['Diretory Found: /x/d', "Set #{key}: d", "Don't forget to #save config"])
    end
    expect(dirs.length).to eq(7)
  end

  describe '.validate_directory (LocalDirectory.cs:34-51 R)' do
    around { |example| Dir.mktmpdir('genie-cfgdir') { |dir| @dir = File.realpath(dir); example.run } }

    it 'finds an existing one, creates a missing one (create: true) and keeps a trailing separator' do
      expect(described_class.validate_directory('', base: @dir)).to eq("Diretory Found: #{@dir}/")
      expect(described_class.validate_directory('new', base: @dir)).to eq("Directory Created: #{@dir}/new")
      expect(File.directory?(File.join(@dir, 'new'))).to be(true)
      expect(described_class.validate_directory("#{@dir}/new", base: '/elsewhere')).to eq("Diretory Found: #{@dir}/new")
    end

    it 'reports Created without creating when create: false' do
      expect(described_class.validate_directory('ghost', base: @dir, create: false)).to eq("Directory Created: #{@dir}/ghost")
      expect(File.exist?(File.join(@dir, 'ghost'))).to be(false)
    end

    it 'raises "Error Setting Directory: ..." when the directory cannot be made' do
      File.write(File.join(@dir, 'file'), 'x')
      expect { described_class.validate_directory('file/sub', base: @dir) }.to raise_error(Lich::Genie::Error, /\AError Setting Directory: /)
    end
  end
end
