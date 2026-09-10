# frozen_string_literal: true

require_relative '../../spec_helper'
require 'gemstone/bank'

module Kernel
  def dothistimeout(_action, _timeout, _success_line); end unless method_defined?(:dothistimeout)
  def matchtimeout(_secs, *_strings); end unless method_defined?(:matchtimeout)
end

RSpec.describe Lich::Gemstone::Bank do
  let(:note) { MockGameObj.new(id: '500', noun: 'note', name: 'bank note') }
  let(:sack) { MockGameObj.new(id: '105', noun: 'sack', name: 'leather sack') }
  let(:hands) { { right: nil, left: nil } }
  let(:room) { double('Room', tags: ['bank'], location: 'Icemule Trace') }
  let(:listing) do
    ['You currently have the following amounts on deposit:',
     '',
     '             Icemule Trace Bank: 52,138',
     '                Four Winds Bank: 616,853,785',
     '                          Total: 616,905,923',
     '',
     'You currently have 0 inter-town bank transfer options available.',
     '',
     'You currently have 10 urchin bank runner uses remaining.']
  end
  let(:sent) { [] }

  # A scripted game: each dothistimeout call returns the next reply in order.
  # +before+ runs with the command first, to change hands the way the game would.
  def replies(*lines, before: nil)
    allow(described_class).to receive(:dothistimeout) do |cmd, _t, _rx|
      sent << cmd
      before&.call(cmd)
      lines.shift
    end
  end

  before do
    stub_const('Room', Class.new { def self.current; end })
    allow(Room).to receive(:current).and_return(room)
    stub_const('Lich::Gemstone::Currency', Module.new do
      def self.silver(*) = @silver

      def self.silver=(v)
        @silver = v
      end

      def self.refresh = @silver
    end)
    Lich::Gemstone::Currency.silver = 0
    stub_const('Lich::Common::Account', Module.new { def self.type = 'NORMAL' })
    stub_const('Lich::Gemstone::StowList', Class.new { def self.default; end })
    stub_const('StowList', Lich::Gemstone::StowList)
    allow(StowList).to receive(:default).and_return(sack)
    allow(sack).to receive(:contents).and_return([])
    stub_const('Lich::Stash', Module.new { def self.add_to_bag(_bag, _item); end })
    allow(GameObj).to receive(:right_hand) { hands[:right] }
    allow(GameObj).to receive(:left_hand) { hands[:left] }
    allow(GameObj).to receive(:npcs).and_return([])
    allow(Lich::Util).to receive(:issue_command).and_return([])
    allow(described_class).to receive(:waitrt?)
    allow(described_class).to receive(:sleep)
    allow(described_class).to receive(:fput)
    XMLData.singleton_class.class_eval { attr_accessor :room_title }
    XMLData.room_title = '[Town Bank]'
  end

  describe '.here? / .pinefar?' do
    it 'is at a bank by tag' do
      expect(described_class.here?).to be true
    end

    it 'is at a bank at the Pinefar depository without the tag' do
      allow(room).to receive(:tags).and_return([])
      XMLData.room_title = '[Pinefar, Depository]'
      expect(described_class.here?).to be true
      expect(described_class.pinefar?).to be true
    end

    it 'is not at a bank elsewhere' do
      allow(room).to receive(:tags).and_return(['town'])
      expect(described_class.here?).to be false
    end
  end

  describe '.account' do
    it 'parses the per-town listing and picks the local bank' do
      allow(Lich::Util).to receive(:issue_command).and_return(listing)
      info = described_class.account
      expect(info[:banks]).to eq('Icemule Trace' => 52_138, 'Four Winds' => 616_853_785)
      expect(info[:total]).to eq(616_905_923)
      expect(info[:balance]).to eq(52_138)
      expect(info[:max]).to be_nil
      expect(described_class.balance).to eq(52_138)
    end

    it 'matches the bank by location prefix' do
      allow(room).to receive(:location).and_return('Four Winds Isle')
      allow(Lich::Util).to receive(:issue_command).and_return(listing)
      expect(described_class.balance).to eq(616_853_785)
    end

    it 'does not take a lone account elsewhere for the local one' do
      allow(room).to receive(:location).and_return("Wehnimer's Landing")
      allow(Lich::Util).to receive(:issue_command).and_return(
        ['You currently have the following amounts on deposit:', '', '             Icemule Trace Bank: 52,138', '                          Total: 52,138']
      )
      expect(described_class.balance).to eq(0)
    end

    it 'is 0 with no account in this town' do
      allow(room).to receive(:location).and_return("Wehnimer's Landing")
      allow(Lich::Util).to receive(:issue_command).and_return(listing)
      expect(described_class.balance).to eq(0)
    end

    it 'parses the single-account wording with a cap' do
      allow(Lich::Util).to receive(:issue_command).and_return(
        ['You currently have an account in the amount of 45,000 silver.',
         'Your account may hold a maximum of 100,000 silvers.']
      )
      expect(described_class.account).to include(balance: 45_000, max: 100_000)
    end

    it 'is nil without access' do
      allow(Lich::Util).to receive(:issue_command).and_return(["The teller says, \"I'm sorry, you don't have access to an account here.\""])
      expect(described_class.account).to be_nil
      expect(described_class.balance).to be_nil
    end
  end

  describe '.deposit' do
    it 'deposits all and reports the amount' do
      replies('You deposit 1,234 silvers into your account.')
      expect(described_class.deposit).to eq(1234)
      expect(sent).to eq(['deposit all'])
    end

    it 'deposits a specific amount' do
      replies("That's a total of 500 silver.")
      expect(described_class.deposit(500)).to eq(500)
      expect(sent).to eq(['deposit 500'])
    end

    it 'reports 0 with nothing to deposit' do
      replies('You have no coins to deposit.')
      expect(described_class.deposit).to eq(0)
    end

    it 'is nil when the bank refuses' do
      replies("I'm sorry, you don't have access to an account here.")
      expect(described_class.deposit).to be_nil
    end

    it 'gives the banker at Pinefar after he is at the counter' do
      XMLData.room_title = '[Pinefar, Depository]'
      Lich::Gemstone::Currency.silver = 800
      allow(GameObj).to receive(:npcs).and_return([MockGameObj.new(id: '1', noun: 'banker', name: 'banker')])
      replies('Smiling greedily, Hurshal takes your silvers and says, "Heh, I\'ll put dese in ye \'Mule bank account right quick."')
      expect(described_class.deposit).to eq(0)
      expect(sent).to eq(['give banker 800 silver'])
    end

    it 'sends nothing at Pinefar with no silver' do
      XMLData.room_title = '[Pinefar, Depository]'
      Lich::Gemstone::Currency.silver = 0
      expect(described_class).not_to receive(:dothistimeout)
      expect(described_class.deposit).to eq(0)
    end

    context 'free to play' do
      before do
        allow(Lich::Common::Account).to receive(:type).and_return('FREE')
      end

      it 'deposits everything when it fits under the cap' do
        allow(Lich::Util).to receive(:issue_command).and_return(
          ['You currently have an account in the amount of 10,000 silver.',
           'Your account may hold a maximum of 100,000 silvers.']
        )
        Lich::Gemstone::Currency.silver = 5_000
        replies('You deposit 5,000 silvers into your account.')
        expect(described_class.deposit).to eq(5_000)
        expect(sent).to eq(['deposit 5000'])
      end

      it 'fills to the cap, takes a note, stows it, then deposits the rest' do
        balances = [
          ['You currently have an account in the amount of 95,000 silver.', 'Your account may hold a maximum of 100,000 silvers.'],
          ['You currently have an account in the amount of 0 silver.', 'Your account may hold a maximum of 100,000 silvers.'],
        ]
        allow(Lich::Util).to receive(:issue_command) { balances.shift }
        carried = [20_000, 15_000, 15_000]
        allow(Lich::Gemstone::Currency).to receive(:silver) { carried.shift }
        replies('You deposit 5,000 silvers into your account.',
                'The teller carefully records the transaction, and then hands you a note.',
                'You deposit 15,000 silvers into your account.',
                before: ->(cmd) { hands[:right] = note if cmd =~ /note/ })
        expect(Lich::Stash).to receive(:add_to_bag).with(sack, note)
        expect(described_class.deposit).to eq(20_000)
        expect(sent).to eq(['deposit 5000', 'withdraw 100000 note', 'deposit 15000'])
      end

      it 'never deposits more than the requested amount across passes' do
        balances = [
          ['You currently have an account in the amount of 95,000 silver.', 'Your account may hold a maximum of 100,000 silvers.'],
          ['You currently have an account in the amount of 0 silver.', 'Your account may hold a maximum of 100,000 silvers.'],
        ]
        allow(Lich::Util).to receive(:issue_command) { balances.shift }
        carried = [20_000, 15_000, 15_000]
        allow(Lich::Gemstone::Currency).to receive(:silver) { carried.shift }
        replies('You deposit 5,000 silvers into your account.',
                'The teller carefully records the transaction, and then hands you a note.',
                'You deposit 5,000 silvers into your account.',
                before: ->(cmd) { hands[:right] = note if cmd =~ /note/ })
        expect(described_class.deposit(10_000)).to eq(10_000)
        expect(sent).to eq(['deposit 5000', 'withdraw 100000 note', 'deposit 5000'])
      end

      it 'stops once the requested amount is in, without converting savings to a note' do
        allow(Lich::Util).to receive(:issue_command).and_return(
          ['You currently have an account in the amount of 95,000 silver.', 'Your account may hold a maximum of 100,000 silvers.']
        )
        Lich::Gemstone::Currency.silver = 20_000
        replies('You deposit 5,000 silvers into your account.')
        expect(described_class.deposit(5_000)).to eq(5_000)
        expect(sent).to eq(['deposit 5000'])
      end

      it 'counts only what the bank confirmed' do
        allow(Lich::Util).to receive(:issue_command).and_return(
          ['You currently have an account in the amount of 10,000 silver.',
           'Your account may hold a maximum of 100,000 silvers.']
        )
        Lich::Gemstone::Currency.silver = 5_000
        replies(nil)
        expect(described_class.deposit).to be_nil
      end

      it 'is nil without access' do
        allow(Lich::Util).to receive(:issue_command).and_return(["you don't have access to an account here."])
        expect(described_class.deposit).to be_nil
      end
    end
  end

  describe '.deposit_note' do
    it 'deposits the note in hand and reports its value' do
      hands[:right] = note
      replies('You deposit your note worth 100,000 into your account.', before: ->(_cmd) { hands[:right] = nil })
      expect(described_class.deposit_note).to eq(100_000)
      expect(sent).to eq(['deposit #500'])
    end

    it 'is nil with no note or at Pinefar' do
      expect(described_class.deposit_note).to be_nil
      hands[:right] = note
      XMLData.room_title = '[Pinefar, Depository]'
      expect(described_class.deposit_note).to be_nil
    end
  end

  describe '.withdraw' do
    it 'withdraws silver and reports the amount' do
      replies('The teller carefully records the transaction, and then hands you 8,000 silver.')
      expect(described_class.withdraw(8000)).to eq(8000)
      expect(sent).to eq(['withdraw 8000 silvers'])
    end

    it 'withdraws a note' do
      replies('The teller carefully records the transaction, and then hands you a note.')
      expect(described_class.withdraw(50_000, note: true)).to eq(50_000)
      expect(sent).to eq(['withdraw 50000 note'])
    end

    it 'is nil when refused' do
      replies("The teller says, \"You don't seem to have that much in your account.\"")
      expect(described_class.withdraw(8000)).to be_nil
    end

    it 'is nil when a note was asked for and none was handed over' do
      replies("The teller says, \"You don't seem to have that much in your account.\"")
      expect(described_class.withdraw(8000, note: true)).to be_nil
    end

    it 'warns about a debt notice and waits for the real answer' do
      replies("The teller says, \"I have a bill of 1,500 silvers presented by your creditors that I suggest you pay.\"")
      allow(described_class).to receive(:matchtimeout).with(3, anything)
                                                      .and_return('The teller carefully records the transaction, and then hands you 6,500 silver.')
      expect(Lich::Messaging).to receive(:msg).with('warn', /debt of 1,500 silver/)
      expect(described_class.withdraw(8000)).to eq(6500)
    end

    it 'is nil when nothing follows the debt notice' do
      replies("The teller says, \"I have a bill of 1,500 silvers presented by your creditors that I suggest you pay.\"")
      allow(described_class).to receive(:matchtimeout).and_return(false)
      allow(Lich::Messaging).to receive(:msg)
      expect(described_class.withdraw(8000)).to be_nil
      expect(described_class.withdraw(8000, note: true)).to be_nil
    end

    it 'asks the banker at Pinefar' do
      XMLData.room_title = '[Pinefar, Depository]'
      allow(GameObj).to receive(:npcs).and_return([MockGameObj.new(id: '1', noun: 'banker', name: 'banker')])
      replies('The banker nods and says, "Alright, here ye go.  Ye understand I be takin\' a little more than that from ye account in the \'Mule.  I don\'t works for free!"')
      expect(described_class.withdraw(200)).to eq(200)
      expect(sent).to eq(['ask banker for 200 silvers'])
    end

    it 'is nil when the Pinefar banker refuses' do
      XMLData.room_title = '[Pinefar, Depository]'
      allow(GameObj).to receive(:npcs).and_return([MockGameObj.new(id: '1', noun: 'banker', name: 'banker')])
      replies('The banker looks at you suspiciously and says, "Hmm, I don\'t think ye be havin\' enough."')
      expect(described_class.withdraw(200)).to be_nil
    end

    context 'free to play' do
      before { allow(Lich::Common::Account).to receive(:type).and_return('FREE') }

      it 'withdraws directly when the balance covers it' do
        allow(Lich::Util).to receive(:issue_command).and_return(['You currently have an account in the amount of 9,000 silver.'])
        replies('The teller carefully records the transaction, and then hands you 8,000 silver.')
        expect(described_class.withdraw(8000)).to eq(8000)
        expect(sent).to eq(['withdraw 8000 silver'])
      end

      it 'is nil when the teller refuses' do
        allow(Lich::Util).to receive(:issue_command).and_return(['You currently have an account in the amount of 9,000 silver.'])
        replies("The teller says, \"You don't seem to have that much in your account.\"")
        expect(described_class.withdraw(8000)).to be_nil
      end

      it 'reports only what was actually handed over when a later step fails' do
        allow(Lich::Util).to receive(:issue_command).and_return(['You currently have an account in the amount of 3,000 silver.'])
        allow(sack).to receive(:contents).and_return([note])
        replies('The teller hands you 3,000 silver.', nil)
        expect(described_class.withdraw(8000)).to eq(3000)
      end

      it 'drains the balance, deposits a stowed note, and withdraws the rest' do
        allow(Lich::Util).to receive(:issue_command).and_return(['You currently have an account in the amount of 3,000 silver.'])
        allow(sack).to receive(:contents).and_return([note])
        replies('The teller hands you 3,000 silver.',
                'You deposit your note worth 100,000 into your account.',
                'The teller hands you 5,000 silver.')
        expect(described_class.withdraw(8000)).to eq(8000)
        expect(sent).to eq(['withdraw 3000 silver', 'deposit #500', 'withdraw 5000 silver'])
      end
    end
  end

  describe '.note_value' do
    it 'reads the note in hand' do
      hands[:left] = note
      replies('This note has a value of 12,500 silver and reads: Bank of Wehnimer\'s Landing.  Hold in right hand to use.')
      expect(described_class.note_value).to eq(12_500)
      expect(sent).to eq(['read #500'])
    end

    it 'is 0 with no note' do
      expect(described_class.note_value).to eq(0)
    end
  end

  describe '.wait_for_banker' do
    it 'returns once the banker is present' do
      allow(GameObj).to receive(:npcs).and_return([], [MockGameObj.new(id: '1', noun: 'banker', name: 'banker')])
      expect(described_class.wait_for_banker).to be true
    end

    it 'gives up after the timeout' do
      now = Time.now
      allow(Time).to receive(:now).and_return(now, now, now + 60)
      expect(described_class.wait_for_banker(timeout: 30)).to be false
    end
  end
end
