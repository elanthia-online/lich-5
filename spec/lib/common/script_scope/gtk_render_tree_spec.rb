# frozen_string_literal: true

require 'json'
require_relative '../../../spec_helper'
require 'webui'
require 'common/script_scope'
require 'common/script_scope/gtk/boot'

# D13 (ledger part 2): ShimAdapter#render_children used to re-implement the
# base adapter's traversal so it could inject placement, the presentation
# facility and submission scopes; two nearly identical walks drift. The base
# traversal now calls narrow hooks and the shim's copy is gone. This pins the
# rendered tree of a window that exercises every hook -- grid spans and box
# padding (placement), keep_above (presentation), a password entry and its
# button (submission scope), a viewer-scoped checkbox -- against a fixture
# captured before the refactor, so the two are provably the same tree.
#
# Regenerate with WEBUI_SHIM_UPDATE_FIXTURE=1 when the tree changes on
# purpose.
RSpec.describe 'GTK compatibility shim: the rendered tree' do
  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('tree') }
  let(:service) { Lich::WebUI::Service.new }
  let(:session) { gtk::Session.new(owner, service: service) }
  let(:fixture) { File.expand_path('../../../fixtures/webui_shim/render_tree.json', __dir__) }

  before do
    gtk::Session.browser_open = proc { |_url, on_start:, **| on_start.call(1); true }
    allow(gtk::Session).to receive(:for).with(anything).and_return(session)
  end

  after do
    gtk::Session.browser_open = nil
    session.shutdown
    service.stop
  end

  def build_window
    window = nil
    session.sync do
      window = gtk::Window.new('Every hook')
      window.set_default_size(500, 400)
      window.set_keep_above(true)
      column = gtk::VBox.new
      grid = gtk::Grid.new
      grid.attach(gtk::Label.new('Name'), 0, 0, 1, 1)
      grid.attach(gtk::Entry.new.tap { |e| e.text = 'Nisugi' }, 1, 0, 2, 1)
      grid.attach(gtk::Label.new('Tall').tap { |l| l.hexpand = true }, 0, 1, 1, 2)
      column.pack_start(grid, expand: false, fill: false, padding: 4)
      row = gtk::HBox.new
      password = gtk::Entry.new
      password.visibility = false
      row.pack_start(password, expand: true, fill: true, padding: 2)
      row.pack_start(gtk::Button.new('Connect'), expand: false, fill: false, padding: 0)
      column.pack_start(row, expand: false, fill: false, padding: 0)
      column.pack_start(gtk::CheckButton.new('Remember').tap { |c| c.active = true }, expand: false, fill: false, padding: 0)
      scrolled = gtk::ScrolledWindow.new
      scrolled.add(gtk::Label.new('body'))
      column.pack_start(scrolled, expand: true, fill: true, padding: 0)
      window.add(column)
      window.show_all
    end
    session.sync {}
    window
  end

  # Widget keys come from a process-wide counter and the page id from the
  # adapter, so both are normalised by order of first appearance.
  def normalized_render(window)
    render = session.adapter.page_for(window.handle).last_render
    text = JSON.pretty_generate(
      tree: render.tree.to_h, facilities: render.facilities,
      submissions: render.submissions, bindings: render.bindings.keys.map { |(cid, event)| "#{cid}##{event}" }
    )
    keys = {}
    text = text.gsub(/\bw\d+\b/) { |key| keys[key] ||= "key#{keys.length + 1}" }
    text.gsub(/adapter-[a-z0-9]+/, 'adapter-X')
  end

  it 'renders the same tree, facilities, submissions and bindings as the captured fixture' do
    actual = normalized_render(build_window)
    if ENV['WEBUI_SHIM_UPDATE_FIXTURE']
      FileUtils.mkdir_p(File.dirname(fixture))
      File.binwrite(fixture, actual)
    end

    expect(File.exist?(fixture)).to be(true), "no fixture at #{fixture}; run once with WEBUI_SHIM_UPDATE_FIXTURE=1"
    expect(actual).to eq(File.binread(fixture).gsub("\r\n", "\n"))
  end

  it 'covers every hook the shim relies on' do
    actual = JSON.parse(normalized_render(build_window))

    expect(actual['facilities']).to eq('presentation' => { 'always_on_top' => true })
    expect(actual['submissions']).not_to be_empty
    placements = []
    walk = ->(node) { placements << node['placement'] if node['placement']; node['children'].to_a.each(&walk) }
    walk.call(actual['tree'])
    expect(placements).to include(a_hash_including('span' => 2), a_hash_including('row_span' => 2), a_hash_including('pad' => 4))
  end
end
