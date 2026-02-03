# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lich::Common::Watchable do
  # Create a test module that extends Watchable
  let(:test_module) do
    Module.new do
      extend Lich::Common::Watchable
    end
  end

  describe 'when extended by a module' do
    it 'provides the watch! method' do
      expect(test_module).to respond_to(:watch!)
    end

    it 'raises NotImplementedError if watch! is not overridden' do
      expect { test_module.watch! }.to raise_error(NotImplementedError, /must implement .watch!/)
    end
  end

  describe 'contract enforcement' do
    it 'enforces that extending modules implement watch!' do
      module_with_implementation = Module.new do
        extend Lich::Common::Watchable

        def self.watch!
          # Custom implementation
          @thread = Thread.new { sleep 0.01 }
        end
      end

      expect { module_with_implementation.watch! }.not_to raise_error
    end
  end

  describe 'documentation' do
    it 'defines the expected interface' do
      expect(Lich::Common::Watchable).to be_a(Module)
      expect(Lich::Common::Watchable.instance_methods(false)).to include(:watch!)
    end
  end
end
