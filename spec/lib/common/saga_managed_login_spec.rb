# frozen_string_literal: true

require_relative '../../login_spec_helper'
require_relative '../../../lib/common/saga_managed_login'

RSpec.describe Lich::Common::SagaManagedLogin do
  let(:target) do
    {
      account: 'TESTACCOUNT',
      character: 'Tsetem',
      game_code: 'GS3',
      frontend: 'saga',
      custom_launch: nil
    }.freeze
  end
  let(:target_resolver) { double('target resolver') }

  def decision_for(**overrides)
    described_class.cli_decision(
      **{
        character: 'Tsetem',
        game_code: 'GS3',
        frontend: 'saga',
        custom_launch: :__unset,
        headless: false,
        data_dir: '/saved',
        target_resolver: target_resolver
      }.merge(overrides)
    )
  end

  it 'routes an explicit saved Saga entry to managed launch' do
    allow(target_resolver).to receive(:resolve_saved_target).and_return(target)

    decision = decision_for

    expect(decision.action).to eq(:launch)
    expect(decision.target).to equal(target)
    expect(decision).to be_frozen
    expect(target_resolver).to have_received(:resolve_saved_target).with(
      'Tsetem',
      game_code: 'GS3',
      frontend: 'saga',
      custom_launch: :__unset,
      data_dir: '/saved'
    )
  end

  it 'routes an implicitly selected saved Saga entry to managed launch' do
    allow(target_resolver).to receive(:resolve_saved_target).and_return(target)

    decision = decision_for(frontend: :__unset)

    expect(decision.action).to eq(:launch)
  end

  it 'passes a non-Saga saved entry through to Lich authentication' do
    allow(target_resolver).to receive(:resolve_saved_target)
      .and_return(target.merge(frontend: 'stormfront'))

    decision = decision_for(frontend: :__unset)

    expect(decision.action).to eq(:passthrough)
  end

  it 'does not read saved metadata for an explicitly non-Saga frontend' do
    expect(target_resolver).not_to receive(:resolve_saved_target)

    decision = decision_for(frontend: 'stormfront')

    expect(decision.action).to eq(:passthrough)
  end

  it 'fails an explicit Saga request when no saved entry matches' do
    allow(target_resolver).to receive(:resolve_saved_target).and_return(nil)

    decision = decision_for

    expect(decision.action).to eq(:error)
    expect(decision.error).to eq('No saved Saga entry matched Tsetem')
  end

  it 'leaves an unresolved implicit request to the established CLI error path' do
    allow(target_resolver).to receive(:resolve_saved_target).and_return(nil)

    decision = decision_for(frontend: :__unset)

    expect(decision.action).to eq(:passthrough)
  end

  {
    'headless login'         => { headless: true },
    'explicit Custom Launch' => { custom_launch: 'my saga command' },
    'character generator'    => { character: 'NEW' }
  }.each do |label, overrides|
    it "preserves Lich's existing path for #{label}" do
      expect(target_resolver).not_to receive(:resolve_saved_target)

      decision = decision_for(**overrides)

      expect(decision.action).to eq(:passthrough)
    end
  end

  it 'preserves Lich authentication if the selected entry has a Custom Launch' do
    allow(target_resolver).to receive(:resolve_saved_target)
      .and_return(target.merge(custom_launch: '/Applications/Saga.app/Contents/MacOS/Saga'))

    decision = decision_for

    expect(decision.action).to eq(:passthrough)
  end

  it 'does not swallow a target resolver exception' do
    allow(target_resolver).to receive(:resolve_saved_target).and_raise(IOError, 'entry store failed')

    expect { decision_for }.to raise_error(IOError, 'entry store failed')
  end

  describe '.launch' do
    let(:launcher) { double('Saga launcher') }

    it 'passes only the Saga contract identifiers to the launcher' do
      allow(launcher).to receive(:launch).and_return(ok: true, pid: 12_345)

      result = described_class.launch(target, launcher: launcher)

      expect(result).to eq(ok: true, pid: 12_345)
      expect(launcher).to have_received(:launch).with(
        account: 'TESTACCOUNT',
        character: 'Tsetem',
        game_code: 'GS3'
      )
    end

    it 'returns a structured launcher failure unchanged' do
      allow(launcher).to receive(:launch).and_return(ok: false, error: 'Saga was not found')

      expect(described_class.launch(target, launcher: launcher))
        .to eq(ok: false, error: 'Saga was not found')
    end

    it 'rejects an invalid target before calling the launcher' do
      expect(launcher).not_to receive(:launch)

      expect {
        described_class.launch(nil, launcher: launcher)
      }.to raise_error(ArgumentError, 'Saga launch target must be a Hash')
    end
  end
end
