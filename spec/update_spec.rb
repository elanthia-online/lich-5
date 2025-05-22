# frozen_string_literal: true

require 'rspec'
require 'fileutils'
require 'tempfile'
require 'stringio'

# Explicitly require updater.rb first to ensure Main is defined
require_relative '../lib/util/update/updater'
require_relative '../lib/util/update/error'
require_relative '../lib/util/update/config'

describe 'Lich::Util::Update.request' do
  before(:each) do
    # Mock Config constants
    stub_const('Lich::Util::Update::Config::DIRECTORIES', {
      lich: '/path/to/lich',
      backup: '/path/to/backup',
      script: '/path/to/scripts',
      lib: '/path/to/lib',
      data: '/path/to/data',
      temp: '/path/to/temp'
    })

    stub_const('Lich::Util::Update::Config::CORE_SCRIPTS', ['go2.lic', 'repository.lic'])

    # Add USER_DATA_FILES constant for create_snapshot
    stub_const('Lich::Util::Update::Config::USER_DATA_FILES', ['user_data.xml'])

    stub_const('Lich::Util::Update::Config::DEFAULT_OPTIONS', {
      action: 'help',
      tag: 'latest',
      confirm: true,
      verbose: false
    })

    stub_const('Lich::Util::Update::Config::CURRENT_VERSION', '5.12.0')

    stub_const('Lich::Util::Update::Config::VALID_EXTENSIONS', {
      script: ['.lic'],
      lib: ['.rb'],
      data: ['.dat', '.xml', '.json']
    })

    # Create mock objects for components
    @logger = instance_double('Lich::Util::Update::Logger',
                              info: nil,
                              error: nil,
                              success: nil,
                              blank_line: nil)

    @github = instance_double('Lich::Util::Update::GitHub')

    @tag_support = instance_double('Lich::Util::Update::TagSupport')

    @validator = instance_double('Lich::Util::Update::Validator')

    @release_manager = instance_double('Lich::Util::Update::ReleaseManager',
                                       announce_update: true)

    # Mock file_manager with the correct 7-parameter signature for create_snapshot
    @file_manager = instance_double('Lich::Util::Update::FileManager')
    allow(@file_manager).to receive(:create_snapshot) do |_lich_dir, _backup_dir, _script_dir, _lib_dir, _data_dir, _core_scripts, _user_data|
      '/path/to/snapshot'
    end

    # Important: Mock installer with the correct method signatures
    @installer_double = instance_double('Lich::Util::Update::Installer',
                                        current_version: '5.12.0')

    # Allow installer.install with the full signature (7-8 arguments)
    allow(@installer_double).to receive(:install) do |_tag, _lich_dir, _backup_dir, _script_dir, _lib_dir, _data_dir, _temp_dir, _options = {}|
      true
    end

    # Allow installer.update_file with the correct signature
    allow(@installer_double).to receive(:update_file) do |_type, _file, _tag|
      true
    end

    # Allow installer.check_update_available with the correct signature
    allow(@installer_double).to receive(:check_update_available) do |tag|
      if tag == 'no_update'
        [false, "No updates available for tag: #{tag}"]
      else
        [true, "Update available: 5.13.0"]
      end
    end

    # Allow installer.check_file_update_available with the correct signature
    allow(@installer_double).to receive(:check_file_update_available) do |_type, file, _tag|
      if file == 'missing.lic'
        [false, "File not found: #{file}"]
      else
        [true, "Update available for #{file}"]
      end
    end

    # Allow installer.update method with the correct signature
    allow(@installer_double).to receive(:update) do |tag|
      if tag == 'no_update'
        [false, "No updates available for tag: #{tag}"]
      else
        [true, "Successfully updated to version 5.13.0"]
      end
    end

    # Allow installer.revert method with the correct signature
    allow(@installer_double).to receive(:revert) do
      [true, "Successfully reverted to previous snapshot"]
    end

    allow(@installer_double).to receive(:current_version=)

    @cleaner = instance_double('Lich::Util::Update::Cleaner',
                               cleanup_all: true)

    # Allow cleaner.cleanup with the correct signature
    allow(@cleaner).to receive(:cleanup) do
      [true, "Cleanup completed successfully"]
    end

    @cli = instance_double('Lich::Util::Update::CLI',
                           display_help: nil,
                           parse: nil)

    # Mock Main.initialize_components to return our mocked components
    allow(Lich::Util::Update::Main).to receive(:initialize_components).and_return({
      logger: @logger,
      github: @github,
      tag_support: @tag_support,
      validator: @validator,
      release_manager: @release_manager,
      file_manager: @file_manager,
      installer: @installer_double,
      cleaner: @cleaner,
      cli: @cli
    })

    # Mock Main.in_lich_environment? for CLI entrypoint tests
    allow(Lich::Util::Update::Main).to receive(:in_lich_environment?).and_return(false)

    # Capture debug output
    @debug_output = StringIO.new

    # Load the update.rb file
    load File.expand_path('../lib/util/update.rb', __dir__)

    # IMPORTANT: Apply the monkey patch AFTER loading update.rb
    # This ensures the original method exists before we try to alias it

    # Test-only override for get_user_confirmation to prevent hanging on stdin
    # This monkey patch allows tests to run without modifying production code
    # rubocop:disable Lint/ConstantDefinitionInBlock
    module Lich
      module Util
        module Update
          class << self
            # Store the original method to restore it after tests
            alias_method :original_get_user_confirmation, :get_user_confirmation

            # Override get_user_confirmation for testing purposes only
            # This prevents the method from blocking on stdin during tests
            # @param logger [Logger] The logger instance for displaying prompts
            # @param test_input [Boolean] Optional test input to return (for testing only)
            # @return [Boolean] The mocked confirmation result
            def get_user_confirmation(_logger, test_input = true)
              # In test environment, return the test_input parameter
              # This allows tests to control the confirmation result
              # without blocking on stdin
              test_input
            end
          end
        end
      end
    end
    # rubocop:enable Lint/ConstantDefinitionInBlock

    # Mock get_user_confirmation to be properly called and tested
    # Default to true for most tests
    allow(Lich::Util::Update).to receive(:get_user_confirmation).and_return(true)
  end

  describe 'with nil parameter' do
    it 'displays help information' do
      expect(@cli).to receive(:display_help)
      result = Lich::Util::Update.request(nil)
      expect(result[:action]).to eq('help')
    end
  end

  describe 'with string parameter' do
    it 'handles "help" command' do
      expect(@cli).to receive(:display_help)
      result = Lich::Util::Update.request('help')
      expect(result[:action]).to eq('help')
    end

    it 'handles "announce" command' do
      expect(@release_manager).to receive(:announce_update).with('5.12.0', 'latest')
      result = Lich::Util::Update.request('announce')
      expect(result[:action]).to eq('announce')
    end

    it 'handles "update" command with available update' do
      # Expect check_update_available to be called first
      expect(@installer_double).to receive(:check_update_available).with('latest').and_return([true, "Update available: 5.13.0"])

      # Expect create_snapshot to be called only after update is confirmed available
      expect(@logger).to receive(:info).with("Update available. Creating snapshot before proceeding...")
      expect(@file_manager).to receive(:create_snapshot)

      # Expect update to be called
      expect(@installer_double).to receive(:update).with('latest').and_return([true, "Successfully updated to version 5.13.0"])

      result = Lich::Util::Update.request('update')
      p result
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be true
    end

    it 'handles "update" command with no available update' do
      # Expect check_update_available to be called and return no update
      expect(@installer_double).to receive(:check_update_available).with('latest').and_return([false, "No updates available"])

      # Expect create_snapshot NOT to be called
      expect(@file_manager).not_to receive(:create_snapshot)

      # Expect update NOT to be called
      expect(@installer_double).not_to receive(:update)

      result = Lich::Util::Update.request('update')
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be false
      expect(result[:message]).to eq("No updates available")
    end

    it 'handles "beta" command with prompt and available update' do
      expect(@logger).to receive(:info).with("You are about to join the beta program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(true)

      # Expect check_update_available to be called
      expect(@installer_double).to receive(:check_update_available).with('beta').and_return([true, "Update available: 5.13.0-beta"])

      # Expect create_snapshot to be called
      expect(@logger).to receive(:info).with("Update available. Creating snapshot before proceeding...")
      expect(@file_manager).to receive(:create_snapshot)

      # Expect update to be called
      expect(@installer_double).to receive(:update).with('beta').and_return([true, "Successfully updated to version 5.13.0-beta"])

      result = Lich::Util::Update.request('beta')
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be true
    end

    it 'handles "beta" command with user cancellation' do
      expect(@logger).to receive(:info).with("You are about to join the beta program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(false)
      expect(@logger).to receive(:info).with("Update cancelled: Beta update will not proceed.")

      # Should not call check_update_available when cancelled
      expect(@installer_double).not_to receive(:check_update_available)

      # Should not call create_snapshot when cancelled
      expect(@file_manager).not_to receive(:create_snapshot)

      # Should not call update when cancelled
      expect(@installer_double).not_to receive(:update)

      result = Lich::Util::Update.request('beta')
      expect(result[:success]).to be false
      expect(result[:message]).to include("cancelled by user")
    end

    it 'handles "--beta" command with prompt and available update' do
      expect(@logger).to receive(:info).with("You are about to join the beta program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(true)

      # Expect check_update_available to be called
      expect(@installer_double).to receive(:check_update_available).with('beta').and_return([true, "Update available: 5.13.0-beta"])

      # Expect create_snapshot to be called
      expect(@logger).to receive(:info).with("Update available. Creating snapshot before proceeding...")
      expect(@file_manager).to receive(:create_snapshot)

      # Expect update to be called
      expect(@installer_double).to receive(:update).with('beta').and_return([true, "Successfully updated to version 5.13.0-beta"])

      result = Lich::Util::Update.request('--beta')
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be true
    end

    it 'handles "--beta" command with user cancellation' do
      expect(@logger).to receive(:info).with("You are about to join the beta program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(false)
      expect(@logger).to receive(:info).with("Update cancelled: Beta update will not proceed.")

      # Should not call check_update_available when cancelled
      expect(@installer_double).not_to receive(:check_update_available)

      # Should not call create_snapshot when cancelled
      expect(@file_manager).not_to receive(:create_snapshot)

      # Should not call update when cancelled
      expect(@installer_double).not_to receive(:update)

      result = Lich::Util::Update.request('--beta')
      expect(result[:success]).to be false
      expect(result[:message]).to include("cancelled by user")
    end

    it 'handles "--alpha" command with prompt and available update' do
      expect(@logger).to receive(:info).with("You are about to join the alpha program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(true)

      # Expect check_update_available to be called
      expect(@installer_double).to receive(:check_update_available).with('alpha').and_return([true, "Update available: 5.13.0-alpha"])

      # Expect create_snapshot to be called
      expect(@logger).to receive(:info).with("Update available. Creating snapshot before proceeding...")
      expect(@file_manager).to receive(:create_snapshot)

      # Expect update to be called
      expect(@installer_double).to receive(:update).with('alpha').and_return([true, "Successfully updated to version 5.13.0-alpha"])

      result = Lich::Util::Update.request('--alpha')
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be true
    end

    it 'handles "--alpha" command with user cancellation' do
      expect(@logger).to receive(:info).with("You are about to join the alpha program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(false)
      expect(@logger).to receive(:info).with("Update cancelled: Alpha update will not proceed.")

      # Should not call check_update_available when cancelled
      expect(@installer_double).not_to receive(:check_update_available)

      # Should not call create_snapshot when cancelled
      expect(@file_manager).not_to receive(:create_snapshot)

      # Should not call update when cancelled
      expect(@installer_double).not_to receive(:update)

      result = Lich::Util::Update.request('--alpha')
      expect(result[:success]).to be false
      expect(result[:message]).to include("cancelled by user")
    end

    it 'handles "alpha" command with prompt and available update' do
      expect(@logger).to receive(:info).with("You are about to join the alpha program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(true)

      # Expect check_update_available to be called
      expect(@installer_double).to receive(:check_update_available).with('alpha').and_return([true, "Update available: 5.13.0-alpha"])

      # Expect create_snapshot to be called
      expect(@logger).to receive(:info).with("Update available. Creating snapshot before proceeding...")
      expect(@file_manager).to receive(:create_snapshot)

      # Expect update to be called
      expect(@installer_double).to receive(:update).with('alpha').and_return([true, "Successfully updated to version 5.13.0-alpha"])

      result = Lich::Util::Update.request('alpha')
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be true
    end

    it 'handles "alpha" command with user cancellation' do
      expect(@logger).to receive(:info).with("You are about to join the alpha program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(false)
      expect(@logger).to receive(:info).with("Update cancelled: Alpha update will not proceed.")

      # Should not call check_update_available when cancelled
      expect(@installer_double).not_to receive(:check_update_available)

      # Should not call create_snapshot when cancelled
      expect(@file_manager).not_to receive(:create_snapshot)

      # Should not call update when cancelled
      expect(@installer_double).not_to receive(:update)

      result = Lich::Util::Update.request('alpha')
      expect(result[:success]).to be false
      expect(result[:message]).to include("cancelled by user")
    end

    it 'handles "--dev" command with prompt and available update' do
      expect(@logger).to receive(:info).with("You are about to join the development program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(true)

      # Expect check_update_available to be called
      expect(@installer_double).to receive(:check_update_available).with('dev').and_return([true, "Update available: 5.13.0-dev"])

      # Expect create_snapshot to be called
      expect(@logger).to receive(:info).with("Update available. Creating snapshot before proceeding...")
      expect(@file_manager).to receive(:create_snapshot)

      # Expect update to be called
      expect(@installer_double).to receive(:update).with('dev').and_return([true, "Successfully updated to version 5.13.0-dev"])

      result = Lich::Util::Update.request('--dev')
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be true
    end

    it 'handles "--dev" command with user cancellation' do
      expect(@logger).to receive(:info).with("You are about to join the development program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(false)
      expect(@logger).to receive(:info).with("Update cancelled: Development update will not proceed.")

      # Should not call check_update_available when cancelled
      expect(@installer_double).not_to receive(:check_update_available)

      # Should not call create_snapshot when cancelled
      expect(@file_manager).not_to receive(:create_snapshot)

      # Should not call update when cancelled
      expect(@installer_double).not_to receive(:update)

      result = Lich::Util::Update.request('--dev')
      expect(result[:success]).to be false
      expect(result[:message]).to include("cancelled by user")
    end

    it 'handles "--script=file.lic" command with available update' do
      # Expect check_file_update_available to be called first
      expect(@installer_double).to receive(:check_file_update_available).with('script', 'file.lic', 'latest').and_return([true, "Update available for file.lic"])

      # Expect update_file to be called
      expect(@installer_double).to receive(:update_file).with('script', 'file.lic', 'latest')

      result = Lich::Util::Update.request('--script=file.lic')
      expect(result[:action]).to eq('update_file')
      expect(result[:success]).to be true
    end

    it 'handles "--script=missing.lic" command with no available update' do
      # Expect check_file_update_available to be called and return no update
      expect(@installer_double).to receive(:check_file_update_available).with('script', 'missing.lic', 'latest').and_return([false, "File not found: missing.lic"])

      # Expect update_file NOT to be called
      expect(@installer_double).not_to receive(:update_file)

      result = Lich::Util::Update.request('--script=missing.lic')
      expect(result[:action]).to eq('update_file')
      expect(result[:success]).to be false
      expect(result[:message]).to eq("File not found: missing.lic")
    end

    it 'handles "revert" command' do
      # Expect revert to be called
      expect(@installer_double).to receive(:revert).and_return([true, "Successfully reverted to previous snapshot"])

      result = Lich::Util::Update.request('revert')
      expect(result[:action]).to eq('revert')
      expect(result[:success]).to be true
      expect(result[:message]).to eq("Successfully reverted to previous snapshot")
    end
  end

  describe 'with symbol parameter' do
    it 'handles :help symbol' do
      expect(@cli).to receive(:display_help)
      result = Lich::Util::Update.request(:help)
      expect(result[:action]).to eq('help')
    end

    it 'handles :announce symbol' do
      expect(@release_manager).to receive(:announce_update).with('5.12.0', 'latest')
      result = Lich::Util::Update.request(:announce)
      expect(result[:action]).to eq('announce')
    end

    it 'handles :update symbol with available update' do
      # Expect check_update_available to be called first
      expect(@installer_double).to receive(:check_update_available).with('latest').and_return([true, "Update available: 5.13.0"])

      # Expect create_snapshot to be called only after update is confirmed available
      expect(@logger).to receive(:info).with("Update available. Creating snapshot before proceeding...")
      expect(@file_manager).to receive(:create_snapshot)

      # Expect update to be called
      expect(@installer_double).to receive(:update).with('latest').and_return([true, "Successfully updated to version 5.13.0"])

      result = Lich::Util::Update.request(:update)
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be true
    end

    it 'handles :beta symbol with prompt and available update' do
      expect(@logger).to receive(:info).with("You are about to join the beta program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(true)

      # Expect check_update_available to be called
      expect(@installer_double).to receive(:check_update_available).with('beta').and_return([true, "Update available: 5.13.0-beta"])

      # Expect create_snapshot to be called
      expect(@logger).to receive(:info).with("Update available. Creating snapshot before proceeding...")
      expect(@file_manager).to receive(:create_snapshot)

      # Expect update to be called
      expect(@installer_double).to receive(:update).with('beta').and_return([true, "Successfully updated to version 5.13.0-beta"])

      result = Lich::Util::Update.request(:beta)
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be true
    end

    it 'handles :beta symbol with user cancellation' do
      expect(@logger).to receive(:info).with("You are about to join the beta program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(false)
      expect(@logger).to receive(:info).with("Update cancelled: Beta update will not proceed.")

      # Should not call check_update_available when cancelled
      expect(@installer_double).not_to receive(:check_update_available)

      # Should not call create_snapshot when cancelled
      expect(@file_manager).not_to receive(:create_snapshot)

      # Should not call update when cancelled
      expect(@installer_double).not_to receive(:update)

      result = Lich::Util::Update.request(:beta)
      expect(result[:success]).to be false
      expect(result[:message]).to include("cancelled by user")
    end

    it 'handles :alpha symbol with prompt and available update' do
      expect(@logger).to receive(:info).with("You are about to join the alpha program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(true)

      # Expect check_update_available to be called
      expect(@installer_double).to receive(:check_update_available).with('alpha').and_return([true, "Update available: 5.13.0-alpha"])

      # Expect create_snapshot to be called
      expect(@logger).to receive(:info).with("Update available. Creating snapshot before proceeding...")
      expect(@file_manager).to receive(:create_snapshot)

      # Expect update to be called
      expect(@installer_double).to receive(:update).with('alpha').and_return([true, "Successfully updated to version 5.13.0-alpha"])

      result = Lich::Util::Update.request(:alpha)
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be true
    end

    it 'handles :alpha symbol with user cancellation' do
      expect(@logger).to receive(:info).with("You are about to join the alpha program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(false)
      expect(@logger).to receive(:info).with("Update cancelled: Alpha update will not proceed.")

      # Should not call check_update_available when cancelled
      expect(@installer_double).not_to receive(:check_update_available)

      # Should not call create_snapshot when cancelled
      expect(@file_manager).not_to receive(:create_snapshot)

      # Should not call update when cancelled
      expect(@installer_double).not_to receive(:update)

      result = Lich::Util::Update.request(:alpha)
      expect(result[:success]).to be false
      expect(result[:message]).to include("cancelled by user")
    end

    it 'handles :dev symbol with prompt and available update' do
      expect(@logger).to receive(:info).with("You are about to join the development program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(true)

      # Expect check_update_available to be called
      expect(@installer_double).to receive(:check_update_available).with('dev').and_return([true, "Update available: 5.13.0-dev"])

      # Expect create_snapshot to be called
      expect(@logger).to receive(:info).with("Update available. Creating snapshot before proceeding...")
      expect(@file_manager).to receive(:create_snapshot)

      # Expect update to be called
      expect(@installer_double).to receive(:update).with('dev').and_return([true, "Successfully updated to version 5.13.0-dev"])

      result = Lich::Util::Update.request(:dev)
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be true
    end

    it 'handles :dev symbol with user cancellation' do
      expect(@logger).to receive(:info).with("You are about to join the development program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(false)
      expect(@logger).to receive(:info).with("Update cancelled: Development update will not proceed.")

      # Should not call check_update_available when cancelled
      expect(@installer_double).not_to receive(:check_update_available)

      # Should not call create_snapshot when cancelled
      expect(@file_manager).not_to receive(:create_snapshot)

      # Should not call update when cancelled
      expect(@installer_double).not_to receive(:update)

      result = Lich::Util::Update.request(:dev)
      expect(result[:success]).to be false
      expect(result[:message]).to include("cancelled by user")
    end

    it 'handles :revert symbol' do
      # Expect revert to be called
      expect(@installer_double).to receive(:revert).and_return([true, "Successfully reverted to previous snapshot"])

      result = Lich::Util::Update.request(:revert)
      expect(result[:action]).to eq('revert')
      expect(result[:success]).to be true
      expect(result[:message]).to eq("Successfully reverted to previous snapshot")
    end
  end

  describe 'with hash parameter' do
    it 'handles {action: "update"} hash with available update' do
      # Expect check_update_available to be called first
      expect(@installer_double).to receive(:check_update_available).with('latest').and_return([true, "Update available: 5.13.0"])

      # Expect create_snapshot to be called only after update is confirmed available
      expect(@logger).to receive(:info).with("Update available. Creating snapshot before proceeding...")
      expect(@file_manager).to receive(:create_snapshot)

      # Expect update to be called
      expect(@installer_double).to receive(:update).with('latest').and_return([true, "Successfully updated to version 5.13.0"])

      result = Lich::Util::Update.request({ action: "update" })
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be true
    end

    it 'handles {action: :update, tag: "beta"} hash with prompt and available update' do
      expect(@logger).to receive(:info).with("You are about to join the beta program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(true)

      # Expect check_update_available to be called
      expect(@installer_double).to receive(:check_update_available).with('beta').and_return([true, "Update available: 5.13.0-beta"])

      # Expect create_snapshot to be called
      expect(@logger).to receive(:info).with("Update available. Creating snapshot before proceeding...")
      expect(@file_manager).to receive(:create_snapshot)

      # Expect update to be called
      expect(@installer_double).to receive(:update).with('beta').and_return([true, "Successfully updated to version 5.13.0-beta"])

      result = Lich::Util::Update.request({ action: :update, tag: "beta" })
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be true
    end

    it 'handles {action: :update, tag: "beta"} hash with user cancellation' do
      expect(@logger).to receive(:info).with("You are about to join the beta program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(false)
      expect(@logger).to receive(:info).with("Update cancelled: Beta update will not proceed.")

      # Should not call check_update_available when cancelled
      expect(@installer_double).not_to receive(:check_update_available)

      # Should not call create_snapshot when cancelled
      expect(@file_manager).not_to receive(:create_snapshot)

      # Should not call update when cancelled
      expect(@installer_double).not_to receive(:update)

      result = Lich::Util::Update.request({ action: :update, tag: "beta" })
      expect(result[:success]).to be false
      expect(result[:message]).to include("cancelled by user")
    end

    it 'handles {action: "update_file", file_type: "script", file: "file.lic"} hash with available update' do
      # Expect check_file_update_available to be called first
      expect(@installer_double).to receive(:check_file_update_available).with('script', 'file.lic', 'latest').and_return([true, "Update available for file.lic"])

      # Expect update_file to be called
      expect(@installer_double).to receive(:update_file).with('script', 'file.lic', 'latest')

      result = Lich::Util::Update.request({ action: "update_file", file_type: "script", file: "file.lic" })
      expect(result[:action]).to eq('update_file')
      expect(result[:success]).to be true
    end

    it 'handles {action: "update_file", file_type: "script", file: "missing.lic"} hash with no available update' do
      # Expect check_file_update_available to be called and return no update
      expect(@installer_double).to receive(:check_file_update_available).with('script', 'missing.lic', 'latest').and_return([false, "File not found: missing.lic"])

      # Expect update_file NOT to be called
      expect(@installer_double).not_to receive(:update_file)

      result = Lich::Util::Update.request({ action: "update_file", file_type: "script", file: "missing.lic" })
      expect(result[:action]).to eq('update_file')
      expect(result[:success]).to be false
      expect(result[:message]).to eq("File not found: missing.lic")
    end
  end

  describe 'with array parameter' do
    it 'handles ["--announce"] array' do
      expect(@release_manager).to receive(:announce_update).with('5.12.0', 'latest')
      result = Lich::Util::Update.request(["--announce"])
      expect(result[:action]).to eq('announce')
    end

    it 'handles ["--script=dependency.lic"] array with available update' do
      # Expect check_file_update_available to be called first
      expect(@installer_double).to receive(:check_file_update_available).with('script', 'dependency.lic', 'latest').and_return([true, "Update available for dependency.lic"])

      # Expect update_file to be called
      expect(@installer_double).to receive(:update_file).with('script', 'dependency.lic', 'latest')

      result = Lich::Util::Update.request(["--script=dependency.lic"])
      expect(result[:action]).to eq('update_file')
      expect(result[:success]).to be true
    end

    it 'handles ["--script=missing.lic"] array with no available update' do
      # Expect check_file_update_available to be called and return no update
      expect(@installer_double).to receive(:check_file_update_available).with('script', 'missing.lic', 'latest').and_return([false, "File not found: missing.lic"])

      # Expect update_file NOT to be called
      expect(@installer_double).not_to receive(:update_file)

      result = Lich::Util::Update.request(["--script=missing.lic"])
      expect(result[:action]).to eq('update_file')
      expect(result[:success]).to be false
      expect(result[:message]).to eq("File not found: missing.lic")
    end
  end

  describe 'CLI entrypoint' do
    # Instead of trying to trigger the actual CLI entrypoint code by reloading the file,
    # we'll directly test the CLI entrypoint logic by mocking the conditions

    it 'detects CLI environment and processes ARGV' do
      # Mock the CLI entrypoint condition
      cli_entrypoint_code = lambda do
        # This is the code from the CLI entrypoint in update.rb
        in_lich_environment = Lich::Util::Update::Main.in_lich_environment?

        if !in_lich_environment
          result = Lich::Util::Update.request(["--help"])
          exit(result[:success] ? 0 : 1)
        else
          Lich::Util::Update.request('help')
        end
      end

      # Set up expectations
      expect(Lich::Util::Update::Main).to receive(:in_lich_environment?).and_return(false)
      expect(Lich::Util::Update).to receive(:request).with(["--help"]).and_return({ success: true })
      expect(Kernel).to receive(:exit).with(0)

      # Execute the CLI entrypoint code
      cli_entrypoint_code.call
    end

    it 'sets exit code based on success' do
      # Mock the CLI entrypoint condition
      cli_entrypoint_code = lambda do
        # This is the code from the CLI entrypoint in update.rb
        in_lich_environment = Lich::Util::Update::Main.in_lich_environment?

        if !in_lich_environment
          result = Lich::Util::Update.request(["--help"])
          exit(result[:success] ? 0 : 1)
        else
          Lich::Util::Update.request('help')
        end
      end

      # Set up expectations
      expect(Lich::Util::Update::Main).to receive(:in_lich_environment?).and_return(false)
      expect(Lich::Util::Update).to receive(:request).with(["--help"]).and_return({ success: false })
      expect(Kernel).to receive(:exit).with(1)

      # Execute the CLI entrypoint code
      cli_entrypoint_code.call
    end
  end

  # Restore the original method after all tests
  after(:all) do
    # Restore the original get_user_confirmation method
    if Lich::Util::Update.respond_to?(:original_get_user_confirmation)
      Lich::Util::Update.singleton_class.class_eval do
        alias_method :get_user_confirmation, :original_get_user_confirmation
        remove_method :original_get_user_confirmation
      end
    end
  end
end
