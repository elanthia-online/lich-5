# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require_relative '../../../lib/main/startup_theme'

RSpec.describe 'WebUI theme preference' do
  def page(**props)
    Lich::WebUI::Page.new(owner: self, id: 'theme', title: 'Theme', props: props) { text(content: 'Unchanged') }
  end

  it 'uses the persisted preference on each render, while explicit page styling wins' do
    allow(Lich).to receive(:track_dark_mode).and_return(true)
    inherited = page
    expect(inherited.render.tree.props[:theme]).to eq('dark')
    expect(page(theme: :light).render.tree.props[:theme]).to eq('light')
    allow(Lich).to receive(:track_dark_mode).and_return(false)
    expect(inherited.render.tree.props[:theme]).to eq('light')
    expect(page(theme: :dark).render.tree.props[:theme]).to eq('dark')
  end

  it 'honors the original startup override and persistence path' do
    stored = false
    allow(Lich).to receive(:track_dark_mode) { stored }
    allow(Lich).to receive(:track_dark_mode=) { |value| stored = value }
    [true, false].each do |dark|
      Lich::Main::StartupTheme.apply(dark_mode: dark)
      expect(page.render.tree.props[:theme]).to eq(dark ? 'dark' : 'light')
      expect(Lich).to have_received(:track_dark_mode=).with(dark)
    end
  end

  it 'uses light when embedded without the Lich preference API' do
    allow(Lich).to receive(:respond_to?).and_call_original
    allow(Lich).to receive(:respond_to?).with(:track_dark_mode).and_return(false)
    expect(page.render.tree.props[:theme]).to eq('light')
  end
end
