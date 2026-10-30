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

  it 'records the policy before anything can activate the script scope, which fixes HAVE_GTK' do
    policy = entrypoint.index('Lich::WebUI.configure_presentation(')
    prefix = entrypoint[0...policy]
    expect(prefix).not_to match(/ScriptScope|TRUSTED_SCRIPT_BINDING|Scripting\.new|Script\.start|Script\.run/)
    lib = File.expand_path('../../../lib', __dir__)
    callers = Dir[File.join(lib, '**', '*.rb')].select { |path| File.read(path).match?(/ScriptScope\.activate!/) }
    expect(callers.map { |path| path.delete_prefix("#{lib}/") }).to eq(['common/script.rb'])
  end

  it 'enables presentation unless --no-gui or --no-gtk resolved gui to false' do
    { {} => true, { gui: true } => true, { gui: false } => false }.each do |options, enabled|
      Lich::WebUI.configure_presentation(enabled: options[:gui] != false)
      expect(Lich::WebUI.presentation_enabled?).to be(enabled)
    end
  end
end
