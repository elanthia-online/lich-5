# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative 'support/save_ordering'
require_relative '../../../lib/genie'
require 'tmpdir'

# Lich::Genie::AliasList: Remix Lists/Aliases.cs (R); its use on the engine path is ParseCommand's
# (parse_command_spec, flow t221_alias_engine).
RSpec.describe Lich::Genie::AliasList do
  subject(:aliases) { described_class.new }

  it 'adds, replaces, looks up exactly (case-sensitive) and removes' do
    aliases.add('nx', 'recall')
    aliases.add('nx', 'recall nexus list')
    aliases.add('NX', 'other')
    expect([aliases['nx'], aliases['NX'], aliases.key?('Nx')]).to eq(['recall nexus list', 'other', false])
    expect(aliases.remove('nx')).to be(true)
    expect(aliases.remove('nx')).to be(false)
    expect(aliases.entries).to eq([%w[NX other]])
  end

  it 'lists in SortedList order' do
    %w[b A a _].each { |k| aliases.add(k, k) }
    expect(aliases.entries.map(&:first)).to eq(%w[_ a A b])
  end

  describe 'files (Aliases.Load / Save)' do
    around { |example| Dir.mktmpdir('genie-aliases') { |dir| @dir = dir; example.run } }

    it 'merges three-token rows, remembers the path even when absent, and saves there' do
      path = File.join(@dir, 'aliases.cfg')
      expect(aliases.load(path)).to be(false)
      expect(aliases.file).to eq(path)
      Lich::Genie::ConfigFile.write_lines(path, ['#alias {,n} {,map}', '#alias {tic}', '#alias {a} {b} {c}', '#alias {nexus} {recall nexus list}'])
      aliases.add('keep', 'k')
      expect(aliases.load).to be(true)
      expect(aliases.entries).to eq([[',n', ',map'], %w[keep k], ['nexus', 'recall nexus list']])
      expect(aliases.save).to be(true)
      expect(File.binread(path)).to eq("#alias {,n} {,map}\r\n#alias {keep} {k}\r\n#alias {nexus} {recall nexus list}\r\n")
    end

    it 'saves nothing with no path at all, and reports an unreadable row as a failed load' do
      expect(aliases.save).to be(false)
      path = File.join(@dir, 'bad.cfg')
      Lich::Genie::ConfigFile.write_lines(path, ['#alias {a} {b}', '"'])
      expect(aliases.load(path)).to be(false)
      expect(aliases['a']).to eq('b')
    end

    it 'orders whole saves: an older snapshot never lands after a newer one' do
      extend GenieSpecSupport::SaveOrdering
      # authored: the side file of an alias that is not is one more write (definition_trust_spec)
      expect_ordered_saves(first: -> { aliases.add('k', 'one', authored: true) }, second: -> { aliases.add('k', 'two', authored: true) },
                           first_marker: '{k} {one}', second_marker: '{k} {two}',
                           save: -> { aliases.save(File.join(@dir, 'aliases.cfg')) })
    end
  end
end
