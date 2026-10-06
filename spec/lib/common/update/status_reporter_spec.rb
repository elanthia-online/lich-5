# frozen_string_literal: true

require_relative 'update_spec_helper'

RSpec.describe Lich::Util::Update::StatusReporter do
  describe '.respond_github_failure' do
    let(:printed) { [] }
    let(:fetch_error) { Lich::Util::Update::FetchError }

    before { allow(described_class).to receive(:respond_mono) { |msg| printed << msg } }

    it 'calls an outage temporary and states the consequence first' do
      described_class.respond_github_failure(fetch_error.new(kind: :unavailable, status: 401), 'No scripts have been updated this run.')

      expect(printed).to eq(['[lich5-update: GitHub check failed. No scripts have been updated this run. This is a temporary error that should resolve itself by your next login.]'])
    end

    it 'uses the temporary wording for network and unparseable responses' do
      %i[network bad_response].each do |kind|
        described_class.respond_github_failure(fetch_error.new(kind: kind), 'X.')
      end

      expect(printed).to all(include('temporary error'))
    end

    it 'uses the temporary wording when no classification is available' do
      described_class.respond_github_failure(nil, 'X.')

      expect(printed.first).to include('GitHub check failed. X. This is a temporary error')
    end

    it 'shows the local reset time for a rate limit' do
      reset = Time.new(2026, 10, 7, 14, 32, 0)
      described_class.respond_github_failure(fetch_error.new(kind: :rate_limited, reset_at: reset), 'X.')

      expect(printed.first).to include('rate limit reached, resets at 14:32', 'X.', 'once the limit resets')
    end

    it 'omits the reset time when GitHub did not report one' do
      described_class.respond_github_failure(fetch_error.new(kind: :rate_limited), 'X.')

      expect(printed.first).to include('(rate limit reached)')
    end

    it 'names the subject on not-found and does not call it temporary' do
      described_class.respond_github_failure(fetch_error.new(kind: :not_found, status: 404), 'No scripts were updated from me/repo.', subject: 'me/repo')

      expect(printed.first).to include('(me/repo not found)', 'Check that the repository and branch exist')
      expect(printed.first).not_to include('temporary')
    end

    it 'never exposes HTTP codes, API paths, or method names' do
      described_class.respond_github_failure(fetch_error.new(kind: :unavailable, status: 401), 'X.')

      expect(printed.first).not_to match(%r{401|/repos/|prep_update})
    end
  end
end
