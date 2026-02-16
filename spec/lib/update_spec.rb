# frozen_string_literal: true

require 'rspec'
require 'fileutils'
require 'tmpdir'

# Mock constants
LICH_VERSION = '5.14.1' unless defined?(LICH_VERSION)
LIB_DIR = File.expand_path('../../lib', __dir__) unless defined?(LIB_DIR)
$clean_lich_char = ';' unless defined?($clean_lich_char)

# Mock respond method
def respond(message = nil)
  # Capture for testing
end unless defined?(respond)

require_relative '../../lib/update'

RSpec.describe Lich::Util::Update do
  describe '.get_branch_info' do
    context 'when LICH_BRANCH constant is defined' do
      before do
        stub_const('LICH_BRANCH', 'test-branch')
        stub_const('LICH_BRANCH_REPO', 'owner/lich-5')
        stub_const('LICH_BRANCH_UPDATED_AT', 1707840000)
      end

      it 'returns branch info from constants' do
        result = described_class.get_branch_info
        expect(result).to be_a(Hash)
        expect(result[:branch_name]).to eq('test-branch')
        expect(result[:repository]).to eq('owner/lich-5')
        expect(result[:updated_at]).to eq(1707840000)
      end
    end

    context 'when LICH_BRANCH constant is empty string' do
      before do
        stub_const('LICH_BRANCH', '')
      end

      it 'falls back to reading from file' do
        allow(described_class).to receive(:read_branch_info_from_file).and_return(nil)
        result = described_class.get_branch_info
        expect(described_class).to have_received(:read_branch_info_from_file)
        expect(result).to be_nil
      end
    end

    context 'when LICH_BRANCH constant is not defined' do
      before do
        # Hide the constant if defined
        hide_const('LICH_BRANCH') if defined?(LICH_BRANCH)
      end

      it 'falls back to reading from file' do
        allow(described_class).to receive(:read_branch_info_from_file).and_return({
          branch_name: 'file-branch',
          repository: 'file-owner/lich-5',
          updated_at: 1707850000
        })
        result = described_class.get_branch_info
        expect(result[:branch_name]).to eq('file-branch')
      end
    end
  end

  describe '.read_branch_info_from_file' do
    let(:temp_dir) { Dir.mktmpdir }
    let(:version_file_path) { File.join(temp_dir, 'version.rb') }

    before do
      stub_const('LIB_DIR', temp_dir)
    end

    after do
      FileUtils.remove_entry(temp_dir)
    end

    context 'when version.rb does not exist' do
      it 'returns nil' do
        result = described_class.read_branch_info_from_file
        expect(result).to be_nil
      end
    end

    context 'when version.rb has no branch tracking' do
      before do
        File.write(version_file_path, <<~RUBY)
          LICH_VERSION = '5.14.1'
          REQUIRED_RUBY = '4.0.0'
        RUBY
      end

      it 'returns nil' do
        result = described_class.read_branch_info_from_file
        expect(result).to be_nil
      end
    end

    context 'when version.rb has branch tracking with single quotes' do
      before do
        File.write(version_file_path, <<~RUBY)
          LICH_VERSION = '5.14.1'
          REQUIRED_RUBY = '4.0.0'

          # Branch tracking (added by lich5-update --branch)
          LICH_BRANCH = 'my-feature-branch'
          LICH_BRANCH_REPO = 'myuser/lich-5'
          LICH_BRANCH_UPDATED_AT = 1707840000
        RUBY
      end

      it 'extracts branch name' do
        result = described_class.read_branch_info_from_file
        expect(result[:branch_name]).to eq('my-feature-branch')
      end

      it 'extracts repository' do
        result = described_class.read_branch_info_from_file
        expect(result[:repository]).to eq('myuser/lich-5')
      end

      it 'extracts updated_at timestamp' do
        result = described_class.read_branch_info_from_file
        expect(result[:updated_at]).to eq(1707840000)
      end
    end

    context 'when version.rb has branch tracking with double quotes' do
      before do
        File.write(version_file_path, <<~RUBY)
          LICH_VERSION = "5.14.1"

          # Branch tracking (added by lich5-update --branch)
          LICH_BRANCH = "another-branch"
          LICH_BRANCH_REPO = "owner/lich-5"
          LICH_BRANCH_UPDATED_AT = 1707850000
        RUBY
      end

      it 'extracts branch name with double quotes' do
        result = described_class.read_branch_info_from_file
        expect(result[:branch_name]).to eq('another-branch')
      end
    end

    context 'when version.rb has branch tracking but no repo or timestamp' do
      before do
        File.write(version_file_path, <<~RUBY)
          LICH_VERSION = '5.14.1'
          LICH_BRANCH = 'minimal-branch'
        RUBY
      end

      it 'returns branch name with nil repo and timestamp' do
        result = described_class.read_branch_info_from_file
        expect(result[:branch_name]).to eq('minimal-branch')
        expect(result[:repository]).to be_nil
        expect(result[:updated_at]).to be_nil
      end
    end

    context 'when LICH_BRANCH is empty string' do
      before do
        File.write(version_file_path, <<~RUBY)
          LICH_VERSION = '5.14.1'
          LICH_BRANCH = ''
        RUBY
      end

      it 'returns nil' do
        result = described_class.read_branch_info_from_file
        expect(result).to be_nil
      end
    end

    context 'when branch name contains special characters' do
      before do
        File.write(version_file_path, <<~RUBY)
          LICH_BRANCH = 'fix/update-branch_status-123'
          LICH_BRANCH_REPO = 'elanthia-online/lich-5'
          LICH_BRANCH_UPDATED_AT = 1707860000
        RUBY
      end

      it 'handles slashes and underscores in branch name' do
        result = described_class.read_branch_info_from_file
        expect(result[:branch_name]).to eq('fix/update-branch_status-123')
      end
    end
  end

  describe 'same-session branch update integration' do
    let(:temp_dir) { Dir.mktmpdir }
    let(:version_file_path) { File.join(temp_dir, 'version.rb') }

    before do
      stub_const('LIB_DIR', temp_dir)
      # Ensure no LICH_BRANCH constant is defined
      hide_const('LICH_BRANCH') if defined?(LICH_BRANCH)
    end

    after do
      FileUtils.remove_entry(temp_dir)
    end

    context 'when branch tracking was just written to file (same session)' do
      before do
        # Simulate store_branch_tracking having written to version.rb
        File.write(version_file_path, <<~RUBY)
          LICH_VERSION = '5.14.1'

          # Branch tracking (added by lich5-update --branch)
          LICH_BRANCH = 'conglomerate_refactor_branch'
          LICH_BRANCH_REPO = 'elanthia-online/lich-5'
          LICH_BRANCH_UPDATED_AT = #{Time.now.to_i}
        RUBY
      end

      it 'get_branch_info returns branch info from file' do
        result = described_class.get_branch_info
        expect(result).not_to be_nil
        expect(result[:branch_name]).to eq('conglomerate_refactor_branch')
        expect(result[:repository]).to eq('elanthia-online/lich-5')
      end
    end
  end
end
