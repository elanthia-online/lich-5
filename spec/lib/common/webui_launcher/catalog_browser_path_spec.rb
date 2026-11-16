# frozen_string_literal: true

require 'tmpdir'
require_relative '../../../spec_helper'
require_relative '../../../login_spec_helper'
require 'common/webui_launcher/catalog'

RSpec.describe Lich::Common::WebUILauncher::Catalog, 'browser path setting' do
  let(:catalog) { described_class.new(data_dir: Dir.tmpdir) }

  it 'has no browser path until one is stored' do
    expect(catalog.browser_path).to be_nil
  end

  it 'stores and reads the chosen browser, and an empty path restores automatic detection' do
    expect(catalog.update_browser_path('/usr/bin/chromium')).to be(true)
    expect(catalog.browser_path).to eq('/usr/bin/chromium')

    expect(catalog.update_browser_path('')).to be(true)
    expect(catalog.browser_path).to be_nil
  end

  it 'reports a failed store and a failed read without raising' do
    failing = Class.new do
      def get_first_value(_query) = raise(IOError, 'synthetic')
      def execute(*_arguments) = raise(IOError, 'synthetic')
    end.new
    allow(Lich).to receive(:db).and_return(failing)

    expect(catalog.update_browser_path('/usr/bin/chromium')).to be(false)
    expect(catalog.browser_path).to be_nil
  end
end
