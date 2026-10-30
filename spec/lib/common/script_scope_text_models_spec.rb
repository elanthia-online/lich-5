# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require_relative '../../../lib/common/script_scope/gtk/session'
require_relative '../../../lib/common/script_scope/gtk/widgets'
require_relative '../../../lib/common/script_scope/gtk/models'
require_relative '../../../lib/common/script_scope/gtk/tree_view'
require_relative '../../../lib/common/script_scope/gtk/text'

# Model, table and text boundaries: the P13 share of 1831:RC27, plus 1844:RC1,
# RC5, RC6 and RC7 and 1845:RC3 and RC5. A recording port stands in for core.
RSpec.describe 'script compatibility models, tables and text' do
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
  let(:owner) { Struct.new(:name, :thread_group).new('models.lic', ThreadGroup.new) }
  let(:port) { port_class.new }
  let(:session) { gtk::Session.new(owner) }
  let(:limit) { Lich::WebUI::Contract::BOUNDS[:table_rows] }

  before do
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    allow(Lich::WebUI).to receive(:adapter).and_return(port)
    allow(Lich::WebUI).to receive(:callback_queue).and_return(proc { |&work| work.call })
    allow(Lich).to receive(:log)
    allow(gtk).to receive(:session) { session }
  end

  def log_view(buffer = gtk::TextBuffer.new)
    view = gtk::TextView.new(buffer)
    view.set_editable(false)
    view
  end

  # Byte-built fixtures keep this source ASCII-only.
  def bytes(*values) = values.pack('C*')
  def utf8(binary) = binary.dup.force_encoding(Encoding::UTF_8)

  it 'stores binary-tagged UTF-8 cells as UTF-8 and refuses other bytes without changing the row (1831:RC27)' do
    store = gtk::ListStore.new(String)
    view = gtk::TreeView.new(store)
    view.append_column(gtk::TreeViewColumn.new('Name', gtk::CellRendererText.new, text: 0))
    view.materialize
    iter = store.append
    cafe = 'caf'.b + bytes(0xC3, 0xA9)
    invalid = 'caf'.b + bytes(0xFF)

    store.set_value(iter, 0, cafe)
    value = store.get_value(iter, 0)
    expect([value, value.encoding]).to eq([utf8(cafe), Encoding::UTF_8])
    expect(port.sets.last[1].first[:cells].values).to eq([utf8(cafe)])
    [invalid, utf8(invalid)].each do |rejected|
      expect { store.set_value(iter, 0, rejected) }.to raise_error(gtk::ModelValueError, /actual=non-UTF-8 String/)
    end
    expect(store.get_value(iter, 0)).to eq(utf8(cafe))
  end

  it 'admits binary-tagged UTF-8 text into a buffer and refuses other bytes without editing it (1831:RC27)' do
    buffer = gtk::TextBuffer.new
    cafe = utf8('caf'.b + bytes(0xC3, 0xA9))
    naive = 'na'.b + bytes(0xC3, 0xAF) + 've'.b
    resume = 'r'.b + bytes(0xC3, 0xA9) + 'sum'.b + bytes(0xC3, 0xA9)
    buffer.text = "#{cafe} "

    buffer.insert(buffer.end_iter, naive)
    expect(buffer.text).to eq("#{cafe} #{utf8(naive)}")
    buffer.text = resume
    expect([buffer.text, buffer.text.encoding]).to eq([utf8(resume), Encoding::UTF_8])
    expect { buffer.insert(buffer.end_iter, bytes(0xFF)) }.to raise_error(gtk::UnsupportedOperation, /operation=insert/)
    expect { buffer.text = bytes(0xFF) }.to raise_error(gtk::UnsupportedOperation, /operation=text=/)
    expect(buffer.text).to eq(utf8(resume))
  end

  it 'leaves an editor intact when log conversion refuses, and degrades long history (1844:RC5)' do
    long_line = 'x' * (Lich::WebUI::Contract::BOUNDS[:log_line] + 1)
    view = gtk::TextView.new
    view.buffer.text = "#{long_line}\nshort"

    expect { view.set_editable(false) }.to raise_error(gtk::UnsupportedOperation, /operation=text/)
    expect([view.send(:log?), view.editable?, view.send(:component_type), view.buffer.text]).to eq([false, true, :textarea, "#{long_line}\nshort"])

    lines = Array.new(gtk::TextBuffer::MAX_LINES + 5) { |index| "line #{index}" }
    view.buffer.text = lines.join("\n")
    view.set_editable(false)
    expect([view.send(:log?), view.editable?, view.buffer.text]).to eq([true, false, lines.last(gtk::TextBuffer::MAX_LINES).join("\n")])
  end

  it 'releases a destroyed view buffer with its text so a replacement view can bind it (1844:RC6)' do
    buffer = gtk::TextBuffer.new
    view = gtk::TextView.new(buffer)
    buffer.text = 'kept'

    view.destroy
    expect(view.destroy).to equal(view)
    replacement = gtk::TextView.new(buffer)
    expect([replacement.buffer, buffer.text]).to eq([buffer, 'kept'])
    buffer.text = 'next'
    expect(replacement.send(:buffer_text)).to eq('next')
  end

  context 'when a signal callback destroys the window holding an editor' do
    retiring_port = Class.new(port_class) do
      attr_reader :bindings, :retired_reads

      def bind(handle, event, callback) = (@bindings ||= {})[[handle, event]] = callback
      def seed(handle, property, value) = @values[[handle, property]] = value
      # Like the core adapter, retiring the root retires every subtree handle.
      def destroy(_handle) = @retired = true

      def get(handle, property)
        return super unless @retired

        (@retired_reads ||= []) << [property, 'handle is already destroyed']
        raise Lich::WebUI::Error, 'handle is already destroyed'
      end
    end
    let(:port) { retiring_port.new }

    it 'completes teardown and keeps the last editor text for a replacement view (1844:RC6)' do
      logs = []
      allow(Lich).to receive(:log) { |message| logs << message }
      buffer = gtk::TextBuffer.new
      buffer.text = 'saved'
      window = gtk::Window.new('form')
      box = gtk::VBox.new
      view = gtk::TextView.new(buffer)
      close = gtk::Button.new('Close')
      box.add(view)
      box.add(close)
      window.add(box)
      window.materialize
      port.seed(view.materialize, :value, 'typed')
      closed = []
      window.signal_connect('destroy') { closed << :window }
      close.signal_connect('clicked') { window.destroy }

      port.bindings.fetch([close.materialize, :activate]).call(Struct.new(:viewer_id, :payload).new('viewer', {}))

      expect(port.retired_reads).to be_nil
      expect(logs.grep(/callback failed/)).to be_empty
      expect([window.destroyed?, view.destroyed?, closed]).to eq([true, true, [:window]])
      expect(buffer.text).to eq('typed')
      replacement = gtk::TextView.new(buffer)
      expect([replacement.buffer, replacement.send(:buffer_text)]).to eq([buffer, 'typed'])
    end
  end

  it 'refuses out-of-capacity path and child indices with attribution while missing rows stay nil (1844:RC1)' do
    store = gtk::TreeStore.new(String)
    store.append
    huge = 2**64

    [huge, [0, huge], "0:#{huge}", limit, [limit]].each do |path|
      expect { store.get_iter(path) }.to raise_error(gtk::UnsupportedOperation, /TreePath operation=new/)
    end
    expect { store.iter_nth_child(nil, huge) }.to raise_error(gtk::UnsupportedOperation, /operation=iter_nth_child/)
    expect { store.iter_nth_child(nil, limit) }.to raise_error(gtk::UnsupportedOperation, /operation=iter_nth_child/)
    expect([store.get_iter(limit - 1), store.get_iter('0:5'), store.iter_nth_child(nil, limit - 1)]).to eq([nil, nil, nil])
    expect(gtk::TreePath.new(limit - 1).indices).to eq([limit - 1])
  end

  it 'answers selection membership without rebuilding the model rows (1844:RC7)' do
    store = gtk::ListStore.new(String)
    first, second = store.append, store.append
    view = gtk::TreeView.new(store)
    view.selection.select_iter(first)
    foreign = gtk::ListStore.new(String).append
    allow(store).to receive(:rows).and_call_original

    expect(view.selection.iter_is_selected?(first)).to be(true)
    expect(view.selection.iter_is_selected?(second)).to be(false)
    expect(view.selection.iter_is_selected?(foreign)).to be(false)
    expect([view.selection.path_is_selected?('0'), view.selection.path_is_selected?('1'), view.selection.path_is_selected?('5')]).to eq([true, false, false])
    expect(store).not_to have_received(:rows)
  end

  it 'reports a removed row as unselected even while viewer state still names it (1844:RC7)' do
    store = gtk::ListStore.new(String)
    store.append
    view = gtk::TreeView.new(store)
    stale = store.get_iter('0')
    store.remove(store.get_iter('0'))
    allow(view).to receive(:view_state).with(:selected).and_return([stale.key])

    expect(view.selection.iter_is_selected?(stale)).to be(false)
  end

  it 'keeps a valid log tail when only discarded lines are overlong (1845:RC3)' do
    view = log_view
    long_line = 'x' * (Lich::WebUI::Contract::BOUNDS[:log_line] + 1)
    tail = Array.new(gtk::TextBuffer::MAX_LINES) { |index| "line #{index}" }

    view.buffer.text = ([long_line] + tail).join("\n")
    expect(view.buffer.text).to eq(tail.join("\n"))
    expect { view.buffer.text = (tail + [long_line]).join("\n") }.to raise_error(gtk::UnsupportedOperation, /operation=text/)
    expect(view.buffer.text).to eq(tail.join("\n"))
  end

  it 'keeps a retained iterator as a current-bounds offset across edits (1845:RC5)' do
    buffer = gtk::TextBuffer.new
    buffer.text = 'abcdef'
    iter = buffer.get_iter_at_offset(4)

    buffer.text = 'XYZabcdef'
    expect(buffer.get_text(buffer.start_iter, iter)).to eq('XYZa')
    buffer.text = 'ab'
    expect { buffer.get_text(buffer.start_iter, iter) }.to raise_error(gtk::UnsupportedOperation, /operation=get_text/)
    expect { buffer.insert(gtk::TextBuffer.new.start_iter, 'x') }.to raise_error(gtk::UnsupportedOperation, /operation=insert/)
  end
end
