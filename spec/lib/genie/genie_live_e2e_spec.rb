# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative 'support/example_timeout'
require_relative '../../support/stream_replay/driver'

# The real run path, end to end (PR #1813 review item 4): a real `lich.rbw --pipe` child
# (offline, spec/support/stream_replay/driver.rb) with the engine enabled for the character
# by its per-character lich_settings row, a loopback game server sending DragonRealms XML, and
# a .cmd started from the client. Covers what the unit specs fake: Script.start routing a .cmd
# to GenieScript#run_genie -> run_genie_interpreter, ensure_downstream_hook! /
# install_downstream_hook! (the one-time banner, the #trigger path from the game stream),
# start_command_queue! (a #trigger's #send goes out through the queue worker),
# install_script_output_trigger_tap!, the roundtime resume gate, and LichGameState's
# reserved / host readers ($righthand, $roomname, $roundtime from the capture; $game and
# $scriptlist from Lich). Asserts what Lich writes to the game socket and to the client.
RSpec.describe 'Genie engine live in a real Lich process', :slow do
  fixture_class = Struct.new(:game, :header_lines, :body_lines, keyword_init: true)
  header = [
    %(<mode id="GAME"/>),
    %(<playerID id='700001'/>),
    %(<settingsInfo  client="1.0.1.28" major="32" crc='1009451187' instance='DR'/>),
    %(<app char="Aldric" game="DR" title="[DR: Aldric]"/>),
    %(<streamWindow id="main" title="Story" location="center" target="drop" resident="true"/>),
    %(<endSetup/>)
  ]
  script = <<~CMD
    var x 5
    math x add 3
    echo X=%x
    put #trigger {^The bell rings} {#send BELLCMD}
    action put ACTION_$1 when ^(\\w+) waves\\.$
    gosub sub1 hello
    echo E2E_READY
    matchre FOUND /^You see (\\w+) here/
    matchwait 15
    echo E2E_TIMEOUT
    exit
    FOUND:
    echo MATCHED_$1
    echo RH=$righthand|NOUN=$righthandnoun|ROOM=$roomname|RT=$roundtime|GAME=$game|SL=$scriptlist
    put e2e_done
    exit
    sub1:
    echo IN_SUB_$1
    return
  CMD
  body = [
    { client: '<c>;e2e' },
    { stdout: /E2E_READY/ },
    'The bell rings loudly.',
    '<prompt time="1700000000">&gt;</prompt>',
    { game: /BELLCMD/ },
    'Brenna waves.',
    '<prompt time="1700000001">&gt;</prompt>',
    { game: /ACTION_Brenna/ },
    %(<streamWindow id='room' title='Room' subtitle=" - [Crossing, Town Green]"/>),
    %(<right exist="4242" noun="sword">steel sword</right>),
    %(<roundTime value='1700000003'/>Roundtime: 1 sec.),
    '<prompt time="1700000002">R&gt;</prompt>',
    'You see Brenna here.', # no prompt after it: $roundtime keeps this roundtime's 1
    { stdout: /MATCHED_Brenna/ },
    { game: /e2e_done/ },
    { stdout: /e2e has exited/ }
  ]

  it 'runs a .cmd through the real Lich run path and talks to the game and the client' do
    fixture = fixture_class.new(game: 'DR', header_lines: header, body_lines: body)
    result = StreamReplay::Driver.new(fixture, settings: { 'genie_enabled:DR:Aldric' => 'true' },
                                               scripts: { 'e2e.cmd' => script }).run
    out = result.stdout
    game = result.game_input

    expect(out).to match(/--- Genie engine v\d+\.\d+\.\d+ \(\d{4}-\d\d-\d\d\) active/)
    expect(out.scan('--- Genie engine v').size).to eq(1) # install_downstream_hook! ran once
    expect(out).to include('X=8') # var + math
    expect(out.index('IN_SUB_hello')).to be < out.index('E2E_READY') # gosub with an argument, then return
    # The #trigger fired on the game stream and its #send left through the command queue; the
    # action's put went out on its own line; the script's last put after the matchre.
    expect(game.scan(/^.*(?:BELLCMD|ACTION_Brenna|e2e_done).*$/).map { |l| l.delete("\r") })
      .to eq(['<c>BELLCMD', '<c>ACTION_Brenna', '<c>e2e_done'])
    expect(out).to include('RH=steel sword|NOUN=sword|ROOM=Crossing, Town Green|RT=1|GAME=DR|SL=e2e')
    expect(out).not_to include('E2E_TIMEOUT')
    expect(out).not_to match(/Script error|GenieError|Exception/i)
  end
end
