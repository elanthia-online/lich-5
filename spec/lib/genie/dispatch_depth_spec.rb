# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# The nesting cap (a decided divergence: Remix recurses until the client crashes): nested
# trigger/#parse dispatch stops at LIMIT levels.
RSpec.describe Lich::Genie::DispatchDepth do
  let(:limit) { described_class::LIMIT }

  # Recurse through nest until +stop_at+ levels (or forever when nil), recording each depth.
  def recurse(seen, overflows, stop_at: nil)
    described_class.nest('#parse X', on_overflow: ->(m) { overflows << m }) do
      seen << described_class.current
      recurse(seen, overflows, stop_at: stop_at) unless stop_at && described_class.current >= stop_at
      :done
    end
  end

  it 'allows exactly LIMIT nested levels and reports the overflow once, at the outermost level' do
    seen = []
    overflows = []
    recurse(seen, overflows)
    expect(seen).to eq((1..limit).to_a)
    expect(overflows).to eq(["Script error: maximum nested dispatch depth (#{limit}) exceeded on: #parse X"])
    expect(described_class.current).to eq(0)
  end

  it 'runs a chain of exactly LIMIT levels without any overflow and returns the block value' do
    seen = []
    overflows = []
    expect(recurse(seen, overflows, stop_at: limit)).to eq(:done)
    expect(seen.last).to eq(limit)
    expect(overflows).to be_empty
  end

  it 'restores the depth when the block raises something else' do
    expect { described_class.nest('x', on_overflow: ->(_m) {}) { raise ArgumentError, 'boom' } }.to raise_error(ArgumentError)
    expect(described_class.current).to eq(0)
  end

  it 'counts each thread on its own (a chain on one script thread never caps another)' do
    other = nil
    described_class.nest('x', on_overflow: ->(_m) {}) do
      described_class.nest('x', on_overflow: ->(_m) {}) do
        other = Thread.new { described_class.current }.value
        expect(described_class.current).to eq(2)
      end
    end
    expect(other).to eq(0)
  end

  it 'lets an inner overflow unwind past inner on_overflow handlers (only the outermost one runs)' do
    calls = []
    build = lambda do |level|
      described_class.nest("lvl#{level}", on_overflow: ->(_m) { calls << level }) { build.call(level + 1) }
    end
    build.call(1)
    expect(calls).to eq([1])
  end

  # The glue's script-output feed runs inside Lich's respond, whose
  # `rescue => e` (lib/global_defs.rb:1761-1798) swallows any exception. The feed hands the
  # overflow to .defer instead; the enclosing nest/resume_at re-raises it.
  describe '.defer (an overflow caught by a host callback that rescues everything)' do
    # Lich's respond/_respond shape: run the block, log and swallow any StandardError.
    def lich_respond(log)
      yield
    rescue StandardError => e
      log << "error: respond: #{e}"
    end

    # The feed: dispatch nested past the cap, hand the overflow to .defer (as the glue does).
    def feed_overflowing_chain
      build = ->(n) { described_class.nest("lvl#{n}", on_overflow: ->(_m) { raise 'inner handler must not run' }) { build.call(n + 1) } }
      build.call(1)
    rescue described_class::Exceeded => e
      described_class.defer(e)
    end

    it 're-raises a deferred overflow when the enclosing nest block ends: one report, at the outermost level' do
      overflows = []
      lich_log = []
      after = []
      described_class.nest('#echo LOOP', on_overflow: ->(m) { overflows << m }) do
        described_class.nest('#echo LOOP', on_overflow: ->(_m) { raise 'not outermost' }) do
          lich_respond(lich_log) { feed_overflowing_chain }
          after << :same_block # plain commands after the swallowed respond still run ...
        end
        after << :outer_block # ... but the enclosing level does not continue
      end
      expect(after).to eq([:same_block])
      expect(overflows.size).to eq(1)
      expect(overflows.first).to include("maximum nested dispatch depth (#{limit}) exceeded")
      expect(lich_log).to be_empty
      expect(described_class.current).to eq(0)
    end

    it 'makes a later nest on the same chain raise before running its block' do
      ran = []
      overflows = []
      described_class.nest('outer', on_overflow: ->(m) { overflows << m }) do
        described_class.nest('mid', on_overflow: ->(_m) {}) do
          lich_respond([]) { feed_overflowing_chain }
          described_class.nest('#parse LOOP', on_overflow: ->(_m) {}) { ran << :next_parse }
        end
      end
      expect(ran).to be_empty
      expect(overflows.size).to eq(1)
    end

    it 'raise_pending! re-raises at once (host ports call it right after respond)' do
      ran = []
      overflows = []
      described_class.nest('outer', on_overflow: ->(m) { overflows << m }) do
        described_class.nest('mid', on_overflow: ->(_m) {}) do
          lich_respond([]) { feed_overflowing_chain }
          described_class.raise_pending!
          ran << :after_echo
        end
      end
      expect(ran).to be_empty
      expect(overflows.size).to eq(1)
    end

    it 'is re-raised by resume_at too (a queued line continuing a chain)' do
      overflows = []
      described_class.resume_at(3, on_overflow: ->(m) { overflows << m }) do
        lich_respond([]) { feed_overflowing_chain }
      end
      expect(overflows.size).to eq(1)
      expect(described_class.current).to eq(0)
    end

    it 'returns false and keeps nothing outside a dispatch chain (no frame to re-raise it)' do
      expect(described_class.defer(described_class::Exceeded.new('x'))).to be(false)
      expect { described_class.raise_pending! }.not_to raise_error
      ran = []
      described_class.nest('fresh', on_overflow: ->(_m) { raise 'stale overflow leaked' }) { ran << :ok }
      expect(ran).to eq([:ok])
    end

    it 'returns true inside a chain' do
      described_class.nest('outer', on_overflow: ->(_m) {}) do
        expect(described_class.defer(described_class::Exceeded.new('x'))).to be(true)
      end
    end

    # The echo port of the genie interpreters and the trigger runner
    # (GenieScript.respond_in_chain) is this helper with Lich's respond as +respond+.
    describe '.respond_in_chain' do
      it 'responds, then stops the chain at once when that respond deferred an overflow' do
        ran = []
        overflows = []
        lich_log = []
        respond = ->(text) { lich_respond(lich_log) { ran << text; feed_overflowing_chain } }
        described_class.nest('outer', on_overflow: ->(m) { overflows << m }) do
          described_class.nest('mid', on_overflow: ->(_m) {}) do
            described_class.respond_in_chain(respond, 'LOOP')
            ran << :after_echo
          end
        end
        expect(ran).to eq(['LOOP'])
        expect(overflows.size).to eq(1)
        expect(lich_log).to be_empty
      end

      it 'just responds when nothing was deferred, inside or outside a chain' do
        seen = []
        respond = ->(text) { seen << text }
        described_class.respond_in_chain(respond, 'plain')
        described_class.nest('outer', on_overflow: ->(_m) { raise 'no overflow expected' }) do
          described_class.respond_in_chain(respond, 'chained')
        end
        expect(seen).to eq(%w[plain chained])
      end

      it 'raises an overflow deferred before the respond only after responding' do
        seen = []
        overflows = []
        described_class.nest('outer', on_overflow: ->(m) { overflows << m }) do
          described_class.defer(described_class::Exceeded.new('earlier'))
          described_class.respond_in_chain(->(text) { seen << text }, 'still printed')
        end
        expect(seen).to eq(['still printed'])
        expect(overflows).to eq(['earlier'])
      end
    end

    it 'never leaks a deferred overflow into the next chain when the first one unwinds with another error' do
      expect do
        described_class.nest('outer', on_overflow: ->(_m) {}) do
          described_class.defer(described_class::Exceeded.new('stale'))
          raise ArgumentError, 'other'
        end
      end.to raise_error(ArgumentError)
      ran = []
      described_class.nest('fresh', on_overflow: ->(m) { raise "stale overflow leaked: #{m}" }) { ran << :ok }
      expect(ran).to eq([:ok])
    end

    it 'never leaks a deferred overflow out of an outermost resume_at that unwinds with another error' do
      expect do
        described_class.resume_at(2, on_overflow: ->(_m) {}) do
          described_class.defer(described_class::Exceeded.new('stale'))
          raise ArgumentError, 'other'
        end
      end.to raise_error(ArgumentError)
      ran = []
      described_class.nest('fresh', on_overflow: ->(m) { raise "stale overflow leaked: #{m}" }) { ran << :ok }
      expect(ran).to eq([:ok])
    end

    it 'raise_pending! clears what it raises: a second call raises nothing' do
      ran = []
      described_class.nest('outer', on_overflow: ->(_m) { raise 'must not be reported' }) do
        described_class.defer(described_class::Exceeded.new('once'))
        expect { described_class.raise_pending! }.to raise_error(described_class::Exceeded, 'once')
        described_class.raise_pending!
        ran << :ok
      end
      expect(ran).to eq([:ok])
    end

    it 'keeps the first deferred overflow when several are deferred on one chain' do
      overflows = []
      described_class.nest('outer', on_overflow: ->(m) { overflows << m }) do
        described_class.defer(described_class::Exceeded.new('first'))
        described_class.defer(described_class::Exceeded.new('second'))
      end
      expect(overflows).to eq(['first'])
    end
  end

  describe '.resume_at (a queued #parse line continuing another thread\'s chain)' do
    it 'continues the count from the carried depth and restores the previous depth after' do
      seen = []
      overflows = []
      described_class.resume_at(limit - 1, on_overflow: ->(m) { overflows << m }) do
        seen << described_class.current
        described_class.nest('#parse A', on_overflow: ->(_m) { raise 'inner handler must not run' }) do
          seen << described_class.current
        end
      end
      expect(seen).to eq([limit - 1, limit])
      expect(overflows).to be_empty
      expect(described_class.current).to eq(0)
    end

    it 'reports a nest past LIMIT once through its own handler (it is the outermost level of this thread)' do
      overflows = []
      value = described_class.resume_at(limit, on_overflow: ->(m) { overflows << m; :capped }) do
        described_class.nest('#parse B', on_overflow: ->(_m) { raise 'inner handler must not run' }) { :not_reached }
      end
      expect(value).to eq(:capped)
      expect(overflows).to eq(["Script error: maximum nested dispatch depth (#{limit}) exceeded on: #parse B"])
      expect(described_class.current).to eq(0)
    end

    it 'never lowers a deeper running count, and lets the overflow unwind to the outer level' do
      overflows = []
      described_class.nest('outer', on_overflow: ->(m) { overflows << m }) do
        described_class.nest('outer2', on_overflow: ->(_m) {}) do
          described_class.resume_at(1, on_overflow: ->(_m) { raise 'not outermost' }) do
            expect(described_class.current).to eq(2)
            build = ->(n) { described_class.nest("lvl#{n}", on_overflow: ->(_m) {}) { build.call(n + 1) } }
            build.call(1)
          end
        end
      end
      expect(overflows.size).to eq(1)
      expect(described_class.current).to eq(0)
    end

    it 'restores the depth when the block raises something else' do
      expect { described_class.resume_at(5, on_overflow: ->(_m) {}) { raise ArgumentError } }.to raise_error(ArgumentError)
      expect(described_class.current).to eq(0)
    end
  end

  # A host call that must never raise (GenieScript.script_list_changed) still lets
  # a nesting-cap overflow through, so the enclosing level stops the chain instead of it running on.
  describe '.contain' do
    it "returns the block's value and reports nothing when it succeeds" do
      errors = []
      expect(described_class.contain(->(e) { errors << e }) { :ok }).to eq(:ok)
      expect(errors).to eq([])
    end

    it 'hands any other error to on_error and returns nil' do
      errors = []
      expect(described_class.contain(->(e) { errors << e.message }) { raise ArgumentError, 'bad' }).to be_nil
      expect(errors).to eq(['bad'])
    end

    it 're-raises an overflow raised inside it, so the outermost nest reports it once and stops the chain' do
      errors = []
      overflows = []
      ran_after = []
      described_class.nest('variable change scriptlist', on_overflow: ->(m) { overflows << m }) do
        described_class.contain(->(e) { errors << e }) do
          descend = lambda do |n|
            described_class.nest('variable change scriptlist', on_overflow: ->(_m) {}) { descend.call(n + 1) }
          end
          descend.call(1)
        end
        ran_after << :after
      end
      expect([errors, overflows.length, ran_after]).to eq([[], 1, []])
      expect(described_class.current).to eq(0)
    end
  end
end
