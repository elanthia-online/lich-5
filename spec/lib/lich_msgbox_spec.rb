# frozen_string_literal: true

require 'rspec'
require 'open3'
require 'rbconfig'

RSpec.describe 'Lich.msgbox GTK responses' do
  # lib/lich replaces database stubs shared by other GUI specs. Keep its load
  # isolated while exercising the actual helper, not a copied implementation.
  let(:harness) do
    <<~'RUBY'
      module Gtk
        module ResponseType
          OK, CANCEL, YES, NO = -5, -6, -8, -9
        end
        class Dialog
          MODAL = :modal
          RESPONSE_OK, RESPONSE_CANCEL, RESPONSE_YES, RESPONSE_NO = -5, -6, -8, -9
        end
        class MessageDialog
          BUTTONS_OK, BUTTONS_OK_CANCEL, BUTTONS_YES_NO = :ok, :ok_cancel, :yes_no
          ERROR, QUESTION, WARNING, INFO = :error, :question, :warning, :info
          attr_accessor :title
          def initialize(*); end
          def run
            raise 'test failure' if ARGV[1] == 'raise'
            ResponseType.const_get(ARGV[1].upcase)
          end
          def destroy
            puts 'destroyed'
          end
        end
      end
      LICH_VERSION = 'test'
      require ARGV[0]
      begin
        puts Lich.msgbox(message: 'Unavailable frontend').inspect
      rescue RuntimeError
        puts 'raised'
      end
    RUBY
  end

  %w[ok cancel yes no raise].each do |response|
    it "destroys the dialog for #{response} without relying on a run block" do
      stdout, stderr, status = Open3.capture3(
        RbConfig.ruby, '-e', harness, File.expand_path('../../lib/lich.rb', __dir__), response
      )
      expect(status.success?).to be(true), stderr
      expected = response == 'raise' ? 'raised' : ":#{response}"
      expect(stdout.lines.map(&:strip)).to eq(['destroyed', expected])
    end
  end
end
