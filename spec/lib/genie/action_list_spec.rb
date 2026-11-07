# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# Remix Script.ClassActionList (Script.cs:328-485 R). Order expectations are the order
# genieflow fires actions in (flow case t93_action_sort_order); class expectations are the
# t97_action_class_first_state golden.
RSpec.describe Lich::Genie::ActionList do
  subject(:list) { described_class.new }

  def keys = list.to_a.map(&:key)

  describe '#add' do
    it 'normalizes the trigger like Triggers.Add (e/, eval, /re/, /re/i)' do
      expect(list.add('/^Foo/i', 'echo a')).to be(true)
      expect(list.add('e/%x = 1/', 'echo b')).to be(true)
      expect(list.add('EVAL %y', 'echo c')).to be(true)
      expect(list.add('^bar/', 'echo d')).to be(true)
      expect(list['^Foo']).to have_attributes(eval: false, action: 'echo a')
      expect(list['^Foo'].regex.match?('FOO')).to be(true)
      expect(list['%x = 1']).to have_attributes(eval: true, regex: nil)
      expect(list['%y']).to have_attributes(eval: true, regex: nil)
      expect(list['^bar'].regex.match?('BAR')).to be(false)
    end

    it 'replaces the action registered under the same key instead of adding a second one' do
      list.add('^dup', 'echo ONE')
      list.add('/^dup/', 'echo TWO')
      expect(list.size).to eq(1)
      expect(list['^dup'].action).to eq('echo TWO')
    end

    it 'keeps an e/ and a plain trigger with the same text as ONE key (eval flag of the last add)' do
      list.add('^k', 'echo plain')
      list.add('e/^k', 'echo eval')
      expect(list.size).to eq(1)
      expect(list['^k']).to have_attributes(eval: true, action: 'echo eval')
    end

    it 'rejects a pattern .NET rejects and registers nothing, not even its class' do
      expect(list.add('(unclosed', '(c) echo x')).to be(false)
      expect(list.add('\\_', 'echo x')).to be(false)
      expect(list.size).to eq(0)
      expect(list.class_state('c')).to be_nil
    end

    it 'accepts an empty trigger (an empty regex matches every line)' do
      expect(list.add('', 'echo all')).to be(true)
      expect(list[''].regex.match?('anything')).to be(true)
    end

    it 'never validates an eval trigger as a regex' do
      expect(list.add('eval (unclosed', 'echo x')).to be(true)
    end

    it 'records instant and the file position' do
      list.add('^i', 'echo i', file_id: 2, file_row: 7, instant: true)
      expect(list['^i']).to have_attributes(instant: true, file_id: 2, file_row: 7)
    end
  end

  describe 'classes (Script.cs:410-426, 469-484 R)' do
    it 'cuts the class off the ACTION text, lower-cased and trimmed, and trims the body' do
      list.add('^a', '( MiXed )   echo hi  ')
      expect(list['^a']).to have_attributes(klass: 'mixed', action: 'echo hi', active: true)
    end

    it 'leaves a body starting with a space or without a closing paren unclassed' do
      list.add('^a', ' (c) echo hi')
      list.add('^b', '(c echo hi')
      expect(list['^a']).to have_attributes(klass: '', action: ' (c) echo hi')
      expect(list['^b']).to have_attributes(klass: '', action: '(c echo hi')
    end

    it 'freezes a class first seen OFF: later actions start inactive even after on' do
      list.set_class('c1', false)
      list.add('^x', '(c1) echo x')
      expect(list['^x'].active).to be(false)
      list.set_class('c1', true)
      expect(list['^x'].active).to be(true) # SetClass flips the existing ones
      list.add('^y', '(c1) echo y')
      expect(list['^y'].active).to be(false) # but the class list still says off
      expect(list.class_state('c1')).to be(false)
    end

    it 'freezes a class first seen through an action ON: actions added after off are active' do
      list.add('^x', '(c2) echo x')
      list.set_class('c2', false)
      expect(list['^x'].active).to be(false)
      list.add('^y', '(c2) echo y')
      expect(list['^y'].active).to be(true)
      expect(list.class_state('c2')).to be(true)
    end

    it 'matches class names after lower-casing and trimming SetClass input' do
      list.add('^x', '(abc) echo x')
      list.set_class(' ABC ', false)
      expect(list['^x'].active).to be(false)
    end

    it 'keeps the class list across clear' do
      list.set_class('c', false)
      list.add('^x', '(c) echo x')
      list.clear
      expect(list.size).to eq(0)
      list.add('^y', '(c) echo y')
      expect(list['^y'].active).to be(false)
    end

    it 'never touches actions of other classes or unclassed actions' do
      list.add('^x', '(a) echo x')
      list.add('^y', 'echo y')
      list.set_class('b', false)
      expect([list['^x'].active, list['^y'].active]).to eq([true, true])
    end
  end

  describe '#remove' do
    it 'normalizes its argument like add' do
      list.add('^gone', 'echo x')
      list.add('^kept', 'echo y')
      list.remove('/^gone/i')
      expect(keys).to eq(['^kept'])
    end

    it 'is a no-op for an unknown key' do
      list.add('^kept', 'echo y')
      list.remove('^nothing')
      expect(keys).to eq(['^kept'])
    end
  end

  describe '#to_a (SortedList order, ICU root collation)' do
    it 'orders symbols before digits before letters, lower before upper case' do
      %w[b?x A?X a?x 0?x ^x .?x _?x x].each { |key| list.add(key, 'echo') }
      expect(keys).to eq(%w[_?x .?x ^x 0?x a?x A?X b?x x])
    end

    it 'keeps a replaced key in place and re-sorts after a new key or a removal' do
      list.add('b', 'echo 1')
      list.add('c', 'echo 2')
      first = list.to_a
      list.add('b', 'echo 3')
      expect(list.to_a.map(&:action)).to eq(['echo 3', 'echo 2'])
      list.add('a', 'echo 4')
      expect(keys).to eq(%w[a b c])
      list.remove('b')
      expect(keys).to eq(%w[a c])
      expect(first.map(&:key)).to eq(%w[b c]) # an earlier snapshot is not mutated
    end

    # uber.cmd re-registers its actions inside combat subs; a
    # same-key replace must not recompute collation keys or re-sort.
    it 'swaps a replaced entry into a copy of the snapshot without computing any collation key' do
      %w[c a b].each { |key| list.add(key, "echo #{key}") }
      before = list.to_a
      allow(Lich::Genie::Collation).to receive(:key).and_call_original
      list.add('b', 'echo B2')
      after = list.to_a
      expect(Lich::Genie::Collation).not_to have_received(:key)
      expect(after.map(&:action)).to eq(['echo a', 'echo B2', 'echo c'])
      expect(before.map(&:action)).to eq(['echo a', 'echo b', 'echo c'])
      expect(after[1].sort_key).to equal(before[1].sort_key)
      expect([after.frozen?, list.to_a]).to eq([true, after]) # cached until the next change
    end

    it 'computes one collation key per new key, never per sort' do
      allow(Lich::Genie::Collation).to receive(:key).and_call_original
      %w[c a b].each { |key| list.add(key, 'echo') }
      list.to_a
      list.add('d', 'echo')
      list.to_a
      expect(Lich::Genie::Collation).to have_received(:key).exactly(4).times
      expect(keys).to eq(%w[a b c d])
    end
  end

  describe '#current?' do
    it 'is false for an entry that was removed or replaced' do
      list.add('^a', 'echo 1')
      old = list['^a']
      expect(list.current?(old)).to be(true)
      list.add('^a', 'echo 2')
      expect(list.current?(old)).to be(false)
      fresh = list['^a']
      list.remove('^a')
      expect(list.current?(fresh)).to be(false)
    end
  end

  # The eval actions Script.TriggerVariableChanged walks, in SortedList order.
  describe '#eval_entries' do
    subject(:list) { described_class.new }

    it 'lists only eval actions, in the sorted order, and follows adds, replaces and removes' do
      list.add('eval %b = 1', 'echo b')
      list.add('^text', 'echo t')
      list.add('e/%a/', 'echo a')
      expect(list.eval_entries.map(&:key)).to eq(['%a', '%b = 1'])
      list.add('e/%a/', 'echo a2')
      expect(list.eval_entries.map(&:action)).to eq(['echo a2', 'echo b'])
      list.remove('eval %b = 1')
      expect(list.eval_entries.map(&:key)).to eq(['%a'])
      list.clear
      expect(list.eval_entries).to eq([])
    end
  end
end
