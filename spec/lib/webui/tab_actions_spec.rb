# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

RSpec.describe 'typed tab-strip actions' do
  let(:service) { Lich::WebUI::Service.new }
  let(:owner) { Object.new }
  let(:adapter) { Lich::WebUI::Adapter.new(owner: owner, service: service, viewer: 'one') }
  before { allow(service.runtime).to receive(:schedule_render) }
  after { service.stop }

  def nodes = adapter.instance_variable_get(:@nodes)

  it 'keeps page slots and pending selection independent of both action roles' do
    tabs = adapter.create(:tabs, names: [])
    pages = 3.times.map { adapter.create(:text, content: 'Page') }
    actions = %i[start end].to_h { |side| [side, adapter.create(:button, label: side.to_s)] }
    adapter.layout_tab_actions(tabs, actions: actions)
    adapter.layout_tabs(tabs, children: pages, names: %w[action_start end C], headers: %w[a b c].map { |key| { key: key } })
    adapter.set(tabs, :selected, 2)
    adapter.layout_tab_actions(tabs, actions: actions.slice(:end))
    expect(adapter.get(tabs, :selected)).to eq(2)
    expect(pages.map { |page| nodes.fetch(page).slot }).to eq(%w[action_start end C])
    adapter.layout_tabs(tabs, children: pages.drop(1), names: %w[end C], headers: %w[b c].map { |key| { key: key } })
    expect(adapter.get(tabs, :selected)).to eq(1)
    expect(nodes.fetch(tabs).children).to eq(pages.drop(1) + [actions[:end]])
    adapter.layout_tabs(tabs, children: [], names: [], headers: [])
    expect(nodes.fetch(tabs).children).to eq([actions[:end]])
    other = adapter.create(:stack, {})
    adapter.attach(other, actions[:start])
    expect(nodes.fetch(actions[:start]).placement).to be_empty
  end

  it 'admits native actions separately from page capacity and releases their parent-specific role on detach' do
    tabs = adapter.create(:tabs, names: ['end'])
    action, page = adapter.create(:button, label: 'Help'), adapter.create(:text, content: 'Page')
    adapter.attach(tabs, action, placement: { tab_action: :end })
    adapter.attach(tabs, page)
    expect(nodes.fetch(page).slot).to eq('end')
    expect(nodes.fetch(action).slot).to be_nil
    expect { adapter.attach(tabs, adapter.create(:button, label: 'Duplicate'), placement: { tab_action: :end }) }.to raise_error(Lich::WebUI::Error)
    adapter.detach(tabs, action)
    adapter.attach(adapter.create(:stack, {}), action)
    expect(adapter.get(action, :label)).to eq('Help')
  end

  it 'restores all action ownership and placement after publication refusal' do
    root, tabs = adapter.create(:page, title: 'Tabs'), adapter.create(:tabs, names: [])
    old, candidate = adapter.create(:button, label: 'Old'), adapter.create(:button, label: 'New')
    adapter.attach(root, tabs)
    adapter.layout_tab_actions(tabs, actions: { end: old })
    allow(adapter).to receive(:dirty!).and_raise(Lich::WebUI::Error, 'refused')
    expect { adapter.layout_tab_actions(tabs, actions: { start: candidate }) }.to raise_error(Lich::WebUI::Error, /refused/)
    expect(nodes.fetch(tabs).children).to eq([old])
    expect(nodes.fetch(old).parent).to equal(tabs)
    expect(nodes.fetch(old).placement).to eq(tab_action: 'end')
    expect(nodes.fetch(candidate).parent).to be_nil
    expect(nodes.fetch(candidate).placement).to be_empty
  end

  it 'refuses role changes through generic placement and rolls back failed action detach' do
    tabs, action = adapter.create(:tabs, names: []), adapter.create(:button, label: 'Help')
    adapter.layout_tab_actions(tabs, actions: { end: action })
    expect { adapter.place(tabs, action, {}) }.to raise_error(Lich::WebUI::Error, /layout_tab_actions/)
    expect { adapter.place(tabs, action, tab_action: :start) }.to raise_error(Lich::WebUI::Error, /layout_tab_actions/)
    allow(adapter).to receive(:dirty!).and_raise(Lich::WebUI::Error, 'refused')
    expect { adapter.detach(tabs, action) }.to raise_error(Lich::WebUI::Error, /refused/)
    expect(nodes.fetch(tabs).children).to eq([action])
    expect(nodes.fetch(action).parent).to equal(tabs)
    expect(nodes.fetch(action).placement).to eq(tab_action: 'end')
  end

  it 'rejects foreign ownership, page/action aliasing, cycles and malformed action maps' do
    tabs, button = adapter.create(:tabs, names: []), adapter.create(:button, label: 'Help')
    adapter.attach(adapter.create(:stack, {}), button)
    [{ wrong: button }, { end: button }, { end: tabs }, { end: adapter.create(:page, title: 'No') }, { start: tabs, end: tabs }].each do |actions|
      expect { adapter.layout_tab_actions(tabs, actions: actions) }.to raise_error(Lich::WebUI::Error)
      expect(nodes.fetch(tabs).children).to be_empty
    end
    action = adapter.create(:button, label: 'Action')
    adapter.layout_tab_actions(tabs, actions: { end: action })
    expect { adapter.layout_tabs(tabs, children: [action], names: ['Fake'], headers: [{ key: 'fake' }]) }.to raise_error(Lich::WebUI::Error)
    expect(adapter.get(tabs, :names)).to be_empty
  end

  def build_actions(placements)
    builder = Lich::WebUI::TreeBuilder.new(owner: owner, page_id: 'tabs', title: 'Tabs')
    builder.tabs(names: ['end']) do
      text(content: 'Actual page', slot: 'end', key: 'page')
      placements.each_with_index { |placement, index| button(label: 'Help', key: "help-#{index}", placement: placement) }
    end
    builder.build
  end

  it 'pins auxiliary placement in a captured render even when the action is later detached' do
    tabs = adapter.create(:tabs, names: ['Page'])
    adapter.attach(tabs, adapter.create(:text, content: 'Page'))
    action = adapter.create(:button, label: 'Help')
    adapter.layout_tab_actions(tabs, actions: { end: action })
    snapshot = adapter.send(:snapshot_children, nodes.fetch(tabs))
    adapter.layout_tab_actions(tabs, actions: {})
    builder = Lich::WebUI::TreeBuilder.new(owner: owner, page_id: 'snapshot', title: 'Snapshot')
    port = adapter
    builder.tabs(names: ['Page']) { port.send(:render_snapshot, self, snapshot, []) }
    tree = builder.build
    expect(tree.children.first.children.last.placement).to eq(tab_action: 'end')
    expect(nodes.fetch(action).placement).to be_empty
  end

  it 'validates typed auxiliary roles without reserving otherwise valid page names' do
    tree = build_actions([{ tab_action: :start }, { tab_action: :end }])
    tabs = tree.children.first
    expect(tabs.props[:names]).to eq(['end'])
    expect(tabs.children.map(&:slot)).to eq(['end', nil, nil])
    [[{ tab_action: :end }, { tab_action: :end }], [{ tab_action: :unknown }], [{ wrong: :end }]].each do |placements|
      expect { build_actions(placements) }.to raise_error(Lich::WebUI::SchemaViolationError)
    end
  end
end
