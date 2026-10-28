# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

RSpec.describe 'WebUI presentation policy at startup' do
  let(:entrypoint) { File.read(File.expand_path('../../../lich.rbw', __dir__)) }

  after { Lich::WebUI.configure_presentation(enabled: nil) }

  it 'records the policy from resolved launch options before the main program starts' do
    parsed = entrypoint.index("require File.join(LIB_DIR, 'main', 'argv_options.rb')")
    policy = entrypoint.index('Lich::WebUI.configure_presentation(enabled: @argv_options[:gui] != false)')
    started = entrypoint.index("require File.join(LIB_DIR, 'main', 'main.rb')")
    expect([parsed, policy, started]).to all(be_a(Integer))
    expect(parsed).to be < policy
    expect(policy).to be < started
  end

  it 'enables presentation unless --no-gui or --no-gtk resolved gui to false' do
    { {} => true, { gui: true } => true, { gui: false } => false }.each do |options, enabled|
      Lich::WebUI.configure_presentation(enabled: options[:gui] != false)
      expect(Lich::WebUI.presentation_enabled?).to be(enabled)
    end
  end
end
