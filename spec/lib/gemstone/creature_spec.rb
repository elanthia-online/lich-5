# frozen_string_literal: true

require_relative '../../spec_helper'
require 'gemstone/creature'
require 'tmpdir'

RSpec.describe Lich::Gemstone::CreatureTemplate do
  before do
    described_class.class_variable_set(:@@templates, {})
    described_class.class_variable_set(:@@loaded, false)
  end

  describe '.load_all' do
    around do |example|
      Dir.mktmpdir do |dir|
        @dir = dir
        example.run
      end
    end

    def write_template(filename, content)
      File.write(File.join(@dir, filename), content)
    end

    it 'loads every non-template .rb file in the directory' do
      write_template('alpha_wolf.rb', '{ name: "alpha wolf", level: 5 }')
      write_template('beta_wolf.rb', '{ name: "beta wolf", level: 6 }')

      described_class.load_all(@dir)

      expect(described_class.all.map(&:name)).to contain_exactly('alpha wolf', 'beta wolf')
    end

    it 'skips _creature_template.rb itself' do
      write_template('_creature_template.rb', '{ name: "should not load" }')

      described_class.load_all(@dir)

      expect(described_class.all).to be_empty
    end

    it "prefers the file's own :name over the filename-derived one, preserving characters a slug can't" do
      # Regression: load_all used to overwrite :name (and the lookup key)
      # from the filename unconditionally, so a real name with a hyphen
      # ("shield-maiden") silently became "shield maiden" after a
      # filename round-trip, breaking exact-name lookup at runtime.
      write_template('shield_maiden.rb', '{ name: "shield-maiden", level: 10 }')

      described_class.load_all(@dir)

      template = described_class['shield-maiden']
      expect(template).not_to be_nil
      expect(template.name).to eq('shield-maiden')
    end

    it "falls back to the filename-derived name when the file doesn't set one" do
      write_template('grey_wolf.rb', '{ level: 5 }')

      described_class.load_all(@dir)

      template = described_class['grey wolf']
      expect(template).not_to be_nil
      expect(template.name).to eq('grey wolf')
    end

    it 'does not raise on a file with malformed Ruby, and skips it' do
      write_template('broken.rb', '{ this is not : valid ruby ][')

      expect { described_class.load_all(@dir) }.not_to raise_error
      expect(described_class.all).to be_empty
    end

    it 'skips a file that evals to something other than a Hash' do
      write_template('not_a_hash.rb', '"just a string"')

      described_class.load_all(@dir)

      expect(described_class.all).to be_empty
    end

    it 'lets a later colliding name silently overwrite an earlier one (documents current behavior)' do
      # Reproduces the real spectre/shadowy_spectre collision without
      # depending on real repo data: BOON_ADJECTIVES strips "shadowy " from
      # the name, so both files normalize to the same lookup key, and only
      # one survives - whichever Dir[] happens to enumerate last.
      write_template('spectre.rb', '{ name: "spectre", level: 50 }')
      write_template('shadowy_spectre.rb', '{ name: "shadowy spectre", level: 80 }')

      described_class.load_all(@dir)

      expect(described_class.all.size).to eq(1)
      expect(described_class['spectre']).not_to be_nil
    end

    it 'logs a debug warning when a collision happens, naming both the key and the file' do
      write_template('spectre.rb', '{ name: "spectre", level: 50 }')
      write_template('shadowy_spectre.rb', '{ name: "shadowy spectre", level: 80 }')
      messages = []
      allow(described_class).to receive(:respond) { |msg| messages << msg }
      $creature_debug = true

      begin
        described_class.load_all(@dir)
      ensure
        $creature_debug = false
      end

      expect(messages.any? { |m| m.include?('collides') && m.include?('spectre') }).to be true
    end
  end
end
