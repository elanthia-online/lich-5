# frozen_string_literal: true

require 'yaml'

RSpec.describe 'Windows release contract gates' do
  def workflow(name)
    YAML.safe_load_file(File.expand_path("../../.github/workflows/#{name}", __dir__), aliases: true)
  end

  it 'keeps the live contract in the existing aggregate CI requirement' do
    jobs = workflow('ci.yml').fetch('jobs')
    expect(jobs.fetch('ci-gate').fetch('needs')).to include('windows_contract')
    expect(jobs.fetch('windows_contract').fetch('steps').last['uses']).to eq('./.github/actions/check-r4l5-contract')
    expect(jobs.fetch('windows_contract')).not_to have_key('if')
  end

  %w[release-on-push-stable.yaml release-on-push-prerelease.yaml].each do |name|
    it "checks the contract before Release Please writes in #{name}" do
      steps = workflow(name).fetch('jobs').fetch('release').fetch('steps')
      gate = steps.index { |step| step['uses'] == './.github/actions/check-r4l5-contract' }
      publication = steps.index { |step| step['uses']&.start_with?('googleapis/release-please-action@') }
      expect(gate).to be < publication
      expect(steps.fetch(gate)).not_to have_key('if')
    end

    it "checks the downloaded executable before attachment in #{name}" do
      steps = workflow(name).fetch('jobs').fetch('build_installer').fetch('steps')
      gate = steps.index { |step| step.dig('with', 'installer') == 'Ruby4Lich5.exe' }
      download = steps.index { |step| step['name'] == 'Download latest Ruby4Lich5 installer' }
      upload = steps.index { |step| step['name'] == 'Upload installer to release' }
      expect(gate).to be > download
      expect(gate).to be < upload
    end
  end

  it 'checks the requested rebuild target before any job may upload archives' do
    jobs = workflow('rebuild-release-assets.yaml').fetch('jobs')
    steps = jobs.fetch('release_guard').fetch('steps')
    gate = steps.find { |step| step['uses'] == './.github/actions/check-r4l5-contract' }
    expect(gate.fetch('with')).to include('gemfile' => 'release-target/Gemfile', 'lockfile' => 'release-target/Gemfile.lock')
    expect(jobs.fetch('build_archives').fetch('needs')).to eq('release_guard')
  end
end
