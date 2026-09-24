# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui/dispatcher'
require 'webui/future'

RSpec.describe Lich::WebUI::Future do
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
