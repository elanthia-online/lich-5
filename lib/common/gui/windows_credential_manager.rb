# frozen_string_literal: true

# The Windows Credential Manager binding moved to
# lib/common/authentication/windows_credential_manager.rb. This name is kept
# for the GTK launcher and its specs; both constants are the same module.
require_relative '../authentication/windows_credential_manager'

module Lich
  module Common
    module GUI
      WindowsCredentialManager = Authentication::WindowsCredentialManager
    end
  end
end
