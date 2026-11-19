# frozen_string_literal: true

module Lich
  module WebUI
    class Runtime
      # Seconds during which one page logs at most one browser failure report.
      CLIENT_ERROR_LOG_INTERVAL = 60
      # Shipped renderer scripts; a position in any other file is logged as "other".
      CLIENT_ERROR_SCRIPTS = Dir.children(File.expand_path('../assets', __dir__)).grep(/\.js\z/).freeze

      private

      # Records a browser renderer failure for an attached viewer's page.
      # Nothing is sent back to the page. Each page logs one line per
      # CLIENT_ERROR_LOG_INTERVAL; later reports are counted and that count is
      # appended to the page's next logged line, so a failing render loop
      # cannot flood diagnostics. The line carries the owner label, page id,
      # generation, error class name and script positions, never free text.
      # Attachment is checked inside the window lock, so a page retired by
      # forget_client_errors cannot regain an entry.
      # @param connection [Object] authenticated transport
      # @param message [Hash] validated client_error envelope
      # @return [Symbol] :logged, or :suppressed inside the page's interval
      # @raise [Protocol::Refusal] when the viewer is not attached to the page
      # @api private
      def client_error(connection, message)
        page = nil
        suppressed = @client_error_mutex.synchronize do
          page = fetch_attachment(connection, message[:page]).page
          logged_at, count, report = Diagnostics.log_window(
            *@client_error_windows.fetch(page, [nil, 0]),
            now: Process.clock_gettime(Process::CLOCK_MONOTONIC), interval: CLIENT_ERROR_LOG_INTERVAL
          )
          @client_error_windows[page] = [logged_at, count]
          report
        end
        return :suppressed unless suppressed

        line = "WebUI client render failure owner=#{Diagnostics.display_label(owner_label(page.owner))} " \
               "page=#{page.id} generation=#{message[:generation]} error=#{message[:error]}"
        positions = client_error_positions(message[:frames])
        line += " at=#{positions}" unless positions.empty?
        line += " suppressed=#{suppressed}" if suppressed.positive?
        log(:error, line)
        :logged
      end

      # Joins validated script positions, naming only shipped renderer scripts.
      # @param frames [Array<String>, nil] validated file.js:line:column positions
      # @return [String] comma-separated positions, empty without frames
      # @api private
      def client_error_positions(frames)
        Array(frames).map do |frame|
          file, position = frame.split(':', 2)
          "#{CLIENT_ERROR_SCRIPTS.include?(file) ? file : 'other'}:#{position}"
        end.join(',')
      end

      # Releases the failure-report windows of pages that closed or whose owner
      # terminated, so a retired page is not retained by its window.
      # @param pages [Array<Page>] retired pages
      # @return [void]
      # @api private
      def forget_client_errors(pages)
        @client_error_mutex.synchronize { pages.each { |page| @client_error_windows.delete(page) } }
      end
    end
  end
end
