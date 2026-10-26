# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../login_spec_helper'
require 'common/webui_launcher'
require_relative '../../support/webui_launcher_fakes'
require_relative '../../support/webui_browser'

RSpec.describe 'WebUI Launcher presentation', browser: true do
  it 'preserves saved layouts, favorite actions and frontend form geometry in Chrome' do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'

    fixtures = WebUISpecSupport::Launcher
    entries = [fixtures::Entry.new('entry-0', 'SYNTHETIC', 'Aldor', 'GS3', 'GemStone IV', 'stormfront', nil, nil, true, 1),
               fixtures::Entry.new('entry-1', 'SYNTHETIC', 'Bera', 'DR', 'DragonRealms', 'wizard', nil, nil, false, nil)]
    catalog = fixtures::ReduxCatalogFixture.new(entries: entries)
    catalog.define_singleton_method(:toggle_favorite) do |key|
      @mutations << [:favorite, key]
      @entries = @entries.map { |entry| entry.key == key ? entry.with(favorite: !entry.favorite) : entry }
    end
    service = Lich::WebUI::Service.new
    geometry = { width: 960, height: 720 }
    store = instance_double(Lich::Common::WebUILauncher::WindowGeometryStore, load: geometry, save: geometry)
    launcher = Lich::Common::WebUILauncher.new(
      data_dir: '/fixture', catalog: catalog, service: service, executor: fixtures::ImmediateExecutor.new,
      geometry_store: store, on_launch: proc {}, browser_open: proc { true }, frontend_locator: fixtures::ReduxFrontendLocator
    )
    editor = launcher.instance_variable_get(:@frontend_tab)
    editor.instance_variable_get(:@state).merge!(
      frontends: [{ id: 'stormfront', label: 'Wrayth', type: 'built-in', status: 'Detected', launch: '/fixture/client', arguments: '' }],
      frontend_draft: { id: 'stormfront', label: 'Wrayth', built_in: true, command: '', directory: '', arguments: '',
                        detected_command: '/fixture/client', capabilities: ['xml'] }
    )
    launches = []
    # Capture only the script/session boundary; real authentication and spawning
    # are outside a synthetic presentation check. The production binding is used.
    launcher.define_singleton_method(:saved_launch) do |event, key|
      launches << [key, event.viewer_id]
      set_notice('Synthetic Play received', :info)
    end
    launcher.start
    page = service.registry.pages_for(launcher).fetch(0)
    controls = {}
    controls[:capture] = ENV['LAUNCHER_PRESENTATION_CAPTURE'] if ENV['LAUNCHER_PRESENTATION_CAPTURE']
    WebUIBrowser.check(service: service, page: page, scenario: 'launcher-presentation', controls: controls)
    expect(launches.map(&:first)).to eq(['entry-0'])
    expect(launches.first.last).to be_a(String)
    expect(catalog.mutations).to eq([[:favorite, 'entry-0'], [:favorite, 'entry-0']])
  ensure
    launcher&.close
    service&.stop
  end
end
