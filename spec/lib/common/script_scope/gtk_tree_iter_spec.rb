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
end
