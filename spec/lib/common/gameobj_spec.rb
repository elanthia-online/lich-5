# frozen_string_literal: true

require_relative '../../spec_helper'
require 'tmpdir'
require 'rexml/document'
require_relative '../../../lib/common/gameobj'

RSpec.describe Lich::Common::GameObj do
  before do
    # NOTE: class_variable_set used because GameObj is a production class with no reset! method
    %i[@@loot @@npcs @@npc_status @@pcs @@pc_status @@inv @@room_desc
       @@fam_loot @@fam_npcs @@fam_pcs @@fam_room_desc @@index @@type_cache @@contents].each do |cv|
      described_class.class_variable_get(cv).clear if described_class.class_variable_defined?(cv)
    end
    described_class.class_variable_set(:@@right_hand, nil)
    described_class.class_variable_set(:@@left_hand, nil)
    described_class.class_variable_set(:@@reserve, nil)

    described_class.new_right_hand('r1', 'empty', 'Empty')
    described_class.new_left_hand('l1', 'empty', 'Empty')

    XMLData.singleton_class.class_eval do
      attr_accessor :current_target_ids, :current_target_id
    end
    XMLData.current_target_ids = []
    XMLData.current_target_id = nil

    allow(described_class).to receive(:respond)
    allow(described_class).to receive(:echo)
    allow(Lich).to receive(:log)
  end

  describe '.new_inv' do
    let(:item_id) { '12345' }
    let(:item_noun) { 'pouch' }
    let(:item_name) { 'red gem pouch' }
    let(:container_id) { '67890' }
    let(:before_name) { 'get #12345 in #67890' }
    let(:after_name) { nil }

    context 'when container is nil (item not in a container)' do
      it 'adds the item to @@inv' do
        obj = described_class.new_inv(item_id, item_noun, item_name)

        expect(described_class.inv).to include(obj)
        expect(obj.id).to eq(item_id)
        expect(obj.noun).to eq(item_noun)
        expect(obj.name).to eq(item_name)
      end

      it 'does not add to @@contents' do
        described_class.new_inv(item_id, item_noun, item_name)

        expect(described_class.containers).to be_empty
      end
    end

    context 'when container is specified' do
      it 'adds the item to the container in @@contents' do
        obj = described_class.new_inv(item_id, item_noun, item_name, container_id)

        containers = described_class.containers
        expect(containers).to have_key(container_id)
        expect(containers[container_id]).to include(obj)
      end

      it 'does not add to @@inv' do
        described_class.new_inv(item_id, item_noun, item_name, container_id)

        expect(described_class.inv).to be_nil
      end

      it 'initializes the container array if it does not exist' do
        # This is the bug fix test - previously this would fail silently
        # because @@contents[container_id] was nil and nil.push() did nothing
        obj = described_class.new_inv(item_id, item_noun, item_name, container_id)

        containers = described_class.containers
        expect(containers[container_id]).to be_an(Array)
        expect(containers[container_id]).to contain_exactly(obj)
      end

      it 'appends to existing container array' do
        first_obj = described_class.new_inv('111', 'gem', 'ruby', container_id)
        second_obj = described_class.new_inv('222', 'gem', 'sapphire', container_id)

        containers = described_class.containers
        expect(containers[container_id]).to contain_exactly(first_obj, second_obj)
      end

      it 'stores items in separate containers correctly' do
        container_a = 'container_a'
        container_b = 'container_b'

        obj_a = described_class.new_inv('111', 'gem', 'ruby', container_a)
        obj_b = described_class.new_inv('222', 'gem', 'sapphire', container_b)

        containers = described_class.containers
        expect(containers[container_a]).to contain_exactly(obj_a)
        expect(containers[container_b]).to contain_exactly(obj_b)
      end
    end

    context 'with before_name and after_name' do
      it 'stores before_name on the object' do
        obj = described_class.new_inv(item_id, item_noun, item_name, container_id, before_name)

        expect(obj.before_name).to eq(before_name)
      end

      it 'stores after_name on the object' do
        obj = described_class.new_inv(item_id, item_noun, item_name, container_id, before_name, 'after text')

        expect(obj.after_name).to eq('after text')
      end
    end

    context 'with integer id' do
      it 'converts integer id to string' do
        obj = described_class.new_inv(12345, item_noun, item_name)

        expect(obj.id).to eq('12345')
      end
    end
  end

  describe '.containers' do
    it 'returns a duplicate of @@contents' do
      described_class.new_inv('123', 'gem', 'ruby', 'container1')

      containers = described_class.containers
      containers['container1'] = []

      # Original should not be affected
      expect(described_class.containers['container1']).not_to be_empty
    end
  end

  describe '.clear_inv' do
    it 'clears the @@inv array' do
      described_class.new_inv('123', 'gem', 'ruby')
      expect(described_class.inv).not_to be_nil

      described_class.clear_inv
      expect(described_class.inv).to be_nil
    end

    it 'does not clear @@contents' do
      described_class.new_inv('123', 'gem', 'ruby', 'container1')

      described_class.clear_inv

      expect(described_class.containers).to have_key('container1')
    end
  end

  describe '.new_reserve' do
    let(:item_id)   { '279838' }
    let(:item_noun) { 'lilac' }
    let(:item_name) { 'sprig of wild lilac' }

    it 'adds the item to @@reserve' do
      obj = described_class.new_reserve(item_id, item_noun, item_name)

      expect(described_class.reserve).to include(obj)
      expect(obj.id).to eq(item_id)
      expect(obj.noun).to eq(item_noun)
      expect(obj.name).to eq(item_name)
    end

    it 'initializes @@reserve from nil on first call' do
      expect(described_class.reserve).to be_nil

      described_class.new_reserve(item_id, item_noun, item_name)

      expect(described_class.reserve).to be_an(Array)
    end

    it 'appends multiple items' do
      first  = described_class.new_reserve('1', 'herb', 'golden herb')
      second = described_class.new_reserve('2', 'potion', 'blue potion')

      expect(described_class.reserve).to contain_exactly(first, second)
    end

    it 'converts integer id to string' do
      obj = described_class.new_reserve(279838, item_noun, item_name)

      expect(obj.id).to eq('279838')
    end
  end

  describe '.reserve' do
    it 'returns nil when @@reserve has never been seen' do
      expect(described_class.reserve).to be_nil
    end

    it 'returns a duplicate so mutations do not affect the registry' do
      obj = described_class.new_reserve('1', 'herb', 'golden herb')

      copy = described_class.reserve
      copy.clear

      expect(described_class.reserve).to include(obj)
    end
  end

  describe '.clear_reserve' do
    it 'initializes @@reserve to [] even when never seen' do
      expect(described_class.reserve).to be_nil

      described_class.clear_reserve

      expect(described_class.reserve).to eq([])
    end

    it 'empties @@reserve when it already has items' do
      described_class.new_reserve('1', 'herb', 'golden herb')
      expect(described_class.reserve).not_to be_nil

      described_class.clear_reserve

      expect(described_class.reserve).to eq([])
    end

    it 'allows new items to be added after clearing' do
      described_class.new_reserve('1', 'herb', 'golden herb')
      described_class.clear_reserve

      obj = described_class.new_reserve('2', 'potion', 'blue potion')

      expect(described_class.reserve).to contain_exactly(obj)
    end
  end

  describe '.clear_container' do
    it 'resets the specified container to an empty array' do
      described_class.new_inv('123', 'gem', 'ruby', 'container1')
      expect(described_class.containers['container1']).not_to be_empty

      described_class.clear_container('container1')

      expect(described_class.containers['container1']).to eq([])
    end
  end

  describe '.delete_container' do
    it 'removes the specified container from @@contents' do
      described_class.new_inv('123', 'gem', 'ruby', 'container1')
      expect(described_class.containers).to have_key('container1')

      described_class.delete_container('container1')

      expect(described_class.containers).not_to have_key('container1')
    end
  end

  describe '.clear_all_containers' do
    it 'clears all containers from @@contents' do
      described_class.new_inv('123', 'gem', 'ruby', 'container1')
      described_class.new_inv('456', 'gem', 'sapphire', 'container2')
      expect(described_class.containers.keys).to contain_exactly('container1', 'container2')

      described_class.clear_all_containers

      expect(described_class.containers).to be_empty
    end

    it 'does not affect @@inv' do
      described_class.new_inv('111', 'gem', 'diamond')
      described_class.new_inv('123', 'gem', 'ruby', 'container1')
      expect(described_class.inv).not_to be_nil

      described_class.clear_all_containers

      expect(described_class.inv).not_to be_nil
    end

    it 'allows new containers to be added after clearing' do
      described_class.new_inv('123', 'gem', 'ruby', 'container1')
      described_class.clear_all_containers

      obj = described_class.new_inv('456', 'gem', 'sapphire', 'container2')

      expect(described_class.containers).to have_key('container2')
      expect(described_class.containers['container2']).to include(obj)
    end
  end

  describe '.inv' do
    it 'returns nil when @@inv is empty' do
      expect(described_class.inv).to be_nil
    end

    it 'returns a duplicate of @@inv when not empty' do
      obj = described_class.new_inv('123', 'gem', 'ruby')

      inv = described_class.inv
      expect(inv).to include(obj)
    end
  end

  describe 'additional collection and lookup behavior' do
    it 'creates npc and stores initial status' do
      npc = described_class.new_npc('10', 'orc', 'an orc', 'stunned')

      expect(described_class.npcs.map(&:id)).to include('10')
      expect(npc.status).to eq('stunned')
    end

    it 'creates pc and supports status updates via #status=' do
      pc = described_class.new_pc('20', 'human', 'a human', 'standing')
      pc.status = 'webbed'

      expect(pc.status).to eq('webbed')
    end

    it 'returns nil for empty loot and duplicate for populated loot' do
      expect(described_class.loot).to be_nil

      described_class.new_loot('30', 'gem', 'a ruby')
      copy = described_class.loot
      copy.clear

      expect(described_class.loot.map(&:id)).to eq(['30'])
    end

    it 'returns duplicate hand objects from right_hand/left_hand readers' do
      described_class.new_right_hand('41', 'sword', 'a longsword')
      described_class.new_left_hand('42', 'shield', 'a shield')

      right = described_class.right_hand
      left = described_class.left_hand
      right.name = 'changed'
      left.name = 'changed'

      expect(described_class.right_hand.name).to eq('a longsword')
      expect(described_class.left_hand.name).to eq('a shield')
    end
  end

  describe '.[] lookup semantics' do
    before do
      described_class.new_inv('101', 'coin', 'a silver coin')
      described_class.new_loot('102', 'gem', 'a bright ruby')
      described_class.new_npc('103', 'orc', 'a cave orc')
      described_class.new_pc('104', 'elf', 'a tall elf')
      described_class.new_room_desc('105', 'statue', 'an obsidian statue')
      described_class.new_inv('106', 'box', 'small wooden box')
    end

    it 'finds by numeric string id' do
      expect(described_class['103']&.name).to eq('a cave orc')
    end

    it 'coerces integer id to string and continues lookup' do
      expect(described_class[104]&.name).to eq('a tall elf')
      expect(described_class).to have_received(:respond).with(/converted Integer 104 to String/)
    end

    it 'finds by noun lookup for single-token query' do
      expect(described_class['gem']&.id).to eq('102')
    end

    it 'finds by exact name and fallback suffix pattern' do
      expect(described_class['a bright ruby']&.id).to eq('102')
      expect(described_class['bright ruby']&.id).to eq('102')
    end

    it 'finds by regexp name lookup' do
      expect(described_class[/obsidian/]&.id).to eq('105')
    end

    it 'returns nil and logs errors for unsupported non-integer type' do
      expect(described_class[:bad]).to be_nil
      expect(described_class).to have_received(:respond).with(/supports String or Regexp only/)
      expect(Lich).to have_received(:log).with(/supports String or Regexp only/)
    end
  end

  describe 'status and target behavior' do
    it 'returns nil for known object without explicit status and gone for missing object' do
      obj = described_class.new_loot('201', 'coin', 'a coin')
      missing = described_class.new('999', 'rock', 'a rock')

      expect(obj.status).to be_nil
      expect(missing.status).to eq('gone')
    end

    it 'updates status only for npcs/pcs and ignores other objects' do
      npc = described_class.new_npc('202', 'orc', 'an orc')
      loot = described_class.new_loot('203', 'gem', 'a gem')

      npc.status = 'dead'
      loot.status = 'dead'

      expect(npc.status).to eq('dead')
      expect(loot.status).to be_nil
    end

    it 'returns duplicated container contents from instance #contents' do
      item = described_class.new_inv('204', 'gem', 'a sapphire', 'bag-1')
      bag = described_class.new('bag-1', 'bag', 'a canvas bag')

      duped = bag.contents
      duped.clear

      expect(item.id).to eq('204')
      expect(described_class.containers['bag-1'].map(&:id)).to eq(['204'])
    end

    it 'returns only valid visible targets with filter rules applied' do
      described_class.new_npc('301', 'orc', 'a cave orc', 'standing')
      described_class.new_npc('302', 'orc', 'animated guardian', 'standing')
      described_class.new_npc('303', 'tentacle', 'a kraken tentacle', 'standing')
      described_class.new_npc('304', 'tentacle', 'an ancient kraken tentacle', 'standing')
      described_class.new_npc('305', 'orc', 'a fallen orc', 'dead')
      XMLData.current_target_ids = %w[301 302 303 304 305 999]

      ids = described_class.targets.map(&:id)
      expect(ids).to contain_exactly('301', '304')
    end

    it 'returns non-present target ids as hidden_targets' do
      described_class.new_npc('301', 'orc', 'a cave orc', 'standing')
      XMLData.current_target_ids = %w[301 999 998]

      expect(described_class.hidden_targets).to contain_exactly('999', '998')
    end

    it 'resolves .target from npcs and pcs by current_target_id' do
      described_class.new_npc('301', 'orc', 'a cave orc', 'standing')
      described_class.new_pc('399', 'elf', 'an elf', 'standing')

      XMLData.current_target_id = '301'
      expect(described_class.target&.name).to eq('a cave orc')

      XMLData.current_target_id = '399'
      expect(described_class.target&.name).to eq('an elf')
    end

    it 'returns nil for dead when none, then returns only dead npcs when present' do
      described_class.new_npc('401', 'orc', 'an orc', 'standing')
      expect(described_class.dead).to be_nil

      dead = described_class.new_npc('402', 'orc', 'a corpse', 'dead')
      expect(described_class.dead.map(&:id)).to eq([dead.id])
    end
  end

  describe 'type/sellable loading behavior' do
    let(:base_xml) do
      <<~XML
        <data>
          <type name="weapon">
            <name>sword|blade</name>
            <noun>sword</noun>
            <exclude>toy</exclude>
          </type>
          <sellable name="gem">
            <name>ruby|sapphire</name>
            <noun>gem</noun>
            <exclude></exclude>
          </sellable>
        </data>
      XML
    end

    let(:custom_xml) do
      <<~XML
        <data>
          <type name="weapon">
            <name>dagger</name>
            <noun></noun>
            <exclude></exclude>
          </type>
          <sellable name="gem">
            <name></name>
            <noun></noun>
            <exclude>fake</exclude>
          </sellable>
        </data>
      XML
    end

    it 'loads base xml, merges custom xml, and supports type/sellable matching' do
      Dir.mktmpdir do |dir|
        base_file = File.join(dir, 'base.xml')
        custom_dir = File.join(dir, 'gameobj-custom')
        custom_file = File.join(custom_dir, 'gameobj-data.xml')

        File.write(base_file, base_xml)
        Dir.mkdir(custom_dir)
        File.write(custom_file, custom_xml)
        stub_const('DATA_DIR', dir)

        expect(described_class.load_data(base_file)).to be(true)

        sword = described_class.new('501', 'sword', 'a steel sword')
        dagger = described_class.new('502', 'knife', 'a sharp dagger')
        toy = described_class.new('503', 'sword', 'a toy sword')
        gem = described_class.new('504', 'gem', 'a sapphire')
        fake = described_class.new('505', 'gem', 'a fake sapphire')

        expect(sword.type).to include('weapon')
        expect(dagger.type).to include('weapon')
        expect(toy.type).to be_nil
        expect(gem.sellable).to include('gem')
        expect(fake.sellable).to be_nil
      end
    end

    it 'preserves verbatim whitespace in classification regexes' do
      # type/name patterns are compiled to regexes and matched against the
      # object name. The loader must not collapse the double space, or an item
      # whose name has two spaces would stop classifying (regression guard for
      # the REXML -> Ox conversion: Ox collapses whitespace unless told not to).
      Dir.mktmpdir do |dir|
        base_file = File.join(dir, 'base.xml')
        # noun is a non-matching value so this asserts purely on the name regex
        File.write(base_file, "<data><type name=\"pole\"><name>war  blade</name><noun>halberd</noun></type></data>")
        stub_const('DATA_DIR', dir)

        expect(described_class.load_data(base_file)).to be(true)
        expect(described_class.type_data['pole'][:name].source).to eq('war  blade')
        expect(described_class.new('601', 'staff', 'a war  blade').type).to include('pole')
        expect(described_class.new('602', 'staff', 'a war blade').type).to be_nil
      end
    end

    it 'caches type results by object name in type_cache' do
      Dir.mktmpdir do |dir|
        base_file = File.join(dir, 'base.xml')
        File.write(base_file, base_xml)
        stub_const('DATA_DIR', dir)

        expect(described_class.load_data(base_file)).to be(true)
        obj = described_class.new('506', 'sword', 'a steel sword')

        expect(obj.type).to eq('weapon')
        expect(described_class.type_cache['a steel sword']).to eq('weapon')
      end
    end

    it 'returns false and reports when base file is missing' do
      stub_const('DATA_DIR', Dir.mktmpdir)

      expect(described_class.load_data('/definitely/missing.xml')).to be(false)
      expect(described_class).to have_received(:echo).with(/file does not exist/)
    end

    it 'returns false when xml is malformed' do
      Dir.mktmpdir do |dir|
        file = File.join(dir, 'bad.xml')
        File.write(file, '<data><type name="x"><name>oops</data>')
        stub_const('DATA_DIR', dir)

        expect(described_class.load_data(file)).to be(false)
        expect(described_class).to have_received(:echo).with(/GameObj\.load_data/)
      end
    end

    it 'reload delegates to load_data with filename' do
      expect(described_class).to receive(:load_data).with('custom.xml')
      described_class.reload('custom.xml')
    end

    it 'merge_data unions regexes and passes through non-regex' do
      a = /sword/
      b = /dagger/

      expect(described_class.merge_data(a, b)).to be_a(Regexp)
      expect(described_class.merge_data(nil, b)).to eq(b)
    end
  end

  describe 'GameObj instance' do
    describe '#initialize' do
      it 'sets id, noun, name, before_name, after_name' do
        obj = described_class.new('123', 'gem', 'ruby', 'before', 'after')

        expect(obj.id).to eq('123')
        expect(obj.noun).to eq('gem')
        expect(obj.name).to eq('ruby')
        expect(obj.before_name).to eq('before')
        expect(obj.after_name).to eq('after')
      end

      it 'converts lapis lazuli noun to lapis' do
        obj = described_class.new('123', 'lapis lazuli', 'blue lapis lazuli')

        expect(obj.noun).to eq('lapis')
      end

      it 'converts Hammer of Kai noun to hammer' do
        obj = described_class.new('123', 'Hammer of Kai', 'some hammer')

        expect(obj.noun).to eq('hammer')
      end

      it 'converts ball and chain noun to ball' do
        obj = described_class.new('123', 'ball and chain', 'iron ball')

        expect(obj.noun).to eq('ball')
      end
    end

    describe '#full_name' do
      it 'returns name when before_name and after_name are nil' do
        obj = described_class.new('123', 'gem', 'ruby')

        expect(obj.full_name).to eq('ruby')
      end

      it 'includes before_name with space' do
        obj = described_class.new('123', 'gem', 'ruby', 'a')

        expect(obj.full_name).to eq('a ruby')
      end

      it 'includes after_name with space' do
        obj = described_class.new('123', 'gem', 'ruby', nil, '(glowing)')

        expect(obj.full_name).to eq('ruby (glowing)')
      end

      it 'includes both before_name and after_name' do
        obj = described_class.new('123', 'gem', 'ruby', 'a', '(glowing)')

        expect(obj.full_name).to eq('a ruby (glowing)')
      end
    end

    describe '#to_s' do
      it 'returns the noun' do
        obj = described_class.new('123', 'gem', 'ruby')

        expect(obj.to_s).to eq('gem')
      end
    end

    describe '#empty?' do
      it 'returns false' do
        obj = described_class.new('123', 'gem', 'ruby')

        expect(obj.empty?).to be false
      end
    end
  end

  # Pruning is driven off the game thread by Lich::Util::MemoryReleaser, which
  # calls prune_index! periodically; there is no insert-path auto-prune.
  describe '.prune_index!' do
    let(:index) { described_class.class_variable_get(:@@index) }

    before do
      # The outer before seeds two hand objects into the index; start from a
      # clean, empty index so entry counts in these examples are exact.
      index.clear
      described_class.class_variable_set(:@@right_hand, nil)
      described_class.class_variable_set(:@@left_hand, nil)
    end

    it 'removes stale, non-live entries and keeps live ones' do
      150.times { |i| described_class.new_npc((800_000 + i).to_s, 'wraith', "wraith #{i}") }
      described_class.clear_npcs # 150 stale entries left in the index
      120.times { |i| described_class.new_npc((900_000 + i).to_s, 'ghost', "ghost #{i}") } # live

      result = described_class.prune_index!(ttl: 0) # ttl 0 -> everything stale by age

      expect(result[:pruned]).to eq(150)
      expect(index.size).to eq(120) # the live ghosts survive
    end

    it 'never prunes an entry that is still live in a registry, regardless of age' do
      keeper = described_class.new_npc('123456', 'guardian', 'a stone guardian')

      result = described_class.prune_index!(ttl: 0)

      key = '123456|guardian|a stone guardian'
      expect(index.key?(key)).to be true
      expect(index[key].first).to equal(keeper)
      expect(result[:skipped_live]).to be >= 1
    end

    it 'prunes a stale variant even when a different-name entry shares its id' do
      # The same exist-id is seen first under one name (then cleared, so it goes
      # stale) and again under a different name that stays live. The live guard
      # keys on object identity, not id, so the stale variant - a distinct
      # instance held in no registry - must still be evicted even though a live
      # sibling shares its id. (An id-based guard would wrongly keep it.)
      described_class.new_npc('555', 'kobold', 'a kobold')
      described_class.clear_npcs # 'a kobold' entry is now stale, not live
      live = described_class.new_npc('555', 'kobold', 'a snarling kobold')

      described_class.prune_index!(ttl: 0)

      expect(index).not_to have_key('555|kobold|a kobold') # stale variant evicted
      expect(index['555|kobold|a snarling kobold'].first).to equal(live) # live sibling kept
    end
  end

  describe 'staged registry refresh (begin_*/commit_*)' do
    describe 'inv staging' do
      it 'keeps the previous snapshot visible until commit' do
        first = described_class.new_inv('1', 'gem', 'a ruby')
        expect(described_class.inv.map(&:id)).to eq(['1'])

        described_class.begin_inv
        described_class.new_inv('2', 'gem', 'a sapphire')

        # Mid-refresh: readers still see the prior complete snapshot, not the
        # half-built staging buffer.
        expect(described_class.inv.map(&:id)).to eq([first.id])

        described_class.commit_inv
        expect(described_class.inv.map(&:id)).to eq(['2'])
      end

      it 'never returns nil during a refresh that started from a populated registry' do
        described_class.new_inv('1', 'gem', 'a ruby')

        described_class.begin_inv
        # No items added yet this stream.
        expect(described_class.inv).not_to be_nil
        expect(described_class.inv.map(&:id)).to eq(['1'])

        described_class.commit_inv
      end

      it 'publishes an empty registry when the staged stream had no items' do
        described_class.new_inv('1', 'gem', 'a ruby')

        described_class.begin_inv
        described_class.commit_inv

        expect(described_class.inv).to be_nil
      end

      it 'commit is a no-op when no refresh was opened' do
        described_class.new_inv('1', 'gem', 'a ruby')

        described_class.commit_inv

        expect(described_class.inv.map(&:id)).to eq(['1'])
      end

      it 'reuses the same instance across a refresh via the shared index' do
        first = described_class.new_inv('1', 'gem', 'a ruby')

        described_class.begin_inv
        restaged = described_class.new_inv('1', 'gem', 'a ruby')
        described_class.commit_inv

        expect(restaged).to be(first)
      end
    end

    describe 'reserve staging' do
      it 'keeps the previous snapshot visible until commit' do
        described_class.new_reserve('1', 'herb', 'a sprig')
        described_class.begin_reserve
        described_class.new_reserve('2', 'herb', 'another sprig')

        expect(described_class.reserve.map(&:id)).to eq(['1'])

        described_class.commit_reserve
        expect(described_class.reserve.map(&:id)).to eq(['2'])
      end
    end

    describe 'room objs staging' do
      it 'swaps loot, npcs and npc status atomically' do
        described_class.new_npc('10', 'orc', 'an orc', 'standing')
        described_class.new_loot('11', 'gem', 'a ruby')

        described_class.begin_room_objs
        described_class.new_npc('20', 'kobold', 'a kobold', 'stunned')

        # Old room still visible mid-refresh.
        expect(described_class.npcs.map(&:id)).to eq(['10'])
        expect(described_class.loot.map(&:id)).to eq(['11'])

        described_class.commit_room_objs
        expect(described_class.npcs.map(&:id)).to eq(['20'])
        expect(described_class.loot).to be_nil
        expect(described_class['20'].status).to eq('stunned')
      end

      it 'applies a deferred status= to the staged npc and survives commit' do
        described_class.begin_room_objs
        npc = described_class.new_npc('20', 'kobold', 'a kobold')

        # Mirrors xmlparser setting status on the just-created npc in a later
        # text callback, while the refresh is still open.
        npc.status = 'dead'

        described_class.commit_room_objs
        expect(described_class['20'].status).to eq('dead')
      end

      it 'an empty room objs stream clears stale npcs and loot on commit' do
        described_class.new_npc('10', 'orc', 'an orc', 'standing')
        described_class.new_loot('11', 'gem', 'a ruby')

        described_class.begin_room_objs
        described_class.commit_room_objs

        expect(described_class.npcs).to be_nil
        expect(described_class.loot).to be_nil
      end
    end

    describe 'room players staging' do
      it 'swaps pcs and pc status atomically' do
        described_class.new_pc('30', 'elf', 'an elf', 'standing')

        described_class.begin_room_players
        described_class.new_pc('31', 'dwarf', 'a dwarf', 'sitting')

        expect(described_class.pcs.map(&:id)).to eq(['30'])

        described_class.commit_room_players
        expect(described_class.pcs.map(&:id)).to eq(['31'])
        expect(described_class['31'].status).to eq('sitting')
      end
    end

    describe 'room desc staging' do
      it 'keeps the previous snapshot visible until commit' do
        described_class.new_room_desc('40', 'statue', 'a statue')

        described_class.begin_room_desc
        described_class.new_room_desc('41', 'fountain', 'a fountain')

        expect(described_class.room_desc.map(&:id)).to eq(['40'])

        described_class.commit_room_desc
        expect(described_class.room_desc.map(&:id)).to eq(['41'])
      end
    end

    describe 'familiar staging' do
      it 'swaps all four familiar registries atomically' do
        described_class.new_fam_npc('50', 'orc', 'an orc')
        described_class.new_fam_loot('51', 'gem', 'a ruby')

        described_class.begin_familiar
        described_class.new_fam_npc('60', 'troll', 'a troll')

        expect(described_class.fam_npcs.map(&:id)).to eq(['50'])
        expect(described_class.fam_loot.map(&:id)).to eq(['51'])

        described_class.commit_familiar
        expect(described_class.fam_npcs.map(&:id)).to eq(['60'])
        expect(described_class.fam_loot).to be_nil
      end
    end

    describe 'container staging' do
      it 'keeps the previous container contents visible until commit' do
        described_class.new_inv('70', 'gem', 'a ruby', 'bag-1')

        described_class.begin_container('bag-1')
        described_class.new_inv('71', 'gem', 'a sapphire', 'bag-1')

        expect(described_class.containers['bag-1'].map(&:id)).to eq(['70'])

        described_class.commit_container('bag-1')
        expect(described_class.containers['bag-1'].map(&:id)).to eq(['71'])
      end

      it 'commit_all_containers publishes every open buffer at once' do
        described_class.begin_container('bag-1')
        described_class.new_inv('71', 'gem', 'a sapphire', 'bag-1')
        described_class.begin_container('bag-2')
        described_class.new_inv('72', 'gem', 'an emerald', 'bag-2')

        described_class.commit_all_containers

        expect(described_class.containers['bag-1'].map(&:id)).to eq(['71'])
        expect(described_class.containers['bag-2'].map(&:id)).to eq(['72'])
      end

      it 'commit_all_containers is a no-op when nothing is staged' do
        described_class.new_inv('70', 'gem', 'a ruby', 'bag-1')

        expect { described_class.commit_all_containers }.not_to(change { described_class.containers })
      end

      it 'delete_container aborts an open refresh so commit cannot resurrect the key' do
        described_class.new_inv('70', 'gem', 'a ruby', 'bag-1')

        described_class.begin_container('bag-1')
        described_class.delete_container('bag-1')
        described_class.commit_all_containers

        expect(described_class.containers).not_to have_key('bag-1')
      end

      it 'clear_all_containers aborts open refreshes too' do
        described_class.begin_container('bag-1')
        described_class.new_inv('71', 'gem', 'a sapphire', 'bag-1')

        described_class.clear_all_containers
        described_class.commit_all_containers

        expect(described_class.containers).to be_empty
      end
    end

    describe 'prune safety during a refresh' do
      it 'never prunes an object held only in an open staging buffer' do
        described_class.begin_room_objs
        staged = described_class.new_npc('80', 'wraith', 'a wraith')

        # Aggressive prune (everything older than 0s is stale) must still skip
        # the in-flight staged object.
        described_class.prune_index!(ttl: 0)

        described_class.commit_room_objs
        expect(described_class.npcs.map(&:id)).to eq([staged.id])
        expect(described_class['80']).to be(staged)
      end
    end
  end
end
