# frozen_string_literal: true

require_relative '../../spec_helper'
require 'gemstone/group'

RSpec.describe Lich::Gemstone::Group::Observer do
  let(:group) { Lich::Gemstone::Group }

  around do |example|
    saved = %i[@@members @@leader @@checked @@status].to_h do |key|
      [key, group.class_variable_get(key)]
    end
    example.run
  ensure
    saved.each { |key, value| group.class_variable_set(key, value) }
  end

  def observe(line)
    match = described_class.wants?(line)
    described_class.consume(line, match) if match
  end

  it 'invalidates cached membership on the ambiguous no-group disband response' do
    member = Object.new
    group.refresh(member)
    group.leader = :self
    group.checked = true

    observe('You have no group to disband.')

    expect(group._members).to eq([member])
    expect(group.leader).to eq(:self)
    expect(group.checked?).to be(false)
  end

  it 'also clears a stale follower leader on an authoritative empty-group reply' do
    old_leader = Object.new
    group.refresh(old_leader)
    group.leader = old_leader
    group.checked = true

    observe('You are not currently in a group.')

    expect(group._members).to be_empty
    expect(group.leader).to eq(:self)
  end

  it 'does not clear follower membership from the ambiguous no-group-to-disband reply' do
    leader = Object.new
    member = Object.new
    group.refresh(leader, member)
    group.leader = leader
    group.checked = true

    observe('You have no group to disband.')

    expect(group._members).to eq([leader, member])
    expect(group.leader).to equal(leader)
    expect(group.checked?).to be(false)
  end

  it 'retains the existing successful-disband and GROUP-query behavior' do
    ['You disband your group.', 'You are not currently in a group.'].each do |line|
      group.refresh(Object.new)
      group.checked = true
      observe(line)
      expect(group._members).to be_empty
      expect(group.leader).to eq(:self)
    end
  end

  it 'does not confuse group closure or quoted speech with empty membership' do
    member = Object.new
    group.refresh(member)
    group.leader = :self
    group.checked = true

    observe('Your group status is now closed.')
    observe('Someone says, "You have no group to disband."')

    expect(group._members).to eq([member])
  end
end
