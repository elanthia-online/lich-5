# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../support/stream_replay/fixture'
require_relative '../support/stream_replay/driver'
require_relative '../support/stream_replay/golden'

# Golden-master replay of captured server streams through a real
# `lich.rbw --pipe` process (see spec/support/stream_replay/driver.rb).
#
# Each fixture's per-prompt parsed state (XMLData, GameObj, DR creatures,
# DRRoom, DRSpells, stripped script lines) must match its committed golden
# exactly. A mismatch means parser-visible behavior changed: if intended,
# regenerate with
#
#   UPDATE_STREAM_GOLDENS=1 bundle exec rspec spec/stream_replay
#
# and review the golden diff in the PR. Fixture provenance is recorded in
# spec/fixtures/streams/MANIFEST.md.
RSpec.describe 'stream replay goldens', :slow do
  repo = File.expand_path('../..', __dir__)
  # benchmark/fixtures/dr_inventory_sample.xml is a prompt-less throughput
  # sample, so it has no snapshots and is not replayed here.
  fixtures = Dir[File.join(repo, 'spec/fixtures/streams/*.xml')].sort +
             %w[gs_sample.xml dr_sample.xml].map { |f| File.join(repo, 'benchmark/fixtures', f) }

  fixtures.each do |path|
    fixture = StreamReplay::Fixture.load(path)
    golden_path = File.join(repo, 'spec/fixtures/streams/goldens', "#{fixture.name}.jsonl")

    it "replays #{File.basename(path)} (#{fixture.game}) to its golden" do
      result = StreamReplay::Driver.new(fixture).run
      expect(result.warnings).to be_empty, result.warnings.join("\n")
      expect(result.snapshots).not_to be_empty

      probe_errors = result.snapshots.flat_map do |snap|
        snap.select { |_k, v| v.is_a?(Hash) && v['error'] }.map { |k, v| "#{k}: #{v['error']}" }
      end
      probe_errors += result.snapshots.filter_map { |snap| snap['probe_error'] }
      expect(probe_errors.uniq).to be_empty, probe_errors.uniq.join("\n")

      deltas = StreamReplay::Golden.encode(result.snapshots)
      if ENV['UPDATE_STREAM_GOLDENS']
        StreamReplay::Golden.write(golden_path, deltas)
        skip "golden written: #{golden_path}"
      end

      expect(File).to exist(golden_path), "missing golden #{golden_path}; run with UPDATE_STREAM_GOLDENS=1"
      mismatches = StreamReplay::Golden.diff(StreamReplay::Golden.read(golden_path), deltas)
      expect(mismatches).to be_empty, "golden mismatch for #{fixture.name}:\n#{mismatches.join("\n")}"
    end
  end
end

# What reaches the client for the Saga-identity <room> block, per front end:
# only Saga (:room_element) gets the raw block; every other front end gets the
# legacy roomName layout it already renders, and Wizard its GSL room codes.
# The legacy layout carries the legacy compass after every view, as the legacy
# stream did.
RSpec.describe 'stream replay: <room> block per front end', :slow do
  fixture = StreamReplay::Fixture.load(File.expand_path('../fixtures/streams/dr_saga_containers_speech.xml', __dir__))
  rooms = 34 # <room> blocks in the fixture
  compass = '<compass><dir value='

  {
    nil      => { '<room>' => 0, '<style id="roomName"' => rooms, compass => rooms },
    'genie'  => { '<room>' => 0, '<style id="roomName"' => rooms, compass => rooms },
    'saga'   => { '<room>' => rooms, '<style id="roomName"' => 0, compass => 0 },
    'wizard' => { '<room>' => 0, "\034GSo" => rooms, compass => 0 }
  }.each do |frontend, expected|
    it "delivers #{expected.map { |k, v| "#{v} x #{k.inspect}" }.join(', ')} to #{frontend || 'a headless pipe'}" do
      result = StreamReplay::Driver.new(fixture, frontend: frontend).run
      expect(result.warnings).to be_empty
      expected.each { |marker, count| expect(result.stdout.scan(marker).size).to eq(count), marker.inspect }
    end
  end
end

# DragonRealms' links and doubled bold reach only Saga (:game_links,
# :double_bold); every other front end gets the legacy line. Scripts see the
# same stream whatever the front end: the parsed state and script lines
# (the per-prompt snapshots) do not depend on it.
RSpec.describe 'stream replay: DragonRealms links and doubled bold per front end', :slow do
  fixture = StreamReplay::Fixture.load(File.expand_path('../fixtures/streams/dr_saga_hunt.xml', __dir__))
  links = fixture.body_lines.sum { |l| l.scan('<a exist').size }
  doubled = fixture.body_lines.sum { |l| l.scan('<pushBold/><pushBold/>').size }
  results = {}
  replay = ->(frontend) { results[frontend] ||= StreamReplay::Driver.new(fixture, frontend: frontend).run }

  it 'replays a fixture that has both' do
    expect([links, doubled]).to all(be > 100)
  end

  { nil => [0, 0], 'genie' => [0, 0], 'saga' => [links, doubled] }.each do |frontend, (want_links, want_doubled)|
    it "delivers #{want_links} links and #{want_doubled} doubled bolds to #{frontend || 'a headless pipe'}, with Saga's snapshots" do
      result = replay.call(frontend)
      expect(result.warnings).to be_empty
      expect(result.stdout.scan('<a exist').size).to eq(want_links)
      expect(result.stdout.scan('<pushBold/><pushBold/>').size).to eq(want_doubled)
      expect(result.snapshots).to eq(replay.call('saga').snapshots)
    end
  end
end

# A Locate view of another room (230008) while the character stands in
# 230007: the legacy stream followed it with 230008's compass
# (spec/fixtures/room_block/dr_legacy_locate.xml), and so does the rewrite.
RSpec.describe 'stream replay: Locate view per front end', :slow do
  fixture = StreamReplay::Fixture.load(File.expand_path('../fixtures/streams/dr_saga_locate_descflag.xml', __dir__))
  own = %(Obvious paths: <d>north</d>, <d>southeast</d>.\r\n<compass><dir value="n"/><dir value="se"/></compass>\r\n)
  located = %(Obvious paths: <d>north</d>, <d>south</d>.\r\n<compass><dir value="n"/><dir value="s"/></compass>\r\n)

  it 'gives a legacy front end the located room\'s compass after the Locate view, between two own-room views' do
    result = StreamReplay::Driver.new(fixture, frontend: 'genie').run
    expect(result.warnings).to be_empty
    out = result.stdout
    expect(out.scan(own).size).to eq(2)
    expect(out.scan(located).size).to eq(1)
    expect(out.index(own)).to be < out.index(located)
    expect(out.index(located)).to be < out.rindex(own)
  end
end
