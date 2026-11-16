# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui/errors'

RSpec.describe Lich::WebUI::Diagnostics do
  it 'retains explicit owner IDs even when nil or false, ahead of a display name' do
    [nil, false, '', 'explicit-id'].each do |id|
      owner = Struct.new(:webui_owner_id, :name).new(id, 'display name')
      expect(described_class.owner_label(owner)).to equal(id)
    end
  end

  it 'retains truthy names including an empty string without coercion' do
    ['', 'display name', 7].each do |name|
      expect(described_class.owner_label(Struct.new(:name).new(name))).to equal(name)
    end
  end

  it 'falls back to class and object identity for absent, nil and false names' do
    [Object.new, Struct.new(:name).new(nil), Struct.new(:name).new(false)].each do |owner|
      expect(described_class.owner_label(owner)).to eq("#{owner.class}:#{owner.object_id}")
    end
  end

  it 'passes diagnostic arguments through and retains the sink result' do
    calls = []
    result = Object.new
    logger = ->(level, message) { calls << [level, message]; result }
    expect(described_class.log(logger, :warning, 'fixture message')).to equal(result)
    expect(calls).to eq([[:warning, 'fixture message']])
  end

  it 'isolates ordinary sink errors while leaving non-StandardError failures visible' do
    expect(described_class.log(->(*) { raise IOError, 'sink unavailable' }, :error, 'fixture')).to be_nil
    expect { described_class.log(->(*) { raise ScriptError, 'fatal fixture' }, :error, 'fixture') }.to raise_error(ScriptError)
  end
end
