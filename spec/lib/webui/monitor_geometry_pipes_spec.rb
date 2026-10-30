# frozen_string_literal: true

require_relative '../../spec_helper'
require 'rbconfig'
require 'webui/monitor_geometry'

RSpec.describe Lich::WebUI::MonitorGeometry do
  let(:geometry) { described_class.new }

  it 'keeps bounded stderr noise out of valid structured stdout without pipe deadlock' do
    script = 'STDERR.write("warning" * 9000); STDOUT.write(%q({"source":"native","screens":[]}))'
    output = geometry.send(:run, [RbConfig.ruby, '-e', script])
    expect(JSON.parse(output)).to eq('source' => 'native', 'screens' => [])
  end

  %w[STDOUT STDERR].each do |stream|
    it "bounds #{stream} independently and reaps the refused helper" do
      process = nil
      allow(Open3).to receive(:popen3).and_wrap_original do |original, *argv, &block|
        original.call(*argv) { |input, output, errors, waiter| process = waiter; block.call(input, output, errors, waiter) }
      end
      expect { geometry.send(:run, [RbConfig.ruby, '-e', "#{stream}.write('x' * 65_537); sleep 10"]) }
        .to raise_error(Lich::WebUI::Error, /output exceeds limit/)
      expect(process).not_to be_alive
    end
  end

  it 'terminates and reaps a helper that misses the discovery deadline' do
    process = nil
    allow(Open3).to receive(:popen3).and_wrap_original do |original, *argv, &block|
      original.call(*argv) { |input, output, errors, waiter| process = waiter; block.call(input, output, errors, waiter) }
    end
    expect { geometry.send(:run, [RbConfig.ruby, '-e', 'sleep 10']) }.to raise_error(Timeout::Error)
    expect(process).not_to be_alive
  end

  it 'refuses a failed helper even with syntactically valid stdout' do
    expect { geometry.send(:run, [RbConfig.ruby, '-e', 'puts "{}"; exit 1']) }
      .to raise_error(Lich::WebUI::Error, /discovery failed/)
  end
end
