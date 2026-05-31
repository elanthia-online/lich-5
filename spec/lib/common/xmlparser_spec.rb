# frozen_string_literal: true

require_relative '../../spec_helper'
require 'rexml/document'
require 'rexml/streamlistener'
require_relative '../../../lib/common/gameobj'
require_relative '../../../lib/common/xmlparser'

# These specs exercise the staged registry refresh wiring in XMLParser by
# driving tag_start / text / tag_end in the same order games.rb feeds them.
# They assert the core guarantee: a GameObj registry never appears empty or
# half-filled mid-stream - readers see the previous complete snapshot until
# the stream/component commits, then the new one.
RSpec.describe Lich::Common::XMLParser do
  let(:gameobj) { Lich::Common::GameObj }
  let(:parser)  { described_class.new }

  before do
    # XMLData, Creature, and GameObj registry/staging resets are provided by
    # spec_helper. The staged inv/reserve paths gate on a GS game, so pin it
    # here (spec_helper's reset leaves game as the generic 'rspec').
    XMLData.game = 'GSIV'
  end

  # ---------------------------------------------------------------------------
  # Helpers - replay common stream fragments
  # ---------------------------------------------------------------------------

  # A bold <a exist=.. noun=..>name</a> as the game sends NPCs in 'room objs'.
  def feed_bold_a(exist, noun, name)
    parser.tag_start('pushBold', {})
    parser.tag_end('pushBold')
    parser.tag_start('a', { 'exist' => exist, 'noun' => noun })
    parser.text(name)
    parser.tag_end('a')
    parser.tag_start('popBold', {})
    parser.tag_end('popBold')
  end

  # A non-bold <a> as the game sends ground loot in 'room objs'.
  def feed_loot_a(exist, noun, name)
    parser.tag_start('a', { 'exist' => exist, 'noun' => noun })
    parser.text(name)
    parser.tag_end('a')
  end

  describe "'room objs' component refresh" do
    it 'keeps the previous npc list visible until the component closes' do
      gameobj.new_npc('1', 'orc', 'an orc', 'standing') # previously published

      parser.tag_start('component', { 'id' => 'room objs' }) # begin_room_objs
      feed_bold_a('2', 'kobold', 'a kobold')

      # Mid-stream: reader still sees the prior room, not the half-built buffer.
      expect(gameobj.npcs.map(&:id)).to eq(['1'])

      parser.tag_end('component') # commit_room_objs
      expect(gameobj.npcs.map(&:id)).to eq(['2'])
    end

    it 'commits loot and npcs together and applies the deferred status line' do
      parser.tag_start('component', { 'id' => 'room objs' })
      feed_bold_a('2', 'kobold', 'a kobold')
      feed_loot_a('3', 'gem', 'a ruby')
      # Status arrives as text outside the <a>, in a later callback.
      parser.text(' that is dead.')
      parser.tag_end('component')

      expect(gameobj.npcs.map(&:id)).to eq(['2'])
      expect(gameobj.loot.map(&:id)).to eq(['3'])
      expect(gameobj['2'].status).to eq('dead')
    end

    it 'clears a stale room when the new component carries no objects' do
      gameobj.new_npc('1', 'orc', 'an orc', 'standing')
      gameobj.new_loot('9', 'gem', 'a ruby')

      parser.tag_start('component', { 'id' => 'room objs' })
      parser.tag_end('component') # empty component -> commit empty

      expect(gameobj.npcs).to be_nil
      expect(gameobj.loot).to be_nil
    end
  end

  describe "'room players' component refresh (GS)" do
    it 'swaps the pc list atomically on close' do
      gameobj.new_pc('-1', 'elf', 'an elf', 'standing')

      parser.tag_start('component', { 'id' => 'room players' }) # begin_room_players
      parser.tag_start('a', { 'exist' => '-2', 'noun' => 'dwarf' })
      parser.text('a dwarf')
      parser.tag_end('a')

      expect(gameobj.pcs.map(&:id)).to eq(['-1'])

      parser.tag_end('component') # commit_room_players
      expect(gameobj.pcs.map(&:id)).to eq(['-2'])
    end
  end

  describe "'room players' DR 'Also here' rebuild" do
    it 'swaps the pc list atomically within the single text callback' do
      gameobj.new_pc('-1', 'elf', 'an elf', 'standing') # previously published
      parser.instance_variable_set(:@game, 'DR')

      parser.tag_start('component', { 'id' => 'room players' })
      # Component open staged an (empty) refresh; published list still visible.
      expect(gameobj.pcs.map(&:name)).to eq(['an elf'])

      # The whole "Also here" line arrives in one callback: begin + fill + commit.
      parser.text('Also here: Bob, Alice')
      expect(gameobj.pcs.map(&:name)).to contain_exactly('Bob', 'Alice')

      parser.tag_end('component') # trailing commit is a no-op
      expect(gameobj.pcs.map(&:name)).to contain_exactly('Bob', 'Alice')
    end
  end

  describe "'inv' stream refresh" do
    def feed_inv_item(exist, noun, name)
      parser.tag_start('a', { 'exist' => exist, 'noun' => noun })
      parser.text(name)
      parser.tag_end('a')
    end

    it 'keeps the previous inventory visible until the stream pops' do
      gameobj.new_inv('1', 'cloak', 'a wool cloak') # previously published

      parser.tag_start('pushStream', { 'id' => 'inv' }) # begin_inv
      parser.tag_end('pushStream')
      feed_inv_item('2', 'tunic', 'a linen tunic')

      expect(gameobj.inv.map(&:id)).to eq(['1'])

      parser.tag_start('popStream', { 'id' => 'inv' }) # commit_inv
      expect(gameobj.inv.map(&:id)).to eq(['2'])
    end
  end

  describe 'container refresh (clearContainer ... inv ... prompt)' do
    # Replays one <inv id='CID'> ... </inv> container element with a single
    # item <a>, matching the live stream shape.
    def feed_container_item(cid, item_exist, item_noun, item_name)
      parser.tag_start('inv', { 'id' => cid })
      parser.tag_start('a', { 'exist' => item_exist, 'noun' => item_noun })
      parser.text(item_name)
      parser.tag_end('a')
      parser.tag_end('inv')
    end

    it 'keeps prior contents visible until the prompt commits the refresh' do
      cid = '2136851'
      gameobj.new_inv('900', 'codex', 'an old codex', cid) # previously published

      parser.tag_start('clearContainer', { 'id' => cid }) # begin_container
      parser.tag_end('clearContainer')
      feed_container_item(cid, '901', 'codex', 'a runic codex')

      # Mid-refresh: reader still sees the previous container contents.
      expect(gameobj.containers[cid].map(&:id)).to eq(['900'])

      parser.tag_start('prompt', { 'time' => '1' }) # commit_all_containers
      parser.tag_end('prompt')

      expect(gameobj.containers[cid].map(&:id)).to eq(['901'])
    end

    it 'commits multiple containers refreshed before the same prompt' do
      parser.tag_start('clearContainer', { 'id' => 'A' })
      parser.tag_end('clearContainer')
      feed_container_item('A', 'a1', 'gem', 'a ruby')
      parser.tag_start('clearContainer', { 'id' => 'B' })
      parser.tag_end('clearContainer')
      feed_container_item('B', 'b1', 'gem', 'an emerald')

      parser.tag_start('prompt', { 'time' => '1' })
      parser.tag_end('prompt')

      expect(gameobj.containers['A'].map(&:id)).to eq(['a1'])
      expect(gameobj.containers['B'].map(&:id)).to eq(['b1'])
    end
  end
end
