# frozen_string_literal: true

# The saved-login account manager moved to
# lib/common/authentication/account_manager.rb. This name is kept for the
# GTK launcher and its specs; both constants are the same module.
require_relative '../authentication/account_manager'

module Lich
  module Common
    module GUI
      AccountManager = Authentication::AccountManager
    end
  end
end
