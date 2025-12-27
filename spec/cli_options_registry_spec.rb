# frozen_string_literal: true

require 'rspec'
require 'ostruct'

LIB_DIR = File.join(File.expand_path("..", File.dirname(__FILE__)), 'lib')

require File.join(LIB_DIR, 'common', 'cli', 'cli_options_registry.rb')

RSpec.describe Lich::Common::CLI::CliOptionsRegistry do
  before do
    # Reset registry state before each test
    # (Note: In production, registry is singleton; for tests we work with what's there)
  end

  describe '.option' do
    it 'registers an option with metadata' do
      Lich::Common::CLI::CliOptionsRegistry.option :test_option,
                                                   type: :string,
                                                   default: 'default_value'

      option = Lich::Common::CLI::CliOptionsRegistry.get_option(:test_option)
      expect(option).not_to be_nil
      expect(option[:type]).to eq(:string)
      expect(option[:default]).to eq('default_value')
    end

    it 'registers option with deprecation metadata' do
      Lich::Common::CLI::CliOptionsRegistry.option :deprecated_option,
                                                   type: :boolean,
                                                   deprecated: true,
                                                   deprecation_message: 'Use new_option instead'

      option = Lich::Common::CLI::CliOptionsRegistry.get_option(:deprecated_option)
      expect(option[:deprecated]).to be true
      expect(option[:deprecation_message]).to eq('Use new_option instead')
    end

    it 'registers option with mutually exclusive constraints' do
      Lich::Common::CLI::CliOptionsRegistry.option :gui,
                                                   type: :boolean,
                                                   default: true,
                                                   mutually_exclusive: [:no_gui]
      Lich::Common::CLI::CliOptionsRegistry.option :no_gui,
                                                   type: :boolean,
                                                   mutually_exclusive: [:gui]

      gui_option = Lich::Common::CLI::CliOptionsRegistry.get_option(:gui)
      expect(gui_option[:mutually_exclusive]).to include(:no_gui)

      no_gui_option = Lich::Common::CLI::CliOptionsRegistry.get_option(:no_gui)
      expect(no_gui_option[:mutually_exclusive]).to include(:gui)
    end

    it 'registers option with handler function' do
      handler = ->(_opts) { puts 'Executed!' }
      Lich::Common::CLI::CliOptionsRegistry.option :execute_command,
                                                   type: :boolean,
                                                   handler: handler

      retrieved_handler = Lich::Common::CLI::CliOptionsRegistry.get_handler(:execute_command)
      expect(retrieved_handler).to eq(handler)
    end

    it 'registers multiple options sequentially' do
      Lich::Common::CLI::CliOptionsRegistry.option :option1, type: :string
      Lich::Common::CLI::CliOptionsRegistry.option :option2, type: :boolean
      Lich::Common::CLI::CliOptionsRegistry.option :option3, type: :integer

      all_options = Lich::Common::CLI::CliOptionsRegistry.all_options
      expect(all_options).to have_key(:option1)
      expect(all_options).to have_key(:option2)
      expect(all_options).to have_key(:option3)
    end
  end

  describe '.get_option' do
    before do
      Lich::Common::CLI::CliOptionsRegistry.option :test_option, type: :string, default: 'test'
    end

    it 'returns option metadata when registered' do
      option = Lich::Common::CLI::CliOptionsRegistry.get_option(:test_option)
      expect(option).to be_a(Hash)
      expect(option[:type]).to eq(:string)
    end

    it 'returns nil for unregistered option' do
      option = Lich::Common::CLI::CliOptionsRegistry.get_option(:nonexistent)
      expect(option).to be_nil
    end
  end

  describe '.all_options' do
    it 'returns all registered options as hash' do
      Lich::Common::CLI::CliOptionsRegistry.option :opt1, type: :string
      Lich::Common::CLI::CliOptionsRegistry.option :opt2, type: :boolean

      all = Lich::Common::CLI::CliOptionsRegistry.all_options
      expect(all).to be_a(Hash)
      expect(all.keys).to include(:opt1, :opt2)
    end

    it 'returns a copy of options (not direct reference)' do
      Lich::Common::CLI::CliOptionsRegistry.option :test_opt, type: :string
      all1 = Lich::Common::CLI::CliOptionsRegistry.all_options
      all2 = Lich::Common::CLI::CliOptionsRegistry.all_options
      expect(all1).to eq(all2)
      expect(all1).not_to be(all2) # Different objects
    end
  end

  describe '.get_handler' do
    it 'returns handler for option with handler' do
      handler = ->(_opts) { 'executed' }
      Lich::Common::CLI::CliOptionsRegistry.option :command,
                                                   type: :boolean,
                                                   handler: handler

      retrieved = Lich::Common::CLI::CliOptionsRegistry.get_handler(:command)
      expect(retrieved).to eq(handler)
      expect(retrieved.call({})).to eq('executed')
    end

    it 'returns nil for option without handler' do
      Lich::Common::CLI::CliOptionsRegistry.option :no_handler, type: :string

      handler = Lich::Common::CLI::CliOptionsRegistry.get_handler(:no_handler)
      expect(handler).to be_nil
    end

    it 'returns nil for unregistered option' do
      handler = Lich::Common::CLI::CliOptionsRegistry.get_handler(:nonexistent)
      expect(handler).to be_nil
    end
  end

  describe '.validate' do
    it 'returns empty array for valid options' do
      Lich::Common::CLI::CliOptionsRegistry.option :gui, type: :boolean, default: true
      parsed = OpenStruct.new(gui: true)

      errors = Lich::Common::CLI::CliOptionsRegistry.validate(parsed)
      expect(errors).to be_empty
    end

    it 'detects mutually exclusive option violations' do
      Lich::Common::CLI::CliOptionsRegistry.option :gui,
                                                   type: :boolean,
                                                   mutually_exclusive: [:no_gui]
      Lich::Common::CLI::CliOptionsRegistry.option :no_gui,
                                                   type: :boolean,
                                                   mutually_exclusive: [:gui]
      parsed = OpenStruct.new(gui: true, no_gui: true)

      errors = Lich::Common::CLI::CliOptionsRegistry.validate(parsed)
      expect(errors).not_to be_empty
      expect(errors.first).to include('mutually exclusive')
    end

    it 'handles options that are not all present' do
      Lich::Common::CLI::CliOptionsRegistry.option :gui, type: :boolean, default: true
      Lich::Common::CLI::CliOptionsRegistry.option :account, type: :string
      parsed = OpenStruct.new(gui: true) # account not set

      errors = Lich::Common::CLI::CliOptionsRegistry.validate(parsed)
      expect(errors).to be_empty
    end

    it 'returns errors as array' do
      Lich::Common::CLI::CliOptionsRegistry.option :opt1,
                                                   type: :boolean,
                                                   mutually_exclusive: [:opt2]
      Lich::Common::CLI::CliOptionsRegistry.option :opt2,
                                                   type: :boolean,
                                                   mutually_exclusive: [:opt1]
      parsed = OpenStruct.new(opt1: true, opt2: true)

      errors = Lich::Common::CLI::CliOptionsRegistry.validate(parsed)
      expect(errors).to be_a(Array)
    end
  end

  describe '.to_opts_schema' do
    it 'converts registry to Opts schema format' do
      Lich::Common::CLI::CliOptionsRegistry.option :account, type: :string, default: 'DEFAULT'
      Lich::Common::CLI::CliOptionsRegistry.option :port, type: :integer, default: 3000
      Lich::Common::CLI::CliOptionsRegistry.option :gui, type: :boolean, default: true

      schema = Lich::Common::CLI::CliOptionsRegistry.to_opts_schema
      expect(schema).to be_a(Hash)
      expect(schema[:account][:type]).to eq(:string)
      expect(schema[:account][:default]).to eq('DEFAULT')
      expect(schema[:port][:type]).to eq(:integer)
      expect(schema[:gui][:type]).to eq(:boolean)
    end

    it 'schema can be used with Opts.parse' do
      Lich::Common::CLI::CliOptionsRegistry.option :account, type: :string, default: 'DEFAULT'
      Lich::Common::CLI::CliOptionsRegistry.option :gui, type: :boolean, default: true

      schema = Lich::Common::CLI::CliOptionsRegistry.to_opts_schema
      argv = ['--account=DOUG']

      require File.join(LIB_DIR, 'util', 'opts.rb')
      opts = Lich::Util::Opts.parse(argv, schema)
      expect(opts.account).to eq('DOUG')
      expect(opts.gui).to be true
    end
  end

  describe 'option metadata defaults' do
    it 'defaults deprecated to false' do
      Lich::Common::CLI::CliOptionsRegistry.option :option, type: :string
      option = Lich::Common::CLI::CliOptionsRegistry.get_option(:option)
      expect(option[:deprecated]).to be false
    end

    it 'defaults mutually_exclusive to empty array' do
      Lich::Common::CLI::CliOptionsRegistry.option :option, type: :string
      option = Lich::Common::CLI::CliOptionsRegistry.get_option(:option)
      expect(option[:mutually_exclusive]).to be_empty
    end

    it 'converts mutually_exclusive to array if single value' do
      Lich::Common::CLI::CliOptionsRegistry.option :option, type: :string, mutually_exclusive: :other
      option = Lich::Common::CLI::CliOptionsRegistry.get_option(:option)
      expect(option[:mutually_exclusive]).to be_a(Array)
    end
  end
end
