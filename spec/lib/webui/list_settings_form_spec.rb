# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

RSpec.describe Lich::WebUI::ListSettingsForm do
  let(:host) { Lich::WebUI::Service.new }
  let(:items) { ['Keep spaces  ', 'duplicate', 'duplicate'] }
  let(:form) do
    described_class.new(owner: :fixture, id: 'lists', title: 'Lists', values: { items: items }, fields: [],
                        lists: { items: { columns: [{ key: 'text', label: 'Items' }],
                          rows: proc { items.map { |text| { 'text' => text } } },
                          add: proc { |text| items << text }, delete: proc { |index| items.delete_at(index) },
                          value: proc { items.dup } } },
                        layout: proc { |tree, field, save|
                          field.call(tree, :items)
                          field.call(tree, :items_entry)
                          field.call(tree, :items_add, label: 'Add')
                          field.call(tree, :items_delete, label: 'Delete')
                          save.call(tree, label: 'Close')
                        })
  end
  before do
    allow(Lich::WebUI).to receive(:service).and_return(host)
    allow(Lich::WebUI).to receive(:registry).and_return(host.registry)
    allow(Lich::WebUI).to receive(:start)
    allow(Lich::WebUI).to receive(:open).and_return(true)
  end
  after { form.close; host.stop }

  def event(label, value = nil)
    render = form.page.last_render
    button = render.tree.each.find { |node| node.props[:label] == label }
    submission = Lich::WebUI::Submission.new(viewer_id: 'fixture', values: render.submissions.fetch(button.cid, []).to_h { |cid| [cid, value] })
    render.bindings.fetch([button.cid, :activate]).call(Struct.new(:submission).new(submission))
  end

  it 'delegates list operations without trimming, sorting or deduplicating and submits original values' do
    form.show
    event('Add', ' New item ')
    expect(items).to eq(['Keep spaces  ', 'duplicate', 'duplicate', ' New item '])
    render = form.page.last_render
    table = render.tree.each.find { |node| node.type == :table }
    expect(table.props[:rows].map { |row| row[:key] }.uniq.length).to eq(4)
    render.bindings.fetch([table.cid, :selection_change]).call(Struct.new(:payload).new({ rows: [table.props[:rows][2][:key]] }))
    event('Delete')
    expect(items).to eq(['Keep spaces  ', 'duplicate', ' New item '])
    event('Close')
    expect(form.wait).to eq(items: items)
  end
end
