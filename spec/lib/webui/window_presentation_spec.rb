# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

# keep_above and opacity are window-manager properties: a page cannot raise
# its own window, and a CSS fade only dims the page because what shows through
# is the browser's own background. These reach the real OS window instead.
RSpec.describe Lich::WebUI::WindowPresentation do
  # A stand-in for user32, recording what it was asked to do. Every spec runs
  # against this, so none of them need a real window or a real Windows.
  let(:win32) do
    Class.new do
      attr_reader :calls
      attr_accessor :ex_style, :style, :windows

      def initialize
        @calls = []
        @windows = []
        @ex_style = 0x200100
        @style = 0x16CF0000
      end

      # windows is a list of [hwnd, visible, pid, owner, class_name]
      def EnumWindows(callback, _lparam)
        @windows.each { |(hwnd, *)| break if callback.call(Fiddle::Pointer.new(hwnd), 0).zero? }
        1
      end

      def IsWindowVisible(hwnd) = row(hwnd)[1] ? 1 : 0
      def IsWindow(_hwnd) = 1
      def GetWindow(hwnd, _flag) = Fiddle::Pointer.new(row(hwnd)[3])

      def GetWindowThreadProcessId(hwnd, buffer)
        buffer[0, 4] = [row(hwnd)[2]].pack('L')
        1
      end

      def GetClassNameW(hwnd, buffer, _max)
        name = row(hwnd)[4].encode('UTF-16LE')
        buffer[0, name.bytesize] = name
        row(hwnd)[4].length
      end

      def SetWindowPos(hwnd, insert_after, *rest)
        @calls << [:set_window_pos, hwnd.to_i, insert_after.to_i, rest.last]
        1
      end

      # -20 is GWL_EXSTYLE (layered), -16 is GWL_STYLE (caption). They are
      # different words and must not share a value.
      def GetWindowLongW(_hwnd, index) = index == -16 ? @style : @ex_style

      def SetWindowLongW(hwnd, index, value)
        index == -16 ? @style = value : @ex_style = value
        @calls << [:set_window_long, hwnd.to_i, value]
        1
      end

      def SetLayeredWindowAttributes(hwnd, _key, alpha, flags)
        @calls << [:set_alpha, hwnd.to_i, alpha, flags]
        1
      end

      private

      def row(hwnd)
        @windows.find { |candidate| candidate[0] == hwnd.to_i } || [hwnd.to_i, false, 0, 0, '']
      end
    end.new
  end

  before do
    described_class.win32 = win32
    described_class.available_override = true
    described_class.thread_factory = ->(&block) { block.call; nil }
    described_class.sleeper = ->(_seconds) {}
  end

  after { described_class.reset_seams! }

  describe 'availability' do
    it 'reports nothing to offer when the host cannot reach the window' do
      described_class.available_override = false

      expect(described_class.support).to eq({})
    end

    it 'offers exactly the properties a page cannot do itself' do
      expect(described_class.support).to eq(always_on_top: true, opacity: true)
    end
  end

  describe 'finding the browser window' do
    it 'takes the one visible top-level window belonging to the process' do
      win32.windows = [
        [11, false, 4242, 0, 'Chrome_WidgetWin_1'],  # invisible helper
        [12, true,  4242, 0, 'Chrome_WidgetWin_1'],  # the window
        [13, true,  4242, 99, 'Chrome_WidgetWin_1'], # owned, so not top-level
        [14, true,  9999, 0, 'Chrome_WidgetWin_1'],  # another process
      ]

      expect(described_class.find_window(4242).to_i).to eq(12)
    end

    # A browser that reused an existing process owns many windows, and dressing
    # up the wrong one would make the player's own browser topmost and
    # translucent. Refusing to guess is the safe answer.
    it 'refuses to choose when the process owns more than one' do
      win32.windows = [
        [21, true, 4242, 0, 'Chrome_WidgetWin_1'],
        [22, true, 4242, 0, 'Chrome_WidgetWin_1'],
      ]

      expect(described_class.find_window(4242)).to be_nil
    end

    it 'is nil when the process owns no window at all' do
      win32.windows = [[31, true, 9999, 0, 'Chrome_WidgetWin_1']]

      expect(described_class.find_window(4242)).to be_nil
    end
  end

  describe 'applying the properties' do
    let(:hwnd) { Fiddle::Pointer.new(500) }

    it 'raises the window with a pointer-width sentinel, not a truncated integer' do
      described_class.apply(hwnd, always_on_top: true, opacity: 1.0)

      call = win32.calls.find { |entry| entry.first == :set_window_pos }
      # HWND_TOPMOST is -1. Passed as a 32-bit long it arrives as
      # 0x00000000FFFFFFFF on this ABI -- an invalid handle -- and the call
      # silently does nothing while reporting no error.
      expect(call[2]).to eq(-1)
      # SWP_NOACTIVATE, or every re-apply steals focus from the game.
      expect(call[3] & 0x0010).to eq(0x0010)
    end

    it 'lowers the window again when the script turns keep-above off' do
      described_class.apply(hwnd, always_on_top: false, opacity: 1.0)

      expect(win32.calls.find { |entry| entry.first == :set_window_pos }[2]).to eq(-2)
    end

    it 'makes the window layered once and sets the alpha' do
      described_class.apply(hwnd, always_on_top: false, opacity: 0.5)

      expect(win32.calls).to include([:set_window_long, 500, 0x200100 | 0x80000])
      expect(win32.calls).to include([:set_alpha, 500, 128, 0x2])
    end

    it 'restores an opaque window without disturbing the z-order bit' do
      described_class.apply(hwnd, always_on_top: false, opacity: 1.0)

      expect(win32.calls).to include([:set_alpha, 500, 255, 0x2])
      # Never written through SetWindowLong; z-order belongs to SetWindowPos.
      expect(win32.calls.none? { |entry| entry.first == :set_window_long && entry[2] & 0x8 != 0 }).to be(true)
    end

    # Chromium draws its own title bar inside the client area, so clearing
    # WS_CAPTION removes a frame that was never there: measured on a real
    # window, the whole non-client region is 8px of resize border. The
    # property is accepted and ignored rather than faked.
    it 'does not pretend to undecorate a window whose frame it cannot touch' do
      described_class.apply(Fiddle::Pointer.new(500), always_on_top: false, opacity: 1.0, borderless: true)

      # Only the layered bit is ever written; the window style is untouched.
      expect(win32.style).to eq(0x16CF0000)
    end

    it 'does nothing at all when the host cannot reach the window' do
      described_class.available_override = false

      expect(described_class.apply(hwnd, always_on_top: true, opacity: 0.5)).to be(false)
      expect(win32.calls).to be_empty
    end

    it 'reports failure rather than raising when a call blows up' do
      allow(win32).to receive(:SetWindowPos).and_raise(Fiddle::DLError, 'boom')

      expect(described_class.apply(hwnd, always_on_top: true, opacity: 1.0)).to be(false)
    end
  end

  describe 'discovery' do
    it 'hands back the window once it appears' do
      win32.windows = [[77, true, 4242, 0, 'Chrome_WidgetWin_1']]
      found = nil

      described_class.discover(4242) { |hwnd| found = hwnd }

      expect(found.to_i).to eq(77)
    end

    it 'gives up rather than polling forever when no window arrives' do
      win32.windows = []
      found = :unset

      described_class.discover(4242, timeout: 0.3) { |hwnd| found = hwnd }

      expect(found).to be_nil
    end
  end
end
