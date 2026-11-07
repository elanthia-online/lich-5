# frozen_string_literal: true

require_relative '../../spec_helper'
require 'tempfile'

RSpec.describe 'native image dimensions' do
  # Builds a BI_RGB fixture with complete DWORD-padded pixel rows.
  # @param width [Integer] pixel width
  # @param height [Integer] signed pixel height, negative for top-down rows
  # @param depth [Integer] bits per pixel
  # @return [String] binary BMP header and pixels
  def bmp(width = 2, height = 3, depth = 24)
    pixels = "\0".b * (((width * depth + 31) / 32) * 4 * height.abs)
    'BM'.b + [54 + pixels.bytesize, 0, 54, 40, width, height, 1, depth, 0, pixels.bytesize, 0, 0, 0, 0].pack('VVVVl<l<vvVVl<l<VV') + pixels
  end

  # Reads dimensions through the public API using a disposable image file.
  # @param bytes [String] binary image contents
  # @return [Array<Integer>] validated width and height
  def dimensions(bytes)
    Tempfile.create('webui-image') do |file|
      file.binmode
      file.write(bytes)
      file.flush
      Lich::WebUI::ImageSize.read(file.path)
    end
  end

  it 'reads PNG and GIF dimensions without a graphics dependency' do
    require 'webui/image_size'
    expect(dimensions([137, 80, 78, 71, 13, 10, 26, 10].pack('C*') + [13].pack('N') + 'IHDR' + [640, 480].pack('NN'))).to eq([640, 480])
    expect(dimensions('GIF89a' + [32, 48].pack('vv'))).to eq([32, 48])
  end

  it 'identifies image formats from headers rather than extensions with one bounded read' do
    require 'webui/image_size'
    fixtures = {
      'png'  => [137, 80, 78, 71, 13, 10, 26, 10].pack('C*') + [13].pack('N') + 'IHDR' + [20, 10].pack('NN'),
      'gif'  => 'GIF89a' + [20, 10].pack('vv'),
      'jpeg' => [255, 216, 255, 192].pack('C*') + [8, 8, 10, 20, 1].pack('nCnnC'),
      'bmp'  => bmp(20, -10, 32)
    }
    allow(File).to receive(:open).and_call_original
    fixtures.each do |format, bytes|
      Tempfile.create(['metadata', '.wrong']) do |file|
        file.binmode
        file.write(bytes)
        file.flush
        expect(File).to receive(:open).with(file.path, 'rb').once.and_call_original
        result = Lich::WebUI::ImageSize.info(file.path)
        expect(result).to be_frozen
        expect([result.format, result.width, result.height]).to eq([format, 20, 10])
      end
    end
  end

  it 'reads padded RGB BMP rows and top-down or 32-bit true-color images' do
    require 'webui/image_size'
    expect(dimensions(bmp)).to eq([2, 3])
    zero_size = bmp
    zero_size[34, 4] = [0].pack('V')
    expect(dimensions(zero_size)).to eq([2, 3])
    expect(dimensions(bmp(2, -3, 32))).to eq([2, 3])
    expect(dimensions(bmp(1024, 400))).to eq([1024, 400])
  end

  it 'refuses unsupported BMP variants, invalid offsets and truncated pixel rows' do
    require 'webui/image_size'
    [[14, [12].pack('V')], [26, [2].pack('v')], [28, [8].pack('v')],
     [30, [1].pack('V')], [10, [53].pack('V')], [10, [500].pack('V')],
     [2, [54].pack('V')]].each do |offset, replacement|
      malformed = bmp
      malformed[offset, replacement.bytesize] = replacement
      expect { dimensions(malformed) }.to raise_error(ArgumentError, /image/)
    end
    expect { dimensions(bmp.byteslice(0, 53)) }.to raise_error(ArgumentError, /image/)
    expect { dimensions(bmp.byteslice(0...-1)) }.to raise_error(ArgumentError, /image/)
    expect { dimensions(bmp(65_537, 1)) }.to raise_error(ArgumentError, /dimensions/)
  end

  it 'ignores differing BI_RGB image sizes while still rejecting missing pixel rows' do
    require 'webui/image_size'
    [24, 32].each do |depth|
      [1, 0xffff_ffff].each do |image_size|
        image = bmp(2, -3, depth)
        image[34, 4] = [image_size].pack('V')
        expect(dimensions(image)).to eq([2, 3])

        truncated = image.byteslice(0...-1)
        truncated[2, 4] = [truncated.bytesize].pack('V')
        expect { dimensions(truncated) }.to raise_error(ArgumentError, /image/)
      end
    end
  end

  it 'skips JPEG metadata segments and reads a start-of-frame header' do
    require 'webui/image_size'
    jpeg = [255, 216, 255, 224].pack('C*') + [6].pack('n') + 'test' + [255, 192].pack('C*') + [8, 8, 120, 160, 1].pack('nCnnC')
    expect(dimensions(jpeg)).to eq([160, 120])
  end

  it 'rejects truncated, unsupported and oversized images explicitly' do
    require 'webui/image_size'
    expect { dimensions('GIF89a') }.to raise_error(ArgumentError, /image/)
    expect { dimensions('arbitrary text') }.to raise_error(ArgumentError, /image/)
    expect { dimensions('GIF89a' + [0, 20].pack('vv')) }.to raise_error(ArgumentError, /dimensions/)
  end
end
