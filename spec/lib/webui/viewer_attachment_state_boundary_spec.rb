# frozen_string_literal: true

require_relative '../../spec_helper'
require 'timeout'
require 'webui/viewer_store'
require 'webui/page'

RSpec.describe Lich::WebUI::ViewerStore, 'attachment state boundary' do
  let(:store) { described_class.new }
  let(:page) do
    Lich::WebUI::Page.new(owner: Object.new, id: 'state', title: 'State') do
      text_input(key: 'name', value: 'Original', read_only: true)
    end
  end
  let(:viewer) { store.attach(connection_id: 'one', address: 'state', page: page) }
  let(:render) { page.render }
  let(:input) { render.tree.children.first }

  before { store.deliver(viewer, render) }

  it 'isolates public hash entries, nested values, strings and composite keys from retained state' do
    store.set_property(viewer, input, :value, +'Draft')
    store.set_property(viewer, input, :selection, [{ text: +'Nested' }])
    values = viewer.values
    values[[input.cid, :value]].replace('Changed')
    values[[input.cid, :selection]].first[:text].replace('Changed')
    values.keys.first << :corrupt
    values.clear

    expect(store.property(viewer, input, :value)).to eq('Draft')
    expect(store.property(viewer, input, :selection)).to eq([{ text: 'Nested' }])
    expect(viewer.values.keys).to contain_exactly([input.cid, :value], [input.cid, :selection])
    captured = viewer.values
    store.set_property(viewer, input, :value, 'Later')
    expect(captured[[input.cid, :value]]).to eq('Draft')
  end

  it 'protects delivered read-only evidence from public hash and string mutation' do
    store.set_property(viewer, input, :value, +'Delivered')
    store.snapshot(viewer, for_delivery: true)
    delivered = viewer.delivered_read_only
    delivered[input.cid].replace('Forged')
    delivered.clear
    expect(viewer.delivered_read_only).to eq(input.cid => 'Delivered')
    expect(store.read_only_submission(viewer, input, 'Delivered')).to eq('Delivered')
    expect { store.read_only_submission(viewer, input, 'Forged') }.to raise_error(Lich::WebUI::Protocol::Refusal)

    store.close(connection_id: 'one', address: 'state')
    expect(viewer.values).to be_empty
    expect(viewer.delivered_read_only).to be_empty
  end

  %i[values delivered_read_only].each do |reader|
    it "copies #{reader} under the same monitor as an atomic store mutation" do
      entered, release = Queue.new, Queue.new
      writer = Thread.new do
        store.seed_property(viewer, input.cid, :value) do
          entered << true
          release.pop
          'Updated'
        end
      end
      Timeout.timeout(1) { entered.pop }
      started = Queue.new
      reading = Thread.new { started << true; viewer.public_send(reader) }
      Timeout.timeout(1) { started.pop }
      expect(reading.join(0.05)).to be_nil
      release << true
      expect(writer.join(1)).to equal(writer)
      expect(reading.join(1)).to equal(reading)
      expect(reading.value).to eq(viewer.public_send(reader))
    ensure
      release << true if release
      writer&.join(1)
      reading&.join(1)
    end
  end
end
