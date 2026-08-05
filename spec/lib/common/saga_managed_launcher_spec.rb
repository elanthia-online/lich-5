# frozen_string_literal: true

require 'rspec'
require_relative '../../../lib/common/saga_managed_launcher'

RSpec.describe Lich::Common::SagaManagedLauncher do
  let(:plan) do
    Lich::Common::FrontendLauncher::SpawnPlan.new(
      environment: {
        'SAGA_AUTO_LOGIN'         => 'Tsetem@GS3',
        'SAGA_AUTO_LOGIN_ACCOUNT' => 'TESTACCOUNT',
        'SAGA_AUTO_LOGIN_MODE'    => 'lich'
      },
      argv: ['/usr/bin/open', '-n', '-b', 'com.auchand.saga']
    )
  end
  let(:plan_builder) { double('plan builder') }
  let(:process_launcher) { double('process launcher') }

  it 'launches the structured plan and returns the child pid' do
    allow(plan_builder).to receive(:saga_managed_login_plan).and_return(plan)
    allow(process_launcher).to receive(:call).with(plan.environment, plan.argv).and_return(12_345)

    result = described_class.launch(
      account: 'TESTACCOUNT',
      character: 'Tsetem',
      game_code: 'GS3',
      plan_builder: plan_builder,
      process_launcher: process_launcher
    )

    expect(result).to eq(ok: true, pid: 12_345)
    expect(plan_builder).to have_received(:saga_managed_login_plan).with(
      account: 'TESTACCOUNT',
      character: 'Tsetem',
      game_code: 'GS3'
    )
  end

  it 'executes the default process boundary and detaches the child' do
    allow(plan_builder).to receive(:saga_managed_login_plan).and_return(plan)
    allow(Lich::Common::ProcessLauncher).to receive(:call)
      .with(plan.environment, plan.argv).and_return(12_345)
    allow(Process).to receive(:detach).with(12_345)

    result = described_class.launch(
      account: 'TESTACCOUNT',
      character: 'Tsetem',
      game_code: 'GS3',
      plan_builder: plan_builder
    )

    expect(result).to eq(ok: true, pid: 12_345)
    expect(Process).to have_received(:detach).with(12_345)
  end

  it 'returns an unavailable result without attempting a process launch' do
    allow(plan_builder).to receive(:saga_managed_login_plan)
      .and_raise(Lich::Common::FrontendLauncher::UnavailableError, 'Saga was not found')

    expect(process_launcher).not_to receive(:call)

    result = described_class.launch(
      account: 'TESTACCOUNT',
      character: 'Tsetem',
      game_code: 'GS3',
      plan_builder: plan_builder,
      process_launcher: process_launcher
    )

    expect(result).to eq(ok: false, error: 'Saga was not found')
  end

  it 'returns an operating-system spawn failure' do
    allow(plan_builder).to receive(:saga_managed_login_plan).and_return(plan)
    allow(process_launcher).to receive(:call).and_raise(Errno::ENOENT, 'Saga')

    result = described_class.launch(
      account: 'TESTACCOUNT',
      character: 'Tsetem',
      game_code: 'GS3',
      plan_builder: plan_builder,
      process_launcher: process_launcher
    )

    expect(result[:ok]).to be(false)
    expect(result[:error]).to include('Saga')
  end

  it 'does not remap invalid caller input' do
    allow(plan_builder).to receive(:saga_managed_login_plan)
      .and_raise(ArgumentError, 'account must not be empty')

    expect {
      described_class.launch(
        account: '',
        character: 'Tsetem',
        game_code: 'GS3',
        plan_builder: plan_builder,
        process_launcher: process_launcher
      )
    }.to raise_error(ArgumentError, 'account must not be empty')
  end
end
