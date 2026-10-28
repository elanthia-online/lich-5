# frozen_string_literal: true

require_relative '../../spec_helper'
require 'tmpdir'
require 'webui/browser_launcher'

RSpec.describe Lich::WebUI::BrowserLauncher do
  let(:logs) { [] }

  before { allow(Lich).to receive(:log) { |message| logs << message } }

  it 'logs a credential-safe manual-cleanup path when profile removal fails' do
    Dir.mktmpdir('lich-webui-browser-') do |profile_dir|
      File.write(File.join(profile_dir, 'launch.url'), "http://127.0.0.1:1/auth?token=#{'f' * 64}")
      allow(FileUtils).to receive(:remove_entry_secure).and_raise(Errno::EACCES, profile_dir)

      expect { described_class.remove_profile(profile_dir) }.not_to raise_error
      expect(logs).to eq(["warning: WebUI launch profile cleanup failed (Errno::EACCES); remove #{profile_dir} manually"])
      expect(logs.join).not_to include('f' * 64)
    end
  end

  it 'does not raise when the diagnostic sink itself fails' do
    allow(FileUtils).to receive(:remove_entry_secure).and_raise(Errno::EACCES)
    allow(Lich).to receive(:log).and_raise('sink failed')

    Dir.mktmpdir('lich-webui-browser-') do |profile_dir|
      expect { described_class.remove_profile(profile_dir) }.not_to raise_error
    end
  end
end
