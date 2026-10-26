# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require 'timeout'

RSpec.describe Lich::WebUI::Adapter do
  let(:owner) { Object.new }
  let(:service) { Lich::WebUI::Service.new }
  let(:adapter) { described_class.new(owner: owner, service: service, viewer: 'viewer-one') }

  after { service.stop }

  def drain_publication
    barrier = Queue.new
    service.runtime.dispatch(owner: owner) { barrier << true }
    expect(barrier.pop(timeout: 3)).to be(true)
  end

  it 'presents only a live owned page after publishing its latest state' do
    allow(service.runtime).to receive(:schedule_render)
    presented = []
    port = described_class.new(owner: owner, service: service, on_publish: ->(page) { presented << page.last_render })
    root = port.create(:page, title: 'Retained')
    child = port.create(:text, content: 'Before')
    port.attach(root, child)
    port.send(:flush!)
    expect(presented.size).to eq(1)
    expect { port.present(child) }.to raise_error(Lich::WebUI::Error, /page root/)
    expect { adapter.present(root) }.to raise_error(Lich::WebUI::Error, /unknown handle/)

    port.set(child, :content, 'After')
    2.times { port.present(root) }
    expect(presented.size).to eq(1)
    port.send(:flush!)
    expect(presented.size).to eq(2)
    expect(presented.last.tree.children.first.props[:content]).to eq('After')
    expect(service.registry.pages_for(owner).size).to eq(1)

    port.present(root)
    port.set(root, :presentation, { hidden: true })
    port.send(:flush!)
    expect(presented.size).to eq(2)
    port.present(root)
    port.destroy(root)
    port.send(:flush!)
    expect(presented.size).to eq(2)
    expect { port.present(root) }.to raise_error(Lich::WebUI::Error, /destroyed/)
  end

  it 'allows an explicit retry after its host opener fails without replacing the page' do
    allow(service.runtime).to receive(:schedule_render)
    attempts = []
    port = described_class.new(owner: owner, service: service, on_publish: lambda do |page|
      attempts << page
      raise 'launch failed' if attempts.size == 2
    end)
    root = port.create(:page, title: 'Retry')
    port.send(:flush!)
    port.present(root)
    expect { port.send(:flush!) }.to raise_error('launch failed')
    port.present(root)
    port.send(:flush!)
    expect(attempts.size).to eq(3)
    expect(attempts.uniq.size).to eq(1)
  end

  it 'limits Button content to one plain text child without attaching refused children' do
    button = adapter.create(:button, label: '')
    text = adapter.create(:text, content: 'Die')
    other = adapter.create(:text, content: 'Other')
    input = adapter.create(:text_input, value: '')
    expect { adapter.attach(button, input) }.to raise_error(Lich::WebUI::Error, /child type/)
    adapter.attach(button, text)
    expect { adapter.attach(button, other) }.to raise_error(Lich::WebUI::Error, /too many children/)
    adapter.detach(button, text)
    adapter.attach(button, other)
    adapter.attach(adapter.create(:stack, {}), input)
  end

  it 'replaces tab collections atomically and preserves old structure after rejected children or headers' do
    tabs = adapter.create(:tabs, names: [])
    one = adapter.create(:text, content: 'One')
    two = adapter.create(:text, content: 'Two')
    adapter.layout_tabs(tabs, children: [one], names: ['One'], headers: [{ key: 'one' }])
    foreign_parent = adapter.create(:stack, {})
    adapter.attach(foreign_parent, two)
    expect { adapter.layout_tabs(tabs, children: [two], names: ['Two'], headers: [{ key: 'two' }]) }.to raise_error(Lich::WebUI::Error)
    expect { adapter.layout_tabs(tabs, children: [one], names: ['One'], headers: []) }.to raise_error(Lich::WebUI::Error)
    expect(adapter.get(tabs, :names)).to eq(['One'])
    adapter.layout_tabs(tabs, children: [], names: [], headers: [])
    adapter.attach(foreign_parent, one)
    expect(adapter.get(one, :content)).to eq('One')
  end

  it 'remaps pending viewer tab writes when a second structural change precedes delivery' do
    allow(service.runtime).to receive(:schedule_render)
    tabs = adapter.create(:tabs, names: [])
    one, two, three = %w[One Two Three].map { |name| adapter.create(:text, content: name) }
    adapter.layout_tabs(tabs, children: [one, two, three], names: %w[One Two Three], headers: %w[one two three].map { |key| { key: key } })
    adapter.set(tabs, :selected, 2)
    adapter.layout_tabs(tabs, children: [two, three], names: %w[Two Three], headers: %w[two three].map { |key| { key: key } })
    expect(adapter.get(tabs, :selected)).to eq(1)
    adapter.layout_tabs(tabs, children: [two], names: ['Two'], headers: [{ key: 'two' }])
    expect(adapter.get(tabs, :selected)).to eq(0)
  end

  it 'retains implicit native callback viewer writes while unrelated tab metadata is dirty' do
    unscoped = described_class.new(owner: owner, service: service)
    allow(service.runtime).to receive(:schedule_render)
    root = unscoped.create(:page, title: 'Native tabs')
    tabs = unscoped.create(:tabs, names: %w[One Two], selected: 1)
    %w[One Two].each { |name| unscoped.attach(tabs, unscoped.create(:text, content: name)) }
    unscoped.attach(root, tabs)
    observed = Queue.new
    unscoped.bind(tabs, :select, proc do |_event|
      unscoped.set(tabs, :show_tabs, true)
      unscoped.set(tabs, :selected, 1)
      observed << unscoped.get(tabs, :selected)
    end)
    unscoped.send(:flush!)
    page = service.registry.pages_for(owner).first
    messages = []
    connection = double('connection', viewer_id: 'native-tabs', alive?: true)
    allow(connection).to receive(:send_text) { |json| messages << JSON.parse(json) }
    address = service.registry.address_for(page)
    service.runtime.handle(connection, type: 'attach', page: address)
    render = messages.last
    service.runtime.handle(connection, type: 'event', page: address, generation: render['generation'],
                                       cid: render.dig('tree', 'children', 0, 'cid'), event: 'select', payload: { index: 0 })
    expect(observed.pop(timeout: 2)).to eq(1)
  end

  it 'stages current select choices until options publish and reconciles consecutive rebuilds per viewer' do
    allow(service.runtime).to receive(:schedule_render)
    identity = Struct.new(:viewer_id).new(nil)
    port = described_class.new(owner: owner, service: service, viewer: identity)
    root = port.create(:page, title: 'Rebuild choices')
    select = port.create(:select, options: [{ value: 'none', label: '' }, { value: 'old', label: 'Old' }], value: 'old', empty_value: 'none')
    port.attach(root, select)
    port.send(:flush!)
    page = service.registry.pages_for(owner).first
    viewers = %w[first second].map do |id|
      connection = double(id, viewer_id: id, alive?: true, send_text: true)
      service.runtime.handle(connection, type: 'attach', page: service.registry.address_for(page))
      service.runtime.instance_variable_get(:@viewers).fetch(connection_id: id, address: service.registry.address_for(page)).viewer_id
    end
    identity.viewer_id = viewers.first
    port.set(select, :options, [{ value: 'none', label: '' }, { value: 'new', label: 'Duplicate' }, { value: 'other', label: 'Duplicate' }])
    port.set(select, :value, 'other')
    port.set(select, :value, 'new')
    expect { port.set(select, :value, 'invented') }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect(port.get(select, :value)).to eq('new')
    identity.viewer_id = viewers.last
    port.set(select, :value, 'other')
    port.send(:flush!)
    expect(port.get(select, :value)).to eq('other')
    identity.viewer_id = viewers.first
    expect(port.get(select, :value)).to eq('new')
    port.set(select, :options, [{ value: 'none', label: '' }, { value: 'next', label: 'Next' }])
    port.set(select, :value, 'next')
    expect { port.set(select, :options, [{ value: 'bad', label: 'x' * 513 }]) }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect(port.get(select, :value)).to eq('next')
    port.set(select, :options, [{ value: 'none', label: '' }])
    expect(port.get(select, :value)).to eq('none')
    port.send(:flush!)
    expect(port.get(select, :value)).to eq('none')
    identity.viewer_id = viewers.last
    expect(port.get(select, :value)).to eq('none')
  end

  it 'preserves pending editable free text and its existing bounds through option replacement' do
    allow(service.runtime).to receive(:schedule_render)
    identity = Struct.new(:viewer_id).new(nil)
    port = described_class.new(owner: owner, service: service, viewer: identity)
    root = port.create(:page, title: 'Editable choices')
    select = port.create(:select, editable: true, free_text_prefix: 'text:', options: [{ value: 'none', label: '' }], value: 'none', empty_value: 'none')
    port.attach(root, select)
    port.send(:flush!)
    page = service.registry.pages_for(owner).first
    connection = double('editor', viewer_id: 'editor', alive?: true, send_text: true)
    service.runtime.handle(connection, type: 'attach', page: service.registry.address_for(page))
    identity.viewer_id = service.runtime.instance_variable_get(:@viewers).fetch(connection_id: 'editor', address: service.registry.address_for(page)).viewer_id
    port.set(select, :options, [{ value: 'none', label: '' }, { value: 'new', label: 'New' }])
    port.set(select, :value, 'text:literal')
    port.set(select, :options, [{ value: 'none', label: '' }])
    expect(port.get(select, :value)).to eq('text:literal')
    expect { port.set(select, :value, 'x' * 8193) }.to raise_error(Lich::WebUI::SchemaViolationError)
    port.send(:flush!)
    expect(port.get(select, :value)).to eq('text:literal')
  end

  it 'exposes the approved adapter operations' do
    expect(described_class.public_instance_methods(false)).to contain_exactly(
      :create, :get, :set, :attach, :detach, :bind, :unbind, :destroy, :modal, :schema, :layout_grid, :layout_tabs, :layout_tab_actions, :replace_child, :set_overlay_pass_through, :monitor_geometry, :focus, :place, :present
    )
  end

  it 'rejects foreign focus and invalid positioned movement without replacing valid state' do
    allow(service.runtime).to receive(:schedule_render)
    root = adapter.create(:page, title: 'Positioned')
    fixed = adapter.create(:overlay, positioned: true)
    entry = adapter.create(:text_input, value: 'Retained', placement: { x: 10, y: 20 })
    adapter.attach(root, fixed)
    adapter.attach(fixed, entry)
    adapter.focus(root, entry)
    adapter.send(:flush!)
    page = service.registry.pages_for(owner).first
    revision = page.last_render.facilities[:focus_revision]
    expect(page.last_render.facilities[:focus]).to eq(page.last_render.tree.children.first.children.first.cid)
    expect { adapter.place(fixed, entry, x: 65_537, y: 0) }.to raise_error(Lich::WebUI::Error)
    expect { adapter.set(fixed, :positioned, false) }.to raise_error(Lich::WebUI::Error, /coordinates/)
    adapter.place(fixed, entry, x: -5, y: 30)
    adapter.send(:flush!)
    expect(page.last_render.tree.children.first.children.first.placement).to eq(x: -5, y: 30)
    expect(page.last_render.facilities[:focus_revision]).to eq(revision)
    detached = adapter.create(:text_input, value: 'Detached')
    expect { adapter.focus(root, detached) }.to raise_error(Lich::WebUI::Error, /descendant/)
    another = Lich::WebUI::Adapter.new(owner: Object.new, service: service)
    foreign = another.create(:text_input, value: 'Foreign')
    expect { adapter.focus(root, foreign) }.to raise_error(Lich::WebUI::Error)
    adapter.destroy(entry)
    adapter.send(:flush!)
    expect(page.last_render.facilities).not_to have_key(:focus)
  end

  it 'validates live overlay hit testing, preserves identity and rolls back failed publication' do
    allow(service.runtime).to receive(:schedule_render)
    root = adapter.create(:page, title: 'Overlay')
    layers = adapter.create(:overlay, {})
    input = adapter.create(:text_input, value: 'Retained', placement: { z: 2 })
    binding = adapter.bind(input, :change, proc {})
    adapter.attach(root, layers)
    adapter.attach(layers, input)
    adapter.send(:flush!)
    nodes = adapter.instance_variable_get(:@nodes)
    adapter.set_overlay_pass_through(layers, input, true)
    expect(nodes.fetch(input).placement).to eq(z: 2, pass_through: true)
    expect(nodes.fetch(input).props[:value]).to eq('Retained')
    expect(nodes.fetch(input).bindings.values).to include(binding)
    expect { adapter.set_overlay_pass_through(layers, input, 'true') }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect { adapter.set_overlay_pass_through(root, input, false) }.to raise_error(Lich::WebUI::Error, /attached overlay child/)
    adapter.instance_variable_set(:@publication_pending, false)
    allow(service.runtime).to receive(:schedule_render).and_raise(Lich::WebUI::Error, 'owner stopped')
    expect { adapter.set_overlay_pass_through(layers, input, false) }.to raise_error(Lich::WebUI::Error, 'owner stopped')
    expect(nodes.fetch(input).placement).to eq(z: 2, pass_through: true)
    allow(service.runtime).to receive(:schedule_render)
    adapter.detach(layers, input)
    expect(nodes.fetch(input).placement).to eq(z: 2)
    expect { adapter.set_overlay_pass_through(layers, input, false) }.to raise_error(Lich::WebUI::Error, /attached overlay child/)
  end

  it 'accepts progress pointer events only when enabled and rejects unrelated event families' do
    validator = Lich::WebUI::Validator.new
    payload = { x: 12, y: 16, button: 3, time: 1, state: 0 }
    context = { owner: 'fixture', page_id: 'page', cid: 'bar' }
    expect(validator.validate_event!(:progress, :pointer_press, payload, props: { value: 0.5, pointer_events: true }, **context)).to eq(payload)
    expect { validator.validate_event!(:progress, :pointer_press, payload, props: { value: 0.5 }, **context) }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect { adapter.bind(adapter.create(:progress, value: 0.5), :scroll, proc {}) }.to raise_error(Lich::WebUI::UnknownEventError)
  end

  it 'preserves separate viewer drafts through overlay hit-testing changes' do
    allow(service.runtime).to receive(:schedule_render)
    identity = Struct.new(:viewer_id).new(nil)
    port = described_class.new(owner: owner, service: service, viewer: identity)
    root = port.create(:page, title: 'Layer inputs')
    layers = port.create(:overlay, {})
    input = port.create(:text_input, value: 'Initial')
    port.attach(root, layers)
    port.attach(layers, input)
    port.send(:flush!)
    page = service.registry.pages_for(owner).first
    viewers = %w[first second].map do |id|
      connection = double(id, viewer_id: id, alive?: true, send_text: true)
      service.runtime.handle(connection, type: 'attach', page: service.registry.address_for(page))
      service.runtime.instance_variable_get(:@viewers).fetch(connection_id: id, address: service.registry.address_for(page)).viewer_id
    end
    identity.viewer_id = viewers.first
    port.set(input, :value, 'Private draft')
    port.set_overlay_pass_through(layers, input, true)
    port.send(:flush!)
    expect(port.get(input, :value)).to eq('Private draft')
    identity.viewer_id = viewers.last
    expect(port.get(input, :value)).to eq('Initial')
    port.set_overlay_pass_through(layers, input, false)
    port.send(:flush!)
    expect(port.get(input, :value)).to eq('Initial')
  end

  it 'creates opaque handles and returns the frozen contract schema' do
    handle = adapter.create(:button, label: 'Go')

    expect(handle.inspect).to eq('#<Lich::WebUI::Adapter::Handle opaque>')
    expect(handle).not_to respond_to(:type, :props, :cid)
    expect(adapter.schema(:button)).to be_frozen
    expect { adapter.schema(:invented) }.to raise_error(Lich::WebUI::UnknownTypeError, /owner=/)
  end

  it 'carries validated child placement through the existing create and attach operations' do
    grid = adapter.create(:grid, cols: 3)
    child = adapter.create(:text, content: 'Spanning cell', placement: { span: 2 })
    expect(adapter.attach(grid, child)).to be_nil
    invalid = adapter.create(:text, content: 'Too wide', placement: { span: 4 })
    expect { adapter.attach(grid, invalid) }.to raise_error(Lich::WebUI::Error, /placement/)
    overflow = adapter.create(:text, content: 'Offset overflow', placement: { column: 3, span: 2 })
    expect { adapter.attach(grid, overflow) }.to raise_error(Lich::WebUI::Error, /placement/)
    # The refused attach is atomic; the child can still join a wider grid.
    expect(adapter.attach(adapter.create(:grid, cols: 4), invalid)).to be_nil
  end

  %i[grid tabs].each do |type|
    it "rolls back #{type} attachment when render scheduling fails, preserving slots and retry" do
      allow(service.runtime).to receive(:schedule_render)
      root = adapter.create(:page, title: 'Transactional attachment')
      parent = adapter.create(type, type == :grid ? { cols: 1 } : { names: %w[First Second Third] })
      first = adapter.create(:text, content: 'First')
      last = adapter.create(:text, content: 'Last')
      candidate = adapter.create(:text_input, value: 'Retained draft')
      binding = adapter.bind(candidate, :change, proc {})
      adapter.attach(root, parent)
      adapter.attach(parent, first)
      adapter.attach(parent, last)
      adapter.send(:flush!)
      nodes = adapter.instance_variable_get(:@nodes)
      slots = [first, last].map { |handle| nodes.fetch(handle).slot }
      error = Lich::WebUI::Error.new('render owner is terminated')
      # The setup scheduler is inert; expose the next real scheduling attempt.
      adapter.instance_variable_set(:@publication_pending, false)
      allow(service.runtime).to receive(:schedule_render).and_raise(error)

      expect { adapter.attach(parent, candidate, 1) }.to(raise_error { |raised| expect(raised).to equal(error) })
      expect(nodes.fetch(parent).children).to eq([first, last])
      expect(nodes.fetch(candidate).parent).to be_nil
      expect(nodes.fetch(candidate).slot).to be_nil
      expect([first, last].map { |handle| nodes.fetch(handle).slot }).to eq(slots)
      expect(nodes.fetch(candidate).bindings.values).to include(binding)
      expect(adapter.get(candidate, :value)).to eq('Retained draft')
      expect(adapter.instance_variable_get(:@publication_pending)).to be(false)

      allow(service.runtime).to receive(:schedule_render).and_call_original
      expect(adapter.attach(parent, candidate, 1)).to be_nil
      page = service.registry.pages_for(owner).first
      Timeout.timeout(3) do
        sleep 0.005 until page.last_render.tree.children.first.children.length == 3
      end
      expect(nodes.fetch(parent).children).to eq([first, candidate, last])
      expect(nodes.fetch(candidate).parent).to equal(parent)
      expect(page.last_render.tree.children.first.children[1].props[:value]).to eq('Retained draft')
      expect([first, candidate, last].map { |handle| nodes.fetch(handle).slot }).to eq(%w[First Second Third]) if type == :tabs
    end
  end

  it 'gets and sets validated server-held state with explicit viewer scope' do
    input = adapter.create(:text_input, value: 'before')
    button = adapter.create(:button, label: 'Before')

    expect(adapter.get(input, :value)).to eq('before')
    expect(adapter.set(input, :value, 'after')).to be_nil
    expect(adapter.set(button, :label, 'After')).to be_nil
    expect(adapter.get(input, :value)).to eq('after')
    expect(adapter.get(button, :label)).to eq('After')

    unscoped = described_class.new(owner: owner, service: service)
    unscoped_input = unscoped.create(:text_input, value: '')
    expect { unscoped.get(unscoped_input, :value) }.to raise_error(Lich::WebUI::AmbiguousViewerError)
    expect { adapter.set(button, :invented, true) }.to raise_error(Lich::WebUI::UnknownPropertyError, /opaque-/)
  end

  %i[get set].each do |operation|
    it "releases the adapter monitor before viewer #{operation} enters page rendering" do
      allow(service.runtime).to receive(:schedule_render)
      root = adapter.create(:page, title: 'Form')
      input = adapter.create(:text_input, value: 'before')
      adapter.attach(root, input)
      adapter.send(:flush!)
      page = service.registry.pages_for(owner).first
      allow(page).to receive(operation) do |*_args, **_options|
        worker = Thread.new { adapter.get(root, :title) }
        expect(worker.join(1)).to equal(worker)
        'after'
      ensure
        worker&.kill
      end
      operation == :get ? adapter.get(input, :value) : adapter.set(input, :value, 'after')
    end
  end

  it 'refuses shrinking a grid past an existing cell without corrupting its layout' do
    grid = adapter.create(:grid, cols: 4)
    child = adapter.create(:text, content: 'Fourth column', placement: { column: 4 })
    adapter.attach(grid, child)
    expect { adapter.set(grid, :cols, 3) }.to raise_error(Lich::WebUI::Error, /placement/)
    expect(adapter.get(grid, :cols)).to eq(4)
  end

  it 'unsets optional shared properties and reapplies schema defaults without changing handles' do
    bar = adapter.create(:progress, value: 0.5, height: 24, fill_color: { r: 0, g: 0, b: 255, a: 1.0 })
    %i[height fill_color].each do |property|
      expect(adapter.set(bar, property, described_class::UNSET)).to be_nil
      expect(adapter.get(bar, property)).to be_nil
    end
    expect(adapter.get(bar, :value)).to eq(0.5)
    text = adapter.create(:text, content: 'Wrapping', wrap: false)
    adapter.set(text, :wrap, described_class::UNSET)
    expect(adapter.get(text, :wrap)).to be true
  end

  it 'restores absent opacity after explicit overrides without changing component identity' do
    { stack: {}, button: { label: 'Action' }, text: { content: 'Subtle', emphasis: :subtle } }.each do |type, props|
      handle = adapter.create(type, props)
      expect(adapter.get(handle, :opacity)).to be_nil
      [0, 0.35, 1].each do |alpha|
        adapter.set(handle, :opacity, alpha)
        expect(adapter.get(handle, :opacity)).to eq(alpha)
        adapter.set(handle, :opacity, described_class::UNSET)
        expect(adapter.get(handle, :opacity)).to be_nil
      end
      expect(adapter.get(handle, :emphasis)).to eq('subtle') if type == :text
    end
  end

  it 'refuses unsetting required, viewer, sensitive and unknown properties' do
    targets = [[:text, { content: 'Retained' }, :content], [:text_input, { value: 'Retained' }, :value],
               [:password_input, {}, :value]]
    targets.each do |type, props, property|
      handle = adapter.create(type, props)
      expect { adapter.set(handle, property, described_class::UNSET) }.to raise_error(Lich::WebUI::SchemaViolationError)
    end
    bar = adapter.create(:progress, value: 0, height: 24)
    expect { adapter.set(bar, :invented, described_class::UNSET) }.to raise_error(Lich::WebUI::UnknownPropertyError)
    expect { adapter.set(bar, :height, nil) }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect(adapter.get(bar, :height)).to eq(24)
  end

  it 'revalidates component invariants before unsetting an optional shared property' do
    bar = adapter.create(:progress, value: 0.5)
    expect { adapter.set(bar, :value, described_class::UNSET) }.to raise_error(Lich::WebUI::SchemaViolationError, /value is required/)
    expect(adapter.get(bar, :value)).to eq(0.5)
  end

  it 'publishes reset presentation as absent properties with the same component identity' do
    allow(service.runtime).to receive(:schedule_render)
    root = adapter.create(:page, title: 'Progress')
    bar = adapter.create(:progress, value: 0.5, height: 24, fill_color: { r: 0, g: 0, b: 255, a: 1.0 })
    adapter.attach(root, bar)
    adapter.send(:flush!)
    page = service.registry.pages_for(owner).first
    before = page.last_render.tree.children.first
    %i[height fill_color].each { |property| adapter.set(bar, property, described_class::UNSET) }
    adapter.send(:flush!)
    after = page.last_render.tree.children.first
    expect(after.cid).to eq(before.cid)
    expect(after.props).to include(value: 0.5)
    expect(after.props).not_to have_key(:height)
    expect(after.props).not_to have_key(:fill_color)
  end

  it 'bounds tall grid spans by their ending row and preserves live placement on refusal' do
    allow(service.runtime).to receive(:schedule_render)
    root = adapter.create(:page, title: 'Tall span')
    grid = adapter.create(:grid, cols: 2)
    child = adapter.create(:text, content: 'Instructions', placement: { row: 9, row_span: 92 })
    adapter.attach(root, grid)
    adapter.attach(grid, child)
    adapter.send(:flush!)
    page = service.registry.pages_for(owner).first
    before = page.last_render.tree.children.first.children.first
    expect(before.placement).to include(row: 9, row_span: 92)
    expect { adapter.layout_grid(grid, columns: 2, placements: { child => { row: 1000, row_span: 26 } }) }
      .to raise_error(Lich::WebUI::Error, /grid rows/)
    adapter.send(:flush!)
    expect(page.last_render.tree.children.first.children.first.placement).to eq(before.placement)
    invalid = adapter.create(:text, content: 'Too tall', placement: { row_span: 1025 })
    expect { adapter.attach(grid, invalid) }.to raise_error(Lich::WebUI::Error, /1024/)
    boundary = adapter.create(:text, content: 'Last row', placement: { row: 1024, row_span: 1 })
    expect { adapter.attach(grid, boundary) }.not_to raise_error
  end

  it 'atomically repositions grid children and rejects invalid or foreign replacements' do
    allow(service.runtime).to receive(:schedule_render)
    root = adapter.create(:page, title: 'Live grid')
    grid = adapter.create(:grid, cols: 2)
    input = adapter.create(:text_input, value: 'retained', placement: { column: 1, row: 1 })
    adapter.attach(root, grid)
    adapter.attach(grid, input)
    adapter.send(:flush!)
    page = service.registry.pages_for(owner).first
    before = page.last_render.tree.children.first.children.first
    adapter.layout_grid(grid, columns: 3, placements: { input => { column: 3, row: 2 } })
    adapter.send(:flush!)
    after = page.last_render.tree.children.first.children.first
    expect(after.cid).to eq(before.cid)
    expect(after.placement).to include(column: 3, row: 2)
    expect(after.props[:value]).to eq('retained')
    expect { adapter.layout_grid(grid, columns: 1, placements: { input => { column: 2 } }) }.to raise_error(Lich::WebUI::Error)
    expect(adapter.get(grid, :cols)).to eq(3)
    other = adapter.create(:grid, cols: 1)
    expect { adapter.layout_grid(other, columns: 1, placements: { input => { column: 1 } }) }.to raise_error(Lich::WebUI::Error, /foreign/)
    adapter.send(:flush!)
    expect(page.last_render.tree.children.first.children.first.placement).to eq(after.placement)
  end

  it 'retires a replaced binding so its old token cannot remove the new callback' do
    button = adapter.create(:button, label: 'Save')
    previous = adapter.bind(button, :activate, proc {})
    replacement = adapter.bind(button, :activate, proc {})
    expect { adapter.unbind(previous) }.to raise_error(Lich::WebUI::Error, /unknown binding/)
    expect(adapter.unbind(replacement)).to be_nil
  end

  it 'refuses every read and server-side write of sensitive values' do
    password = adapter.create(:password_input, label: 'Password')

    expect { adapter.get(password, :value) }.to raise_error(Lich::WebUI::SensitiveReadError)
    expect { adapter.set(password, :value, 'secret') }.to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'accepts unattributed defaults only before publication, preserving later viewer isolation' do
    allow(service.runtime).to receive(:schedule_render)
    identity = Struct.new(:viewer_id).new(nil)
    port = described_class.new(owner: owner, service: service, viewer: identity)
    root = port.create(:page, title: 'Queued initialization')
    input = port.create(:text_input, value: 'before')
    port.attach(root, input)
    port.set(input, :value, 'initialized')
    expect { port.get(input, :value) }.to raise_error(Lich::WebUI::AmbiguousViewerError)
    port.send(:flush!)
    page = service.registry.pages_for(owner).first
    expect(page.last_render.tree.children.first.props[:value]).to eq('initialized')
    expect { port.set(input, :value, 'unattributed') }.to raise_error(Lich::WebUI::AmbiguousViewerError)
    viewers = %w[first second].map do |id|
      connection = double(id, viewer_id: id, alive?: true, send_text: true)
      service.runtime.handle(connection, type: 'attach', page: service.registry.address_for(page))
      service.runtime.instance_variable_get(:@viewers).fetch(connection_id: id, address: service.registry.address_for(page)).viewer_id
    end
    identity.viewer_id = viewers.first
    port.set(input, :value, 'first only')
    expect(port.get(input, :value)).to eq('first only')
    identity.viewer_id = viewers.last
    expect(port.get(input, :value)).to eq('initialized')
  end

  it 'replaces select options without retaining a removed default or accepting an invalid option list' do
    options = [{ value: 'none', label: '' }, { value: 'old', label: 'Old' }]
    select = adapter.create(:select, options: options, value: 'old')
    adapter.set(select, :options, options.take(1))
    expect(adapter.get(select, :value)).to eq('none')
    expect { adapter.set(select, :options, [{ label: 'Missing value' }]) }.to raise_error(Lich::WebUI::Error)
    expect(adapter.get(select, :options)).to eq(options.take(1))
  end

  context 'browse selection before publication' do
    let(:columns) { [{ key: 'name', label: 'Name' }] }
    let(:rows) { [{ key: 'first', cells: { name: 'First' } }, { key: 'second', cells: { name: 'Second' } }] }

    it 'selects the first remaining row and permits an empty table to be repopulated' do
      table = adapter.create(:table, columns: columns, rows: rows, selection: 'browse', selected: ['first'])
      # Read before publication so ViewerStore reconciliation cannot mask a stale default.
      adapter.set(table, :rows, rows.drop(1))
      expect(adapter.get(table, :selected)).to eq(['second'])
      adapter.set(table, :rows, [])
      expect(adapter.get(table, :selected)).to eq([])
      adapter.set(table, :rows, rows)
      expect(adapter.get(table, :selected)).to eq(['first'])
      expect { adapter.set(table, :rows, [{ cells: {} }]) }.to raise_error(Lich::WebUI::SchemaViolationError)
      expect(adapter.get(table, :selected)).to eq(['first'])
    end

    it 'supplies a selection when entering browse mode unless the table is empty' do
      [[], rows].each do |initial_rows|
        table = adapter.create(:table, columns: columns, rows: initial_rows, selection: 'single', selected: [])
        adapter.set(table, :selection, 'browse')
        expect(adapter.get(table, :selected)).to eq(initial_rows.empty? ? [] : ['first'])
      end
    end

    it 'preserves a surviving selection when entering browse mode or replacing rows' do
      table = adapter.create(:table, columns: columns, rows: rows, selection: 'single', selected: ['second'])
      adapter.set(table, :selection, 'browse')
      expect(adapter.get(table, :selected)).to eq(['second'])
      adapter.set(table, :rows, rows)
      expect(adapter.get(table, :selected)).to eq(['second'])
    end

    it 'keeps none and single modes from automatically selecting a replacement row' do
      %w[none single].each do |mode|
        table = adapter.create(:table, columns: columns, rows: rows, selection: 'browse', selected: ['first'])
        adapter.set(table, :selection, mode)
        expect(adapter.get(table, :selected)).to eq(mode == 'none' ? [] : ['first'])
        adapter.set(table, :rows, rows.drop(1))
        expect(adapter.get(table, :selected)).to eq([])
      end
    end
  end

  it 'attaches, detaches, binds, unbinds, and destroys with attributed failures' do
    page = adapter.create(:page, title: 'Adapter page')
    group = adapter.create(:group, label: 'Actions')
    button = adapter.create(:button, label: 'Go')
    callback = proc {}

    expect(adapter.attach(page, group)).to be_nil
    expect(adapter.attach(group, button, 0)).to be_nil
    binding = adapter.bind(button, :activate, callback)
    expect(binding).to match(/\Abinding-[0-9a-f]{32}\z/)
    expect(adapter.unbind(binding)).to be_nil
    expect(adapter.detach(group, button)).to be_nil
    expect { adapter.detach(group, button) }.to raise_error(Lich::WebUI::Error, /owner=.*opaque-/)
    expect(adapter.destroy(button)).to be_nil
    expect { adapter.destroy(button) }.to raise_error(Lich::WebUI::Error, /already destroyed/)
  end

  it 'publishes a page using only the ten public operations' do
    rendered = Queue.new
    allow(service).to receive(:refresh).and_wrap_original do |original, page|
      result = original.call(page)
      rendered << page
      result
    end
    page = adapter.create(:page, title: 'Public port')
    button = adapter.create(:button, label: 'Visible')
    adapter.attach(page, button)

    published = Timeout.timeout(2) { rendered.pop }
    expect(service.registry.pages_for(owner)).to include(published)
    expect(published.last_render.tree.children.first.props[:label]).to eq('Visible')
  end

  it 'does not resurrect a page when its owner terminates before delivery' do
    adapter.create(:page, title: 'Cancelled')
    service.terminate_owner(owner)
    service.stop
    expect(service.registry.pages_for(owner)).to be_empty
  end

  it 'publishes equal page roots independently in the same render batch' do
    scheduled = []
    published = []
    allow(service.runtime).to receive(:schedule_render) { |_key, **_options, &render| scheduled << render }
    port = described_class.new(owner: owner, service: service, on_publish: ->(page) { published << page })
    first = port.create(:page, title: '')
    second = port.create(:page, title: '')

    scheduled.shift.call
    drain_publication

    expect(published.length).to eq(2)
    expect(published.map(&:id).uniq.length).to eq(2)
    expect(service.registry.pages_for(owner)).to match_array(published)
    port.destroy(first)
    expect(service.registry.pages_for(owner)).to eq([published.last])
    port.set(second, :title, 'Still open')
    scheduled.shift.call
    drain_publication
    expect(published.last.last_render.tree.props[:title]).to eq('Still open')
  end

  it 'keeps queued initialization ahead of one coalesced publication task' do
    scheduled, ready, release = Queue.new, Queue.new, Queue.new
    allow(service.runtime).to receive(:schedule_render) { |_key, **_options, &render| scheduled << render }
    port = described_class.new(owner: owner, service: service)
    service.runtime.dispatch(owner: owner) do
      root = port.create(:page, title: 'Queued construction')
      entry = port.create(:text_input, value: 'Initial')
      port.attach(root, entry)
      ready << true
      release.pop
      port.set(entry, :value, 'Completed before publication')
    end
    expect(ready.pop(timeout: 3)).to be(true)
    scheduled.pop(timeout: 3).call
    expect(service.registry.pages_for(owner)).to be_empty
    expect(scheduled).to be_empty
    release << true
    drain_publication
    page = service.registry.pages_for(owner).first
    expect(page.last_render.tree.children.first.props[:value]).to eq('Completed before publication')
  ensure
    release&.push(true)
  end

  it 'resolves equal unrendered roots to their own handles' do
    allow(service.runtime).to receive(:schedule_render)
    first = adapter.create(:page, title: '')
    second = adapter.create(:page, title: '')
    nodes = adapter.instance_variable_get(:@nodes)

    expect(adapter.send(:handle_for, nodes.fetch(first))).to equal(first)
    expect(adapter.send(:handle_for, nodes.fetch(second))).to equal(second)
  end

  it 'batches mutations into one generation at the runtime render boundary' do
    scheduled = []
    allow(service.runtime).to receive(:schedule_render) { |_key, **_options, &render| scheduled << render }
    page_handle = adapter.create(:page, title: 'Adapter page')
    button = adapter.create(:button, label: 'Before')
    adapter.attach(page_handle, button)

    scheduled.shift.call
    drain_publication
    page = service.registry.pages_for(owner).fetch(0)
    first_generation = page.generation

    adapter.set(button, :label, 'Intermediate')
    adapter.set(button, :label, 'After')
    expect(page.generation).to eq(first_generation)

    scheduled.shift.call
    drain_publication
    expect(page.generation).to eq(first_generation + 1)
    expect(page.last_render.tree.children.first.props[:label]).to eq('After')
  end

  it 'returns a cancellable future from modal' do
    future = adapter.modal(
      id: 'adapter-dialog', title: 'Question', body: 'Continue?',
      buttons: [{ id: 'yes', label: 'Yes' }], no_viewer: :default, default_button: 'yes'
    )

    expect(future).to be_a(Lich::WebUI::Future)
    expect(future.await(timeout: 1)&.button).to eq('yes')
  end

  ["\r\n", "\r"].each do |line_break|
    it "reconciles real textarea edits before Save without replaying #{line_break.inspect} normalization" do
      allow(service.runtime).to receive(:schedule_render)
      root = adapter.create(:page, title: 'Text form')
      input = adapter.create(:textarea, value: "First#{line_break}Second")
      save = adapter.create(:button, label: 'Save')
      adapter.attach(root, input)
      adapter.attach(root, save)
      events = Queue.new
      adapter.bind(input, :change, ->(event) { events << [:change, event.payload[:value]] })
      adapter.bind(save, :activate, ->(event) { events << [:save, event.submission[event.submission.cids.first]] })
      adapter.send(:flush!)
      page = service.registry.pages_for(owner).first
      address = service.registry.address_for(page)
      connection = double('connection', viewer_id: 'textarea-reader', alive?: true)
      messages = []
      allow(connection).to receive(:send_text) { |json| messages << JSON.parse(json) }
      service.runtime.handle(connection, type: 'attach', page: address)
      render = messages.last
      submit = lambda do |text|
        service.runtime.handle(connection, type: 'event', page: address, generation: render['generation'],
                                           cid: render.dig('tree', 'children', 1, 'cid'), event: 'activate', payload: {}, submission: [text])
      end

      # Browser newline conversion is not an edit; a missed real edit still
      # reaches the legacy change handler before the terminal Save callback.
      expect(submit.call("First\nSecond")).to eq(:queued)
      expect(events.pop(timeout: 2)).to eq([:save, "First\nSecond"])
      expect(events).to be_empty
      expect(submit.call("First\nChanged")).to eq(:queued)
      expect(events.pop(timeout: 2)).to eq([:change, "First\nChanged"])
      expect(events.pop(timeout: 2)).to eq([:save, "First\nChanged"])
      expect(events).to be_empty
    end
  end

  it 'reads and writes the event viewer without exposing their value to another viewer' do
    unscoped = described_class.new(owner: owner, service: service)
    scheduled = []
    allow(service.runtime).to receive(:schedule_render) { |_key, **_options, &render| scheduled << render }
    root = unscoped.create(:page, title: 'Private drafts')
    input = unscoped.create(:text_input, value: 'initial')
    unscoped.attach(root, input)
    results = Queue.new
    unscoped.bind(input, :change, proc do |_event|
      value = unscoped.get(input, :value)
      unscoped.set(input, :value, value.upcase)
      results << value
    end)
    scheduled.shift.call
    drain_publication
    page = service.registry.pages_for(owner).first
    address = service.registry.address_for(page)
    connections = %w[first second].map do |id|
      connection = double("connection #{id}", viewer_id: id, alive?: true)
      messages = []
      allow(connection).to receive(:send_text) { |json| messages << JSON.parse(json) }
      service.runtime.handle(connection, type: 'attach', page: address)
      [connection, messages]
    end
    first, messages = connections.first
    render = messages.last
    service.runtime.handle(first, type: 'event', page: address,
                                  cid: render.dig('tree', 'children', 0, 'cid'),
                                  generation: render['generation'], event: 'change', payload: { value: 'private' })

    expect(Timeout.timeout(2) { results.pop }).to eq('private')
    service.refresh(page)
    expect(connections.first.last.last.dig('tree', 'children', 0, 'props', 'value')).to eq('PRIVATE')
    expect(connections.last.last.last.dig('tree', 'children', 0, 'props', 'value')).to eq('initial')
  end

  %i[string_like resolver].each do |identity_kind|
    it "normalizes #{identity_kind} identities and seeds before a concurrent live write" do
      allow(service.runtime).to receive(:schedule_render)
      identity = double('string-like identity')
      selected = identity_kind == :resolver ? double('viewer resolver', viewer_id: identity) : identity
      scoped = described_class.new(owner: owner, service: service, viewer: selected)
      root = scoped.create(:page, title: 'Ordered seeds')
      scoped.send(:flush!)
      page = service.registry.pages_for(owner).first
      connection = double('connection', viewer_id: 'seed-reader', alive?: true, send_text: true)
      service.runtime.handle(connection, type: 'attach', page: service.registry.address_for(page))
      attachment = service.runtime.instance_variable_get(:@viewers).attachments_for(page).first
      allow(identity).to receive(:to_s).and_return(attachment.viewer_id)
      input = scoped.create(:textarea, value: 'Default')
      scoped.attach(root, input)
      scoped.set(input, :value, 'Queued')
      entered = Queue.new
      writer = nil
      allow(service.runtime).to receive(:seed_viewer_properties).and_wrap_original do |original, *args|
        # Force a live writer into the publication/seeding gap. It must wait
        # until the older seed is installed, then win with its newer value.
        writer = Thread.new do
          entered << true
          scoped.set(input, :value, 'Newer')
        end
        entered.pop
        writer.join(0.05)
        original.call(*args)
      end
      scoped.send(:flush!)
      expect(writer.join(2)).to equal(writer)
      expect(service.runtime).to have_received(:seed_viewer_properties).with(page, [[attachment.viewer_id, anything, :value, 'Queued']])
      expect(scoped.get(input, :value)).to eq('Newer')
    ensure
      writer&.kill if writer&.alive?
    end
  end

  it 'swaps ordinary children atomically and rejects owned, foreign and cyclic replacements' do
    root = adapter.create(:stack, {})
    old, replacement = %w[Old New].map { |name| adapter.create(:text, content: name) }
    adapter.attach(root, old)
    other = adapter.create(:stack, {})
    adapter.attach(other, replacement)
    expect { adapter.replace_child(root, old, replacement) }.to raise_error(Lich::WebUI::Error)
    expect { adapter.replace_child(root, old, root) }.to raise_error(Lich::WebUI::Error)
    foreign = described_class.new(owner: Object.new, service: service).create(:text, content: 'Foreign')
    expect { adapter.replace_child(root, old, foreign) }.to raise_error(Lich::WebUI::Error)
    adapter.detach(other, replacement)
    adapter.replace_child(root, old, replacement)
    adapter.attach(other, old)
    expect { adapter.detach(root, old) }.to raise_error(Lich::WebUI::Error)
    adapter.detach(root, replacement)
    expect(adapter.get(replacement, :content)).to eq('New')
  end
  [true, false].each do |replace_previous|
    it "restores ordinary child ownership when publication refuses #{replace_previous ? 'replacement' : 'append'}" do
      allow(service.runtime).to receive(:schedule_render)
      root, parent = adapter.create(:page, title: 'Rollback'), adapter.create(:stack, {})
      before, old, after, replacement = %w[Before Old After New].map { |name| adapter.create(:text, content: name) }
      [before, old, after].each { |child| adapter.attach(parent, child) }
      adapter.attach(root, parent)
      adapter.send(:flush!)
      adapter.instance_variable_set(:@publication_pending, false)
      failure = Lich::WebUI::Error.new('render owner is terminated')
      allow(service.runtime).to receive(:schedule_render).and_raise(failure)
      expect { adapter.replace_child(parent, replace_previous ? old : nil, replacement) }.to(raise_error { |error| expect(error).to equal(failure) })
      expect(adapter.send(:node!, parent).children).to eq([before, old, after])
      expect(adapter.send(:node!, old).parent).to equal(parent)
      expect(adapter.send(:node!, replacement).parent).to be_nil
      expect(adapter.instance_variable_get(:@publication_pending)).to be(false)
      allow(service.runtime).to receive(:schedule_render)
      adapter.replace_child(parent, replace_previous ? old : nil, replacement)
      expected = replace_previous ? [before, replacement, after] : [before, old, after, replacement]
      expect(adapter.send(:node!, parent).children).to eq(expected)
      expect(adapter.send(:node!, replacement).parent).to equal(parent)
      adapter.send(:flush!)
      page = service.registry.pages_for(owner).first
      expect(page.last_render.tree.each.select { |node| node.type == :text }.map { |node| node.props[:content] }).to eq(expected.map { |handle| adapter.get(handle, :content) })
    end
  end
end
