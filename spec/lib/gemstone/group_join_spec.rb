# frozen_string_literal: true

require_relative '../../spec_helper'

require 'gemstone/group'

# The follower's side of Group.add: JOIN a leader and read the answer.
RSpec.describe Lich::Gemstone::Group do
  GroupJoinPc = Struct.new(:id, :noun, :name) unless defined?(GroupJoinPc)

  let(:leader) { GroupJoinPc.new('-1001', 'Etanamir', 'Etanamir') }
  let(:sent) { [] }

  before do
    allow(GameObj).to receive(:pcs).and_return([leader])
  end

  def answer(line)
    allow(described_class).to receive(:dothistimeout) { |cmd, _t, _rx| sent << cmd; line }
  end

  it 'joins by noun or GameObj, sending JOIN with the id' do
    answer('You join Etanamir.')
    expect(described_class.join('Etanamir')).to eq({ ok: leader })
    expect(described_class.join(leader)).to eq({ ok: leader })
    expect(sent).to eq(['join #-1001', 'join #-1001'])
  end

  it 'reports a closed group, a missing player and no answer as errors, and already a member as a noop' do
    answer("Etanamir's group status is closed.")
    expect(described_class.join('Etanamir')).to eq({ err: leader })
    answer("You are already a member of Etanamir's group.")
    expect(described_class.join('Etanamir')).to eq({ noop: leader })
    answer(false)
    expect(described_class.join('Etanamir')).to eq({ err: leader })
    expect(described_class.join('Nobody')).to eq({ err: nil })
  end
end
