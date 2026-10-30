# frozen_string_literal: true

require_relative '../../spec_helper'
require 'json'
require 'psych'
require 'securerandom'
require 'webui/sensitive_value'

RSpec.describe Lich::WebUI::SensitiveValue do
  let(:secret) { 'canary-92b3f6a9' }

  it 'redacts conversion, inspection, JSON, YAML, and Marshal serialization for both origins', security_id: 'sec-sensitive-carrier' do
    %i[viewer server].each do |origin|
      carrier = described_class.new(secret, origin: origin)
      representations = [
        carrier.to_s, carrier.inspect, "value=#{carrier}", JSON.generate(carrier),
        Psych.dump(carrier), Marshal.dump(carrier),
      ]

      expect(representations).to all(include(described_class::REDACTION))
      expect(representations).to all(satisfy { |representation| !representation.include?(secret) })
    end
  end

  it 'keeps a high-entropy canary and its fragments out of every registered bulk sink', security_id: 'sec-bulk-leakage' do
    canary = "canary-#{SecureRandom.hex(24)}"
    carrier = described_class.server(canary)
    sinks = {
      'bulk state payload' => JSON.generate(value: carrier),
      'log line'           => "credential=#{carrier}",
      'telemetry record'   => JSON.generate(event: 'credential', value: carrier.as_json),
      'error output'       => StandardError.new("credential=#{carrier.inspect}").full_message,
    }

    fragments = [canary, canary[0, 8], canary[-8, 8]]
    expect(sinks.keys).to contain_exactly('bulk state payload', 'log line', 'telemetry record', 'error output')
    expect(sinks.values).to all(satisfy { |value| fragments.none? { |fragment| value.include?(fragment) } })
  ensure
    carrier&.discard!
  end

  it 'provides plaintext to one consuming block and clears it afterward' do
    carrier = described_class.viewer(secret)
    observed = carrier.consume { |value| value.dup }

    expect(observed).to eq(secret)
    expect(carrier).to be_consumed
    expect { carrier.consume { nil } }.to raise_error(Lich::WebUI::ConsumedSensitiveValueError)
  end

  it 'requires a declared origin and a string value' do
    expect { described_class.new(secret, origin: :keychain) }.to raise_error(ArgumentError, /unknown sensitive origin/)
    expect { described_class.server(nil) }.to raise_error(ArgumentError, /must be a String/)
  end

  it 'can be forcibly discarded when its one callback opportunity ends unused' do
    carrier = described_class.server(secret)

    expect(carrier.discard!).to be true
    expect(carrier.discard!).to be false
    expect { carrier.consume { nil } }.to raise_error(Lich::WebUI::ConsumedSensitiveValueError)
  end
  it 'G3 RC32 refuses dup and clone without changing the original lifecycle' do
    %i[viewer server].each do |origin|
      carrier = described_class.new(secret, origin: origin)
      expect { carrier.dup }.to raise_error(TypeError, /cannot be copied/)
      expect { carrier.clone }.to raise_error(TypeError, /cannot be copied/)
      expect { carrier.clone(freeze: false) }.to raise_error(TypeError, /cannot be copied/)
      expect(carrier).not_to be_consumed
      expect(carrier.consume(&:dup)).to eq(secret)
      expect(carrier).to be_consumed
    end
  end

  it 'G3 RC33 refuses freezing while keeping consume and discard available' do
    carrier = described_class.viewer(secret)
    expect { carrier.freeze }.to raise_error(TypeError, /cannot be frozen/)
    expect(carrier).not_to be_frozen
    expect(carrier.discard!).to be true
    expect(carrier.discard!).to be false
    expect { carrier.consume { nil } }.to raise_error(Lich::WebUI::ConsumedSensitiveValueError)
    consumable = described_class.server(secret)
    expect { consumable.freeze }.to raise_error(TypeError)
    expect(consumable.consume(&:dup)).to eq(secret)
    expect(consumable).to be_consumed
  end
end
