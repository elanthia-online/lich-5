# frozen_string_literal: true

require_relative '../../spec_helper'
require 'open3'
require 'rbconfig'
require 'webui'

RSpec.describe 'Adapter publication boundaries' do
  let(:owner) { Object.new }
  let(:service) { Lich::WebUI::Service.new }
  let(:published) { [] }
  let(:adapter) do
    Lich::WebUI::Adapter.new(owner: owner, service: service, viewer: 'one',
                             on_publish: ->(page) { published << page })
  end

  before { allow(service.runtime).to receive(:schedule_render) }
  after { service.stop }

  it 'retains pending viewer values and bindings when refresh fails before first publication' do
    root = adapter.create(:page, title: 'Pending')
    input = adapter.create(:text_input, value: 'Default')
    button = adapter.create(:button, label: 'Save')
    adapter.attach(root, input)
    adapter.attach(root, button)
    adapter.set(input, :value, 'Pending')
    calls = []
    callback = proc { calls << :save }
    adapter.bind(button, :activate, callback)
    allow(service.runtime).to receive(:seed_viewer_properties).and_call_original
    error = Lich::WebUI::Error.new('refresh refused')
    allow(service).to receive(:refresh).and_raise(error)

    expect { adapter.send(:flush!) }.to(raise_error { |raised| expect(raised).to equal(error) })
    expect(published).to be_empty
    expect(service.runtime).not_to have_received(:seed_viewer_properties)
    expect(adapter.get(input, :value)).to eq('Pending')
    page = service.registry.pages_for(owner).fetch(0)

    allow(service).to receive(:refresh).and_call_original
    adapter.set(root, :title, 'Ready')
    adapter.send(:flush!)
    expect(published).to eq([page])
    expect(service.registry.pages_for(owner)).to eq([page])
    tree = page.last_render.tree
    entry, save = tree.children
    expect(entry.props[:value]).to eq('Default')
    expect(service.runtime).to have_received(:seed_viewer_properties).with(page, [['one', entry.cid, :value, 'Pending']])
    expect(page.last_render.submissions.fetch(save.cid)).to eq([entry.cid])
    page.last_render.bindings.fetch([save.cid, :activate]).call(
      Lich::WebUI::Runtime::EventContext.new(
        viewer_id: 'one', page: page, component: save, event: :activate, payload: {}, submission: nil
      )
    )
    expect(calls).to eq([:save])
  end

  it 'builds one captured tree and callback set while concurrent mutations prepare the next publication' do
    root = adapter.create(:page, title: 'Snapshot')
    first = adapter.create(:text, content: 'First')
    second = adapter.create(:text, content: 'Before')
    button = adapter.create(:button, label: 'Action')
    [first, second, button].each { |child| adapter.attach(root, child) }
    calls = []
    adapter.bind(button, :activate, ->(_context) { calls << :before })
    changed = false
    worker = nil
    allow(Lich::WebUI::TreeBuilder).to receive(:new).and_wrap_original do |constructor, **options|
      builder = constructor.call(**options)
      allow(builder).to receive(:component).and_wrap_original do |component, *args, **props, &block|
        unless changed
          changed = true
          worker = Thread.new do
            adapter.set(second, :content, 'After')
            adapter.bind(button, :activate, ->(_context) { calls << :after })
          end
          expect(worker.join(1)).to equal(worker)
          worker.value
        end
        component.call(*args, **props, &block)
      end
      builder
    end

    adapter.send(:flush!)
    page = published.fetch(0)
    first_render = page.last_render
    expect(first_render.tree.children.map { |child| child.props[:content] }).to eq(['First', 'Before', nil])
    button_cid = first_render.tree.children.last.cid
    context = Lich::WebUI::Runtime::EventContext.new(
      viewer_id: 'one', page: page, component: nil, event: :activate, payload: {}, submission: nil
    )
    first_render.bindings.fetch([button_cid, :activate]).call(context)
    expect(calls).to eq([:before])

    adapter.send(:flush!)
    next_render = page.last_render
    expect(next_render.tree.children.map(&:cid)).to eq(first_render.tree.children.map(&:cid))
    expect(next_render.tree.children[1].props[:content]).to eq('After')
    next_render.bindings.fetch([button_cid, :activate]).call(context)
    expect(calls).to eq(%i[before after])
    expect(published).to eq([page])
  ensure
    worker&.kill if worker&.alive?
  end

  %w[webui/adapter webui].each do |entry|
    it "boots through #{entry} and publishes with the production facade in a fresh process" do
      code = <<~RUBY_CODE
        require '#{entry}'
        require 'webui'
        service = Lich::WebUI::Service.new
        begin
          service.runtime.define_singleton_method(:schedule_render) { |*_args, **_options, &_work| }
          owner = Object.new
          port = Lich::WebUI::Adapter.new(owner: owner, service: service)
          root = port.create(:page, title: 'Boot')
          child = port.create(:text, content: 'Ready')
          port.attach(root, child)
          port.send(:flush!)
          page = service.registry.pages_for(owner).fetch(0)
          abort 'wrong tree' unless page.last_render.tree.children.first.props[:content] == 'Ready'
          port.set(child, :content, 'Changed')
          port.send(:flush!)
          abort 'wrong mutation' unless page.last_render.tree.children.first.props[:content] == 'Changed'
          port.destroy(root)
          abort 'page retained' unless service.registry.pages_for(owner).empty?
          puts 'ready'
        ensure
          service.stop
        end
      RUBY_CODE
      output, errors, status = Open3.capture3(RbConfig.ruby, '-w', '-I', LIB_DIR, '-e', code)
      expect(status.success?).to be(true), errors
      # TreeBuilder intentionally replaces its generated text method. These
      # two existing warnings are the complete baseline; any other warning fails.
      expect(errors.lines).to match([
                                      %r{/webui/tree_builder\.rb:\d+: warning: method redefined; discarding old text\n\z},
                                      %r{/webui/tree_builder\.rb:\d+: warning: previous definition of text was here\n\z},
                                    ])
      expect(output).to eq("ready\n")
    end
  end
end
