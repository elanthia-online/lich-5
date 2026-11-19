# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# The JavaScript value conversions of the Jint 4 stand-in. Expected strings are Remix's own
# output through genieflow (probes and the frozen t227/t229
# goldens): `jscall` stores Jint's ToString ("1e+21"), echo/setVar get the CLR object's
# ToString ("1E+21", "True").
RSpec.describe Lich::Genie::JsValue do
  null = described_class::NULL

  describe '.to_string (ECMA-262 ToString, Number::toString)' do
    {
      1e21 => '1e+21', 1e20 => '100000000000000000000', -0.0 => '0', 0.000001 => '0.000001',
      1e-7 => '1e-7', 1.5e-7 => '1.5e-7', 123_456_789_012.0 => '123456789012', 0.1 => '0.1', -2.5 => '-2.5',
      1.5e300 => '1.5e+300', 5e-324 => '5e-324', Float::NAN => 'NaN', Float::INFINITY => 'Infinity',
      -Float::INFINITY => '-Infinity', 1500.0 => '1500', 31.0 => '31'
    }.each do |number, text|
      it "formats #{number.inspect} as #{text}" do
        expect(described_class.to_string(number)).to eq(text)
      end
    end

    it 'formats the other primitives' do
      expect([true, false, nil, null, 'x', ''].map { |v| described_class.to_string(v) }).to eq(['true', 'false', 'undefined', 'null', 'x', ''])
    end
  end

  describe '.clr_string (the CLR object a host function receives, then ToString)' do
    it 'formats numbers like .NET double.ToString and booleans like bool.ToString (t229)' do
      expect([1e21, -0.0, 0.1, 1e16, 1e17, 0.00001, 3.0, true, false].map { |v| described_class.clr_string(v) })
        .to eq(%w[1E+21 -0 0.1 10000000000000000 1E+17 1E-05 3 True False])
    end

    it 'is nil for undefined and null (IsNothing)' do
      expect([described_class.clr_string(nil), described_class.clr_string(null)]).to eq([nil, nil])
    end
  end

  describe '.param_string (a CLR string parameter: Jint converts with ToString)' do
    it 'reads getVar(1.5) as "1.5", getVar(true) as "true", getVar(1e21) as "1e+21"; nil for undefined/null' do
      expect([1.5, true, 1e21, 'n', nil, null].map { |v| described_class.param_string(v) }).to eq(['1.5', 'true', '1e+21', 'n', nil, nil])
    end
  end

  describe '.index0 and .call_to_string (member reads)' do
    it 'gives a string its first character and any other primitive undefined' do
      expect([described_class.index0('%x'), described_class.index0(''), described_class.index0(5.0), described_class.index0(true)])
        .to eq(['%', nil, nil, nil])
    end

    it "throws Jint 4's TypeError on undefined and null (t227)" do
      expect { described_class.index0(nil) }.to raise_error(Lich::Genie::JsRuntime::JsError, "Cannot read property '0' of undefined")
      expect { described_class.index0(null) }.to raise_error(Lich::Genie::JsRuntime::JsError, "Cannot read property '0' of null")
      expect { described_class.call_to_string(nil) }
        .to raise_error(Lich::Genie::JsRuntime::JsError, "Cannot read property 'toString' of undefined")
    end

    it 'converts a number for toString like ToString (buildArray("a", 42) -> "42")' do
      expect(described_class.call_to_string(42.0)).to eq('42')
    end
  end

  describe '.to_number and .to_uint32 (the doReplace "length" path)' do
    it 'parses strings like StringToNumber' do
      cases = { '' => 0.0, '  2 ' => 2.0, '0x1F' => 31.0, '0o17' => 15.0, '0b11' => 3.0, '-Infinity' => -Float::INFINITY,
                '1.' => 1.0, '.5' => 0.5, '+1e3' => 1000.0, "#{[0xA0].pack('U')}4#{[0xFEFF].pack('U')}" => 4.0 }
      cases.each { |text, number| expect(described_class.to_number(text)).to eq(number), text.inspect }
      %w[x 1_0 0x 08x 1e].each { |text| expect(described_class.to_number(text)).to be_nan, text }
    end

    it 'converts the other primitives' do
      expect([true, false, null].map { |v| described_class.to_number(v) }).to eq([1.0, 0.0, 0.0])
      expect(described_class.to_number(nil)).to be_nan
    end

    it 'wraps modulo 2**32 and maps NaN/Infinity to 0' do
      expect([-1.0, 4_294_967_296.0, 2.7, Float::NAN, Float::INFINITY].map { |n| described_class.to_uint32(n) }).to eq([4_294_967_295, 0, 2, 0, 0])
    end
  end

  describe '.split_bar / .join_bar' do
    it 'splits like String.prototype.split("|"): "" is one empty element, empties kept' do
      expect([described_class.split_bar(''), described_class.split_bar('a||b|')]).to eq([[''], ['a', '', 'b', '']])
    end

    it 'joins holes, undefined and null as empty and numbers/booleans with ToString' do
      expect(described_class.join_bar(['a', nil, null, 5.0, true, 0.5])).to eq('a|||5|true|0.5')
    end
  end
end
