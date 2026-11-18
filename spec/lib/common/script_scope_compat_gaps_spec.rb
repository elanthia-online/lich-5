# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/script_scope'

RSpec.describe 'legacy GTK calls that scripts use outside the widget catalog' do
  let(:scope) { Lich::Common::ScriptScope }
  let(:gtk) { scope.const_get(:Gtk, false) }
  let(:owner) { Struct.new(:name).new('compat-gaps.lic') }
  let(:service) { Lich::WebUI::Service.new }

  before do
    scope.activate!
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    allow(Lich::WebUI).to receive(:adapter) { |owner:, viewer: nil| Lich::WebUI::Adapter.new(owner: owner, service: service, viewer: viewer) }
    allow(Lich::WebUI).to receive(:callback_queue) { |owner:| proc { |&work| service.runtime.dispatch(owner: owner, &work) } }
    allow(Lich).to receive(:log)
  end

  after do
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    Lich::Common::ScriptDeath.run(owner)
    service.stop
  end

  it 'reports one main loop level, from any script thread, so the zero-level guard skips Gtk.main' do
    expect(gtk.main_level).to eq(1)
    expect(Thread.new { gtk.main_level }.value).to eq(1)
  end

  it 'shows gtk3 as a loaded gem to scripts only while the compatibility layer presents' do
    allow(Lich::WebUI).to receive(:presentation_enabled?).and_return(true)
    spec = scope::Gem.loaded_specs['gtk3']
    expect(spec).to be_a(Gem::Specification)
    expect(spec.name).to eq('gtk3')
    expect(Gem.loaded_specs).not_to have_key('gtk3') unless Gem.loaded_specs.key?('gtk3')
    expect(scope::Gem::Version.new('1.2')).to eq(Gem::Version.new('1.2'))
    expect(scope::Gem.ruby_version).to eq(Gem.ruby_version)
    allow(Lich::WebUI).to receive(:presentation_enabled?).and_return(false)
    expect(scope::Gem.loaded_specs['gtk3']).to eq(Gem.loaded_specs['gtk3'])
  end

  it 'removes a combo row by position through the GTK2-era remove_text name' do
    combo = gtk::ComboBoxText.new
    %w[alpha beta gamma].each { |text| combo.append_text(text) }
    combo.remove_text(1)
    expect(combo.model.rows.map { |row| row[0] }).to eq(%w[alpha gamma])
    combo.remove_text(-1)
    combo.remove_text(5)
    expect(combo.model.rows.map { |row| row[0] }).to eq(%w[alpha gamma])
  end

  it 'lets a reopened script reuse a size group cached by its previous run' do
    group = gtk::SizeGroup.new(:horizontal)
    group.add_widget(gtk::Label.new('First run'))
    Lich::Common::ScriptDeath.run(owner)
    reopened = Struct.new(:name).new('compat-gaps.lic')
    allow(Lich::Common::Script).to receive(:current).and_return(reopened)
    label = gtk::Label.new('Second run')
    expect(group.add_widget(label)).to equal(group)
    expect(group.widgets).to eq([label])
    stranger = Struct.new(:name).new('other.lic')
    allow(Lich::Common::Script).to receive(:current).and_return(stranger)
    expect { group.add_widget(gtk::Label.new('Foreign')) }.to raise_error(gtk::UnsupportedOperation)
  ensure
    allow(Lich::Common::Script).to receive(:current).and_return(reopened) if reopened
    Lich::Common::ScriptDeath.run(reopened) if reopened
    Lich::Common::ScriptDeath.run(stranger) if defined?(stranger) && stranger
  end
end
