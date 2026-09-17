# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

# A selection list, which neither `tabs` nor `split` gives an author. `tabs` is
# flat and carries no per-item state; building a rail out of `split` plus
# buttons means hand-rolling the list and losing keyboard navigation and ARIA
# with it. That is the reason this is a primitive.
RSpec.describe 'WebUI contract: navigation and selection primitives' do
  let(:validator) { Lich::WebUI::Validator.new }
  let(:context) { { owner: 'owner', page_id: 'page', cid: 'cid' } }

  def validate(props)
    validator.validate_component!(:nav, props, **context)
  end

  describe 'the schema' do
    it 'carries sections, subtitles, status and badges per item' do
      validated = validate(
        items: [
          { id: 'overview', label: 'Overview', section: 'Setup', status: 'done' },
          { id: 'areas', label: 'Areas', section: 'Setup', detail: '3 selected',
            status: 'current', badge: '2' },
        ], selected: 'areas'
      )

      expect(validated[:items].map { |item| item[:id] }).to eq(%w[overview areas])
      expect(validated[:items].last).to include(detail: '3 selected', badge: '2', status: 'current')
      expect(validated[:selected]).to eq('areas')
    end

    it 'defaults an item with no status to none' do
      validated = validate(items: [{ id: 'plain', label: 'Plain' }])

      expect(validated[:items].first[:status]).to eq('none')
    end

    it 'requires every item to have an identifier and a label' do
      expect { validate(items: [{ id: 'x' }]) }.to raise_error(Lich::WebUI::SchemaViolationError)
      expect { validate(items: [{ label: 'X' }]) }.to raise_error(Lich::WebUI::SchemaViolationError)
    end

    it 'refuses a status outside the vocabulary' do
      expect { validate(items: [{ id: 'x', label: 'X', status: 'nonsense' }]) }
        .to raise_error(Lich::WebUI::SchemaViolationError)
    end

    it 'requires items' do
      expect { validate(selected: 'x') }.to raise_error(Lich::WebUI::SchemaViolationError)
    end

    # Selection is per viewer: two browsers looking at one page navigate
    # independently, as they do for tabs and table selection.
    it 'scopes the selection to the viewer' do
      schema = Lich::WebUI::Contract.schema(:nav)

      expect(schema[:properties][:selected][:scope]).to eq(:viewer)
      expect(schema[:value_scope]).to eq(:viewer)
    end

    it 'emits the identifier that was chosen' do
      expect(Lich::WebUI::Contract.schema(:nav)[:events].keys).to eq([:select])
    end
  end

  describe 'rendering' do
    it 'reaches the tree with its items intact' do
      service = Lich::WebUI::Service.new
      page = service.registry.register(
        Lich::WebUI::Page.new(owner: Object.new, id: 'rail', title: 'Rail') do
          nav(key: 'sidebar', selected: 'areas', items: [
                { id: 'overview', label: 'Overview', section: 'Setup', status: 'done' },
                { id: 'areas', label: 'Areas', section: 'Setup', status: 'current', badge: '2' },
                { id: 'review', label: 'Review', section: 'Finish', status: 'blocked', disabled: true },
              ])
        end
      )
      page.bind_runtime(service.runtime)
      component = page.render.tree.each.find { |candidate| candidate.type == :nav }

      expect(component.props[:selected]).to eq('areas')
      expect(component.props[:items].map { |item| item[:section] }).to eq(%w[Setup Setup Finish])
      expect(component.props[:items].last[:disabled]).to be(true)
    ensure
      service&.stop
    end
  end

  describe 'the client' do
    let(:javascript) { File.read(File.join(Lich::WebUI::Service::ASSETS_DIR, 'app.js')) }

    # The platform gives these for free to a listbox; a stack of buttons does
    # not, and every script would otherwise reimplement them.
    it 'renders a listbox with keyboard navigation and active descendant' do
      expect(javascript).to include('list.setAttribute("role", "listbox")')
      expect(javascript).to include('option.setAttribute("role", "option")')
      expect(javascript).to include('aria-activedescendant')
      %w[ArrowDown ArrowUp Home End].each do |key|
        expect(javascript).to include(%(event.key === "#{key}"))
      end
    end

    it 'does not emit a selection for a disabled item or a disabled nav' do
      expect(javascript).to include('if (item.disabled !== true && component.props.disabled !== true)')
      expect(javascript).to include('if (component.props.disabled === true || !selectable.length) return;')
    end

    it 'shows status as a marker rather than as text a reader would announce' do
      css = File.read(File.join(Lich::WebUI::Service::ASSETS_DIR, 'app.css'))

      expect(css).to include('.nav-item[data-status="done"] > .nav-item-marker::before')
      expect(css).to include('.nav-item[data-status="current"] > .nav-item-marker::before')
      expect(css).to include('.nav-item[data-status="blocked"] > .nav-item-marker::before')
    end
  end

  # A card is a group the viewer can choose. A new node type would duplicate
  # everything a group already does -- label, border, children, collapsible --
  # to add one piece of state, so the state lives on group instead.
  describe 'a selectable group' do
    def validate_group(props)
      Lich::WebUI::Validator.new.validate_component!(
        :group, props, owner: 'owner', page_id: 'page', cid: 'cid'
      )
    end

    it 'carries a viewer-scoped selected state' do
      validated = validate_group(label: 'Icemule', selectable: true, selected: true)

      expect(validated).to include(selectable: true, selected: true)
      expect(Lich::WebUI::Contract.schema(:group)[:properties][:selected][:scope]).to eq(:viewer)
    end

    it 'defaults to an ordinary group' do
      validated = validate_group(label: 'Plain')

      expect(validated[:selectable]).to be(false)
      expect(validated[:selected]).to be(false)
    end

    it 'reports which way it was toggled' do
      expect(Lich::WebUI::Contract.schema(:group)[:events]).to have_key(:select)
    end

    it 'is a control in the client, not just a border' do
      javascript = File.read(File.join(Lich::WebUI::Service::ASSETS_DIR, 'app.js'))

      expect(javascript).to include('group.setAttribute("role", "button")')
      expect(javascript).to include('group.setAttribute("aria-pressed", String(selected))')
      expect(javascript).to include('emit(page, component, "select", { selected: !selected })')
    end
  end

  # A heading should not need a markup span wrapped round it to be one size
  # larger. The vocabulary is Pango's, which the markup path already accepts,
  # so `size:` and a markup span render identically.
  describe 'text size' do
    it 'accepts the type scale and refuses a relative nudge' do
      validator = Lich::WebUI::Validator.new
      context = { owner: 'owner', page_id: 'page', cid: 'cid' }

      expect(validator.validate_component!(:text, { content: 'Heading', size: 'x-large' }, **context))
        .to include(size: 'x-large')
      # `smaller` and `larger` depend on context, which a first-class property
      # should not.
      expect { validator.validate_component!(:text, { content: 'x', size: 'larger' }, **context) }
        .to raise_error(Lich::WebUI::SchemaViolationError)
    end

    it 'sets a font size rather than wrapping the content' do
      javascript = File.read(File.join(Lich::WebUI::Service::ASSETS_DIR, 'app.js'))

      expect(javascript).to include('text.style.fontSize = component.props.size')
    end
  end
end
