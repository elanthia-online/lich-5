# frozen_string_literal: true

module Lich
  module WebUI
    class Runtime
      # Seconds during which one page logs at most one browser failure report.
      CLIENT_ERROR_LOG_INTERVAL = 60
      # Characters of report text kept in a log line, per field.
      CLIENT_ERROR_LOG_CHARACTERS = { message: 200, stack: 600 }.freeze

      private

      # Records a browser renderer failure for an attached viewer's page.
      # Nothing is sent back to the page. Each page logs one line per
      # CLIENT_ERROR_LOG_INTERVAL; later reports are counted and that count is
      # appended to the page's next logged line, so a failing render loop
      # cannot flood diagnostics.
      # @param connection [Object] authenticated transport
      # @param message [Hash] validated client_error envelope
      # @return [Symbol] :logged, or :suppressed inside the page's interval
      # @raise [Protocol::Refusal] when the viewer is not attached to the page
      # @api private
      def client_error(connection, message)
        page = fetch_attachment(connection, message[:page]).page
        suppressed = @client_error_mutex.synchronize do
          logged_at, count = @client_error_windows[page]
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          if logged_at && now - logged_at < CLIENT_ERROR_LOG_INTERVAL
            @client_error_windows[page] = [logged_at, count + 1]
            next
          end
          @client_error_windows[page] = [now, 0]
          count.to_i
        end
        return :suppressed unless suppressed

        line = "WebUI client render failure owner=#{owner_label(page.owner)} page=#{page.id} " \
               "generation=#{message[:generation]} message=#{client_error_text(message[:message], :message)}"
        line += " stack=#{client_error_text(message[:stack], :stack)}" if message.key?(:stack)
        line += " suppressed=#{suppressed}" if suppressed.positive?
        log(:error, line)
        :logged
      end

      # Reduces browser-supplied text to one bounded, quoted, printable ASCII
      # token: ASCII whitespace and control runs collapse to a space, any other
      # non-ASCII character becomes "?", and long hexadecimal runs are redacted
      # so no credential-shaped value reaches the log through a report.
      # @param text [String] validated report field
      # @param field [Symbol] :message or :stack, selecting the length bound
      # @return [String] quoted single-line text
      # @api private
      def client_error_text(text, field)
        printable = text.to_s.dup.force_encoding(Encoding::UTF_8).scrub('?')
                        .gsub(/[\x00-\x20\x7F]+/, ' ').gsub(/[^\x20-\x7E]/, '?')
                        .gsub(/\h{32,}/, '[redacted]').strip
        printable[0, CLIENT_ERROR_LOG_CHARACTERS.fetch(field)].inspect
      end
    end
  end
end
