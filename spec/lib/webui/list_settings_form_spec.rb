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
                        layout: layout)
  end
  let(:layout) do
    proc { |tree, field, save|
      field.call(tree, :items)
      field.call(tree, :items_entry)
      field.call(tree, :items_add, label: 'Add')
      field.call(tree, :items_delete, label: 'Delete')
      save.call(tree, label: 'Close')
    }
  end
  before do
    allow(Lich::WebUI).to receive(:service).and_return(host)
    allow(Lich::WebUI).to receive(:registry).and_return(host.registry)
    allow(Lich::WebUI).to receive(:start)
    allow(Lich::WebUI).to receive(:open).and_return(true)
  end
  after { form.close; host.stop }

  let(:viewers) { host.runtime.instance_variable_get(:@viewers) }
  let(:attachment) do
    viewers.attach(connection_id: 'fixture', address: host.registry.address_for(form.page), page: form.page).tap do |viewer|
      viewers.deliver(viewer, form.page.last_render)
    end
  end
  let(:callback_event) { Struct.new(:viewer_id, :payload, :submission) }

  def table
    form.page.last_render.tree.each.find { |node| node.type == :table }
  end

  def event(label, value = nil)
    render = form.page.last_render
    button = render.tree.each.find { |node| node.props[:label] == label }
    submission = Lich::WebUI::Submission.new(viewer_id: attachment.viewer_id, values: render.submissions.fetch(button.cid, []).to_h { |cid| [cid, value] })
    render.bindings.fetch([button.cid, :activate]).call(callback_event.new(attachment.viewer_id, {}, submission))
  end

  # Records the choice in the viewer store, then notifies the form as the runtime does.
  def select_row(row)
    form.page.set(table.cid, :selected, [row], viewer: attachment.viewer_id)
    form.page.last_render.bindings.fetch([table.cid, :selection_change]).call(callback_event.new(attachment.viewer_id, { rows: [row] }, nil))
  end

  # Reads the viewer's own selection after it has received the newest render.
  def highlight
    viewers.deliver(attachment, form.page.last_render)
    form.page.get(table.cid, :selected, viewer: attachment.viewer_id)
  end

  it 'delegates list operations without trimming, sorting or deduplicating and submits original values' do
    form.show
    event('Add', ' New item ')
    expect(items).to eq(['Keep spaces  ', 'duplicate', 'duplicate', ' New item '])
    expect(table.props[:rows].map { |row| row[:key] }.uniq.length).to eq(4)
    select_row(table.props[:rows][2][:key])
    event('Delete')
    expect(items).to eq(['Keep spaces  ', 'duplicate', ' New item '])
    event('Close')
    expect(form.wait).to eq(items: items)
  end

  it 'clears the acting viewer selection after Add so Delete cannot act on a stale highlight' do
    form.show
    select_row('row-1')
    expect(highlight).to eq(['row-1'])
    event('Add', 'added')
    expect(highlight).to eq([])
    event('Delete')
    expect(items).to eq(['Keep spaces  ', 'duplicate', 'duplicate', 'added'])
  end

  it 'does not leave the viewer selection on the row that moved into a deleted position' do
    form.show
    select_row('row-0')
    event('Delete')
    expect(items).to eq(%w[duplicate duplicate])
    expect(highlight).to eq([])
    event('Delete')
    expect(items).to eq(%w[duplicate duplicate])
  end

  it 'still deletes and refreshes when the acting viewer has left before its callback runs' do
    form.show
    select_row('row-0')
    viewers.close(connection_id: 'fixture', address: attachment.address)
    expect { event('Delete') }.to(change { form.page.last_render.generation })
    expect(items).to eq(%w[duplicate duplicate])
    expect(table.props[:rows].length).to eq(2)
  end

  context 'when the layout omits the list table' do
    let(:layout) do
      proc { |tree, field, save|
        field.call(tree, :items_entry)
        field.call(tree, :items_add, label: 'Add')
        save.call(tree, label: 'Close')
      }
    end

    it 'still adds and refreshes' do
      form.show
      expect { event('Add', 'added') }.to(change { form.page.last_render.generation })
      expect(items).to eq(['Keep spaces  ', 'duplicate', 'duplicate', 'added'])
    end
  end
end
