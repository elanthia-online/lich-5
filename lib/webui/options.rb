# frozen_string_literal: true

module Lich
  module WebUI
    # Process-wide WebUI settings taken from the command line before the
    # service exists: whether a fixed port is wanted, and whether Lich should
    # open a browser itself.
    #
    # The server stays on loopback. Players whose display is not where Lich
    # runs (an SSH tunnel, a headless box) forward that loopback port and
    # open the launch URL where their browser is; these two settings are
    # what make that possible: a port they can forward ahead of time, and
    # the URL printed instead of a window they cannot see.
    module Options
      class << self
        # @return [Integer] the port to bind; 0 asks the OS for a free one
        def port
          @port || 0
        end

        # @return [Boolean] whether Lich opens a browser window itself
        def open_browser?
          @open_browser.nil? ? true : @open_browser
        end

        # @param port [Integer, nil] a fixed port, or nil for ephemeral
        # @param open_browser [Boolean, nil] false to print the launch URL instead
        def configure(port: nil, open_browser: nil)
          @port = Integer(port) unless port.nil?
          @open_browser = open_browser unless open_browser.nil?
          self
        end

        def reset!
          @port = nil
          @open_browser = nil
        end
      end
    end
  end
end
