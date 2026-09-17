# frozen_string_literal: true

# The keychain-backed master password manager moved to
# lib/common/authentication/master_password_manager.rb. This name is kept
# for the GTK launcher and its specs; both constants are the same module.
require_relative '../authentication/master_password_manager'

module Lich
  module Common
    module GUI
      MasterPasswordManager = Authentication::MasterPasswordManager
    end
  end
end
