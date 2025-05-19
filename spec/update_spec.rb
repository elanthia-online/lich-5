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
    
    @file_manager = instance_double('Lich::Util::Update::FileManager', 
                                   create_snapshot: '/path/to/snapshot')
    
    # Important: Mock installer with the correct method signature, but WITHOUT revert
    @installer_double = instance_double('Lich::Util::Update::Installer', 
                                      current_version: '5.12.0')
    
    # Allow installer.install with the full signature (7-8 arguments)
    allow(@installer_double).to receive(:install) do |tag, lich_dir, backup_dir, script_dir, lib_dir, data_dir, temp_dir, options={}|
      true
    end
    
    # Allow installer.update_file with the correct signature
    allow(@installer_double).to receive(:update_file) do |type, file, location, version='production'|
      true
    end
    
    allow(@installer_double).to receive(:current_version=)
    
    @cleaner = instance_double('Lich::Util::Update::Cleaner', 
                              cleanup_all: true)
    
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
    
    # Capture debug output
    @debug_output = StringIO.new
    
    # Load the update.rb file
    load File.expand_path('../lib/util/update.rb', __dir__)
    
    # IMPORTANT: Apply the monkey patch AFTER loading update.rb
    # This ensures the original method exists before we try to alias it
    
    # Test-only override for get_user_confirmation to prevent hanging on stdin
    # This monkey patch allows tests to run without modifying production code
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
            def get_user_confirmation(logger, test_input = true)
              # In test environment, return the test_input parameter
              # This allows tests to control the confirmation result
              # without blocking on stdin
              test_input
            end
          end
        end
      end
    end
    
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
    
    it 'handles "update" command' do
      expect(@file_manager).to receive(:create_snapshot)
      # Expect installer.install with all required arguments
      expect(@installer_double).to receive(:install).with(
        'latest',
        '/path/to/lich',
        '/path/to/backup',
        '/path/to/scripts',
        '/path/to/lib',
        '/path/to/data',
        '/path/to/temp',
        { confirm: true, create_snapshot: false }
      )
      result = Lich::Util::Update.request('update')
      expect(result[:action]).to eq('update')
    end
    
    it 'handles "beta" command with prompt' do
      expect(@logger).to receive(:info).with("You are about to join the beta program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(true)
      # Expect installer.install with all required arguments
      expect(@installer_double).to receive(:install).with(
        'beta',
        '/path/to/lich',
        '/path/to/backup',
        '/path/to/scripts',
        '/path/to/lib',
        '/path/to/data',
        '/path/to/temp',
        { confirm: true, create_snapshot: false }
      )
      result = Lich::Util::Update.request('beta')
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be true
    end
    
    it 'handles "beta" command with user cancellation' do
      expect(@logger).to receive(:info).with("You are about to join the beta program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(false)
      expect(@logger).to receive(:info).with("Update cancelled: Beta update will not proceed.")
      # Should not call installer.install when cancelled
      expect(@installer_double).not_to receive(:install)
      result = Lich::Util::Update.request('beta')
      expect(result[:success]).to be false
      expect(result[:message]).to include("cancelled by user")
    end
    
    it 'handles "--beta" command with prompt' do
      expect(@logger).to receive(:info).with("You are about to join the beta program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(true)
      # Expect installer.install with all required arguments
      expect(@installer_double).to receive(:install).with(
        'beta',
        '/path/to/lich',
        '/path/to/backup',
        '/path/to/scripts',
        '/path/to/lib',
        '/path/to/data',
        '/path/to/temp',
        { confirm: true, create_snapshot: false }
      )
      result = Lich::Util::Update.request('--beta')
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be true
    end
    
    it 'handles "--beta" command with user cancellation' do
      expect(@logger).to receive(:info).with("You are about to join the beta program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(false)
      expect(@logger).to receive(:info).with("Update cancelled: Beta update will not proceed.")
      # Should not call installer.install when cancelled
      expect(@installer_double).not_to receive(:install)
      result = Lich::Util::Update.request('--beta')
      expect(result[:success]).to be false
      expect(result[:message]).to include("cancelled by user")
    end
    
    it 'handles "--alpha" command with prompt' do
      expect(@logger).to receive(:info).with("You are about to join the alpha program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(true)
      # Expect installer.install with all required arguments
      expect(@installer_double).to receive(:install).with(
        'alpha',
        '/path/to/lich',
        '/path/to/backup',
        '/path/to/scripts',
        '/path/to/lib',
        '/path/to/data',
        '/path/to/temp',
        { confirm: true, create_snapshot: false }
      )
      result = Lich::Util::Update.request('--alpha')
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be true
    end
    
    it 'handles "--alpha" command with user cancellation' do
      expect(@logger).to receive(:info).with("You are about to join the alpha program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(false)
      expect(@logger).to receive(:info).with("Update cancelled: Alpha update will not proceed.")
      # Should not call installer.install when cancelled
      expect(@installer_double).not_to receive(:install)
      result = Lich::Util::Update.request('--alpha')
      expect(result[:success]).to be false
      expect(result[:message]).to include("cancelled by user")
    end
    
    it 'handles "alpha" command with prompt' do
      expect(@logger).to receive(:info).with("You are about to join the alpha program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(true)
      # Expect installer.install with all required arguments
      expect(@installer_double).to receive(:install).with(
        'alpha',
        '/path/to/lich',
        '/path/to/backup',
        '/path/to/scripts',
        '/path/to/lib',
        '/path/to/data',
        '/path/to/temp',
        { confirm: true, create_snapshot: false }
      )
      result = Lich::Util::Update.request('alpha')
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be true
    end
    
    it 'handles "alpha" command with user cancellation' do
      expect(@logger).to receive(:info).with("You are about to join the alpha program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(false)
      expect(@logger).to receive(:info).with("Update cancelled: Alpha update will not proceed.")
      # Should not call installer.install when cancelled
      expect(@installer_double).not_to receive(:install)
      result = Lich::Util::Update.request('alpha')
      expect(result[:success]).to be false
      expect(result[:message]).to include("cancelled by user")
    end
    
    it 'handles "--dev" command with prompt' do
      expect(@logger).to receive(:info).with("You are about to join the development program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(true)
      # Expect installer.install with all required arguments
      expect(@installer_double).to receive(:install).with(
        'dev',
        '/path/to/lich',
        '/path/to/backup',
        '/path/to/scripts',
        '/path/to/lib',
        '/path/to/data',
        '/path/to/temp',
        { confirm: true, create_snapshot: false }
      )
      result = Lich::Util::Update.request('--dev')
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be true
    end
    
    it 'handles "--dev" command with user cancellation' do
      expect(@logger).to receive(:info).with("You are about to join the development program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(false)
      expect(@logger).to receive(:info).with("Update cancelled: Development update will not proceed.")
      # Should not call installer.install when cancelled
      expect(@installer_double).not_to receive(:install)
      result = Lich::Util::Update.request('--dev')
      expect(result[:success]).to be false
      expect(result[:message]).to include("cancelled by user")
    end
    
    it 'handles "--script=file.lic" command' do
      # Expect installer.update_file with correct arguments
      expect(@installer_double).to receive(:update_file).with('script', 'file.lic', 'latest')
      result = Lich::Util::Update.request('--script=file.lic')
      expect(result[:action]).to eq('update_file')
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
    
    it 'handles :update symbol' do
      expect(@file_manager).to receive(:create_snapshot)
      # Expect installer.install with all required arguments
      expect(@installer_double).to receive(:install).with(
        'latest',
        '/path/to/lich',
        '/path/to/backup',
        '/path/to/scripts',
        '/path/to/lib',
        '/path/to/data',
        '/path/to/temp',
        { confirm: true, create_snapshot: false }
      )
      result = Lich::Util::Update.request(:update)
      expect(result[:action]).to eq('update')
    end
    
    it 'handles :beta symbol with prompt' do
      expect(@logger).to receive(:info).with("You are about to join the beta program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(true)
      # Expect installer.install with all required arguments
      expect(@installer_double).to receive(:install).with(
        'beta',
        '/path/to/lich',
        '/path/to/backup',
        '/path/to/scripts',
        '/path/to/lib',
        '/path/to/data',
        '/path/to/temp',
        { confirm: true, create_snapshot: false }
      )
      result = Lich::Util::Update.request(:beta)
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be true
    end
    
    it 'handles :beta symbol with user cancellation' do
      expect(@logger).to receive(:info).with("You are about to join the beta program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(false)
      expect(@logger).to receive(:info).with("Update cancelled: Beta update will not proceed.")
      # Should not call installer.install when cancelled
      expect(@installer_double).not_to receive(:install)
      result = Lich::Util::Update.request(:beta)
      expect(result[:success]).to be false
      expect(result[:message]).to include("cancelled by user")
    end
    
    it 'handles :alpha symbol with prompt' do
      expect(@logger).to receive(:info).with("You are about to join the alpha program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(true)
      # Expect installer.install with all required arguments
      expect(@installer_double).to receive(:install).with(
        'alpha',
        '/path/to/lich',
        '/path/to/backup',
        '/path/to/scripts',
        '/path/to/lib',
        '/path/to/data',
        '/path/to/temp',
        { confirm: true, create_snapshot: false }
      )
      result = Lich::Util::Update.request(:alpha)
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be true
    end
    
    it 'handles :alpha symbol with user cancellation' do
      expect(@logger).to receive(:info).with("You are about to join the alpha program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(false)
      expect(@logger).to receive(:info).with("Update cancelled: Alpha update will not proceed.")
      # Should not call installer.install when cancelled
      expect(@installer_double).not_to receive(:install)
      result = Lich::Util::Update.request(:alpha)
      expect(result[:success]).to be false
      expect(result[:message]).to include("cancelled by user")
    end
    
    it 'handles :dev symbol with prompt' do
      expect(@logger).to receive(:info).with("You are about to join the development program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(true)
      # Expect installer.install with all required arguments
      expect(@installer_double).to receive(:install).with(
        'dev',
        '/path/to/lich',
        '/path/to/backup',
        '/path/to/scripts',
        '/path/to/lib',
        '/path/to/data',
        '/path/to/temp',
        { confirm: true, create_snapshot: false }
      )
      result = Lich::Util::Update.request(:dev)
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be true
    end
    
    it 'handles :dev symbol with user cancellation' do
      expect(@logger).to receive(:info).with("You are about to join the development program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(false)
      expect(@logger).to receive(:info).with("Update cancelled: Development update will not proceed.")
      # Should not call installer.install when cancelled
      expect(@installer_double).not_to receive(:install)
      result = Lich::Util::Update.request(:dev)
      expect(result[:success]).to be false
      expect(result[:message]).to include("cancelled by user")
    end
  end
  
  describe 'with hash parameter' do
    it 'handles {action: "update"} hash' do
      expect(@file_manager).to receive(:create_snapshot)
      # Expect installer.install with all required arguments
      expect(@installer_double).to receive(:install).with(
        'latest',
        '/path/to/lich',
        '/path/to/backup',
        '/path/to/scripts',
        '/path/to/lib',
        '/path/to/data',
        '/path/to/temp',
        { confirm: true, create_snapshot: false }
      )
      result = Lich::Util::Update.request({action: "update"})
      expect(result[:action]).to eq('update')
    end
    
    it 'handles {action: :update, tag: "beta"} hash with prompt' do
      expect(@logger).to receive(:info).with("You are about to join the beta program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(true)
      # Expect installer.install with all required arguments
      expect(@installer_double).to receive(:install).with(
        'beta',
        '/path/to/lich',
        '/path/to/backup',
        '/path/to/scripts',
        '/path/to/lib',
        '/path/to/data',
        '/path/to/temp',
        { confirm: true, create_snapshot: false }
      )
      result = Lich::Util::Update.request({action: :update, tag: "beta"})
      expect(result[:action]).to eq('update')
      expect(result[:success]).to be true
    end
    
    it 'handles {action: :update, tag: "beta"} hash with user cancellation' do
      expect(@logger).to receive(:info).with("You are about to join the beta program for Lich5.")
      expect(Lich::Util::Update).to receive(:get_user_confirmation).with(@logger).and_return(false)
      expect(@logger).to receive(:info).with("Update cancelled: Beta update will not proceed.")
      # Should not call installer.install when cancelled
      expect(@installer_double).not_to receive(:install)
      result = Lich::Util::Update.request({action: :update, tag: "beta"})
      expect(result[:success]).to be false
      expect(result[:message]).to include("cancelled by user")
    end
    
    it 'handles {action: "update_file", file_type: "script", file: "file.lic"} hash' do
      # Expect installer.update_file with correct arguments
      expect(@installer_double).to receive(:update_file).with('script', 'file.lic', 'latest')
      result = Lich::Util::Update.request({action: "update_file", file_type: "script", file: "file.lic"})
      expect(result[:action]).to eq('update_file')
    end
  end
  
  describe 'with array parameter' do
    it 'handles ["--announce"] array' do
      expect(@release_manager).to receive(:announce_update).with('5.12.0', 'latest')
      result = Lich::Util::Update.request(["--announce"])
      expect(result[:action]).to eq('announce')
    end
    
    it 'handles ["--script=dependency.lic"] array' do
      # Expect installer.update_file with correct arguments
      expect(@installer_double).to receive(:update_file).with('script', 'dependency.lic', 'latest')
      result = Lich::Util::Update.request(["--script=dependency.lic"])
      expect(result[:action]).to eq('update_file')
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
