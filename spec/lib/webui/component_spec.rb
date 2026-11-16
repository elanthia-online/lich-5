# frozen_string_literal: true

require_relative '../../spec_helper'
require 'pp'
require 'webui/tree_builder'

RSpec.describe Lich::WebUI::Component do
  let(:canary) { 'canary-component-7d4a' }
  let(:tree) do
    builder = Lich::WebUI::TreeBuilder.new(owner: :fixture, page_id: 'spec-page', title: 'Spec')
    secret = canary
    builder.group do
      text_input(key: 'token', value: secret, sensitive: true)
      text_input(key: 'name', value: 'visible-name')
    end
    builder.password_input(key: 'password')
    builder.build
  end

  it 'visits nodes depth-first and finds an exact component ID' do
    expect(tree.each.map(&:cid)).to eq(
      %w[page:spec-page page:spec-page/group:0 page:spec-page/group:0/text_input:token
         page:spec-page/group:0/text_input:name page:spec-page/password_input:password]
    )
    expect(tree.find('page:spec-page/group:0/text_input:name').props[:value]).to eq('visible-name')
    expect(tree.find('missing')).to be_nil
  end

  it 'omits a sensitive value from the wire hash at every level but keeps the live prop' do
    token = tree.find('page:spec-page/group:0/text_input:token')

    expect(JSON.generate(tree.to_h)).not_to include(canary)
    expect(JSON.generate(tree.to_h)).to include('visible-name')
    expect(token.props[:value]).to eq(canary)
  end

  it 'redacts a sensitive value from inspect and pp, including through parent nodes' do
    token = tree.find('page:spec-page/group:0/text_input:token')

    [token.inspect, tree.inspect, PP.pp(token, +''), PP.pp(tree, +'')].each do |text|
      expect(text).not_to include(canary)
      expect(text).to include(Lich::WebUI::SensitiveValue::REDACTION)
    end
    expect(tree.inspect).to include('visible-name')
  end
end
