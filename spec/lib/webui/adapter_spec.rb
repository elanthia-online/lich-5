# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

RSpec.describe Lich::WebUI::Adapter do
  let(:owner) { Object.new }
  let(:service) { Lich::WebUI::Service.new }
  let(:adapter) { described_class.new(owner: owner, service: service, viewer: 'viewer-one') }

  after { service.stop }

  it 'exposes exactly the ten locked operations' do
    expect(described_class.public_instance_methods(false)).to contain_exactly(
      :create, :get, :set, :attach, :detach, :bind, :unbind, :destroy, :modal, :schema
    )
  end

  it 'creates opaque handles and returns the frozen contract schema' do
    handle = adapter.create(:button, label: 'Go')

    expect(handle.inspect).to eq('#<Lich::WebUI::Adapter::Handle opaque>')
    expect(handle).not_to respond_to(:type, :props, :cid)
    expect(adapter.schema(:button)).to be_frozen
    expect { adapter.schema(:invented) }.to raise_error(Lich::WebUI::UnknownTypeError, /owner=/)
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

  it 'refuses every read and server-side write of sensitive values' do
    password = adapter.create(:password_input, label: 'Password')

    expect { adapter.get(password, :value) }.to raise_error(Lich::WebUI::SensitiveReadError)
    expect { adapter.set(password, :value, 'secret') }.to raise_error(Lich::WebUI::SchemaViolationError)
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

  it 'batches mutations into one generation when the shim yields' do
    page_handle = adapter.create(:page, title: 'Adapter page')
    button = adapter.create(:button, label: 'Before')
    adapter.attach(page_handle, button)

    adapter.send(:flush!)
    page = service.registry.pages_for(owner).fetch(0)
    first_generation = page.generation

    adapter.set(button, :label, 'Intermediate')
    adapter.set(button, :label, 'After')
    expect(page.generation).to eq(first_generation)

    adapter.send(:flush!)
    expect(page.generation).to eq(first_generation + 1)
    expect(page.last_render.tree.children.first.props[:label]).to eq('After')
  end

  # A viewer attaching takes the page's render mutex and then reaches into
  # the adapter for the tree; flush! took them in the opposite order and
  # deadlocked the script thread against the connection thread.
  it 'refreshes outside its own lock so a concurrent render cannot deadlock it' do
    page_handle = adapter.create(:page, title: 'Adapter page')
    button = adapter.create(:button, label: 'Before')
    adapter.attach(page_handle, button)
    adapter.send(:flush!)
    page = service.registry.pages_for(owner).fetch(0)

    # Pauses the first render inside its render block: the render mutex is
    # held and the adapter's is about to be taken, which is exactly where a
    # viewer attaching on the connection thread sits. Only the first render
    # blocks, so flush!'s own render runs through.
    inside_render = Queue.new
    release_render = Queue.new
    paused = false
    pause_mutex = Mutex.new
    original_block = page.instance_variable_get(:@render_block)
    page.instance_variable_set(:@render_block, proc do |builder|
      first = pause_mutex.synchronize { paused ? false : (paused = true) }
      if first
        inside_render << :held
        release_render.pop
      end
      instance_exec(builder, &original_block)
    end)

    # Connection thread: holds the render mutex, then wants the adapter's.
    attacher = Thread.new { page.render }
    inside_render.pop

    # Script thread: wants the render mutex while holding the adapter's.
    adapter.set(button, :label, 'After')
    flusher = Thread.new { adapter.send(:flush!) }

    # Let the flusher reach the lock before releasing the paused render --
    # otherwise it finishes first and the inversion never forms.
    sleep 0.05 until flusher.status == 'sleep' || !flusher.alive?
    release_render << :go
    expect(flusher.join(5)).not_to be_nil, 'flush! deadlocked against a concurrent render'
    expect(attacher.join(5)).not_to be_nil
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

  # handle_for was Hash#key, which scans values -- and a Node is a Struct, so
  # every candidate is a memberwise == recursing into props and children.
  # flush! calls it twice per dirty root on every commit, and the shim commits
  # on every property write. It is a reverse identity map now, which has to
  # stay in step with @nodes through destruction or handle_for starts lying.
  describe 'the handle lookup' do
    def nodes = adapter.instance_variable_get(:@nodes)
    def reverse = adapter.instance_variable_get(:@handles_by_node)

    it 'round-trips a node back to the handle it was created with' do
      root = adapter.create(:page, { title: 'T' })
      child = adapter.create(:text, { content: 'hi', wrap: false })
      adapter.attach(root, child)

      expect(adapter.send(:handle_for, nodes[child])).to equal(child)
    end

    it 'stays in step with the node table as nodes come and go' do
      root = adapter.create(:page, { title: 'T' })
      children = Array.new(4) do |index|
        handle = adapter.create(:text, { content: "row #{index}", wrap: false })
        adapter.attach(root, handle)
        handle
      end

      expect(reverse.size).to eq(nodes.size)

      adapter.destroy(children[1])

      expect(reverse.size).to eq(nodes.size)

      # Destroying a root cascades; nothing may be left behind on either side.
      adapter.destroy(root)

      expect(nodes).to be_empty
      expect(reverse).to be_empty
    end

    it 'forgets a destroyed node rather than answering for it' do
      root = adapter.create(:page, { title: 'T' })
      child = adapter.create(:text, { content: 'gone', wrap: false })
      adapter.attach(root, child)
      node = nodes[child]
      adapter.destroy(child)

      expect(adapter.send(:handle_for, node)).to be_nil
    end
  end
end
