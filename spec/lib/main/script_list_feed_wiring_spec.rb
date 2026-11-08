# frozen_string_literal: true

require 'rspec'

# main.rb runs at load time, so (as in client_string_log_spec.rb) its wiring
# is checked against the shipping source. The primary client gets the script
# list (docs/frontends/script-list-feed.md) from its session set as soon as
# its read loop starts; a client that declares script_list gets it from
# ClientCapabilities.declare instead.
RSpec.describe 'script list feed wiring for the primary client (main.rb)' do
  main_source = File.read(File.expand_path('../../../lib/main/main.rb', __dir__))
  loop_start = main_source.index('while (client_string = $_CLIENT_.gets)')
  hand_off = main_source.index('Lich::Common::ScriptListFeed.client_ready($_CLIENT_)')

  it 'hands the primary client to the feed' do
    expect(hand_off).not_to be_nil
  end

  it 'does so just before the primary read loop starts' do
    expect(loop_start).not_to be_nil
    expect(hand_off).to be < loop_start
    between = main_source[hand_off...loop_start]
    expect(between.lines.count).to be <= 4
  end
end
