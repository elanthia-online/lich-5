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
end
