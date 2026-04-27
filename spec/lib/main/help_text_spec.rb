# frozen_string_literal: true

require 'rspec'

require_relative '../../../lib/main/help_text'

RSpec.describe Lich::Main::HelpText do
  describe '.render' do
    it 'shows the concise overview by default' do
      output = described_class.render

      expect(output).to include('Lich 5')
      expect(output).to include('lich --help login')
      expect(output).not_to include('--install')
    end

    it 'renders login help with headless guidance' do
      output = described_class.render('login')

      expect(output).to include('--headless PORT')
      expect(output).to include('--headless auto')
      expect(output).to include('--save')
    end

    it 'maps diagnostics requests to automation help' do
      output = described_class.render('diagnostics')

      expect(output).to include('Lich Help: automation')
      expect(output).to include('--active-sessions')
      expect(output).to include('--session-info NAME')
    end
  end

  describe '.topic_from_argv' do
    it 'extracts the topic after --help' do
      expect(described_class.topic_from_argv(%w[--help login], '--help')).to eq('login')
    end

    it 'extracts the topic from inline --help syntax' do
      expect(described_class.topic_from_argv(['--help=accounts'], '--help=accounts')).to eq('accounts')
    end
  end
end
