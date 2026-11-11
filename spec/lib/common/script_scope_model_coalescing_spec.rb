# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require_relative '../../../lib/common/script_scope/gtk/session'
require_relative '../../../lib/common/script_scope/gtk/widgets'
require_relative '../../../lib/common/script_scope/gtk/models'
require_relative '../../../lib/common/script_scope/gtk/tree_view'
require_relative '../../../lib/common/script_scope/gtk/combo_box'

# Script-thread model writes outside a callback. Owner dispatcher work
# is held in a list until the spec runs it, as the core holds it for the owner
# worker. A recording port stands in for core.
RSpec.describe 'script compatibility model publication outside callbacks' do
  port_class = Class.new do
    attr_reader :sets

    def initialize
      @sets = []
      @values = {}
    end

    def create(_type, _props) = Object.new
    def attach(*) = nil
    def detach(*) = nil
    def destroy(_handle) = nil
    def bind(*) = 'binding'
    def schema(type) = Lich::WebUI::Contract.schema(type)

    def set(handle, property, value)
      @sets << [property, value]
      @values[[handle, property]] = value
    end

    def get(handle, property) = @values[[handle, property]]
  end

  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name, :thread_group).new('fill.lic', ThreadGroup.new) }
  let(:port) { port_class.new }
  let(:session) { gtk::Session.new(owner) }
  let(:jobs) { [] }

  before do
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    allow(Lich::WebUI).to receive(:adapter).and_return(port)
    allow(Lich::WebUI).to receive(:callback_queue).and_return(proc { |&work| jobs << work; :queued })
    allow(Lich).to receive(:log)
    allow(gtk).to receive(:session) { session }
  end

  def run_jobs
    jobs.shift.call until jobs.empty?
  end

  def shown_table(store)
    view = gtk::TreeView.new(store)
    view.append_column(gtk::TreeViewColumn.new('Name', gtk::CellRendererText.new, text: 0))
    view.append_column(gtk::TreeViewColumn.new('Count', gtk::CellRendererText.new, text: 1))
    yield view if block_given?
    view.materialize
    view
  end

  # Counts whole-table validations, publications and changed-row checks.
  def record(view)
    counts = Hash.new(0)
    %i[model_will_change! model_changed! model_rows_will_change!].each do |name|
      allow(view).to receive(name).and_wrap_original do |method, *args|
        counts[name] += 1
        method.call(*args)
      end
    end
    counts
  end

  def published_rows = port.sets.select { |property, _value| property == :rows }.map(&:last)

  def fill(store, count)
    count.times do |index|
      row = store.append
      row[0], row[1] = "Row #{index}", index
    end
  end

  it 'publishes an 800-row script-thread fill a bounded number of times and shows every row' do
    store = gtk::ListStore.new(String, Integer)
    view = shown_table(store)
    counts = record(view)

    store.append
    expect(published_rows.last.length).to eq(1)
    fill(store, 799)
    expect([store.size, store.get_iter('799')[0], store.each.count]).to eq([800, 'Row 798', 800])

    run_jobs
    expect(counts.values_at(:model_will_change!, :model_changed!)).to eq([2, 2])
    expect(counts[:model_rows_will_change!]).to eq(799 * 3)
    expect(published_rows.length).to eq(2)
    expect(published_rows.last.length).to eq(800)
    expect(published_rows.last.last[:cells].values).to eq(['Row 798', 798])
    expect(jobs).to be_empty
  end

  it 'publishes coalesced rows at the next widget read, before the fence job runs' do
    store = gtk::ListStore.new(String, Integer)
    view = shown_table(store)
    fill(store, 3)
    expect(published_rows.last.length).to eq(1)

    view.headers_visible?
    expect(published_rows.last.map { |row| row[:cells].values }).to eq([['Row 0', 0], ['Row 1', 1], ['Row 2', 2]])
    publications = published_rows.length
    run_jobs
    expect(published_rows.length).to eq(publications)

    store.append
    expect(published_rows.last.length).to eq(4)
  end

  it 'still refuses an invalid script-thread write at its call while coalescing' do
    store = gtk::ListStore.new(String, Integer)
    view = shown_table(store) do |table|
      column = table.columns.first
      column.set_cell_data_func(column.renderer) { |_column, cell, _model, iter| cell.text = [0xFF].pack('C*') if iter[1] == 13 }
    end
    combo = gtk::ComboBox.new(store)
    counts = record(view)
    fill(store, 2)
    row = store.get_iter('1')
    checks = counts[:model_rows_will_change!]
    publications = published_rows.length

    expect { row[1] = 13 }.to raise_error(gtk::UnsupportedOperation, /operation=text=/)
    expect(counts[:model_rows_will_change!]).to eq(checks + 1)
    expect { row[0] = 'x' * (Lich::WebUI::Contract::BOUNDS[:short_text] + 1) }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect([store.size, row[0], row[1]]).to eq([2, 'Row 1', 1])
    expect(published_rows.length).to eq(publications)

    run_jobs
    expect(published_rows.last.map { |published| published[:cells].values }).to eq([['Row 0', 0], ['Row 1', 1]])
    expect(combo.model.rows.map { |iter| iter[0] }).to eq(['Row 0', 'Row 1'])
  end

  it 'keeps one validation and one publication for the same fill inside Gtk.queue' do
    store = gtk::ListStore.new(String, Integer)
    view = shown_table(store)
    counts = record(view)

    session.queue { fill(store, 800) }
    run_jobs
    expect(counts.values_at(:model_will_change!, :model_changed!, :model_rows_will_change!)).to eq([1, 1, 0])
    expect(published_rows.length).to eq(1)
    expect(published_rows.last.length).to eq(800)
  end

  it 'rolls back a callback that fails midway and keeps a coalesced write for the fence' do
    store = gtk::ListStore.new(String, Integer)
    row = store.append
    view = shown_table(store)
    session.queue do
      fill(store, 5)
      row[0] = 'Staged'
      raise 'abort this callback'
    end
    row[0] = 'First'
    row[0] = 'Second'
    expect(published_rows.last.first[:cells].values).to eq(['First', 0])
    counts = record(view)

    run_jobs
    expect([store.size, row[0]]).to eq([1, 'Second'])
    expect(counts[:model_changed!]).to eq(1)
    expect(published_rows.last.map { |published| published[:cells].values }).to eq([['Second', 0]])
    expect(Lich).to have_received(:log).with(/callback failed/)
  end
end
