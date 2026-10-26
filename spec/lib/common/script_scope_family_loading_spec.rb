# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/script_scope'
require_relative '../../support/webui_shim_bindings'
require 'open3'
require 'rbconfig'

RSpec.describe 'GTK bridge family loading and Builder transactions' do
  include WebUISpecSupport::ShimBindings

  let(:scope) { Lich::Common::ScriptScope }
  let(:gtk) { scope.const_get(:Gtk, false) }
  let(:owner) { Struct.new(:name).new('family-boundary.lic') }
  let(:service) { Lich::WebUI::Service.new }

  before do
    install_webui_shim_bindings
    allow(Lich).to receive(:log)
  end

  after do
    Lich::Common::ScriptDeath.run(owner)
    service.stop
  end

  %w[widgets layout tree_view builder].each do |entry|
    it "retains #{entry} entry identity, aliases and later extensions in a fresh process" do
      code = <<~RUBY_CODE
        require 'common/script_scope'
        scope = Lich::Common::ScriptScope
        scope.activate!
        gtk = scope.const_get(:Gtk, false)
        classes = %i[Widget Window Box Notebook Label Entry ToggleButton RadioButton
                     Fixed Layout Grid ScrolledWindow CellRendererText TreeViewColumn
                     TreeSelection TreeView Builder].to_h { |name| [name, gtk.const_get(name, false)] }
        abort 'entry was not loaded by boot' unless require('common/script_scope/gtk/#{entry}') == false
        classes.each { |name, klass| abort "class replaced: \#{name}" unless gtk.const_get(name, false).equal?(klass) }
        abort 'builder catalog lost identity' unless gtk::Builder::CLASSES['GtkEntry'].equal?(gtk::Entry)
        abort 'builder identity extension missing' unless classes.values_at(:Widget, :CellRendererText).all? { |klass| klass.ancestors.include?(gtk::BuilderIdentity) }
        abort 'widget transfer extension missing' unless gtk::Widget.instance_method(:drag_source_set).owner.equal?(gtk::WidgetTransfers)
        abort 'transfer extension missing' unless gtk::TreeView.instance_method(:enable_model_drag_source).owner.equal?(gtk::TreeView)
        abort 'entry alias changed' unless gtk::Entry.instance_method(:text=).original_name == :set_text
        abort 'grid alias changed' unless gtk::Grid.instance_method(:set_row_spacing).original_name == :row_spacings=
        abort 'lookup alias changed' unless gtk::Builder.instance_method(:[]).original_name == :get_object
        abort 'widget helper exposed' unless gtk::Widget.protected_instance_methods(false).include?(:read)
        abort 'signal helper exposed' unless gtk::Widget.private_instance_methods(false).include?(:disconnect_signal_handler)
        abort 'builder helper exposed' unless gtk::Builder.private_instance_methods(false).include?(:compose)
        abort 'native Gtk escaped' if Object.const_defined?(:Gtk, false)
        puts 'ready'
      RUBY_CODE
      output, status = Open3.capture2e(RbConfig.ruby, '-I', LIB_DIR, '-e', code)
      expect(status.success?).to be(true), output
      expect(output).to eq("ready\n")
    end
  end

  it 'retires observers and pending widgets after a composition failure without damaging the prior graph' do
    builder = gtk::Builder.new
    builder.add_from_string('<interface><object class="GtkEntry" id="retained"><property name="text">Keep</property></object></interface>')
    retained = builder['retained']
    created = []
    allow(gtk::ListStore).to receive(:new).and_wrap_original do |original, *types|
      original.call(*types).tap do |store|
        created << store
        allow(store).to receive(:watch).and_call_original
      end
    end
    expect do
      builder.add_from_string(<<~XML)
        <interface>
          <object class="GtkListStore" id="store"><columns><column type="gchararray"/></columns></object>
          <object class="GtkTreeView" id="view"><property name="model">store</property></object>
          <object class="GtkGrid" id="grid"><child><object class="GtkEntry" id="candidate"/>
            <packing><property name="left-attach">24</property></packing>
          </child></object>
        </interface>
      XML
    end.to raise_error(gtk::BuilderError)
    expect(builder.objects).to eq([retained])
    expect(builder['retained']).to equal(retained)
    expect(retained.text).to eq('Keep')
    expect(created.length).to eq(1)
    expect(created.first).to have_received(:watch).with(an_instance_of(gtk::TreeView)).once
    expect(created.first.instance_variable_get(:@observers)).to be_empty
    expect { builder['candidate'] }.to raise_error(gtk::BuilderError)
    expect(service.registry.pages_for(owner)).to be_empty
    builder.add_from_string('<interface><object class="GtkEntry" id="candidate"><property name="text">Retry</property></object></interface>')
    expect(builder['candidate'].text).to eq('Retry')
    expect(builder.objects).to eq([retained, builder['candidate']])
  end
end
