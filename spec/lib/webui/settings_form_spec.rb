# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require 'webui/settings_form'

RSpec.describe Lich::WebUI::SettingsForm do
  let(:owner) { Object.new }
  let(:service) { Lich::WebUI::Service.new }
  let(:values) { { echo: true, bag: 'backpack', limit: 4, unrelated: ['preserved'] } }
  let(:fields) do
    [
      { key: :echo, type: :checkbox, label: 'Echo commands', group: 'General' },
      { key: :bag, type: :text_input, label: 'Bag', group: 'General' },
      { key: :limit, type: :number_input, label: 'Limit', group: 'Limits', min: 0, max: 10 },
    ]
  end
  let(:form) { described_class.new(owner: owner, id: 'setup', title: 'Fixture setup', values: values, fields: fields) }

  before do
    allow(Lich::WebUI).to receive(:service).and_return(service)
    allow(Lich::WebUI).to receive(:registry).and_return(service.registry)
    allow(Lich::WebUI).to receive(:start)
    allow(Lich::WebUI).to receive(:open).and_return(true)
  end

  after do
    form.close
    service.stop
  end

  it 'cancels without waiting when the host cannot open its window' do
    allow(Lich::WebUI).to receive(:open).and_return(false)
    form.show
    expect(form.instance_variable_get(:@completion)).to be_resolved
    expect(form.wait).to be_nil
    expect(service.registry.pages_for(owner)).to be_empty
  end

  it 'inherits the stored dark preference instead of forcing light' do
    allow(Lich).to receive(:track_dark_mode).and_return(true)
    form.show
    expect(form.page.last_render.tree.props[:theme]).to eq('dark')
  end

  def invoke(label, submitted = [])
    render = form.page.last_render
    button = render.tree.each.find { |node| node.props[:label] == label }
    scope = render.submissions.fetch(button.cid, [])
    submission = Lich::WebUI::Submission.new(viewer_id: 'fixture', values: scope.zip(submitted).to_h)
    render.bindings.fetch([button.cid, :activate]).call(Struct.new(:submission).new(submission))
  end

  it 'returns only an explicit Save snapshot and preserves settings outside the form' do
    form.show
    invoke('Save & Close', [false, 'satchel', 7])
    result = form.wait
    expect(result).to eq(echo: false, bag: 'satchel', limit: 7, unrelated: ['preserved'])
    expect(values[:bag]).to eq('backpack')
    result[:unrelated] << 'new'
    expect(values[:unrelated]).to eq(['preserved'])
    expect(service.registry.pages_for(owner)).to be_empty
  end

  it 'discards unsubmitted changes on Cancel or host close' do
    form.show
    invoke('Cancel')
    expect(form.wait).to be_nil
    expect(values[:bag]).to eq('backpack')
  end

  it 'treats the host close event as cancellation' do
    form.show
    form.page.lifecycle_bindings.fetch(:close).call(nil)
    expect(form.wait).to be_nil
  end

  it 'displays a known-choice reference without accepting it as submitted input' do
    fields << { key: :reference, type: :text, content: '101 Spirit Warding I' }
    form.show
    expect(form.page.last_render.tree.each.any? { |node| node.props[:content] == '101 Spirit Warding I' }).to be(true)
    invoke('Save & Close', [true, 'satchel', 4])
    expect(form.wait).not_to have_key(:reference)
  end

  it 'retains an unselected combo without inventing a selectable blank choice' do
    fields << { key: :guild, type: :select, label: 'Guild', options: [{ value: 'Landing', label: 'Landing' }] }
    values[:guild] = nil
    form.show
    select = form.page.last_render.tree.each.find { |node| node.type == :select }
    expect(select.props).not_to have_key(:value)
    validator = Lich::WebUI::Validator.new
    context = { props: select.props, owner: 'fixture', page_id: 'setup', cid: select.cid }
    expect(validator.validate_input_value!(:select, '', **context)).to eq('')
    expect { validator.validate_input_value!(:select, 'invented', **context) }.to raise_error(Lich::WebUI::SchemaViolationError)
    invoke('Save & Close', [true, 'bag', 4, ''])
    expect(form.wait[:guild]).to eq('')
  end

  it 'keeps invalid domain values editable and allows a corrected submission' do
    checked = described_class.new(owner: owner, id: 'checked', title: 'Checked', values: values, fields: fields,
                                  normalize: proc { |draft| raise ArgumentError, 'Bag is required' if draft[:bag].empty?; draft })
    allow(self).to receive(:form).and_return(checked)
    form.show
    invoke('Save & Close', [true, '', 4])
    expect(form.page.last_render.tree.each.any? { |node| node.props[:content] == 'Bag is required' }).to be(true)
    invoke('Save & Close', [true, 'sack', 4])
    expect(form.wait[:bag]).to eq('sack')
  end

  it 'submits fields across optional tabs and binds viewer-local tab selection' do
    tabbed = described_class.new(owner: owner, id: 'tabs', title: 'Tabbed', values: values, fields: fields, tabbed: true)
    allow(self).to receive(:form).and_return(tabbed)
    form.show
    render = form.page.last_render
    tabs = render.tree.each.find { |node| node.type == :tabs }
    expect(tabs.props[:names]).to eq(%w[General Limits])
    expect(render.bindings).to have_key([tabs.cid, :select])
    invoke('Save & Close', [false, 'case', 9])
    expect(form.wait).to include(echo: false, bag: 'case', limit: 9)
  end

  it 'uses a script layout and original Close action without adding a second set of controls' do
    layout = proc do |tree, field, save|
      tree.grid(cols: 2) do
        field.call(self, :bag, label: nil)
        field.call(self, :echo)
      end
      field.call(tree, :limit)
      save.call(tree, label: 'Close')
    end
    original = described_class.new(owner: owner, id: 'original', title: 'Original', values: values,
                                   fields: fields, layout: layout, props: { size: [650, 425] })
    allow(self).to receive(:form).and_return(original)
    form.show
    expect(form.page.last_render.tree.props).to include(bare: true, theme: 'light', density: 'compact', size: [650, 425])
    expect(form.page.last_render.tree.each.select { |node| node.type == :button }.map { |node| node.props[:label] }).to eq(['Close'])
    invoke('Close', ['satchel', false, 7])
    expect(form.wait).to include(bag: 'satchel', echo: false, limit: 7)
  end
end
