# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

RSpec.describe Lich::WebUI::Page do
  let(:owner) { Object.new }

  it 'renders stable keyed cids and strictly increasing generations' do
    items = %w[a b]
    page = described_class.new(owner: owner, id: 'items', title: 'Items') do
      stack do
        collection(items) { |item| button(key: item, label: item) }
      end
    end

    first = page.render
    items.reverse!
    second = page.render
    first_cids = first.tree.each.select { |node| node.type == :button }.map(&:cid)
    second_cids = second.tree.each.select { |node| node.type == :button }.map(&:cid)

    expect(second.generation).to be > first.generation
    expect(second_cids).to contain_exactly(*first_cids)
  end

  it 'requires author keys for direct children of variable collections' do
    page = described_class.new(owner: owner, id: 'items', title: 'Items') do
      stack { collection([1]) { |item| text content: item.to_s } }
    end

    expect { page.render }
      .to raise_error(Lich::WebUI::IdentityError, /author key required.*owner=.*page=items/)
  end

  it 'retains outer collection key requirements after a nested collection finishes' do
    page = described_class.new(owner: owner, id: 'nested-items', title: 'Nested items') do
      stack do
        collection([1]) do
          collection([1]) { text(key: 'inner', content: 'inner') }
          text content: 'outer'
        end
      end
    end

    expect { page.render }
      .to raise_error(Lich::WebUI::IdentityError, /author key required.*page=nested-items/)
  end

  it 'allows page state accessors from an author render block without deadlocking' do
    page = nil
    page = described_class.new(owner: owner, id: 'stateful', title: 'Stateful') do
      text(content: page.fetch_shared_value('status', :content, 'ready'))
    end

    expect(page.render.tree.children.first.props[:content]).to eq('ready')
  end

  it 'gives positional siblings distinct cids' do
    page = described_class.new(owner: owner, id: 'siblings', title: 'Siblings') do
      stack do
        text content: 'one'
        text content: 'two'
      end
    end

    cids = page.render.tree.each.select { |node| node.type == :text }.map(&:cid)
    expect(cids.uniq.length).to eq(2)
  end

  it 'registers callbacks and submission scopes only on the server render record' do
    callback = proc {}
    page = described_class.new(owner: owner, id: 'login', title: 'Login') do
      password = password_input(key: 'password')
      button(key: 'submit', label: 'Log in', on: { activate: callback }, submit: [password])
    end

    render = page.render
    password = render.tree.each.find { |node| node.type == :password_input }
    button = render.tree.each.find { |node| node.type == :button }

    expect(render.bindings[[button.cid, :activate]]).to equal(callback)
    expect(render.submissions[button.cid]).to eq([password.cid])
    expect(render.to_h.to_s).not_to include('Proc')
    expect(render.to_h.to_s).not_to include('submissions')
  end

  it 'refuses change bindings on inputs declared sensitive' do
    page = described_class.new(owner: owner, id: 'secret', title: 'Secret') do
      text_input(value: '', sensitive: true, on: { change: proc {} })
    end

    expect { page.render }.to raise_error(Lich::WebUI::UnknownEventError, /sensitive.*change/)
  end

  it 'requires accelerators to target a server-registered binding' do
    page = described_class.new(owner: owner, id: 'keys', title: 'Keys') do
      button(key: 'save', label: 'Save')
      accelerators([{ keys: 'ctrl+s', target: 'page:keys/button:save', event: 'activate' }])
    end

    expect { page.render }.to raise_error(Lich::WebUI::SchemaViolationError, /not server-registered/)
  end

  it 'requires focus to target a rendered focusable component' do
    valid = described_class.new(owner: owner, id: 'valid-focus', title: 'Valid') do
      input = text_input(key: 'name', value: '')
      focus(input.cid)
    end
    unknown = described_class.new(owner: owner, id: 'unknown-focus', title: 'Unknown') do
      focus('page:unknown-focus/button:missing')
    end
    non_focusable = described_class.new(owner: owner, id: 'text-focus', title: 'Text') do
      label = text(key: 'label', content: 'Label')
      focus(label.cid)
    end

    expect(valid.render.facilities[:focus]).to end_with('/text_input:name')
    expect { unknown.render }.to raise_error(Lich::WebUI::SchemaViolationError, /unknown or non-focusable/)
    expect { non_focusable.render }.to raise_error(Lich::WebUI::SchemaViolationError, /unknown or non-focusable/)
  end

  it 'validates named slots' do
    page = described_class.new(owner: owner, id: 'split', title: 'Split') do
      split(orientation: :horizontal) do
        text slot: :first, content: 'left'
        text slot: :third, content: 'invalid'
      end
    end

    expect { page.render }.to raise_error(Lich::WebUI::SchemaViolationError, /child slot is unknown/)
  end

  it 'refuses duplicate page ids within one owner only' do
    registry = Lich::WebUI::Registry.new
    page = described_class.new(owner: owner, id: 'same', title: 'One') {}
    another = described_class.new(owner: owner, id: 'same', title: 'Two') {}
    other_owner = described_class.new(owner: Object.new, id: 'same', title: 'Other') {}

    registry.register(page)
    expect { registry.register(another) }.to raise_error(Lich::WebUI::DuplicatePageError)
    expect { registry.register(other_owner) }.not_to raise_error
  end

  it 'accepts only the three locked page lifecycle callbacks' do
    callback = proc {}
    page = described_class.new(owner: owner, id: 'life', title: 'Life', on: { attach: callback }) {}

    expect(page.lifecycle_bindings).to eq(attach: callback)
    expect { described_class.new(owner: owner, id: 'bad', title: 'Bad', on: { click: callback }) {} }
      .to raise_error(Lich::WebUI::UnknownEventError, /lifecycle/)
  end
end
