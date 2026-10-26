# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

RSpec.describe 'native setup presentation helpers' do
  it 'preserves blanks, duplicates, ordering and authored choice values' do
    choices = ['Z', '', ' same ', 'Z'].freeze
    expect(Lich::WebUI::SettingsForm.choice_options(choices)).to eq(
      choices.map { |value| { value: value, label: value } }
    )
  end

  it 'reads current list values lazily and passes mutation callbacks through unchanged' do
    items = ['Z', '', ' same ', 'Z']
    add = proc { |text| items << text }
    delete = proc { |index| items.delete_at(index) }
    value = proc { items }
    spec = Lich::WebUI::ListSettingsForm.text_list_spec(value: value, add: add, delete: delete)
    expect(spec.values_at(:value, :add, :delete)).to eq([value, add, delete])
    expect(spec[:rows].call).to eq(items.map { |text| { 'text' => text } })
    items = [' replacement ']
    expect(spec[:rows].call).to eq([{ 'text' => ' replacement ' }])
    spec[:add].call(' second ')
    spec[:delete].call(0)
    expect(items).to eq([' second '])
    expect(spec[:clear_after_add]).to be(false)
  end

  it 'does not repair an original list callback failure or swallow its partial mutation' do
    items = ['existing']
    spec = Lich::WebUI::ListSettingsForm.text_list_spec(
      value: proc { items }, delete: proc {},
      add: proc { |text| items.push(text); items.uniq!.sort! }, clear_after_add: true
    )
    expect { spec[:add].call('new') }.to raise_error(NoMethodError)
    expect(items).to eq(%w[existing new])
    expect(spec[:clear_after_add]).to be(true)
  end

  it 'composes the original footer tree and submission callback with caller-specific spacing' do
    [10, 5, 15].each do |margin|
      callback = proc { |event| event }
      build = proc do |helper|
        tree = Lich::WebUI::TreeBuilder.new(owner: self, page_id: 'footer', title: 'Footer')
        entry = tree.text_input(key: 'value', value: ' untouched ')
        action = proc { |parent, **props| parent.button(**props, submit: [entry], on: { activate: callback }) }
        notice_props = { margin: { left: margin }, wrap: true }
        action_props = { min_width: 80, margin: { right: margin } }
        if helper
          tree.setup_footer(notice: 'Exact notice.', action: action, notice_props: notice_props, action_props: action_props)
        else
          tree.columns(count: 2, compact: true, weights: [5, 1], gap: 0) do
            text(font_style: :italic, content: 'Exact notice.', slot: '0', **notice_props)
            action.call(self, label: 'Close', slot: '1', align: :end, **action_props)
          end
        end
        [tree.build.to_h, tree.bindings, tree.submissions]
      end
      expect(build.call(true)).to eq(build.call(false))
    end
  end
end
