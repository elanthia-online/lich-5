# frozen_string_literal: true

# Real-keychain fence for the spec suite.
#
# Rule: specs never touch the developer's keychain. The OS-level store,
# retrieve and delete calls behind Lich::Common::GUI::MasterPasswordManager
# raise here, so a spec whose fake manager is not reached fails with a plain
# message instead of reading or rewriting the real master password. Loaded for
# every rspec process through `.rspec` and `.rspec_parallel`
# (`--require ./spec/support/real_keychain_fence`), so it does not depend on a
# spec file requiring spec_helper.
#
# The fence installs its stubs through RSpec::Mocks directly, not through the
# example's `allow` and `receive`, because an example group may define helper
# methods with those names (active_sessions_handoff_spec defines `receive`).
#
# The fence sits below the level existing specs stub: an example that stubs
# WindowsCredentialManager.store_credential, or Open3.capture3, still wins,
# because example stubs are installed after this before hook.
#
# An example that truly needs the keychain opts in with `real_keychain: true`.
# None does today; the tag exists so the exception is visible, not silent.
module RealKeychainFence
  class Reached < StandardError; end

  MESSAGE = 'would touch the real keychain; give the code under test a manager double'

  MANAGER = 'Lich::Common::GUI::MasterPasswordManager'
  WINDOWS_MANAGER = 'Lich::Common::GUI::WindowsCredentialManager'

  # macOS and Linux wrappers shell out directly, so they are fenced themselves.
  MANAGER_METHODS = %i[
    store_macos_keychain retrieve_macos_keychain delete_macos_keychain
    store_linux_keychain retrieve_linux_keychain delete_linux_keychain
  ].freeze

  # Windows wrappers delegate to WindowsCredentialManager.store_credential and
  # its siblings, and windows_credential_manager_spec exercises those methods
  # directly, so the fence sits one level below them, on the Win32 calls they
  # make. These are attached only on Windows (windows_credential_manager.rb);
  # elsewhere there is nothing to fence, and the store, retrieve and delete
  # methods return before any OS call because available? is false.
  WINDOWS_METHODS = %i[CredReadW CredWriteW CredDeleteW].freeze

  # The strict read path calls the keychain tool by absolute path through Open3.
  TOOL = %r{(\A|/)(security|secret-tool)\z}

  def self.apply
    fence_module(MANAGER, MANAGER_METHODS)
    fence_module(WINDOWS_MANAGER, WINDOWS_METHODS)
    fence_open3
  end

  # An unloaded manager constant is a gap in the fence, not a reason to skip it:
  # load the file that defines it (it pulls in WindowsCredentialManager too) and
  # fence the result. The file can only load where Lich::Util is available. A
  # process without it (a spec that never loads spec_helper) cannot load the
  # manager at all, so the code under test cannot reach it either; the fence
  # does not apply there and says so by raising only if the load fails for any
  # other reason.
  def self.ensure_loaded(const_name)
    return true if Object.const_defined?(const_name)
    return false unless defined?(Lich::Util) && Lich::Util.respond_to?(:install_gem_requirements)

    lib = File.expand_path('../../lib', __dir__)
    $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
    require 'common/gui/master_password_manager'
    return true if Object.const_defined?(const_name)

    raise Reached, "#{const_name} is not defined after loading its file, so the fence cannot cover it; #{MESSAGE}"
  rescue LoadError, NameError => e
    raise Reached, "#{const_name} could not be loaded (#{e.class}), so the fence cannot cover it; #{MESSAGE}"
  end

  def self.fence_module(const_name, methods)
    return unless ensure_loaded(const_name)

    target = Object.const_get(const_name)
    methods.each do |name|
      next unless target.respond_to?(name, true)

      ::RSpec::Mocks.allow_message(target, name) { |*| raise Reached, "#{const_name}.#{name} #{MESSAGE}" }
    end
  end

  def self.fence_open3
    return unless defined?(Open3)

    ::RSpec::Mocks.allow_message(Open3, :capture3).and_wrap_original do |original, *args, **opts|
      raise Reached, "Open3.capture3(#{args.first}) #{MESSAGE}" if args.first.to_s.match?(TOOL)

      original.call(*args, **opts)
    end
  end
end

RSpec.configure do |config|
  config.before(:each) do |example|
    next if example.metadata[:real_keychain]

    RealKeychainFence.apply
  end
end
