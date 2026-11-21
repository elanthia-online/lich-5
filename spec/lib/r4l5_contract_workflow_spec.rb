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

  it 'runs the pre-tag contract check unconditionally for a stable release' do
    steps = workflow('release-on-push-stable.yaml').fetch('jobs').fetch('release').fetch('steps')
    gate = steps.find { |step| step['uses'] == './.github/actions/check-r4l5-contract' }
    expect(gate).not_to have_key('if')
  end

  it 'skips the pre-tag contract check for a prerelease only when the merged PR is labelled installer-less' do
    steps = workflow('release-on-push-prerelease.yaml').fetch('jobs').fetch('release').fetch('steps')
    labels = steps.index { |step| step['id'] == 'installer_less' }
    gate = steps.index { |step| step['uses'] == './.github/actions/check-r4l5-contract' }
    expect(labels).to be < gate
    expect(steps.fetch(gate).fetch('if')).to eq("${{ steps.installer_less.outputs.skip_contract != 'true' }}")

    lookup = steps.fetch(labels)
    expect(lookup.fetch('env')).to include('PUSHED_SHA' => '${{ github.sha }}', 'BASE' => '${{ github.ref_name }}')
    run = lookup.fetch('run')
    # Only the two installer labels on the merged PR for this push turn the
    # check off; a failed lookup or no PR leaves it on.
    expect(run).to include('/commits/${PUSHED_SHA}/pulls', "|| echo '[]'", 'select(.merged_at != null and .base.ref == $base)')
    expect(run).to include('skip="false"', '(skip-installer|no-installer)', 'echo "skip_contract=$skip" >> "$GITHUB_OUTPUT"')
    expect(run.scan('skip="true"').size).to eq(1)
  end

  it 'keeps the installer check of a prerelease that does attach an installer' do
    steps = workflow('release-on-push-prerelease.yaml').fetch('jobs').fetch('build_installer').fetch('steps')
    gate = steps.find { |step| step.dig('with', 'installer') == 'Ruby4Lich5.exe' }
    expect(gate).not_to have_key('if')
  end

  %w[ci.yml release-on-push-stable.yaml release-on-push-prerelease.yaml rebuild-release-assets.yaml].each do |name|
    it "checks out tooling and explicit consumer inputs before every local contract action in #{name}" do
      workflow(name).fetch('jobs').each do |job_name, job|
        steps = job.fetch('steps', [])
        steps.each_with_index do |step, index|
          next unless step['uses'] == './.github/actions/check-r4l5-contract'

          prior = steps.take(index)
          checkouts = prior.select { |entry| entry['uses']&.start_with?('actions/checkout@') }
          expect(checkouts.count { |entry| !entry.dig('with', 'path') }).to eq(1), "#{name}:#{job_name} tooling"
          if step.dig('with', 'gemfile') == 'release-target/Gemfile'
            target = checkouts.select { |entry| entry.dig('with', 'path') == 'release-target' }
            expect(target.length).to eq(1), "#{name}:#{job_name} target"
            expect(target.first.dig('with', 'ref')).not_to be_nil
            expect(target.first.dig('with', 'persist-credentials')).to be(false)
            if name == 'rebuild-release-assets.yaml'
              expected = job_name == 'release_guard' ? '${{ inputs.tag }}' : '${{ needs.release_guard.outputs.tag }}'
              expect(target.first.dig('with', 'ref')).to eq(expected)
            end
          end
        end
      end
    end
  end

  it 'checks the requested rebuild target before any job may upload archives' do
    jobs = workflow('rebuild-release-assets.yaml').fetch('jobs')
    steps = jobs.fetch('release_guard').fetch('steps')
    gate = steps.find { |step| step['uses'] == './.github/actions/check-r4l5-contract' }
    draft = steps.index { |step| step['name'] == 'Verify draft release exists for tag' }
    expect(draft).to be < steps.index(gate)
    expect(steps.fetch(draft).fetch('run')).to include('isDraft', 'Refusing to clobber assets on a published release.')
    expect(gate).not_to have_key('if')
    expect(gate.fetch('with')).to include('gemfile' => 'release-target/Gemfile', 'lockfile' => 'release-target/Gemfile.lock')
    expect(jobs.fetch('build_archives').fetch('needs')).to eq('release_guard')
  end
end
