# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui/browser_window'

RSpec.describe 'WebUI window host startup failure' do
  let(:url) { "http://127.0.0.1:4567/auth?token=#{'f' * 64}&to=%2F" }

  describe Lich::WebUI::BrowserLauncher do
    let(:logs) { [] }
    let(:failures) { [] }

    before { allow(Lich).to receive(:log) { |message| logs << message } }

    def open_with(**options)
      described_class.open(
        url, on_failure: ->(message) { failures << message },
             thread_factory: ->(&_block) { raise 'no monitor expected' }, **options
      )
    end

    it 'reports an authored requirement when no browser is available, not just the error class' do
      allow(File).to receive(:executable?).and_return(false)

      expect(open_with(platform: 'x86_64-linux', spawn: ->(*) { raise 'must not spawn' })).to be(false)
      expect(failures).to eq(['unable to open WebUI window: Google Chrome is required to open the WebUI launcher window'])
      expect(logs).to eq(['warning: unable to open WebUI window: Google Chrome is required to open the WebUI launcher window'])
    end

    it 'names only the failure class for an unexpected error and never echoes its message' do
      spawn = ->(*argv, **) { raise ArgumentError, "bad launch #{url} #{argv.inspect}" }

      expect(open_with(browser_path: '/bin/browser', spawn: spawn)).to be(false)
      expect(failures).to eq(['unable to open WebUI window: the window host could not be started (ArgumentError)'])
      expect((failures + logs).join).not_to include('token', 'f' * 64, 'launch')
    end

    it 'reports a failed start once, separately from a host that started and exited' do
      exits = []
      spawn = ->(*) { raise Errno::ENOENT, '/bin/browser' }

      expect(open_with(browser_path: '/bin/browser', spawn: spawn, on_exit: -> { exits << true })).to be(false)
      expect(failures.size).to eq(1)
      expect(failures.first).to include('Errno::ENOENT')
      expect(exits).to be_empty
    end

    it 'still returns false when the failure observer itself raises' do
      result = described_class.open(url, browser_path: '/bin/browser', spawn: ->(*) { raise IOError },
                                         on_failure: ->(_message) { raise 'observer failed' })
      expect(result).to be(false)
    end
  end

  describe Lich::WebUI::BrowserWindow do
    let(:closes) { [] }

    def window(opener)
      described_class.new(on_close: -> { closes << true }, opener: opener, terminate: ->(*) {})
    end

    it 'closes and notifies its owner once when the host fails to start' do
      host_window = window(->(*, **) { false })

      expect(host_window.open(url)).to be(false)
      expect(host_window).to be_closed
      expect(closes).to eq([true])
      expect(host_window.open(url)).to be(false)
      expect(closes).to eq([true])
    end

    it 'closes, notifies and re-raises when the opener raises' do
      host_window = window(->(*, **) { raise IOError, 'spawn failed' })

      expect { host_window.open(url) }.to raise_error(IOError, 'spawn failed')
      expect(host_window).to be_closed
      expect(closes).to eq([true])
    end

    it 'does not notify when closure was already requested during startup' do
      host_window = nil
      host_window = window(lambda do |*, **|
        host_window.close
        false
      end)

      expect(host_window.open(url)).to be(false)
      expect(closes).to be_empty
    end

    it 'does not notify after a successful start' do
      host_window = window(->(*, **) { true })

      expect(host_window.open(url)).to be(true)
      expect(host_window).not_to be_closed
      expect(closes).to be_empty
    end
  end
end
