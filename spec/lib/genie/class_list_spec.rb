# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative 'support/save_ordering'
require_relative '../../../lib/genie'
require 'tmpdir'

# Lich::Genie::ClassList: Remix Lists/Classes.cs (R) -- the global class list. Expectations pinned
# by genieflow (flow t213_class_model).
RSpec.describe Lich::Genie::ClassList do
  subject(:classes) { described_class.new }

  describe '#add (Classes.Add: true/on/1 on, ANYTHING else off)' do
    it 'turns true/on/1 on in any case and every other value off, `yes` and "" included' do
      { 'True' => true, 'ON' => true, '1' => true, 'false' => false, 'off' => false, '0' => false,
        'yes' => false, 'enable' => false, '' => false, ' on' => false }.each do |value, state|
        classes.add('k', value)
        expect(classes['k']).to be(state), value.inspect
      end
    end

    it 'keeps keys case-sensitive and lists them in SortedList order' do
      classes.add('Bar', 'off')
      classes.add('baz', 'on')
      classes.add('bar', 'on')
      classes.add('_x', 'on')
      expect(classes.entries).to eq([['_x', true], ['bar', true], ['Bar', false], ['baz', true]])
    end
  end

  describe 'activate_all / inactivate_all / clear (Classes.cs:11-85 R)' do
    it 'switches everything on, everything but `default` off, and clear leaves default = True' do
      classes.add('default', 'off')
      classes.add('a', 'off')
      classes.activate_all
      expect(classes.entries).to eq([['a', true], ['default', true]])
      classes.inactivate_all
      expect(classes.entries).to eq([['a', false], ['default', true]])
      classes.clear
      expect(classes.entries).to eq([['default', true]])
    end

    it 'is a no-op on an empty list (no default is invented by activate/inactivate)' do
      classes.inactivate_all
      classes.activate_all
      expect(classes.entries).to eq([])
    end
  end

  describe '#each_state (Command_EventClassChange walk, FormMain.cs:7483-7519 R)' do
    it 'yields `default` as "" and every other key as stored, in list order' do
      classes.add('default', 'True')
      classes.add('Zed', 'off')
      classes.add('alpha', 'on')
      expect(classes.enum_for(:each_state).to_a).to eq([['alpha', true], ['', true], ['Zed', false]])
    end
  end

  describe 'files (Classes.Load / Save)' do
    around { |example| Dir.mktmpdir('genie-classes') { |dir| @dir = dir; example.run } }

    it 'adds default = True even when the file is missing or no path is given, returning false' do
      expect(classes.load(File.join(@dir, 'missing.cfg'))).to be(false)
      expect(described_class.new.tap { |c| c.load(nil) }.entries).to eq([['default', true]])
      expect(classes.entries).to eq([['default', true]])
    end

    it 'merges three-token rows only, lower-casing the value, and round-trips Remix\'s format' do
      path = File.join(@dir, 'classes.cfg')
      Lich::Genie::ConfigFile.write_lines(path, ['#class {A b} {FALSE}', '#class {c} {On}', '#class {d}', '#class {e} {1} {x}'])
      classes.add('keep', 'on')
      expect(classes.load(path)).to be(true)
      expect(classes.entries).to eq([['A b', false], ['c', true], ['default', true], ['keep', true]])
      out = File.join(@dir, 'out.cfg')
      expect(classes.save(out)).to be(true)
      expect(File.binread(out)).to eq("#class {A b} {False}\r\n#class {c} {True}\r\n#class {default} {True}\r\n#class {keep} {True}\r\n")
    end

    it 'stops at a malformed row (ParseArgs throws) keeping the rows before it' do
      path = File.join(@dir, 'bad.cfg')
      Lich::Genie::ConfigFile.write_lines(path, ['#class {a} {on}', '"', '#class {b} {on}'])
      expect(classes.load(path)).to be(false)
      expect(classes.entries.map(&:first)).to eq(%w[a default])
    end

    it 'saves nothing without a path' do
      expect(classes.save(nil)).to be(false)
    end

    it 'orders whole saves: an older snapshot never lands after a newer one' do
      extend GenieSpecSupport::SaveOrdering
      expect_ordered_saves(first: -> { classes.add('k', 'on') }, second: -> { classes.add('k', 'off') },
                           first_marker: '{k} {True}', second_marker: '{k} {False}',
                           save: -> { classes.save(File.join(@dir, 'classes.cfg')) })
    end
  end
end
