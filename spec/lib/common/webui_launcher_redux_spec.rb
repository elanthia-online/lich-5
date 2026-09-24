# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../login_spec_helper'
require 'common/webui_launcher'

# Fixture types stay local to this contract-focused example group.
# rubocop:disable Lint/ConstantDefinitionInBlock
RSpec.describe Lich::Common::WebUILauncher do
  Entry = Lich::Common::WebUILauncher::Catalog::Entry

  class ReduxFrontendLocator
    Resolution = Data.define(:frontend_id)

    def self.available(gui_selectable:, refresh:)
      raise unless gui_selectable && refresh

      [Resolution.new('stormfront'), Resolution.new('saga')]
    end

    def self.resolve(frontend, refresh: false)
      Resolution.new(frontend) if %w[stormfront saga].include?(frontend) && [true, false].include?(refresh)
    end
  end

  class ReduxCatalogFixture
    attr_reader :mutations

    def initialize(entries: [], keychain: true, mode: :standard)
      @entries = entries
      @keychain = keychain
      @mode = mode
      @mutations = []
    end

    def entries(autosort: false)
      autosort ? @entries.sort_by(&:char_name) : @entries
    end

    def accounts = @entries.map(&:user_id).uniq
    def encryption_mode = @mode
    def enhanced_encryption_available? = @keychain
    def toggle_favorite(key) = @mutations << [:favorite, key]
    def remove_entry(key) = @mutations << [:remove_entry, key]
    def remove_account(account) = @mutations << [:remove_account, account]
    def update_character(key, character) = @mutations << [:update_character, key, character]
    def add_character(account, character) = @mutations << [:add_character, account, character]
  end

  let(:entries) do
    [
      Entry.new('entry-0', 'DOUG', 'Aldor', 'GS3', 'GemStone IV', 'stormfront', nil, nil, true, 1),
      Entry.new('entry-1', 'DOUG', 'Bera', 'DR', 'DragonRealms', 'wizard', nil, nil, false, nil),
    ]
  end
  let(:catalog) { ReduxCatalogFixture.new(entries: entries) }
  let(:launcher) do
    described_class.new(
      data_dir: '/fixture', catalog: catalog, on_launch: proc {}, browser_open: proc { true },
      frontend_locator: ReduxFrontendLocator
    )
  end
  let(:tree) { launcher.send(:build_page).render.tree }

  def find(component, cid_suffix)
    component.each.find { |candidate| candidate.cid.end_with?(cid_suffix) }
  end

  it 'preserves the GTK top-level tab form, order, and saved-entry default' do
    tabs = find(tree, 'tabs:launcher-tabs')

    expect(tabs.type).to eq(:tabs)
    expect(tabs.props[:names]).to eq(['Saved Entry', 'Manual Entry', 'Account Management'])
    expect(tabs.props[:selected]).to eq(0)
    expect(tabs.children.map(&:slot)).to eq(['Saved Entry', 'Manual Entry', 'Account Management'])
  end

  it 'preserves favorites/account navigation and keeps row actions beside each saved row' do
    tabs = find(tree, 'tabs:saved-account-tabs')
    row = find(tree, 'group:entry-0')
    row_columns = row.children.first

    expect(tabs.props[:names]).to eq(['FAVORITES', 'DOUG'])
    expect(row_columns.type).to eq(:columns)
    expect(row_columns.props).to include(count: 3, weights: [7, 2, 1])
    expect(row_columns.children.map(&:type)).to eq([:button, :button, :button])
    expect(row_columns.children.map { |item| item.props[:label] })
      .to eq(['Aldor  |  GS Prime  |  Wrayth', 'Remove', 'filled_star'])
    expect(row_columns.children.first.props[:a11y_label]).to eq('Play Aldor')
    expect(row_columns.children.last.props[:a11y_label]).to eq('Unfavorite Aldor')
  end

  it 'keeps compact Play and Remove actions in list layout without exposing favorites' do
    list_launcher = described_class.new(
      data_dir: '/fixture', catalog: catalog, on_launch: proc {}, browser_open: proc { true }, tab_layout: false
    )
    rendered = list_launcher.send(:build_page).render.tree
    row = find(rendered, 'group:entry-1').children.first

    expect(row.props).to include(count: 2, weights: [8, 1])
    expect(row.children.map { |item| item.props[:label] }).to eq(['Play Bera | DR Prime | Wizard', 'Remove'])
    expect(rendered.each.none? { |component| component.cid.end_with?('button:favorite-entry-1') }).to be(true)
  end

  it 'puts the version in a bare page title rather than visible launcher content' do
    page = launcher.send(:build_page)

    expect(page.title).to match(/\ALich v/)
    expect(page.render.tree.props[:bare]).to be(true)
  end

  it 'uses the canonical compact realm names for every saved game instance' do
    realms = described_class::GAME_REALMS

    expect(realms).to eq(
      'GS3' => 'GS Prime', 'GSF' => 'GS Shattered', 'GSX' => 'GS Platinum', 'GST' => 'GS Test',
      'DR' => 'DR Prime', 'DRF' => 'DR Fallen', 'DRT' => 'DR Test'
    )
  end

  it 'authors saved geometry and persists bounded browser geometry proposals' do
    geometry_store = instance_double(
      Lich::Common::WebUILauncher::WindowGeometryStore,
      load: { width: 960, height: 720, position: [120, 48] }
    )
    allow(geometry_store).to receive(:save).and_return(width: 1000, height: 760, position: [-80, 60])
    geometry_launcher = described_class.new(
      data_dir: '/fixture', catalog: catalog, on_launch: proc {}, browser_open: proc { true },
      geometry_store: geometry_store
    )
    page = geometry_launcher.send(:build_page)
    render = page.render
    geometry_control = find(render.tree, 'text_input:window-geometry')
    event = Struct.new(:payload).new({ value: '{"width":1000,"height":760,"position":[-80,60]}' })

    expect(render.facilities[:geometry]).to eq(width: 960, height: 720, x: 120, y: 48)
    expect(geometry_control.props[:hidden]).to be(true)
    expect(geometry_launcher.window_geometry_changed(event))
      .to eq(width: 1000, height: 760, position: [-80, 60])
    expect(geometry_store).to have_received(:save).with(
      'width' => 1000, 'height' => 760, 'position' => [-80, 60]
    )
  end

  it 'preserves the GTK GUI Settings toggle and its setting order' do
    settings_toggle = find(tree, 'toggle:gui-settings-toggle')
    settings = find(tree, 'group:gui-settings')
    controls = settings.each.select { |component| component.type == :toggle }

    expect(settings_toggle.props).to include(label: 'GUI Settings', checked: false)
    expect(controls.map { |control| control.props[:label] })
      .to eq(['Dark Theme', 'Tab Layout', 'AutoSort', 'Multi-Launch'])
    expect(find(tree, 'stack:gui-settings-options').props[:hidden]).to be(true)
  end

  it 'preserves manual credentials, character list, launch options, and Play workflow order' do
    manual = find(tree, 'stack:manual-panel')
    groups = manual.children.select { |component| component.type == :group }

    expect(groups.map { |group| group.props[:label] }).to eq(['Credentials', 'Character', 'Launch Options'])
    expect(groups[0].each.map(&:type)).to include(:text_input, :password_input)
    expect(groups[1].each.map(&:type)).to include(:table)
    expect(find(groups[2], 'button:manual-play').props[:label]).to eq('Play')
    expect(launcher.send(:build_page).render.facilities[:accelerators])
      .to contain_exactly(hash_including(keys: 'enter', target: a_string_ending_with('button:manual-connect')))
  end

  it 'uses only dynamically discovered frontends, hides custom fields, and right-aligns disabled Play' do
    manual = find(tree, 'stack:manual-panel')
    frontend = find(manual, 'select:manual-frontend')
    custom_fields = find(manual, 'stack:manual-custom-fields')
    play = find(manual, 'button:manual-play')
    play_columns = find(manual, 'columns:manual-play-actions')

    expect(frontend.props[:options]).to eq([
                                             { value: 'stormfront', label: 'Wrayth' }, { value: 'saga', label: 'Saga' }
                                           ])
    expect(frontend.props[:options].map { |option| option[:value] }).not_to include('wizard', 'avalon')
    expect(custom_fields.props[:hidden]).to be(true)
    expect(play.props[:disabled]).to be(true)
    expect(play.slot).to eq('1')
    expect(play_columns.props).to include(count: 2, weights: [4, 1])
  end

  it 'reveals custom inputs only when the custom launch checkbox is checked' do
    event = Struct.new(:payload).new({ value: true })
    launcher.manual_option_changed(event, :custom_enabled)

    expect(find(launcher.send(:build_page).render.tree, 'stack:manual-custom-fields').props[:hidden]).to be(false)
  end

  it 'preserves account-management nested tabs and back/primary action pairing' do
    tabs = find(tree, 'tabs:account-management-tabs')
    character_actions = find(tree, 'group:character-form-section').children.last
    account_actions = find(tree, 'group:account-form-section').children.last

    expect(tabs.props[:names]).to eq(['Accounts', 'Add Character', 'Add Account', 'Encryption Management'])
    expect(character_actions.children.map { |button| button.props[:label] }).to eq(['Back to Accounts', 'Add Character'])
    expect(account_actions.children.map { |button| button.props[:label] }).to eq(['Back to Accounts', 'Add Account'])
  end

  it 'uses the same dynamically discovered frontend choices in account-management forms' do
    character_frontend = find(tree, 'select:character-frontend')
    account_frontend = find(tree, 'select:account-frontend')

    expect(character_frontend.props[:options]).to eq([
                                                       { value: 'stormfront', label: 'Wrayth' },
                                                       { value: 'saga', label: 'Saga' }
                                                     ])
    expect(account_frontend.props[:options]).to eq(character_frontend.props[:options])
  end

  it 'shows all three encryption modes and an actionable keychain-unavailable state' do
    unavailable = described_class.new(
      data_dir: '/fixture', catalog: ReduxCatalogFixture.new(entries: entries, keychain: false),
      on_launch: proc {}, browser_open: proc { true }
    )
    rendered = unavailable.send(:build_page).render.tree
    section = find(rendered, 'group:encryption-section')
    mode = section.each.find { |component| component.type == :radio }

    expect(mode.props[:options].map { |option| option[:value] }).to eq(%w[plaintext standard enhanced])
    expect(section.each.map { |component| component.props[:content] }.compact).to include('Secure keychain unavailable.')
  end

  it 'defaults to Manual Entry when there are no saved entries' do
    empty = described_class.new(
      data_dir: '/fixture', catalog: ReduxCatalogFixture.new, on_launch: proc {}, browser_open: proc { true }
    )
    rendered = empty.send(:build_page).render.tree

    expect(find(rendered, 'tabs:launcher-tabs').props[:selected]).to eq(1)
  end

  it 'stops loudly instead of falling back to an ordinary browser tab' do
    registry = instance_double(Lich::WebUI::Registry, register: nil)
    service = instance_double(
      Lich::WebUI::Service,
      registry: registry,
      runtime: instance_double(Lich::WebUI::Runtime),
      start: nil,
      refresh: nil,
      launch_url: 'http://127.0.0.1:1234/auth?token=redacted',
      terminate_owner: nil,
      stop: nil
    )
    recovery = []
    failed = described_class.new(
      data_dir: '/fixture', catalog: catalog, service: service, on_launch: proc {}, browser_open: proc { false },
      recovery: ->(message) { recovery << message }
    )

    expect { failed.start }.to raise_error(Lich::WebUI::Error, /dedicated launcher window failed/)
    expect(failed.lifecycle).to eq(:closed)
    expect(recovery).to contain_exactly(match(/ERROR:.*Google Chrome.*launcher has stopped/))
  end
end
# rubocop:enable Lint/ConstantDefinitionInBlock
