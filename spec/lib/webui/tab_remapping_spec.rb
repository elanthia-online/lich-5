# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../support/webui_shim_bindings'
require 'webui'
require_relative '../../../lib/common/script_scope'

RSpec.describe 'stable tab selection across structural edits' do
  let(:owner) { Struct.new(:name).new('tab-remapping.lic') }

  cases = [
    ['reordered identity', %w[a b c], 1, [{ key: 'c' }, { key: 'a' }, { key: 'b' }], 2],
    ['preceding removal', %w[a b c], 2, [{ key: 'b' }, { key: 'c' }], 1],
    ['selected removal', %w[a b c], 1, [{ key: 'a' }, { key: 'c' }], 1],
    ['last removal', %w[a b c], 2, [{ key: 'a' }, { key: 'b' }], 1],
    ['hidden identity', %w[a b c], 1, [{ key: 'b', hidden: true }, { key: 'a' }, { key: 'c' }], 1],
    ['all hidden', %w[a b c], 2, [{ key: 'b', hidden: true }, { key: 'a', hidden: true }], 0],
    ['empty collection', %w[a b c], 2, [], 0],
    ['missing old headers', nil, 2, [{ key: 'b' }, { key: 'a' }], 1],
    ['disabled identity', %w[a b c], 1, [{ key: 'b', disabled: true }, { key: 'a' }], 0],
  ]

  context 'imperative defaults and pending viewer writes' do
    let(:service) { Lich::WebUI::Service.new }
    let(:viewer) { Struct.new(:viewer_id).new('pending') }
    let(:adapter) { Lich::WebUI::Adapter.new(owner: owner, service: service, viewer: viewer) }
    after { service.stop }

    cases.each do |label, old_keys, index, headers, expected|
      it "preserves #{label} for authored and pending selections" do
        original = old_keys || %w[a b c]
        props = { names: original, selected: index }
        props[:headers] = old_keys.map { |key| { key: key } } if old_keys
        tabs = adapter.create(:tabs, **props)
        children = (original + headers.map { |header| header[:key] }).uniq.to_h do |key|
          [key, adapter.create(:text, content: key)]
        end
        original.each { |key| adapter.attach(tabs, children.fetch(key)) }
        adapter.set(tabs, :selected, index)

        adapter.layout_tabs(tabs, children: headers.map { |header| children.fetch(header[:key]) },
                            names: headers.map { |header| header[:key] }, headers: headers)
        expect(adapter.get(tabs, :selected)).to eq(expected)
        viewer.viewer_id = 'fresh'
        expect(adapter.get(tabs, :selected)).to eq(expected)
      end
    end
  end

  context 'delivered viewer choices' do
    cases.each do |label, old_keys, index, headers, expected|
      it "preserves #{label} independently of the replacement authored default" do
        props = { names: old_keys || %w[a b c], selected: index }
        props[:headers] = old_keys.map { |key| { key: key } } if old_keys
        target = Lich::WebUI::Page.new(owner: owner, id: 'tabs', title: 'Tabs') { tabs(key: 'pages', **props) }
        store = Lich::WebUI::ViewerStore.new
        viewer = store.attach(connection_id: 'viewer', address: 'tabs', page: target)
        store.deliver(viewer, target.render)
        props = { names: headers.map { |header| header[:key] }, headers: headers, selected: 0 }

        store.deliver(viewer, target.render)
        expect(store.serialize(viewer).dig(:children, 0, :props, :selected)).to eq(expected)
      end
    end

    it 'remaps divergent viewers separately and preserves the no-new-headers guard' do
      props = { names: %w[a b c], headers: %w[a b c].map { |key| { key: key } }, selected: 0 }
      target = Lich::WebUI::Page.new(owner: owner, id: 'tabs', title: 'Tabs') { tabs(key: 'pages', **props) }
      store = Lich::WebUI::ViewerStore.new
      viewers = %w[one two].map { |id| store.attach(connection_id: id, address: 'tabs', page: target) }
      render = target.render
      viewers.each { |viewer| store.deliver(viewer, render) }
      viewers.zip([1, 2]).each { |viewer, index| store.set_property(viewer, render.tree.children.first, :selected, index) }
      props = { names: %w[c a b], headers: %w[c a b].map { |key| { key: key } }, selected: 0 }
      render = target.render
      viewers.each { |viewer| store.deliver(viewer, render) }
      expect(viewers.map { |viewer| store.serialize(viewer).dig(:children, 0, :props, :selected) }).to eq([2, 0])

      props = { names: ['Only'], selected: 0 }
      render = target.render
      viewers.each { |viewer| store.deliver(viewer, render) }
      expect(viewers.map { |viewer| store.serialize(viewer).dig(:children, 0, :props, :selected) }).to eq([2, 0])
    end
  end

  context 'Notebook shadow state' do
    include WebUISpecSupport::ShimBindings
    let(:scope) { Lich::Common::ScriptScope }
    let(:gtk) { scope.const_get(:Gtk, false) }
    let(:service) { Lich::WebUI::Service.new }
    before { install_webui_shim_bindings }
    after do
      Lich::Common::ScriptDeath.run(owner)
      service.stop
    end

    it 'retains the selected page across removal and falls back when it becomes hidden' do
      notebook = gtk::Notebook.new
      pages = %w[a b c].map { |key| gtk::Label.new(key) }
      pages.each { |page| notebook.append_page(page, gtk::Label.new(page.text)) }
      notebook.set_current_page(2)
      notebook.remove_page(0)
      expect(notebook.send(:read, :selected)).to eq(1)
      pages.last.hide
      expect(notebook.send(:read, :selected)).to eq(0)
      pages.last.show
      expect(notebook.send(:read, :selected)).to eq(0)
      notebook.remove_page(0)
      expect(notebook.send(:read, :selected)).to eq(0)
      notebook.remove_page(0)
      expect(notebook.send(:read, :selected)).to eq(0)
    end
  end
end
