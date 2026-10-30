# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui/window_presentation'

RSpec.describe Lich::WebUI::WindowPresentation::Controller do
  let(:logs) { [] }
  # Enumerates no windows, so discovery never finds an owned handle.
  let(:win32) do
    Class.new do
      attr_reader :writes

      def initialize = @writes = []
      def EnumWindows(*) = 1
      def SetWindowPos(*args) = (@writes << args) && 1
    end.new
  end

  before { allow(Lich).to receive(:log) { |message| logs << message } }

  it 'names the unavailable capabilities when discovery times out and keeps accepting renders' do
    clock = [0.0]
    controller = described_class.new(win32: win32, thread_factory: ->(&work) { work.call },
                                     sleeper: ->(*) { clock[0] += 1 }, clock: -> { clock[0] })
    controller.start(42)

    expected = 'warning: WebUI window presentation unavailable (always_on_top, opacity, hidden): ' \
               'no single owned browser window was found within 15 seconds; the window remains usable without them'
    expect(logs).to eq([expected])
    render = Struct.new(:generation, :tree, :facilities).new(
      2, Struct.new(:props).new({ presentation: { opacity: 0.5 } }), { presentation: {} }
    )
    expect { controller.update(render) }.not_to raise_error
    expect(win32.writes).to be_empty
    expect(logs.size).to eq(1)
  end
end
