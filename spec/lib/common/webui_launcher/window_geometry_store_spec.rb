# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'tmpdir'
require 'common/webui_launcher/window_geometry_store'

RSpec.describe Lich::Common::WebUILauncher::WindowGeometryStore do
  it 'migrates valid GTK geometry and then prefers WebUI geometry' do
    Dir.mktmpdir do |data_dir|
      File.write(File.join(data_dir, 'login_gui_settings.yml'), YAML.dump(
                                                                  width: 900, height: 700, position: [120, 80]
                                                                ))
      store = described_class.new(data_dir: data_dir)

      expect(store.load).to eq(width: 900, height: 700, position: [120, 80])
      expect(store.save('width' => 1000, 'height' => 760, 'position' => [-200, 40]))
        .to eq(width: 1000, height: 760, position: [-200, 40])
      expect(store.load).to eq(width: 1000, height: 760, position: [-200, 40])
      expect(File.stat(File.join(data_dir, described_class::FILE_NAME)).mode & 0o777).to eq(0o600)
    end
  end

  it 'rejects malformed and unbounded geometry' do
    store = described_class.new(data_dir: Dir.tmpdir)

    expect(store.validate(width: 900, height: 700, position: nil))
      .to eq(width: 900, height: 700, position: nil)
    expect(store.validate(width: 200, height: 700, position: [0, 0])).to be_nil
    expect(store.validate(width: 900, height: 700, position: [100_000, 0])).to be_nil
    expect(store.validate(width: '900', height: 700, position: [0, 0])).to be_nil
  end
end
