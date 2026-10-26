# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui/dispatcher'
require 'webui/future'

RSpec.describe Lich::WebUI::Future do
  it 'isolates failing callbacks registered both before and after completion' do
    logger = double('logger', call: nil)
    future = described_class.new(logger: logger)
    observed = []
    future.then { raise 'private callback details' }
    future.then { |result| observed << result.button }
    expect(future.resolve(button: 'ok')).to be(true)
    expect { future.then { raise 'late callback' } }.not_to raise_error
    expect(observed).to eq(['ok'])
    expect(logger).to have_received(:call).with(:error, 'WebUI completion callback failed: RuntimeError').twice
  end

  it 'resolves once and notifies callbacks registered before and after completion' do
    observed = []
    future = described_class.new
    future.then { |result| observed << result }

    expect(future.resolve(button: 'yes')).to be true
    expect(future.resolve(button: 'no')).to be false
    future.then { |result| observed << result }

    expect(future.await.button).to eq('yes')
    expect(observed.map(&:button)).to eq(%w[yes yes])
  end

  it 'continues completion when both a callback and its diagnostic sink fail' do
    future = described_class.new(logger: proc { raise 'logger failed' })
    completed = false
    future.then { raise 'callback failed' }
    future.then { completed = true }
    expect { future.cancel }.not_to raise_error
    expect(completed).to be(true)
  end

  it 'supports cancellation and a bounded blocking wait for the compatibility shim' do
    future = described_class.new

    expect(future.await(timeout: 0.001)).to be_nil
    expect(future.cancel(reason: :terminated)).to be true
    expect(future.await).to have_attributes(button: nil, reason: :terminated)
  end

  it 'refuses blocking waits from a WebUI dispatch callback' do
    Thread.current.thread_variable_set(
      Lich::WebUI::Dispatcher::THREAD_CONTEXT_KEY,
      Lich::WebUI::Dispatcher::Context.new(Object.new, 'page', 'viewer', 'cid', :activate)
    )

    expect { described_class.new.await(timeout: 0) }
      .to raise_error(Lich::WebUI::Dispatcher::ReentryError, /cannot block/)
  ensure
    Thread.current.thread_variable_set(Lich::WebUI::Dispatcher::THREAD_CONTEXT_KEY, nil)
  end
end
