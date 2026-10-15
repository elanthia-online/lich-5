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
RSpec.describe 'stream replay: <room> block per front end', :slow do
  fixture = StreamReplay::Fixture.load(File.expand_path('../fixtures/streams/dr_saga_containers_speech.xml', __dir__))
  rooms = 34 # <room> blocks in the fixture

  {
    nil      => { '<room>' => 0, '<style id="roomName"' => rooms },
    'genie'  => { '<room>' => 0, '<style id="roomName"' => rooms },
    'saga'   => { '<room>' => rooms, '<style id="roomName"' => 0 },
    'wizard' => { '<room>' => 0, "\034GSo" => rooms }
  }.each do |frontend, expected|
    it "delivers #{expected.map { |k, v| "#{v} x #{k.inspect}" }.join(', ')} to #{frontend || 'a headless pipe'}" do
      result = StreamReplay::Driver.new(fixture, frontend: frontend).run
      expect(result.warnings).to be_empty
      expected.each { |marker, count| expect(result.stdout.scan(marker).size).to eq(count), marker.inspect }
    end
  end
end
