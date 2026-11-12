# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# Remix's m_oScriptList / m_oScriptListNew (FormMain.cs:3182-3183, 3401-3426, 3809-3835,
# 4516-4541, 4678-4714, 8339-8351 R) with Lich's deterministic tick end: the end of a script's
# run. End to end against the Remix goldens: flow t158-t165 (flow_parity_spec).
RSpec.describe Lich::Genie::ScriptList do
  subject(:list) { described_class.new }

  # A host handle; equal by VALUE (like the flow harness's Hash entries) so a list that compared
  # with == instead of identity would confuse two copies of one script.
  let(:handle_class) do
    Struct.new(:genie_file_name, :seen) do
      def genie_listed = (self.seen = (seen || 0) + 1)
    end
  end

  def handle(file) = handle_class.new(file)

  describe 'membership' do
    it 'keeps a launched script out of the list until its first run is over (a typed launch: no launcher)' do
      hunt = handle('hunt.cmd')
      list.launched(hunt)
      expect([list.listed?(hunt), list.frozen?(hunt), list.listed]).to eq([false, false, []])
      expect(list.run_ended(hunt)).to be(true) # listed: the "scriptlist" change is due
      expect([list.listed?(hunt), list.frozen?(hunt), list.value]).to eq([true, false, 'hunt'])
    end

    it 'lists a child only once its own first run AND its launcher\'s run are over, in launch order' do
      parent = handle('parent.cmd')
      child = handle('child.cmd')
      list.launched(parent)
      list.launched(child, launcher: parent)
      expect(list.run_ended(child)).to be(false) # the parent is still in its run (Remix: the same tick)
      expect([list.frozen?(child), list.listed?(child)]).to eq([true, false])
      list.run_ended(parent)
      expect(list.listed).to eq([parent, child])
      expect(list.value).to eq('parent|child')
    end

    it 'lists a child whose launcher run ended before the child\'s own first run did, at the child\'s run end' do
      parent = handle('parent.cmd')
      child = handle('child.cmd')
      list.launched(parent)
      list.run_ended(parent)
      list.launched(child, launcher: parent)
      list.run_ended(parent) # the launcher's run ends again: the child is released, not ready
      expect(list.listed?(child)).to be(false)
      expect(list.run_ended(child)).to be(true)
      expect(list.listed).to eq([parent, child])
    end

    # Remix: every script launched inside one synchronous run sits in m_oScriptListNew until the
    # tick end, and AddScripts lists them together in launch order (FormMain.cs:4691-4699,
    # 3809-3835 R). Flow p05/p06 shape: a grandchild is never listed before
    # its ancestors' runs are over.
    it 'lists a grandchild chain only at the end of the outermost run, in launch order' do
      a = handle('a.cmd')
      b = handle('b.cmd')
      c = handle('c.cmd')
      d = handle('d.cmd')
      list.launched(a)
      list.launched(b, launcher: a)
      list.launched(c, launcher: b)
      list.launched(d, launcher: c)
      list.finished(d) # ends inside its first run
      list.run_ended(c) # (stores "none": D's end changed the list)
      expect(list.run_ended(b)).to be(false) # B's run is over, but B itself is not listed: neither is C
      expect([list.listed, list.value, list.frozen?(c)]).to eq([[], 'none', true])
      expect(list.run_ended(a)).to be(true)
      expect(list.listed).to eq([a, b, c])
      expect(list.value).to eq('a|b|c')
    end

    it 're-parents the pending children of a pending script that finished to its launcher (listed launcher)' do
      a = handle('a.cmd')
      list.launched(a)
      list.run_ended(a)
      b = handle('b.cmd')
      c = handle('c.cmd')
      list.launched(b, launcher: a)
      list.launched(c, launcher: b)
      list.run_ended(c)
      list.finished(b) # B ends in its first run: C waits for A's run, not B's
      expect([list.listed, list.frozen?(c)]).to eq([[a], true])
      expect(list.run_ended(a)).to be(true)
      expect(list.listed).to eq([a, c])
    end

    it 're-parents to a pending grand-launcher, listing both at its run end in launch order' do
      x = handle('x.cmd')
      a = handle('a.cmd')
      b = handle('b.cmd')
      list.launched(x)
      list.launched(a, launcher: x)
      list.launched(b, launcher: a)
      list.run_ended(b)
      list.finished(a)
      expect(list.listed).to eq([])
      list.run_ended(x)
      expect(list.listed).to eq([x, b])
    end

    it 're-parents to no launcher when the finished pending script had none: listed at once' do
      a = handle('a.cmd')
      b = handle('b.cmd')
      list.launched(a)
      list.launched(b, launcher: a)
      list.run_ended(b)
      list.finished(a) # a typed launch that ends in its first run
      expect(list.listed).to eq([b])
    end

    it 'keeps a ready child pending while its launcher is ready but held by its own launcher' do
      a = handle('a.cmd')
      list.launched(a)
      list.run_ended(a)
      b = handle('b.cmd')
      c = handle('c.cmd')
      list.launched(b, launcher: a)
      list.launched(c, launcher: b)
      list.run_ended(c)
      list.run_ended(b)
      list.run_ended(b) # a second run end of the still-pending B releases nothing either
      expect([list.listed, list.frozen?(b), list.frozen?(c)]).to eq([[a], true, true])
      list.run_ended(a)
      expect(list.listed).to eq([a, b, c])
    end

    it 'releases the children of a launcher that finished (aborted) mid-run' do
      parent = handle('parent.cmd')
      child = handle('child.cmd')
      list.launched(parent)
      list.launched(child, launcher: parent)
      list.run_ended(child)
      list.finished(parent)
      expect(list.listed).to eq([child])
    end

    it 'ignores a second launch of a script already pending or listed' do
      hunt = handle('hunt.cmd')
      2.times { list.launched(hunt) }
      list.run_ended(hunt)
      list.launched(hunt)
      expect([list.listed, list.frozen?(hunt)]).to eq([[hunt], false])
    end

    it 'compares handles by identity, never by value' do
      one = handle('same.cmd')
      two = handle('same.cmd')
      expect(one).to eq(two)
      list.launched(one)
      list.launched(two)
      list.run_ended(one)
      expect(list.listed.map(&:object_id)).to eq([one.object_id])
      list.finished(two)
      expect(list.listed.map(&:object_id)).to eq([one.object_id])
    end

    it 'tells a newly listed handle once, outside its lock (the handle may call back in)' do
      hunt = handle('hunt.cmd')
      watcher = handle('watcher.cmd')
      registry = list
      probes = []
      watcher.define_singleton_method(:genie_listed) { probes << registry.listed?(self) } # would deadlock under the lock
      [hunt, watcher].each { |s| registry.launched(s) }
      [hunt, watcher].each { |s| registry.run_ended(s) }
      registry.run_ended(hunt)
      expect([hunt.seen, probes]).to eq([1, [true]])
    end
  end

  describe '$scriptlist (SetScriptListVariable at a tick end)' do
    it 'is "none" before any tick end and after the last script left' do
      expect(list.value).to eq('none')
      hunt = handle('hunt.cmd')
      list.launched(hunt)
      list.run_ended(hunt)
      list.finished(hunt)
      expect(list.value).to eq('hunt') # finished does not store
      expect(list.tick_end).to be(true)
      expect(list.value).to eq('none')
    end

    it 'keeps the old value after an abort until a run ends, then stores it once' do
      a = handle('a.cmd')
      b = handle('b.cmd')
      [a, b].each { |s| list.launched(s) }
      [a, b].each { |s| list.run_ended(s) }
      list.finished(b)
      expect(list.value).to eq('a|b')
      expect(list.run_ended(a)).to be(true)
      expect(list.value).to eq('a')
      expect(list.run_ended(a)).to be(false) # nothing changed since
    end

    # Flow t170: a first run nested in its launcher's run happens inside
    # the launcher's row in Remix (FormMain.cs:4700-4714 R); SetScriptListVariable waits for the
    # tick end after the whole chain (FormMain.cs:8345-8351 R).
    it 'stores nothing at the end of a first run nested in its launcher\'s run, and stores at the launcher\'s run end' do
      parent = handle('parent.cmd')
      old = handle('kid.cmd')
      list.launched(parent)
      list.run_ended(parent)
      list.launched(old, launcher: parent)
      list.run_ended(old)
      list.run_ended(parent) # parent|kid stored
      list.finished(old) # the relaunch's dupe abort: changed, not stored
      fresh = handle('kid.cmd')
      list.launched(fresh, launcher: parent)
      expect([list.run_ended(fresh), list.value]).to eq([false, 'parent|kid'])
      expect([list.run_ended(parent), list.value]).to eq([true, 'parent|kid'])
      expect(list.listed).to eq([parent, fresh])
    end

    it 'stores at the end of a first run that is not nested: its launcher\'s run is over, or it had none' do
      parent = handle('parent.cmd')
      list.launched(parent)
      list.run_ended(parent)
      late = handle('late.cmd')
      list.launched(late, launcher: parent)
      list.run_ended(parent) # the launcher's run is over before the child's first run ends
      expect([list.run_ended(late), list.value]).to eq([true, 'parent|late'])
      orphan = handle('orphan.cmd')
      list.launched(orphan, launcher: late)
      list.finished(late) # a finished launcher releases it
      expect([list.run_ended(orphan), list.value]).to eq([true, 'parent|orphan'])
    end

    it 'raises the change for a pause/resume status change although the value is the same' do
      a = handle('a.cmd')
      list.launched(a)
      list.run_ended(a)
      list.changed!
      expect([list.tick_end, list.tick_end, list.value]).to eq([true, false, 'a'])
    end

    it 'names each script by GetFileNameWithoutExtension of its FileName' do
      %w[x.y.cmd sub/deep.cmd].each do |file|
        h = handle(file)
        list.launched(h)
        list.run_ended(h)
      end
      expect(list.value).to eq('x.y|deep')
    end

    it 'stores at once only off a script thread (no ParseDispatch owner)' do
      a = handle('a.cmd')
      list.launched(a)
      list.run_ended(a)
      list.changed!
      expect(Lich::Genie::ParseDispatch.as_owner(Object.new) { list.tick_end_outside_script }).to be(false)
      expect(list.tick_end_outside_script).to be(true)
    end
  end

  describe '#duplicates (LoadScript\'s dupe check)' do
    it 'walks only the listed scripts and compares the FileName exactly' do
      listed = handle('hunt.cmd')
      pending = handle('hunt.cmd')
      other = handle('Hunt.cmd')
      [listed, other].each { |s| list.launched(s) }
      [listed, other].each { |s| list.run_ended(s) }
      list.launched(pending)
      expect(list.duplicates('hunt.cmd').map(&:object_id)).to eq([listed.object_id])
      expect(list.duplicates('nope.cmd')).to eq([])
    end
  end

  describe '#launch_depth (first runs nested in first runs)' do
    it 'counts only launchers still in their first run, and refuses past LIMIT through the host' do
      chain = [handle('s.cmd')]
      list.launched(chain.first)
      expect(list.launch_depth(chain.first)).to eq(2)
      (described_class::LIMIT - 1).times do
        nxt = handle('s.cmd')
        list.launched(nxt, launcher: chain.last)
        chain << nxt
      end
      expect(list.launch_depth(chain.last)).to eq(described_class::LIMIT + 1)
      list.run_ended(chain.last)
      expect(list.launch_depth(chain.last)).to eq(1) # its first run is over: a fresh launch
      expect(list.launch_depth(nil)).to eq(1)
    end
  end

  describe '#wait_first_run (the launcher side of the synchronous first run)' do
    it 'returns at once for a script not pending, already run, or finished' do
      ran = handle('ran.cmd')
      done = handle('done.cmd')
      list.launched(ran)
      list.run_ended(ran)
      list.launched(done)
      list.finished(done)
      expect([handle('x.cmd'), ran, done].map { |s| list.wait_first_run(s, timeout: 5) }).to eq([true, true, true])
    end

    it 'blocks until the child\'s run ends on another thread' do
      child = handle('child.cmd')
      list.launched(child, launcher: handle('parent.cmd'))
      waiter = Thread.new { list.wait_first_run(child, timeout: 5) }
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      Thread.pass until waiter.status == 'sleep' || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      expect(waiter.status).to eq('sleep')
      list.run_ended(child)
      expect(waiter.join(5)&.value).to be(true)
    end

    it 'wakes when the child finishes without ever waiting' do
      child = handle('child.cmd')
      list.launched(child)
      waiter = Thread.new { list.wait_first_run(child, timeout: 5) }
      Thread.pass until waiter.status == 'sleep' || !waiter.alive?
      list.finished(child)
      expect(waiter.join(5)&.value).to be(true)
    end

    it 'gives up after its timeout' do
      child = handle('child.cmd')
      list.launched(child)
      expect(list.wait_first_run(child, timeout: 0.01)).to be(false)
      expect(list.wait_first_run(child, timeout: 0)).to be(false)
    end
  end
end
