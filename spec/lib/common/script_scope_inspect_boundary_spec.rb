# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../support/webui_shim_bindings'
require 'pp'
require 'yaml'
require 'tmpdir'
require 'timeout'
require_relative '../../../lib/common/script_scope'

RSpec.describe 'session credential inspection boundary' do
  include WebUISpecSupport::ShimBindings

  let(:scope) { Lich::Common::ScriptScope }
  let(:owner) { Struct.new(:name).new('inspect.lic') }
  let(:service) { Lich::WebUI::Service.new }
  let(:compatibility) { scope.const_get(:Gtk, false) }
  let(:session_token) { service.server.instance_variable_get(:@session_token) }

  before do
    install_webui_shim_bindings
    allow(Lich).to receive(:log)
  end

  after do
    Lich::Common::ScriptDeath.run(owner)
    service.stop
  end

  # Every text form a script can obtain from a value by echoing or printing it.
  def renderings(value)
    [value.inspect, value.to_s, PP.pp(value, +''), "#{value}", format('%p', value), YAML.dump(value)]
  end

  # Size of a fresh label's rendering, which embeds its session summary.
  def built_label_size(session)
    compatibility::Label.new('Boon').tap { |label| expect(label.session).to equal(session) }.inspect.bytesize
  end

  def widgets
    window = compatibility::Window.new
    box = compatibility::Box.new(:vertical)
    label = compatibility::Label.new('Boon')
    button = compatibility::Button.new('Refresh')
    button.signal_connect('clicked') { nil }
    box.pack_start(label)
    box.pack_start(button)
    window.add(box)
    { window: window, box: box, label: label, button: button }
  end

  # Attaches a viewer through the runtime and returns the resume token it was sent.
  def attach_viewer(page)
    sent = []
    connection = double('boundary viewer', viewer_id: 'boundary-viewer-5c1e', alive?: true)
    allow(connection).to receive(:send_text) { |json| sent << JSON.parse(json) }
    service.runtime.handle(connection, type: 'attach', page: service.registry.address_for(page))
    sent.filter_map { |message| message['resume'] }.first
  end

  def native_page
    service.registry.register(Lich::WebUI::Page.new(owner: owner, id: 'boundary', title: 'Boundary') do
      password_input(key: 'password')
    end)
  end

  it 'keeps the session token out of every rendering of shim widgets and their collections' do
    built = widgets
    expect(session_token).to match(/\A\h{64}\z/)
    subjects = built.values + [built, built.values, { nested: [built] }]

    subjects.each do |subject|
      renderings(subject).each { |text| expect(text).not_to include(session_token) }
    end
  end

  it 'keeps session and resume tokens out of a shown window with an attached viewer' do
    built = widgets
    built[:window].show_all
    page = nil
    Timeout.timeout(2) { sleep 0.001 until (page = service.registry.pages_for(owner).first)&.last_render }
    resume_token = attach_viewer(page)
    expect(resume_token).to match(/\Aresume-\h{32}\z/)

    (built.values + [built]).each do |subject|
      renderings(subject).each do |text|
        expect(text).not_to include(session_token)
        expect(text).not_to include(resume_token)
        expect(text).not_to include('boundary-viewer-5c1e')
        expect(text).not_to include('Adapter::Node')
      end
    end
  end

  it 'keeps session and resume tokens out of a native page with an attached viewer' do
    page = native_page
    resume_token = attach_viewer(page)
    expect(resume_token).to match(/\Aresume-\h{32}\z/)

    renderings(page).each do |text|
      expect(text).not_to include(session_token)
      expect(text).not_to include(resume_token)
      expect(text).not_to include('boundary-viewer-5c1e')
    end
  end

  %i[runtime modals].each do |reader|
    it "keeps session and resume tokens out of the service #{reader} with an attached viewer" do
      resume_token = attach_viewer(native_page)
      expect(resume_token).to match(/\Aresume-\h{32}\z/)

      renderings(service.public_send(reader)).each do |text|
        expect(text).not_to include(session_token)
        expect(text).not_to include(resume_token)
      end
    end
  end

  %i[runtime modals].each do |reader|
    it "keeps a queued attach reply's resume token out of the service #{reader}" do
      page = native_page
      near, far = UNIXSocket.pair
      connection = Lich::WebUI::Server::Connection.new(near, thread_factory: ->(&_writer) {})
      service.runtime.handle(connection, type: 'attach', page: service.registry.address_for(page))
      resume_token = connection.instance_variable_get(:@queue).join[/resume-\h{32}/]
      expect(resume_token).not_to be_nil

      renderings(service.public_send(reader)).each do |text|
        binary = text.scan(/!binary \|-?\n((?:[ \t]+\S+\n)+)/).map { |(encoded)| encoded.unpack1('m') }
        expect(text).not_to include(resume_token)
        expect(binary.join).not_to include(resume_token)
      end
      expect(connection.inspect).to eq(
        "#<Lich::WebUI::Server::Connection viewer_id=#{connection.viewer_id.inspect} alive=true>"
      )
    ensure
      [near, far].each { |socket| socket&.close }
    end
  end

  it 'renders the viewer store and an attachment without the resume token' do
    page = native_page
    resume_token = attach_viewer(page)
    store = service.runtime.instance_variable_get(:@viewers)
    attachment = store.attachments_for(page).first
    expect(attachment.resume_token).to eq(resume_token)

    [store, attachment, [attachment]].each do |subject|
      renderings(subject).each { |text| expect(text).not_to include(resume_token) }
    end
    expect(store.inspect).to eq('#<Lich::WebUI::ViewerStore attachments=1>')
    expect(attachment.inspect).to eq(
      "#<Lich::WebUI::ViewerStore::Attachment viewer_id=#{attachment.viewer_id.inspect} resume_state=:fresh>"
    )
  end

  it 'keeps a native password input value out of every rendering of its component' do
    input = Lich::WebUI::Component.new(
      type: :password_input, cid: 'password_input:master',
      props: { label: 'Password', value: 'canary-boundary-91fe', sensitive: true }
    )
    parent = Lich::WebUI::Component.new(type: :group, cid: 'group:0', props: {}, children: [input])

    [input, parent, [input], { nested: parent }].each do |subject|
      renderings(subject).each { |text| expect(text).not_to include('canary-boundary-91fe') }
    end
    expect(input.props[:value]).to eq('canary-boundary-91fe')
  end

  it 'keeps widget class names in the rendering for debugging' do
    built = widgets

    expect(built[:label].inspect).to include('Lich::Common::ScriptScope::Gtk::Label')
    expect(built.inspect).to include('Gtk::Window', 'Gtk::Button')
  end

  it 'renders each object between a widget and the server opaquely' do
    session = widgets[:label].session
    path = [session, session.port, service, service.server]

    path.each do |object|
      renderings(object).each { |text| expect(text).not_to include(session_token) }
      expect(object.inspect).to start_with("#<#{object.class.name}")
      expect(object.inspect.bytesize).to be < 200
      expect(PP.pp(object, +'').chomp).to eq(object.inspect)
    end
    expect(session.inspect).to eq('#<Lich::Common::ScriptScope::Gtk::Session owner="inspect.lic">')
    expect(session.port.inspect).to eq('#<Lich::WebUI::Adapter owner="inspect.lic">')
    expect(service.inspect).to eq('#<Lich::WebUI::Service stopped=false>')
  end

  it 'bounds a long or multi-line owner label to one printable line in each summary' do
    session = widgets[:label].session
    plain_adapter, plain_session = session.port.inspect, session.inspect
    [128, 512, 2048].each do |size|
      owner.name = "boon\r\nINJECTED #{'W' * size}"

      [session, session.port].each do |object|
        expect(object.inspect).to match(/\A[\x20-\x7E]+\z/)
        expect(object.inspect).to include('owner="boon INJECTED WWW')
        expect(object.inspect.bytesize).to be < 200
      end
      expect(built_label_size(session)).to be < 4096
    end
    owner.name = 'inspect.lic'
    expect([session.port.inspect, session.inspect]).to eq([plain_adapter, plain_session])
  end

  it 'keeps the token out of errors raised through the shim and its host objects' do
    built = widgets
    session = built[:label].session
    messages = [built[:label], session, session.port, service, service.server].flat_map do |object|
      error = begin
        object.public_send(:no_such_shim_operation)
      rescue StandardError => raised
        raised
      end
      [error.message, error.full_message(highlight: false), error.inspect, "failed: #{object}"]
    end

    messages.each { |text| expect(text).not_to include(session_token) }
  end

  it 'keeps session and launch credentials out of a running server rendering' do
    server = service.start.server
    launch_token = server.launch_url[/token=(\h+)/, 1]

    renderings(server).each do |text|
      expect(text).not_to include(session_token)
      expect(text).not_to include(launch_token)
    end
    expect(server.inspect).to eq("#<Lich::WebUI::Server host=\"127.0.0.1\" port=#{server.port} running=true>")
    expect(service.inspect).to eq('#<Lich::WebUI::Service stopped=false>')
  end
end
