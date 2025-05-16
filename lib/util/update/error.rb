# frozen_string_literal: true

module Lich
  module Util
    module Update
      # Base error class for Lich Update
      class Error < StandardError; end

      # Error raised when version is not supported
      class VersionError < Error; end

      # Error raised when network operations fail
      class NetworkError < Error; end

      # Error raised when file operations fail
      class FileError < Error; end

      # Error raised when validation fails
      class ValidationError < Error; end

      # Error raised when installation fails
      class InstallationError < Error; end
    end
  end
end
