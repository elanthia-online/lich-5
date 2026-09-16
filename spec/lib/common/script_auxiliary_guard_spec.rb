# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/limitedarray'

RSpec.describe 'Script auxiliary input execution guards' do
  let(:script_class) { Lich::Common::Script }
  let(:interrupted) { Lich::Common::ScriptExecutionGuard::Interrupted }
  let(:buffer) { Lich::Common::LimitedArray.new }
  let(:script) { script_class.allocate }

  before(:context) do
    require_relative '../../../lib/common/script'
  end

  after(:context) do
    %i[SubScript ExecScript WizardScript Script Scripting TRUSTED_SCRIPT_BINDING].each do |const_name|
      Lich::Common.send(:remove_const, const_name) if Lich::Common.const_defined?(const_name, false)
    end
    $LOADED_FEATURES.delete_if { |path| path.end_with?('/lib/common/script.rb') }
  end

  after do
    @worker&.kill
    @worker&.join
  end

  { upstream: :@upstream_buffer, unique: :@unique_buffer }.each do |kind, variable|
    context "#{kind} input" do
      let(:blocking_read) { "#{kind}_gets".to_sym }
      let(:polling_read) { "#{kind}_gets?".to_sym }

      before { script.instance_variable_set(variable, buffer) }

      it 'preserves ordinary buffered and empty nonblocking reads' do
        expect(script.public_send(polling_read)).to be_nil
        buffer.push('first', 'second')
        expect(script.public_send(blocking_read)).to eq('first')
        expect(script.public_send(polling_read)).to eq('second')
        expect(script.public_send(polling_read)).to be_nil
      end

      it 'keeps the existing unguarded polling sleep' do
        allow(script).to receive(:sleep).with(0.05) { buffer.push('arrived') }
        expect(script).not_to receive(:execution_sleep)
        expect(script.public_send(blocking_read)).to eq('arrived')
        expect(script).to have_received(:sleep).with(0.05).once
      end

      it 'returns available data under an accepting policy' do
        script.with_execution_guard(->(_) { true }) do
          buffer.push('first', 'second')
          expect(script.public_send(blocking_read)).to eq('first')
          expect(script.public_send(polling_read)).to eq('second')
          expect(script.public_send(polling_read)).to be_nil
        end
      end

      it 'cancels an idle blocking read without needing an incoming item' do
        entered = Queue.new
        allow(script).to receive(:execution_sleep).and_wrap_original do |original, seconds|
          entered << true
          original.call(seconds)
        end
        expect do
          script.with_execution_guard(->(_) { true }) do |guard|
            @worker = Thread.new do
              script.public_send(blocking_read)
            rescue Lich::Common::ScriptExecutionGuard::Interrupted => error
              error
            end
            expect(entered.pop(timeout: 1)).to eq(true)
            guard.cancel!(:manual_hold)
            expect(@worker.join(1)).to equal(@worker)
            expect(@worker.value.reason).to eq(:manual_hold)
          end
        end.to raise_error(interrupted) { |error| expect(error.reason).to eq(:manual_hold) }
        expect(buffer).to be_empty
      end

      it 'checks cancellation before consuming queued input in either read mode' do
        [blocking_read, polling_read].each do |read|
          buffer.push('queued')
          expect do
            script.with_execution_guard(->(_) { true }) do |guard|
              guard.cancel!(:room_changed)
              script.public_send(read)
            end
          end.to raise_error(interrupted) { |error| expect(error.reason).to eq(:room_changed) }
          expect(buffer.shift).to eq('queued')
        end
      end

      it 'rechecks cancellation after the buffer returns an item' do
        [blocking_read, polling_read].each do |read|
          buffer.push('queued')
          expect do
            script.with_execution_guard(->(_) { true }) do |guard|
              allow(buffer).to receive(:shift).and_wrap_original do |original|
                line = original.call
                guard.cancel!(:room_changed)
                line
              end
              script.public_send(read)
              raise 'cancelled reader returned an item'
            end
          end.to raise_error(interrupted) { |error| expect(error.reason).to eq(:room_changed) }
        end
      end
    end
  end
end
