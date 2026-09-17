# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'webui'
require 'common/script_scope'
require 'common/script_scope/gtk/boot'

# #next! advances an iter by rewriting its key, and the model handed out its
# own row objects -- so the caller's iter WAS a row, and advancing it
# rewrote that row. jinx.lic walks a store exactly this way, twice.
RSpec.describe 'GTK compatibility shim: walking a list store' do
  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:store) do
    gtk::ListStore.new(String).tap do |model|
      %w[alpha beta gamma].each { |value| model.append.tap { |iter| iter[0] = value } }
    end
  end

  def contents
    (0..2).map { |index| store.get_iter(gtk::TreePath.new([index]))[0] }
  end

  it 'terminates, visiting every row once' do
    iter = store.iter_first
    seen = []
    # Bounded so a regression fails rather than hanging the suite.
    9.times do
      seen << iter[0]
      break unless iter.next!
    end

    expect(seen).to eq(%w[alpha beta gamma])
  end

  it 'leaves the model untouched' do
    iter = store.iter_first
    iter.next! while iter.next!

    expect(contents).to eq(%w[alpha beta gamma])
  end

  it 'still writes through to the row it has advanced to' do
    iter = store.iter_first
    iter.next!
    iter[0] = 'BETA'

    expect(contents).to eq(%w[alpha BETA gamma])
  end

  it 'reports the end of the model' do
    iter = store.get_iter(gtk::TreePath.new([2]))

    expect(iter.next!).to be(false)
  end

  it 'hands out iters that do not alias each other' do
    first = store.iter_first
    second = store.iter_first
    first.next!

    expect(second[0]).to eq('alpha')
  end

  # iter_first/get_iter/iter_after were taught to hand out copies; the three
  # constructors and #each were not, and they are how a script actually gets
  # hold of an iter. `iter = store.append; iter[0] = value` is the populate
  # idiom, and walking from what it returned rewrote the model exactly as
  # before.
  describe 'the iters a script gets from anywhere other than a lookup' do
    def all_rows
      store.to_enum(:each).map { |_model, _path, row| row[0] }
    end

    it 'does not let the iter from #append rewrite the model when walked' do
      iter = store.append
      iter[0] = 'delta'
      iter.next! while iter.next!

      expect(all_rows).to eq(%w[alpha beta gamma delta])
    end

    it 'does not let the iter from #prepend rewrite the model when walked' do
      iter = store.prepend
      iter[0] = 'delta'
      iter.next! while iter.next!

      expect(all_rows).to eq(%w[delta alpha beta gamma])
    end

    it 'does not let the iter from #insert rewrite the model when walked' do
      iter = store.insert(1)
      iter[0] = 'delta'
      iter.next! while iter.next!

      expect(all_rows).to eq(%w[alpha delta beta gamma])
    end

    # #each dup'd the array but yielded the model's own row objects.
    it 'does not let an each-yielded iter rewrite the model' do
      first = nil
      store.each { |_model, _path, iter| first ||= iter }
      first.next!

      expect(contents).to eq(%w[alpha beta gamma])
    end

    it 'still writes through an each-yielded iter' do
      store.each { |_model, _path, iter| iter[0] = iter[0].upcase }

      expect(contents).to eq(%w[ALPHA BETA GAMMA])
    end

    it 'still writes through the iter a constructor returned' do
      iter = store.append
      iter[0] = 'delta'

      expect(contents + [store.get_iter(gtk::TreePath.new([3]))[0]])
        .to eq(%w[alpha beta gamma delta])
    end

    it 'walks to the end from a constructed iter without repeating a row' do
      iter = store.append
      iter[0] = 'delta'
      seen = []
      walker = store.iter_first
      9.times do
        seen << walker[0]
        break unless walker.next!
      end

      expect(seen).to eq(%w[alpha beta gamma delta])
    end
  end

  # append/prepend/insert/each were taught to hand out copies; TreeSelection
  # still returned the model's own row objects, so a walk from
  # `selection.selected` -- an ordinary idiom -- rewrote the model exactly as
  # before. This is a different entry point, not the same bug twice.
  describe 'the iters a selection hands back' do
    let(:view) { gtk::TreeView.new(store) }
    let(:selection) { view.selection }

    before { selection.select_path(gtk::TreePath.new([0])) }

    it 'walks to the end without repeating a row' do
      cursor = selection.selected
      seen = []
      9.times do
        seen << cursor[0]
        break unless cursor.next!
      end

      expect(seen).to eq(%w[alpha beta gamma])
    end

    it 'leaves the model untouched when the selected iter is advanced' do
      cursor = selection.selected
      cursor.next! while cursor.next!

      expect(contents).to eq(%w[alpha beta gamma])
    end

    it 'does not alias the model through selected_each either' do
      first = nil
      selection.selected_each { |_model, _path, iter| first ||= iter }
      first.next!

      expect(contents).to eq(%w[alpha beta gamma])
    end

    # The copy shares the row's values array, so a script editing through a
    # selected iter must still reach the model.
    it 'still writes through to the model' do
      selection.selected[0] = 'ALPHA'

      expect(contents).to eq(%w[ALPHA beta gamma])
    end
  end

  # TreeStore was a bare ListStore subclass, so every hierarchy operation
  # answered as though the rows were siblings. Each expectation below was
  # checked against gtk3 3.24.52 rather than assumed.
  describe 'a tree store' do
    let(:tree) { gtk::TreeStore.new(String) }
    let!(:root) { tree.append(nil).tap { |iter| iter[0] = 'root' } }
    let!(:child) { tree.append(root).tap { |iter| iter[0] = 'child' } }
    let!(:grandchild) { tree.append(child).tap { |iter| iter[0] = 'grand' } }
    let!(:sibling) { tree.append(nil).tap { |iter| iter[0] = 'sibling' } }

    # Was "0" -- the sibling index with every ancestor dropped.
    it 'spells a path with every ancestor in it' do
      expect(grandchild.path.to_s).to eq('0:0:0')
      expect(child.path.to_s).to eq('0:0')
      expect(sibling.path.to_s).to eq('1')
    end

    it 'resolves a path back to the row it names' do
      expect(tree.get_iter(gtk::TreePath.new([0, 0, 0]))[0]).to eq('grand')
    end

    # Was the next row in the backing array, which for a row with children is
    # its own first child -- so a walk descended instead of advancing.
    it 'advances to the next sibling rather than into its own children' do
      cursor = tree.iter_first

      expect(cursor.next!).to be(true)
      expect(cursor[0]).to eq('sibling')
    end

    it 'walks the top level and stops' do
      seen = []
      cursor = tree.iter_first
      9.times do
        seen << cursor[0]
        break unless cursor.next!
      end

      expect(seen).to eq(%w[root sibling])
    end

    # Was immediate children only, leaving grandchildren pointing at a parent
    # that no longer existed.
    it 'takes the whole subtree when a row is removed' do
      tree.remove(tree.iter_first)

      expect(tree.to_enum(:each).map { |_model, _path, iter| iter[0] }).to eq(['sibling'])
    end

    it 'answers the questions a script walking a tree asks' do
      expect(tree.iter_n_children(root)).to eq(1)
      expect(tree.iter_n_children).to eq(2)
      expect(tree.iter_has_child?(root)).to be(true)
      expect(tree.iter_has_child?(grandchild)).to be(false)
      expect(tree.iter_children(root)[0]).to eq('child')
      expect(tree.iter_parent(grandchild)[0]).to eq('child')
      expect(tree.iter_parent(root)).to be_nil
    end

    # The flat store is unchanged: it has no parents, so nothing above applies.
    it 'leaves a flat list store alone' do
      flat = gtk::ListStore.new(String)
      %w[a b].each { |value| flat.append.tap { |iter| iter[0] = value } }

      expect(flat.iter_first.path.to_s).to eq('0')
      expect(flat.iter_after(flat.iter_first)[0]).to eq('b')
    end
  end
end
