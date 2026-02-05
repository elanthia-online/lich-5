# frozen_string_literal: true

require 'rspec'

# Minimal mock setup - we test the Frontend module in isolation
# without loading the full Lich application stack.

module Lich
  module Common
    # Reset Frontend if already loaded, so we get a clean slate
  end
end

# Stub out the heavy dependencies that front-end.rb pulls in
# before requiring it
require 'tempfile'
require 'json'
require 'fileutils'

# Stub Lich.log for test output
module Lich
  def self.log(msg)
    # silent in tests
  end
end unless Lich.respond_to?(:log)

require_relative '../../../lib/common/front-end'

# Shorthand for use in describe-level iteration
FE = Lich::Common::Frontend

RSpec.describe Lich::Common::Frontend do
  let(:frontend) { Lich::Common::Frontend }

  # ─── Constants ─────────────────────────────────────────────

  describe 'CLIENT_STRING' do
    it 'is defined' do
      expect(frontend::CLIENT_STRING).to be_a(String)
    end

    it 'identifies as WRAYTH frontend' do
      expect(frontend::CLIENT_STRING).to include('/FE:WRAYTH')
    end

    it 'includes version 1.0.1.28' do
      expect(frontend::CLIENT_STRING).to include('/VERSION:1.0.1.28')
    end

    it 'uses WIN_UNKNOWN as platform' do
      expect(frontend::CLIENT_STRING).to include('/P:WIN_UNKNOWN')
    end

    it 'requests XML protocol' do
      expect(frontend::CLIENT_STRING).to include('/XML')
    end

    it 'does not leak RUBY_PLATFORM' do
      # Wrayth masquerades as a Windows client regardless of actual platform
      expect(frontend::CLIENT_STRING).not_to include(RUBY_PLATFORM) unless RUBY_PLATFORM == 'WIN_UNKNOWN'
    end
  end

  # ─── Capability Sets ───────────────────────────────────────

  describe 'XML_FRONTENDS' do
    it 'is frozen' do
      expect(FE::XML_FRONTENDS).to be_frozen
    end

    it 'includes stormfront' do
      expect(FE::XML_FRONTENDS).to include('stormfront')
    end

    it 'includes wrayth' do
      expect(FE::XML_FRONTENDS).to include('wrayth')
    end

    it 'includes frostbite' do
      expect(FE::XML_FRONTENDS).to include('frostbite')
    end

    it 'includes profanity' do
      expect(FE::XML_FRONTENDS).to include('profanity')
    end

    it 'includes genie' do
      expect(FE::XML_FRONTENDS).to include('genie')
    end

    it 'does not include GSL-based frontends' do
      expect(FE::XML_FRONTENDS).not_to include('wizard')
      expect(FE::XML_FRONTENDS).not_to include('avalon')
    end
  end

  describe 'GSL_FRONTENDS' do
    it 'is frozen' do
      expect(FE::GSL_FRONTENDS).to be_frozen
    end

    it 'includes wizard' do
      expect(FE::GSL_FRONTENDS).to include('wizard')
    end

    it 'includes avalon' do
      expect(FE::GSL_FRONTENDS).to include('avalon')
    end

    it 'does not include XML frontends' do
      expect(FE::GSL_FRONTENDS).not_to include('stormfront')
      expect(FE::GSL_FRONTENDS).not_to include('wrayth')
      expect(FE::GSL_FRONTENDS).not_to include('profanity')
    end
  end

  describe 'STREAM_FRONTENDS' do
    it 'is frozen' do
      expect(FE::STREAM_FRONTENDS).to be_frozen
    end

    it 'includes stormfront' do
      expect(FE::STREAM_FRONTENDS).to include('stormfront')
    end

    it 'includes wrayth' do
      expect(FE::STREAM_FRONTENDS).to include('wrayth')
    end

    it 'includes profanity' do
      expect(FE::STREAM_FRONTENDS).to include('profanity')
    end

    it 'does not include frostbite' do
      expect(FE::STREAM_FRONTENDS).not_to include('frostbite')
    end

    it 'does not include genie' do
      expect(FE::STREAM_FRONTENDS).not_to include('genie')
    end

    it 'is a subset of XML_FRONTENDS' do
      expect(FE::STREAM_FRONTENDS - FE::XML_FRONTENDS).to be_empty
    end
  end

  describe 'MONO_FRONTENDS' do
    it 'is frozen' do
      expect(FE::MONO_FRONTENDS).to be_frozen
    end

    it 'includes stormfront' do
      expect(FE::MONO_FRONTENDS).to include('stormfront')
    end

    it 'includes wrayth' do
      expect(FE::MONO_FRONTENDS).to include('wrayth')
    end

    it 'includes genie' do
      expect(FE::MONO_FRONTENDS).to include('genie')
    end

    it 'does not include profanity' do
      expect(FE::MONO_FRONTENDS).not_to include('profanity')
    end

    it 'does not include frostbite' do
      expect(FE::MONO_FRONTENDS).not_to include('frostbite')
    end

    it 'is a subset of XML_FRONTENDS' do
      expect(FE::MONO_FRONTENDS - FE::XML_FRONTENDS).to be_empty
    end
  end

  describe 'GSL_FRONTENDS and XML_FRONTENDS are mutually exclusive' do
    it 'have no overlap' do
      overlap = FE::GSL_FRONTENDS & FE::XML_FRONTENDS
      expect(overlap).to be_empty
    end
  end

  # ─── Predicate Methods ─────────────────────────────────────

  describe '.supports_xml?' do
    context 'with explicit argument' do
      FE::XML_FRONTENDS.each do |fe|
        it "returns true for '#{fe}'" do
          expect(frontend.supports_xml?(fe)).to be true
        end
      end

      FE::GSL_FRONTENDS.each do |fe|
        it "returns false for '#{fe}'" do
          expect(frontend.supports_xml?(fe)).to be false
        end
      end

      it "returns false for 'unknown'" do
        expect(frontend.supports_xml?('unknown')).to be false
      end

      it 'returns false for nil' do
        expect(frontend.supports_xml?(nil)).to be false
      end
    end

    context 'with $frontend global (default argument)' do
      around do |example|
        original = $frontend
        example.run
        $frontend = original
      end

      it 'reads from $frontend when no argument given' do
        $frontend = 'stormfront'
        expect(frontend.supports_xml?).to be true
      end

      it 'returns false for GSL frontend' do
        $frontend = 'wizard'
        expect(frontend.supports_xml?).to be false
      end
    end
  end

  describe '.supports_gsl?' do
    context 'with explicit argument' do
      FE::GSL_FRONTENDS.each do |fe|
        it "returns true for '#{fe}'" do
          expect(frontend.supports_gsl?(fe)).to be true
        end
      end

      FE::XML_FRONTENDS.each do |fe|
        it "returns false for '#{fe}'" do
          expect(frontend.supports_gsl?(fe)).to be false
        end
      end

      it "returns false for 'unknown'" do
        expect(frontend.supports_gsl?('unknown')).to be false
      end

      it 'returns false for nil' do
        expect(frontend.supports_gsl?(nil)).to be false
      end
    end

    context 'with $frontend global (default argument)' do
      around do |example|
        original = $frontend
        example.run
        $frontend = original
      end

      it 'reads from $frontend when no argument given' do
        $frontend = 'wizard'
        expect(frontend.supports_gsl?).to be true
      end

      it 'returns true for avalon' do
        $frontend = 'avalon'
        expect(frontend.supports_gsl?).to be true
      end

      it 'returns false for stormfront' do
        $frontend = 'stormfront'
        expect(frontend.supports_gsl?).to be false
      end
    end
  end

  describe '.supports_streams?' do
    context 'with explicit argument' do
      FE::STREAM_FRONTENDS.each do |fe|
        it "returns true for '#{fe}'" do
          expect(frontend.supports_streams?(fe)).to be true
        end
      end

      it "returns false for 'frostbite'" do
        expect(frontend.supports_streams?('frostbite')).to be false
      end

      it "returns false for 'genie'" do
        expect(frontend.supports_streams?('genie')).to be false
      end

      it "returns false for 'wizard'" do
        expect(frontend.supports_streams?('wizard')).to be false
      end

      it 'returns false for nil' do
        expect(frontend.supports_streams?(nil)).to be false
      end
    end

    context 'with $frontend global (default argument)' do
      around do |example|
        original = $frontend
        example.run
        $frontend = original
      end

      it 'returns true for profanity' do
        $frontend = 'profanity'
        expect(frontend.supports_streams?).to be true
      end

      it 'returns false for wizard' do
        $frontend = 'wizard'
        expect(frontend.supports_streams?).to be false
      end
    end
  end

  describe '.supports_mono?' do
    context 'with explicit argument' do
      FE::MONO_FRONTENDS.each do |fe|
        it "returns true for '#{fe}'" do
          expect(frontend.supports_mono?(fe)).to be true
        end
      end

      it "returns false for 'profanity'" do
        expect(frontend.supports_mono?('profanity')).to be false
      end

      it "returns false for 'frostbite'" do
        expect(frontend.supports_mono?('frostbite')).to be false
      end

      it "returns false for 'wizard'" do
        expect(frontend.supports_mono?('wizard')).to be false
      end

      it 'returns false for nil' do
        expect(frontend.supports_mono?(nil)).to be false
      end
    end

    context 'with $frontend global (default argument)' do
      around do |example|
        original = $frontend
        example.run
        $frontend = original
      end

      it 'returns true for genie' do
        $frontend = 'genie'
        expect(frontend.supports_mono?).to be true
      end

      it 'returns false for wizard' do
        $frontend = 'wizard'
        expect(frontend.supports_mono?).to be false
      end
    end
  end

  # ─── Client Accessor ─────────────────────────────────────

  describe '.client' do
    around do |example|
      original = $frontend
      example.run
      $frontend = original
    end

    it 'returns the current $frontend value' do
      $frontend = 'stormfront'
      expect(frontend.client).to eq('stormfront')
    end

    it 'reflects changes to $frontend' do
      $frontend = 'wizard'
      expect(frontend.client).to eq('wizard')
      $frontend = 'profanity'
      expect(frontend.client).to eq('profanity')
    end
  end

  describe '.client=' do
    around do |example|
      original = $frontend
      example.run
      $frontend = original
    end

    it 'sets the $frontend value' do
      frontend.client = 'frostbite'
      expect($frontend).to eq('frostbite')
    end

    it 'is readable via .client after assignment' do
      frontend.client = 'genie'
      expect(frontend.client).to eq('genie')
    end

    it 'integrates with predicates' do
      frontend.client = 'wizard'
      expect(frontend.supports_gsl?).to be true
      expect(frontend.supports_xml?).to be false

      frontend.client = 'stormfront'
      expect(frontend.supports_gsl?).to be false
      expect(frontend.supports_xml?).to be true
    end
  end

  # ─── send_handshake ────────────────────────────────────────

  describe '.send_handshake' do
    it 'is defined as a module method' do
      expect(frontend).to respond_to(:send_handshake)
    end

    it 'accepts one argument (version_string)' do
      expect(frontend.method(:send_handshake).arity).to eq(1)
    end
  end

  # ─── Behavioral Consistency ────────────────────────────────

  describe 'predicate consistency across all known frontends' do
    all_frontends = %w[stormfront wrayth frostbite profanity genie wizard avalon unknown suks]

    all_frontends.each do |fe|
      context "for frontend '#{fe}'" do
        it 'is not both xml_capable and gsl_based' do
          expect(frontend.supports_xml?(fe) && frontend.supports_gsl?(fe)).to be false
        end

        it 'stream support implies XML capability' do
          next unless frontend.supports_streams?(fe)

          expect(frontend.supports_xml?(fe)).to be true
        end
      end
    end
  end

  # ─── Existing Functionality Preserved ──────────────────────

  describe 'existing session file functionality' do
    it 'still responds to create_session_file' do
      expect(frontend).to respond_to(:create_session_file)
    end

    it 'still responds to cleanup_session_file' do
      expect(frontend).to respond_to(:cleanup_session_file)
    end

    it 'still responds to session_file_location' do
      expect(frontend).to respond_to(:session_file_location)
    end
  end

  describe 'existing PID functionality' do
    it 'still responds to pid' do
      expect(frontend).to respond_to(:pid)
    end

    it 'still responds to pid=' do
      expect(frontend).to respond_to(:pid=)
    end

    it 'still responds to detect_pid' do
      expect(frontend).to respond_to(:detect_pid)
    end

    it 'still responds to refocus' do
      expect(frontend).to respond_to(:refocus)
    end
  end

  # ─── Regression: Old Patterns Still Match ──────────────────

  describe 'regression: predicate methods match old regex patterns' do
    # These tests verify that the new predicate methods produce the same
    # results as the old regex patterns they replaced.

    describe 'old: $frontend =~ /^(?:wizard|avalon)$/' do
      it 'matches supports_gsl? for all known frontends' do
        %w[stormfront wrayth frostbite profanity genie wizard avalon unknown suks].each do |fe|
          old_result = !!(fe =~ /^(?:wizard|avalon)$/)
          new_result = frontend.supports_gsl?(fe)
          expect(new_result).to eq(old_result),
                                "Mismatch for '#{fe}': old=#{old_result}, new=#{new_result}"
        end
      end
    end

    describe 'old: $frontend =~ /^(?:stormfront|frostbite|wrayth|profanity|genie)$/' do
      it 'matches supports_xml? for all known frontends' do
        %w[stormfront wrayth frostbite profanity genie wizard avalon unknown suks].each do |fe|
          old_result = !!(fe =~ /^(?:stormfront|frostbite|wrayth|profanity|genie)$/)
          new_result = frontend.supports_xml?(fe)
          expect(new_result).to eq(old_result),
                                "Mismatch for '#{fe}': old=#{old_result}, new=#{new_result}"
        end
      end
    end

    describe 'old: $frontend =~ /stormfront|profanity/i (stream_window in messaging.rb)' do
      it 'supports_streams? is a superset that adds wrayth (intentional bug fix)' do
        # The old pattern was missing wrayth - supports_streams? fixes this
        %w[stormfront profanity].each do |fe|
          old_result = !!(fe =~ /stormfront|profanity/i)
          new_result = frontend.supports_streams?(fe)
          expect(new_result).to eq(old_result),
                                "Mismatch for '#{fe}': old=#{old_result}, new=#{new_result}"
        end

        # Wrayth is the intentional addition (bug fix)
        expect(frontend.supports_streams?('wrayth')).to be true
      end
    end

    describe 'old: $fake_stormfront (was true when wizard/avalon)' do
      it 'supports_gsl? matches old $fake_stormfront behavior' do
        %w[wizard avalon].each do |fe|
          expect(frontend.supports_gsl?(fe)).to(be(true),
                                                "supports_gsl?('#{fe}') should be true (was $fake_stormfront=true)")
        end

        %w[stormfront wrayth frostbite profanity genie unknown].each do |fe|
          expect(frontend.supports_gsl?(fe)).to(be(false),
                                                "supports_gsl?('#{fe}') should be false (was $fake_stormfront=false)")
        end
      end
    end
  end
end
