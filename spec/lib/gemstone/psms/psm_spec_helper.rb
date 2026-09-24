# frozen_string_literal: true

# Shared setup for the PSM category specs: loads the PSM modules with the
# Infomon, Status, creature and combat definitions they read, and provides
# game-state helpers plus the table invariants every category must hold.

require_relative '../../../spec_helper'

load_spell_data

require 'util/util'
require 'gemstone/psms'
require 'gemstone/overwatch'
require 'gemstone/infomon'
require 'gemstone/infomon/status'
require 'gemstone/creature'
require 'gemstone/combat/defs/attacks'
require 'gemstone/combat/defs/assaults'
require 'gemstone/combat/parser'
require 'attributes/skills'

# psms.rb reads MOC ranks through an unqualified Skills.
Skills = Lich::Gemstone::Skills unless defined?(Skills)

module Kernel
  def dothistimeout(_action, _timeout, _success_line); end unless method_defined?(:dothistimeout)
end

# The spec GameObj keeps its id but does not read it back; production does.
class PsmSpecTarget < GameObj
  attr_reader :id
end

module PsmSpecHelpers
  REPLAY_DIR = File.expand_path('../../../fixtures/replay', __dir__)

  def orc
    PsmSpecTarget.new('12345', 'orc', 'an orc')
  end

  # Sets the listed effects active (ten minutes left) in an Effects dialog,
  # replacing whatever it held.
  def effects(kind, *names)
    XMLData.save_dialogs(kind, names.to_h { |n| [n, Time.now.to_f + 600] })
  end

  # Writes Infomon ranks (e.g. 'cman.bullrush' => 2).
  def ranks(ranks)
    Lich::Gemstone::Infomon.setup!
    ranks.each { |key, rank| Lich::Gemstone::Infomon.set(key, rank) }
    Lich::Gemstone::Infomon.flush
  end

  # A game line as a script sees it: XML tags stripped.
  def plain(line)
    line.gsub(/<[^>]+>/, '')
  end

  # The first line of a replay fixture (lifted from a real session log) that
  # matches +pattern+, XML stripped.
  def replay_line(fixture, pattern)
    File.readlines(File.join(REPLAY_DIR, "#{fixture}.txt"), chomp: true)
        .map { |line| plain(line) }
        .find { |line| line.match?(pattern) } || raise("no #{pattern.inspect} line in replay/#{fixture}.txt")
  end

  # Scripts the game's answers to PSM commands: each dothistimeout returns the
  # next reply. Returns the list the sent commands are recorded in.
  def game_replies(*replies)
    sent = []
    allow(Lich::Gemstone::PSMS).to receive(:dothistimeout) do |cmd, _timeout, _regex|
      sent << cmd
      replies.shift || false
    end
    sent
  end

  # The name the combat parser gives the attack in a line, so a sample line
  # is only trusted when combat's log-derived definitions recognize it too.
  def combat_attack(line)
    Lich::Gemstone::Combat::Parser.parse_attack(line)&.dig(:name)
  end
end

RSpec.shared_context 'psm game state' do
  include PsmSpecHelpers

  before do
    Lich::Gemstone::Infomon.setup!
    Lich::Gemstone::Infomon.set('skill.multi_opponent_combat', 0)
    Lich::Gemstone::Infomon.flush
    XMLData.stamina = 100
    %w[Buffs Debuffs Cooldowns].each { |kind| effects(kind) }
    allow(Script).to receive(:current).and_return(double('Script', name: 'test_script'))
  end
end

# The invariants every category's technique table holds, checked entry by
# entry. +verb+ is the category's command verb; +shared_short_names+ lists
# short names deliberately shared by more than one entry.
RSpec.shared_examples 'a PSM technique table' do |category, verb:, shared_short_names: []|
  include_context 'psm game state'

  table = category.instance_variable_get(:@table)
  type_prefix = category.name.split('::').last.downcase

  it 'has techniques' do
    expect(table).not_to be_empty
  end

  it 'keys every technique by its normalized long name' do
    table.each_key { |long_name| expect(Lich::Gemstone::PSMS.name_normal(long_name)).to eq(long_name) }
  end

  it 'gives every technique a short name, a known type, a cost and a result regex' do
    table.each do |long_name, psm|
      expect(psm[:short_name]).to match(/\A[a-z]+\z/), "#{long_name} short name #{psm[:short_name].inspect}"
      expect(%i[passive setup attack area_of_effect assault buff concentration martial_stance reaction]).to include(psm[:type]), "#{long_name} type"
      expect(psm[:regex]).to be_a(Regexp), "#{long_name} regex"
    end
  end

  it 'prices every technique in whole, non-negative stamina or mana' do
    table.each do |long_name, psm|
      %i[cost cooldown_cost target_cost].each do |key|
        next unless psm.key?(key)

        expect(psm[key]).to be_a(Hash).and(satisfy { |c| !c.empty? }), "#{long_name} #{key}"
        psm[key].each do |resource, amount|
          expect(%i[stamina mana]).to include(resource), "#{long_name} #{key} resource"
          expect(amount).to be_a(Integer).and(be >= 0), "#{long_name} #{key} amount"
        end
      end
    end
  end

  it 'makes passive techniques free' do
    table.each { |long_name, psm| expect(psm[:cost].values).to all(be_zero), long_name if psm[:type] == :passive }
  end

  it 'keeps short names unique' do
    duplicates = table.values.map { |psm| psm[:short_name] }.tally.select { |_, n| n > 1 }.keys
    expect(duplicates).to match_array(shared_short_names)
  end

  it 'uses the short name as the command word, or nil for techniques that cannot be used' do
    table.each do |long_name, psm|
      expect(psm[:usage]).to eq(psm[:short_name]).or(be_nil), long_name if psm.key?(:usage)
    end
  end

  it 'finds every technique by long name, short name, spaced title case and symbol' do
    table.each do |long_name, psm|
      titled = long_name.split('_').map(&:capitalize).join(' ')
      [long_name, titled, long_name.to_sym].each do |name|
        expect(category.technique(name)).to equal(psm), "#{category}.technique(#{name.inspect})"
      end
      # a shared short name resolves to the first of the techniques sharing it
      expect(category.technique(psm[:short_name])[:short_name]).to eq(psm[:short_name])
      expect(category.technique(psm[:short_name])).to equal(psm) unless shared_short_names.include?(psm[:short_name])
    end
  end

  it 'lists every technique in its lookups' do
    expect(category.lookups.map { |l| l[:long_name] }).to eq(table.keys)
    expect(category.public_send("#{type_prefix}_lookups")).to eq(category.lookups)
  end

  it 'reads every rank from Infomon, by long name, short name and getter' do
    long_name, psm = table.first
    ranks("#{type_prefix}.#{psm[:short_name]}" => 3)
    expect(category[long_name]).to eq(3)
    expect(category[psm[:short_name]]).to eq(3)
    expect(category.public_send(long_name)).to eq(3)
    expect(category.public_send(psm[:short_name])).to eq(3)
    expect(category.known?(long_name, min_rank: 3)).to be(true)
    expect(category.known?(long_name, min_rank: 4)).to be(false)
  end

  it 'builds each usable technique command from its verb and usage word' do
    table.each do |long_name, psm|
      usage = psm.key?(:usage) ? psm[:usage] : psm[:short_name]
      next if usage.nil?

      expect(category.command(long_name, orc)).to end_with("#{usage} #12345")
      expect(category.command(long_name)).to start_with(verb).or(eq(usage)) if verb
    end
  end

  it 'answers nil and sends nothing for techniques that cannot be used' do
    unusable = table.select { |_, psm| psm.key?(:usage) && psm[:usage].nil? }
    next if unusable.empty?

    sent = game_replies
    unusable.each do |long_name, psm|
      ranks("#{type_prefix}.#{psm[:short_name]}" => 1)
      expect(category.command(long_name)).to be_nil
      expect(category.use(long_name)).to be_nil
    end
    expect(sent).to be_empty
  end

  it "hears each technique's refusals, roundtime and the shared failures" do
    table.each_key do |long_name|
      regex = category.results_regex(long_name)
      expect(regex).to match("#{long_name} what?")
      expect(regex).to match("#{long_name} is still in cooldown.")
      expect(regex).to match('...wait 2 seconds.')
      expect(regex).to match('You are still stunned.')
    end
  end

  it 'rejects an unknown technique name' do
    expect { category.technique('no_such_technique') }
      .to raise_error(ArgumentError, /The referenced #{category.name.split('::').last} skill no_such_technique is invalid/)
  end
end
