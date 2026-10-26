# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui/viewer_store'
require 'webui/page'

RSpec.describe Lich::WebUI::ViewerStore do
  let(:owner) { Object.new }
  let(:page) do
    Lich::WebUI::Page.new(owner: owner, id: 'form', title: 'Form') do
      text_input(key: 'name', value: '')
    end
  end

  it 'retires only an unambiguous exited viewer after copying its closing state' do
    store = described_class.new
    viewer = store.attach(connection_id: 'old', address: 'form', page: page)
    render = page.render
    store.deliver(viewer, render)
    input = render.tree.children.first
    store.set_property(viewer, input, :value, 'Closing draft')
    store.transient_disconnect('old')
    snapshot = store.closing_snapshot(page, retire: true)
    expect(snapshot.values[[input.cid, :value]]).to eq('Closing draft')
    expect(viewer.values).to be_empty
    expect(store.closing_snapshot(page)).to be_nil

    first = store.attach(connection_id: 'new', address: 'form', page: page, resume_token: viewer.resume_token)
    expect(first).not_to equal(viewer)
    store.deliver(first, render)
    second = store.attach(connection_id: 'other', address: 'form', page: page)
    store.deliver(second, render)
    expect(store.closing_snapshot(page, retire: true)).to be_nil
    expect(store.attachments_for(page)).to eq([first, second])
  end

  it 'applies new tree-row expansion defaults without resetting retained viewer choices' do
    rows = [{ key: 'old', cells: { name: 'Old' }, expanded: true }]
    table_page = Lich::WebUI::Page.new(owner: owner, id: 'tree', title: 'Tree') do
      table(key: 'tree', columns: [{ key: 'name', label: 'Name' }], rows: rows)
    end
    store = described_class.new
    viewer = store.attach(connection_id: 'one', address: 'tree', page: table_page)
    first = table_page.render
    store.deliver(viewer, first)
    component = first.tree.each.find { |node| node.type == :table }
    store.update(viewer, component, :row_toggle, row: 'old', expanded: false)
    rows = rows + [{ key: 'new', cells: { name: 'New' }, expanded: true }]
    store.deliver(viewer, table_page.render)
    rendered = store.serialize(viewer)[:children].first[:props]
    expect(rendered[:expanded]).to eq(['new'])
    expect(rendered[:rows].map { |row| row[:expanded] }).to eq([false, true])
  end

  it 'refuses repeated attachment without retaining unreachable viewers' do
    now = 100.0
    store = described_class.new(clock: -> { now })
    first = store.attach(connection_id: 'one', address: 'page-one', page: page)
    first.values[:draft] = 'retained'
    3.times do
      expect { store.attach(connection_id: 'one', address: 'page-one', page: page) }
        .to raise_error(Lich::WebUI::Error, /already attached/)
    end
    expect(store.attachments_for(page)).to eq([first])
    expect(store.transient_disconnect('one')).to eq([first])
    now += described_class::RECONNECT_WINDOW + 1
    expect(store.attachments_for(page)).to be_empty
    expect(first.values).to be_empty
  end

  it 'does not orphan either viewer when a resume targets an occupied connection/page pair' do
    store = described_class.new
    first = store.attach(connection_id: 'one', address: 'page-one', page: page)
    store.transient_disconnect('one')
    second = store.attach(connection_id: 'two', address: 'page-one', page: page)
    expect do
      store.attach(connection_id: 'two', address: 'page-one', page: page, resume_token: first.resume_token)
    end.to raise_error(Lich::WebUI::Error, /already attached/)
    expect(store.fetch(connection_id: 'two', address: 'page-one')).to equal(second)
    expect(store.attach(connection_id: 'three', address: 'page-one', page: page, resume_token: first.resume_token)).to equal(first)
    store.close(connection_id: 'two', address: 'page-one')
    store.close(connection_id: 'three', address: 'page-one')
    expect(store.attachments_for(page)).to be_empty
  end

  it 'keeps viewer-local values isolated and shared display content common' do
    store = described_class.new
    first = store.attach(connection_id: 'one', address: 'page-one', page: page)
    second = store.attach(connection_id: 'two', address: 'page-one', page: page)
    first_render = page.render
    second_render = page.render
    store.deliver(first, first_render)
    store.deliver(second, second_render)
    first_input = first_render.tree.each.find { |component| component.type == :text_input }

    store.update(first, first_input, :change, value: 'Alice')

    expect(store.serialize(first).dig(:children, 0, :props, :value)).to eq('Alice')
    expect(store.serialize(second).dig(:children, 0, :props, :value)).to eq('')
  end

  it 'refuses serialization before a render has been delivered' do
    store = described_class.new
    attachment = store.attach(connection_id: 'one', address: 'page-one', page: page)

    expect { store.serialize(attachment) }.to raise_error(Lich::WebUI::Error, /no delivered render/)
  end

  it 'snapshots input acknowledgments with viewer values and discards removed identities' do
    store = described_class.new
    first = store.attach(connection_id: 'one', address: 'form', page: page)
    second = store.attach(connection_id: 'two', address: 'form', page: page)
    render = page.render
    [first, second].each { |viewer| store.deliver(viewer, render) }
    input = render.tree.children.first
    store.update(first, input, :change, { value: 'Drea' }, 11)
    captured = store.snapshot(first)
    store.update(first, input, :change, { value: 'Dreaven' }, 12)
    expect(captured.input_requests).to eq(input.cid => 11)
    expect(captured.values[[input.cid, :value]]).to eq('Drea')
    expect(store.snapshot(first).input_requests).to eq(input.cid => 12)
    expect(store.snapshot(second).input_requests).to be_empty
    empty = Lich::WebUI::Page.new(owner: owner, id: 'form', title: 'Empty') {}.render
    store.deliver(first, empty)
    expect(store.snapshot(first).input_requests).to be_empty
    store.close(connection_id: 'two', address: 'form')
    expect(second.input_requests).to be_empty
  end

  it 'refuses radio selection before a render has been delivered without changing viewer state' do
    target = Lich::WebUI::Page.new(owner: owner, id: 'radio', title: 'Radio') do
      radio_option(group: 'choice', label: 'One', checked: true)
    end
    store = described_class.new
    attachment = store.attach(connection_id: 'one', address: 'radio', page: target)
    component = target.render.tree.children.first

    expect { store.select_radio_option(attachment, component) }
      .to raise_error(Lich::WebUI::Error, 'viewer has no delivered render')
    expect(attachment.values).to be_empty
    expect(attachment.render).to be_nil
  end

  it 'ignores an older delivery without reverting the tree or viewer selections' do
    choices = [{ value: 'old', label: 'Old' }]
    target = Lich::WebUI::Page.new(owner: owner, id: 'choices', title: 'Choices') do
      select(key: 'choice', options: choices, value: choices.first[:value])
    end
    store = described_class.new
    attachment = store.attach(connection_id: 'one', address: 'choices', page: target)
    older = target.render
    choices.replace([{ value: 'new', label: 'New' }])
    newer = target.render
    store.deliver(attachment, newer)
    values = attachment.values.dup

    store.deliver(attachment, older)

    expect(attachment.delivered_generation).to eq(newer.generation)
    expect(attachment.render).to equal(newer)
    expect(attachment.values).to eq(values)
    expect(store.serialize(attachment).dig(:children, 0, :props, :value)).to eq('new')
    store.deliver(attachment, newer)
    expect(attachment.render).to equal(newer)
  end

  it 'retains a moved divider whose initial position was naturally sized, isolated by viewer' do
    target = Lich::WebUI::Page.new(owner: owner, id: 'split', title: 'Split') do
      split(key: 'row', orientation: :horizontal) do
        text(slot: :first, content: 'Duration')
        text(slot: :second, content: 'Spell')
      end
    end
    store = described_class.new
    first = store.attach(connection_id: 'one', address: 'split', page: target)
    second = store.attach(connection_id: 'two', address: 'split', page: target)
    render = target.render
    [first, second].each { |viewer| store.deliver(viewer, render) }
    divider = render.tree.children.first
    store.update(first, divider, :move, position: 35)
    [first, second].each { |viewer| store.deliver(viewer, target.render) }
    expect(store.serialize(first).dig(:children, 0, :props, :position)).to eq(35)
    expect(store.serialize(second).dig(:children, 0, :props)).not_to have_key(:position)
  end

  it 'clears a removed select choice for each viewer while retaining other valid choices' do
    options = [{ value: 'none', label: '' }, { value: 'old', label: 'Old' }, { value: 'keep', label: 'Keep' }]
    page = Lich::WebUI::Page.new(owner: owner, id: 'choices', title: 'Choices') do
      select(key: 'choice', options: options, value: 'none')
    end
    store = described_class.new
    first = store.attach(connection_id: 'one', address: 'choices', page: page)
    second = store.attach(connection_id: 'two', address: 'choices', page: page)
    render = page.render
    [first, second].each { |viewer| store.deliver(viewer, render) }
    input = render.tree.each.find { |node| node.type == :select }
    store.update(first, input, :change, value: 'old')
    store.update(second, input, :change, value: 'keep')
    options.delete_at(1)
    render = page.render
    [first, second].each { |viewer| store.deliver(viewer, render) }
    expect(store.serialize(first).dig(:children, 0, :props, :value)).to eq('none')
    expect(store.serialize(second).dig(:children, 0, :props, :value)).to eq('keep')
  end

  it 'resumes within the transient window and destroys values after expiry' do
    now = 100.0
    store = described_class.new(clock: -> { now })
    attachment = store.attach(connection_id: 'one', address: 'page-one', page: page)
    render = page.render
    store.deliver(attachment, render)
    input = render.tree.each.find { |component| component.type == :text_input }
    store.update(attachment, input, :change, value: 'retained')
    store.transient_disconnect('one')

    resumed = store.attach(
      connection_id: 'two', address: 'page-one', page: page, resume_token: attachment.resume_token
    )
    expect(resumed).to equal(attachment)
    expect(resumed.values[[input.cid, :value]]).to eq('retained')

    store.transient_disconnect('two')
    now += described_class::RECONNECT_WINDOW + 1
    fresh = store.attach(
      connection_id: 'three', address: 'page-one', page: page, resume_token: attachment.resume_token
    )
    expect(fresh).not_to equal(attachment)
    expect(attachment.values).to be_empty
  end

  it 'destroys all viewer state when its page owner terminates' do
    store = described_class.new
    attachment = store.attach(connection_id: 'one', address: 'page-one', page: page)
    store.deliver(attachment, page.render)

    store.destroy_page(page)

    expect(attachment.values).to be_empty
    expect { store.fetch(connection_id: 'one', address: 'page-one') }.to raise_error(Lich::WebUI::Error)
  end

  it 'retains false viewer values when a later render redeclares a true default' do
    page = Lich::WebUI::Page.new(owner: owner, id: 'expander', title: 'Expander') do
      expander(key: 'details', label: 'Details', open: true) { text(content: 'body') }
    end
    store = described_class.new
    attachment = store.attach(connection_id: 'one', address: 'page-one', page: page)
    first = page.render
    store.deliver(attachment, first)
    expander = first.tree.each.find { |component| component.type == :expander }
    store.update(attachment, expander, :toggle, open: false)

    store.deliver(attachment, page.render)

    serialized = store.serialize(attachment)
    expect(serialized.dig(:children, 0, :props, :open)).to be false
  end
  it 'retains a viewer radio choice when a new selected default joins its group' do
    add_option = false
    target = Lich::WebUI::Page.new(owner: owner, id: 'radio', title: 'Radio') do
      radio_option(key: 'one', group: 'mode', label: 'One', checked: !add_option)
      radio_option(key: 'two', group: 'mode', label: 'Two', checked: false)
      radio_option(key: 'three', group: 'mode', label: 'Three', checked: true) if add_option
    end
    store = described_class.new
    viewer = store.attach(connection_id: 'one', address: 'radio', page: target)
    render = target.render
    store.deliver(viewer, render)
    store.select_radio_option(viewer, render.tree.children[1])
    add_option = true
    store.deliver(viewer, target.render)
    expect(store.serialize(viewer)[:children].map { |node| node[:props][:checked] }).to eq([false, true, false])
    fresh = store.attach(connection_id: 'fresh', address: 'radio', page: target)
    store.deliver(fresh, target.render)
    expect(store.serialize(fresh)[:children].map { |node| node[:props][:checked] }).to eq([false, false, true])
  end
end
