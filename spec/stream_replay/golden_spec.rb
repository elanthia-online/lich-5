# frozen_string_literal: true

require_relative '../spec_helper'
require 'tmpdir'
require_relative '../support/stream_replay/golden'

# Every replay golden is a StreamReplay::Golden delta encoding, and every
# golden failure is a Golden.diff report, so these pin both directly.
RSpec.describe StreamReplay::Golden do
  def snap(prompt, **sections)
    sections.transform_keys(&:to_s).merge('prompt' => prompt)
  end

  describe '.encode' do
    it 'records the first prompt in full, then only added, changed and removed paths' do
      snapshots = [
        snap(1, xmldata: { 'room_title' => 'A', 'room_id' => 1 }, stripped: ['x']),
        snap(2, xmldata: { 'room_title' => 'A', 'room_id' => 2, 'room_count' => 7 }, stripped: ['x']),
        snap(3, xmldata: { 'room_title' => 'A' }, stripped: [])
      ]
      expected = [
        { 'prompt' => 1, 'changes' => { 'stripped' => ['x'], 'xmldata.room_id' => 1, 'xmldata.room_title' => 'A' } },
        { 'prompt' => 2, 'changes' => { 'xmldata.room_count' => 7, 'xmldata.room_id' => 2 } },
        { 'prompt' => 3, 'changes' => { 'stripped' => [], 'xmldata.room_count' => nil, 'xmldata.room_id' => nil } }
      ]
      expect(described_class.encode(snapshots)).to eq(expected)
    end

    it 'omits prompts with no changes and numbers prompts by body position' do
      # The probe's own counter includes the discarded warm-up prompt, so body
      # snapshots arrive numbered from 2; goldens number them from 1.
      snapshots = [snap(2, stripped: ['a']), snap(3, stripped: ['a']), snap(4, stripped: ['b'])]
      expect(described_class.encode(snapshots).map { |d| d['prompt'] }).to eq([1, 3])
    end

    it 'ignores the volatile prompt counter itself' do
      expect(described_class.encode([snap(1, stripped: []), snap(99, stripped: [])]).length).to eq(1)
    end

    it 'splits only the SPLIT sections; other top-level keys are compared whole' do
      snapshots = [
        snap(1, drroom: { 'pcs' => ['A'] }, dr_creatures: [{ 'id' => 1 }]),
        snap(2, drroom: { 'pcs' => ['A'] }, dr_creatures: [{ 'id' => 1, 'noun' => 'x' }])
      ]
      deltas = described_class.encode(snapshots)
      expect(deltas.last['changes']).to eq('dr_creatures' => [{ 'id' => 1, 'noun' => 'x' }])
    end

    it 'keeps a section whose probe raised whole, and splits it again once it recovers' do
      snapshots = [
        snap(1, gameobj: { 'npcs' => [] }),
        snap(2, gameobj: { 'error' => 'NameError: boom' }),
        snap(3, gameobj: { 'npcs' => [] })
      ]
      expected = [
        { 'gameobj.npcs' => [] },
        { 'gameobj' => { 'error' => 'NameError: boom' }, 'gameobj.npcs' => nil },
        { 'gameobj' => nil, 'gameobj.npcs' => [] }
      ]
      expect(described_class.encode(snapshots).map { |d| d['changes'] }).to eq(expected)
    end
  end

  describe '.diff' do
    let(:golden) { [{ 'prompt' => 1, 'changes' => { 'a' => 1 } }, { 'prompt' => 3, 'changes' => { 'b' => [1] } }] }

    it 'is empty when the deltas match' do
      expect(described_class.diff(golden, golden.map(&:dup))).to eq([])
    end

    it 'names the prompt and path of a changed value' do
      actual = [golden[0], { 'prompt' => 3, 'changes' => { 'b' => [2] } }]
      expect(described_class.diff(golden, actual)).to eq(["prompt 3 b:\n    expected [1]\n    actual   [2]"])
    end

    it 'reports a path that changed only on one side as (unchanged) on the other' do
      actual = [golden[0], { 'prompt' => 2, 'changes' => { 'a' => 5 } }, golden[1]]
      expect(described_class.diff(golden, actual)).to eq(["prompt 2 a:\n    expected (unchanged)\n    actual   5"])
    end

    it 'tells a path set to nil apart from an unchanged path' do
      actual = [golden[0], { 'prompt' => 3, 'changes' => { 'b' => [1], 'a' => nil } }]
      expect(described_class.diff(golden, actual)).to eq(["prompt 3 a:\n    expected (unchanged)\n    actual   null"])
    end

    it 'stops at the limit' do
      actual = (1..30).map { |n| { 'prompt' => n, 'changes' => { 'z' => n } } }
      expect(described_class.diff([], actual, limit: 5).length).to eq(5)
    end
  end

  describe '.write / .read' do
    it 'round-trips deltas as one JSON object per line' do
      deltas = described_class.encode([snap(1, xmldata: { 'room_name' => nil, 'x' => 'a "quoted" value' }), snap(2, xmldata: { 'x' => 'y' })])
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'g.jsonl')
        described_class.write(path, deltas)
        expect(File.read(path).lines.length).to eq(deltas.length)
        expect(described_class.read(path)).to eq(deltas)
      end
    end
  end
end
