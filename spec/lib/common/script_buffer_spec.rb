# frozen_string_literal: true

require_relative '../../spec_helper'

RSpec.describe 'Lich::Common::Script downstream buffer' do
  let(:buffer) { Lich::Common::LimitedArray.new }
  let(:script) do
    Lich::Common::Script.allocate.tap do |instance|
      instance.instance_variable_set(:@downstream_buffer, buffer)
      instance.instance_variable_set(:@want_downstream, true)
      instance.instance_variable_set(:@want_downstream_xml, false)
      instance.instance_variable_set(:@want_script_output, false)
    end
  end

  before(:context) do
    require_relative '../../../lib/common/script'
  end

  after(:context) do
    %i[ExecScript WizardScript Script Scripting TRUSTED_SCRIPT_BINDING].each do |const_name|
      Lich::Common.send(:remove_const, const_name) if Lich::Common.const_defined?(const_name, false)
    end
    $LOADED_FEATURES.delete_if { |path| path.end_with?('/lib/common/script.rb') }
  end

  it 'blocks gets until a downstream line arrives' do
    waiter = Thread.new { script.gets }
    sleep 0.02

    buffer.push('line')

    expect(waiter.value).to eq('line')
  end

  it 'supports a bounded gets timeout' do
    expect(script.gets(0.02)).to be_nil
  end

  it 'provides a non-blocking gets?' do
    expect(script.gets?).to be_nil
    buffer.push('line')
    expect(script.gets?).to eq('line')
  end

  it 'returns and clears buffered lines atomically' do
    buffer.push('one')
    buffer.push('two')

    expect(script.clear).to eq(%w[one two])
    expect(buffer).to be_empty
  end
end
