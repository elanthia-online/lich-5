# frozen_string_literal: true

require_relative '../../spec_helper'
require 'socket'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'digest/sha1'
require 'base64'
require 'rbconfig'

RSpec.describe 'macOS native host presentation' do
  before(:all) do
    next unless ENV['NATIVE_HOST'] == '1' && RUBY_PLATFORM.include?('darwin')

    @directory = Dir.mktmpdir('lich-native-presentation')
    root = File.expand_path('../../..', __dir__)
    source = File.join(root, 'lib/webui/native/macos')
    app = File.join(@directory, 'PresentationChecks.app/Contents')
    FileUtils.mkdir_p([File.join(app, 'MacOS'), File.join(app, 'Resources')])
    FileUtils.cp(File.join(source, 'window.js'), File.join(app, 'Resources'))
    plist = File.read(File.join(source, 'Info.plist')).gsub('LichWebUI', 'PresentationChecks').gsub('org.lich.webui', 'org.lich.webui.presentation-checks')
    File.write(File.join(app, 'Info.plist'), plist)
    @executable = File.join(app, 'MacOS/PresentationChecks')
    output, status = Open3.capture2e('xcrun', 'swiftc', '-DWEBUI_HOST_TEST',
                                     '-target', "#{RbConfig::CONFIG.fetch('host_cpu')}-apple-macos14.0",
                                     '-module-cache-path', File.join(@directory, 'ModuleCache'),
                                     File.join(source, 'Host.swift'), File.join(source, 'ExternalLinks.swift'),
                                     File.join(root, 'spec/webui/native_presentation.swift'), '-o', @executable)
    raise "Native regression compilation failed: #{output}" unless status.success?
  end

  after(:all) { FileUtils.remove_entry(@directory) if @directory }

  before(:each, native_host: true) do
    skip 'Set NATIVE_HOST=1 on macOS to run AppKit/WebKit regressions' unless @executable
  end

  def check_presentation(steps, borderless: false)
    server = TCPServer.new('127.0.0.1', 0)
    port = server.addr[1]
    # Each WebSocket message arrives while the prior native state is in effect.
    # No evaluateJavaScript call wakes the hidden WebView for the test.
    worker = Thread.new do
      client = nil
      loop do
        client = server.accept
        request = client.gets
        next client.close unless request

        headers = {}
        while (line = client.gets) && line != "\r\n"
          name, value = line.split(':', 2)
          headers[name.downcase] = value.strip
        end
        target = request.split[1]
        if target == '/ws'
          accept = Base64.strict_encode64(Digest::SHA1.digest(headers.fetch('sec-websocket-key') + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'))
          client.write("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: #{accept}\r\n\r\n")
          steps.each_with_index do |state, index|
            sleep(index == 1 && steps.first == 'hidden' ? 15 : 1) if index.positive?
            message = JSON.generate(title: "phase-#{index}", hidden: state == 'hidden', borderless: borderless,
                                    minimized: state == 'minimized', minimized_revision: index)
            frame = message.bytesize < 126 ? [0x81, message.bytesize].pack('CC') : [0x81, 126, message.bytesize].pack('CCn')
            client.write(frame + message)
          end
        else
          body = <<~HTML
                   <!doctype html><title>Native presentation regression</title>
                   <script>
                     const socket = new WebSocket('ws://' + location.host + '/ws');
                     socket.onmessage = event => window.lichNativeWindow.present(JSON.parse(event.data));
                   </script>
                 HTML
          client.write("HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
        end
        client.close
      end
    rescue IOError, Errno::EBADF, Errno::EPIPE
      nil # The test owns and closes this disposable server.
    ensure
      client&.close
    end
    output, status = Open3.capture2e(@executable, "http://127.0.0.1:#{port}/", steps.join(','))
    expect(status.success?).to be(true), output
    expect(output.lines.grep(/^Verified /).length).to eq(steps.length)
  ensure
    server&.close
    worker&.join(2)
    worker&.kill if worker&.alive?
  end

  it 'serves a normal request after an empty connection closes' do
    allow(Open3).to receive(:capture2e) do |_executable, address, _steps|
      port = address.split(':').last.to_i
      TCPSocket.open('127.0.0.1', port) do |client|
        client.close_write
        expect(IO.select([client], nil, nil, 2)).not_to be_nil
        expect(client.read).to eq('')
      end
      TCPSocket.open('127.0.0.1', port) do |client|
        client.write("GET / HTTP/1.1\r\nHost: localhost\r\n\r\n")
        expect(IO.select([client], nil, nil, 2)).not_to be_nil
        expect(client.read).to include('HTTP/1.1 200 OK', 'new WebSocket')
      end
      ["Verified visible\n", instance_double(Process::Status, success?: true)]
    end

    check_presentation(['visible'])
  end

  it 'receives server reveals from initial hiding and repeated hide/show cycles', native_host: true do
    check_presentation(%w[hidden visible hidden visible hidden visible])
  end

  it 'minimizes and restores a borderless window twice', native_host: true do
    check_presentation(%w[visible minimized visible minimized visible], borderless: true)
  end
end
