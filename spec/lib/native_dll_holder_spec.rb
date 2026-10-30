# frozen_string_literal: true

require_relative '../support/native_dll_holder'

RSpec.describe NativeDirectoryHandle do
  let(:api) { double('Windows directory API') }
  let(:error_source) { double('Fiddle saved error', win32_last_error: 32) }
  let(:directory) { 'C:/native extension' }
  let(:encoded) { directory.encode('UTF-16LE').b + [0].pack('v') }

  before do
    allow(api).to receive(:CreateFileW).with(encoded, 1, 3, 0, 3, 0x02000000, 0).and_return(101)
    allow(api).to receive(:CreateFileW).with(encoded, 0x00010000, 7, 0, 3, 0x02000000, 0).and_return(-1)
    expect(api).not_to receive(:GetLastError)
    allow(api).to receive(:CloseHandle)
  end

  it 'uses sharing-checked access and verifies delete denial before yielding readiness' do
    expect(api).to receive(:CreateFileW).with(encoded, 1, 3, 0, 3, 0x02000000, 0).ordered.and_return(101)
    expect(error_source).to receive(:win32_last_error).ordered.and_return(0)
    expect(api).to receive(:CreateFileW).with(encoded, 0x00010000, 7, 0, 3, 0x02000000, 0).ordered.and_return(-1)
    expect(error_source).to receive(:win32_last_error).ordered.and_return(32)
    expect { |ready| described_class.hold(directory, api: api, error_source: error_source, &ready) }.to yield_control
    expect(api).to have_received(:CloseHandle).with(101).once
  end

  it 'preserves the failed native call error before converting its handle' do
    saved = Struct.new(:win32_last_error).new(0)
    probe = Object.new
    probe.define_singleton_method(:to_i) { saved.win32_last_error = 0; -1 }
    allow(api).to receive(:CreateFileW).with(encoded, 0x00010000, 7, 0, 3, 0x02000000, 0) do
      saved.win32_last_error = 32
      probe
    end
    expect { |ready| described_class.hold(directory, api: api, error_source: saved, &ready) }.to yield_control
    expect(saved.win32_last_error).to eq(0)
    expect(api).to have_received(:CloseHandle).with(101).once
  end

  it 'rejects an ineffective hold and closes both successful handles without signaling readiness' do
    allow(api).to receive(:CreateFileW).with(encoded, 0x00010000, 7, 0, 3, 0x02000000, 0).and_return(202)
    expect { described_class.hold(directory, api: api, error_source: error_source) { raise 'incorrect readiness signal' } }.to raise_error(/did not block delete access/)
    expect(api).to have_received(:CloseHandle).with(202).once
    expect(api).to have_received(:CloseHandle).with(101).once
  end

  it 'does not mistake a different probe error for established sharing contention' do
    allow(error_source).to receive(:win32_last_error).and_return(5)
    expect { described_class.hold(directory, api: api, error_source: error_source) { raise 'incorrect readiness signal' } }.to raise_error(/unexpected delete-access probe failure.*5/)
    expect(api).to have_received(:CloseHandle).with(101).once
  end

  [-1, (1 << (Fiddle::SIZEOF_VOIDP * 8)) - 1].each do |invalid|
    it "rejects invalid handle representation #{invalid} without closing it" do
      allow(api).to receive(:CreateFileW).with(encoded, 1, 3, 0, 3, 0x02000000, 0).and_return(invalid)
      allow(error_source).to receive(:win32_last_error).and_return(5)
      expect { described_class.hold(directory, api: api, error_source: error_source) { raise 'incorrect readiness signal' } }.to raise_error(/could not hold.*5/)
      expect(api).not_to have_received(:CloseHandle)
    end
  end

  it 'releases the held directory when the parent interaction fails' do
    expect { described_class.hold(directory, api: api, error_source: error_source) { raise IOError, 'parent gone' } }.to raise_error(IOError, 'parent gone')
    expect(api).to have_received(:CloseHandle).with(101).once
  end
end
