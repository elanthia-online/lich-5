# frozen_string_literal: true

require_relative '../../../spec_helper'
require_relative '../../../login_spec_helper'
require 'common/webui_launcher'
require_relative '../../../support/webui_launcher_fakes'
require 'open3'
require 'rbconfig'

RSpec.describe Lich::Common::WebUILauncher, 'presentation boundaries' do
  let(:entry) { WebUISpecSupport::Launcher::Entry.new('entry-0', 'SYNTHETIC', 'Alpha', 'GS3', 'GemStone IV', 'stormfront', nil, nil, true, 1) }
  let(:catalog) { WebUISpecSupport::Launcher::ReduxCatalogFixture.new(entries: [entry]) }
  let(:launcher) do
    described_class.new(data_dir: '/fixture', catalog: catalog, on_launch: proc {}, browser_open: proc { true },
                        service: WebUISpecSupport::Launcher::WorkflowService.new,
                        executor: WebUISpecSupport::Launcher::ImmediateExecutor.new,
                        frontend_locator: WebUISpecSupport::Launcher::ReduxFrontendLocator)
  end

  after { launcher.close }

  # Resolves one control by its stable authored key, independently of ancestor CIDs.
  # @param render [Lich::WebUI::Page::Render] completed page render
  # @param suffix [String] component type and authored key
  # @return [Lich::WebUI::Component] matching control
  def control(render, suffix)
    render.tree.each.find { |node| node.cid.end_with?(suffix) }
  end

  %w[common/webui_launcher common/webui_launcher/frontend_tab].each do |entry_path|
    it "retains controller identity and visibility when loaded through #{entry_path}" do
      code = <<~RUBY_CODE
        require File.join(ARGV.fetch(0), 'spec/spec_helper')
        require File.join(ARGV.fetch(0), 'spec/login_spec_helper')
        require '#{entry_path}'
        controller = Lich::Common::WebUILauncher
        editor = controller::FrontendTab
        require 'common/webui_launcher'
        require 'common/webui_launcher/frontend_tab'
        abort 'controller replaced' unless controller.equal?(Lich::Common::WebUILauncher)
        abort 'editor replaced' unless editor.equal?(controller::FrontendTab)
        abort 'manual callback lost' unless controller.public_instance_methods(false).include?(:manual_connect)
        abort 'account callback lost' unless controller.public_instance_methods(false).include?(:save_character)
        abort 'view exposed' unless controller.private_instance_methods(false).include?(:render_manual)
        abort 'operation gate exposed' unless controller.private_instance_methods(false).include?(:commit)
        abort 'worker launch exposed' unless controller.private_instance_methods(false).include?(:perform_saved_launch)
        abort 'editor decoder exposed' unless editor.private_instance_methods(false).include?(:frontend_fields_from)
        puts 'ready'
      RUBY_CODE
      root = File.expand_path('../../../..', __dir__)
      output, status = Open3.capture2e(RbConfig.ruby, '-I', LIB_DIR, '-e', code, root)
      expect(status.success?).to be(true), output
      expect(output).to eq("ready\n")
    end
  end

  it 'renders captured forms without rereading mutable controller state or exposing retained credentials' do
    carrier = Lich::WebUI::SensitiveValue.viewer('synthetic-render-exclusion')
    launcher.instance_variable_get(:@manual_credentials)['viewer'] = carrier
    snapshot = launcher.send(:render_state)
    launcher.instance_variable_get(:@entries).clear
    launcher.instance_variable_set(:@frontend_options, [])
    launcher.instance_variable_get(:@manual)[:account] = 'CHANGED-AFTER-CAPTURE'
    %i[entries accounts encryption_mode enhanced_encryption_available?].each do |method|
      expect(catalog).not_to receive(method)
    end
    expect(WebUISpecSupport::Launcher::ReduxFrontendLocator).not_to receive(:available)
    expect(WebUISpecSupport::Launcher::ReduxFrontendLocator).not_to receive(:resolve)
    controller = launcher
    render = Lich::WebUI::Page.new(owner: controller, id: 'snapshot', title: 'Captured state') do
      controller.send(:render_saved, self, snapshot)
      controller.send(:render_manual, self, snapshot)
      controller.send(:render_accounts, self, snapshot)
      controller.send(:render_encryption, self, snapshot)
    end.render
    expect(control(render, 'table:accounts-table').props[:rows].map { |row| row[:cells]['character'] }).to eq(['Alpha'])
    expect(control(render, 'text_input:manual-account').props[:value]).to eq('')
    expect(control(render, 'select:manual-frontend').props[:options]).not_to be_empty
    expect(JSON.generate(render.tree.to_h)).not_to include('synthetic-render-exclusion', 'CHANGED-AFTER-CAPTURE')
    expect(snapshot).not_to have_key(:manual_credentials)
    expect(carrier).not_to be_consumed
  end

  it 'pairs each form submission scope with its existing named callback' do
    render = launcher.send(:build_page).render
    forms = {
      'manual-connect'    => [:manual_connect, %w[text_input:manual-account password_input:manual-password]],
      'manual-play'       => [:manual_play, %w[select:manual-frontend checkbox:manual-custom-enabled text_input:manual-custom text_input:manual-custom-dir checkbox:manual-save checkbox:manual-favorite]],
      'character-save'    => [:save_character, %w[select:character-account text_input:character-name select:character-game select:character-frontend text_input:character-custom text_input:character-custom-dir]],
      'account-add'       => [:save_account, %w[text_input:account-name password_input:account-password select:account-frontend]],
      'encryption-change' => [:change_encryption, %w[radio:encryption-mode password_input:encryption-master password_input:encryption-confirm checkbox:encryption-plaintext-confirm]],
      'master-change'     => [:change_master_password, %w[password_input:master-current password_input:master-new password_input:master-confirm]],
    }
    forms.each do |key, (handler, suffixes)|
      button = control(render, "button:#{key}")
      cids = render.submissions.fetch(button.cid)
      expect(cids.map { |cid| cid.split('/').last }).to eq(suffixes)
      event = WebUISpecSupport::Launcher::Event.new('viewer', {}, nil)
      arguments = key == 'manual-connect' ? [event, *cids] : [event]
      expect(launcher).to receive(handler).with(*arguments)
      render.bindings.fetch([button.cid, :activate]).call(event)
    end
  end

  it 'decodes a character save from the exact fields declared by its rendered action' do
    render = launcher.send(:build_page).render
    action = control(render, 'button:character-save')
    values = render.submissions.fetch(action.cid).to_h do |cid|
      value = { 'select:character-account' => 'SYNTHETIC', 'text_input:character-name' => 'Beta',
                'select:character-game' => 'DR', 'select:character-frontend' => 'stormfront',
                'text_input:character-custom' => '', 'text_input:character-custom-dir' => '' }.fetch(cid.split('/').last)
      [cid, value]
    end
    event = WebUISpecSupport::Launcher::Event.new('viewer', {}, Lich::WebUI::Submission.new(viewer_id: 'viewer', values: values))
    render.bindings.fetch([action.cid, :activate]).call(event)
    expect(catalog.mutations).to eq([[:add_character, 'SYNTHETIC', {
      char_name: 'Beta', game_code: 'DR', game_name: 'DragonRealms', frontend: 'stormfront', custom_launch: nil, custom_launch_dir: nil,
    }]])
    expect(launcher.active_operations).to be_empty
  end

  it 'routes frontend Save fields and capabilities through the existing decoder before queuing work' do
    tab = launcher.instance_variable_get(:@frontend_tab)
    tab.begin_new_frontend
    render = launcher.send(:build_page).render
    action = control(render, 'button:frontend-save')
    fields = { 'frontend-id' => 'synthetic-client', 'frontend-label' => 'Synthetic client',
               'frontend-command' => '/fixture/client', 'frontend-directory' => '', 'frontend-arguments' => '--flag "two words"' }
    values = render.submissions.fetch(action.cid).to_h do |cid|
      type, key = cid.split('/').last.split(':', 2)
      [cid, type == 'checkbox' ? key == 'frontend-capability-xml' : fields.fetch(key)]
    end
    event = WebUISpecSupport::Launcher::Event.new('viewer', {}, Lich::WebUI::Submission.new(viewer_id: 'viewer', values: values))
    expect(tab).to receive(:frontend_fields_from).with(event).and_wrap_original do |decoder, submitted|
      decoder.call(submitted).tap do |decoded|
        expect(decoded).to eq(id: 'synthetic-client', label: 'Synthetic client', command: '/fixture/client',
                              directory: '', arguments: '--flag "two words"', capabilities: ['xml'])
      end
    end
    expect(tab).to receive(:queue_edit)
    render.bindings.fetch([action.cid, :activate]).call(event)
  end
end
