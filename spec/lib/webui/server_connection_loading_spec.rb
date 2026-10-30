# frozen_string_literal: true

require_relative '../../spec_helper'
require 'open3'
require 'rbconfig'

RSpec.describe 'Server connection loading' do
  %w[webui/server webui/server/connection].each do |entry|
    it "loads through #{entry} with framing, close and class identity intact" do
      code = <<~RUBY_CODE
        require '#{entry}'
        require 'timeout'
        klass = Lich::WebUI::Server::Connection
        sender, receiver = Socket.pair(:UNIX, :STREAM, 0)
        begin
          connection = klass.new(sender)
          abort 'bad viewer identity' unless connection.viewer_id.match?(/\\Aviewer-[0-9a-f]{32}\\z/)
          abort 'wrong deadline' unless klass::WRITE_TIMEOUT == 10.0
          abort 'text write failed' unless connection.send_text('ready')
          frame = Timeout.timeout(2) { Lich::WebUI::WebSocket.read_frame(receiver, require_mask: false) }
          abort 'wrong text frame' unless frame.text? && frame.payload == 'ready'
          abort 'pong write failed' unless connection.send_pong('echo')
          pong = Timeout.timeout(2) { Lich::WebUI::WebSocket.read_frame(receiver, require_mask: false) }
          abort 'wrong pong frame' unless pong.opcode == Lich::WebUI::WebSocket::OPCODE_PONG && pong.payload == 'echo'
          connection.close
          close = Timeout.timeout(2) { Lich::WebUI::WebSocket.read_frame(receiver, require_mask: false) }
          abort 'wrong close frame' unless close.close? && close.payload.unpack1('n') == 1000
          abort 'still alive' if connection.alive?
          abort 'stream not shut down' unless Timeout.timeout(2) { receiver.read } == ''
          require 'webui/server'
          require 'webui/server/connection'
          abort 'class replaced' unless klass.equal?(Lich::WebUI::Server::Connection)
          abort 'closed stream accepted another write' unless connection.send_text('late') == false
          puts 'ready'
        ensure
          sender.close
          receiver.close
        end
      RUBY_CODE
      output, errors, status = Open3.capture3(RbConfig.ruby, '-w', '-I', LIB_DIR, '-e', code)
      expect(status.success?).to be(true), errors
      expect(errors).to be_empty
      expect(output).to eq("ready\n")
    end
  end
end
