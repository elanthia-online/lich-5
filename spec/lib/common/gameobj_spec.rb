# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/common/gameobj'

RSpec.describe Lich::Common::GameObj do
  # Reset class variables before each test to ensure isolation
  before do
    described_class.clear_inv
    described_class.send(:class_variable_set, :@@contents, {})
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
end
