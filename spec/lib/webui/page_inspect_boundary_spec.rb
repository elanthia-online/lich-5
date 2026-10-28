# frozen_string_literal: true

require_relative '../../spec_helper'
require 'pp'
require 'webui/page'

RSpec.describe Lich::WebUI::Page do
  it 'inspects as owner label, id and title only, never its runtime, viewers, values or render' do
    owner = Struct.new(:webui_owner_id).new('owner-label')
    page = described_class.new(owner: owner, id: 'form', title: 'Form') do
      text_input(key: 'name', value: 'render-canary')
    end
    runtime = Object.new
    runtime.define_singleton_method(:inspect) { 'runtime-canary' }
    page.bind_runtime(runtime)
    page.render
    page.write_shared_value('name', :value, 'shared-canary')
    page.observe_monitors('viewer-canary', nil)

    expected = '#<Lich::WebUI::Page owner="owner-label" id="form" title="Form">'
    expect(page.inspect).to eq(expected)
    expect(PP.pp(page, +'').chomp).to eq(expected)
  end
end
