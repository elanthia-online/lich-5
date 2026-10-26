# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require 'tmpdir'

RSpec.describe Lich::WebUI::WindowGeometryStore do
  around do |example|
    Dir.mktmpdir('geometry-spec') do |directory|
      @directory = directory
      example.run
    end
  end

  def page(name = 'map')
    Lich::WebUI::Page.new(owner: Struct.new(:name).new(name), id: 'main', title: 'Fixture') {}
  end

  it 'restores across fresh host instances and isolates scripts and characters without rewriting unchanged geometry' do
    context = ['GS', 'Fixture']
    store = described_class.new(directory: @directory, context: -> { context })
    original = page
    original.observe_window_geometry(width: 410, height: 310, position: [-500, 40])
    store.save(original)
    file = Dir[File.join(@directory, '*.json')].fetch(0)
    timestamp = File.mtime(file)
    store.save(original)
    expect(File.mtime(file)).to eq(timestamp)
    reopened = described_class.new(directory: @directory, context: -> { context })
    expect(reopened.read(page)).to eq(original.window_geometry)
    expect(reopened.read(page('spellson'))).to be_nil
    context = ['GS', 'Other']
    expect(reopened.read(page)).to be_nil
  end

  it 'does not replace a valid saved size with a minimized or unmeasured window' do
    store = described_class.new(directory: @directory, context: -> { 'fixture' })
    target = page
    store.save(target)
    expect(Dir.children(@directory)).to be_empty
    target.observe_window_geometry(width: 410, height: 310, position: [5, 40])
    store.save(target)
    target.observe_window_geometry(width: 0, height: 0, position: [5, 40])
    store.save(target)
    expect(store.read(target)).to include(width: 410, height: 310)
  end
end
