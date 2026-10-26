# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

RSpec.describe 'parent-relative placement and slots' do
  let(:owner) { Struct.new(:name).new('placement-owner') }
  let(:service) { Lich::WebUI::Service.new }
  let(:adapter) { Lich::WebUI::Adapter.new(owner: owner, service: service) }
  after { service.stop }

  cases = [
    ['last grid cell', :grid, { cols: 3 }, { column: 3, span: 1, row: 1024, row_span: 1 }, nil, nil],
    ['parent-relative span', :grid, { cols: 3 }, { span: 4 }, ['must be <= 3', 'placement.span'], ['must be <= 3', 'placement.span']],
    ['invalid row type', :grid, { cols: 3 }, { row: '2' }, ['must be an Integer', 'placement.row'], ['must be an Integer', 'placement.row']],
    ['ending row overflow', :grid, { cols: 3 }, { row: 1024, row_span: 2 }, ['child placement exceeds grid rows', :row_span], ['child placement exceeds grid rows', :children]],
    ['ending column difference', :grid, { cols: 3 }, { column: 3, span: 2 }, ['child placement exceeds grid columns', :span], nil],
    ['spread row difference', :grid, { cols: 3, row_sizing: :spread }, {}, nil, ['spread grid sizing requires an explicit row for every child', :children]],
    ['column before row overflow', :grid, { cols: 3 }, { column: 3, span: 2, row: 1024, row_span: 2 }, ['child placement exceeds grid columns', :span], ['child placement exceeds grid rows', :children]],
    ['unknown-key refusal order', :grid, { cols: 3 }, { span: 'bad', unknown: 1 }, ['must be an Integer', 'placement.span'], ['unknown child placement unknown', :children]],
    ['unpositioned coordinates', :overlay, {}, { x: 1, y: 2 }, ['coordinates require a positioned overlay', :placement], ['coordinates require a positioned overlay', :children]],
    ['positioned coordinate bounds', :overlay, { positioned: true }, { x: -65_536, y: 65_536 }, nil, nil],
    ['coordinate overflow', :overlay, { positioned: true }, { x: 65_537 }, ['must be <= 65536', 'placement.x'], ['must be <= 65536', 'placement.x']],
  ]

  cases.each do |label, type, props, placement, imperative_error, declarative_error|
    it "preserves Adapter admission and attribution for #{label}" do
      parent = adapter.create(type, props)
      child = adapter.create(:text, content: 'Child', placement: placement)
      action = -> { adapter.attach(parent, child) }
      if imperative_error
        message, field = imperative_error
        expect(&action).to raise_error(Lich::WebUI::Error) { |error|
          expected_class = field.is_a?(String) ? Lich::WebUI::SchemaViolationError : Lich::WebUI::Error
          expect(error.class).to eq(expected_class)
          expect(error.message.split(' (').first).to eq(message)
          expect(error.field).to eq(field)
          expect(error.owner).to eq('placement-owner')
          expect(error.page_id).to eq('adapter-unrendered')
          expect(error.cid).to match(/\Aopaque-/)
        }
        expect(adapter.instance_variable_get(:@nodes).fetch(parent).children).to be_empty
      else
        expect(&action).not_to raise_error
        expect(adapter.instance_variable_get(:@nodes).fetch(parent).children).to eq([child])
      end
    end

    it "preserves TreeBuilder admission and attribution for #{label}" do
      builder = Lich::WebUI::TreeBuilder.new(owner: owner, page_id: 'rules', title: 'Rules')
      child = nil
      parent = builder.component(type, key: 'parent', **props) { child = text(key: 'child', content: 'Child', placement: placement) }
      if declarative_error
        message, field = declarative_error
        expect { builder.build }.to raise_error(Lich::WebUI::SchemaViolationError) { |error|
          expect(error.message.split(' (').first).to eq(message)
          expect(error.field).to eq(field)
          expect(error.owner).to eq('placement-owner')
          expect(error.page_id).to eq('rules')
          expect(error.cid).to eq(field == :children ? parent.cid : child.cid)
        }
      else
        expect { builder.build }.not_to raise_error
      end
    end
  end

  [[:split, { orientation: :horizontal }, %w[first second]],
   [:columns, { count: 2 }, %w[0 1]],
   [:tabs, { names: %w[Named Other] }, %w[Named Other]]].each do |type, props, slots|
    it "derives matching #{type} slots through imperative and declarative consumers" do
      parent = adapter.create(type, props)
      children = slots.map { |slot| adapter.create(:text, content: slot) }
      children.each { |child| adapter.attach(parent, child) }
      nodes = adapter.instance_variable_get(:@nodes)
      expect(children.map { |child| nodes.fetch(child).slot }).to eq(slots)

      builder = Lich::WebUI::TreeBuilder.new(owner: owner, page_id: 'rules', title: 'Rules')
      builder.component(type, key: 'parent', **props) { slots.each { |slot| text(content: slot, slot: slot) } }
      expect(builder.build.children.first.children.map(&:slot)).to eq(slots)
    end
  end

  it 'keeps dynamic imperative slot numbering after a capacity reduction until publication' do
    parent = adapter.create(:columns, count: 2)
    children = 2.times.map { adapter.create(:text, content: 'Child') }
    children.each { |child| adapter.attach(parent, child) }
    adapter.set(parent, :count, 1)
    nodes = adapter.instance_variable_get(:@nodes)
    expect(children.map { |child| nodes.fetch(child).slot }).to eq(%w[0 1])
  end
end
