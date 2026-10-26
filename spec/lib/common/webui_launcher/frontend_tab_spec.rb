# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'common/webui_launcher/frontend_tab'

RSpec.describe Lich::Common::WebUILauncher::FrontendTab do
  let(:directory) { Dir.mktmpdir('native-frontend-tab') }
  let(:pending) { [] }
  let(:executor) do
    queue = pending
    Object.new.tap { |worker| worker.define_singleton_method(:post) { |&work| queue << work } }
  end
  let(:locator) do
    Class.new do
      def self.resolve(_id, **_options) = nil
      def self.refresh! = nil
    end
  end
  let(:changed) { [] }
  let(:tab) { described_class.new(data_dir: directory, locator: locator, executor: executor, on_change: -> { changed << true }) }

  before { Lich::Common::FrontendSettings.load!(data_dir: directory) }
  after do
    tab.close
    FileUtils.remove_entry(directory)
    Lich::Common::Frontend.replace_user_configuration!(built_in_overrides: {}, custom_definitions: {})
    Lich::Common::FrontendSettings.instance_variable_set(:@current, Lich::Common::FrontendSettings::EMPTY_CONFIGURATION)
  end

  def tree
    subject = tab
    Lich::WebUI::Page.new(owner: 'frontend-test', id: 'frontend-test', title: 'Frontends') do |ui|
      subject.render(ui)
    end.render.tree
  end

  def find(suffix)
    tree.each.find { |node| node.cid.end_with?(suffix) }
  end

  def event(id: 'test-client', label: 'Test client', command: '/tmp/client', arguments: '--flag "two words"')
    values = { id: id, label: label, command: command, directory: '', arguments: arguments }
             .to_h { |key, value| ["page:frontend-test/text_input:frontend-#{key}", value] }
    values['page:frontend-test/checkbox:frontend-capability-xml'] = true
    submission = Lich::WebUI::Submission.new(viewer_id: 'test-viewer', values: values)
    Struct.new(:submission).new(submission)
  end

  it 'preserves catalog columns, first selection, field locks and action order' do
    catalog = find('table:frontends-table')
    expect(catalog.props[:columns].map { |column| column[:label] })
      .to eq(['Frontend', 'Type', 'Status', 'Executable / command', 'Additional arguments'])
    expect(find('text_input:frontend-id').props[:value]).to eq(catalog.props[:rows].first[:key])
    expect(find('text_input:frontend-id').props[:disabled]).to be(true)
    expect(find('button:frontends-delete').props[:disabled]).to be(true)
    expect(find('columns:frontend-actions').children.filter_map { |child| child.props[:label] })
      .to eq(['Add Custom', 'Save', 'Delete Custom', 'Reload'])
  end

  it 'does no filesystem writes on the event thread and persists literal arguments on the worker' do
    tab.begin_new_frontend
    tab.save_frontend(event)
    expect(File.exist?(File.join(directory, 'frontends.yml'))).to be(false)
    pending.shift.call
    document = YAML.safe_load_file(File.join(directory, 'frontends.yml'))
    expect(document.fetch('custom').fetch('test-client')).to include(
      'command' => '/tmp/client', 'arguments' => ['--flag', 'two words'], 'capabilities' => ['xml']
    )
    expect(find('text_input:frontend-id').props[:value]).to eq('test-client')
    expect(changed).not_to be_empty
  end

  it 'does not write a queued edit after the launcher closes' do
    tab.begin_new_frontend
    tab.save_frontend(event)
    tab.close
    pending.shift.call
    expect(File.exist?(File.join(directory, 'frontends.yml'))).to be(false)
  end

  it 'honors the parent close gate before writing frontend settings' do
    guarded = described_class.new(data_dir: directory, locator: locator, executor: executor,
                                  on_change: proc {}, commit: ->(&_work) { false })
    guarded.begin_new_frontend
    guarded.save_frontend(event)
    pending.shift.call

    expect(File.exist?(File.join(directory, 'frontends.yml'))).to be(false)
  ensure
    guarded&.close
  end

  it 'rejects overlapping edits rather than queuing a duplicate save' do
    tab.begin_new_frontend
    tab.save_frontend(event)
    tab.save_frontend(event)
    expect(pending.size).to eq(1)
  end

  it 'refuses a submitted identifier that differs from the server selection' do
    tab.save_frontend(event(id: 'forged-custom'))
    pending.shift.call
    expect(File.exist?(File.join(directory, 'frontends.yml'))).to be(false)
    expect(tree.each.map { |node| node.props[:content] }.compact.join).to include('selection changed')
  end

  it 'shows validation failure and leaves the existing document intact' do
    tab.begin_new_frontend
    tab.save_frontend(event(id: '../invalid'))
    pending.shift.call
    expect(File.exist?(File.join(directory, 'frontends.yml'))).to be(false)
    expect(tree.each.map { |node| node.props[:content] }.compact.join).to include('Stable ID')
  end

  it 'deletes only the selected custom record through the worker' do
    tab.begin_new_frontend
    tab.save_frontend(event)
    pending.shift.call
    tab.delete_frontend
    pending.shift.call
    expect(YAML.safe_load_file(File.join(directory, 'frontends.yml')).fetch('custom')).to be_empty
  end

  it 'renders cached detection without repeating filesystem discovery' do
    tab
    expect(locator).not_to receive(:resolve)
    tree
  end

  it 'changes editor identity on selection so browser drafts cannot survive into another record' do
    previous = find('text_input:frontend-id').cid
    tab.begin_new_frontend
    fresh = find('text_input:frontend-id')
    expect(fresh.cid).not_to eq(previous)
    expect(fresh.props[:value]).to eq('')
  end

  [[], ['removed-client']].each do |rows|
    it "ignores an empty or stale selection #{rows.inspect} without replacing the draft" do
      tab.begin_new_frontend
      before = tree.to_h
      changes = changed.size

      tab.select_frontend(Struct.new(:payload).new({ rows: rows }))

      expect(tree.to_h).to eq(before)
      expect(changed.size).to eq(changes)
    end
  end
end
