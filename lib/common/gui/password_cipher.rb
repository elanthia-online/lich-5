# frozen_string_literal: true

# The password cipher moved to lib/common/authentication/password_cipher.rb.
# This name is kept for the GTK launcher and its specs; both constants are
# the same module.
require_relative '../authentication/password_cipher'

module Lich
  module Common
    module GUI
      PasswordCipher = Authentication::PasswordCipher
    end
  end
end
