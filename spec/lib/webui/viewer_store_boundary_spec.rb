# frozen_string_literal: true

require_relative '../../spec_helper'
require 'open3'
require 'rbconfig'
require 'webui/viewer_store'
require 'webui/page'

RSpec.describe 'ViewerStore boundaries' do
  let(:store) { Lich::WebUI::ViewerStore.new }
  let(:owner) { Object.new }
  let(:content) { { input: true } }
  let(:page) do
    state = content
    Lich::WebUI::Page.new(owner: owner, id: 'seed', title: 'Seeding') do
      text_input(key: 'name', value: 'Default') if state[:input]
    end
  end

  %i[disconnect close removal].each do |retirement|
    it "refuses a pending property seed after #{retirement} without invoking validation for a stale target" do
      viewer = store.attach(connection_id: 'one', address: 'seed', page: page)
      render = page.render
      store.deliver(viewer, render)
      input = render.tree.children.first
      case retirement
      when :disconnect then store.transient_disconnect('one')
      when :close then store.close(connection_id: 'one', address: 'seed')
      when :removal
        content[:input] = false
        store.deliver(viewer, page.render)
      end
      validator = double('stale target validator')
      expect(validator).not_to receive(:call)
      expect(store.seed_property(viewer, input.cid, :value) { |target| validator.call(target) }).to be_nil

      case retirement
      when :disconnect
        resumed = store.attach(connection_id: 'resumed', address: 'seed', page: page, resume_token: viewer.resume_token)
        expect(resumed).to equal(viewer)
        expect(store.seed_property(resumed, input.cid, :value) { 'Resumed' }).to eq('Resumed')
        expect(store.property(resumed, input, :value)).to eq('Resumed')
      when :close
        replacement = store.attach(connection_id: 'one', address: 'seed', page: page)
        expect(replacement).not_to equal(viewer)
        store.deliver(replacement, render)
        expect(store.property(replacement, input, :value)).to eq('Default')
        expect(store.seed_property(viewer, input.cid, :value) { |target| validator.call(target) }).to be_nil
        expect(store.seed_property(replacement, input.cid, :value) { 'Replacement' }).to eq('Replacement')
        expect(store.property(replacement, input, :value)).to eq('Replacement')
      when :removal
        expect(store.serialize(viewer)[:children]).to be_empty
        content[:input] = true
        store.deliver(viewer, page.render)
        expect(store.seed_property(viewer, input.cid, :value) { 'Returned' }).to eq('Returned')
        expect(store.property(viewer, input, :value)).to eq('Returned')
      end
    end
  end

  it 'keeps lifecycle snapshots separate from the read-only text actually delivered to the browser' do
    target = Lich::WebUI::Page.new(owner: owner, id: 'readonly', title: 'Read-only') do
      textarea(key: 'note', value: "Before\r\npaint", read_only: true)
    end
    viewer = store.attach(connection_id: 'one', address: 'readonly', page: target)
    render = target.render
    store.deliver(viewer, render)
    input = render.tree.children.first
    store.snapshot(viewer, for_delivery: true)
    store.set_property(viewer, input, :value, 'Later server value')
    captured = store.snapshot(viewer)
    closing = store.closing_snapshot(target)
    expect(captured.values[[input.cid, :value]]).to eq('Later server value')
    expect(closing.values[[input.cid, :value]]).to eq('Later server value')
    expect(store.read_only_submission(viewer, input, "Before\npaint")).to eq('Later server value')
    expect do
      store.read_only_submission(viewer, input, 'Later server value')
    end.to raise_error(Lich::WebUI::Protocol::Refusal, /read-only text cannot be changed/)
    store.snapshot(viewer, for_delivery: true)
    expect(store.read_only_submission(viewer, input, 'Later server value')).to eq('Later server value')
  end

  it 'loads the public ViewerStore entry alone and preserves delivery, admission and resume in a fresh process' do
    code = <<~RUBY_CODE
      require 'webui/viewer_store'
      require 'webui/page'
      store = Lich::WebUI::ViewerStore.new
      page = Lich::WebUI::Page.new(owner: Object.new, id: 'boot', title: 'Boot') do
        text_input(key: 'name', value: 'Default')
      end
      viewer = store.attach(connection_id: 'one', address: 'boot', page: page)
      render = page.render
      store.deliver(viewer, render)
      input = render.tree.children.first
      result = store.admit_event(viewer, event: 'change', generation: render.generation, cid: input.cid) do
        store.update(viewer, input, :change, { value: 'Draft' }, 9)
        :queued
      end
      abort 'not admitted' unless result == :queued
      captured = store.snapshot(viewer)
      abort 'ack lost' unless captured.input_requests[input.cid] == 9
      store.transient_disconnect('one')
      resumed = store.attach(connection_id: 'two', address: 'boot', page: page, resume_token: viewer.resume_token)
      abort 'viewer replaced' unless resumed.equal?(viewer)
      abort 'draft lost' unless store.serialize(resumed)[:children].first[:props][:value] == 'Draft'
      closing = store.closing_snapshot(page, retire: true)
      abort 'closing state lost' unless closing.values[[input.cid, :value]] == 'Draft'
      begin
        store.admit_event(viewer, event: 'change', generation: render.generation, cid: input.cid) { abort 'retired viewer admitted' }
        abort 'no retirement refusal'
      rescue Lich::WebUI::Protocol::Refusal => error
        abort 'wrong refusal' unless error.reason == :attachment
      end
      require 'webui/viewer_store'
      puts 'ready'
    RUBY_CODE
    output, errors, status = Open3.capture3(RbConfig.ruby, '-I', LIB_DIR, '-e', code)
    expect(status.success?).to be(true), errors
    expect(errors).to be_empty
    expect(output).to eq("ready\n")
  end
end
